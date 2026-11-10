## The sky: a real Hubble/Webb photograph (game/art/backdrops, see CREDITS.md), dimmed so play
## stays readable, under parallax star layers. Star layers are drawn once into a 2×2 tile block;
## scrolling only moves the layer nodes.
extends Node2D

const BACKDROPS: PackedStringArray = ["cosmic-cliffs", "pillars-webb", "carina", "pillars-hubble", "whirlpool"]
## How bright the photo is drawn: enough to feel real, dark enough that planets and counts win.
const BACKDROP_TINT := Color(0.2, 0.21, 0.25)

const Palette := preload("res://game/theme/palette.gd")
const Textures := preload("res://game/fx/textures.gd")
const DrawLayer := preload("res://game/fx/draw_layer.gd")

const TILE := Vector2(2048, 1280)
## [parallax factor, stars per tile, min size px, max size px, peak alpha]; layer 0 is nebulae.
const LAYERS := [
	[0.02, 0, 0.0, 0.0, 0.0],
	[0.05, 700, 1.0, 1.8, 0.55],
	[0.12, 240, 1.4, 2.6, 0.75],
	[0.25, 60, 2.0, 3.4, 0.95],
]

@export var star_seed := 3
## Slow autonomous drift (px/s at the nearest layer) so the sky is never perfectly still.
var drift := Vector2(-6.0, -1.5)
var reduced := false
var _layers: Array = []
var _time := 0.0
var _camera := Vector2.ZERO
## Name from BACKDROPS (or "" for stars only). Set before the node enters the tree.
var backdrop := "cosmic-cliffs"
var _photo: Sprite2D


static func backdrop_for_seed(seed: int) -> String:
	return BACKDROPS[posmod(seed, BACKDROPS.size())]


func _ready() -> void:
	if backdrop != "":
		_photo = Sprite2D.new()
		_photo.texture = load("res://game/art/backdrops/%s.jpg" % backdrop)
		_photo.modulate = BACKDROP_TINT
		add_child(_photo)
	for i in range(LAYERS.size()):
		var layer := DrawLayer.new()
		if i == 0:
			layer.material = Textures.additive()
		layer.painter = _paint.bind(i)
		add_child(layer)
		_layers.append(layer)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	_apply()


## Screen-space camera position (world position × zoom).
func scroll(camera_screen_pos: Vector2) -> void:
	_camera = camera_screen_pos


func _apply() -> void:
	if _photo != null and _photo.texture != null:
		var view := get_viewport_rect().size
		var tex := _photo.texture.get_size()
		var cover := maxf(view.x / tex.x, view.y / tex.y) * 1.12
		_photo.scale = Vector2(cover, cover)
		var slack := (tex * cover - view) * 0.5
		var off := -_camera * 0.015 + (Vector2.ZERO if reduced else Vector2(sin(_time * 0.02), cos(_time * 0.017)) * 0.4 * slack)
		_photo.position = view * 0.5 + off.clamp(-slack, slack)
	for i in range(_layers.size()):
		var f: float = LAYERS[i][0]
		var off := -_camera * f + drift * _time * f * 4.0
		off = Vector2(fposmod(off.x, TILE.x), fposmod(off.y, TILE.y)) - TILE
		_layers[i].position = off


func _paint(ci: CanvasItem, i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed * 97 + i
	if i == 0:
		if backdrop != "":
			return
		var glow := Textures.glow()
		var tints := [Palette.PLAYERS[1], Palette.PLAYERS[3], Palette.PLAYERS[4], Palette.PLAYERS[1], Palette.PLAYERS[3]]
		var blobs: Array = []
		for k in range(5):
			blobs.append([Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y), rng.randf_range(380.0, 720.0), tints[k], rng.randf_range(0.05, 0.085)])
		for tx in range(2):
			for ty in range(2):
				for b: Array in blobs:
					var r: float = b[1]
					var p: Vector2 = b[0] + Vector2(tx, ty) * TILE
					var c: Color = b[2]
					ci.draw_texture_rect(glow, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c, b[3]))
		return
	var spec: Array = LAYERS[i]
	var dot := Textures.dot()
	var stars: Array = []
	for k in range(int(spec[1])):
		var mag := rng.randf()
		var s := lerpf(spec[2], spec[3], mag * mag)
		var col := Palette.ICE if rng.randf() < 0.82 else Palette.PLAYERS[1].lerp(Palette.ICE, 0.6)
		stars.append([Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y), s, Color(col, float(spec[4]) * (0.35 + 0.65 * mag))])
	for tx in range(2):
		for ty in range(2):
			for st: Array in stars:
				var s: float = st[1]
				var p: Vector2 = st[0] + Vector2(tx, ty) * TILE
				ci.draw_texture_rect(dot, Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), false, st[2])
