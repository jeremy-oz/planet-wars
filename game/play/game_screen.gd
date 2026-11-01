## The game: camera, map, HUD, speed, pause, results. Owns a Session and steps it on a timer.
##
## Sim time: one tick every TICK_SECONDS at 1×. Rendering interpolates between ticks.
extends Node2D

const Palette := preload("res://game/theme/palette.gd")
const UiKit := preload("res://game/ui/ui_kit.gd")
const Session := preload("res://game/play/session.gd")
const MapView := preload("res://game/play/map_view.gd")
const Starfield := preload("res://game/play/starfield.gd")
const ShareBar := preload("res://game/ui/share_bar.gd")
const PauseOverlay := preload("res://game/ui/pause_overlay.gd")
const ResultOverlay := preload("res://game/ui/result_overlay.gd")
const GreedyBot := preload("res://sim/bots/greedy_bot.gd")

const HUMAN := 1
const TICK_SECONDS := 0.25
const SPEEDS := [0.5, 1.0, 2.0, 4.0]
const SPEED_LABELS := ["½×", "1×", "2×", "4×"]
const FRACTIONS := [0.25, 0.5, 0.75, 1.0]
const MAX_STEPS_PER_FRAME := 4

var main: Node
var config: Dictionary = {}
var session: Session
var map_view: MapView
var camera: Camera2D
var speed_index := 1
var paused := false
var fraction_index := 1
var peak_fleets := 0
var sim_usec := 0  ## total time spent in Session.step(), for the perf report
var sim_steps := 0
var sim_worst_usec := 0

var _starfield: Node2D
var _acc := 0.0
var _game_seconds := 0.0
var _ended := false
var _overlay: Control = null
var _shake := 0.0
var _rng := RandomNumberGenerator.new()
var _sent_once := false
var _fit_zoom := 1.0
var _panning := false
var _hud: Dictionary = {}
var _shown_totals := PackedFloat32Array()
var _fraction_buttons: Array = []
var _demo_bot: RefCounted = null
var _demo: Dictionary = {}
var _demo_wait := 1.0


func _ready() -> void:
	_rng.seed = 77
	session = Session.new(config)
	if bool(config.get("autopilot", false)):
		session.autopilot = GreedyBot.new(int(config.get("seed", 1)) + 7)
	if bool(config.get("demo_cursor", false)):
		_demo_bot = GreedyBot.new(int(config.get("seed", 1)) + 9)
	speed_index = clampi(int(config.get("speed_index", 1)), 0, SPEEDS.size() - 1)
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	_starfield = Starfield.new()
	bg.add_child(_starfield)
	map_view = MapView.new()
	add_child(map_view)
	map_view.bind(session.world)
	map_view.send_requested.connect(_on_send)
	map_view.denied.connect(_on_denied)
	map_view.selection_changed.connect(_on_selection_changed)
	map_view.you_marker = 0.0 if (bool(config.get("autopilot", false))) else 6.0
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_shown_totals.resize(session.world.num_players + 1)
	for p in range(1, session.world.num_players + 1):
		_shown_totals[p] = session.world.total_ships(p)
	_build_hud()
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	if main and main.audio:
		main.audio.set_tension(0.0)


# --- loop ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if session == null:
		return
	if not paused and not _ended:
		session.think_ahead(1)
		_acc += delta * SPEEDS[speed_index] / TICK_SECONDS
		var steps := 0
		while _acc >= 1.0 and steps < MAX_STEPS_PER_FRAME:
			_acc -= 1.0
			steps += 1
			_step()
			if _ended:
				break
		_acc = minf(_acc, 0.999)
	map_view.tick_fraction = _acc
	map_view.screen_scale = camera.zoom.x
	map_view.estimate_ships = session.estimate(map_view.current_sources(), FRACTIONS[fraction_index])
	peak_fleets = maxi(peak_fleets, session.world.fleets.size())
	_update_shake(delta)
	_starfield.scroll(camera.position * camera.zoom.x)
	_update_hud(delta)
	if _demo_bot != null:
		_demo_process(delta)
	if main and main.audio:
		var total := 0
		for v in session.totals():
			total += v
		main.audio.set_tension(clampf(float(session.ships_in_flight) / maxf(float(total), 1.0) * 3.0, 0.0, 1.0))


func _step() -> void:
	var t0 := Time.get_ticks_usec()
	var events := session.step()
	var spent := Time.get_ticks_usec() - t0
	sim_usec += spent
	sim_steps += 1
	sim_worst_usec = maxi(sim_worst_usec, spent)
	_game_seconds += TICK_SECONDS
	map_view.on_events(events)
	_react(events)
	if session.outcome != Session.Outcome.PLAYING:
		_ended = true
		get_tree().create_timer(0.9).timeout.connect(_show_result)


## Sounds and camera shake for this tick's events. Capped so a 200-planet war stays musical.
func _react(events: Array) -> void:
	var audio: Node = main.audio if main else null
	var chimes := 0
	var whooshes := 0
	for e: Dictionary in events:
		match str(e["type"]):
			"launch":
				if int(e["owner"]) != HUMAN and whooshes < 2 and audio:
					audio.play("whoosh", -16.0, _rng.randf_range(0.85, 1.1))
					whooshes += 1
			"arrival":
				var id: int = e["planet"]
				var g: int = session.world.planets[id].growth
				var involved: int = e["involved"]
				var mine := int(e["owner"]) == HUMAN or int(e["owner_before"]) == HUMAN
				match str(e["kind"]):
					"capture":
						if audio and chimes < 3:
							if int(e["owner"]) == HUMAN:
								audio.chime(5 - g, -2.0)
							elif int(e["owner_before"]) == HUMAN:
								audio.chime(5 + (5 - g), -4.0)
								audio.play("thud", -6.0)
							else:
								audio.chime(5 + (5 - g), -14.0)
							chimes += 1
						if mine:
							_shake = maxf(_shake, clampf(float(involved) / 70.0, 0.25, 1.0) * 7.0)
					"battle":
						if audio and mine:
							audio.play("thud", -10.0, _rng.randf_range(0.9, 1.1))
						if mine and involved > 30:
							_shake = maxf(_shake, clampf(float(involved) / 120.0, 0.1, 0.6) * 7.0)


func _update_shake(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 18.0)
	if _shake > 0.05:
		camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake / camera.zoom.x
	else:
		camera.offset = Vector2.ZERO


# --- input --------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _overlay != null:
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE and _overlay is PauseOverlay:
			close_pause()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4:
				set_fraction(k.keycode - KEY_1)
			KEY_SPACE:
				toggle_pause()
			KEY_ESCAPE:
				if not map_view.selection.is_empty():
					map_view.cancel()
					map_view.selection = PackedInt32Array()
				else:
					open_pause()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_PERIOD:
				set_speed(speed_index + 1)
			KEY_MINUS, KEY_KP_SUBTRACT, KEY_COMMA:
				set_speed(speed_index - 1)
			KEY_A:
				if k.ctrl_pressed or k.meta_pressed:
					map_view.select_all()
			_:
				return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.12, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.12, mb.position)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
	elif event is InputEventMouseMotion and _panning:
		camera.position -= (event as InputEventMouseMotion).relative / camera.zoom.x
		_clamp_camera()
	elif event is InputEventPanGesture:
		camera.position += (event as InputEventPanGesture).delta * 12.0 / camera.zoom.x
		_clamp_camera()
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		_zoom_at(mg.factor, mg.position)


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var view := get_viewport_rect().size
	var world_before := camera.position + (screen_pos - view * 0.5) / camera.zoom.x
	var z := clampf(camera.zoom.x * factor, _fit_zoom * 0.85, maxf(_fit_zoom * 4.0, 2.0))
	camera.zoom = Vector2(z, z)
	camera.position = world_before - (screen_pos - view * 0.5) / z
	_clamp_camera()


func _clamp_camera() -> void:
	var r := map_view.map_rect()
	camera.position = camera.position.clamp(r.position, r.end)


func _fit_camera() -> void:
	var view := get_viewport_rect().size
	var r := map_view.map_rect()
	var usable := view - Vector2(64.0, 250.0)  # top HUD ~80 px, bottom hint + send bar ~150 px
	_fit_zoom = minf(usable.x / r.size.x, usable.y / r.size.y)
	camera.zoom = Vector2(_fit_zoom, _fit_zoom)
	camera.position = r.get_center() + Vector2(0, 32.0) / _fit_zoom


# --- actions ------------------------------------------------------------------------------

func set_fraction(i: int) -> void:
	fraction_index = clampi(i, 0, FRACTIONS.size() - 1)
	for k in range(_fraction_buttons.size()):
		(_fraction_buttons[k] as Button).set_pressed_no_signal(k == fraction_index)


func set_speed(i: int) -> void:
	var before := speed_index
	speed_index = clampi(i, 0, SPEEDS.size() - 1)
	if before != speed_index:
		UiKit.sound("ui_click")
		_pulse(_hud["speed"])


func toggle_pause() -> void:
	paused = not paused
	UiKit.sound("ui_click")
	(_hud["pause_button"] as Button).text = "RESUME" if paused else "PAUSE"
	var banner: Control = _hud["banner"]
	banner.visible = true
	create_tween().tween_property(banner, "modulate:a", 1.0 if paused else 0.0, 0.2)


func open_pause() -> void:
	if _overlay != null or _ended:
		return
	if not paused:
		toggle_pause()
	(_hud["banner"] as Control).modulate.a = 0.0
	var o := PauseOverlay.new()
	o.resume.connect(close_pause)
	o.restart.connect(func() -> void: main.start_game(config.duplicate()))
	o.new_map.connect(_new_map)
	o.settings.connect(func() -> void: main.open_settings())
	o.main_menu.connect(func() -> void: main.goto_menu())
	_set_overlay(o)


func close_pause() -> void:
	if _overlay is PauseOverlay:
		_overlay.close()
		_overlay = null
		if paused:
			toggle_pause()


## For capture tooling: end the match now as a win or a loss.
func force_end(won: bool) -> void:
	_ended = true
	session.outcome = Session.Outcome.WON if won else Session.Outcome.LOST
	_show_result()


func _new_map() -> void:
	var c := config.duplicate()
	c["seed"] = randi_range(1, 999999)
	main.start_game(c)


func _set_overlay(o: Control) -> void:
	if _overlay != null:
		_overlay.close()
	_overlay = o
	(_hud["overlay_layer"] as CanvasLayer).add_child(o)


func _show_result() -> void:
	if not is_inside_tree():
		return
	var won := session.outcome == Session.Outcome.WON
	if main and main.audio:
		main.audio.play("win" if won else "lose", -2.0)
		main.audio.set_tension(0.0)
	var o := ResultOverlay.new()
	o.won = won
	o.stats = session.stats[HUMAN]
	o.history = session.history
	o.seconds = _game_seconds
	o.opponents = session.world.num_players - 1
	o.rematch.connect(func() -> void: main.start_game(config.duplicate()))
	o.new_map.connect(_new_map)
	o.main_menu.connect(func() -> void: main.goto_menu())
	_set_overlay(o)


func _on_send(sources: PackedInt32Array, destination: int) -> void:
	if session.queue_send(sources, destination, FRACTIONS[fraction_index]):
		if main and main.audio:
			var ships := session.estimate(sources, FRACTIONS[fraction_index])
			main.audio.play("whoosh", -4.0, clampf(1.25 - log(float(maxi(ships, 1))) / 12.0, 0.8, 1.2))
		map_view.you_marker = minf(map_view.you_marker, 1.0)
		if not _sent_once:
			_sent_once = true
			var tip: Control = _hud["tip"]
			create_tween().tween_property(tip, "modulate:a", 0.0, 0.6)


func _on_denied(_planet: int) -> void:
	UiKit.sound("deny")
	if main and main.audio:
		main.audio.play("deny", -6.0, 1.0, "UI")
	_flash_hint("that planet isn't yours: start from one of yours (blue)")


func _on_selection_changed() -> void:
	if not map_view.selection.is_empty() and main and main.audio:
		main.audio.play("select", -10.0, 1.0, "UI")


# --- HUD ----------------------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var overlay_layer := CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)
	_hud["overlay_layer"] = overlay_layer
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 28)
	layer.add_child(root)

	# top-left: every player's ships and a share bar
	var tl := PanelContainer.new()
	tl.theme_type_variation = "ChipPanel"
	tl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(tl)
	var tl_col := VBoxContainer.new()
	tl_col.add_theme_constant_override("separation", 6)
	tl.add_child(tl_col)
	var totals := HBoxContainer.new()
	totals.add_theme_constant_override("separation", 22)
	tl_col.add_child(totals)
	var labels: Array = [null]
	for p in range(1, session.world.num_players + 1):
		var l := UiKit.label("", "ShipCountLabel")
		l.add_theme_color_override("font_color", Palette.player_color(p))
		l.tooltip_text = "you" if p == HUMAN else "%s bot" % session.config["bot"]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		totals.add_child(l)
		labels.append(l)
	_hud["totals"] = labels
	var bar := ShareBar.new()
	bar.custom_minimum_size = Vector2(0, 4)
	tl_col.add_child(bar)
	_hud["share"] = bar

	# top-right: clock, speed, pause, menu
	var tr := PanelContainer.new()
	tr.theme_type_variation = "ChipPanel"
	tr.size_flags_horizontal = Control.SIZE_SHRINK_END
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(tr)
	var tr_row := HBoxContainer.new()
	tr_row.add_theme_constant_override("separation", 4)
	tr.add_child(tr_row)
	var clock := UiKit.label("0:00", "CaptionLabel")
	clock.custom_minimum_size = Vector2(64, 0)
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr_row.add_child(clock)
	_hud["clock"] = clock
	var slower := UiKit.button("–", "GhostButton")
	slower.custom_minimum_size = Vector2(52, 48)
	slower.tooltip_text = "slower  ( - )"
	slower.pressed.connect(func() -> void: set_speed(speed_index - 1))
	tr_row.add_child(slower)
	var speed := UiKit.label("1×", "ShipCountLabel")
	speed.custom_minimum_size = Vector2(52, 0)
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tr_row.add_child(speed)
	_hud["speed"] = speed
	var faster := UiKit.button("+", "GhostButton")
	faster.custom_minimum_size = Vector2(52, 48)
	faster.tooltip_text = "faster  ( + )"
	faster.pressed.connect(func() -> void: set_speed(speed_index + 1))
	tr_row.add_child(faster)
	var pause_button := UiKit.button("PAUSE")
	pause_button.custom_minimum_size = Vector2(124, 48)
	pause_button.tooltip_text = "pause  ( space )"
	pause_button.pressed.connect(toggle_pause)
	tr_row.add_child(pause_button)
	_hud["pause_button"] = pause_button
	var menu := UiKit.button("≡", "GhostButton")
	menu.custom_minimum_size = Vector2(52, 48)
	menu.tooltip_text = "menu  ( esc )"
	menu.pressed.connect(open_pause)
	tr_row.add_child(menu)

	# bottom-centre: contextual hint above the send share
	var bottom_col := VBoxContainer.new()
	bottom_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_col.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_col.add_theme_constant_override("separation", 10)
	root.add_child(bottom_col)
	var hint := UiKit.label("", "HintLabel")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Palette.MIST)
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_shadow_color", Color(Palette.VOID, 0.8))
	hint.add_theme_constant_override("shadow_outline_size", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_col.add_child(hint)
	_hud["hint"] = hint
	_hud["hint_flash"] = 0.0
	_hud["hint_text"] = ""
	var bottom := PanelContainer.new()
	bottom.theme_type_variation = "ChipPanel"
	bottom.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom_col.add_child(bottom)
	var b_row := HBoxContainer.new()
	b_row.add_theme_constant_override("separation", 6)
	bottom.add_child(b_row)
	var send_label := UiKit.label("   send ", "CaptionLabel")
	b_row.add_child(send_label)
	var group := ButtonGroup.new()
	for i in range(FRACTIONS.size()):
		var b := Button.new()
		b.text = "%d%%" % int(FRACTIONS[i] * 100)
		b.theme_type_variation = "ChipButton"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(86, 48)
		b.tooltip_text = "send %d%% of each planet's ships  ( %d )" % [int(FRACTIONS[i] * 100), i + 1]
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		b.pressed.connect(func() -> void: set_fraction(idx))
		UiKit.juice(b)
		b_row.add_child(b)
		_fraction_buttons.append(b)
	set_fraction(fraction_index)

	# top-centre: paused banner and first-game tip
	var top_center := VBoxContainer.new()
	top_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_center.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_theme_constant_override("separation", 10)
	root.add_child(top_center)
	var banner := PanelContainer.new()
	banner.theme_type_variation = "ChipPanel"
	banner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(UiKit.label("   PAUSED   ", "HeadingLabel"))
	banner.modulate.a = 0.0
	top_center.add_child(banner)
	_hud["banner"] = banner
	var tip := UiKit.label("you are blue  ·  drag from your planet to another to send ships  ·  take them all to win", "SubtitleLabel")
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_color_override("font_color", Palette.ICE)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_child(tip)
	_hud["tip"] = tip
	if _demo_bot != null or session.autopilot != null:
		tip.modulate.a = 0.0
		_sent_once = true
	else:
		UiKit.stagger_in([tip], 0.6, 0.0, 0.6)
	UiKit.stagger_in([tl, tr, bottom_col], 0.1, 0.06)


func _update_hud(delta: float) -> void:
	var labels: Array = _hud["totals"]
	var k := 1.0 - exp(-delta / 0.07)
	var bar: Control = _hud["share"]
	var values := PackedFloat32Array()
	values.resize(session.world.num_players + 1)
	var totals := session.totals()
	for p in range(1, session.world.num_players + 1):
		_shown_totals[p] = lerpf(_shown_totals[p], float(totals[p]), k)
		values[p] = _shown_totals[p]
		var l: Label = labels[p]
		l.text = ("● you %d" if p == HUMAN else "● %d") % int(round(_shown_totals[p]))
		l.modulate.a = 1.0 if totals[p] > 0 else 0.3
	bar.set("values", values)
	bar.queue_redraw()
	var t := int(_game_seconds)
	(_hud["clock"] as Label).text = "%d:%02d" % [t / 60, t % 60]
	(_hud["speed"] as Label).text = SPEED_LABELS[speed_index]
	var hint: Label = _hud["hint"]
	_hud["hint_flash"] = float(_hud["hint_flash"]) - delta
	hint.text = _hud["hint_text"] if float(_hud["hint_flash"]) > 0.0 else _hint()


func _hint() -> String:
	var pct := int(FRACTIONS[fraction_index] * 100)
	if map_view.is_dragging():
		return "release on a planet to send %d ships  ·  right-click cancels" % map_view.estimate_ships
	if map_view.is_boxing():
		return "release to select every planet of yours inside the box"
	var n := map_view.selection.size()
	if n > 0:
		return "%d selected  ·  click a target to send %d ships (%d%%)  ·  keys 1–4 change the share  ·  right-click cancels" % [n, map_view.estimate_ships, pct]
	if not _sent_once:
		return "click one of your planets, then click a target  ·  or drag between them"
	return "click or drag from your planets  ·  double-click selects all  ·  space pauses  ·  scroll zooms"


func _flash_hint(text: String) -> void:
	_hud["hint_text"] = text
	_hud["hint_flash"] = 2.5


func _pulse(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- demo driver: a fake cursor plays the human seat through the real UI path -----------------

func _demo_process(delta: float) -> void:
	if paused or _ended:
		return
	var w := session.world
	match str(_demo.get("phase", "idle")):
		"idle":
			_demo_wait -= delta
			if _demo_wait > 0.0:
				return
			var orders: Array = _demo_bot.decide(w, HUMAN)
			if orders.is_empty():
				_demo_wait = 0.4
				return
			var best: Variant = orders[0]
			for o in orders:
				if o.ships > best.ships:
					best = o
			var from := map_view.ghost_cursor
			if from == Vector2.INF:
				from = map_view.planet_pos(best.source) + Vector2(140, 90)
			_demo = {"phase": "approach", "src": best.source, "dst": best.destination, "ships": best.ships, "t": 0.0, "from": from}
		"approach":
			_demo["t"] = float(_demo["t"]) + delta / 0.45
			var e := _ease(float(_demo["t"]))
			map_view.ghost_cursor = (_demo["from"] as Vector2).lerp(map_view.planet_pos(int(_demo["src"])), e)
			if float(_demo["t"]) >= 1.0:
				if w.planets[int(_demo["src"])].owner != HUMAN:
					_demo = {}
					return
				map_view.selection = PackedInt32Array([int(_demo["src"])])
				var have: int = w.planets[int(_demo["src"])].ships
				var idx := FRACTIONS.size() - 1
				for i in range(FRACTIONS.size()):
					if have > 0 and int(floor(have * FRACTIONS[i])) >= int(_demo["ships"]):
						idx = i
						break
				set_fraction(idx)
				_demo["phase"] = "drag"
				_demo["t"] = 0.0
		"drag":
			_demo["t"] = float(_demo["t"]) + delta / 0.6
			var e2 := _ease(float(_demo["t"]))
			var a := map_view.planet_pos(int(_demo["src"]))
			var b := map_view.planet_pos(int(_demo["dst"]))
			map_view.demo_drag(PackedInt32Array([int(_demo["src"])]), a.lerp(b, e2))
			if float(_demo["t"]) >= 1.0:
				map_view.demo_release()
				_on_send(PackedInt32Array([int(_demo["src"])]), int(_demo["dst"]))
				_demo = {}
				_demo_wait = _rng.randf_range(0.5, 1.2)


static func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
