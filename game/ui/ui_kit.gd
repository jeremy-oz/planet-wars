## UI building blocks so every screen looks and moves the same (docs/STYLE_GUIDE.md §4–§5):
## pill buttons that lift on hover and dip on press, chip selectors, staggered entrances.
extends RefCounted

## The AudioDirector, set by Main. Null in headless tests, where sounds are skipped.
static var audio: Node = null


static func button(text: String, variation: String = "", min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_width, 52.0)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	juice(b)
	return b


static func juice(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void: _hover(b, true))
	b.mouse_exited.connect(func() -> void: _hover(b, false))
	b.button_down.connect(func() -> void: _scale_to(b, 0.96, 0.08))
	b.button_up.connect(func() -> void: _scale_to(b, 1.03 if b.is_hovered() else 1.0, 0.15))
	b.pressed.connect(func() -> void: sound("ui_click"))


static func label(text: String, variation: String = "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l


## A row of mutually exclusive chips. `options` is [[text, value], ...]; calls on_change(value).
static func chips(options: Array, selected: Variant, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for opt: Array in options:
		var b := Button.new()
		b.text = str(opt[0])
		b.theme_type_variation = "ChipButton"
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 44)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.button_pressed = opt[1] == selected
		var value: Variant = opt[1]
		b.pressed.connect(func() -> void: on_change.call(value))
		juice(b)
		row.add_child(b)
	return row


## Fade (and, outside containers, slide 12 px) nodes in one after another, 40 ms apart.
static func stagger_in(nodes: Array, start: float = 0.0, step: float = 0.04, duration: float = 0.3) -> void:
	for i in range(nodes.size()):
		var n: CanvasItem = nodes[i]
		n.modulate.a = 0.0
		var tw := n.create_tween().set_parallel(true)
		tw.tween_property(n, "modulate:a", 1.0, duration).set_delay(start + i * step).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if n is Control and not (n.get_parent() is Container):
			var c := n as Control
			var target := c.position
			c.position = target + Vector2(0, 12)
			tw.tween_property(c, "position", target, duration).set_delay(start + i * step).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func sound(sound_name: String) -> void:
	if audio != null and is_instance_valid(audio):
		audio.play_ui(sound_name)


static func _hover(b: BaseButton, on: bool) -> void:
	if b.disabled:
		return
	_scale_to(b, 1.03 if on else 1.0, 0.15)
	if on:
		sound("ui_hover")


static func _scale_to(c: Control, s: float, duration: float) -> void:
	if not c.is_inside_tree():
		return
	if c.has_meta("scale_tween"):
		var old: Tween = c.get_meta("scale_tween")
		if old != null and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	c.set_meta("scale_tween", tw)
