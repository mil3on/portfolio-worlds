// Healing / holy light column for an open CylinderMesh (UV.y 0 at the top, 1 at the bottom): soft
// core brightest where it faces the camera, streaks rising, bright foot, fading out at the top.
// Additive, unshaded, Compatibility-safe. Original work (Summer, s06-fantasy).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 1.0, 0.5);
uniform vec3 hot_color : source_color = vec3(0.85, 1.0, 0.8);
uniform float energy : hint_range(0.0, 10.0) = 1.6;
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float rise_speed = 0.6;
uniform float pulse_boost : hint_range(0.0, 3.0) = 0.0;
// Soft contact (m): the column fades where it passes into walls, rocks or props (shelf rule 8).
uniform float contact_fade = 0.35;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float h = 1.0 - UV.y;                       // 0 bottom .. 1 top
	float facing = abs(dot(NORMAL, VIEW));
	float soft = pow(facing, 2.5);
	float t = TIME;
	float streak = vnoise(vec2(UV.x * 28.0, h * 2.5 - t * rise_speed * 2.5));
	streak = pow(streak, 3.0) * 1.6;
	float bands = 0.5 + 0.5 * sin(h * 18.0 - t * 4.0);
	float fade = pow(1.0 - h, 1.6) * smoothstep(0.0, 0.05, h);
	float foot = exp(-h * 9.0) * 1.2;
	vec3 col = mix(color, hot_color, soft * 0.6) * (soft * (0.35 + streak + bands * 0.15) + foot * soft);
	float contact = 1.0;
	if (contact_fade > 0.0) {
		float d = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV, d) * 2.0 - 1.0;
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
#endif
		vec4 sv = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		contact = smoothstep(0.0, contact_fade, VERTEX.z - sv.z / sv.w);
	}
	ALBEDO = col * fade * contact * energy * intensity * (1.0 + pulse_boost);
}
