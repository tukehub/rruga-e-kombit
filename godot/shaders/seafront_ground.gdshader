shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Lungomare ground: pale stone paving in square slabs, and lawns cut by a
// diamond grid of diagonal paved paths (after aerial photographs).
// UV.x = metres along the seafront, UV.y = metres across it from the road
// centreline. COLOR.r = 0 paving, 1 lawn.

uniform vec3 stone : source_color = vec3(0.78, 0.76, 0.71);
uniform vec3 joint : source_color = vec3(0.66, 0.64, 0.60);
uniform vec3 grass : source_color = vec3(0.27, 0.47, 0.19);
uniform float slab = 1.2;
uniform float path_pitch = 34.0;
uniform float path_half = 1.1;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV;
	// Slabs with thin joints, each a touch lighter or darker.
	vec2 cell = floor(p / slab);
	vec2 f = fract(p / slab);
	float j = step(min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * slab, 0.035);
	vec3 paving = mix(stone * (0.94 + 0.08 * hash(cell)), joint, j);
	// Lawn with diagonal paths both ways.
	float a = abs(mod(p.x + p.y, path_pitch) - path_pitch * 0.5);
	float b = abs(mod(p.x - p.y, path_pitch) - path_pitch * 0.5);
	// Distance to the nearest path centreline of either family.
	float d = path_pitch * 0.5 - max(a, b);
	float path = 1.0 - smoothstep(path_half - 0.15, path_half + 0.15, d);
	vec3 lawn = grass * (0.88 + 0.2 * hash(floor(p * 0.5)));
	float is_lawn = COLOR.r * (1.0 - path);
	ALBEDO = mix(paving, lawn, is_lawn) * (1.0 - 0.3 * wetness * (1.0 - is_lawn));
	ROUGHNESS = mix(mix(0.72, 0.25, wetness), 0.95, is_lawn);
	SPECULAR = 0.4;
}
