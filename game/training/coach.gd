## The training coach: a short lesson at the start of each world, then a live coach that watches
## the match and points at your best next move when you are in trouble or idle.
##
## Pure logic, no nodes: the game screen feeds it the world, your actions and game time, and draws
## what it returns (a card of text, rings around planets, a suggested-move arrow). The advice comes
## from sim/bots/coach_bot.gd, and tests/game/test_training.gd wins every world by following it at
## a person's pace, so "do what the arrow says" always works.
extends RefCounted

const World := preload("res://sim/world.gd")
const CoachBot := preload("res://sim/bots/coach_bot.gd")
const Levels := preload("res://game/training/levels.gd")

const HUMAN := 1
const IDLE_SECONDS := 6.0  ## no send for this long and a good move exists: point at it
const HINT_SECONDS := 8.0  ## a hint fades after this long (or as soon as you send)
const DEFEND_COOLDOWN := 6.0  ## seconds before warning about the same planet again
## Ships a planet adds per second for each growth level; the game screen sets it from the pace.
var growth_per_second := 4.0

var world: World
var names := PackedStringArray()  ## display name per planet ("Earth", "Io", ...)
var quiet := false  ## the last world: only danger warnings, no idle tips
var steps: Array = []  ## resolved lesson steps (see Levels "lesson")
var step := 0
var hint: Dictionary = {}  ## the live hint on screen, or {}
var last_send := 0.0
var _bot := CoachBot.new(0)
var _seconds := 0.0
var _hint_at := -100.0
var _warned: Dictionary = {}  # planet -> game seconds of the last defend warning


func _init(p_world: World, level: int, p_names: PackedStringArray) -> void:
	world = p_world
	names = p_names
	var lv: Dictionary = Levels.LEVELS[level]
	quiet = bool(lv.get("quiet_coach", false))
	var refs := _refs()
	for raw: Dictionary in lv.get("lesson", []):
		var s := raw.duplicate()
		s["text"] = _fill(str(raw["text"]), refs)
		s["focus"] = PackedInt32Array()
		for r: String in raw.get("focus", []):
			if refs.has(r):
				s["focus"].append(refs[r])
		var arrow: Array = raw.get("arrow", [])
		if arrow.size() == 2 and refs.has(arrow[0]) and refs.has(arrow[1]):
			s["sources"] = PackedInt32Array([refs[arrow[0]]])
			s["destination"] = refs[arrow[1]]
		steps.append(s)


## The lesson step on screen now, or {} (none left, or the next one is waiting for its moment).
func lesson() -> Dictionary:
	if step >= steps.size():
		return {}
	var s: Dictionary = steps[step]
	var after := str(s.get("after", ""))
	if after.begins_with("own:") and world.planet_count(HUMAN) < int(after.substr(4)):
		return {}
	return s


## While a lesson step is up the match waits for you (nothing moves).
func holding() -> bool:
	return not lesson().is_empty()


func lesson_progress() -> Vector2i:
	return Vector2i(mini(step + 1, steps.size()), steps.size())


## Tell the coach what you just did. `kind`: "ok" (GOT IT), "send", "select", "fraction", "speed".
## data: "sources" (PackedInt32Array) and "destination" for a send, "count" for a selection.
func on_action(kind: String, data: Dictionary = {}) -> void:
	if kind == "send":
		last_send = _seconds
		hint = {}
	var s := lesson()
	if s.is_empty():
		return
	var wait := str(s.get("wait", "ok"))
	var done := false
	match wait:
		"ok":
			done = kind == "ok"
		"send":
			done = kind == "send"
		"send_many":
			done = kind == "send" and (data.get("sources", PackedInt32Array()) as PackedInt32Array).size() >= 2
		"select_many":
			done = (kind == "select" and int(data.get("count", 0)) >= 2) or (kind == "send" and (data.get("sources", PackedInt32Array()) as PackedInt32Array).size() >= 2)
		"fraction":
			done = kind == "fraction"
		"speed":
			done = kind == "speed" or kind == "ok"
	if done:
		step += 1
		last_send = _seconds  # the idle clock starts when the lesson lets go


## Called once per sim tick with game time. Returns the live hint to show ({} for none):
## {kind: "defend"|"expand"|"strike"|"grow", text, sources, destination}.
func update(seconds: float) -> Dictionary:
	_seconds = seconds
	if holding():
		return hint
	if not hint.is_empty() and seconds - _hint_at > HINT_SECONDS:
		hint = {}
	# a fresh warning beats any tip; otherwise wait until you have been idle a while
	var a := _bot.advise(world, HUMAN)
	if a.is_empty():
		return hint
	if a["kind"] == "defend":
		var d: int = a["destination"]
		if seconds - float(_warned.get(d, -100.0)) >= DEFEND_COOLDOWN:
			_warned[d] = seconds
			_show(a, seconds)
		return hint
	if quiet or not hint.is_empty():
		return hint
	if seconds - last_send >= IDLE_SECONDS:
		_show(a, seconds)
	return hint


## Ask for the best move now (the HINT button). Always returns the advice, or a "save up" note.
func request(seconds: float) -> Dictionary:
	_seconds = seconds
	var a := _bot.advise(world, HUMAN)
	if a.is_empty():
		hint = {"kind": "wait", "text": "Nothing worth taking yet. Let your planets grow, then look again.", "sources": PackedInt32Array(), "destination": -1}
		_hint_at = seconds
		return hint
	_show(a, seconds)
	return hint


func _show(a: Dictionary, seconds: float) -> void:
	hint = {"kind": a["kind"], "text": describe(a), "sources": a["sources"], "destination": a["destination"]}
	_hint_at = seconds


## Plain words for a piece of advice.
func describe(a: Dictionary) -> String:
	var dst: int = a["destination"]
	var t := world.planets[dst]
	var srcs: PackedInt32Array = a["sources"]
	var from := _list(srcs)
	var together := "  Drag a box around them (or shift-click) to send together." if srcs.size() > 1 else ""
	match str(a["kind"]):
		"defend":
			var incoming := 0
			for f in world.fleets:
				if f.destination == dst and f.owner != HUMAN and f.owner != 0:
					incoming += f.ships
			return "%s is under attack: %d ships incoming. Drag %d from %s onto it to hold it." % [names[dst], incoming, a["ships"], from]
		"grow":
			return "%s is nearly full and has stopped growing. Drag %d ships from %s onto it: the extra makes it grow a level, so it makes more and holds more.%s" % [names[dst], a["ships"], from, together]
		"strike":
			return "%s has only %d ships. Strike it from %s before it grows.%s" % [names[dst], t.ships, from, together]
		_:
			var per_ten := int(round(t.growth * growth_per_second * 10.0))
			return "Your ships are waiting. Take %s from %s: it adds %d ships every 10 seconds once it's yours.%s" % [names[dst], from, per_ten, together]


func _list(ids: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for i in ids:
		parts.append(names[i])
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[parts.size() - 1]


## Named planets a lesson can point at: home, enemy, near (closest neutral to home), cheap (best
## ships-per-trip neutral), big (highest-level neutral).
func _refs() -> Dictionary:
	var refs := {}
	for p in world.planets:
		if p.owner == HUMAN and not refs.has("home"):
			refs["home"] = p.id
		elif p.owner == 2 and not refs.has("enemy"):
			refs["enemy"] = p.id
	if not refs.has("home"):
		return refs
	var home: int = refs["home"]
	var near_tt := 1 << 30
	var cheap_cost := INF
	var big_growth := -1
	for p in world.planets:
		if p.owner != 0:
			continue
		var tt := world.travel_time(home, p.id)
		if tt < near_tt:
			near_tt = tt
			refs["near"] = p.id
		var cost := float(p.ships + 1) * tt / float(p.growth + 1)
		if cost < cheap_cost:
			cheap_cost = cost
			refs["cheap"] = p.id
		if p.growth > big_growth:
			big_growth = p.growth
			refs["big"] = p.id
	return refs


func _fill(text: String, refs: Dictionary) -> String:
	for k: String in refs:
		text = text.replace("{%s}" % k, names[refs[k]])
	return text
