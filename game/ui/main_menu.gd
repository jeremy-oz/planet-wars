## Animated main menu (signed-off design: docs/design/main_menu.png) with a live bot game on the right.
extends Control

const Palette := preload("res://game/theme/palette.gd")
const UiKit := preload("res://game/ui/ui_kit.gd")
const Session := preload("res://game/play/session.gd")
const MapView := preload("res://game/play/map_view.gd")
const Starfield := preload("res://game/play/starfield.gd")
const NearestBot := preload("res://sim/bots/nearest_bot.gd")

const DEMO_TICK := 0.3

var main: Node
var _demo: Session
var _view: MapView
var _holder: Node2D
var _acc := 0.0
var _restart_in := -1.0
var _demo_seed := 101


func _ready() -> void:
	_fill_window()
	get_viewport().size_changed.connect(_fill_window)
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	bg.add_child(Starfield.new())
	_holder = Node2D.new()
	add_child(_holder)
	_view = MapView.new()
	_view.interactive = false
	_holder.add_child(_view)
	_new_demo()
	_holder.modulate.a = 0.0
	create_tween().tween_property(_holder, "modulate:a", 0.9, 0.9).set_delay(0.3)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 128)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	var title := UiKit.label("PLANET WARS", "TitleLabel")
	var subtitle := UiKit.label("grow  ·  send  ·  win", "SubtitleLabel")
	col.add_child(title)
	col.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 72)
	col.add_child(spacer)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(buttons)
	var play := UiKit.button("PLAY", "PrimaryButton", 300.0)
	play.pressed.connect(func() -> void: main.goto_setup())
	var online := UiKit.button("PLAY ONLINE", "", 300.0)
	online.disabled = true
	online.tooltip_text = "Online play arrives in the next update."
	var settings := UiKit.button("SETTINGS", "", 300.0)
	settings.pressed.connect(func() -> void: main.open_settings())
	var quit := UiKit.button("QUIT", "GhostButton", 300.0)
	quit.pressed.connect(func() -> void: get_tree().quit())
	for b in [play, online, settings, quit]:
		buttons.add_child(b)
	var soon := UiKit.label("online play arrives in the next update", "CaptionLabel")
	soon.add_theme_color_override("font_color", Palette.DUSK)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)
	var footer := UiKit.label("v%s  ·  a game for friends  ·  no accounts, no tracking" % ProjectSettings.get_setting("application/config/version", "0"), "CaptionLabel")
	col.add_child(footer)
	UiKit.stagger_in([title, subtitle], 0.05, 0.08, 0.4)
	UiKit.stagger_in([play, online, settings, quit], 0.25)
	UiKit.stagger_in([footer], 0.5)
	get_viewport().size_changed.connect(_fit_demo)
	if main and main.audio:
		main.audio.set_tension(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			main.goto_setup()


func _process(delta: float) -> void:
	if _restart_in >= 0.0:
		_restart_in -= delta
		if _restart_in < 0.0:
			_demo_seed += 1
			_new_demo()
			create_tween().tween_property(_holder, "modulate:a", 0.9, 0.6)
		return
	_acc += delta / DEMO_TICK
	if _acc >= 1.0:
		_acc -= 1.0
		var events := _demo.step()
		_view.on_events(events)
		if _demo.outcome != Session.Outcome.PLAYING:
			_restart_in = 2.0
			create_tween().tween_property(_holder, "modulate:a", 0.0, 1.2).set_delay(0.8)
	_view.tick_fraction = _acc


func _new_demo() -> void:
	_demo = Session.new({"seed": _demo_seed, "opponents": 2, "bot": "greedy", "difficulty": "relaxed", "map": "small", "spectate": true, "max_ticks": 500})
	_demo.autopilot = NearestBot.new(_demo_seed)
	_view.bind(_demo.world)
	_acc = 0.0
	_fit_demo()


func _fit_demo() -> void:
	var view := get_viewport_rect().size
	var region := Rect2(view.x * 0.47, view.y * 0.12, view.x * 0.48, view.y * 0.76)
	var rect := _view.map_rect()
	var s := minf(region.size.x / rect.size.x, region.size.y / rect.size.y)
	_holder.scale = Vector2(s, s)
	_holder.position = region.get_center() - rect.get_center() * s
	_view.screen_scale = s


## Screens hang off Main (a plain Node), so anchors have no parent rect: size to the window directly.
func _fill_window() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
