@tool
## Static game-screen mock: a hand-placed 16-planet map mid-game, drawn with the shared palette
## primitives. No simulation here — numbers are made up to look like turn ~200 of a 4-player game.
extends Node2D

const Palette := preload("res://game/theme/palette.gd")

# [position, growth, owner, growth_progress, ships, selected, hovered]
const PLANETS := [
	[Vector2(250, 220), 5, 1, 0.62, 148, true, false],
	[Vector2(430, 420), 3, 1, 0.3, 41, false, false],
	[Vector2(300, 640), 2, 1, 0.8, 22, false, false],
	[Vector2(1350, 230), 5, 2, 0.45, 131, false, false],
	[Vector2(1180, 450), 3, 2, 0.1, 57, false, false],
	[Vector2(1390, 620), 1, 2, 0.9, 9, false, false],
	[Vector2(820, 150), 4, 3, 0.5, 88, false, false],
	[Vector2(640, 300), 2, 3, 0.2, 19, false, false],
	[Vector2(760, 680), 4, 4, 0.7, 103, false, false],
	[Vector2(1020, 620), 2, 4, 0.35, 27, false, false],
	[Vector2(800, 460), 5, 0, 0.0, 95, false, true],
	[Vector2(560, 560), 1, 0, 0.0, 12, false, false],
	[Vector2(1020, 310), 2, 0, 0.0, 33, false, false],
	[Vector2(1200, 800), 3, 0, 0.0, 58, false, false],
	[Vector2(470, 800), 1, 0, 0.0, 8, false, false],
	[Vector2(1550, 420), 2, 0, 0.0, 24, false, false],
]

# [from index, to index, ships, owner, progress]
const FLEETS := [
	[0, 10, 70, 1, 0.55],
	[3, 12, 40, 2, 0.4],
	[6, 7, 25, 3, 0.8],
	[8, 13, 48, 4, 0.3],
	[4, 10, 30, 2, 0.2],
]

var _font: Font


func _draw() -> void:
	if _font == null:
		_font = load("res://game/fonts/Exo2-Variable.ttf")
	# target line from the selected planet to the hovered one (drag in progress)
	var sel: Vector2 = PLANETS[0][0]
	var hov: Vector2 = PLANETS[10][0]
	draw_line(sel, hov, Color(Palette.ICE.r, Palette.ICE.g, Palette.ICE.b, 0.35), 2.0, true)
	draw_circle(hov, 6.0, Color(Palette.ICE.r, Palette.ICE.g, Palette.ICE.b, 0.6))
	for f in FLEETS:
		Palette.draw_fleet(self, PLANETS[f[0]][0], PLANETS[f[1]][0], f[2], f[3], f[4], f[0] * 7 + f[1])
	for p in PLANETS:
		Palette.draw_planet(self, p[0], p[1], p[2], p[3], p[5], p[6])
	for p in PLANETS:
		var pos: Vector2 = p[0]
		var r := Palette.planet_radius(p[1])
		var text := str(p[4])
		var fsize := int(clampf(16.0 + r * 0.25, 16.0, 30.0))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize).x
		var col := Palette.ICE if p[2] != 0 else Palette.MIST
		draw_string(_font, pos + Vector2(-w / 2.0, fsize * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
