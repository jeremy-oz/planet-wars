## Draws every fleet with one MultiMesh and game/fx/fleet_stream.gdshader.
##
## The CPU touches a fleet twice: when it first appears (write its instance) and when it is gone
## (free its slot). Everything per-frame happens on the GPU from the `sim_time` uniform, so frame
## cost does not grow with the number of fleets in flight.
extends MultiMeshInstance2D

const Palette := preload("res://game/theme/palette.gd")
const World := preload("res://sim/world.gd")
const SHADER := preload("res://game/fx/fleet_stream.gdshader")

var _slots: Dictionary = {}  # fleet instance id -> slot
var _free := PackedInt32Array()
var _used := 0  # high-water mark
var _mat: ShaderMaterial


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	material = _mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _quad()
	mm.instance_count = 256
	mm.visible_instance_count = 0
	multimesh = mm


static func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, -1), Vector2(1, -1), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func clear() -> void:
	_slots.clear()
	_free = PackedInt32Array()
	_used = 0
	multimesh.visible_instance_count = 0


## Call after every sim tick. `radius` maps planet id -> drawn radius (fleets leave the surface).
func sync(world: World, unit: float, radius: Callable) -> void:
	var seen: Dictionary = {}
	for f in world.fleets:
		var id := f.get_instance_id()
		seen[id] = true
		if _slots.has(id) or f.trip_length < 2:
			continue
		var slot := _alloc()
		_slots[id] = slot
		var a := world.planets[f.source].position * unit
		var b := world.planets[f.destination].position * unit
		var dist := a.distance_to(b)
		if dist < 1.0:
			continue
		var dir := (b - a) / dist
		var start := a + dir * float(radius.call(f.source))
		var end := b - dir * float(radius.call(f.destination))
		var normal := Vector2(-dir.y, dir.x)
		var side := 1.0 if (posmod(id, 1 << 20) >> 4) % 2 == 0 else -1.0
		var bulge := minf(start.distance_to(end) * 0.07, unit * 0.9) * side
		var launch := float(world.tick_count - (f.trip_length - 1 - f.remaining))
		multimesh.set_instance_transform_2d(slot, Transform2D(end - start, normal, start))
		multimesh.set_instance_color(slot, Palette.player_color(f.owner))
		multimesh.set_instance_custom_data(slot, Color(launch, float(f.trip_length), float(f.ships), bulge))
	for id: int in _slots.keys():
		if not seen.has(id):
			var slot: int = _slots[id]
			_slots.erase(id)
			multimesh.set_instance_custom_data(slot, Color(0, 0, 0, 0))
			_free.append(slot)


func set_time(sim_time: float, screen_scale: float, reduced_motion: bool) -> void:
	_mat.set_shader_parameter("sim_time", sim_time)
	_mat.set_shader_parameter("min_px", 1.0 / maxf(screen_scale, 0.01))
	_mat.set_shader_parameter("wobble", 0.0 if reduced_motion else 1.0)


func active_count() -> int:
	return _slots.size()


func _alloc() -> int:
	if not _free.is_empty():
		var slot := _free[_free.size() - 1]
		_free.remove_at(_free.size() - 1)
		return slot
	if _used >= multimesh.instance_count:
		_grow()
	_used += 1
	multimesh.visible_instance_count = _used
	return _used - 1


func _grow() -> void:
	var old := multimesh.buffer
	var old_count := multimesh.instance_count
	multimesh.instance_count = old_count * 2
	var buf := multimesh.buffer
	for i in range(old.size()):
		buf[i] = old[i]
	multimesh.buffer = buf
	multimesh.visible_instance_count = _used
