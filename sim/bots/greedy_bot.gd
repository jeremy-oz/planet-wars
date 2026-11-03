## Captures the best-value planet it can afford, accounting for ships already on the way.
##
## Value = growth per ship spent per tick of travel. Enemy targets price in their growth during the
## trip. Each owned planet keeps a small reserve and sends exactly what a capture needs, so it
## snowballs instead of trickling. Deterministic; needs no RNG.
extends "res://sim/bots/bot.gd"

const RESERVE_PER_GROWTH := 2
const RESERVE_BASE := 3


func bot_name() -> String:
	return "GreedyBot"


func decide(world: World, player: int) -> Array:
	var orders: Array = []
	var targets := not_owned(world, player)
	if targets.is_empty():
		return orders
	# ships of mine already heading to each planet, so two planets never both pay for one capture
	var incoming: Dictionary = {}
	for f in world.fleets:
		if f.owner == player:
			incoming[f.destination] = incoming.get(f.destination, 0) + f.ships
	# enemy ships heading to each of my planets: keep enough home to survive
	var threat: Dictionary = {}
	for f in world.fleets:
		if f.owner != player and f.owner != 0:
			threat[f.destination] = threat.get(f.destination, 0) + f.ships
	for src in owned(world, player):
		var reserve: int = src.growth * RESERVE_PER_GROWTH + RESERVE_BASE + threat.get(src.id, 0)
		var surplus: int = src.ships - reserve
		if surplus < 1:
			continue
		var best: World.Planet = null
		var best_score := 0.0
		var best_needed := 0
		for t in targets:
			var tt := world.travel_time(src.id, t.id)
			var needed: int = world.ships_to_take(t.id, tt) - incoming.get(t.id, 0)
			if incoming.get(t.id, 0) > 0:
				needed += world.shield_of(t)  # a separate arrival meets the shield again
			if needed < 1:
				continue  # already covered by ships in flight
			if needed > surplus:
				continue
			var score := float(t.growth + 1) / (float(needed) * float(tt))
			if score > best_score:
				best_score = score
				best = t
				best_needed = needed
		if best != null:
			orders.append(World.Order.new(player, src.id, best.id, best_needed))
			incoming[best.id] = incoming.get(best.id, 0) + best_needed
	return orders
