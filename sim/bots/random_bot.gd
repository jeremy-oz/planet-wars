## Sends a random number of ships from a random owned planet to a random other planet.
## The baseline every other bot must beat convincingly.
extends "res://sim/bots/bot.gd"


func bot_name() -> String:
	return "RandomBot"


func decide(world: World, player: int) -> Array:
	var mine := owned(world, player)
	if mine.is_empty() or world.planets.size() < 2:
		return []
	var src: World.Planet = mine[rng.randi_range(0, mine.size() - 1)]
	if src.ships < 1:
		return []
	var dst_id := rng.randi_range(0, world.planets.size() - 2)
	if dst_id >= src.id:
		dst_id += 1
	return [World.Order.new(player, src.id, dst_id, rng.randi_range(1, src.ships))]
