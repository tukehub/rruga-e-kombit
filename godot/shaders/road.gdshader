shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

// UV: x = metres across the centreline (negative left), y = metres along the lap.
uniform sampler2D tex_asphalt : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_asphalt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_asphalt_r : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float half_w = 10.0;
uniform float track_len = 5000.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 asphalt_tint : source_color = vec3(0.90, 0.92, 0.96);
uniform vec3 line_white : source_color = vec3(0.9, 0.9, 0.86);
uniform vec3 line_yellow : source_color = vec3(0.95, 0.75, 0.2);
uniform float lane_count = 4.0;
uniform float start_s = 0.0;

varying vec2 ruv;
varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	ruv = UV;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float across = ruv.x;
	float along = ruv.y;
	vec2 tuv = vec2(across, along) / 5.0;
	// second asphalt sample rotated to kill repetition
	vec2 tuv2 = vec2(along, -across) / 7.3;
	vec3 asphalt = mix(texture(tex_asphalt, tuv).rgb, texture(tex_asphalt, tuv2).rgb, 0.5) * asphalt_tint;
	vec3 n1 = texture(tex_asphalt_n, tuv).rgb;
	vec3 n2 = texture(tex_asphalt_n, tuv2).rgb;
	// The second sample's UVs are rotated 90 degrees; rotate its tangent-space
	// direction back before blending or the surface grain lights incorrectly.
	vec3 nrm = mix(n1, vec3(1.0 - n2.g, n2.r, n2.b), 0.5);
	float rough = texture(tex_asphalt_r, tuv).r * 0.45 + 0.5;

	// darker tyre tracks in the lanes
	float lane_w = 2.0 * half_w / lane_count;
	float lane_pos = fract((across + half_w) / lane_w);
	float wear = exp(-pow((lane_pos - 0.3) * 6.0, 2.0)) + exp(-pow((lane_pos - 0.7) * 6.0, 2.0));
	asphalt *= 1.0 - 0.09 * wear;

	// lane markings: dashed white between lanes, solid yellow centre, solid white edges
	float edge = 1.0 - smoothstep(0.15, 0.25, abs(abs(across) - (half_w - 0.35)));
	float centre = 1.0 - smoothstep(0.12, 0.22, abs(across));
	float dash = step(0.5, fract(along / 6.0));
	float lane_line = 0.0;
	for (int i = 1; i < 4; i++) {
		float lx = -half_w + float(i) * lane_w;
		if (abs(float(i) * 2.0 - lane_count) < 0.5) continue; // centre handled separately
		lane_line = max(lane_line, (1.0 - smoothstep(0.1, 0.18, abs(across - lx))) * dash);
	}
	vec3 col = asphalt;
	float mark = max(edge, max(lane_line, centre));
	// Paint wear noise is only evaluated on the markings themselves.
	if (mark > 0.0) {
		float worn = 0.78 + 0.20 * vnoise(vec2(across, along) * 1.7);
		col = mix(col, line_white * worn, edge * 0.9);
		col = mix(col, line_white * worn, lane_line * 0.85);
		col = mix(col, line_yellow * worn, centre * 0.9);
		rough = mix(rough, 0.55, mark);
	}

	// start / finish chequer band 6 m long
	float ds = along - start_s;
	ds = ds - track_len * floor(ds / track_len);
	if (ds < 6.0 && ds > 0.0) {
		float cx = floor(across / 1.0);
		float cy = floor(ds / 1.0);
		float chk = mod(cx + cy, 2.0);
		col = mix(col, mix(vec3(0.05), vec3(0.9), chk), 0.9);
		rough = 0.55;
	}

	// puddles: low frequency noise, concentrate near edges. A dry road skips
	// the noise entirely.
	float wet = 0.0;
	if (wetness > 0.001) {
		float pud = vnoise(vec2(across, along) * 0.11) * 0.6 + vnoise(vec2(along, across) * 0.37) * 0.4;
		float puddle = smoothstep(0.62 - 0.25 * wetness, 0.72 - 0.25 * wetness, pud) * wetness;
		puddle *= 0.5 + 0.5 * smoothstep(0.2, 0.8, abs(across) / half_w);
		wet = wetness * 0.75 + puddle;
		col *= 1.0 - 0.25 * clamp(wet, 0.0, 1.0);
		rough = mix(rough, 0.08, clamp(wet, 0.0, 1.0));
		rough = mix(rough, 0.03, puddle);
		nrm = mix(nrm, vec3(0.5, 0.5, 1.0), puddle);
	}

	// snow slush on the sides
	if (snow > 0.001) {
		float slush = snow * smoothstep(0.55, 0.95, abs(across) / half_w);
		col = mix(col, vec3(0.85, 0.87, 0.9), slush);
		rough = mix(rough, 0.6, slush);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = mix(0.5, 0.8, wet);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = mix(0.45, 0.2, clamp(wet, 0.0, 1.0));
}
