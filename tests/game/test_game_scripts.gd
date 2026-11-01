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
	assert_true(game.session.world.tick_count >= 4, "1× speed steps about 4 ticks per second")
	game.map_view.send_requested.emit(PackedInt32Array([0]), 2)
	game._process(0.3)
	assert_true(game.session.stats[1]["fleets"] >= 1, "a UI send reaches the sim")
	game.set_speed(3)
	assert_eq(game.speed_index, 3)
	game.open_pause()
	assert_true(game.paused)
	game.close_pause()
	assert_false(game.paused)
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
	game._game_seconds = 30.0
	game.force_end(true)
	assert_eq(main.progress.stars("moon"), 3, "a fast win records 3 stars")
	assert_true(main.progress.is_unlocked(1), "and opens Mercury")
	main.free()
	DirAccess.remove_absolute(tmp)
