shader_type spatial;
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

// Terrain splat: R road, G vegetation, B water, A urban (unused channels are grass/rock by slope).
uniform sampler2D splat : source_color, filter_linear, repeat_disable;
uniform float splat_span = 6000.0;
uniform sampler2D tex_grass : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_urban : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_urban_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_road : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_square : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool skanderbeg_square = false;
uniform float sea_level = -50.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 water_color : source_color = vec3(0.02, 0.09, 0.14);
uniform vec3 grass_tint : source_color = vec3(0.78, 0.86, 0.62);
uniform vec3 urban_tint : source_color = vec3(0.72, 0.70, 0.66);

varying vec3 wpos;
varying vec3 wnrm;
varying float cam_dist;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cam_dist = length((VIEW_MATRIX * vec4(wpos, 1.0)).xyz);
}

// hash based detail noise to break tiling
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 suv = wpos.xz / splat_span + 0.5;
	vec4 sp = texture(splat, suv);
	float in_splat = step(0.0, suv.x) * step(suv.x, 1.0) * step(0.0, suv.y) * step(suv.y, 1.0);
	sp *= in_splat;

	// two-scale texturing: near (4 m tiles) blended with far (40 m tiles)
	vec2 uv_n = wpos.xz / 4.0;
	vec2 uv_f = wpos.xz / 41.0;
	float far_w = clamp((cam_dist - 120.0) / 500.0, 0.0, 1.0);
	float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);

	vec3 grass = mix(texture(tex_grass, uv_n).rgb, texture(tex_grass, uv_f).rgb, far_w) * grass_tint;
	vec3 rock = mix(texture(tex_rock, uv_n).rgb, texture(tex_rock, uv_f).rgb, far_w);
	vec3 urban = mix(texture(tex_urban, uv_n).rgb, texture(tex_urban, uv_f).rgb, far_w) * urban_tint;
	vec3 road = texture(tex_road, uv_n * 0.5).rgb * 0.85;

	vec3 n_grass = mix(texture(tex_grass_n, uv_n).rgb, vec3(0.5, 0.5, 1.0), far_w);
	vec3 n_rock = mix(texture(tex_rock_n, uv_n).rgb, vec3(0.5, 0.5, 1.0), far_w);
	vec3 n_urban = mix(texture(tex_urban_n, uv_n).rgb, vec3(0.5, 0.5, 1.0), far_w);

	float rock_w = smoothstep(0.35, 0.65, slope + (vnoise(wpos.xz * 0.02) - 0.5) * 0.3);
	// high altitude -> rock & snow
	float alt = clamp((wpos.y - 900.0) / 600.0, 0.0, 1.0);
	rock_w = max(rock_w, alt * 0.8);

	vec3 base = mix(grass, rock, rock_w);
	vec3 nrm = mix(n_grass, n_rock, rock_w);
	float rough = mix(0.92, 0.85, rock_w);

	float urban_w = sp.a * (1.0 - rock_w * 0.5);
	base = mix(base, urban, urban_w);
	nrm = mix(nrm, n_urban, urban_w);
	rough = mix(rough, 0.8, urban_w);

	float road_w = smoothstep(0.25, 0.7, sp.r);
	base = mix(base, road, road_w);
	nrm = mix(nrm, vec3(0.5, 0.5, 1.0), road_w);
	rough = mix(rough, 0.75, road_w);

	// vegetation darkens / greens a little
	base = mix(base, base * vec3(0.72, 0.9, 0.6), sp.g * 0.6 * (1.0 - road_w));

	// A geographically placed, softly edged paving area around the monument.
	// The road is separate geometry above the terrain, so this cannot cover it.
	if (skanderbeg_square) {
		vec2 square = abs(wpos.xz - vec2(20.0, -55.0));
		float square_w = (1.0 - smoothstep(76.0, 84.0, square.x))
			* (1.0 - smoothstep(75.0, 83.0, square.y));
		vec3 paving = texture(tex_square, wpos.xz / 5.0).rgb * vec3(0.96, 0.94, 0.89);
		base = mix(base, paving, square_w);
		nrm = mix(nrm, vec3(0.5, 0.5, 1.0), square_w);
		rough = mix(rough, 0.88, square_w);
	}

	// water
	float water_w = max(smoothstep(0.3, 0.8, sp.b), 1.0 - smoothstep(-1.5, 0.5, wpos.y - sea_level));
	base = mix(base, water_color, water_w);
	rough = mix(rough, 0.05, water_w);
	nrm = mix(nrm, vec3(0.5, 0.5, 1.0), water_w);
	float metal = 0.0;

	// snow cover
	float snow_w = snow * smoothstep(0.3, 0.8, wnrm.y) * (1.0 - water_w) * (1.0 - road_w * 0.7);
	snow_w = max(snow_w, alt * (1.0 - water_w) * 0.9);
	base = mix(base, vec3(0.92, 0.94, 0.98), snow_w);
	rough = mix(rough, 0.6, snow_w);

	// wet surfaces darken and sharpen
	float wet_w = wetness * (1.0 - snow_w) * (1.0 - water_w);
	base *= 1.0 - 0.45 * wet_w;
	rough = mix(rough, 0.18, wet_w * (0.6 + 0.4 * road_w));

	// detail variation
	float v = vnoise(wpos.xz * 0.12) * 0.16 + 0.92;
	base *= v;

	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = mix(0.5, 0.7, water_w);
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 0.6;
	// faint urban glow at night for distant city blocks
	EMISSION = vec3(1.0, 0.72, 0.4) * urban_w * night * 0.012 * far_w;
}
