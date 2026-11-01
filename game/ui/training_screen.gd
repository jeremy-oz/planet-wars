## Training: our solar system. The nine levels as real worlds on an orbit out from the Sun;
## locked worlds are grey rock, won worlds wear your colour, the next one pulses.
## Click a world (or ←/→) to read its brief; LAUNCH or Enter to play; Esc goes back.
extends Control

const Palette := preload("res://game/theme/palette.gd")
const UiKit := preload("res://game/ui/ui_kit.gd")
const Starfield := preload("res://game/play/starfield.gd")
const PlanetRenderer := preload("res://game/fx/planet_renderer.gd")
const Bodies := preload("res://game/fx/bodies.gd")
const Textures := preload("res://game/fx/textures.gd")
const Levels := preload("res://game/training/levels.gd")
const Progress := preload("res://game/training/progress.gd")
const StarRow := preload("res://game/ui/star_row.gd")
const EXO := preload("res://game/fonts/Exo2-Variable.ttf")

## Rough relative sizes (px at 1080p): giants big, moons and Pluto small.
const SIZES := {"moon": 24.0, "mercury": 26.0, "venus": 34.0, "mars": 30.0, "jupiter": 58.0, "saturn": 50.0, "uranus": 40.0, "neptune": 40.0, "pluto": 20.0}

var main: Node
var progress: Progress
var selected := 0
var _worlds: PlanetRenderer
var _pos: Array[Vector2] = []
var _rad: Array[float] = []
var _hover := -1
var _time := 0.0
var _title: Label
var _brief: Label
var _meta: Label
var _stars: Control
var _launch: Button
var _font: FontVariation


func _ready() -> void:
	_fill_window()
	get_viewport().size_changed.connect(_fill_window)
	progress = main.progress if main and main.get("progress") != null else Progress.new()
	selected = progress.next_level()
	_font = FontVariation.new()
	_font.base_font = EXO
	_font.variation_opentype = {2003265652: 560}
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var sky := Starfield.new()
	sky.backdrop = "pillars-webb"
	bg.add_child(sky)
	_worlds = PlanetRenderer.new()
	add_child(_worlds)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 96)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	var back := UiKit.button("‹  BACK", "GhostButton", 120.0)
	back.pressed.connect(func() -> void: main.goto_menu())
	head.add_child(back)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -4)
	titles.add_child(UiKit.label("TRAINING", "HeadingLabel"))
	var sub := UiKit.label("our solar system  ·  %d of %d stars" % [progress.total_stars(), Levels.count() * 3], "CaptionLabel")
	titles.add_child(sub)
	head.add_child(titles)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(fill)

	# The brief for the selected world.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.custom_minimum_size = Vector2(760, 0)
	col.add_child(panel)
	var inner := MarginContainer.new()
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 32)
	for side in ["top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(inner)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	inner.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 4)
	row.add_child(text)
	_title = UiKit.label("", "HeadingLabel")
	_brief = UiKit.label("", "")
	_brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brief.custom_minimum_size = Vector2(440, 0)
	_meta = UiKit.label("", "CaptionLabel")
	text.add_child(_title)
	text.add_child(_brief)
	text.add_child(_meta)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	_stars = StarRow.new()
	_stars.star_size = 13.0
	right.add_child(_stars)
	_launch = UiKit.button("LAUNCH", "PrimaryButton", 190.0)
	_launch.pressed.connect(_play)
	right.add_child(_launch)

	UiKit.stagger_in([head, panel], 0.1, 0.1)
	_layout()
	_select(selected)
	if main and main.audio:
		main.audio.set_tension(0.0)


func _layout() -> void:
	var view := get_viewport_rect().size
	var k := view.y / 1080.0
	_pos.clear()
	_rad.clear()
	var n := Levels.count()
	for i in range(n):
		var t := float(i) / float(n - 1)
		var x := lerpf(view.x * 0.13, view.x * 0.9, t)
		var y := view.y * 0.44 + sin(t * PI * 1.1 - 0.4) * view.y * 0.07
		_pos.append(Vector2(x, y))
		_rad.append(float(SIZES.get(Levels.LEVELS[i]["body"], 30.0)) * k * 1.25)


func _process(delta: float) -> void:
	_time += delta
	var mouse := get_local_mouse_position()
	var h := -1
	for i in range(_pos.size()):
		if mouse.distance_to(_pos[i]) < _rad[i] + 22.0:
			h = i
	if h != _hover:
		_hover = h
		if h >= 0 and progress.is_unlocked(h):
			UiKit.sound("ui_hover")
	_update_worlds()
	queue_redraw()


func _update_worlds() -> void:
	var n := Levels.count()
	_worlds.resize(n)
	_worlds.set_view(1.0, false)
	for i in range(n):
		var lv: Dictionary = Levels.LEVELS[i]
		var won := progress.stars(lv["id"]) > 0
		var open := progress.is_unlocked(i)
		var flags := 0
		if i == selected:
			flags |= 1
		elif i == _hover and open:
			flags |= 2
		if not open:
			flags |= 8
		var c: Color = Palette.PLAYERS[1] if won else Color(0.86, 0.9, 1.0)
		var r := _rad[i] * (1.0 + 0.02 * sin(_time * 1.3 + i))
		_worlds.set_planet(i, _pos[i], r, r + 44.0, c, 0, flags, _time * 0.08 + i * 1.7, Bodies.layer(lv["body"]))


func _draw() -> void:
	var view := get_viewport_rect().size
	# The Sun, just off the left edge, and the path out through the system.
	var glow := Textures.glow()
	var sun := Vector2(-view.y * 0.16, view.y * 0.44)
	for s in [[view.y * 0.95, 0.10], [view.y * 0.5, 0.22], [view.y * 0.24, 0.5]]:
		draw_texture_rect(glow, Rect2(sun - Vector2(s[0], s[0]), Vector2(s[0], s[0]) * 2.0), false, Color(1.0, 0.82, 0.55, s[1]))
	for i in range(_pos.size() - 1):
		var a := _pos[i]
		var b := _pos[i + 1]
		var lit := progress.is_unlocked(i + 1)
		var steps := int(a.distance_to(b) / 14.0)
		for s in range(1, steps):
			var p := a.lerp(b, float(s) / float(steps))
			if p.distance_to(a) < _rad[i] + 16.0 or p.distance_to(b) < _rad[i + 1] + 16.0:
				continue
			draw_circle(p, 1.8 if lit else 1.3, Color(Palette.ICE if lit else Palette.DUSK, 0.55 if lit else 0.35), true, -1.0, true)
	for i in range(_pos.size()):
		var lv: Dictionary = Levels.LEVELS[i]
		var open := progress.is_unlocked(i)
		var name_text := str(lv["title"]).to_upper()
		var fs := 17
		var w := _font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var base := _pos[i] + Vector2(-w * 0.5, _rad[i] + 40.0)
		var col := Palette.ICE if open else Palette.DUSK
		draw_string(_font, base, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_string(_font, base + Vector2(w * 0.5 - 4.0, -_rad[i] * 2.0 - 64.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, 0.7))
		var earned := progress.stars(lv["id"])
		for k in range(3):
			var c := _pos[i] + Vector2((k - 1) * 17.0, _rad[i] + 60.0)
			draw_colored_polygon(StarRow.star_points(c, 7.0), StarRow.GOLD if k < earned else Color(Palette.MIST, 0.16 if open else 0.08))
		if not open:
			_draw_lock(base + Vector2(-14.0, -6.0))


func _draw_lock(c: Vector2) -> void:
	var body := Rect2(c + Vector2(-6, -3), Vector2(12, 9))
	draw_rect(body, Color(Palette.DUSK, 0.9))
	draw_arc(c + Vector2(0, -3), 4.0, PI, TAU, 12, Color(Palette.DUSK, 0.9), 1.6, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover >= 0:
			if _hover == selected and progress.is_unlocked(_hover) and (event as InputEventMouseButton).double_click:
				_play()
			else:
				_select(_hover)
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT, KEY_A:
			_select(maxi(selected - 1, 0))
		KEY_RIGHT, KEY_D:
			_select(mini(selected + 1, Levels.count() - 1))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_play()
		KEY_ESCAPE:
			main.goto_menu()
		_:
			return
	get_viewport().set_input_as_handled()


func _select(i: int) -> void:
	if i != selected:
		UiKit.sound("ui_click")
	selected = i
	var lv: Dictionary = Levels.LEVELS[i]
	var open := progress.is_unlocked(i)
	_title.text = "%d · %s" % [i + 1, lv["title"]]
	_brief.text = str(lv["brief"]) if open else "Locked: win %s first." % Levels.LEVELS[i - 1]["title"]
	var foes: int = lv["bots"].size()
	var planets: int = lv["map_text"].count("\nP ") if lv.has("map_text") else int(lv["planets"])
	var par: Array = lv["par"]
	_meta.text = "%d %s  ·  %d planets  ·  %s  ·  3 stars under %s, 2 under %s" % [foes, "opponent" if foes == 1 else "opponents", planets, lv["difficulty"], _clock(par[1]), _clock(par[0])]
	_stars.earned = progress.stars(lv["id"])
	_stars.queue_redraw()
	_launch.disabled = not open
	_launch.text = "LAUNCH" if progress.stars(lv["id"]) == 0 else "PLAY AGAIN"


func _play() -> void:
	if not progress.is_unlocked(selected):
		return
	main.start_game(Levels.config(selected))


static func _clock(s: Variant) -> String:
	var t := int(s)
	return "%d:%02d" % [t / 60, t % 60]


## Screens hang off Main (a plain Node), so anchors have no parent rect: size to the window directly.
func _fill_window() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if is_inside_tree():
		_layout()
