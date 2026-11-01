// Planets (docs/STYLE_GUIDE.md §4): disc with a soft highlight, rim, growth ring, selection rings.
// One MultiMesh instance per planet; antialiasing via fwidth so edges stay crisp at any zoom.
// Instance transform: origin = centre, axes scaled to the quad's outer radius.
// COLOR = planet colour. INSTANCE_CUSTOM = (body radius px, growth, flags, ring rotation).
// flags: 1 selected, 2 hovered, 4 drag target, 8 neutral.
shader_type canvas_item;

uniform float px = 1.0;             // world px per screen px
uniform float pulse_amount = 1.0;   // 0 under reduced motion
uniform vec4 ice : source_color = vec4(0.925, 0.945, 0.98, 1.0);
uniform vec4 ash : source_color = vec4(0.553, 0.592, 0.671, 1.0);

varying vec2 v_local;
varying vec4 v_data;
varying vec4 v_color;

void vertex() {
	float outer = length(MODEL_MATRIX[0].xy);
	v_local = (UV * 2.0 - 1.0) * outer;
	v_data = INSTANCE_CUSTOM;
	v_color = COLOR;
}

float band(float d, float centre, float width, float aa) {
	return 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, abs(d - centre));
}

vec4 over(vec4 dst, vec3 rgb, float a) {
	return vec4(mix(dst.rgb, rgb, a), dst.a + a * (1.0 - dst.a));
}

void fragment() {
	float r = v_data.x;
	float growth = v_data.y;
	float flags = v_data.z;
	float rot = v_data.w;
	bool selected = mod(flags, 2.0) >= 1.0;
	bool hovered = mod(floor(flags / 2.0), 2.0) >= 1.0;
	bool target = mod(floor(flags / 4.0), 2.0) >= 1.0;
	bool neutral = mod(floor(flags / 8.0), 2.0) >= 1.0;
	vec3 c = v_color.rgb;
	float d = length(v_local);
	float aa = max(fwidth(d), 0.5);
	float line = max(1.6 * px, 2.0);
	float ring_w = max(2.2 * px, 3.0);
	vec4 o = vec4(0.0);

	vec3 body = neutral ? ash.rgb * 0.45 : c * 0.82;
	float hl = exp(-pow(length(v_local - vec2(-0.26, -0.3) * r) / (0.5 * r), 2.0)) * (neutral ? 0.09 : 0.17);
	body = body + vec3(hl);
	o = over(o, body, 1.0 - smoothstep(r - aa, r + aa, d));
	vec3 rim = mix(c, vec3(1.0), 0.15);
	o = over(o, rim, band(d, r - line * 0.5, line, aa) * (neutral ? 0.6 : 0.95));

	float rr = r + max(5.0 * px, 6.0);
	float ang = atan(v_local.y, v_local.x);
	if (neutral) {
		float dot_r = max(1.6 * px, 2.2);
		float best = 1e9;
		for (int k = 0; k < 5; k++) {
			if (float(k) < growth) {
				float a = -PI / 2.0 + TAU * float(k) / 5.0;
				best = min(best, length(v_local - vec2(cos(a), sin(a)) * rr));
			}
		}
		o = over(o, ash.rgb, (1.0 - smoothstep(dot_r - aa, dot_r + aa, best)) * 0.6);
	} else {
		float ring = band(d, rr, ring_w, aa);
		float sweep = TAU * growth / 5.0 * 0.985;
		float rel = mod(ang - rot, TAU);
		float on_arc = step(rel, sweep);
		o = over(o, c, ring * mix(0.13, 0.9, on_arc));
	}

	float sel_r = rr + max(6.0 * px, 7.0);
	if (selected) {
		float pulse = 1.0 + 0.03 * (1.0 + sin(TIME * TAU / 1.2)) * pulse_amount;
		o = over(o, ice.rgb, band(d, sel_r * pulse, line, aa));
		o = over(o, ice.rgb, band(d, (sel_r + 5.0 * px) * pulse, max(px, 1.0), aa) * 0.22);
	} else if (target) {
		o = over(o, ice.rgb, band(d, sel_r, line, aa) * 0.9);
	} else if (hovered) {
		o = over(o, ice.rgb, band(d, sel_r, line, aa) * 0.45);
	}
	COLOR = o;
}
