@tool
## Static backdrop for design mocks: starfield plus a few very soft nebula blobs. Seeded, so the
## same picture renders every time. Real gameplay backgrounds (Iteration 2) will parallax; this does not.
extends Node2D

const Palette := preload("res://game/theme/palette.gd")

@export var seed: int = 7
@export var stars: int = 420
@export var size: Vector2 = Vector2(1600, 900)
@export var nebulae: bool = true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.VOID)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if nebulae:
		var blobs := [
			[Vector2(size.x * 0.82, size.y * 0.18), 420.0, Palette.PLAYERS[1], 0.05],
			[Vector2(size.x * 0.2, size.y * 0.85), 380.0, Palette.PLAYERS[3], 0.045],
			[Vector2(size.x * 0.55, size.y * 0.55), 520.0, Palette.PLAYERS[4], 0.028],
		]
		for b in blobs:
			Palette.draw_glow(self, b[0], b[1] * 0.5, b[2], b[3], 2.0, 22)
	for i in range(stars):
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var mag := rng.randf()
		var r := 0.7 + mag * mag * 1.6
		var a := 0.15 + mag * 0.7
		var col := Palette.ICE if rng.randf() < 0.8 else Palette.MIST
		draw_circle(p, r, Color(col.r, col.g, col.b, a))
