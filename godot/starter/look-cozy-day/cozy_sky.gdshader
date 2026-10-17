// Stylized day sky: saturated blue gradient, low wide cumulus with white tops and cool
// blue bellies, a soft sun glow that follows the scene's first DirectionalLight3D.
// `storm` greys it out. Colours are LINEAR values (no source_color on purpose).
// From Grow Your Garden's weather_sky "stylized" branch (Summer Engine; base shader
// from Lantern Hollow). No textures, no TIME: the sky renders once (cheap on web).
shader_type sky;
render_mode use_debanding;

uniform vec3 zenith_color = vec3(0.05, 0.24, 0.78);
uniform vec3 horizon_color = vec3(0.40, 0.66, 0.92);
uniform vec3 cloud_shade = vec3(0.56, 0.66, 0.86);
uniform vec3 ground_color = vec3(0.20, 0.36, 0.20);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
// Shift to move the clouds (changing it re-renders the sky; keep updates rare on web).
uniform vec2 cloud_offset = vec2(0.0);
uniform float sun_glow : hint_range(0.0, 2.0) = 1.0;
uniform float storm : hint_range(0.0, 1.0) = 0.0;
uniform float sky_energy = 1.0;

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash31(vec3(i, 2)), hash31(vec3(i + vec2(1, 0), 2)), f.x),
			mix(hash31(vec3(i + vec2(0, 1), 2)), hash31(vec3(i + vec2(1, 1), 2)), f.x), f.y);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float altitude = max(direction.y, 0.0);
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(-0.4, 0.6, -0.5));
	float mu = max(dot(direction, sun), 0.0);
	vec3 color = mix(horizon_color, zenith_color, pow(smoothstep(0.0, 0.8, altitude), 0.55));
	color += vec3(1.0, 0.9, 0.7) * (pow(mu, 28.0) * 0.22 + smoothstep(0.9990, 0.9994, mu) * 1.6) * sun_glow;
	vec2 q = direction.xz / (altitude + 0.16) * 1.9 + cloud_offset;
	float puff = cloud_noise(q) * 0.58 + cloud_noise(q * 2.1 + 3.7) * 0.3 + cloud_noise(q * 4.3) * 0.12;
	float th = 0.78 - cloud_cover * 0.36;
	float body = smoothstep(th, th + 0.05, puff) * smoothstep(0.02, 0.14, altitude) * (1.0 - smoothstep(0.5, 0.85, altitude));
	float lit = smoothstep(th, th + 0.22, cloud_noise(q + vec2(0.12, 0.2)) * 0.58 + cloud_noise(q * 2.1 + 3.82) * 0.3 + cloud_noise(q * 4.3 + 0.1) * 0.12);
	vec3 cloud = mix(cloud_shade, vec3(1.0, 0.98, 0.95), clamp(lit + pow(mu, 4.0) * 0.3, 0.0, 1.0));
	color = mix(color, cloud, body);
	vec3 storm_color = mix(vec3(0.38, 0.45, 0.56), vec3(0.64, 0.68, 0.76), puff);
	color = mix(color, storm_color, storm * 0.94);
	color = direction.y < 0.0 ? mix(horizon_color, ground_color, min(-direction.y * 5.0, 1.0)) : color;
	COLOR = color * sky_energy;
}
