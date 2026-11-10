## Volume sliders and window mode. Changes apply live; BACK or Esc closes.
extends "res://game/ui/overlay_base.gd"

signal closed

const SoundIcon := preload("res://game/ui/sound_icon.gd")

var main: Node
var _unmuted := {}  # key -> volume before muting from the icon


func _ready() -> void:
	column.add_child(UiKit.label("SETTINGS", "HeadingLabel"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	for row: Array in [["music", "Music"], ["sfx", "Effects"], ["ui", "Interface"]]:
		var key: String = row[0]
		var icon := SoundIcon.new()
		icon.kind = key
		grid.add_child(icon)
		var name_label := UiKit.label(row[1])
		name_label.custom_minimum_size = Vector2(120, 0)
		grid.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(300, 30)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE
		slider.value = float(main.settings[key]) if main else 0.7
		var value_label := UiKit.label("%d%%" % int(round(slider.value * 100.0)), "CaptionLabel")
		value_label.custom_minimum_size = Vector2(48, 0)
		icon.level = slider.value
		slider.value_changed.connect(func(v: float) -> void:
			icon.level = v
			_on_volume(key, v, value_label))
		icon.toggled.connect(func() -> void:
			if slider.value > 0.001:
				_unmuted[key] = slider.value
				slider.value = 0.0
			else:
				slider.value = float(_unmuted.get(key, 0.7))
			_preview(key))
		slider.drag_ended.connect(func(_changed: bool) -> void: _preview(key))
		grid.add_child(slider)
		grid.add_child(value_label)
	column.add_child(grid)
	var display_row := HBoxContainer.new()
	display_row.add_theme_constant_override("separation", 18)
	var display_gap := Control.new()
	display_gap.custom_minimum_size = Vector2(34, 0)
	display_row.add_child(display_gap)
	var dl := UiKit.label("Display")
	dl.custom_minimum_size = Vector2(120, 0)
	display_row.add_child(dl)
	var fullscreen: bool = bool(main.settings["fullscreen"]) if main else false
	display_row.add_child(UiKit.chips([["Window", false], ["Fullscreen", true]], fullscreen, _on_fullscreen))
	column.add_child(display_row)
	var back := UiKit.button("BACK", "PrimaryButton", 220.0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(close)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)
	column.add_child(back)
	super._ready()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	super.close()


func _on_volume(key: String, v: float, value_label: Label) -> void:
	value_label.text = "%d%%" % int(round(v * 100.0))
	if main:
		main.settings[key] = v
		main.apply_settings()


func _preview(key: String) -> void:
	if main == null or main.audio == null:
		return
	match key:
		"sfx":
			main.audio.chime(2)
		"ui":
			main.audio.play_ui("ui_click")


func _on_fullscreen(on: Variant) -> void:
	if main:
		main.settings["fullscreen"] = bool(on)
		main.apply_settings()
