## Combat resolution edge cases — docs/SPEC.md §5.
extends "res://tests/case.gd"

const World := preload("res://sim/world.gd")


## Planet 0 is far away (unused); planet 1 is the battlefield. Fleets arrive next tick.
func _battlefield(owner: int, ships: int) -> World:
	var w := World.new()
	w.add_planet(Vector2(100, 100), 1, 1, 0)
	w.add_planet(Vector2(0, 0), owner, ships, 0)
	w.num_players = 3
	return w


func test_capture_keeps_the_difference() -> void:
	var w := _battlefield(0, 20)
	w.add_fleet(2, 35, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 2)
	assert_eq(w.planets[1].ships, 15)


func test_failed_attack_leaves_defender_with_difference() -> void:
	var w := _battlefield(1, 40)
	w.add_fleet(2, 15, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 1)
	assert_eq(w.planets[1].ships, 25)


func test_reinforcing_own_planet_merges_without_combat() -> void:
	var w := _battlefield(2, 10)
	w.add_fleet(2, 25, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 2)
	assert_eq(w.planets[1].ships, 35)


func test_tie_leaves_owner_unchanged_with_zero_ships() -> void:
	var neutral := _battlefield(0, 20)
	neutral.add_fleet(2, 20, 0, 1, 1, 1)
	neutral.tick()
	assert_eq(neutral.planets[1].owner, 0, "neutral stays neutral")
	assert_eq(neutral.planets[1].ships, 0)
	var owned := _battlefield(1, 20)
	owned.add_fleet(2, 20, 0, 1, 1, 1)
	owned.tick()
	assert_eq(owned.planets[1].owner, 1, "owner keeps the planet")
	assert_eq(owned.planets[1].ships, 0)


func test_tie_between_two_attackers_on_neutral_stays_neutral() -> void:
	var w := _battlefield(0, 5)
	w.add_fleet(2, 30, 0, 1, 1, 1)
	w.add_fleet(3, 30, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 0)
	assert_eq(w.planets[1].ships, 0)


func test_three_way_only_top_two_matter() -> void:
	var w := _battlefield(1, 10)
	w.add_fleet(2, 50, 0, 1, 1, 1)
	w.add_fleet(3, 30, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 2)
	assert_eq(w.planets[1].ships, 20, "50 - 30; the defender's 10 is irrelevant")


func test_three_way_defender_can_hold() -> void:
	var w := _battlefield(1, 60)
	w.add_fleet(2, 50, 0, 1, 1, 1)
	w.add_fleet(3, 30, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 1)
	assert_eq(w.planets[1].ships, 10)


func test_same_owner_fleets_merge_before_fighting() -> void:
	var w := _battlefield(1, 40)
	w.add_fleet(2, 25, 0, 1, 1, 1)
	w.add_fleet(2, 25, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 2)
	assert_eq(w.planets[1].ships, 10)


func test_growth_happens_before_arrival() -> void:
	var w := World.new()
	w.add_planet(Vector2(100, 100), 1, 1, 0)
	w.add_planet(Vector2(0, 0), 1, 10, 5)
	w.add_fleet(2, 15, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[1].owner, 1, "10 + 5 growth = 15 vs 15 is a tie")
	assert_eq(w.planets[1].ships, 0)


func test_arrivals_at_different_planets_are_independent() -> void:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 0, 5, 0)
	w.add_planet(Vector2(10, 0), 0, 5, 0)
	w.add_fleet(1, 8, 1, 0, 1, 1)
	w.add_fleet(2, 9, 0, 1, 1, 1)
	w.tick()
	assert_eq(w.planets[0].owner, 1)
	assert_eq(w.planets[0].ships, 3)
	assert_eq(w.planets[1].owner, 2)
	assert_eq(w.planets[1].ships, 4)
