shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
// Skanderbeg Square, points mode: honed limestone/marble slabs, slightly damp.
// A 1K PBR tile set (albedo, roughness, OpenGL normal) laid in world space.
// Each slab of the texture's grid is shuffled, turned 0/90/180/270 degrees
// and given its own tone, so the repeat disappears; broad damp patches lower
// the roughness and darken the stone. Mobile-friendly: 3 texture reads, no
// integer maths, no loops.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

// Texture repeats per metre of ground. One repeat holds sub_grid_divisions^2
// slabs, so slab size = 1 / (tile_scale * sub_grid_divisions) metres.
uniform float tile_scale = 0.2;
// Slabs along each side of the texture (granite_tile_04: a 5 x 5 grid).
uniform float sub_grid_divisions = 5.0;
// Where the texture's first joints lie, in UV (0..1): the grid is not at 0.
uniform vec2 grid_offset = vec2(0.0952, 0.0);

// Lift the scanned stone toward pale Albanian limestone.
uniform vec3 stone_tint : source_color = vec3(1.0, 0.95, 0.86);
uniform float albedo_gain : hint_range(0.5, 3.0) = 1.25;
uniform float tile_brightness_var : hint_range(0.0, 0.5) = 0.14;
uniform float tile_tint_var : hint_range(0.0, 0.3) = 0.08;

uniform float base_roughness : hint_range(0.0, 1.0) = 0.42;
uniform float roughness_variation : hint_range(0.0, 0.5) = 0.12;
// How much of the texture's own roughness detail survives (joints stay matt).
uniform float roughness_detail : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.45;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.35;

// Damp / worn patches: size in metres, how wet and how dark they get.
uniform float macro_scale = 14.0;
uniform float damp_amount : hint_range(0.0, 1.0) = 0.55;
uniform float damp_darkening : hint_range(0.0, 0.5) = 0.18;

varying vec2 ground;

// Integer-free hashes: floor()/fract() only, stable on mediump GPUs.
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec4 hash42(vec2 p) {
	vec4 p4 = fract(vec4(p.xyxy) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float n = sub_grid_divisions;
	// Grid space: whole numbers fall on the texture's joints.
	vec2 g = ground * tile_scale * n - grid_offset * n;
	vec2 cell = floor(g);
	vec2 local = fract(g) - 0.5;
	// Continuous derivatives, taken before the per-slab jumps: no mip seams.
	vec2 dx = dFdx(g);
	vec2 dy = dFdy(g);

	vec4 h = hash42(cell + vec2(17.0, 59.0));
	// Quarter turn 0..3, as a float; cos/sin rounded to exact -1/0/1.
	float turn = floor(h.x * 4.0) * (PI * 0.5);
	float c = round(cos(turn));
	float s = round(sin(turn));
	mat2 rot = mat2(vec2(c, s), vec2(-s, c));
	// Which slab of the texture to borrow: shuffles the repeat.
	vec2 src = floor(h.yz * n);

	vec2 uv = (src + 0.5 + rot * local) / n + grid_offset;
	vec2 uv_dx = (rot * dx) / n;
	vec2 uv_dy = (rot * dy) / n;

	vec3 albedo = textureGrad(albedo_tex, uv, uv_dx, uv_dy).rgb;
	float rough_tex = textureGrad(roughness_tex, uv, uv_dx, uv_dy).r;
	vec2 nxy = textureGrad(normal_tex, uv, uv_dx, uv_dy).rg * 2.0 - 1.0;

	// The sampled normal was turned with the texture: turn it back to the
	// ground's frame. Tangent space y points to -v, so flip around the rotation.
	vec2 n_uv = vec2(nxy.x, -nxy.y);
	n_uv = transpose(rot) * n_uv;
	nxy = vec2(n_uv.x, -n_uv.y);

	// Per-slab tone: brightness +/-14 %, warm/cool +/-8 %.
	float bright = 1.0 + (h.w * 2.0 - 1.0) * tile_brightness_var;
	float warm = hash12(cell + vec2(3.7, 91.3)) * 2.0 - 1.0;
	vec3 tint = vec3(1.0 + warm * tile_tint_var, 1.0, 1.0 - warm * tile_tint_var);

	// Low-frequency damp/worn patches across the whole square.
	vec2 mp = ground / macro_scale;
	float macro = value_noise(mp) * 0.65 + value_noise(mp * 2.7 + 13.1) * 0.35;
	float damp = smoothstep(0.42, 0.78, macro) * damp_amount;

	vec3 col = albedo * albedo_gain * stone_tint * tint * bright;
	col *= 1.0 - damp * damp_darkening;
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));

	// Honed stone around base_roughness; joints keep the texture's matt grout.
	float slab_rough = (hash12(cell + vec2(41.0, 7.0)) * 2.0 - 1.0) * roughness_variation;
	float rough = base_roughness + slab_rough + (rough_tex - 0.77) * roughness_detail;
	rough = mix(rough, rough * 0.55, damp);
	ROUGHNESS = clamp(rough, 0.08, 1.0);
	METALLIC = 0.0;
	SPECULAR = specular_amount;

	// Ground frame for the normal map: u along world +X, v along world +Z.
	TANGENT = normalize((VIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	BINORMAL = normalize((VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	NORMAL_MAP = vec3(nxy * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - damp * 0.4);
}
