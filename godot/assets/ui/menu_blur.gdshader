shader_type canvas_item;

// A small glass panel: mip sampling gives an inexpensive, strong blur over the 3D world.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// The left edge deliberately runs off-screen. Only the two right corners round off.
	float r = 0.095;
	if (UV.x > 1.0 - r && UV.y < r && length(UV - vec2(1.0 - r, r)) > r) discard;
	if (UV.x > 1.0 - r && UV.y > 1.0 - r && length(UV - vec2(1.0 - r, 1.0 - r)) > r) discard;
	vec4 scene = textureLod(screen_texture, SCREEN_UV, 4.5);
	COLOR = vec4(mix(scene.rgb, vec3(1.0), 0.72), 0.88);
}
