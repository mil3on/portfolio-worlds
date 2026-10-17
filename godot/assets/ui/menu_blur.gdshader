shader_type canvas_item;

// A small glass panel: mip sampling gives an inexpensive, strong blur over the 3D world.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 p = UV - vec2(0.5);
	vec2 q = abs(p) - vec2(0.42, 0.44);
	if (length(max(q, vec2(0.0))) > 0.08) {
		discard;
	}
	vec4 scene = textureLod(screen_texture, SCREEN_UV, 4.5);
	COLOR = vec4(mix(scene.rgb, vec3(1.0), 0.72), 0.88);
}
