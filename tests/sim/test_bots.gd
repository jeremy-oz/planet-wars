## Bot sanity and the Iteration 1 benchmark: 1000 Greedy-vs-Random games in < 10 s, Greedy > 90 %.
extends "res://tests/case.gd"

const World := preload("res://sim/world.gd")
const Ascii := preload("res://sim/ascii.gd")
const MapText := preload("res://sim/map_text.gd")
const MapGenerator := preload("res://sim/map_generator.gd")
const MatchRunner := preload("res://sim/match_runner.gd")
const GreedyBot := preload("res://sim/bots/greedy_bot.gd")
const RandomBot := preload("res://sim/bots/random_bot.gd")
const NearestBot := preload("res://sim/bots/nearest_bot.gd")
const CoachBot := preload("res://sim/bots/coach_bot.gd")

const BENCH_GAMES := 1000
const BENCH_BUDGET_S := 10.0
const BENCH_MIN_WIN_RATE := 0.9


func test_bots_only_issue_valid_orders() -> void:
	var world := MapText.parse(MapGenerator.generate(3, 3, 12), 3)
	var bots := {1: GreedyBot.new(1), 2: RandomBot.new(2), 3: NearestBot.new(3)}
	for i in range(60):
		var orders: Array = []
		for player in bots:
			for o in bots[player].decide(world, player):
				assert_true(world.is_valid_order(o), "%s issued an invalid order at tick %d" % [bots[player].bot_name(), i])
				assert_eq(o.player, player)
				orders.append(o)
		world.tick(orders)


func test_ascii_renderer_shows_planets_and_legend() -> void:
	var world := MapText.parse(MapGenerator.generate(5, 2, 6), 5)
	world.tick([World.Order.new(1, 0, 2, 10)])
	var text := Ascii.render(world, 40, 12)
	assert_true(text.contains("1"))
	assert_true(text.contains("2"))
	assert_true(text.contains("o"), "neutral planets drawn as o")
	assert_true(text.contains("*"), "a fleet in flight drawn as *")
	assert_true(text.contains("tick 1"))
	assert_true(text.contains("player 1"))


func test_greedy_beats_random_1000_games_under_10s() -> void:
	var started := Time.get_ticks_usec()
	var greedy_wins := 0
	var ticks_total := 0
	for i in range(BENCH_GAMES):
		var seed := 1000 + i
		var world := MapText.parse(MapGenerator.generate(seed, 2, 10), seed)
		world.max_ticks = 400
		var bots := {}
		# alternate seats so the result is not a map-position artefact
		if i % 2 == 0:
			bots = {1: GreedyBot.new(seed), 2: RandomBot.new(seed)}
		else:
			bots = {1: RandomBot.new(seed), 2: GreedyBot.new(seed)}
		var result := MatchRunner.play(world, bots)
		ticks_total += result["ticks"]
		var greedy_seat := 1 if i % 2 == 0 else 2
		if result["winner"] == greedy_seat:
			greedy_wins += 1
	var elapsed := (Time.get_ticks_usec() - started) / 1_000_000.0
	var rate := float(greedy_wins) / float(BENCH_GAMES)
	print("  bench: %d games in %.2fs (%.1f ms/game, avg %d ticks), Greedy won %.1f%%" % [BENCH_GAMES, elapsed, elapsed * 1000.0 / BENCH_GAMES, ticks_total / BENCH_GAMES, rate * 100.0])
	assert_true(elapsed < BENCH_BUDGET_S, "benchmark took %.2fs, budget %.0fs" % [elapsed, BENCH_BUDGET_S])
	assert_true(rate > BENCH_MIN_WIN_RATE, "Greedy win rate %.3f below %.2f" % [rate, BENCH_MIN_WIN_RATE])


func test_coach_bot_issues_valid_orders_and_beats_random() -> void:
	var world := MapText.parse(MapGenerator.generate(5, 3, 12), 5)
	var bots := {1: CoachBot.new(1), 2: RandomBot.new(2), 3: NearestBot.new(3)}
	for i in range(60):
		var orders: Array = []
		for player in bots:
			for o in bots[player].decide(world, player):
				assert_true(world.is_valid_order(o), "%s issued an invalid order at tick %d" % [bots[player].bot_name(), i])
				orders.append(o)
		world.tick(orders)
	var wins := 0
	for seed in range(1, 21):
		var w := MapText.parse(MapGenerator.generate(seed, 2, 12), seed)
		if MatchRunner.play(w, {1: CoachBot.new(seed), 2: RandomBot.new(seed)})["winner"] == 1:
			wins += 1
	assert_true(wins >= 18, "CoachBot won %d of 20 against Random" % wins)
