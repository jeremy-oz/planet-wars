## Every script in game/ parses, and every screen builds headlessly without errors.
extends "res://tests/case.gd"

const Main := preload("res://game/main.gd")


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out


func test_every_game_script_parses() -> void:
	var files := _scripts("res://game")
	assert_true(files.size() >= 15, "found %d scripts" % files.size())
	for path in files:
		var s: GDScript = load(path)
		assert_true(s != null and s.can_instantiate(), "%s does not parse" % path)


func test_audio_files_exist() -> void:
	for n in ["pad_calm", "pad_tense", "whoosh", "thud", "ui_click", "ui_hover", "select", "deny", "win", "lose", "chime_0", "chime_9"]:
		assert_true(ResourceLoader.exists("res://game/audio/%s.wav" % n), n)


func test_screens_build_and_switch() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var main: Node = Main.new()
	tree.root.add_child(main)
	assert_not_null(main.current, "starts on the main menu")
	assert_eq(main.current.get_script().resource_path, "res://game/ui/main_menu.gd")
	main.goto_setup(false)
	assert_eq(main.current.get_script().resource_path, "res://game/ui/setup_screen.gd")
	main.open_settings()
	assert_not_null(main._settings_overlay)
	main.start_game({"seed": 3, "opponents": 2, "map": "small"}, false)
	var game: Node = main.current
	assert_eq(game.get_script().resource_path, "res://game/play/game_screen.gd")
	for i in range(12):
		game._process(0.1)
	assert_eq(game.session.config.get("pace", "calm"), "calm", "calm is the default pace")
	assert_true(game.session.world.tick_count >= 2, "1× calm steps 2.5 ticks per second")
	game.map_view.send_requested.emit(PackedInt32Array([0]), 2)
	game._process(0.45)  # one calm tick is 0.4 s
	assert_true(game.session.stats[1]["fleets"] >= 1, "a UI send reaches the sim")
	game.set_speed(3)
	assert_eq(game.speed_index, 3)
	game.open_pause()
	assert_true(game.paused)
	main.audio._process(0.5)
	assert_true(main.audio.is_music_paused(), "pausing the game pauses the music")
	game.close_pause()
	assert_false(game.paused)
	main.audio._process(0.1)
	assert_false(main.audio.is_music_paused(), "resuming brings it back")
	game.toggle_pause()
	main.audio._process(0.5)
	main.goto_menu(false)
	main.audio._process(0.1)
	assert_false(main.audio.is_music_paused(), "leaving a paused game brings the music back")
	main.start_game({"seed": 3, "opponents": 2, "map": "small"}, false)
	game = main.current
	game.force_end(true)
	assert_true(game._ended)
	main.free()


func test_training_screen_launches_a_level_and_records_stars() -> void:
	var tmp := "user://test_progress_screens.cfg"
	var tree := Engine.get_main_loop() as SceneTree
	var main: Node = Main.new()
	main.progress = preload("res://game/training/progress.gd").new(tmp)
	tree.root.add_child(main)
	main.goto_training(false)
	var screen: Node = main.current
	assert_eq(screen.get_script().resource_path, "res://game/ui/training_screen.gd")
	assert_eq(screen.selected, 0, "a fresh player starts at the first level")
	screen._process(0.016)
	main.start_game(preload("res://game/training/levels.gd").config(screen.selected), false)
	var game: Node = main.current
	assert_eq(game.get_script().resource_path, "res://game/play/game_screen.gd")
	assert_eq(str(game.config["level"]), "moon")
	assert_true(main.last_config.is_empty() or not main.last_config.has("level"), "levels do not overwrite the skirmish setup")
	assert_not_null(game.coach, "training levels have a coach")
	game._process(1.0)
	assert_eq(game.session.world.tick_count, 0, "the opening lesson holds the match")
	assert_true((game._hud["coach_card"] as Control).visible, "the lesson card is up")
	(game._hud["coach_ok"] as Button).pressed.emit()
	assert_eq(game.coach.step, 1, "GOT IT moves the lesson on")
	game._game_seconds = 30.0
	game.force_end(true)
	assert_eq(main.progress.stars("moon"), 3, "a fast win records 3 stars")
	assert_true(main.progress.is_unlocked(1), "and opens Mercury")
	var Levels := preload("res://game/training/levels.gd")
	for k in range(2):
		main.start_game(Levels.config(3), false)
		main.current.force_end(false)
	var result: Node = main.current._overlay
	assert_eq(str(result.easier_title), "EASIER MARS", "two losses in a row offer the easier retry")
	assert_eq(result.easier.get_connections().size(), 1, "EASIER is wired to a match")
	main.free()
	DirAccess.remove_absolute(tmp)
