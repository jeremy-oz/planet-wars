@tool
## Decorative planet cluster for the main menu mock: three owned planets and two neutrals with a
## fleet in flight, so the menu already shows what the game is.
extends Node2D

const Palette := preload("res://game/theme/palette.gd")


func _draw() -> void:
	var a := Vector2(0, 0)
	var b := Vector2(340, -150)
	var c := Vector2(230, 190)
	var n1 := Vector2(-150, 180)
	var n2 := Vector2(120, -230)
	Palette.draw_fleet(self, a, b, 60, 1, 0.62, 3)
	Palette.draw_planet(self, n1, 2, 0, 0.0)
	Palette.draw_planet(self, n2, 1, 0, 0.0)
	Palette.draw_planet(self, c, 3, 2, 0.4)
	Palette.draw_planet(self, b, 2, 3, 0.75)
	Palette.draw_planet(self, a, 5, 1, 0.55, true)
