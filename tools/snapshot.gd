## Render the static design scenes to docs/design/*.png.
##
##   godot --path . -s tools/snapshot.gd        (needs a display; not --headless)
##
## Used for the Iteration 0 sign-off and by `make design`. Each scene is added to
## the root, given a few frames to lay out, captured from the root viewport, freed.
extends SceneTree

const OUT_DIR := "res://docs/design"
const SCENES := {
	"main_menu": "res://game/ui/main_menu_static.tscn",
	"game_screen": "res://game/ui/game_screen_mock.tscn",
}


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for name in SCENES:
		var packed: PackedScene = load(SCENES[name])
		var scene := packed.instantiate()
		root.add_child(scene)
		for i in range(6):
			await process_frame
		var image := root.get_texture().get_image()
		var path := "%s/%s.png" % [OUT_DIR, name]
		var err := image.save_png(path)
		print("snapshot: %s -> %s (%dx%d) %s" % [name, path, image.get_width(), image.get_height(), "ok" if err == OK else error_string(err)])
		scene.queue_free()
		await process_frame
	quit(0)
