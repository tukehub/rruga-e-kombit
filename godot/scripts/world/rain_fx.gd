class_name RainFx
extends Node3D
## Rain drawn by two shader-driven meshes: falling streaks in a box that wraps
## around the camera, and splash crowns on the road. Nothing is simulated on
## the CPU; each quad is placed by its shader from a random per-quad seed.

const STREAK_SHADER := preload("res://shaders/rain_streak.gdshader")
const SPLASH_SHADER := preload("res://shaders/rain_splash.gdshader")

## Same switches the old particle rain exposed, so SkyEnv drives both alike.
var emitting := false
var amount_ratio := 1.0
var level := 0.0
var _streak_mat: ShaderMaterial
var _splash_mat: ShaderMaterial
var _last_cam := Vector3.ZERO
var _cam_velocity := Vector3.ZERO
var _has_cam := false


func _init() -> void:
	var streaks := 8000
	var splashes := 800
	if Quality.preset == "low":
		streaks = 2500
		splashes = 250
	elif Quality.preset == "medium":
		streaks = 4500
		splashes = 450
	_streak_mat = ShaderMaterial.new()
	_streak_mat.shader = STREAK_SHADER
	_splash_mat = ShaderMaterial.new()
	_splash_mat.shader = SPLASH_SHADER
	add_child(_layer(_seed_quads(streaks, 11), _streak_mat))
	add_child(_layer(_seed_quads(splashes, 23), _splash_mat))
	_streak_mat.set_shader_parameter("rain", 0.0)
	_splash_mat.set_shader_parameter("rain", 0.0)


## `count` unit quads (x -0.5..0.5, y 0..1), each with four random numbers
## stored in UV and UV2 for its shader.
static func _seed_quads(count: int, rng_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var corners := [Vector3(-0.5, 0.0, 0.0), Vector3(0.5, 0.0, 0.0), Vector3(-0.5, 1.0, 0.0), Vector3(0.5, 1.0, 0.0)]
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize(count * 4)
	uv.resize(count * 4)
	uv2.resize(count * 4)
	idx.resize(count * 6)
	for i in count:
		var a := Vector2(rng.randf(), rng.randf())
		var b := Vector2(rng.randf(), rng.randf())
		var o := i * 4
		for c in 4:
			verts[o + c] = corners[c]
			uv[o + c] = a
			uv2[o + c] = b
		idx[i * 6] = o
		idx[i * 6 + 1] = o + 1
		idx[i * 6 + 2] = o + 2
		idx[i * 6 + 3] = o + 2
		idx[i * 6 + 4] = o + 1
		idx[i * 6 + 5] = o + 3
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _layer(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	# The shader moves every vertex, so the mesh bounds mean nothing.
	mi.custom_aabb = AABB(Vector3(-100000.0, -100000.0, -100000.0), Vector3(200000.0, 200000.0, 200000.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mi


## `to_sun` points towards the light; colours are the scene's sun and haze.
func set_light(to_sun: Vector3, sun: Color, haze: Color) -> void:
	var sun_linear := sun.srgb_to_linear()
	var haze_linear := haze.srgb_to_linear()
	var sun_v := Vector3(sun_linear.r, sun_linear.g, sun_linear.b) * 0.5
	# Never fully dark: night rain still has to read against the road.
	var ambient_v := Vector3(maxf(haze_linear.r * 0.35, 0.09), maxf(haze_linear.g * 0.35, 0.10), maxf(haze_linear.b * 0.35, 0.12))
	for mat: ShaderMaterial in [_streak_mat, _splash_mat]:
		mat.set_shader_parameter("to_sun", to_sun.normalized())
		mat.set_shader_parameter("sun_light", sun_v)
		mat.set_shader_parameter("ambient_light", ambient_v)


## The road under the player: a point on it and the direction it runs in.
func set_ground(origin: Vector3, tangent: Vector3) -> void:
	var flat := Vector2(tangent.x, tangent.z)
	var run := flat.length()
	var grad := Vector2.ZERO
	if run > 0.001:
		grad = flat / run * (tangent.y / run)
	_splash_mat.set_shader_parameter("ground_origin", origin)
	_splash_mat.set_shader_parameter("ground_grad", grad)


func _process(dt: float) -> void:
	var target := clampf(amount_ratio, 0.0, 1.0) if emitting else 0.0
	level = move_toward(level, target, dt * 0.8)
	_streak_mat.set_shader_parameter("rain", level)
	_splash_mat.set_shader_parameter("rain", level)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pos := cam.global_position
	if _has_cam and dt > 0.0001:
		var v := (pos - _last_cam) / dt
		# A camera cut is not motion.
		if v.length() > 120.0:
			v = Vector3.ZERO
		_cam_velocity = _cam_velocity.lerp(v, minf(1.0, dt * 10.0))
	_last_cam = pos
	_has_cam = true
	_streak_mat.set_shader_parameter("camera_velocity", _cam_velocity)
	var pixels := maxf(1.0, float(DisplayServer.window_get_size().y) * get_viewport().scaling_3d_scale)
	_streak_mat.set_shader_parameter("pixel_size", 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / pixels)
