// Billboard sparkle for the aura's rising motes: shape 0 = plus/cross (healing), 1 = four-point star.
// Additive, unshaded. Original work (Summer, s06-fantasy).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform int shape : hint_range(0, 1) = 0;
uniform float energy : hint_range(0.0, 16.0) = 4.0;

void vertex() {
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = mv * mat4(vec4(s, 0, 0, 0), vec4(0, s, 0, 0), vec4(0, 0, s, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float a;
	if (shape == 0) {
		float bar = max(step(abs(p.x), 0.22) * step(abs(p.y), 0.75), step(abs(p.y), 0.22) * step(abs(p.x), 0.75));
		float glow = exp(-dot(p, p) * 3.0) * 0.5;
		a = bar * 0.9 + glow;
	} else {
		a = exp(-dot(p, p) * 9.0) + (exp(-abs(p.x) * 24.0) * exp(-abs(p.y) * 2.5) + exp(-abs(p.y) * 24.0) * exp(-abs(p.x) * 2.5)) * 0.8;
	}
	a *= smoothstep(1.0, 0.8, length(p));
	ALBEDO = COLOR.rgb * a * COLOR.a * energy;
}
