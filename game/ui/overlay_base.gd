## Base for modal overlays: dims the game, centres a glass panel, fades and slides it in.
extends Control

const Palette := preload("res://game/theme/palette.gd")
const UiKit := preload("res://game/ui/ui_kit.gd")

var panel: PanelContainer
var column: VBoxContainer
var _dim: ColorRect


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(Palette.VOID, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)


func _ready() -> void:
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.97, 0.97)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func close() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_inside_tree():
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
