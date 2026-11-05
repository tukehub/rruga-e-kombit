shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 paint_color : source_color = vec4(0.0, 0.55, 1.0, 1.0);
uniform float brake_light : hint_range(0.0, 1.0) = 0.0;

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
	ALBEDO = col;
	METALLIC = mix(0.02, 0.14, blue);
	ROUGHNESS = mix(0.72, 0.34, blue);
	// Rear-light UV island from the supplied atlas. Exclude red sponsor/livery
	// pixels elsewhere so only the lamp brightens when braking.
	float rear_island = step(0.55, UV.x) * step(0.41, UV.y) * step(UV.y, 0.52);
	float red_lamp = smoothstep(0.16, 0.48, original.r - max(original.g, original.b));
	EMISSION = vec3(1.0, 0.015, 0.01) * rear_island * red_lamp * brake_light * 2.0;
}
