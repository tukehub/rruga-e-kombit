// Livery mask (README 6.3): a transparent artwork atlas projected
// onto the body from above and from the sides, in mesh space. Four tiles
// across; row 0 is the view from above, row 1 the view from the side.
uniform sampler2D livery_atlas : source_color, filter_linear, repeat_disable;
uniform int livery_tile = -1;
uniform vec4 livery_color : source_color = vec4(1.0);
uniform vec3 body_min = vec3(-0.98, 0.09, -2.18);
uniform vec3 body_size = vec3(1.96, 1.06, 4.39);

varying vec3 livery_pos;
varying vec3 livery_normal;

vec4 livery_decal() {
	if (livery_tile < 0) {
		return vec4(0.0);
	}
	vec3 q = clamp((livery_pos - body_min) / body_size, vec3(0.004), vec3(0.996));
	vec3 n = normalize(livery_normal);
	float column = float(livery_tile);
	vec2 top_uv = vec2((column + q.x) * 0.25, q.z * 0.5);
	vec2 side_uv = vec2((column + q.z) * 0.25, 0.5 + (1.0 - q.y) * 0.5);
	vec4 top = texture(livery_atlas, top_uv);
	vec4 side = texture(livery_atlas, side_uv);
	top.a *= smoothstep(0.35, 0.65, n.y);
	side.a *= smoothstep(0.12, 0.4, abs(n.x));
	vec4 ink = top.a > side.a ? top : side;
	// White artwork takes the contrasting ink chosen for the base coat.
	// Coloured pinlines keep their authored colour across all paint choices.
	float chroma = max(max(ink.r, ink.g), ink.b) - min(min(ink.r, ink.g), ink.b);
	return vec4(mix(livery_color.rgb, ink.rgb, smoothstep(0.02, 0.20, chroma)), ink.a);
}
