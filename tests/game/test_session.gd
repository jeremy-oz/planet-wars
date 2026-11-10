## Session: the single-player match wrapper around the sim (game/play/session.gd).
extends "res://tests/case.gd"

const Session := preload("res://game/play/session.gd")
const World := preload("res://sim/world.gd")
const GreedyBot := preload("res://sim/bots/greedy_bot.gd")


func _first_neutral(s: Session) -> int:
	for p in s.world.planets:
		if p.owner == 0:
			return p.id
	return -1


func test_config_builds_requested_map() -> void:
	var s := Session.new({"seed": 3, "opponents": 3, "map": "large"})
	assert_eq(s.world.num_players, 4)
	assert_eq(s.world.planets.size(), 48)
	assert_eq(s.bots.size(), 3)
	assert_eq(s.world.planet_count(Session.HUMAN), 1)
	var huge := Session.new({"map": "huge", "opponents": 3})
	assert_eq(huge.world.planets.size(), 200, "huge map must fit 200 planets")


func test_queue_send_takes_fraction_at_apply_time() -> void:
	var s := Session.new({"seed": 4, "difficulty": "relaxed"})
	var home := 0
	var target := _first_neutral(s)
	assert_true(s.queue_send(PackedInt32Array([home]), target, 0.5))
	var events := s.step()
	var launched := 0
	for e: Dictionary in events:
		if e["type"] == "launch" and int(e["owner"]) == Session.HUMAN:
			launched = int(e["ships"])
	assert_eq(launched, 50, "half of 100 home ships")
	assert_eq(s.stats[Session.HUMAN]["fleets"], 1)
	assert_eq(s.stats[Session.HUMAN]["ships_sent"], 50)


func test_queue_send_rejects_planets_not_owned() -> void:
	var s := Session.new({"seed": 4})
	var neutral := _first_neutral(s)
	assert_false(s.queue_send(PackedInt32Array([neutral]), 0, 1.0))
	assert_false(s.queue_send(PackedInt32Array([0]), 0, 1.0), "source equals destination")
	assert_false(s.queue_send(PackedInt32Array([0]), 999, 1.0), "no such planet")


func test_two_sends_from_one_source_in_one_tick_share_the_ships() -> void:
	var s := Session.new({"seed": 4, "difficulty": "relaxed"})
	var n := _first_neutral(s)
	s.queue_send(PackedInt32Array([0]), n, 0.5)
	s.queue_send(PackedInt32Array([0]), n, 1.0)
	var sent := 0
	for e: Dictionary in s.step():
		if e["type"] == "launch" and int(e["owner"]) == Session.HUMAN:
			sent += int(e["ships"])
	assert_eq(sent, 100, "50 then the remaining 50, never more than the planet holds")


func test_estimate_matches_what_is_sent() -> void:
	var s := Session.new({"seed": 4})
	assert_eq(s.estimate(PackedInt32Array([0]), 0.25), 25)
	assert_eq(s.estimate(PackedInt32Array([0]), 1.0), 100)
	assert_eq(s.estimate(PackedInt32Array([1]), 1.0), 0, "a bot's planet contributes nothing")


func test_capture_event_and_stats() -> void:
	var s := Session.new({"seed": 4, "difficulty": "relaxed"})
	var n := _first_neutral(s)
	var w := s.world
	w.planets[n].ships = 1
	s.queue_send(PackedInt32Array([0]), n, 1.0)
	var captured := false
	for i in range(80):
		for e: Dictionary in s.step():
			if e["type"] == "arrival" and int(e["planet"]) == n and e["kind"] == "capture" and int(e["owner"]) == Session.HUMAN:
				captured = true
		if captured:
			break
	assert_true(captured, "the send should capture a 1-ship neutral")
	assert_true(int(s.stats[Session.HUMAN]["captured"]) >= 1)
	assert_true(int(s.stats[Session.HUMAN]["peak_planets"]) >= 2)


func test_history_records_every_tick() -> void:
	var s := Session.new({"seed": 2})
	for i in range(10):
		s.step()
	assert_eq(s.history.size(), 11, "initial row plus one per tick")
	assert_eq((s.history[0] as PackedInt32Array)[1], 100)


func test_outcome_lost_when_human_eliminated() -> void:
	var s := Session.new({"seed": 2})
	for p in s.world.planets:
		if p.owner == Session.HUMAN:
			p.owner = 2
	s.step()
	assert_eq(s.outcome, Session.Outcome.LOST)
	assert_eq(s.step(), [], "a finished session does nothing")


func test_outcome_won_when_only_human_left() -> void:
	var s := Session.new({"seed": 2, "opponents": 2})
	for p in s.world.planets:
		if p.owner > 1:
			p.owner = 1
	s.step()
	assert_eq(s.outcome, Session.Outcome.WON)


func test_autopilot_plays_a_full_game_deterministically() -> void:
	var hashes: Array = []
	for run in range(2):
		var s := Session.new({"seed": 12, "opponents": 2, "bot": "nearest", "difficulty": "sharp", "map": "small"})
		s.autopilot = GreedyBot.new(5)
		var guard := 0
		while s.outcome == Session.Outcome.PLAYING and guard < 3000:
			s.step()
			guard += 1
		assert_ne(s.outcome, Session.Outcome.PLAYING, "game should finish")
		hashes.append(s.world.state_hash())
	assert_eq(hashes[0], hashes[1])


func test_difficulty_sets_how_often_bots_think() -> void:
	var relaxed := Session.new({"difficulty": "relaxed"})
	var thinks := 0
	for t in range(8):
		relaxed.world.tick_count = t
		if relaxed._thinks(2):
			thinks += 1
	assert_eq(thinks, 2)
	var sharp := Session.new({"difficulty": "sharp"})
	assert_true(sharp._thinks(2))


func test_thinking_ahead_gives_identical_games() -> void:
	var hashes: Array = []
	for ahead in [false, true]:
		var s := Session.new({"seed": 21, "opponents": 3, "difficulty": "normal", "map": "small"})
		s.autopilot = GreedyBot.new(3)
		for i in range(150):
			if ahead:
				s.think_ahead(1)
				s.think_ahead(2)
			s.step()
		hashes.append(s.world.state_hash())
	assert_eq(hashes[0], hashes[1], "pre-computed bot orders must not change the game")


func test_planets_have_room_and_a_full_one_grows_when_fed() -> void:
	var s := Session.new({"map_text": "# players: 2\nP 5 5 1 60 2\nP 7 5 1 40 1\nP 25 5 2 10 1\n"})
	assert_eq(s.world.capacity_of(s.world.planets[0]), Session.CAP_PER_LEVEL * 2, "calm pace caps planets")
	s.queue_send(PackedInt32Array([1]), 0, 1.0)  # 40 onto a full level-2 planet: 30 buys level 3
	var grew := false
	for i in range(10):
		for e in s.step():
			if e["type"] == "grow" and int(e["planet"]) == 0:
				grew = true
	assert_true(grew, "a grow event for the presentation")
	assert_eq(s.world.planets[0].growth, 3)
