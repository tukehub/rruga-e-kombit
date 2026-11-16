extends Node
## Quality presets (low / medium / high) and device auto-detection.
## World builders read the exported fields; environments/viewports get
## configured through apply_*().
##
## Renderer truth: Android ships Godot's Mobile renderer and desktop runs
## Forward+ (project.godot, rendering_method[.mobile]). PRESETS say what a
## tier asks for; `p` is what the active renderer and the current pressure
## stage actually deliver. Read `p`, never PRESETS, and never ask the
## RenderingServer which renderer is running: `renderer` already says.

signal preset_changed(preset: String)
signal budget_changed
const Governor = preload("res://scripts/game/performance_governor.gd")

## Godot 4.4 runs these under Forward+ only; Mobile and Compatibility ignore
## them without an error, so `p` switches them off there.
const FORWARD_PLUS_ONLY: Array[String] = ["ssao", "sdfgi", "ssr", "vol_fog", "sun_penumbra"]
## Mobile and Compatibility light one mesh with at most eight omni lights.
## The road is one mesh, so street lamps and combat lights share those eight.
## Forward+ clusters lights and has no such cap.
const OMNI_LIGHTS_PER_MESH := 8
const SPOT_LIGHTS_PER_MESH := 8
const MESH_OMNI_SHARE := {"lamp_lights": 6, "fx_light_limit": 2}

const PRESETS := {
	"low": {
		"scale": 0.7, "msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"ssao": false, "ssao_q": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "sdfgi": false, "ssr": false, "ssr_steps": 16,
		"vol_fog": false, "glow": true, "glow_levels": 2,
		"shadow_size": 1024, "shadow_splits": 1, "shadow_dist": 70.0, "car_shadows": false,
		"building_dist": 600.0, "tree_mul": 0.35, "lamp_lights": 0, "probe": false, "wet_reflections": false,
		"props_dist": 350.0, "anisotropy": 1, "max_fps": 60,
	},
	"medium": {
		"scale": 0.8, "msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"ssao": true, "ssao_q": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "sdfgi": false, "ssr": true, "ssr_steps": 24,
		"vol_fog": false, "glow": true, "glow_levels": 3,
		"shadow_size": 2048, "shadow_splits": 1, "shadow_dist": 80.0, "car_shadows": false,
		"building_dist": 1000.0, "tree_mul": 0.6, "lamp_lights": 6, "probe": true, "wet_reflections": true,
		"props_dist": 600.0, "anisotropy": 2, "max_fps": 60,
	},
	"high": {
		"scale": 1.0, "msaa": Viewport.MSAA_2X, "fxaa": false,
		"ssao": true, "ssao_q": RenderingServer.ENV_SSAO_QUALITY_LOW, "sdfgi": true, "ssr": true, "ssr_steps": 48,
		"vol_fog": true, "glow": true, "glow_levels": 4,
		"shadow_size": 4096, "shadow_splits": 4, "shadow_dist": 220.0, "car_shadows": true,
		"building_dist": 2400.0, "tree_mul": 1.0, "lamp_lights": 14, "probe": true, "wet_reflections": true,
		"props_dist": 1000.0, "anisotropy": 4, "max_fps": 60,
	},
}

var preset := "medium"
var p: Dictionary = PRESETS.medium
var detected := "medium"
var detect_reason := ""
## "forward_plus" (desktop), "mobile" (Android) or "gl_compatibility" (fallback).
var renderer := "forward_plus"
var frame_target := 60
var adaptive_enabled := true
var pressure_stage := 0
var governor := Governor.new()
var _settings_signature := {}


func _ready() -> void:
	renderer = RenderingServer.get_current_rendering_method()
	detected = detect()
	configure_from_settings()
	Settings.changed.connect(configure_from_settings)


func configure_from_settings() -> void:
	var signature := {"quality": Settings.quality, "fps": Settings.frame_target, "adaptive": Settings.adaptive_quality}
	if signature == _settings_signature:
		return
	_settings_signature = signature
	frame_target = 30 if Settings.frame_target == 30 else 60
	adaptive_enabled = Settings.adaptive_quality
	set_preset(Settings.quality)


func set_preset(name: String) -> void:
	var want := name
	if want == "auto" or not PRESETS.has(want):
		want = detected
	preset = want
	pressure_stage = 0
	governor.reset(frame_target)
	_derive_budget()
	preset_changed.emit(preset)
	budget_changed.emit()


func _derive_budget() -> void:
	p = PRESETS[preset].duplicate(true)
	var stage := pressure_stage
	p.scale = maxf(0.6, float(p.scale) * [1.0, 0.9, 0.8, 0.7][stage])
	p.max_fps = frame_target
	p.rain_density = [1.0, 0.85, 0.65, 0.45][stage] * (0.8 if frame_target == 30 else 1.0)
	p.mirror_interval = 3 + stage
	p.mirror_width = 256 if stage == 0 else (192 if stage == 1 else 128)
	p.fx_extras = preset != "low" and stage < 2
	p.paint_flakes = p.fx_extras
	p.speed_post = p.fx_extras
	p.driving_cars = maxi(0, {"low": 0, "medium": 2, "high": 3}[preset] - stage) if stage < 2 else 0
	p.fx_flash_limit = maxi(2, {"low": 3, "medium": 5, "high": 8}[preset] - stage * 2)
	p.fx_ring_limit = maxi(0, {"low": 2, "medium": 4, "high": 6}[preset] - stage * 2)
	p.fx_light_limit = maxi(0, {"low": 0, "medium": 2, "high": 4}[preset] - stage)
	p.fx_sparks = stage < 2 and preset != "low"
	p.lamp_lights = mini(int(p.lamp_lights), [14, 6, 3, 2][stage])
	p.shadow_dist = maxf(50.0, float(p.shadow_dist) * (1.0 - stage * 0.15))
	if stage >= 2:
		p.msaa = Viewport.MSAA_DISABLED
		p.fxaa = true
		p.car_shadows = false
		p.shadow_splits = 1
		p.shadow_size = mini(1024, int(p.shadow_size))
		p.ssr = false
		p.vol_fog = false
	if stage >= 3:
		p.sdfgi = false
		p.ssao = false
	# Soft sun shadows cost a penumbra search; only an unpressured high tier pays.
	p.sun_penumbra = preset == "high" and stage == 0
	if renderer != "forward_plus":
		for key in FORWARD_PLUS_ONLY:
			p[key] = false
		for key in MESH_OMNI_SHARE:
			p[key] = mini(int(p[key]), int(MESH_OMNI_SHARE[key]))
	Engine.max_fps = frame_target


func observe_frame(dt: float, active := true) -> void:
	if adaptive_enabled and governor.observe(dt, active):
		set_pressure_stage(governor.stage)


func set_pressure_stage(stage: int) -> void:
	pressure_stage = clampi(stage, 0, Governor.MAX_STAGE)
	governor.stage = pressure_stage
	_derive_budget()
	budget_changed.emit()


func reset_observation(grace := Governor.WARMUP) -> void:
	governor.reset(frame_target, true, grace)


func snapshot() -> Dictionary:
	var result := governor.snapshot()
	result.merge({"preset": preset, "adaptive": adaptive_enabled, "render_scale": p.scale,
		"rain_density": p.rain_density, "mirror_interval": p.mirror_interval,
		"mirror_width": p.mirror_width, "fx_light_limit": p.fx_light_limit,
		"lamp_lights": p.lamp_lights, "renderer": renderer}, true)
	result.merge({"paint_flakes": p.paint_flakes, "speed_post": p.speed_post, "driving_cars": p.driving_cars})
	# What the renderer was really asked to draw, for PROFILE comparisons.
	for key in FORWARD_PLUS_ONLY:
		result[key] = bool(p[key])
	return result


## Rough device tiering from GPU name and RAM. Desktop always high.
func detect() -> String:
	var os_name := OS.get_name()
	var ram_gb := float(OS.get_memory_info().get("physical", 0)) / (1024.0 * 1024.0 * 1024.0)
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	detect_reason = "%s / %.1f GB" % [gpu, ram_gb]
	if os_name != "Android" and os_name != "iOS":
		return "high"
	var tier := 1
	var re := RegEx.new()
	re.compile("adreno[^0-9]*(\\d{3})")
	var m := re.search(gpu)
	if m:
		var num := int(m.get_string(1))
		tier = 2 if num >= 730 else (1 if num >= 640 else 0)
	elif gpu.find("xclipse") >= 0:
		re.compile("xclipse[^0-9]*(\\d{3})")
		m = re.search(gpu)
		var num := int(m.get_string(1)) if m else 500
		tier = 2 if num >= 900 else 1
	elif gpu.find("immortalis") >= 0:
		tier = 2
	elif gpu.find("mali") >= 0:
		re.compile("mali-g(\\d+)")
		m = re.search(gpu)
		var num := int(m.get_string(1)) if m else 50
		tier = 2 if num >= 715 else (1 if num >= 68 else 0)
	elif gpu.find("powervr") >= 0:
		tier = 0
	if ram_gb > 0.0 and ram_gb < 5.5:
		tier = mini(tier, 0)
	elif ram_gb > 0.0 and ram_gb < 7.5:
		tier = mini(tier, 1)
	# Auto mode stops at medium on a phone. High there means native
	# resolution, MSAA, a 4096 shadow atlas in four cascades and car shadows
	# (no GI: the Mobile renderer has none); players may still select it.
	return ["low", "medium", "high"][mini(tier, 1)]


func apply_viewport(vp: Viewport) -> void:
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = float(p.scale)
	vp.msaa_3d = p.msaa
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if p.fxaa else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = true
	vp.positional_shadow_atlas_size = 1024 if preset == "low" else 2048
	vp.anisotropic_filtering_level = p.anisotropy


func apply_env(env: Environment, wet: bool) -> void:
	env.ssao_enabled = bool(p.ssao)
	env.sdfgi_enabled = bool(p.sdfgi)
	if env.sdfgi_enabled:
		env.sdfgi_cascades = 4
		env.sdfgi_min_cell_size = 0.5
		env.sdfgi_use_occlusion = true
		# sky light read by SDFGI blows out upward-facing surfaces (car roofs);
		# keep the sky in the regular ambient term and let SDFGI do sun bounce only
		env.sdfgi_read_sky_light = false
		env.sdfgi_energy = 0.35
		env.sdfgi_bounce_feedback = 0.2
	env.ssr_enabled = bool(p.ssr) and wet
	env.ssr_max_steps = int(p.ssr_steps)
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.3
	env.volumetric_fog_enabled = bool(p.vol_fog)
	env.glow_enabled = bool(p.glow)
	for i in 7:
		env.set_glow_level(i, 1.0 if i < int(p.glow_levels) else 0.0)
	RenderingServer.environment_set_ssao_quality(p.ssao_q, true, 0.5, 2, 50.0, 300.0)


func apply_sun(sun: DirectionalLight3D) -> void:
	var splits := int(p.shadow_splits)
	if splits >= 4:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	elif splits == 2:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = float(p.shadow_dist)
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	sun.directional_shadow_blend_splits = splits > 1
	sun.directional_shadow_fade_start = 0.8
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.5
	RenderingServer.directional_shadow_atlas_set_size(int(p.shadow_size), true)
