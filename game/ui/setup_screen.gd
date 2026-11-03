## New game: opponents, bot, pace, difficulty, map size and seed, with a live preview of the map.
extends Control

const Palette := preload("res://game/theme/palette.gd")
const UiKit := preload("res://game/ui/ui_kit.gd")
const Session := preload("res://game/play/session.gd")
const MapView := preload("res://game/play/map_view.gd")
const Starfield := preload("res://game/play/starfield.gd")

const BOT_NOTES := {
	"random": "flails about — good for learning the controls",
	"nearest": "spreads to whatever is closest",
	"greedy": "picks the best-value targets and snowballs",
}
const PACE_NOTES := {
	"calm": "Calm: planets grow slowly and owned planets are shielded — plan one strong attack",
	"fast": "Fast: the arcade pace — planets grow quickly and change hands in seconds",
}

var main: Node
var config: Dictionary
var _preview: MapView
var _preview_holder: Node2D
var _bot_note: Label
var _pace_note: Label
var _seed_edit: LineEdit
var _time := 0.0


func _ready() -> void:
	_fill_window()
	get_viewport().size_changed.connect(_fill_window)
	config = Session.default_config()
	if main and not main.last_config.is_empty():
		config.merge(main.last_config, true)
	config["spectate"] = false
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	bg.add_child(Starfield.new())
	_preview_holder = Node2D.new()
	add_child(_preview_holder)
	_preview = MapView.new()
	_preview.interactive = false
	_preview_holder.add_child(_preview)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 64)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(panel)
	var inner := MarginContainer.new()
	for side in ["left", "right"]:
		inner.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	inner.add_child(col)
	col.add_child(UiKit.label("NEW GAME", "HeadingLabel"))
	var rows: Array = []
	rows.append(_row("Opponents", UiKit.chips([["1", 1], ["2", 2], ["3", 3]], int(config["opponents"]), _set_option.bind("opponents"))))
	rows.append(_row("Opponent", UiKit.chips([["Random", "random"], ["Nearest", "nearest"], ["Greedy", "greedy"]], config["bot"], _set_option.bind("bot"))))
	_bot_note = UiKit.label("", "CaptionLabel")
	rows.append(_bot_note)
	rows.append(_row("Pace", UiKit.chips([["Calm", "calm"], ["Fast", "fast"]], config.get("pace", Session.DEFAULT_PACE), _set_option.bind("pace"))))
	_pace_note = UiKit.label("", "CaptionLabel")
	rows.append(_pace_note)
	rows.append(_row("Difficulty", UiKit.chips([["Relaxed", "relaxed"], ["Normal", "normal"], ["Sharp", "sharp"]], config["difficulty"], _set_option.bind("difficulty"))))
	rows.append(_row("Map", UiKit.chips([["Small", "small"], ["Medium", "medium"], ["Large", "large"], ["Huge", "huge"]], config["map"], _set_option.bind("map"))))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(config["seed"])
	_seed_edit.custom_minimum_size = Vector2(170, 44)
	_seed_edit.max_length = 9
	_seed_edit.text_changed.connect(_on_seed_text)
	seed_row.add_child(_seed_edit)
	var dice := UiKit.button("NEW SEED", "GhostButton")
	dice.custom_minimum_size = Vector2(0, 44)
	dice.pressed.connect(_new_seed)
	seed_row.add_child(dice)
	rows.append(_row("Map seed", seed_row))
	for r in rows:
		col.add_child(r)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	col.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	var back := UiKit.button("BACK", "GhostButton", 160.0)
	back.pressed.connect(func() -> void: main.goto_menu())
	var start := UiKit.button("START", "PrimaryButton", 240.0)
	start.pressed.connect(_start)
	buttons.add_child(back)
	buttons.add_child(start)
	col.add_child(buttons)
	_refresh()
	UiKit.stagger_in([panel])
	UiKit.stagger_in(rows, 0.1)
	get_viewport().size_changed.connect(_fit_preview)


func _row(title: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := UiKit.label(title)
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	row.add_child(control)
	return row


func _process(delta: float) -> void:
	_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_start()
			KEY_ESCAPE:
				main.goto_menu()


func _set_option(value: Variant, key: String) -> void:
	config[key] = value
	_refresh()


func _on_seed_text(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != text:
		_seed_edit.text = digits
		_seed_edit.caret_column = digits.length()
	config["seed"] = int(digits) if digits != "" else 0
	_refresh()


func _new_seed() -> void:
	config["seed"] = randi_range(1, 999999)
	_seed_edit.text = str(config["seed"])
	_refresh()


func _refresh() -> void:
	var pace := str(config.get("pace", Session.DEFAULT_PACE))
	var think: float = Session.THINK_EVERY.get(config["difficulty"], 2) * float(Session.PACES[pace]["tick_seconds"])
	_bot_note.text = "%s · %s" % [BOT_NOTES.get(config["bot"], ""), "thinks every %.1f s" % think]
	_pace_note.text = PACE_NOTES.get(pace, "")
	var s := Session.new(config)
	_preview.bind(s.world)
	_fit_preview()


func _fit_preview() -> void:
	var view := get_viewport_rect().size
	var region := Rect2(view.x * 0.5, view.y * 0.1, view.x * 0.46, view.y * 0.8)
	var rect := _preview.map_rect()
	var s := minf(region.size.x / rect.size.x, region.size.y / rect.size.y)
	_preview_holder.scale = Vector2(s, s)
	_preview_holder.position = region.get_center() - rect.get_center() * s
	_preview.screen_scale = s


func _start() -> void:
	main.start_game(config.duplicate())


## Screens hang off Main (a plain Node), so anchors have no parent rect: size to the window directly.
func _fill_window() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
