## Headless test runner.
##
##   godot --headless --path . -s tests/run_tests.gd
##
## Discovers every `res://tests/**/test_*.gd`, instantiates it, and calls each
## `test_*` method. Exit code 0 when everything passes, 1 otherwise. An empty
## suite passes. Output is plain text so CI logs stay readable.
extends SceneTree

const TEST_ROOT := "res://tests"
const TestCase := preload("res://tests/case.gd")


func _initialize() -> void:
	# _run() returns null if a script error aborts it; never hang CI on that.
	var code = _run()
	if code == null:
		print("run_tests: runner aborted by a script error (see above)")
		code = 2
	quit(code)


func _run() -> int:
	var started := Time.get_ticks_msec()
	var files := _discover(TEST_ROOT)
	files.sort()
	var passed := 0
	var failed := 0
	var failures: PackedStringArray = []

	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL ", path.trim_prefix("res://"), " (does not parse)")
			failures.append("%s: script does not parse or cannot be instantiated" % path)
			continue
		var instance: Variant = script.new()
		if not (instance is TestCase):
			continue
		var case: TestCase = instance
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			case._reset(name)
			case.before_each()
			case.call(name)
			case.after_each()
			var label := "%s::%s" % [path.trim_prefix("res://"), name]
			if case._failures.is_empty():
				passed += 1
				print("  ok   ", label)
			else:
				failed += 1
				print("  FAIL ", label)
				for f in case._failures:
					print("       ", f)
					failures.append("%s: %s" % [label, f])

	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("")
	print("%d test file(s), %d passed, %d failed in %.2fs" % [files.size(), passed, failed, elapsed])
	if failed > 0:
		print("")
		print("Failures:")
		for f in failures:
			print("  ", f)
	return 0 if failed == 0 else 1


func _discover(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := root.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				found.append_array(_discover(full))
		elif entry.begins_with("test_") and entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found
