shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Spectators around the arena: one MultiMesh, one draw call. Each person
// hops and waves both raised arms on their own beat.
// UV.x tags the part: 0 head, 1 shirt, 2 left arm, 3 right arm, 4 trousers.
// Instance colour: skin tone. Vertex colour: trousers.
// INSTANCE_CUSTOM: rgb shirt colour, a beat phase.

uniform float hop_height = 0.16;
uniform float wave_angle = 0.3;

varying vec3 tint;

vec3 swing(vec3 v, vec2 pivot, float angle) {
	vec2 p = v.xy - pivot;
	float c = cos(angle);
	float s = sin(angle);
	return vec3(vec2(p.x * c - p.y * s, p.x * s + p.y * c) + pivot, v.z);
}

void vertex() {
	float phase = INSTANCE_CUSTOM.a;
	float rate = 5.0 + 3.0 * fract(phase * 7.31);
	float beat = TIME * rate + phase * 6.2832;
	float part = UV.x;
	if (part > 1.5 && part < 2.5) {
		VERTEX = swing(VERTEX, vec2(-0.25, 1.38), sin(beat) * wave_angle);
	} else if (part > 2.5) {
		VERTEX = swing(VERTEX, vec2(0.25, 1.38), -sin(beat + 0.9) * wave_angle);
	}
	float hop = max(0.0, sin(beat * 0.5));
	VERTEX.y += hop * hop * hop_height;
	// Skin from the instance colour; trousers from the vertex colour.
	vec3 skin = COLOR.rgb;           // vertex white x instance skin tone
	tint = skin;
	if (part > 0.5 && part < 1.5) {
		tint = INSTANCE_CUSTOM.rgb;
	} else if (part > 3.5) {
		tint = vec3(0.13, 0.14, 0.19);
	}
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
}
