## Plays a world to completion with a bot per seat. Used by tests, the benchmark and
## (later) the single-player game loop. Returns {winner, ticks, hash}.
extends RefCounted

const World := preload("res://sim/world.gd")


## `bots` maps player id -> bot (anything with `decide(world, player) -> Array[World.Order]`).
## Seats without a bot never send orders. `on_tick`, if given, is called with the world after each tick.
static func play(world: World, bots: Dictionary, on_tick: Callable = Callable()) -> Dictionary:
	while world.winner() == -1:
		var orders: Array = []
		for player in range(1, world.num_players + 1):
			if bots.has(player) and world.is_alive(player):
				orders.append_array(bots[player].decide(world, player))
		world.tick(orders)
		if on_tick.is_valid():
			on_tick.call(world)
	return {"winner": world.winner(), "ticks": world.tick_count, "hash": world.state_hash()}
