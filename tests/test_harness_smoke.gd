## Proves the runner and assertion helpers work. Not a game test.
extends "res://tests/case.gd"


func test_assertions_pass() -> void:
	assert_true(true)
	assert_false(false)
	assert_eq(1 + 1, 2)
	assert_ne("a", "b")
	assert_almost_eq(0.1 + 0.2, 0.3, 1e-9)
	assert_null(null)
	assert_not_null(self)


func test_failures_are_recorded_not_thrown() -> void:
	var probe: RefCounted = load("res://tests/case.gd").new()
	probe._reset("probe")
	probe.assert_eq(1, 2, "deliberate")
	probe.assert_true(false)
	assert_eq(probe._failures.size(), 2)
	assert_true(probe._failures[0].contains("deliberate"))
