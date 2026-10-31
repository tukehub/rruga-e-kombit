class_name SkyEnv
extends Node3D
## WorldEnvironment + sun + weather particles driven by Data.ENV presets.
## HDRI (CC0, Poly Haven) per preset; procedural sky as fallback.

const HDRI := {
	"night": "res://assets/hdri/sky_night.hdr",
	"dusk": "res://assets/hdri/sky_dusk.hdr",
	"sunset": "res://assets/hdri/sky_sunset.hdr",
	"day": "res://assets/hdri/sky_day.hdr",
	"golden": "res://assets/hdri/sky_golden.hdr",
	"rain": "res://assets/hdri/sky_overcast.hdr",
	"snow": "res://assets/hdri/sky_overcast.hdr",
}

var world_env: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var rain: GPUParticles3D
var snow: GPUParticles3D
var env_id := "night"
var preset: Dictionary
var wet := 0.0
var night := 0.0


func _ready() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	_make_weather()


func apply(id: String, is_wet_override: bool = false) -> void:
	env_id = id
	preset = Data.ENV[id]
	var is_night := bool(preset.stars) or bool(preset.rain) or bool(preset.snow)
	night = clampf(float(preset.win), 0.0, 1.0)
	wet = 1.0 if (bool(preset.wet) or is_wet_override) else 0.0

	# sky
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var hdri_path: String = HDRI.get(id, "")
	if hdri_path != "" and ResourceLoader.exists(hdri_path):
		var pano := PanoramaSkyMaterial.new()
		pano.panorama = load(hdri_path)
		pano.energy_multiplier = _sky_energy(id)
		sky.sky_material = pano
	else:
		var pm := ProceduralSkyMaterial.new()
		pm.sky_top_color = Data.col(preset.sky_top)
		pm.sky_horizon_color = Data.col(preset.sky_hor)
		pm.ground_bottom_color = Data.col(preset.ground)
		pm.ground_horizon_color = Data.col(preset.sky_hor)
		pm.sun_angle_max = 20.0
		sky.sky_material = pm
	sky.radiance_size = Sky.RADIANCE_SIZE_128 if Quality.preset == "low" else Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.sky_rotation = Vector3(0, _sky_yaw(id), 0)

	# ambient from sky + a floor so night streets are readable
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = float(preset.ambient) * (1.4 if is_night else 0.8)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# tonemap + exposure
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(preset.exposure)
	env.tonemap_white = 4.0

	# bloom with neon threshold (sunlit white stays below the threshold)
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_intensity = 0.45 * float(preset.bloom)
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.15 if is_night else 1.7
	env.glow_hdr_scale = 2.0
	env.glow_hdr_luminance_cap = 12.0

	# fog
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Data.col(preset.fog)
	env.fog_light_energy = 1.0
	env.fog_density = float(preset.fog_density) * 0.35
	env.fog_sky_affect = 0.2 if is_night else 0.35
	env.fog_aerial_perspective = 0.5
	env.fog_height = -20.0
	env.fog_height_density = 0.0
	env.volumetric_fog_density = 0.006 if is_night else 0.0025
	env.volumetric_fog_albedo = Data.col(preset.fog).lightened(0.3)
	env.volumetric_fog_emission = Data.col(preset.fog) * 0.02
	env.volumetric_fog_length = 96.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.3
	env.volumetric_fog_sky_affect = 0.15

	# SSAO/SSR/SDFGI from quality
	env.ssao_radius = 1.5
	env.ssao_intensity = 2.0
	env.ssao_power = 1.5
	env.ssao_detail = 0.3
	env.ssil_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.03
	Quality.apply_env(env, wet > 0.5)

	# sun / moon
	var dir: Vector3 = preset.sun_dir
	sun.look_at_from_position(dir.normalized() * 100.0, Vector3.ZERO, Vector3.UP)
	sun.light_color = Data.col(preset.sun_col)
	sun.light_energy = float(preset.sun_i) * 0.5 * (0.5 if bool(preset.moon) else 1.0)
	sun.light_indirect_energy = 1.0
	# PCSS penumbra: values >= ~0.3 smear PSSM shadows into nothing at this
	# shadow distance, so keep the sun disc small (real sun is 0.26 deg)
	sun.light_angular_distance = 0.15 if not is_night else 0.3
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.9 if not is_night else 0.7
	Quality.apply_sun(sun)

	rain.emitting = bool(preset.rain)
	snow.emitting = bool(preset.snow)
	rain.visible = rain.emitting
	snow.visible = snow.emitting


func _sky_energy(id: String) -> float:
	match id:
		"night": return 0.9
		"rain", "snow": return 0.35
		"dusk": return 0.8
		"sunset": return 0.9
		_: return 1.0


func _sky_yaw(id: String) -> float:
	# rotate the HDRI so its sun roughly matches preset.sun_dir
	match id:
		"sunset": return deg_to_rad(110.0)
		"golden": return deg_to_rad(-70.0)
		"dusk": return deg_to_rad(-100.0)
		_: return 0.0


func _make_weather() -> void:
	rain = GPUParticles3D.new()
	var rm := ParticleProcessMaterial.new()
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rm.emission_box_extents = Vector3(30, 1, 30)
	rm.direction = Vector3(0, -1, 0)
	rm.spread = 3.0
	rm.initial_velocity_min = 22.0
	rm.initial_velocity_max = 28.0
	rm.gravity = Vector3(0, -12, 0)
	rm.scale_min = 0.6
	rm.scale_max = 1.0
	rain.process_material = rm
	rain.amount = 1400
	rain.lifetime = 1.4
	rain.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var drop := BoxMesh.new()
	drop.size = Vector3(0.02, 0.5, 0.02)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.7, 0.8, 1.0, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.emission_enabled = true
	dm.emission = Color(0.6, 0.7, 0.9)
	dm.emission_energy_multiplier = 0.4
	drop.material = dm
	rain.draw_pass_1 = drop
	rain.emitting = false
	add_child(rain)

	snow = GPUParticles3D.new()
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm.emission_box_extents = Vector3(30, 1, 30)
	sm.direction = Vector3(0, -1, 0)
	sm.spread = 25.0
	sm.initial_velocity_min = 1.5
	sm.initial_velocity_max = 3.0
	sm.gravity = Vector3(0, -1.2, 0)
	sm.turbulence_enabled = true
	sm.turbulence_noise_strength = 1.5
	sm.turbulence_noise_scale = 3.0
	sm.scale_min = 0.5
	sm.scale_max = 1.2
	snow.process_material = sm
	snow.amount = 900
	snow.lifetime = 6.0
	snow.visibility_aabb = AABB(Vector3(-40, -30, -40), Vector3(80, 60, 80))
	var flake := SphereMesh.new()
	flake.radius = 0.05
	flake.height = 0.1
	flake.radial_segments = 4
	flake.rings = 2
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.95, 0.96, 1.0, 0.9)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flake.material = fm
	snow.draw_pass_1 = flake
	snow.emitting = false
	add_child(snow)


## Call every frame with the camera position so weather follows the player.
func follow(pos: Vector3) -> void:
	rain.global_position = pos + Vector3(0, 18, 0)
	snow.global_position = pos + Vector3(0, 14, 0)
