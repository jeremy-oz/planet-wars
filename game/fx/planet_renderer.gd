## Draws every planet with one MultiMesh and game/fx/planet.gdshader. Updated once per frame.
extends MultiMeshInstance2D

const SHADER := preload("res://game/fx/planet.gdshader")

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
	multimesh = mm


static func _quad() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func resize(count: int) -> void:
	if multimesh.instance_count != count:
		multimesh.instance_count = count


func set_view(screen_scale: float, reduced_motion: bool) -> void:
	_mat.set_shader_parameter("px", 1.0 / maxf(screen_scale, 0.01))
	_mat.set_shader_parameter("pulse_amount", 0.0 if reduced_motion else 1.0)


## flags: 1 selected, 2 hovered, 4 drag target, 8 neutral.
func set_planet(i: int, pos: Vector2, radius: float, outer: float, color: Color, growth: int, flags: int, rotation: float) -> void:
	multimesh.set_instance_transform_2d(i, Transform2D(Vector2(outer, 0), Vector2(0, outer), pos))
	multimesh.set_instance_color(i, color)
	multimesh.set_instance_custom_data(i, Color(radius, float(growth), float(flags), rotation))
