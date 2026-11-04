## Draws a match and turns mouse/touch into sends (docs/STYLE_GUIDE.md §4–§5).
##
## Pure presentation: it reads the sim and never writes it; sends leave through `send_requested`.
## Layers, back to front: glow (additive), planets, fleets (additive), fx (additive), overlay.
## Sizes are in world px (1 map unit = UNIT px); `screen_scale` keeps lines crisp when zoomed out.
extends Node2D

signal send_requested(sources: PackedInt32Array, destination: int)
signal selection_changed
signal denied(planet: int)
## A captured planet's count reached zero and it changed colour (after FLIP_DRAIN).
signal flipped(planet: int, owner: int, owner_before: int)

const Palette := preload("res://game/theme/palette.gd")
const Textures := preload("res://game/fx/textures.gd")
const DrawLayer := preload("res://game/fx/draw_layer.gd")
const FleetRenderer := preload("res://game/fx/fleet_renderer.gd")
const PlanetRenderer := preload("res://game/fx/planet_renderer.gd")
const Bodies := preload("res://game/fx/bodies.gd")
const MAX_FX := 160
const NEUTRAL_TEXT := Color("#C9D0DE")
const WIN_COLOR := Color("#7FE3B5")
const LOSE_COLOR := Color("#FF8A7A")
const World := preload("res://sim/world.gd")

const UNIT := 40.0
const HUMAN := 1
const DRAG_THRESHOLD := 8.0  # screen px before a press becomes a drag
const COUNT_TIME := 0.07  # ship-count tween time constant (settles in ~220 ms)
const COLOR_TIME := 0.07  # ownership cross-fade time constant
## Captures play out in two beats: the defender's count drains to zero in their colour, then the
## planet flips and counts up in the attacker's colour (owner survey, iteration 2, Q4).
const FLIP_DRAIN := 0.5
const FLIP_RISE := 0.4
const EXO := preload("res://game/fonts/Exo2-Variable.ttf")

var world: World
var interactive := true
var screen_scale := 1.0  ## on-screen px per world px (camera zoom × node scale)
var tick_fraction := 0.0  ## 0..1 progress toward the next sim tick, for smooth fleets
var selection: PackedInt32Array = []
var hover := -1
var estimate_ships := 0  ## set by the owner; shown next to the cursor while aiming
var ghost_cursor := Vector2.INF  ## demo driver's fake cursor in world px; INF hides it
var reduced_motion := false
## Seconds left to show the "YOU" marker on the human's planets (set by the game at the start).
var you_marker := 0.0
## Training coach marks: {"focus": planet ids to ring, "sources" + "destination" for a suggested
## move arrow, "kind": "defend" draws it in warning red}. Empty draws nothing.
var guide: Dictionary = {}
const GUIDE_COLOR := Color("#FFD27A")

var _pressing := false
var _dragging := false
var _boxing := false
var _press_planet := -1
var _press_pos := Vector2.ZERO
var _press_screen := Vector2.ZERO
var _cursor := Vector2.ZERO
var _drag_sources: PackedInt32Array = []

var _shown := PackedFloat32Array()
var _shown_owner := PackedInt32Array()  # owner as drawn; lags the sim during a capture's drain
var _flip := PackedFloat32Array()  # seconds since this planet was captured
var _flip_from := PackedFloat32Array()  # count shown when the capture landed
var _body := PackedInt32Array()  # Bodies layer per planet
var _color: Array[Color] = []
var _pop := PackedFloat32Array()
var _squash := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _deny := PackedFloat32Array()
var _fx: Array = []
var _time := 0.0
var _jitter := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _font: FontVariation
var _layers: Dictionary = {}
var _fx_rng := RandomNumberGenerator.new()
var _fleets: FleetRenderer
var _planets: PlanetRenderer


func _ready() -> void:
	_font = FontVariation.new()
	_font.base_font = EXO
	_font.variation_opentype = {2003265652: 560}
	for layer_name in ["glow", "planets", "fleets", "fx", "overlay"]:
		if layer_name == "fleets":
			_fleets = FleetRenderer.new()
			_fleets.name = "Fleets"
			add_child(_fleets)
			continue
		if layer_name == "planets":
			_planets = PlanetRenderer.new()
			_planets.name = "Planets"
			add_child(_planets)
			continue
		var layer := DrawLayer.new()
		layer.name = layer_name.capitalize()
		if layer_name in ["glow", "fx"]:
			layer.material = Textures.additive()
		add_child(layer)
		_layers[layer_name] = layer
	_layers["glow"].painter = _paint_glow
	_layers["fx"].painter = _paint_fx
	_layers["overlay"].painter = _paint_overlay
	_fx_rng.seed = 4242
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(256):
		_jitter.append(rng.randf())


## Point the view at a world. Safe to call again for a new match.
## `homes` maps seat -> body name (game/fx/bodies.gd) for that seat's starting planet.
func bind(p_world: World, homes: Dictionary = {}) -> void:
	world = p_world
	var n := world.planets.size()
	_shown.resize(n)
	_shown_owner.resize(n)
	_flip.resize(n)
	_flip_from.resize(n)
	_body = Bodies.assign(world, homes)
	_pop.resize(n)
	_squash.resize(n)
	_phase.resize(n)
	_deny.resize(n)
	_color.resize(n)
	_radius.resize(n)
	for i in range(n):
		var nearest := INF
		for j in range(n):
			if j != i:
				nearest = minf(nearest, world.planets[i].position.distance_to(world.planets[j].position))
		_radius[i] = minf(radius_for(world.planets[i].growth), nearest * UNIT * 0.36)
		_shown[i] = world.planets[i].ships
		_shown_owner[i] = world.planets[i].owner
		_flip[i] = 10.0
		_pop[i] = 10.0
		_squash[i] = 10.0
		_deny[i] = 10.0
		_phase[i] = float(i) * 2.399  # golden angle: neighbours never breathe in step
		_color[i] = Palette.player_color(world.planets[i].owner)
	selection = PackedInt32Array()
	_fx.clear()
	cancel()
	if _fleets != null:
		_fleets.clear()
		_sync_fleets()


func _sync_fleets() -> void:
	if _fleets != null and world != null:
		_fleets.sync(world, UNIT, planet_radius)


# --- geometry -----------------------------------------------------------------------------

static func radius_for(growth: int) -> float:
	return UNIT * (0.42 + 0.13 * growth)


func planet_pos(id: int) -> Vector2:
	return world.planets[id].position * UNIT


## Growth-scaled radius, capped so two neighbours never touch (maps allow planets 2 units apart).
func planet_radius(id: int) -> float:
	return _radius[id] if id < _radius.size() else radius_for(world.planets[id].growth)


func map_rect() -> Rect2:
	if world == null or world.planets.is_empty():
		return Rect2(0, 0, 100, 100)
	var r := Rect2(planet_pos(0), Vector2.ZERO)
	for i in range(world.planets.size()):
		r = r.expand(planet_pos(i))
	return r.grow(UNIT * 1.6)


## Nearest planet whose disc (plus a forgiving margin for fingers) contains `point`; -1 if none.
func planet_at(point: Vector2, slop_screen_px: float = 14.0) -> int:
	if world == null:
		return -1
	var best := -1
	var best_d := INF
	var slop := slop_screen_px / screen_scale
	for p in world.planets:
		var d := (p.position * UNIT).distance_to(point) - planet_radius(p.id)
		if d <= slop and d < best_d:
			best_d = d
			best = p.id
	return best


func is_dragging() -> bool:
	return _dragging


func is_boxing() -> bool:
	return _boxing


func current_sources() -> PackedInt32Array:
	return _drag_sources if _dragging else selection


func drag_target() -> int:
	if not _dragging:
		return -1
	var t := planet_at(_cursor)
	if t < 0 or (_drag_sources.size() == 1 and _drag_sources[0] == t):
		return -1
	return t


# --- frame update -------------------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	you_marker = maxf(0.0, you_marker - delta)
	if world == null:
		return
	var k_count := 1.0 - exp(-delta / COUNT_TIME)
	var k_color := 1.0 - exp(-delta / COLOR_TIME)
	for i in range(world.planets.size()):
		var p := world.planets[i]
		if _flip[i] < FLIP_DRAIN + FLIP_RISE:
			_flip[i] += delta
			var t := _flip[i]
			if t < FLIP_DRAIN:
				var e := t / FLIP_DRAIN
				_shown[i] = _flip_from[i] * (1.0 - e * e * (3.0 - 2.0 * e))
			else:
				if _shown_owner[i] != p.owner:
					var before := _shown_owner[i]
					_shown_owner[i] = p.owner
					_color[i] = Palette.player_color(p.owner).lerp(Palette.ICE, 0.35)
					flipped.emit(i, p.owner, before)
				var e := clampf((t - FLIP_DRAIN) / FLIP_RISE, 0.0, 1.0)
				_shown[i] = float(p.ships) * (1.0 - pow(1.0 - e, 3.0))
		else:
			_shown_owner[i] = p.owner
			_shown[i] = lerpf(_shown[i], float(p.ships), k_count)
			if absf(_shown[i] - p.ships) < 0.5:
				_shown[i] = p.ships
		_color[i] = _color[i].lerp(Palette.player_color(_shown_owner[i]), k_color)
		_pop[i] += delta
		_squash[i] += delta
		_deny[i] += delta
	var kept := PackedInt32Array()
	for id in selection:
		if world.planets[id].owner == HUMAN:
			kept.append(id)
	if kept.size() != selection.size():
		selection = kept
		selection_changed.emit()
	if interactive and ghost_cursor == Vector2.INF:
		hover = planet_at(get_global_mouse_position())
		if _pressing:
			_cursor = get_global_mouse_position()
	if _fx.size() > MAX_FX:
		_fx = _fx.slice(_fx.size() - MAX_FX)
	var alive: Array = []
	for fx: Dictionary in _fx:
		fx["t"] = float(fx["t"]) + delta
		if float(fx["t"]) < float(fx["dur"]):
			alive.append(fx)
	_fx = alive
	for layer: Node2D in _layers.values():
		layer.queue_redraw()
	if _fleets != null:
		_fleets.set_time(float(world.tick_count) + tick_fraction, screen_scale, reduced_motion)
	_update_planets()


# --- input --------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not interactive or world == null or ghost_cursor != Vector2.INF:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var wp := get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					var id := planet_at(wp)
					if id >= 0 and world.planets[id].owner == HUMAN:
						select_all()
						_pressing = false
						get_viewport().set_input_as_handled()
						return
				_pressing = true
				_dragging = false
				_boxing = false
				_press_pos = wp
				_press_screen = mb.position
				_press_planet = planet_at(wp)
				_cursor = wp
			elif _pressing:
				_pressing = false
				_cursor = wp
				_release(mb.shift_pressed)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			cancel()
			selection = PackedInt32Array()
			selection_changed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressing:
		var mm := event as InputEventMouseMotion
		_cursor = get_global_mouse_position()
		if not _dragging and not _boxing and mm.position.distance_to(_press_screen) > DRAG_THRESHOLD:
			if _press_planet >= 0:
				var sources := _sources_for(_press_planet)
				if sources.is_empty():
					_pressing = false
					_deny_at(_press_planet)
				else:
					_dragging = true
					_drag_sources = sources
			else:
				_boxing = true


func _sources_for(p: int) -> PackedInt32Array:
	if world.planets[p].owner == HUMAN:
		if selection.has(p):
			return selection.duplicate()
		return PackedInt32Array([p])
	return PackedInt32Array()


func _release(shift: bool) -> void:
	if _dragging:
		finish_drag()
		return
	if _boxing:
		_boxing = false
		var rect := Rect2(_press_pos, Vector2.ZERO).expand(_cursor)
		var picked: PackedInt32Array = selection.duplicate() if shift else PackedInt32Array()
		for p in world.planets:
			if p.owner == HUMAN and rect.has_point(p.position * UNIT) and not picked.has(p.id):
				picked.append(p.id)
		selection = picked
		selection_changed.emit()
		return
	click_planet(_press_planet, shift)


## Drop a drag: send to the planet under the cursor (your own too: that's how you reinforce).
## The selection is cleared either way, so the next click starts fresh.
func finish_drag() -> void:
	var t := drag_target()
	if t >= 0:
		_send(_drag_sources, t)
	_dragging = false
	_drag_sources = PackedInt32Array()
	_set_selection(PackedInt32Array())


## One click on planet `id` (-1 = empty space). The meaning depends only on what was clicked,
## never on what was selected before: your planet → select it (again → deselect; shift → add or
## remove), any other planet → send the selection there and clear it. Owner, round 7: a click
## that sometimes picked a source and sometimes sent ships cost time in a fight.
func click_planet(id: int, shift: bool) -> void:
	if id < 0:
		if not shift:
			_set_selection(PackedInt32Array())
		return
	if world.planets[id].owner == HUMAN:
		var s := PackedInt32Array([id])
		if shift:
			s = selection.duplicate()
			if s.has(id):
				s.remove_at(s.find(id))
			else:
				s.append(id)
		elif selection == s:
			s = PackedInt32Array()
		_set_selection(s)
	elif selection.is_empty():
		_deny_at(id)
	else:
		_send(selection, id)
		_set_selection(PackedInt32Array())


func _set_selection(s: PackedInt32Array) -> void:
	if s == selection:
		return
	selection = s
	selection_changed.emit()


func _send(sources: PackedInt32Array, target: int) -> void:
	var filtered := PackedInt32Array()
	for s in sources:
		if s != target:
			filtered.append(s)
	if filtered.is_empty():
		return
	for s in filtered:
		_squash[s] = 0.0
	send_requested.emit(filtered, target)


func _deny_at(id: int) -> void:
	_deny[id] = 0.0
	denied.emit(id)


func select_all() -> void:
	var s := PackedInt32Array()
	for p in world.planets:
		if p.owner == HUMAN:
			s.append(p.id)
	selection = s
	selection_changed.emit()


func cancel() -> void:
	_pressing = false
	_dragging = false
	_boxing = false
	_drag_sources = PackedInt32Array()


## Demo driver: show a drag in progress from `sources` with the cursor at `cursor` (world px).
func demo_drag(sources: PackedInt32Array, cursor: Vector2) -> void:
	_dragging = true
	_drag_sources = sources
	_cursor = cursor
	ghost_cursor = cursor


func demo_release() -> void:
	_dragging = false
	_drag_sources = PackedInt32Array()


# --- events → effects ---------------------------------------------------------------------

func on_events(events: Array) -> void:
	_sync_fleets()
	var crowded := world.fleets.size() > 300
	for e: Dictionary in events:
		match str(e["type"]):
			"launch":
				var src: int = e["source"]
				_squash[src] = 0.0
				if not crowded or int(e["owner"]) == HUMAN:
					_add_burst(src, int(e["destination"]), Palette.player_color(int(e["owner"])), int(e["ships"]))
			"arrival":
				var id: int = e["planet"]
				var pos := planet_pos(id)
				var r := planet_radius(id)
				match str(e["kind"]):
					"capture":
						# Impact now; flash, ripple and pop land on the flip (negative t = delayed).
						if not reduced_motion:
							_flip_from[id] = _shown[id]
							_flip[id] = 0.0
						var d := -FLIP_DRAIN if not reduced_motion else 0.0
						_pop[id] = d
						var c := Palette.player_color(int(e["owner"]))
						_add_ring_sparks(id, Palette.player_color(int(e["owner_before"])), int(e["involved"]))
						_fx.append({"type": "flash", "pos": pos, "r": r, "t": d, "dur": 0.18, "color": Palette.ICE})
						_fx.append({"type": "ripple", "pos": pos, "r": r, "t": d, "dur": 0.55, "color": c})
						_fx.append({"type": "ripple", "pos": pos, "r": r, "t": d - 0.12, "dur": 0.55, "color": c})
						if reduced_motion:
							flipped.emit(id, int(e["owner"]), int(e["owner_before"]))
					"battle":
						if not crowded or int(e["involved"]) > 40:
							_add_ring_sparks(id, Palette.player_color(world.planets[id].owner), int(e["involved"]))
					_:
						if crowded:
							continue
						_fx.append({"type": "absorb", "pos": pos, "r": r, "t": 0.0, "dur": 0.3, "color": Palette.player_color(world.planets[id].owner)})


func _add_burst(src: int, dst: int, color: Color, ships: int) -> void:
	var dir := (planet_pos(dst) - planet_pos(src)).normalized()
	var sparks: Array = []
	for i in range(clampi(int(sqrt(float(ships)) * 2.0), 5, 22)):
		sparks.append([dir.angle() + _fx_rng.randf_range(-0.7, 0.7), _fx_rng.randf_range(0.5, 1.6), _fx_rng.randf_range(1.6, 3.4)])
	_fx.append({"type": "burst", "pos": planet_pos(src), "r": planet_radius(src), "t": 0.0, "dur": 0.45, "color": color, "sparks": sparks})


func _add_ring_sparks(id: int, color: Color, involved: int) -> void:
	var sparks: Array = []
	for i in range(clampi(int(sqrt(float(involved)) * 1.6), 8, 26)):
		sparks.append([_fx_rng.randf() * TAU, _fx_rng.randf_range(0.4, 1.2), _fx_rng.randf_range(1.6, 3.0)])
	_fx.append({"type": "burst", "pos": planet_pos(id), "r": planet_radius(id), "t": 0.0, "dur": 0.4, "color": color.lerp(Palette.ICE, 0.4), "sparks": sparks})


# --- painting -----------------------------------------------------------------------------

func _visual_radius(i: int) -> float:
	var base := planet_radius(i)
	var breath := 1.0 if reduced_motion else 1.0 + 0.02 * sin(_time * TAU / 4.0 + _phase[i])
	var pop := 1.0
	if _pop[i] >= 0.0 and _pop[i] < 0.4:
		var e := _pop[i] / 0.4
		pop = 1.0 + 0.18 * sin(e * PI) * (1.0 - 0.4 * e)
	var squash := 1.0
	if _squash[i] < 0.22:
		squash = 1.0 - 0.08 * sin(_squash[i] / 0.22 * PI)
	return base * breath * pop * squash


func _px(screen_px: float, min_world: float = 0.0) -> float:
	return maxf(screen_px / screen_scale, min_world)


func _paint_glow(ci: CanvasItem) -> void:
	if world == null:
		return
	var glow := Textures.glow()
	for i in range(world.planets.size()):
		var p := world.planets[i]
		var pos := p.position * UNIT
		var r := _visual_radius(i)
		var a := 0.0
		var c := _color[i]
		if _shown_owner[i] != 0:
			a = 0.36 + 0.06 * sin(_time * TAU / 6.0 + _phase[i])
		elif i == hover or i == drag_target():
			a = 0.16
			c = Palette.ICE
		if selection.has(i):
			a += 0.1
		if a <= 0.0:
			continue
		var s := r * 2.4
		ci.draw_texture_rect(glow, Rect2(pos - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(c, a))


func _update_planets() -> void:
	if _planets == null or world == null:
		return
	var n := world.planets.size()
	_planets.resize(n)
	_planets.set_view(screen_scale, reduced_motion)
	var target := drag_target()
	var px := 1.0 / maxf(screen_scale, 0.01)
	var margin := maxf(5.0 * px, 6.0) + maxf(6.0 * px, 7.0) + 9.0 * px + 3.0
	for i in range(n):
		var p := world.planets[i]
		var pos := p.position * UNIT
		if _deny[i] < 0.35:
			pos.x += sin(_deny[i] * 60.0) * 3.0 * px * (1.0 - _deny[i] / 0.35)
		var r := _visual_radius(i)
		var flags := 0
		if selection.has(i):
			flags |= 1
		if i == hover and interactive:
			flags |= 2
		if i == target:
			flags |= 4
		if _shown_owner[i] == 0:
			flags |= 8
		var spin := (0.0 if reduced_motion else _time * 0.08) + _phase[i]
		_planets.set_planet(i, pos, r, (r + margin) * 1.06, _color[i], p.growth, flags, fposmod(spin, TAU * 10.0), _body[i])


func _paint_fx(ci: CanvasItem) -> void:
	var glow := Textures.glow()
	var dot := Textures.dot()
	for fx: Dictionary in _fx:
		var t: float = fx["t"]
		if t < 0.0:
			continue
		var e := t / float(fx["dur"])
		var pos: Vector2 = fx["pos"]
		var r: float = fx["r"]
		var c: Color = fx["color"]
		match str(fx["type"]):
			"flash":
				var s := r * (1.8 + 0.6 * e)
				ci.draw_texture_rect(glow, Rect2(pos - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(c, 0.95 * (1.0 - e) * (1.0 - e)))
			"ripple":
				var eo := 1.0 - pow(1.0 - e, 3.0)
				ci.draw_arc(pos, r * (1.05 + 1.5 * eo), 0.0, TAU, 72, Color(c, 0.75 * (1.0 - e) * (1.0 - e)), _px(2.2, 2.5) * (1.0 - 0.5 * e), true)
			"absorb":
				var s2 := r * 1.6
				ci.draw_texture_rect(glow, Rect2(pos - Vector2(s2, s2), Vector2(s2, s2) * 2.0), false, Color(c, 0.3 * (1.0 - e)))
			"burst":
				var eo2 := 1.0 - (1.0 - e) * (1.0 - e)
				for sp: Array in fx["sparks"]:
					var ang: float = sp[0]
					var d: float = r + r * float(sp[1]) * 1.4 * eo2
					var size: float = maxf(float(sp[2]) * (1.0 - 0.6 * e), _px(1.2))
					var p := pos + Vector2(cos(ang), sin(ang)) * d
					ci.draw_texture_rect(dot, Rect2(p - Vector2(size, size), Vector2(size, size) * 2.0), false, Color(c.lightened(0.3), 1.0 - e))


## Attack preview under the target: "37 vs 45 · not enough" in red, "· takes it" in green,
## "+37 reinforce" for your own planet. Enemy defenders include growth during the trip.
func _draw_preview(ci: CanvasItem, sources: PackedInt32Array, target: int) -> void:
	var t := world.planets[target]
	var text := ""
	var col := Palette.ICE
	if t.owner == HUMAN:
		text = "+%d reinforce" % estimate_ships
	else:
		var trip := 1
		for s in sources:
			if s != target:
				trip = maxi(trip, world.travel_time(s, target))
		var defenders := world.ships_to_take(target, trip) - 1  # with growth and the planet's shield
		var wins := estimate_ships > defenders
		text = "%d vs %d  ·  %s" % [estimate_ships, defenders, "takes it" if wins else "not enough"]
		col = WIN_COLOR if wins else LOSE_COLOR
	var lfs := int(_px(17.0))
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs).x
	var lp := planet_pos(target) + Vector2(-tw * 0.5, planet_radius(target) + _px(40.0))
	ci.draw_string_outline(_font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, int(_px(5.0)), Color(Palette.VOID, 0.8))
	ci.draw_string(_font, lp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, col)


func _paint_overlay(ci: CanvasItem) -> void:
	if world == null:
		return
	var shadow := Color(Palette.VOID, 0.6)
	for i in range(world.planets.size()):
		var p := world.planets[i]
		var r := _visual_radius(i)
		if r * screen_scale < 9.0 and i != hover and not selection.has(i):
			continue
		# Counts sit under the planet, below the level orbit, so the real surface stays visible.
		var fs := int(maxf(15.0 / screen_scale, minf(r * 0.5, 21.0 / screen_scale)))
		var text := str(int(round(_shown[i])))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var below := r + maxf(6.0 / screen_scale, 7.0) + (maxf(12.0 / screen_scale, 13.0) if selection.has(i) or i == drag_target() else 0.0)
		var base := p.position * UNIT + Vector2(-w * 0.5, below + fs * 0.92)
		if _deny[i] < 0.35:
			base.x += sin(_deny[i] * 60.0) * _px(3.0) * (1.0 - _deny[i] / 0.35)
		var outline := maxi(int(_px(4.0)), 3)
		ci.draw_string_outline(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(Palette.VOID, 0.7))
		ci.draw_string(_font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.ICE if _shown_owner[i] != 0 else NEUTRAL_TEXT)
	if _dragging:
		var target := drag_target()
		var step := _px(16.0, 12.0)
		var offset := fmod(_time * 90.0 / screen_scale, step)
		for s in _drag_sources:
			var a := planet_pos(s)
			var b := planet_pos(target) if target >= 0 else _cursor
			var d := a.distance_to(b)
			if d < 1.0:
				continue
			var dir := (b - a) / d
			var from := planet_radius(s) + _px(8.0)
			var to := d - (planet_radius(target) + _px(14.0) if target >= 0 else 0.0)
			var x := from + offset
			while x < to:
				ci.draw_circle(a + dir * x, _px(2.0, 2.0), Color(Palette.ICE, 0.6), true, -1.0, true)
				x += step
		if target >= 0:
			_draw_preview(ci, _drag_sources, target)
		else:
			var label := "%d ships" % estimate_ships
			var lfs := int(_px(17.0))
			var lp := _cursor + Vector2(_px(18.0), -_px(22.0))
			ci.draw_string_outline(_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, int(_px(4.0)), Color(Palette.VOID, 0.7))
			ci.draw_string(_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, lfs, Palette.ICE)
	elif interactive and not selection.is_empty() and hover >= 0 and world.planets[hover].owner != HUMAN:
		_draw_preview(ci, selection, hover)  # own planets select on click, so they get no send preview
	if you_marker > 0.0:
		var a := clampf(you_marker / 1.0, 0.0, 1.0)
		var bob := 0.0 if reduced_motion else sin(_time * 4.0) * _px(4.0)
		for p in world.planets:
			if p.owner != HUMAN:
				continue
			var top := p.position * UNIT - Vector2(0, planet_radius(p.id) + _px(26.0) + bob)
			var yfs := int(_px(18.0))
			var yw := _font.get_string_size("YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, yfs).x
			ci.draw_string_outline(_font, top - Vector2(yw * 0.5, _px(8.0)), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, yfs, int(_px(4.0)), Color(Palette.VOID, 0.7 * a))
			ci.draw_string(_font, top - Vector2(yw * 0.5, _px(8.0)), "YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, yfs, Color(Palette.ICE, a))
			var tip := top + Vector2(0, _px(8.0))
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-_px(7.0), -_px(6.0)), tip + Vector2(_px(7.0), -_px(6.0)), tip + Vector2(0, _px(3.0))]), Color(Palette.ICE, a))
	if not guide.is_empty():
		_draw_guide(ci)
	if _boxing:
		var rect := Rect2(_press_pos, Vector2.ZERO).expand(_cursor)
		ci.draw_rect(rect, Color(Palette.ICE, 0.05))
		ci.draw_rect(rect, Color(Palette.ICE, 0.5), false, _px(1.5))
	if ghost_cursor != Vector2.INF:
		ci.draw_circle(ghost_cursor, _px(5.0), Color(Palette.ICE, 0.95), true, -1.0, true)
		ci.draw_arc(ghost_cursor, _px(13.0), 0.0, TAU, 32, Color(Palette.ICE, 0.5), _px(1.5), true)


## The coach's marks: a breathing ring around each planet it talks about, and a moving chevron
## path from the suggested sources to the target (gold for a move, red for a defence).
func _draw_guide(ci: CanvasItem) -> void:
	var col := Palette.EMBER if str(guide.get("kind", "")) == "defend" else GUIDE_COLOR
	var breathe := 0.5 + 0.5 * sin(_time * 4.0)
	var rings := PackedInt32Array(guide.get("focus", PackedInt32Array()))
	var dst: int = int(guide.get("destination", -1))
	var sources: PackedInt32Array = guide.get("sources", PackedInt32Array())
	if dst >= 0:
		rings.append(dst)
	for id in rings:
		if id < 0 or id >= world.planets.size():
			continue
		var r := planet_radius(id) + _px(14.0) + breathe * _px(5.0)
		var segs := 24
		for k in range(segs):
			if k % 2 == 1:
				continue
			var a0 := TAU * k / segs + _time * 0.6
			ci.draw_arc(planet_pos(id), r, a0, a0 + TAU / segs, 6, Color(col, 0.55 + 0.4 * breathe), _px(2.5, 2.0), true)
	if dst < 0 or dst >= world.planets.size():
		return
	var step := _px(22.0, 16.0)
	var offset := fmod(_time * 70.0 / screen_scale, step)
	for s in sources:
		if s < 0 or s >= world.planets.size() or s == dst:
			continue
		var a := planet_pos(s)
		var b := planet_pos(dst)
		var d := a.distance_to(b)
		var dir := (b - a) / d
		var side := Vector2(-dir.y, dir.x)
		var from := planet_radius(s) + _px(12.0)
		var to := d - planet_radius(dst) - _px(22.0)
		var x := from + offset
		var size := _px(7.0, 5.0)
		while x < to:
			var c := a + dir * x
			var fade := clampf(minf(x - from, to - x) / _px(30.0), 0.0, 1.0)
			ci.draw_polyline(PackedVector2Array([c - dir * size + side * size, c, c - dir * size - side * size]), Color(col, 0.9 * fade), _px(2.5, 2.0), true)
			x += step
