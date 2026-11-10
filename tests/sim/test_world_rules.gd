## Growth, travel time, orders, winner — docs/SPEC.md §2–§4, §6.
extends "res://tests/case.gd"

const World := preload("res://sim/world.gd")


func _two_planet_world() -> World:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 1, 10, 2)
	w.add_planet(Vector2(3, 4), 2, 10, 3)
	return w


func test_owned_planets_grow_neutral_do_not() -> void:
	var w := _two_planet_world()
	w.add_planet(Vector2(10, 10), 0, 7, 5)
	w.tick()
	assert_eq(w.planets[0].ships, 12)
	assert_eq(w.planets[1].ships, 13)
	assert_eq(w.planets[2].ships, 7, "neutral must not grow")
	assert_eq(w.tick_count, 1)


func test_growth_every_n_ticks_paces_production() -> void:
	var w := _two_planet_world()
	w.growth_every = 3
	for i in range(6):
		w.tick()
	assert_eq(w.planets[0].ships, 10 + 2 * 2, "grows on ticks 0 and 3 only")
	assert_eq(w.planets[1].ships, 10 + 3 * 2)


func test_travel_time_is_ceil_of_distance_min_one() -> void:
	var w := _two_planet_world()
	w.add_planet(Vector2(3.1, 4), 0, 1, 1)   # 0.1 from planet 1
	w.add_planet(Vector2(0, 0), 0, 1, 1)     # same spot as planet 0
	assert_eq(w.travel_time(0, 1), 5, "3-4-5 triangle")
	assert_eq(w.travel_time(1, 2), 1, "0.1 rounds up to 1")
	assert_eq(w.travel_time(0, 3), 1, "distance 0 still takes one tick")
	assert_eq(w.travel_time(1, 0), w.travel_time(0, 1), "symmetric")


func test_fleet_arrives_after_trip_length_ticks() -> void:
	var w := _two_planet_world()
	w.tick([World.Order.new(1, 0, 1, 4)])
	assert_eq(w.planets[0].ships, 8, "10 - 4 sent + 2 growth")
	assert_eq(w.fleets.size(), 1)
	assert_eq(w.fleets[0].trip_length, 5)
	assert_eq(w.fleets[0].remaining, 4, "advanced once in the launch tick")
	for i in range(3):
		w.tick()
	assert_eq(w.fleets.size(), 1, "still flying after 4 ticks")
	w.tick()
	assert_eq(w.fleets.size(), 0, "arrived on tick 5")


func test_one_tick_trip_arrives_same_tick() -> void:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 1, 10, 0)
	w.add_planet(Vector2(0.5, 0), 0, 2, 0)
	w.tick([World.Order.new(1, 0, 1, 5)])
	assert_eq(w.fleets.size(), 0)
	assert_eq(w.planets[1].owner, 1)
	assert_eq(w.planets[1].ships, 3)


func test_invalid_orders_are_dropped_silently() -> void:
	var w := _two_planet_world()
	var bad := [
		World.Order.new(1, 1, 0, 1),   # not my planet
		World.Order.new(1, 0, 0, 1),   # source == destination
		World.Order.new(1, 0, 1, 0),   # zero ships
		World.Order.new(1, 0, 1, 11),  # more than I have
		World.Order.new(1, 0, 9, 1),   # no such planet
		World.Order.new(0, 0, 1, 1),   # neutral cannot order
	]
	assert_eq(w.apply_orders(bad), 6)
	assert_eq(w.fleets.size(), 0)
	assert_eq(w.planets[0].ships, 10)


func test_orders_from_one_source_see_earlier_orders() -> void:
	var w := _two_planet_world()
	w.add_planet(Vector2(9, 9), 0, 1, 1)
	var orders := [World.Order.new(1, 0, 1, 6), World.Order.new(1, 0, 2, 6)]
	assert_eq(w.apply_orders(orders), 1, "second order exceeds what is left")
	assert_eq(w.planets[0].ships, 4)


func test_players_apply_in_ascending_id_regardless_of_list_order() -> void:
	var w := _two_planet_world()
	w.apply_orders([World.Order.new(2, 1, 0, 3), World.Order.new(1, 0, 1, 2)])
	assert_eq(w.fleets[0].owner, 1)
	assert_eq(w.fleets[1].owner, 2)


func test_winner_ongoing_then_last_player_standing() -> void:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 1, 50, 1)
	w.add_planet(Vector2(1, 0), 2, 5, 1)
	assert_eq(w.winner(), -1)
	w.tick([World.Order.new(1, 0, 1, 40)])
	assert_eq(w.planets[1].owner, 1)
	assert_eq(w.winner(), 1)


func test_player_with_only_a_fleet_is_still_alive() -> void:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 1, 10, 1)
	w.add_planet(Vector2(5, 0), 0, 1, 1)
	w.add_fleet(2, 30, 1, 1, 5, 3)
	assert_true(w.is_alive(2))
	assert_eq(w.winner(), -1)


func test_max_ticks_most_ships_wins_tie_is_draw() -> void:
	var w := World.new()
	w.max_ticks = 2
	w.add_planet(Vector2(0, 0), 1, 10, 3)
	w.add_planet(Vector2(50, 0), 2, 10, 1)
	w.tick()
	assert_eq(w.winner(), -1)
	w.tick()
	assert_eq(w.winner(), 1, "16 vs 12 ships at the limit")
	var d := World.new()
	d.max_ticks = 1
	d.add_planet(Vector2(0, 0), 1, 10, 1)
	d.add_planet(Vector2(50, 0), 2, 10, 1)
	d.tick()
	assert_eq(d.winner(), 0, "equal ships at the limit is a draw")


func test_num_players_follows_highest_owner() -> void:
	var w := World.new()
	w.add_planet(Vector2(0, 0), 0, 1, 1)
	assert_eq(w.num_players, 0)
	w.add_planet(Vector2(1, 0), 3, 1, 1)
	assert_eq(w.num_players, 3)
