## Every planet with a surplus sends half its ships to the nearest planet it does not own.
## Deterministic; needs no RNG.
extends "res://sim/bots/bot.gd"

const RESERVE_PER_GROWTH := 3


func bot_name() -> String:
	return "NearestBot"


func decide(world: World, player: int) -> Array:
	var orders: Array = []
	var targets := not_owned(world, player)
	if targets.is_empty():
		return orders
	for src in owned(world, player):
		var reserve: int = src.growth * RESERVE_PER_GROWTH + 2
		var send: int = (src.ships - reserve) / 2
		if send < 1:
			continue
		var best: World.Planet = null
		var best_tt := 1 << 30
		for t in targets:
			var tt := world.travel_time(src.id, t.id)
			if tt < best_tt:
				best_tt = tt
				best = t
		orders.append(World.Order.new(player, src.id, best.id, send))
	return orders
