## Training ladder (game/training/): level data, stars, unlocks, and that every level is fair.
extends "res://tests/case.gd"

const Levels := preload("res://game/training/levels.gd")
const Progress := preload("res://game/training/progress.gd")
const Session := preload("res://game/play/session.gd")
const Bodies := preload("res://game/fx/bodies.gd")
const GreedyBot := preload("res://sim/bots/greedy_bot.gd")
const TMP := "user://test_progress.cfg"


func after_each() -> void:
	super.after_each()
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(TMP)


func test_every_level_builds_a_valid_match() -> void:
	var ids := {}
	for i in range(Levels.count()):
		var lv: Dictionary = Levels.LEVELS[i]
		assert_false(ids.has(lv["id"]), "level ids are unique")
		ids[lv["id"]] = true
		assert_true(Bodies.NAMES.has(lv["body"]), "%s: body has a texture" % lv["id"])
		var s := Session.new(Levels.config(i))
		assert_eq(s.world.num_players, 1 + lv["bots"].size(), "%s: one seat per bot plus you" % lv["id"])
		assert_eq(s.world.planet_count(Session.HUMAN), 1, "%s: you start with one planet" % lv["id"])
		var par: Array = lv["par"]
		assert_true(int(par[0]) > int(par[1]), "%s: the 2-star par is looser than the 3-star par" % lv["id"])


func test_levels_start_small_and_grow() -> void:
	var prev := 0
	for i in range(Levels.count()):
		var n := Session.new(Levels.config(i)).world.planets.size()
		assert_true(n >= prev, "level %d has no fewer planets than the one before" % i)
		prev = n
	assert_true(Session.new(Levels.config(0)).world.planets.size() <= 6, "the first level is tiny")


## A Greedy bot in your seat wins every level, inside the 3-star par: each level is winnable,
## and 3 stars are possible. (It reacts every tick, so a person needs longer; see levels.gd.)
func test_every_level_is_winnable_within_three_star_par() -> void:
	for i in range(Levels.count()):
		var s := Session.new(Levels.config(i))
		s.autopilot = GreedyBot.new(17)
		var ticks := 0
		while s.outcome == Session.Outcome.PLAYING and ticks < 4000:
			s.step()
			ticks += 1
		var id: String = Levels.LEVELS[i]["id"]
		assert_eq(s.outcome, Session.Outcome.WON, "%s: winnable" % id)
		assert_eq(Levels.stars_for(i, true, ticks * 0.25), 3, "%s: 3 stars in reach" % id)


func test_stars_by_time() -> void:
	assert_eq(Levels.stars_for(0, false, 10.0), 0)
	assert_eq(Levels.stars_for(0, true, 10.0), 3)
	assert_eq(Levels.stars_for(0, true, 70.0), 2)
	assert_eq(Levels.stars_for(0, true, 999.0), 1)


func test_progress_unlocks_in_order_and_keeps_best() -> void:
	var p := Progress.new(TMP)
	assert_true(p.is_unlocked(0))
	assert_false(p.is_unlocked(1), "level 2 waits for a win on level 1")
	assert_eq(p.next_level(), 0)
	assert_true(p.record("moon", 2))
	assert_true(p.is_unlocked(1))
	assert_false(p.record("moon", 1), "a worse result does not replace the best")
	assert_eq(p.next_level(), 1)
	var reloaded := Progress.new(TMP)
	assert_eq(reloaded.stars("moon"), 2, "progress survives a restart")
	assert_eq(reloaded.total_stars(), 2)


func test_level_enemy_holds_the_named_world() -> void:
	for i in range(Levels.count()):
		var c := Levels.config(i)
		var s := Session.new(c)
		var layers := Bodies.assign(s.world, c["homes"])
		for p in s.world.planets:
			if p.owner == 2:
				assert_eq(layers[p.id], Bodies.layer(Levels.LEVELS[i]["body"]), "%s held by the enemy" % Levels.LEVELS[i]["id"])
			elif p.owner == 1:
				assert_eq(layers[p.id], Bodies.layer("earth"), "you always launch from Earth")
