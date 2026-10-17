// Healing / holy aura ground circle: bright outer ring, a band of runes turning slowly, an inner
// sigil ring turning the other way, a soft glowing disc, pulse waves running outward, and a
// sparkling dust field. Use on a PlaneMesh (UV 0..1 spans the circle) a few cm above the ground.
// Additive, unshaded, Compatibility-safe. Original work (Summer, s06-fantasy).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 1.0, 0.5);
uniform vec3 hot_color : source_color = vec3(0.85, 1.0, 0.8);
uniform float energy : hint_range(0.0, 10.0) = 2.4;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float spin_speed = 0.12;          // turns per second of the rune band
uniform float pulse_period = 1.6;         // seconds between pulse waves
uniform float rune_count = 18.0;
uniform float pulse_boost : hint_range(0.0, 3.0) = 0.0;  // healing_aura.gd flashes this on pulse()

float h11(float n) { return fract(sin(n * 127.1) * 43758.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a; vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}
float rune(vec2 q, float cell) {
	float d = seg(q, vec2(0.0, -0.5), vec2(0.0, 0.5));
	if (h11(cell + 0.11) < 0.5) d = min(d, seg(q, vec2(0.0, 0.5), vec2(0.32, 0.15)));
	if (h11(cell + 0.23) < 0.4) d = min(d, seg(q, vec2(0.0, 0.5), vec2(-0.32, 0.15)));
	if (h11(cell + 0.37) < 0.45) d = min(d, seg(q, vec2(0.0, 0.0), vec2(0.32, -0.3)));
	if (h11(cell + 0.41) < 0.35) d = min(d, seg(q, vec2(0.0, 0.05), vec2(-0.32, 0.35)));
	if (h11(cell + 0.53) < 0.3) d = min(d, seg(q, vec2(-0.3, -0.3), vec2(0.3, 0.3)));
	float aa = fwidth(d) + 0.02;
	return 1.0 - smoothstep(0.08 - aa, 0.08 + aa, d);
}
float ring(float r, float at, float w) { return exp(-pow((r - at) / w, 2.0)); }

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 1.0) discard;
	float ang = atan(p.y, p.x);
	float t = TIME;
	// outer double ring
	float g = ring(r, 0.95, 0.018) * 1.4 + ring(r, 0.885, 0.008) * 0.9;
	// rune band between 0.71 and 0.86, turning
	float band_c = 0.785; float band_h = 0.13;
	float a1 = ang + t * spin_speed * 6.2831;
	float u = fract(a1 / 6.2831) * rune_count;
	float cell = floor(u);
	vec2 rq = vec2((fract(u) - 0.5) * 6.2831 * band_c / rune_count / band_h * 1.6, (r - band_c) / band_h * 1.25);
	float runes = rune(rq, cell + 3.0) * step(abs(r - band_c), band_h * 0.5);
	g += runes * (0.8 + 0.4 * sin(t * 3.0 - cell * 0.7));
	g += ring(r, band_c + band_h * 0.55, 0.006) * 0.8 + ring(r, band_c - band_h * 0.55, 0.006) * 0.8;
	// inner sigil: hexagram-like star turning the other way
	float a2 = ang - t * spin_speed * 4.0;
	float star = 0.0;
	for (int k = 0; k < 2; k++) {
		float off = float(k) * 3.14159 / 3.0;
		float aa = mod(a2 + off, 6.2831 / 3.0) - 3.14159 / 3.0;
		float dline = abs(r * cos(aa) - 0.33);
		star += (1.0 - smoothstep(0.004, 0.012, dline)) * step(r, 0.66);
	}
	g += star * 0.7 + ring(r, 0.62, 0.007) * 0.9;
	// soft disc + pulse waves
	float disc = (1.0 - smoothstep(0.0, 1.0, r)) * 0.18;
	float ph = fract(t / pulse_period);
	float wave = ring(r, ph * 1.0, 0.05) * (1.0 - ph) * 0.9;
	// dust sparkles
	vec2 sc = p * 14.0;
	vec2 cid = floor(sc);
	vec2 cf = fract(sc) - 0.5;
	float sp = step(0.86, h21(cid)) * exp(-dot(cf, cf) * 40.0) * pow(0.5 + 0.5 * sin(t * 4.0 + h21(cid + 7.0) * 60.0), 4.0);
	vec3 col = color * (g + disc + wave * 0.8) + hot_color * (sp * 0.8 + ring(r, 0.95, 0.006) * 0.8 + wave * 0.3);
	col *= 1.0 + pulse_boost;
	float edge_fade = smoothstep(1.0, 0.97, r);
	ALBEDO = col * energy * intensity * edge_fade;
}
