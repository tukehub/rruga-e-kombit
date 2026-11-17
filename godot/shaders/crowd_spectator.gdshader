shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Spectators from tools/optimize_crowd.py: static ~2k-triangle meshes,
// animated here on the GPU, no Skeleton3D. Mesh space: 1.75 m tall, soles
// at y = 0, facing +Z.
// INSTANCE_CUSTOM: r phase (0..1), g speed (0..1), b outfit/tint seed (0..1).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float body_height = 1.75;
uniform float bounce = 0.07;          // metres the head rises on a cheer
uniform float sway = 0.06;            // metres of side-to-side at the head
uniform float lean = 0.08;            // metres the head leans toward the square
uniform float base_rate = 3.0;        // radians per second at speed 0
uniform float rate_range = 4.0;       // added at speed 1
uniform float brightness_var : hint_range(0.0, 0.5) = 0.12;
uniform float outfit_shift : hint_range(0.0, 1.0) = 0.45;

varying float v_height;
varying vec3 v_tint;
varying float v_bright;

vec3 palette(float t) {
	// A cheap cosine palette: reds, blues, greens, ochres, greys.
	return 0.55 + 0.4 * cos(6.2832 * (t + vec3(0.0, 0.33, 0.67)));
}

void vertex() {
	float phase = INSTANCE_CUSTOM.r * 6.2832;
	float rate = base_rate + INSTANCE_CUSTOM.g * rate_range;
	float t = TIME * rate + phase;
	// Feet planted (w = 0), head moves most (w = 1).
	float w = clamp(VERTEX.y / body_height, 0.0, 1.0);
	float w2 = w * w;
	float hop = max(0.0, sin(t));
	VERTEX.y += w2 * bounce * hop * hop;
	VERTEX.x += w2 * sway * sin(t * 0.5 + 1.3);
	VERTEX.z += w2 * lean * (0.5 + 0.5 * sin(t + 0.7));
	v_height = w;
	v_tint = palette(INSTANCE_CUSTOM.b);
	v_bright = 1.0 + (fract(INSTANCE_CUSTOM.b * 13.7 + INSTANCE_CUSTOM.r) * 2.0 - 1.0) * brightness_var;
}

void fragment() {
	vec3 albedo = texture(albedo_tex, UV).rgb;
	// Re-dye the clothes band (hips to shoulders) toward the instance colour,
	// keeping the texture's folds and shading as luminance.
	float outfit = smoothstep(0.44, 0.5, v_height) * (1.0 - smoothstep(0.78, 0.83, v_height));
	float luma = dot(albedo, vec3(0.299, 0.587, 0.114));
	vec3 dyed = luma * 1.6 * v_tint;
	albedo = mix(albedo, dyed, outfit * outfit_shift);
	ALBEDO = clamp(albedo * v_bright, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}
