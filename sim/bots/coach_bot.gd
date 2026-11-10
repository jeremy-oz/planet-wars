## The training coach's advisor: the ONE move a person should make next, and why.
##
## A person makes about one move every two seconds, so this picks a single order, defence first:
##   "defend"  an enemy fleet will take one of your planets; reinforce it from a planet that can
##             get there in time.
##   "strike"  an enemy planet is weak enough to take now (its growth during the trip priced in).
##   "expand"  the best-value neutral you can afford.
##   "grow"    land ships on a full planet of yours so it reaches the next level (growing planets).
## Every source keeps a reserve against enemy planets close enough to hit it, so following the
## advice never leaves a front-line planet empty. Deterministic; needs no RNG.
## tests/game/test_training.gd plays every training level by following this advice at a human pace.
extends "res://sim/bots/bot.gd"

const RESERVE_PER_GROWTH := 2
const RESERVE_BASE := 3
var near_ticks := 12  ## an enemy planet this close (3 s at 1×) threatens a source
var exposure := 0.5  ## ...and the source keeps this share of that enemy's ships at home
var strike_bonus := 2.0  ## an enemy planet is worth this many neutrals of the same size (it stops their growth)
var grow_value := 3.0  ## one level on your own planet: more ships, more room, a bigger shield, and no fight


func bot_name() -> String:
	return "CoachBot"


func decide(world: World, player: int) -> Array:
	var a := advise(world, player)
	if a.is_empty():
		return []
	# split the ships over the group in proportion to what each can spare
	var orders: Array = []
	var left: int = a["ships"]
	var srcs: PackedInt32Array = a["sources"]
	for i in range(srcs.size()):
		var n: int = left if i == srcs.size() - 1 else mini(left, world.planets[srcs[i]].ships - reserve(world, player, world.planets[srcs[i]], 0))
		if n >= 1:
			orders.append(World.Order.new(player, srcs[i], a["destination"], n))
			left -= n
	return orders


## {kind: "defend"|"strike"|"expand"|"grow", sources: PackedInt32Array, destination, ships} or {} when there is nothing
## worth doing yet (save up).
func advise(world: World, player: int) -> Dictionary:
	var mine := owned(world, player)
	if mine.is_empty():
		return {}
	var incoming := {}  # my ships already heading to a planet
	var threat := {}  # enemy ships heading to each of my planets
	var first_eta := {}  # soonest enemy arrival at each of my planets
	for f in world.fleets:
		if f.owner == player:
			incoming[f.destination] = int(incoming.get(f.destination, 0)) + f.ships
		elif f.owner != 0 and world.planets[f.destination].owner == player:
			threat[f.destination] = int(threat.get(f.destination, 0)) + f.ships
			first_eta[f.destination] = mini(int(first_eta.get(f.destination, 1 << 30)), f.remaining)
	var spare := {}
	for src in mine:
		spare[src.id] = src.ships - reserve(world, player, src, int(threat.get(src.id, 0)))

	# 1. defend the most valuable planet that will fall
	var best := {}
	var best_value := -1.0
	for m in mine:
		if not threat.has(m.id):
			continue
		var eta: int = first_eta[m.id]
		var short: int = int(threat[m.id]) - (world.garrison_after(m, eta) + world.shield_of(m)) - int(incoming.get(m.id, 0)) + 1
		if short < 1:
			continue
		for h in mine:
			if h.id == m.id or int(spare[h.id]) < short or world.travel_time(h.id, m.id) > eta:
				continue
			var value := float(m.growth + 1) / float(world.travel_time(h.id, m.id))
			if value > best_value:
				best_value = value
				best = {"kind": "defend", "sources": PackedInt32Array([h.id]), "destination": m.id, "ships": short}
	if not best.is_empty():
		return best

	# 2. the best-value capture: from one planet, or from the nearest two or three together
	var best_score := 0.0
	for t in world.planets:
		var grow := t.owner == player
		if grow and (not world.can_grow(t) or threat.has(t.id)):
			continue
		var near: Array = []
		for src in mine:
			if src.id != t.id and int(spare[src.id]) >= 1:
				near.append(src)
		near.sort_custom(func(a: World.Planet, b: World.Planet) -> bool: return world.travel_time(a.id, t.id) < world.travel_time(b.id, t.id))
		var group: Array = []
		var pooled := 0
		for src in near.slice(0, 3):
			group.append(src.id)
			pooled += int(spare[src.id])
			var tt := world.travel_time(src.id, t.id)  # the slowest of the group so far
			var needed: int
			var gain: float
			if grow:
				needed = world.ships_to_grow(t) - int(incoming.get(t.id, 0))
				gain = grow_value
			else:
				needed = world.ships_to_take(t.id, tt) - int(incoming.get(t.id, 0))
				if int(incoming.get(t.id, 0)) > 0:
					needed += world.shield_of(t)  # a separate arrival meets the shield again
				# a strike also removes the enemy's growth: worth twice a neutral of the same size
				gain = float(t.growth + 1) * (strike_bonus if t.owner != 0 else 1.0)
			if needed < 1 or needed > pooled:
				continue
			# every extra planet in a group is another click, so groups pay a small toll
			var score := gain / (float(needed) * float(tt)) / (1.0 + 0.25 * (group.size() - 1))
			if score > best_score:
				best_score = score
				var kind := "grow" if grow else ("strike" if t.owner != 0 else "expand")
				best = {"kind": kind, "sources": PackedInt32Array(group), "destination": t.id, "ships": needed}
			break
	return best


## Ships `src` should keep home: a base reserve, what is already flying at it, and a share of any
## enemy planet near enough to strike before reinforcements could arrive.
func reserve(world: World, player: int, src: World.Planet, threat: int) -> int:
	var keep := 0
	for e in world.planets:
		if e.owner != 0 and e.owner != player and world.travel_time(e.id, src.id) <= near_ticks:
			keep = maxi(keep, int(e.ships * exposure))
	return src.growth * RESERVE_PER_GROWTH + RESERVE_BASE + maxi(threat, keep)
