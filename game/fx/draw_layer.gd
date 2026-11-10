## A Node2D whose _draw delegates to a Callable, so one owner can paint several layers
## (each with its own blend material) from shared state.
extends Node2D

var painter: Callable


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)
