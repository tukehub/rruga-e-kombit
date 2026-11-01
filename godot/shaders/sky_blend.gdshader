shader_type sky;
uniform sampler2D from_sky : source_color, filter_linear, repeat_enable;
uniform sampler2D to_sky : source_color, filter_linear, repeat_enable;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform float from_energy = 1.0;
uniform float to_energy = 1.0;
uniform float from_yaw = 0.0;
uniform float to_yaw = 0.0;
void sky() {
 vec2 a = SKY_COORDS + vec2(from_yaw / TAU, 0.0);
 vec2 b = SKY_COORDS + vec2(to_yaw / TAU, 0.0);
 COLOR = mix(texture(from_sky, a).rgb * from_energy, texture(to_sky, b).rgb * to_energy, blend);
}
