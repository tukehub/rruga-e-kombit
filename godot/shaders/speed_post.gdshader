shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 delta = SCREEN_UV - vec2(0.5, 0.46);
	// Preserve the car and the road ahead; peripheral cues carry the speed.
	float edge = smoothstep(0.15, 0.65, length(delta));
	vec2 offset = delta * edge * strength * 0.018;
	vec3 color = texture(screen_texture, SCREEN_UV).rgb * 0.4;
	color += texture(screen_texture, SCREEN_UV - offset).rgb * 0.3;
	color += texture(screen_texture, SCREEN_UV - offset * 2.0).rgb * 0.2;
	color += texture(screen_texture, SCREEN_UV - offset * 3.0).rgb * 0.1;
	vec2 chroma = offset * 0.12;
	color.r += (texture(screen_texture, SCREEN_UV + chroma).r - texture(screen_texture, SCREEN_UV).r) * 0.35;
	color.b += (texture(screen_texture, SCREEN_UV - chroma).b - texture(screen_texture, SCREEN_UV).b) * 0.35;
	color *= 1.0 - edge * edge * strength * 0.13;
	COLOR = vec4(color, 1.0);
}
