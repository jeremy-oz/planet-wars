## Pause menu. Esc or RESUME closes it.
extends "res://game/ui/overlay_base.gd"

signal resume
signal restart
signal new_map
signal settings
signal main_menu


func _ready() -> void:
	column.add_child(UiKit.label("PAUSED", "HeadingLabel"))
	column.add_child(UiKit.label("the war waits for you", "CaptionLabel"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	column.add_child(gap)
	var items := [["RESUME", "PrimaryButton", resume], ["RESTART", "", restart], ["NEW MAP", "", new_map], ["SETTINGS", "", settings], ["MAIN MENU", "GhostButton", main_menu]]
	var buttons: Array = []
	for it: Array in items:
		var b := UiKit.button(it[0], it[1], 300.0)
		var sig: Signal = it[2]
		b.pressed.connect(func() -> void: sig.emit())
		column.add_child(b)
		buttons.append(b)
	super._ready()
	UiKit.stagger_in(buttons, 0.05)
