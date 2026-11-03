## Training ladder (game/training/): level data, stars, unlocks, and that every level is fair.
extends "res://tests/case.gd"

const Levels := preload("res://game/training/levels.gd")
const Progress := preload("res://game/training/progress.gd")
const Session := preload("res://game/play/session.gd")
const Bodies := preload("res://game/fx/bodies.gd")
const CoachBot := preload("res://sim/bots/coach_bot.gd")
const Coach := preload("res://game/training/coach.gd")
const MapText := preload("res://sim/map_text.gd")
const FRACTIONS := [0.25, 0.5, 0.75, 1.0]
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
	assert_true(prev <= 14, "the last world stays readable (Auralux-sized, at most 14 planets)")


## Owner, round 6: "too many planets too quickly". The count rises in small steps.
func test_planet_count_rises_in_small_steps() -> void:
	var prev := Session.new(Levels.config(0)).world.planets.size()
	for i in range(1, Levels.count()):
		var n := Session.new(Levels.config(i)).world.planets.size()
		assert_true(n - prev <= 3, "%s adds at most 3 planets" % Levels.LEVELS[i]["id"])
		prev = n


## Every map after the first is a designed formation: each seat's home is the same distance from
## the centre and has the same planets around it, and no two planets crowd each other.
func test_formations_are_fair_and_spaced() -> void:
	for i in range(1, Levels.count()):
		var id: String = Levels.LEVELS[i]["id"]
		var w := MapText.parse(str(Levels.config(i)["map_text"]))  # the map before any head start
		var homes: Array = []
		for p in w.planets:
			if p.owner != 0:
				homes.append(p)
		assert_eq(homes.size(), w.num_players, "%s: one home per seat" % id)
		var centre := Vector2(15, 10)
		var profile := []
		for h in homes:
			var near := []
			for p in w.planets:
				if p != h:
					near.append(Vector2(p.position.distance_to(h.position), p.growth))
			near.sort()
			profile.append(near)
			assert_almost_eq(h.position.distance_to(centre), homes[0].position.distance_to(centre), 0.05, "%s: homes equally far from the centre" % id)
			assert_eq(h.ships, homes[0].ships, "%s: equal starts" % id)
		for k in range(1, profile.size()):
			for m in range(profile[0].size()):
				var a: Vector2 = profile[0][m]
				var b: Vector2 = profile[k][m]
				assert_true(absf(a.x - b.x) < 0.05 and a.y == b.y, "%s: every seat sees the same map" % id)
		for a in w.planets:
			for b in w.planets:
				if a.id < b.id:
					assert_true(a.position.distance_to(b.position) >= 2.5, "%s: planets %d and %d too close" % [id, a.id, b.id])


## Following the coach briskly (one move every 1, 1.5 or 2 s) wins every level inside the 3-star
## par at least once: 3 stars are possible for a quick player.
func test_every_level_is_winnable_within_three_star_par() -> void:
	for i in range(Levels.count()):
		var id: String = Levels.LEVELS[i]["id"]
		var best := 0
		for seconds: float in [1.0, 1.5, 2.0]:
			var s := _follow_coach(Levels.config(i), seconds)
			if s.outcome == Session.Outcome.WON:
				best = maxi(best, Levels.stars_for(i, true, s.world.tick_count * s.tick_seconds))
		assert_eq(best, 3, "%s: 3 stars in reach" % id)


## Play a level like a person who follows the coach: one move every `seconds` of game time,
## through the real send path (queue_send with the 25/50/75/100 % share keys).
func _follow_coach(cfg: Dictionary, seconds: float) -> Session:
	var s := Session.new(cfg)
	var advisor := CoachBot.new(0)
	var every := maxi(1, int(round(seconds / s.tick_seconds)))
	var t := 0
	while s.outcome == Session.Outcome.PLAYING and t * s.tick_seconds < 800.0 * 1.25:
		if t % every == 0:
			var a := advisor.advise(s.world, 1)
			if not a.is_empty():
				var srcs: PackedInt32Array = a["sources"]
				for f: float in FRACTIONS:
					var n := 0
					for x in srcs:
						n += int(floor(s.world.planets[x].ships * f))
					if n >= int(a["ships"]):
						s.queue_send(srcs, a["destination"], f)
						break
		s.step()
		t += 1
	return s


## The owner got stuck on Mars: every world must be winnable at a person's pace (one move every
## two seconds, following the coach), on the normal and the easier retry, with 2 stars in reach.
func test_every_world_is_winnable_at_a_human_pace_by_following_the_coach() -> void:
	for i in range(Levels.count()):
		var id: String = Levels.LEVELS[i]["id"]
		for assist: bool in [false, true]:
			var s := _follow_coach(Levels.config(i, assist), 2.0)
			assert_eq(s.outcome, Session.Outcome.WON, "%s%s: won at one move every 2 s" % [id, " (easier)" if assist else ""])
			if not assist:
				assert_true(Levels.stars_for(i, true, s.world.tick_count * s.tick_seconds) >= 2, "%s: 2 stars at that pace" % id)


func test_the_easier_retry_is_easier_and_worth_one_star() -> void:
	for i in range(Levels.count()):
		var normal := Session.new(Levels.config(i))
		var easy := Session.new(Levels.config(i, true))
		assert_true(easy.world.total_ships(1) > normal.world.total_ships(1), "%s: a bigger home fleet" % Levels.LEVELS[i]["id"])
		assert_true(Session.THINK_EVERY[easy.config["difficulty"]] > Session.THINK_EVERY[normal.config["difficulty"]], "%s: a slower enemy" % Levels.LEVELS[i]["id"])
	assert_eq(Levels.stars_for(0, true, 1.0, true), 1, "the easier retry earns one star, however fast")
	assert_eq(Levels.stars_for(0, false, 1.0, true), 0)


func test_progress_counts_losses_in_a_row() -> void:
	var p := Progress.new(TMP)
	assert_eq(p.losses("mars"), 0)
	p.record("mars", 0)
	p.record("mars", 0)
	assert_eq(p.losses("mars"), Levels.ASSIST_LOSSES, "two losses: the easier retry is offered")
	assert_eq(Progress.new(TMP).losses("mars"), 2, "the streak survives a restart")
	assert_true(p.record("mars", 1))
	assert_eq(p.losses("mars"), 0, "a win clears the streak")
	assert_true(p.is_unlocked(Levels.index_of("mars") + 1), "an easier-retry win opens the next world")


func _names(world: RefCounted) -> PackedStringArray:
	var out := PackedStringArray()
	for p in world.planets:
		out.append("P%d" % p.id)
	return out


func test_the_lesson_holds_the_match_until_each_step_is_done() -> void:
	var s := Session.new(Levels.config(0))
	var c := Coach.new(s.world, 0, _names(s.world))
	assert_eq(c.steps.size(), 3)
	assert_true(c.holding(), "the first world opens on a lesson")
	assert_false(str(c.lesson()["text"]).contains("{"), "planet names are filled in")
	c.on_action("send", {"sources": PackedInt32Array([0]), "destination": 1})
	assert_eq(c.step, 0, "a send does not skip a GOT IT step")
	c.on_action("ok")
	assert_eq(c.step, 1)
	assert_true(c.lesson().has("destination"), "the send step points at a planet")
	c.on_action("ok")
	assert_eq(c.step, 1, "the send step waits for a send")
	c.on_action("send", {"sources": PackedInt32Array([0]), "destination": 1})
	c.on_action("ok")
	assert_false(c.holding(), "lesson over: the match runs")


func test_the_mars_lesson_waits_until_you_own_two_planets() -> void:
	var i := Levels.index_of("mars")
	var s := Session.new(Levels.config(i))
	var c := Coach.new(s.world, i, _names(s.world))
	c.on_action("send", {"sources": PackedInt32Array([0]), "destination": 1})
	assert_false(c.holding(), "nothing to box-select with one planet: play on")
	for p in s.world.planets:
		if p.owner == 0:
			p.owner = 1
			break
	assert_true(c.holding(), "two planets: the box-select lesson appears")
	c.on_action("select", {"count": 2})
	assert_false(c.holding())


func test_the_coach_warns_before_a_planet_falls_and_names_the_helper() -> void:
	# P0 weak and under attack, P1 strong next door, enemy home far away
	var w := MapText.parse("# players: 2\nP 5 5 1 4 1\nP 8 5 1 60 3\nP 25 5 2 40 3\nF 2 30 2 0 20 6\n", 1)
	var c := Coach.new(w, 0, _names(w))
	c.steps = []
	var h := c.update(10.0)
	assert_eq(str(h.get("kind", "")), "defend")
	assert_eq(int(h["destination"]), 0)
	assert_eq((h["sources"] as PackedInt32Array)[0], 1)
	assert_true(str(h["text"]).contains("P0") and str(h["text"]).contains("P1"), h["text"])


func test_the_coach_points_at_a_move_when_you_sit_idle() -> void:
	var w := MapText.parse("# players: 2\nP 5 5 1 40 3\nP 9 5 0 5 2\nP 25 5 2 10 1\n", 1)
	var c := Coach.new(w, 0, _names(w))
	c.steps = []
	c.on_action("send")
	assert_true(c.update(2.0).is_empty(), "you just sent: no nagging")
	var h := c.update(2.0 + Coach.IDLE_SECONDS)
	assert_eq(str(h.get("kind", "")), "expand")
	assert_eq(int(h["destination"]), 1, "the cheap, close neutral")
	c.on_action("send")
	assert_true(c.hint.is_empty(), "a send clears the hint")
	assert_false(c.request(20.0).is_empty(), "H always answers")


func test_stars_by_time() -> void:
	assert_eq(Levels.stars_for(0, false, 10.0), 0)
	assert_eq(Levels.stars_for(0, true, 10.0), 3)
	assert_eq(Levels.stars_for(0, true, 60.0), 2)
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
			else:
				assert_false(layers[p.id] in [Bodies.layer("earth"), Bodies.layer(Levels.LEVELS[i]["body"])], "%s: no neutral shares a home's name" % Levels.LEVELS[i]["id"])
