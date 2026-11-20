shader_type spatial;
// Open water for coastal and lake cities. Opaque, one flat plane: the waves
// are analytic normals only (no displacement, no textures, no depth read), so
// it costs the same on the Mobile renderer as on Forward+. Reflections come
// from the sky radiance like every other glossy surface.
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.015, 0.075, 0.13);
uniform vec3 shallow_color : source_color = vec3(0.05, 0.36, 0.40);
uniform vec3 foam_color : source_color = vec3(0.86, 0.90, 0.90);
// Signed shore distance on the near grid (tools/pipeline/water.py): water is
// 128..255 = shore distance 0..shore_span metres. Outside the grid: open sea.
uniform sampler2D shore : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(-4500.0);
uniform float shore_size = 9000.0;
uniform float shore_span = 320.0;
uniform float wave_strength : hint_range(0.0, 2.0) = 1.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;   // rain roughens the surface
uniform float night : hint_range(0.0, 1.0) = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Slope of one travelling sine swell: d(height)/d(x,z).
vec2 swell(vec2 p, vec2 dir, float len, float amp, float speed) {
	float k = 6.2831853 / len;
	float ph = dot(p, dir) * k + TIME * speed * k;
	return dir * (amp * k * cos(ph));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	// Small waves fade out with distance before they can alias into sparkle.
	// Each band is gone before its wavelength shrinks under a few pixels; the
	// distance roughness below stands in for the waves it hides.
	float near_w = 1.0 - smoothstep(40.0, 320.0, dist);
	float mid_w = 1.0 - smoothstep(150.0, 1100.0, dist);
	float far_rough = smoothstep(250.0, 2500.0, dist);
	vec2 p = wpos.xz;
	vec2 slope = vec2(0.0);
	slope += swell(p, normalize(vec2(0.8, 0.6)), 37.0, 0.32, 1.6) * mid_w;
	slope += swell(p, normalize(vec2(-0.3, 0.95)), 21.0, 0.16, 1.2) * mid_w;
	slope += swell(p, normalize(vec2(0.95, -0.2)), 9.0, 0.05, 0.9) * near_w;
	slope += swell(p, normalize(vec2(-0.7, -0.7)), 4.3, 0.018, 0.7) * near_w;
	slope += swell(p, normalize(vec2(0.2, -0.98)), 2.1, 0.006, 0.55) * near_w;
	slope *= wave_strength * (1.0 + wetness * 0.6);

	vec2 suv = (p - shore_origin) / shore_size;
	float inside = step(0.0, suv.x) * step(suv.x, 1.0) * step(0.0, suv.y) * step(suv.y, 1.0);
	float code = texture(shore, clamp(suv, 0.0, 1.0)).r * 255.0;
	float d = mix(1.0, clamp((code - 128.0) / 127.0, 0.0, 1.0), inside) * shore_span;   // metres
	// Calmer, turquoise water over the shelf; foam lapping the beach.
	float shallow = 1.0 - smoothstep(4.0, 140.0, d);
	slope *= mix(1.0, 0.45, shallow);
	vec3 n_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float lap = sin(TIME * 0.9 + d * 0.35) * 0.5 + 0.5;
	float foam_n = vnoise(p * 0.45 + vec2(TIME * 0.12, TIME * 0.07));
	float foam = (1.0 - smoothstep(0.0, 5.0 + 6.0 * lap, d)) * smoothstep(0.35, 0.75, foam_n + 0.25 * lap) * inside;
	// Wave crests catch a little light in the distance as well.
	float crest = smoothstep(0.12, 0.3, length(slope)) * 0.12 * near_w;

	vec3 col = mix(deep_color, shallow_color, shallow * 0.85);
	col = mix(col, foam_color, clamp(foam + crest, 0.0, 1.0));
	ALBEDO = col * (1.0 - night * 0.5);
	ROUGHNESS = mix(mix(0.05, 0.11, wetness) + 0.12 * far_rough, 0.7, foam);
	SPECULAR = mix(0.55, 0.2, foam);
	METALLIC = 0.0;
}
