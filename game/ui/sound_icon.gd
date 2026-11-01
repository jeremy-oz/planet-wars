## Drawn icons for the volume sliders (owner survey, iteration 2, Q5): a note for music, a
## speaker for effects, a pointer for interface sounds. Sound waves follow the volume; at zero a
## cross shows it is muted. Clicking the icon mutes or restores that channel.
extends Control

const Palette := preload("res://game/theme/palette.gd")

signal toggled

var kind := "sfx"  # "music", "sfx" or "ui"
var level := 1.0:
	set(v):
		level = v
		queue_redraw()
var _hover := false


func _ready() -> void:
	custom_minimum_size = Vector2(34, 30)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "mute / unmute"
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggled.emit()
		accept_event()


func _draw() -> void:
	var c := Palette.ICE if _hover else Palette.MIST
	if level <= 0.001:
		c = Palette.DUSK
	var o := size * 0.5 + Vector2(-5, 0)
	match kind:
		"music":
			draw_circle(o + Vector2(-5, 7), 3.6, c, true, -1.0, true)
			draw_circle(o + Vector2(6, 5), 3.6, c, true, -1.0, true)
			draw_line(o + Vector2(-1.6, 7), o + Vector2(-1.6, -8), c, 2.0, true)
			draw_line(o + Vector2(9.4, 5), o + Vector2(9.4, -10), c, 2.0, true)
			draw_colored_polygon(PackedVector2Array([o + Vector2(-1.6, -8), o + Vector2(9.4, -10), o + Vector2(9.4, -6), o + Vector2(-1.6, -4)]), c)
		"sfx":
			draw_colored_polygon(PackedVector2Array([o + Vector2(-9, -4), o + Vector2(-4, -4), o + Vector2(2, -9), o + Vector2(2, 9), o + Vector2(-4, 4), o + Vector2(-9, 4)]), c)
		"ui":
			draw_colored_polygon(PackedVector2Array([o + Vector2(-7, -10), o + Vector2(5, 2), o + Vector2(-0.5, 2.5), o + Vector2(2.5, 9), o + Vector2(-0.5, 10), o + Vector2(-3.5, 4), o + Vector2(-7, 7)]), c)
	var wx := o + Vector2(7 if kind != "music" else 14, 0)
	if level <= 0.001:
		draw_line(wx + Vector2(0, -5), wx + Vector2(9, 4), c, 2.0, true)
		draw_line(wx + Vector2(0, 4), wx + Vector2(9, -5), c, 2.0, true)
	elif kind != "music":
		for k in range(3):
			if level > k / 3.0:
				draw_arc(wx + Vector2(-4, 0), 5.0 + k * 4.5, -0.85, 0.85, 10, c, 1.8, true)
