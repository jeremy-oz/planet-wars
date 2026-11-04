## Click rules (docs/STYLE_GUIDE.md §5): a click on your own planet always selects it, a click on
## any other planet sends the selection there, and a send clears the selection. Nothing depends on
## what was selected before, so the same click never means "pick a source" one time and "send
## here" the next. Reinforcing your own planet is a drag.
extends "res://tests/case.gd"

const MapView := preload("res://game/play/map_view.gd")
const MapText := preload("res://sim/map_text.gd")
const World := preload("res://sim/world.gd")

var view: Node2D
var sends: Array = []


func before_each() -> void:
	var w: World = MapText.parse("# players: 2\nP 4 10 1 30 3\nP 10 6 1 10 1\nP 10 14 1 10 1\nP 16 10 0 5 1\nP 26 10 2 30 3\n")
	assert_not_null(w, "test map parses")
	view = MapView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.bind(w)
	sends = []
	view.send_requested.connect(func(s: PackedInt32Array, d: int) -> void: sends.append([s, d]))


func after_each() -> void:
	view.free()


func test_clicking_own_planet_selects_it() -> void:
	view.click_planet(0, false)
	assert_eq(view.selection, PackedInt32Array([0]))
	assert_eq(sends.size(), 0)


func test_clicking_another_own_planet_switches_the_source_and_sends_nothing() -> void:
	view.click_planet(0, false)
	view.click_planet(1, false)
	assert_eq(view.selection, PackedInt32Array([1]), "the new planet becomes the source")
	assert_eq(sends.size(), 0, "no ships move between your own planets on a click")


func test_clicking_a_target_sends_and_clears_the_selection() -> void:
	view.click_planet(1, false)
	view.click_planet(3, false)
	assert_eq(sends.size(), 1)
	assert_eq(sends[0][0], PackedInt32Array([1]))
	assert_eq(sends[0][1], 3)
	assert_true(view.selection.is_empty(), "after a send the next click starts fresh")
	view.click_planet(2, false)
	assert_eq(view.selection, PackedInt32Array([2]), "so the next own planet is a source again")
	assert_eq(sends.size(), 1)


func test_clicking_the_selected_planet_again_deselects_it() -> void:
	view.click_planet(0, false)
	view.click_planet(0, false)
	assert_true(view.selection.is_empty())


func test_shift_click_adds_and_removes_sources() -> void:
	view.click_planet(0, false)
	view.click_planet(1, true)
	assert_eq(view.selection, PackedInt32Array([0, 1]))
	view.click_planet(0, true)
	assert_eq(view.selection, PackedInt32Array([1]))
	view.click_planet(4, false)
	assert_eq(sends.size(), 1)
	assert_eq(sends[0][0], PackedInt32Array([1]))


func test_clicking_a_target_with_nothing_selected_sends_nothing() -> void:
	view.click_planet(4, false)
	assert_eq(sends.size(), 0)
	assert_true(view.selection.is_empty())


func test_clicking_empty_space_clears_the_selection() -> void:
	view.click_planet(0, false)
	view.click_planet(-1, false)
	assert_true(view.selection.is_empty())


func test_dragging_onto_your_own_planet_reinforces_it() -> void:
	view.demo_drag(PackedInt32Array([0]), view.planet_pos(1))
	view.finish_drag()
	assert_eq(sends.size(), 1)
	assert_eq(sends[0][1], 1)
	assert_true(view.selection.is_empty(), "a drag-send leaves nothing selected either")
