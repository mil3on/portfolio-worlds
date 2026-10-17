shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap, specular_disabled;
// Cozy chunky canopy: soft top-to-underside ramp (bright warm crown, cool belly), lumpy clumps from vertex
// noise, gentle sway. No COLOR, no instance uniforms: safe on Compatibility. From Grow Your Garden (Summer).

uniform vec3 top_color : source_color = vec3(.55, .80, .33);
uniform vec3 bottom_color : source_color = vec3(.20, .46, .38);
uniform float ramp_low = -0.45;
uniform float ramp_high = 0.9;
uniform float lump = 0.14;
uniform float sway = 0.04;
// Weather moods: frost caps on upward clumps (0..1), gust multiplies sway.
uniform float frost = 0.0;
uniform float gust = 1.0;

varying vec3 v_local;
varying float v_tint;

float cozy_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float cozy_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(cozy_hash(i), cozy_hash(i + vec3(1, 0, 0)), f.x),
			mix(cozy_hash(i + vec3(0, 1, 0)), cozy_hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(cozy_hash(i + vec3(0, 0, 1)), cozy_hash(i + vec3(1, 0, 1)), f.x),
			mix(cozy_hash(i + vec3(0, 1, 1)), cozy_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_tint = cozy_hash(floor(origin * 1.7) + vec3(4.1));
	v_local = VERTEX;
	VERTEX += NORMAL * (cozy_noise(VERTEX * 1.3 + origin * 0.21) - 0.5) * lump * 2.0;
	float wave = sin(TIME * 0.9 + origin.x * 0.31 + origin.z * 0.23) + 0.3 * sin(TIME * 1.7 + VERTEX.y);
	VERTEX.xz += vec2(1.0, 0.45) * wave * sway * gust * max(VERTEX.y - 1.5, 0.0) * 0.25;
}

void fragment() {
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 c = mix(bottom_color, top_color, smoothstep(ramp_low, ramp_high, nw.y));
	// per-tree variation plus soft leaf-clump dapple (painted, not photographic)
	c *= 0.93 + 0.14 * v_tint;
	c *= 0.95 + 0.09 * smoothstep(0.45, 0.8, cozy_noise(v_local * 3.2));
	c = mix(c, vec3(0.88, 0.93, 1.0), frost * smoothstep(0.45, 0.85, nw.y) * 0.7);
	ALBEDO = c;
	ROUGHNESS = 0.88;
	BACKLIGHT = c * 0.22;
}
