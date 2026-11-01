// Fleets as glowing particle streams (docs/STYLE_GUIDE.md §4), drawn entirely on the GPU.
//
// One MultiMesh instance per fleet, written once at launch. The vertex shader places a small quad
// around the stream's head from the sim clock; the fragment shader draws the dots, trail and glow.
// Instance transform: origin = path start, x axis = path (start→end), y axis = unit normal.
// INSTANCE_CUSTOM = (launch tick, trip length, ships, bulge px). ships <= 0 hides the instance.
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
	float root = sqrt(max(ships, 0.0));
	float stream = clamp(24.0 + root * 9.0, 30.0, 190.0) * s;
	float glow = (16.0 + root * 2.6) * s;
	float spread = (8.0 + root * 0.5) * s;
	float bulge = d.w * s;
	float back = stream * 1.15 + spread;
	float halfw = spread * 1.6 + glow + abs(bulge) * 0.25;
	float along = mix(-back, glow, VERTEX.x);
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
	float root = sqrt(v_ships);
	float stream = clamp(24.0 + root * 9.0, 30.0, 190.0) * s;
	float glow_r = (16.0 + root * 2.6) * s;
	float a = 0.0;
	float dh = length(vec2(v_along, v_lateral)) / glow_r;
	a += 0.3 * exp(-dh * dh * 2.6);
	if (behind >= 0.0 && behind < stream * 1.1) {
		float u = behind / (stream * 1.1);
		float w = max((2.0 + root * 0.22) * s, min_px * 1.2);
		a += 0.2 * (1.0 - u) * exp(-(ly * ly) / (w * w));
	}
	float n = clamp(root * 4.5, 8.0, 56.0);
	float cell = stream / n;
	float ci = floor(behind / cell);
	float dots = 0.0;
	for (int k = -1; k <= 1; k++) {
		float idx = ci + float(k);
		if (idx < 0.0) {
			continue;
		}
		float h1 = hash(idx * 12.9898 + v_seed);
		float h2 = hash(idx * 78.233 + v_seed * 1.7);
		float cb = (idx + h1) * cell;
		float u = cb / stream;
		if (u > 1.0) {
			continue;
		}
		float lat = (h2 - 0.5) * 2.0 * (1.5 + 6.0 * u) * (0.6 + root * 0.04) * s;
		lat += sin(TIME * 2.6 + idx) * 1.5 * s * wobble;
		float r = max((1.7 + 2.6 * (1.0 - u)) * s, min_px * 1.3);
		float q = length(vec2(behind - cb, ly - lat)) / r;
		dots += (0.3 + 0.7 * (1.0 - u)) * (1.0 - smoothstep(0.3, 1.0, q));
	}
	a += dots;
	float from_start = v_prog * v_len + v_along;
	a *= step(-2.0 * s, from_start);
	vec3 rgb = mix(v_color.rgb, vec3(1.0), clamp(dots * 0.18, 0.0, 0.35));
	COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
