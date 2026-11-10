// Fleets as glowing particle streams (docs/STYLE_GUIDE.md §4), drawn entirely on the GPU.
//
// One MultiMesh instance per fleet, written once at launch. The vertex shader places a small quad
// around the stream's head from the sim clock; the fragment shader draws the dots, trail and glow.
// Instance transform: origin = path start, x axis = path (start→end), y axis = unit normal.
// INSTANCE_CUSTOM = (launch tick, trip length, ships, bulge px). ships <= 0 hides the instance.
//
// Size reads as fleet strength: one dot per ship up to 80, and the swarm's width, length, dot size
// and head glow all grow with sqrt(ships), so 3 ships are a thin wisp and 100 a wide, bright swarm.
shader_type canvas_item;
render_mode blend_add, skip_vertex_transform;

uniform float sim_time = 0.0;       // world.tick_count + fraction toward the next tick
uniform float min_px = 1.0;         // world px per screen px, so dots never vanish when zoomed out
uniform float wobble = 1.0;         // 0 under reduced motion

varying float v_along;
varying float v_lateral;
varying float v_prog;
varying float v_len;
varying float v_bulge;
varying float v_ships;
varying float v_seed;
varying float v_scale;
varying vec4 v_color;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

// Sizes in world px before the instance scale: x = stream length, y = swarm half-width,
// z = head glow radius, w = dot radius at the head.
vec4 fleet_size(float ships) {
	float root = sqrt(max(ships, 1.0));
	return vec4(
		clamp(10.0 + root * 13.0, 20.0, 220.0),
		1.5 + root * 2.6,
		6.0 + root * 4.5,
		min(1.3 + root * 0.35, 5.0)
	);
}

void vertex() {
	vec4 d = INSTANCE_CUSTOM;
	vec2 xa = MODEL_MATRIX[0].xy;
	vec2 yr = MODEL_MATRIX[1].xy;
	vec2 origin = MODEL_MATRIX[3].xy;
	float s = max(length(yr), 1e-5);
	vec2 ny = yr / s;
	float len = max(length(xa), 1e-5);
	vec2 dir = xa / len;
	float ships = d.z;
	float prog = clamp((sim_time - d.x) / max(d.y - 1.0, 1.0), 0.0, 1.0);
	vec4 sz = fleet_size(ships) * s;
	float bulge = d.w * s;
	float back = sz.x * 1.15 + sz.z;
	float halfw = sz.y * 1.2 + sz.z + sz.w + abs(bulge) * 0.25 + 3.0 * s;
	float along = mix(-back, sz.z, VERTEX.x);
	float lateral = VERTEX.y * halfw;
	vec2 head = origin + xa * prog + ny * sin(prog * PI) * bulge;
	vec2 pos = head + dir * along + ny * lateral;
	float alive = step(0.5, ships) * step(1.5, d.y);
	VERTEX = mix(origin, pos, alive);
	v_along = along;
	v_lateral = lateral;
	v_prog = prog;
	v_len = len;
	v_bulge = bulge;
	v_ships = ships;
	v_seed = float(INSTANCE_ID % 997) * 1.618;
	v_scale = s;
	v_color = COLOR;
}

void fragment() {
	float s = v_scale;
	float behind = -v_along;
	float t = clamp(v_prog + v_along / max(v_len, 1.0), 0.0, 1.0);
	float ly = v_lateral - (sin(t * PI) - sin(v_prog * PI)) * v_bulge;
	float root = sqrt(max(v_ships, 1.0));
	vec4 sz = fleet_size(v_ships) * s;
	float stream = sz.x;
	float a = 0.0;
	// head glow, wider and brighter for bigger fleets
	float dh = length(vec2(v_along, v_lateral)) / sz.z;
	a += (0.22 + min(root * 0.025, 0.25)) * exp(-dh * dh * 2.6);
	// faint trail
	if (behind >= 0.0 && behind < stream * 1.1) {
		float u = behind / (stream * 1.1);
		float w = max((1.0 + root * 0.35) * s, min_px * 1.2);
		a += 0.18 * (1.0 - u) * exp(-(ly * ly) / (w * w));
	}
	// one dot per ship (up to 80), packed along the stream
	float n = clamp(v_ships, 1.0, 80.0);
	float cell = stream / n;
	float ci = floor(behind / cell);
	float dots = 0.0;
	for (int k = -2; k <= 2; k++) {
		float idx = ci + float(k);
		if (idx < 0.0 || idx >= n) {
			continue;
		}
		float h1 = hash(idx * 12.9898 + v_seed);
		float h2 = hash(idx * 78.233 + v_seed * 1.7);
		float cb = (idx + h1) * cell;
		float u = cb / stream;
		float lat = (h2 - 0.5) * 2.0 * sz.y * (0.35 + 0.65 * u);
		lat += sin(TIME * 2.6 + idx) * 1.5 * s * wobble;
		float r = max(min(sz.w * (0.55 + 0.45 * (1.0 - u)), cell * 2.2), min_px * 1.3);
		float q = length(vec2(behind - cb, ly - lat)) / r;
		dots += (0.35 + 0.65 * (1.0 - u)) * (1.0 - smoothstep(0.3, 1.0, q));
	}
	a += dots;
	float from_start = v_prog * v_len + v_along;
	a *= step(-2.0 * s, from_start);
	vec3 rgb = mix(v_color.rgb, vec3(1.0), clamp(dots * 0.18, 0.0, 0.35));
	COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
