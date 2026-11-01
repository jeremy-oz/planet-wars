## Base class for local opponent bots. Bots are for playing against, not a product.
##
## A bot owns a seeded RNG so a game with bots is as deterministic as one without.
## Subclasses implement `decide()` and must not mutate the world.
extends RefCounted

const World := preload("res://sim/world.gd")

var rng := RandomNumberGenerator.new()


func _init(seed: int = 0) -> void:
	rng.seed = seed


func bot_name() -> String:
	return "Bot"


## Return this tick's orders for `player`. Must be pure apart from `rng`.
func decide(_world: World, _player: int) -> Array:
	return []


func owned(world: World, player: int) -> Array:
	var out: Array = []
	for p in world.planets:
		if p.owner == player:
			out.append(p)
	return out


func not_owned(world: World, player: int) -> Array:
	var out: Array = []
	for p in world.planets:
		if p.owner != player:
			out.append(p)
	return out
