## A row of three stars (training results and the solar-system map). Drawn, not a font glyph,
## so it looks the same everywhere. Earned stars pop in one after another when `animate` is set.
extends Control

const Palette := preload("res://game/theme/palette.gd")
const GOLD := Color("#FFD27A")

var earned := 0
var star_size := 14.0
var animate := false
var _shown := PackedFloat32Array([1.0, 1.0, 1.0])
var _t := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(star_size * 2.0 * 3.0 + star_size * 0.8 * 2.0, star_size * 2.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if animate:
		_shown = PackedFloat32Array([0.0, 0.0, 0.0])


func _process(delta: float) -> void:
	if not animate:
		return
	_t += delta
	for i in range(3):
		_shown[i] = clampf((_t - 0.35 - 0.28 * i) / 0.3, 0.0, 1.0)
	queue_redraw()


static func star_points(centre: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in range(10):
		var a := -PI / 2.0 + PI * float(k) / 5.0
		pts.append(centre + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	return pts


func _draw() -> void:
	var gap := star_size * 0.8
	var x0 := (size.x - (star_size * 6.0 + gap * 2.0)) * 0.5 + star_size
	for i in range(3):
		var c := Vector2(x0 + i * (star_size * 2.0 + gap), size.y * 0.5)
		var e := _shown[i]
		draw_colored_polygon(star_points(c, star_size), Color(Palette.MIST, 0.18))
		if i < earned and e > 0.0:
			var pop := 1.0 + 0.35 * sin(e * PI) * (1.0 - e * 0.5)
			draw_colored_polygon(star_points(c, star_size * e * pop), GOLD)
