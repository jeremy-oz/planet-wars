## Entry point: owns audio, settings, screen switching (300 ms fade through the void), and the
## tooling modes used by tools/capture.py and `make perf`:
##   -- --capture-screens <dir>   walk every screen and save PNGs
##   -- --quick-shots <dir>       three frames of the demo game (art iteration)
##   -- --demo                    endless match with a fake cursor (for the 60 s recording)
##   -- --perf [<report path>]    200-planet stress test, vsync off, frame-time report
extends Node

const Palette := preload("res://game/theme/palette.gd")
const UiKit := preload("res://game/ui/ui_kit.gd")
const AudioDirector := preload("res://game/audio/audio_director.gd")
const MainMenu := preload("res://game/ui/main_menu.gd")
const SetupScreen := preload("res://game/ui/setup_screen.gd")
const GameScreen := preload("res://game/play/game_screen.gd")
const SettingsOverlay := preload("res://game/ui/settings_overlay.gd")
const TrainingScreen := preload("res://game/ui/training_screen.gd")
const Progress := preload("res://game/training/progress.gd")

const DEMO_CONFIG := {"seed": 5, "opponents": 3, "bot": "greedy", "difficulty": "normal", "map": "medium", "demo_cursor": true}

var audio: Node
var settings := {"music": 0.7, "sfx": 0.8, "ui": 0.6, "fullscreen": false}
var last_config: Dictionary = {}  ## last skirmish setup (training levels are not kept here)
var progress := Progress.new()
var current: Node = null
var _fade: ColorRect
var _overlay_layer: CanvasLayer
var _settings_overlay: Control = null


func _ready() -> void:
	add_to_group("main")
	RenderingServer.set_default_clear_color(Palette.VOID)
	audio = AudioDirector.new()
	audio.name = "Audio"
	add_child(audio)
	UiKit.audio = audio
	audio.apply_volumes(settings)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 50
	add_child(_overlay_layer)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Palette.VOID
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(_fade)
	var args := OS.get_cmdline_user_args()
	if args.has("--capture-screens"):
		var i := args.find("--capture-screens")
		_capture(args[i + 1] if i + 1 < args.size() else "user://capture")
	elif args.has("--quick-shots"):
		var k := args.find("--quick-shots")
		_quick_shots(args[k + 1] if k + 1 < args.size() else "user://quick")
	elif args.has("--demo"):
		start_game(DEMO_CONFIG.duplicate(), false)
	elif args.has("--perf"):
		var j := args.find("--perf")
		_perf(args[j + 1] if j + 1 < args.size() else "")
	else:
		goto_menu(false)


func _exit_tree() -> void:
	preload("res://game/fx/textures.gd").release()
	UiKit.audio = null


func goto_menu(animated: bool = true) -> void:
	var m := MainMenu.new()
	m.main = self
	_show(m, animated)


func goto_setup(animated: bool = true) -> void:
	var s := SetupScreen.new()
	s.main = self
	_show(s, animated)


func goto_training(animated: bool = true) -> void:
	var t := TrainingScreen.new()
	t.main = self
	_show(t, animated)


func start_game(config: Dictionary, animated: bool = true) -> void:
	if not config.has("level"):
		last_config = config.duplicate()
	var g := GameScreen.new()
	g.main = self
	g.config = config
	_show(g, animated)


func open_settings() -> void:
	if _settings_overlay != null:
		return
	var s := SettingsOverlay.new()
	s.main = self
	s.closed.connect(func() -> void: _settings_overlay = null)
	_settings_overlay = s
	_overlay_layer.add_child(s)


func apply_settings() -> void:
	audio.apply_volumes(settings)
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func _show(screen: Node, animated: bool) -> void:
	if animated and current != null and is_inside_tree():
		var out := create_tween()
		out.tween_property(_fade, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
		await out.finished
	if current != null:
		current.queue_free()
	current = screen
	add_child(screen)
	move_child(screen, 0)
	if is_inside_tree():
		var into := create_tween()
		into.tween_property(_fade, "modulate:a", 0.0, 0.3 if not animated else 0.15).set_trans(Tween.TRANS_SINE)
	else:
		_fade.modulate.a = 0.0


# --- tooling modes ------------------------------------------------------------------------

func _wait(seconds: float) -> Signal:
	return get_tree().create_timer(seconds).timeout


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := dir.path_join(shot_name + ".png")
	img.save_png(path)
	print("capture: ", path)


func _capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# Captures never touch the player's real training progress.
	var scratch := "user://capture_progress.cfg"
	DirAccess.remove_absolute(scratch)
	progress = Progress.new(scratch)
	goto_menu(false)
	await _wait(2.4)
	await _shot(dir, "01_main_menu")
	goto_training()
	await _wait(1.6)
	await _shot(dir, "01b_training")
	start_game(preload("res://game/training/levels.gd").config(0))
	await _wait(2.2)
	await _shot(dir, "01c_level_1")
	last_config = DEMO_CONFIG.duplicate()
	goto_setup()
	await _wait(1.2)
	await _shot(dir, "02_setup")
	open_settings()
	await _wait(0.8)
	await _shot(dir, "03_settings")
	if _settings_overlay:
		_settings_overlay.close()
	start_game(DEMO_CONFIG.duplicate())
	await _wait(1.0)
	await _shot(dir, "04_game_start")
	await _wait(17.0)
	await _shot(dir, "05_game_midgame")
	var g: Node = current
	g.open_pause()
	await _wait(0.8)
	await _shot(dir, "06_pause")
	g.close_pause()
	await _wait(0.3)
	# a real win: training level 2 (Mercury) with the blue seat on autopilot, played out at 4×
	var mercury := preload("res://game/training/levels.gd").config(1)
	mercury["autopilot"] = true
	mercury["speed_index"] = 3
	start_game(mercury)
	var guard := 0
	while not current._ended and guard < 600:
		await _wait(0.1)
		guard += 1
	await _wait(1.8)
	await _shot(dir, "07_victory")
	# a real loss: the blue seat idles against two Sharp Greedy bots at 4×
	start_game({"seed": 15, "opponents": 2, "bot": "greedy", "difficulty": "sharp", "map": "small", "speed_index": 3})
	guard = 0
	while not current._ended and guard < 900:
		await _wait(0.1)
		guard += 1
	await _wait(1.8)
	await _shot(dir, "08_defeat")
	var huge := {"seed": 9, "opponents": 3, "bot": "greedy", "difficulty": "sharp", "map": "huge", "autopilot": true, "speed_index": 2}
	start_game(huge)
	await _wait(9.0)
	await _shot(dir, "09_game_huge")
	goto_training()
	await _wait(1.6)
	await _shot(dir, "10_training_after_win")
	DirAccess.remove_absolute(scratch)
	get_tree().quit()


## Dev loop: the menu, the training map, level 1 and a busy demo game, for checking art changes
## without the full capture walk (about 25 s).
func _quick_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	goto_menu(false)
	await _wait(2.4)
	await _shot(dir, "a_menu")
	goto_training(false)
	await _wait(1.4)
	await _shot(dir, "b_training")
	start_game(preload("res://game/training/levels.gd").config(0), false)
	await _wait(2.0)
	await _shot(dir, "c_level1")
	start_game(DEMO_CONFIG.duplicate(), false)
	await _wait(12.0)
	await _shot(dir, "d_game")
	get_tree().quit()


func _perf(report_path: String) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	start_game({"seed": 9, "opponents": 3, "bot": "greedy", "difficulty": "sharp", "map": "huge", "autopilot": true, "speed_index": 3}, false)
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	await _wait(3.0)
	var render_cpu := 0.0
	var render_gpu := 0.0
	var frames := PackedFloat32Array()
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < 20_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in frames:
		total += f
	var g: Node = current
	var lines := PackedStringArray([
		"# Performance — 200-planet map, all effects on",
		"",
		"Godot %s · %s · %s" % [Engine.get_version_info()["string"], RenderingServer.get_video_adapter_name(), OS.get_name()],
		"Map: huge (%d planets), 4 bot-driven seats, Sharp, 4× speed, vsync off, 20 s after a 3 s warm-up." % g.session.world.planets.size(),
		"",
		"| metric | value |",
		"|---|---|",
		"| frames | %d |" % frames.size(),
		"| average fps | %.0f |" % (frames.size() / (total / 1000.0)),
		"| mean frame | %.2f ms |" % (total / frames.size()),
		"| p95 frame | %.2f ms |" % sorted[int(sorted.size() * 0.95)],
		"| p99 frame | %.2f ms |" % sorted[int(sorted.size() * 0.99)],
		"| worst frame | %.2f ms |" % sorted[sorted.size() - 1],
		"| render CPU, mean | %.2f ms |" % (render_cpu / frames.size()),
		"| render GPU, mean | %.2f ms |" % (render_gpu / frames.size()),
		"| peak fleets in flight | %d |" % g.peak_fleets,
		"| ticks simulated | %d |" % g.session.world.tick_count,
		"| sim step, mean | %.2f ms |" % (g.sim_usec / 1000.0 / maxf(g.sim_steps, 1)),
		"| sim step, worst | %.2f ms |" % (g.sim_worst_usec / 1000.0),
		"| sim share of frame time | %.0f%% |" % (100.0 * g.sim_usec / 1000.0 / total),
		"",
		"60 fps holds when p99 < 16.7 ms. Frame times are wall clock, so they include waiting on the GPU;",
		"the GL Compatibility renderer on macOS does not report GPU time separately (it reads 0).",
		"This is a stress test: four Sharp bots at 4× keep thousands of fleets in flight, far more than a human game.",
	])
	var report := "\n".join(lines) + "\n"
	print(report)
	if report_path != "":
		var f := FileAccess.open(report_path, FileAccess.WRITE)
		if f:
			f.store_string(report)
	get_tree().quit()
