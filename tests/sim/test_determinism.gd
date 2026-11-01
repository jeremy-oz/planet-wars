## Same seed + same orders twice → identical state_hash() at every tick — docs/SPEC.md §9.
extends "res://tests/case.gd"

const World := preload("res://sim/world.gd")
const MapText := preload("res://sim/map_text.gd")
const MapGenerator := preload("res://sim/map_generator.gd")
const MatchRunner := preload("res://sim/match_runner.gd")
const GreedyBot := preload("res://sim/bots/greedy_bot.gd")
const RandomBot := preload("res://sim/bots/random_bot.gd")
const NearestBot := preload("res://sim/bots/nearest_bot.gd")


func _play(seed: int) -> Array:
	var world := MapText.parse(MapGenerator.generate(seed, 3, 14), seed)
	world.max_ticks = 300
	var hashes: Array = []
	var bots := {1: GreedyBot.new(seed), 2: RandomBot.new(seed + 1), 3: NearestBot.new(seed + 2)}
	MatchRunner.play(world, bots, func(w: World) -> void: hashes.append(w.state_hash()))
	return hashes


func test_same_seed_same_hashes_every_tick() -> void:
	var a := _play(7)
	var b := _play(7)
	assert_eq(a.size(), b.size())
	assert_true(a.size() > 10, "game should last a while")
	for i in range(a.size()):
		if a[i] != b[i]:
			fail("hash diverged at tick %d" % i)
			break


func test_different_seed_different_hashes() -> void:
	assert_ne(_play(7)[-1], _play(8)[-1])


func test_hash_changes_with_any_field() -> void:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 1, 10, 1)
	w.add_planet(Vector2(5, 0), 2, 10, 1)
	var base := w.state_hash()
	assert_eq(base.length(), 16)
	w.planets[0].ships += 1
	var after_ships := w.state_hash()
	assert_ne(after_ships, base)
	w.planets[0].ships -= 1
	assert_eq(w.state_hash(), base, "restoring state restores the hash")
	w.planets[1].owner = 1
	assert_ne(w.state_hash(), base)
	w.planets[1].owner = 2
	w.add_fleet(1, 1, 0, 1, 5, 5)
	assert_ne(w.state_hash(), base)


func test_hash_is_stable_across_runs() -> void:
	# A pinned value: if this changes, the sim rules or the hash changed and SIM_VERSION must bump.
	var w := MapText.parse(MapGenerator.generate(1, 2, 8), 1)
	w.max_ticks = 100
	var result := MatchRunner.play(w, {1: GreedyBot.new(1), 2: NearestBot.new(2)})
	assert_eq(result["hash"], PINNED_HASH, "sim output changed; bump SIM_VERSION and re-pin")


const PINNED_HASH := "64d0389b04f370ba"
