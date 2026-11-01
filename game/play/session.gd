## One single-player match: the sim world, the bots, the human's queued sends, events and stats.
##
## No rendering and no wall clock: the game screen calls step() on its own timer, so this is
## tested headlessly like the sim. Player 1 is always the human seat.
extends RefCounted

const World := preload("res://sim/world.gd")
const MapText := preload("res://sim/map_text.gd")
const MapGenerator := preload("res://sim/map_generator.gd")
const RandomBot := preload("res://sim/bots/random_bot.gd")
const NearestBot := preload("res://sim/bots/nearest_bot.gd")
const GreedyBot := preload("res://sim/bots/greedy_bot.gd")

const HUMAN := 1
const BOT_KINDS := ["random", "nearest", "greedy"]
## Ticks between bot decisions, by difficulty (1 tick = 0.25 s at 1× speed).
const THINK_EVERY := {"relaxed": 4, "normal": 2, "sharp": 1}
const MAP_SIZES := {"small": 12, "medium": 24, "large": 48, "huge": 200}

enum Outcome { PLAYING, WON, LOST }

var config: Dictionary
var world: World
var bots: Dictionary = {}  # player -> bot
var autopilot: RefCounted = null  # a bot driving the human seat (demos, perf), or null
var outcome: int = Outcome.PLAYING
## player -> {produced, fleets, ships_sent, captured, lost, peak_planets}
var stats: Dictionary = {}
## One PackedInt32Array per tick: total ships per player (index 0 unused).
var history: Array = []
## Ships currently in flight, all players (updated every step).
var ships_in_flight := 0
var _pending: Array = []
var _prepared: Dictionary = {}  # player -> orders decided for tick _prepared_tick
var _prepared_tick := -1


static func default_config() -> Dictionary:
	return {"seed": 1, "opponents": 1, "bot": "greedy", "difficulty": "normal", "map": "medium", "spectate": false}


static func make_bot(kind: String, bot_seed: int) -> RefCounted:
	match kind:
		"random":
			return RandomBot.new(bot_seed)
		"nearest":
			return NearestBot.new(bot_seed)
		_:
			return GreedyBot.new(bot_seed)


func _init(p_config: Dictionary = {}) -> void:
	config = default_config()
	config.merge(p_config, true)
	var map_seed: int = int(config["seed"])
	var players: int
	if config.has("map_text"):
		# Hand-made map (training levels): the seat count comes from the map itself.
		world = MapText.parse(str(config["map_text"]), map_seed)
		assert(world != null, MapText.last_error)
		players = world.num_players
	else:
		players = 1 + clampi(int(config["opponents"]), 1, 7)
		var planet_count: int = int(config.get("planets", MAP_SIZES.get(config["map"], 24)))
		var size_scale := sqrt(maxf(1.0, planet_count / 16.0))
		world = MapText.parse(MapGenerator.generate(map_seed, players, planet_count, Vector2(30.0, 20.0) * size_scale), map_seed)
	world.max_ticks = int(config.get("max_ticks", 1 << 30))
	# `bots` (one kind per opponent seat) overrides the single `bot` kind.
	var kinds: Array = config.get("bots", [])
	for p in range(2, players + 1):
		var kind := str(kinds[p - 2]) if p - 2 < kinds.size() else str(config["bot"])
		bots[p] = make_bot(kind, map_seed * 31 + p)
	for p in range(1, players + 1):
		stats[p] = {"produced": 0, "fleets": 0, "ships_sent": 0, "captured": 0, "lost": 0, "peak_planets": world.planet_count(p)}
	_record_history()


## Queue a send from `sources` (planets the human owns) to `destination`; applied on the next step.
## `fraction` is taken of what each source holds at that moment. Returns false if nothing can go.
func queue_send(sources: PackedInt32Array, destination: int, fraction: float) -> bool:
	if destination < 0 or destination >= world.planets.size():
		return false
	var valid: PackedInt32Array = []
	for s in sources:
		if s != destination and s >= 0 and s < world.planets.size() and world.planets[s].owner == HUMAN and world.planets[s].ships >= 1:
			valid.append(s)
	if valid.is_empty():
		return false
	_pending.append({"sources": valid, "destination": destination, "fraction": clampf(fraction, 0.01, 1.0)})
	return true


## How many ships a send of `fraction` from `sources` would launch right now (for UI labels).
func estimate(sources: PackedInt32Array, fraction: float) -> int:
	var n := 0
	for s in sources:
		if s >= 0 and s < world.planets.size() and world.planets[s].owner == HUMAN:
			n += _ships_for(world.planets[s].ships, fraction)
	return n


static func _ships_for(have: int, fraction: float) -> int:
	if have < 1:
		return 0
	if fraction >= 1.0:
		return have
	return clampi(int(floor(have * fraction)), 1, have)


## Advance one tick. Returns presentation events:
##   {type: "launch", owner, source, destination, ships}
##   {type: "arrival", kind: "capture"|"battle"|"reinforce", planet, owner_before, owner, involved}
##   {type: "eliminated", player}
func step() -> Array:
	var events: Array = []
	if outcome != Outcome.PLAYING:
		return events
	var orders: Array = _human_orders()
	for p in _thinkers():
		if _prepared_tick == world.tick_count and _prepared.has(p):
			orders.append_array(_prepared[p])
		else:
			orders.append_array(_decide(p))
	_prepared.clear()

	var owners_before := PackedInt32Array()
	for pl in world.planets:
		owners_before.append(pl.owner)
	var alive_before := world.alive_players()
	var fleets_before := world.fleets.size()
	world.apply_orders(orders)
	for i in range(fleets_before, world.fleets.size()):
		var f: World.Fleet = world.fleets[i]
		events.append({"type": "launch", "owner": f.owner, "source": f.source, "destination": f.destination, "ships": f.ships})
		stats[f.owner]["fleets"] += 1
		stats[f.owner]["ships_sent"] += f.ships

	var arriving: Dictionary = {}  # planet -> {owner: ships}
	for f in world.fleets:
		if f.remaining == 1:
			if not arriving.has(f.destination):
				arriving[f.destination] = {}
			var by: Dictionary = arriving[f.destination]
			by[f.owner] = int(by.get(f.owner, 0)) + f.ships
	var defenders := PackedInt32Array()
	for pl in world.planets:
		defenders.append(pl.ships + (pl.growth if pl.owner != 0 else 0))
		if pl.owner != 0:
			stats[pl.owner]["produced"] += pl.growth

	world.tick([])  # orders already applied above; tick() applies none, then grows, moves, resolves

	var destinations := arriving.keys()
	destinations.sort()
	for id: int in destinations:
		var pl: World.Planet = world.planets[id]
		var by: Dictionary = arriving[id]
		var involved: int = defenders[id]
		var foreign := false
		for o: int in by:
			involved += int(by[o])
			if o != owners_before[id]:
				foreign = true
		var kind := "reinforce"
		if pl.owner != owners_before[id]:
			kind = "capture"
		elif foreign:
			kind = "battle"
		events.append({"type": "arrival", "kind": kind, "planet": id, "owner_before": owners_before[id], "owner": pl.owner, "involved": involved})
		if kind == "capture":
			if pl.owner != 0:
				stats[pl.owner]["captured"] += 1
			if owners_before[id] != 0:
				stats[owners_before[id]]["lost"] += 1
	for p in alive_before:
		if not world.is_alive(p):
			events.append({"type": "eliminated", "player": p})
	for p: int in stats:
		stats[p]["peak_planets"] = maxi(int(stats[p]["peak_planets"]), world.planet_count(p))
	_record_history()
	_update_outcome()
	return events


## Let up to `max_bots` bots decide their orders for the coming tick now, spreading the cost of
## thinking over the frames between ticks. Deterministic: the world cannot change between ticks,
## and step() uses exactly these orders.
func think_ahead(max_bots: int = 1) -> void:
	if outcome != Outcome.PLAYING:
		return
	if _prepared_tick != world.tick_count:
		_prepared.clear()
		_prepared_tick = world.tick_count
	var done := 0
	for p in _thinkers():
		if _prepared.has(p):
			continue
		_prepared[p] = _decide(p)
		done += 1
		if done >= max_bots:
			return


func _thinkers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for p in range(1, world.num_players + 1):
		if not world.is_alive(p) or not _thinks(p):
			continue
		if bots.has(p) or (p == HUMAN and autopilot != null):
			out.append(p)
	return out


func _decide(p: int) -> Array:
	return (autopilot if p == HUMAN else bots[p]).decide(world, p)


func is_spectating() -> bool:
	return bool(config.get("spectate", false))


func _thinks(player: int) -> bool:
	var every: int = int(THINK_EVERY.get(config["difficulty"], 2))
	return (world.tick_count + player) % every == 0


func _human_orders() -> Array:
	var orders: Array = []
	var left: Dictionary = {}
	for intent: Dictionary in _pending:
		var dst: int = intent["destination"]
		for src: int in intent["sources"]:
			var pl: World.Planet = world.planets[src]
			if pl.owner != HUMAN or src == dst:
				continue
			var have: int = int(left.get(src, pl.ships))
			var n := _ships_for(have, float(intent["fraction"]))
			if n < 1:
				continue
			left[src] = have - n
			orders.append(World.Order.new(HUMAN, src, dst, n))
	_pending.clear()
	return orders


func _update_outcome() -> void:
	if is_spectating():
		var w := world.winner()
		if w != -1:
			outcome = Outcome.WON if w == HUMAN else Outcome.LOST
		return
	if not world.is_alive(HUMAN):
		outcome = Outcome.LOST
	elif world.alive_players().size() == 1:
		outcome = Outcome.WON


## Latest total ships per player (index 0 unused); cached so the HUD never re-sums every frame.
func totals() -> PackedInt32Array:
	return history[history.size() - 1]


func _record_history() -> void:
	var row := PackedInt32Array()
	row.resize(world.num_players + 1)
	ships_in_flight = 0
	for pl in world.planets:
		if pl.owner != 0:
			row[pl.owner] += pl.ships
	for f in world.fleets:
		row[f.owner] += f.ships
		ships_in_flight += f.ships
	history.append(row)
