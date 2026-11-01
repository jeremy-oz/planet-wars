## The pure, deterministic Planet Wars simulation. Implements docs/SPEC.md exactly.
##
## No rendering, no clock, no I/O, no unseeded randomness. Same map + seed + orders
## → same `state_hash()` on every machine. Preload by path:
##   const World := preload("res://sim/world.gd")
extends RefCounted

const SIM_VERSION := "1.0"
const DEFAULT_MAX_TICKS := 1000

## Planet record. `owner` 0 is neutral, 1..N are players.
class Planet:
	var id: int
	var position: Vector2
	var owner: int
	var ships: int
	var growth: int

	func _init(p_id: int, p_position: Vector2, p_owner: int, p_ships: int, p_growth: int) -> void:
		id = p_id
		position = p_position
		owner = p_owner
		ships = p_ships
		growth = p_growth


## Fleet in flight. `remaining` counts down to 0, at which point it arrives (SPEC §4).
class Fleet:
	var owner: int
	var ships: int
	var source: int
	var destination: int
	var trip_length: int
	var remaining: int

	func _init(p_owner: int, p_ships: int, p_source: int, p_destination: int, p_trip_length: int, p_remaining: int) -> void:
		owner = p_owner
		ships = p_ships
		source = p_source
		destination = p_destination
		trip_length = p_trip_length
		remaining = p_remaining


## One launch request from a player (SPEC §2).
class Order:
	var player: int
	var source: int
	var destination: int
	var ships: int

	func _init(p_player: int, p_source: int, p_destination: int, p_ships: int) -> void:
		player = p_player
		source = p_source
		destination = p_destination
		ships = p_ships


var planets: Array[Planet] = []
var fleets: Array[Fleet] = []
var num_players: int = 0
var tick_count: int = 0
var max_ticks: int = DEFAULT_MAX_TICKS
var seed: int = 0
## Seeded RNG for anything in the sim that needs randomness (currently only map generation).
var rng := RandomNumberGenerator.new()

var _travel: PackedInt32Array = []  # travel-time matrix, n*n, built lazily
var _travel_n: int = -1


func _init(p_seed: int = 0) -> void:
	seed = p_seed
	rng.seed = p_seed


# --- building -----------------------------------------------------------------------------

func add_planet(position: Vector2, owner: int, ships: int, growth: int) -> Planet:
	var p := Planet.new(planets.size(), position, owner, ships, growth)
	planets.append(p)
	if owner > num_players:
		num_players = owner
	_travel_n = -1
	return p


func add_fleet(owner: int, ships: int, source: int, destination: int, trip_length: int, remaining: int) -> Fleet:
	var f := Fleet.new(owner, ships, source, destination, trip_length, remaining)
	fleets.append(f)
	if owner > num_players:
		num_players = owner
	return f


# --- geometry -----------------------------------------------------------------------------

## SPEC §3: ceil of the Euclidean distance, at least 1 tick.
func travel_time(a: int, b: int) -> int:
	_ensure_travel()
	return _travel[a * _travel_n + b]


func _ensure_travel() -> void:
	var n := planets.size()
	if _travel_n == n:
		return
	_travel_n = n
	_travel.resize(n * n)
	for i in range(n):
		for j in range(n):
			var d := ceili(planets[i].position.distance_to(planets[j].position))
			_travel[i * n + j] = maxi(1, d)


# --- orders -------------------------------------------------------------------------------

## SPEC §2 validity, evaluated against the current state (so earlier orders this tick count).
func is_valid_order(o: Order) -> bool:
	if o.source < 0 or o.source >= planets.size() or o.destination < 0 or o.destination >= planets.size():
		return false
	if o.source == o.destination:
		return false
	var src := planets[o.source]
	if src.owner != o.player or o.player < 1:
		return false
	return o.ships >= 1 and o.ships <= src.ships


## Applies every valid order, players in ascending id, each player's orders in the order given.
## Returns the number of orders dropped as invalid.
func apply_orders(orders: Array) -> int:
	var dropped := 0
	for o: Order in orders:
		if o.player < 1 or o.player > num_players:
			dropped += 1
	for player in range(1, num_players + 1):
		for o: Order in orders:
			if o.player != player:
				continue
			if not is_valid_order(o):
				dropped += 1
				continue
			var tt := travel_time(o.source, o.destination)
			planets[o.source].ships -= o.ships
			fleets.append(Fleet.new(o.player, o.ships, o.source, o.destination, tt, tt))
	return dropped


# --- the tick -----------------------------------------------------------------------------

## SPEC §4. One step of the simulation with this tick's orders (any player, any order).
func tick(orders: Array = []) -> void:
	apply_orders(orders)
	for p in planets:
		if p.owner != 0:
			p.ships += p.growth
	var still_flying: Array[Fleet] = []
	var arrivals: Dictionary = {}  # destination -> Array[Fleet]
	for f in fleets:
		f.remaining -= 1
		if f.remaining <= 0:
			if not arrivals.has(f.destination):
				arrivals[f.destination] = []
			arrivals[f.destination].append(f)
		else:
			still_flying.append(f)
	fleets = still_flying
	var destinations := arrivals.keys()
	destinations.sort()
	for d in destinations:
		_resolve(planets[d], arrivals[d])
	tick_count += 1


## SPEC §5: simultaneous combat. Only the two largest forces matter.
func _resolve(planet: Planet, arriving: Array) -> void:
	var force: Dictionary = {}  # owner -> ships
	force[planet.owner] = planet.ships
	for f: Fleet in arriving:
		force[f.owner] = force.get(f.owner, 0) + f.ships
	if force.size() == 1:
		planet.ships = force[planet.owner]
		return
	var owners := force.keys()
	owners.sort()
	var top_owner := -1
	var top := -1
	var second := -1
	for owner in owners:
		var s: int = force[owner]
		if s > top:
			second = top
			top = s
			top_owner = owner
		elif s > second:
			second = s
	if top == second:
		planet.ships = 0  # tie: current owner keeps the planet with nothing on it
		return
	planet.ships = top - second
	planet.owner = top_owner


# --- queries ------------------------------------------------------------------------------

func planet_count(player: int) -> int:
	var n := 0
	for p in planets:
		if p.owner == player:
			n += 1
	return n


func fleet_count(player: int) -> int:
	var n := 0
	for f in fleets:
		if f.owner == player:
			n += 1
	return n


## Ships on planets plus ships in flight.
func total_ships(player: int) -> int:
	var n := 0
	for p in planets:
		if p.owner == player:
			n += p.ships
	for f in fleets:
		if f.owner == player:
			n += f.ships
	return n


func growth_rate(player: int) -> int:
	var n := 0
	for p in planets:
		if p.owner == player:
			n += p.growth
	return n


func is_alive(player: int) -> bool:
	for p in planets:
		if p.owner == player:
			return true
	for f in fleets:
		if f.owner == player:
			return true
	return false


func alive_players() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for player in range(1, num_players + 1):
		if is_alive(player):
			out.append(player)
	return out


## SPEC §6: -1 while the game is on, a player id, or 0 for a draw.
func winner() -> int:
	var alive := alive_players()
	if alive.size() == 1:
		return alive[0]
	if alive.size() == 0:
		return 0
	if tick_count >= max_ticks:
		var best := 0
		var best_ships := -1
		var tied := false
		for player in alive:
			var s := total_ships(player)
			if s > best_ships:
				best_ships = s
				best = player
				tied = false
			elif s == best_ships:
				tied = true
		return 0 if tied else best
	return -1


# --- determinism --------------------------------------------------------------------------

const FNV_OFFSET := -3750763034362895579  # 14695981039346656037 as a signed 64-bit int
const FNV_PRIME := 1099511628211


## SPEC §9: FNV-1a over integer fields only, canonical order. 16 hex characters.
func state_hash() -> String:
	var h := FNV_OFFSET
	h = _fnv(h, tick_count)
	h = _fnv(h, planets.size())
	for p in planets:
		h = _fnv(h, p.id)
		h = _fnv(h, p.owner)
		h = _fnv(h, p.ships)
	h = _fnv(h, fleets.size())
	for f in fleets:
		h = _fnv(h, f.owner)
		h = _fnv(h, f.ships)
		h = _fnv(h, f.source)
		h = _fnv(h, f.destination)
		h = _fnv(h, f.trip_length)
		h = _fnv(h, f.remaining)
	return "%08x%08x" % [(h >> 32) & 0xFFFFFFFF, h & 0xFFFFFFFF]


static func _fnv(h: int, value: int) -> int:
	for i in range(8):
		h ^= (value >> (i * 8)) & 0xFF
		h *= FNV_PRIME  # 64-bit wraparound is the intended behaviour
	return h
