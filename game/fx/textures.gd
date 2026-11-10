## Procedural textures shared by every renderer, built once: a soft glow and a soft dot.
## Drawing textured quads is far cheaper than stacks of circles, which keeps 200-planet maps at 60 fps.
extends RefCounted

static var _glow: Texture2D
static var _dot: Texture2D
static var _additive: CanvasItemMaterial


static func glow() -> Texture2D:
	if _glow == null:
		_glow = _radial(256, PackedFloat32Array([0.0, 0.16, 0.42, 0.72, 1.0]), [1.0, 0.6, 0.22, 0.05, 0.0])
	return _glow


static func dot() -> Texture2D:
	if _dot == null:
		_dot = _radial(32, PackedFloat32Array([0.0, 0.35, 0.7, 1.0]), [1.0, 0.85, 0.25, 0.0])
	return _dot


static func additive() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive


## Drop the cached resources (called on exit so the renderer does not report leaks).
static func release() -> void:
	_glow = null
	_dot = null
	_additive = null


static func _radial(size: int, offsets: PackedFloat32Array, alphas: Array) -> Texture2D:
	var g := Gradient.new()
	var colors := PackedColorArray()
	for a in alphas:
		colors.append(Color(1, 1, 1, float(a)))
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
