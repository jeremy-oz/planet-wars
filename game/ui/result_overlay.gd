## Win/lose screen with a short stats summary and the ships-over-time chart.
extends "res://game/ui/overlay_base.gd"

const HistoryChart := preload("res://game/ui/history_chart.gd")

signal rematch
signal new_map
signal main_menu

var won := false
var stats: Dictionary = {}  # the human's stats from Session
var history: Array = []
var seconds := 0.0
var opponents := 1


func _ready() -> void:
	var title := UiKit.label("VICTORY" if won else "DEFEAT", "TitleLabel")
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Palette.PLAYERS[1] if won else Palette.MIST)
	column.add_child(title)
	var who := "opponent" if opponents == 1 else "opponents"
	var line := ("you outlasted %d %s in %s" % [opponents, who, _clock(seconds)]) if won else ("you held on for %s" % _clock(seconds))
	column.add_child(UiKit.label(line, "SubtitleLabel"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 0)
	var cells := [
		[str(stats.get("captured", 0)), "planets taken"],
		[str(stats.get("peak_planets", 0)), "peak planets"],
		[str(stats.get("produced", 0)), "ships grown"],
		[str(stats.get("fleets", 0)), "fleets sent"],
		[str(stats.get("lost", 0)), "planets lost"],
	]
	var cell_nodes: Array = []
	for c: Array in cells:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.add_child(UiKit.label(c[0], "HeadingLabel"))
		v.add_child(UiKit.label(c[1], "CaptionLabel"))
		grid.add_child(v)
		cell_nodes.append(v)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	column.add_child(spacer)
	column.add_child(grid)
	var chart := HistoryChart.new()
	chart.history = history
	chart.custom_minimum_size = Vector2(620, 120)
	column.add_child(UiKit.label("ships over time", "CaptionLabel"))
	column.add_child(chart)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var items := [["MAIN MENU", "GhostButton", main_menu], ["REMATCH", "", rematch], ["NEW MAP", "PrimaryButton", new_map]]
	var buttons: Array = []
	for it: Array in items:
		var b := UiKit.button(it[0], it[1], 190.0)
		var sig: Signal = it[2]
		b.pressed.connect(func() -> void: sig.emit())
		row.add_child(b)
		buttons.append(b)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	column.add_child(row)
	super._ready()
	UiKit.stagger_in(cell_nodes, 0.15, 0.06)
	UiKit.stagger_in(buttons, 0.4)


static func _clock(s: float) -> String:
	var t := int(s)
	return "%d:%02d" % [t / 60, t % 60]
