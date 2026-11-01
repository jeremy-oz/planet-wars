## Map text parsing, serialisation and the seeded generator — docs/SPEC.md §7–§8.
extends "res://tests/case.gd"

const World := preload("res://sim/world.gd")
const MapText := preload("res://sim/map_text.gd")
const MapGenerator := preload("res://sim/map_generator.gd")

const SAMPLE := """
# a comment
# players: 2
P 11.5 7.25 1 100 5
P 3.0  2.0  0  45 3

P 20 14 2 100 5
F 1 25 0 1 9 3
"""


func test_parse_planets_and_fleets() -> void:
	var w := MapText.parse(SAMPLE)
	assert_not_null(w)
	assert_eq(w.planets.size(), 3)
	assert_eq(w.planets[0].position, Vector2(11.5, 7.25))
	assert_eq(w.planets[1].owner, 0)
	assert_eq(w.planets[1].ships, 45)
	assert_eq(w.planets[1].growth, 3)
	assert_eq(w.planets[2].id, 2)
	assert_eq(w.num_players, 2)
	assert_eq(w.fleets.size(), 1)
	assert_eq(w.fleets[0].remaining, 3)


func test_players_header_can_exceed_owners_present() -> void:
	var w := MapText.parse("# players: 4\nP 0 0 1 10 1\nP 5 5 0 10 1\n")
	assert_eq(w.num_players, 4)


func test_malformed_lines_return_null() -> void:
	assert_null(MapText.parse("P 1 2 3\n"))
	assert_true(MapText.last_error.contains("line 1"))
	assert_null(MapText.parse("X 1 2 3 4 5\n"))
	assert_true(MapText.last_error.contains("unknown record"))
	assert_null(MapText.parse("P 0 0 1 1 1\nF 1 5 0 7 3 3\n"), "fleet to a planet that does not exist")
	assert_true(MapText.last_error.contains("fleet"))
	assert_not_null(MapText.parse("P 0 0 1 1 1\n"))
	assert_eq(MapText.last_error, "", "cleared on success")


func test_round_trip_preserves_state_hash() -> void:
	var w := MapText.parse(SAMPLE)
	w.tick([World.Order.new(2, 2, 1, 30)])
	var again := MapText.parse(MapText.serialize(w))
	again.tick_count = w.tick_count
	assert_eq(again.state_hash(), w.state_hash())


func test_generator_is_seeded_and_respects_constraints() -> void:
	var a := MapGenerator.generate(42, 4, 24)
	var b := MapGenerator.generate(42, 4, 24)
	var c := MapGenerator.generate(43, 4, 24)
	assert_eq(a, b, "same seed, same map")
	assert_ne(a, c, "different seed, different map")
	var w := MapText.parse(a)
	assert_eq(w.num_players, 4)
	assert_eq(w.planets.size(), 24)
	for player in range(1, 5):
		assert_eq(w.planet_count(player), 1, "one home planet per player")
		var home: World.Planet = w.planets[player - 1]
		assert_eq(home.ships, 100)
		assert_eq(home.growth, 5)
	for i in range(w.planets.size()):
		for j in range(i + 1, w.planets.size()):
			assert_true(w.planets[i].position.distance_to(w.planets[j].position) >= 2.0, "planets %d and %d too close" % [i, j])
		assert_true(w.planets[i].growth >= 1 and w.planets[i].growth <= 5)
