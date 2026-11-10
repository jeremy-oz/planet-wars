// Planets (docs/STYLE_GUIDE.md §4): real NASA surface maps on a lit, slowly turning sphere, an
// atmosphere in the owner's colour, level pips on an orbit, and selection rings.
// One MultiMesh instance per planet; antialiasing via fwidth so edges stay crisp at any zoom.
// Instance transform: origin = centre, axes scaled to the quad's outer radius.
// COLOR = owner colour. INSTANCE_CUSTOM = (body radius px, level 1-5, flags + 16 * body layer, spin).
// flags: 1 selected, 2 hovered, 4 drag target, 8 neutral.
shader_type canvas_item;

uniform float px = 1.0;             // world px per screen px
uniform float pulse_amount = 1.0;   // 0 under reduced motion
uniform vec4 ice : source_color = vec4(0.925, 0.945, 0.98, 1.0);
uniform vec4 ash : source_color = vec4(0.553, 0.592, 0.671, 1.0);
uniform sampler2DArray bodies : source_color, filter_linear_mipmap, repeat_enable;
uniform float body_width = 1024.0;

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
	float level = v_data.y;
	float packed = v_data.z;
	float spin = v_data.w;
	float layer = floor(packed / 16.0);
	float flags = packed - layer * 16.0;
	bool selected = mod(flags, 2.0) >= 1.0;
	bool hovered = mod(floor(flags / 2.0), 2.0) >= 1.0;
	bool target = mod(floor(flags / 4.0), 2.0) >= 1.0;
	bool neutral = mod(floor(flags / 8.0), 2.0) >= 1.0;
	vec3 c = v_color.rgb;
	float d = length(v_local);
	float aa = max(fwidth(d), 0.5);
	float line = max(1.6 * px, 2.0);
	vec4 o = vec4(0.0);

	// Atmosphere: a soft halo just outside the limb, owner colour only.
	if (!neutral) {
		float halo = exp(-pow(max(d - r, 0.0) / (0.16 * r + 2.0 * px), 2.0)) * step(r - aa, d);
		o = over(o, c, halo * 0.7);
	}

	// The body: equirectangular map on a sphere, lit from the upper left.
	vec2 p = v_local / r;
	float d2 = dot(p, p);
	if (d2 < 1.2) {
		float z = sqrt(max(1.0 - d2, 0.0));
		vec3 n = vec3(p.x, p.y, z);
		float lon = atan(n.x, n.z) + spin;
		float lat = asin(clamp(n.y, -1.0, 1.0));
		vec2 uv = vec2(fract(lon / TAU + 0.5), 0.5 + lat / PI);
		float lod = max(log2(body_width / (PI * r / px)), 0.0);
		vec3 surf = textureLod(bodies, vec3(uv, layer), lod).rgb;
		float lum = dot(surf, vec3(0.299, 0.587, 0.114));
		vec3 col;
		if (neutral) {
			col = mix(vec3(lum), surf, 0.3) * 0.62;
		} else {
			vec3 tinted = c * (0.28 + 1.05 * lum);
			col = mix(surf, tinted, 0.3);
		}
		vec3 L = normalize(vec3(-0.55, -0.6, 0.62));
		float diff = clamp(dot(n, L), 0.0, 1.0);
		col *= 0.16 + 1.0 * pow(diff, 0.75);
		// Limb: atmosphere scatter on owned worlds, a faint terminator glow on rock.
		float limb = pow(1.0 - z, 2.4);
		col += (neutral ? ash.rgb * 0.18 : c * 0.85) * limb;
		o = over(o, col, 1.0 - smoothstep(r - aa, r + aa, d));
	}
	if (neutral) {
		o = over(o, ash.rgb, band(d, r - line * 0.5, line, aa) * 0.5);
	}

	// Level pips: one moon per level on a faint orbit, turning with the planet.
	float rr = r + max(6.0 * px, 7.0);
	vec3 pip = neutral ? ash.rgb : mix(c, vec3(1.0), 0.2);
	o = over(o, pip, band(d, rr, max(px, 1.0), aa) * (neutral ? 0.18 : 0.28));
	float dot_r = max(2.3 * px, 2.6);
	float best = 1e9;
	for (int k = 0; k < 5; k++) {
		if (float(k) < level) {
			float a = spin * 4.0 - PI / 2.0 + TAU * float(k) / max(level, 1.0);
			best = min(best, length(v_local - vec2(cos(a), sin(a)) * rr));
		}
	}
	o = over(o, pip, (1.0 - smoothstep(dot_r - aa, dot_r + aa, best)) * (neutral ? 0.75 : 1.0));

	float sel_r = rr + max(7.0 * px, 8.0);
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
