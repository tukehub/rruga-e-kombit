shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 paint_color : source_color = vec4(0.0, 0.55, 1.0, 1.0);
uniform float brake_light : hint_range(0.0, 1.0) = 0.0;
uniform float body_damage : hint_range(0.0, 1.0) = 0.0;

float wear_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 original = texture(atlas, UV).rgb;
	vec3 col = original;
	// Tint the saturated blue body paint while retaining monochrome trim,
	// baked body details and the texture used by the separately drawn wheels.
	float blue = smoothstep(0.025, 0.18, col.b - col.r)
		* smoothstep(0.02, 0.12, col.g - col.r);
	float lightness = max(max(col.r, col.g), col.b);
	col = mix(col, paint_color.rgb * lightness, blue);
	// The source atlas has small third-party sponsor marks on a dark panel.
	// Cover only that panel; the car remains unbranded in the game.
	float logo = step(0.252, UV.x) * step(UV.x, 0.332)
		* step(0.252, UV.y) * step(UV.y, 0.365);
	col = mix(col, texture(atlas, vec2(0.247, UV.y)).rgb, logo);
	// Wear stays attached to body UVs. Only painted panels change; the glass,
	// wheels, lamp islands and original paint identity remain readable.
	float wear = 0.0;
	if (body_damage > 0.001) {
		vec2 cell = floor(UV * vec2(85.0, 65.0));
		float patch = smoothstep(1.0 - body_damage * 0.72, 1.0, wear_hash(cell));
		float line = abs(sin(UV.x * 780.0 + UV.y * 210.0));
		float scratch = 1.0 - smoothstep(0.04, 0.04 + max(fwidth(line) * 1.5, 0.03), line);
		wear = clamp(patch * (0.32 + scratch * 0.68) * blue * body_damage, 0.0, 1.0);
		col *= 1.0 - body_damage * blue * 0.22;
		col = mix(col, vec3(0.13, 0.14, 0.145), wear * 0.85);
	}
	ALBEDO = col;
	METALLIC = mix(0.02, 0.14, blue);
	ROUGHNESS = mix(0.72, 0.34, blue);
	ROUGHNESS = mix(ROUGHNESS, 0.86, clamp(wear + body_damage * blue * 0.35, 0.0, 1.0));
	// Rear-light UV island from the supplied atlas. Exclude red sponsor/livery
	// pixels elsewhere so only the lamp brightens when braking.
	float rear_island = step(0.55, UV.x) * step(0.41, UV.y) * step(UV.y, 0.52);
	float red_lamp = smoothstep(0.16, 0.48, original.r - max(original.g, original.b));
	EMISSION = vec3(1.0, 0.015, 0.01) * rear_island * red_lamp * brake_light * 2.0;
}
