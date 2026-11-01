## Base class for Planet Wars headless tests.
##
## Subclass with `extends "res://tests/case.gd"` and add methods whose
## names start with `test_`. Assertions record failures instead of aborting so
## one test can report several problems. No class_name on purpose: the runner
## must work on a fresh clone before Godot has built its class cache.
extends RefCounted

var _failures: PackedStringArray = []
var _current_test: String = ""


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func _reset(test_name: String) -> void:
	_current_test = test_name
	_failures = []


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("expected true" + _suffix(message))


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("expected false" + _suffix(message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail("expected %s, got %s%s" % [_repr(expected), _repr(actual), _suffix(message)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if actual == unexpected:
		fail("expected something other than %s%s" % [_repr(unexpected), _suffix(message)])


func assert_almost_eq(actual: float, expected: float, tolerance: float = 1e-6, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("expected %s ± %s, got %s%s" % [expected, tolerance, actual, _suffix(message)])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("expected null, got %s%s" % [_repr(value), _suffix(message)])


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("expected non-null" + _suffix(message))


func _suffix(message: String) -> String:
	return "" if message.is_empty() else " — " + message


func _repr(value: Variant) -> String:
	if value is String:
		return '"%s"' % value
	return str(value)
