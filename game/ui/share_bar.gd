## Thin stacked bar: each player's share of all ships, in player colours. Values tween in the owner.
extends Control

const Palette := preload("res://game/theme/palette.gd")

var values := PackedFloat32Array()  # index = player, 0 unused


func _draw() -> void:
	var total := 0.0
	for i in range(1, values.size()):
		total += maxf(values[i], 0.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.RIM, 0.6))
	if total <= 0.0:
		return
	var x := 0.0
	for i in range(1, values.size()):
		var w := size.x * maxf(values[i], 0.0) / total
		if w > 0.5:
			draw_rect(Rect2(x, 0, maxf(w - 1.0, 0.5), size.y), Palette.player_color(i))
		x += w
