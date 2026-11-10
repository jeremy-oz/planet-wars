## Ships over time for every player: the "how the game went" line chart on the result screen.
extends Control

const Palette := preload("res://game/theme/palette.gd")

var history: Array = []  # PackedInt32Array per tick
var highlight := 1


func _draw() -> void:
	draw_line(Vector2(0, size.y), Vector2(size.x, size.y), Color(Palette.RIM, 0.9), 1.0)
	if history.size() < 2:
		return
	var players: int = (history[0] as PackedInt32Array).size() - 1
	var peak := 1
	for row: PackedInt32Array in history:
		for p in range(1, row.size()):
			peak = maxi(peak, row[p])
	var samples := mini(history.size(), int(size.x / 3.0))
	for p in range(players, 0, -1):
		var pts := PackedVector2Array()
		for k in range(samples):
			var idx := int(round(float(k) / float(samples - 1) * float(history.size() - 1)))
			var v: int = (history[idx] as PackedInt32Array)[p]
			pts.append(Vector2(size.x * k / float(samples - 1), size.y - size.y * float(v) / float(peak)))
		var c := Palette.player_color(p)
		if p == highlight:
			var fill := pts.duplicate()
			fill.append(Vector2(size.x, size.y))
			fill.append(Vector2(0, size.y))
			draw_colored_polygon(fill, Color(c, 0.12))
			draw_polyline(pts, c, 3.0, true)
		else:
			draw_polyline(pts, Color(c, 0.75), 1.5, true)
