## Planet capacity and growing planets — docs/SPEC.md §4–§5 (round 8, owner: "bigger planets can
## host more ships", "planets that can grow"). Off by default (cap_per_level 0, max_growth 0).
extends "res://tests/case.gd"

const World := preload("res://sim/world.gd")


## Planet 0 (player 1, growth `growth`, `ships`) is the planet under test; planet 1 is a far
## neighbour of player 1 that sends fleets. Cap 20 per level, cost 10 per next level, max 5.
func _world(ships: int, growth: int) -> World:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 1, ships, growth)
	w.add_planet(Vector2(50, 0), 1, 0, 0)
	w.add_planet(Vector2(90, 0), 2, 0, 0)
	w.cap_per_level = 20
	w.upgrade_cost_per_level = 10
	w.max_growth = 5
	return w


func test_capacity_scales_with_level() -> void:
	var w := _world(0, 2)
	assert_eq(w.capacity_of(w.planets[0]), 40)
	w.planets[0].growth = 5
	assert_eq(w.capacity_of(w.planets[0]), 100)
	w.planets[0].growth = 0
	assert_eq(w.capacity_of(w.planets[0]), 20, "a level-0 planet still holds one level's worth")
	w.cap_per_level = 0
	assert_eq(w.capacity_of(w.planets[0]), 1 << 30, "no cap: the 2010 rule")


func test_growth_stops_at_capacity() -> void:
	var w := _world(38, 2)
	w.tick()
	assert_eq(w.planets[0].ships, 40)
	w.tick()
	assert_eq(w.planets[0].ships, 40, "a full planet makes nothing")


func test_growth_never_lowers_an_overfull_planet() -> void:
	var w := _world(55, 2)
	w.tick()
	assert_eq(w.planets[0].ships, 55)


func test_reinforcing_below_capacity_is_a_plain_merge() -> void:
	var w := _world(10, 2)
	w.add_fleet(1, 15, 1, 0, 1, 1)
	w.growth_every = 99  # with tick_count 1 nothing grows this tick, so only the fleet counts
	w.tick_count = 1
	w.tick()
	assert_eq(w.planets[0].ships, 25)
	assert_eq(w.planets[0].progress, 0)


func test_ships_beyond_capacity_go_into_growth() -> void:
	var w := _world(35, 2)  # holds 40; next level costs 30
	w.growth_every = 99
	w.tick_count = 1
	w.add_fleet(1, 20, 1, 0, 1, 1)
	w.tick()
	assert_eq(w.planets[0].ships, 40, "fills up first")
	assert_eq(w.planets[0].progress, 15, "the rest feeds its growth")
	assert_eq(w.planets[0].growth, 2)


func test_enough_overflow_levels_the_planet_up() -> void:
	var w := _world(40, 2)
	w.growth_every = 99
	w.tick_count = 1
	w.add_fleet(1, 34, 1, 0, 1, 1)
	w.tick()
	assert_eq(w.planets[0].growth, 3, "30 ships bought level 3")
	assert_eq(w.planets[0].progress, 4, "the change carries toward level 4")
	assert_eq(w.capacity_of(w.planets[0]), 60)


func test_one_big_fleet_can_climb_several_levels() -> void:
	var w := _world(20, 1)
	w.growth_every = 99
	w.tick_count = 1
	w.add_fleet(1, 50, 1, 0, 1, 1)  # 20 for level 2, 30 for level 3
	w.tick()
	assert_eq(w.planets[0].growth, 3)
	assert_eq(w.planets[0].progress, 0)


func test_at_the_top_level_extra_ships_just_stay() -> void:
	var w := _world(100, 5)
	w.growth_every = 99
	w.tick_count = 1
	w.add_fleet(1, 20, 1, 0, 1, 1)
	w.tick()
	assert_eq(w.planets[0].growth, 5)
	assert_eq(w.planets[0].ships, 120, "nothing is lost")


func test_without_upgrades_extra_ships_just_stay() -> void:
	var w := _world(40, 2)
	w.max_growth = 0
	w.growth_every = 99
	w.tick_count = 1
	w.add_fleet(1, 20, 1, 0, 1, 1)
	w.tick()
	assert_eq(w.planets[0].ships, 60)
	assert_eq(w.planets[0].growth, 2)


func test_a_battle_feeds_no_growth_and_a_capture_resets_it() -> void:
	var w := _world(40, 2)
	w.growth_every = 99
	w.tick_count = 1
	w.planets[0].progress = 12
	w.add_fleet(2, 10, 2, 0, 1, 1)
	w.tick()
	assert_eq(w.planets[0].owner, 1)
	assert_eq(w.planets[0].progress, 12, "holding a planet keeps its progress")
	w.add_fleet(2, 200, 2, 0, 1, 1)
	w.tick()
	assert_eq(w.planets[0].owner, 2)
	assert_eq(w.planets[0].progress, 0, "a new owner starts from nothing")
	assert_eq(w.planets[0].growth, 2, "but keeps the level")


func test_ships_to_take_prices_growth_up_to_capacity_only() -> void:
	var w := _world(38, 2)
	w.planets[0].owner = 2
	w.shield = 0
	# 10 growth steps would add 20, but the planet tops out at 40
	assert_eq(w.ships_to_take(0, 10), 41)


func test_upgrade_needed_counts_room_and_cost() -> void:
	var w := _world(35, 2)
	w.planets[0].progress = 5
	assert_eq(w.ships_to_grow(w.planets[0]), 5 + 25, "5 to fill, 25 more to reach level 3")
	w.planets[0].growth = 5
	assert_eq(w.ships_to_grow(w.planets[0]), -1, "already at the top")


func test_growth_and_progress_are_part_of_the_hash() -> void:
	var w := _world(10, 2)
	var base := w.state_hash()
	w.planets[0].progress = 1
	assert_ne(w.state_hash(), base)
	w.planets[0].progress = 0
	w.planets[0].growth = 3
	assert_ne(w.state_hash(), base)
