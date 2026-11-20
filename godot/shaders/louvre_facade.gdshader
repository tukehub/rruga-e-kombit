shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;
// Flamurtari stadium cladding: a red skin behind horizontal grey aluminium
// louvres, with vertical support posts. UV is in metres (x along the facade,
// y up from the ground). Below `grey_below` the skin behind the slats is dark
// grey, as on the side wings of the main stand.

uniform vec3 skin : source_color = vec3(0.62, 0.05, 0.07);
uniform vec3 skin_low : source_color = vec3(0.16, 0.16, 0.17);
uniform vec3 slat : source_color = vec3(0.62, 0.62, 0.60);
uniform float slat_pitch = 0.46;
uniform float slat_width = 0.13;
uniform float post_pitch = 3.6;
uniform float grey_below = 0.0;

void fragment() {
	vec2 p = UV;
	float s = fract(p.y / slat_pitch);
	float on_slat = 1.0 - smoothstep(slat_width / slat_pitch - 0.04, slat_width / slat_pitch + 0.04, s);
	float post = step(abs(fract(p.x / post_pitch) - 0.5) * post_pitch, 0.07);
	vec3 back = mix(skin, skin_low, step(p.y, grey_below));
	// The slat's lower edge throws a thin shadow on the skin.
	float shadow = smoothstep(slat_width / slat_pitch, slat_width / slat_pitch + 0.12, s);
	back *= mix(0.72, 1.0, shadow);
	vec3 col = mix(back, slat, max(on_slat, post * 0.85));
	ALBEDO = col;
	METALLIC = mix(0.0, 0.55, on_slat);
	ROUGHNESS = mix(0.7, 0.38, on_slat);
}
