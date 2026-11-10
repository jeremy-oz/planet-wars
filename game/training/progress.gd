## Training progress on this computer: best stars per level, in user://progress.cfg.
## Nothing leaves the machine. The first level is always open; each win opens the next.
extends RefCounted

const Levels := preload("res://game/training/levels.gd")
const DEFAULT_PATH := "user://progress.cfg"

var path := DEFAULT_PATH
var _stars: Dictionary = {}  # level id -> best stars (1..3)
var _losses: Dictionary = {}  # level id -> losses in a row (reset by a win)


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for id in cfg.get_section_keys("stars") if cfg.has_section("stars") else PackedStringArray():
			_stars[id] = clampi(int(cfg.get_value("stars", id, 0)), 0, 3)
		for id in cfg.get_section_keys("losses") if cfg.has_section("losses") else PackedStringArray():
			_losses[id] = maxi(int(cfg.get_value("losses", id, 0)), 0)


func stars(id: String) -> int:
	return int(_stars.get(id, 0))


func total_stars() -> int:
	var n := 0
	for v in _stars.values():
		n += int(v)
	return n


func is_unlocked(i: int) -> bool:
	return i == 0 or (i > 0 and i < Levels.count() and stars(Levels.LEVELS[i - 1]["id"]) > 0)


## First level not yet won (or the last level), for "continue".
func next_level() -> int:
	for i in range(Levels.count()):
		if stars(Levels.LEVELS[i]["id"]) == 0:
			return i
	return Levels.count() - 1


## Losses in a row on this level (the easier retry appears at Levels.ASSIST_LOSSES).
func losses(id: String) -> int:
	return int(_losses.get(id, 0))


## Record a finished match (`earned` 0 = a loss). Keeps the best stars; a loss adds to the losing
## streak and a win clears it. Returns true if the best improved.
func record(id: String, earned: int) -> bool:
	if earned <= 0:
		_losses[id] = losses(id) + 1
	else:
		_losses.erase(id)
	var improved := earned > stars(id)
	if improved:
		_stars[id] = earned
	var cfg := ConfigFile.new()
	for k in _stars:
		cfg.set_value("stars", k, _stars[k])
	for k in _losses:
		cfg.set_value("losses", k, _losses[k])
	cfg.save(path)
	return improved
