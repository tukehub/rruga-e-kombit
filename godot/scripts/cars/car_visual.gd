class_name CarVisual
extends Node3D
## Renders one CarState: GLB model (body + 4 wheel nodes), paint/glass/light
## materials, wheel spin/steer, hop/spin/wreck motion, brake lights, shield.
## Sim frame: d>0 and yaw>0 are towards the track normal N = (-tz, tx) = RIGHT,
## so Godot yaw (counter-clockwise positive) = atan2(-tx, -tz) - yaw.

static var shared: Dictionary = {}
static var _sport_checked := false
static var _sport_scene: PackedScene
const CONTACT_SHADER := preload("res://shaders/car_contact.gdshader")
const SPORT_SHADER := preload("res://shaders/sport_car.gdshader")

var def: Dictionary
var is_player := false
var color := Color.WHITE
var model: Node3D
var body: MeshInstance3D
var wheels: Dictionary = {}  # name -> MeshInstance3D
var mat_paint: StandardMaterial3D
var sport_paint: ShaderMaterial
var mat_rear: StandardMaterial3D
var mat_front: StandardMaterial3D
var shield: MeshInstance3D
var head_l: SpotLight3D
var head_r: SpotLight3D
var spin := 0.0
var steer_vis := 0.0
var night := 0.0
var nitro_jets: Array[MeshInstance3D] = []
var blink := 0.0
var wreck_roll := 0.0
var base_pos := Vector3.ZERO
var contact_shadow: MeshInstance3D
var visual_wheel_radius := 0.36
var visual_wheelbase := 2.7
var finish_driver: Node3D
var finish_glass: StandardMaterial3D


func setup(p_def: Dictionary, p_color: Color, p_is_player: bool) -> void:
	def = p_def
	color = p_color
	is_player = p_is_player
	var scene := _load_car_scene(str(def.model))
	model = scene.instantiate()
	add_child(model)
	for ch in model.get_children():
		if ch is MeshInstance3D:
			if ch.name == "body":
				body = ch
			elif String(ch.name).begins_with("wheel"):
				wheels[String(ch.name)] = ch
			ch.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			_override_materials(ch)
	if wheels.has("wheel_rl"):
		var rear: MeshInstance3D = wheels["wheel_rl"]
		if rear.mesh != null:
			visual_wheel_radius = maxf(0.05, rear.mesh.get_aabb().size.y * 0.5)
		if wheels.has("wheel_fl"):
			var front: MeshInstance3D = wheels["wheel_fl"]
			visual_wheelbase = maxf(0.1, absf(front.position.z - rear.position.z))
	_make_contact_shadow()
	_make_nitro()
	_make_shield()
	if is_player:
		_make_finish_driver()
		_make_headlights()
	_apply_car_shadows()
	if not Quality.preset_changed.is_connected(_apply_car_shadows):
		Quality.preset_changed.connect(_apply_car_shadows)


func _apply_car_shadows(_preset: String = "") -> void:
	var shadow_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(Quality.p.car_shadows) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for root in [model, finish_driver]:
		if root == null:
			continue
		for child in root.get_children():
			if child is GeometryInstance3D:
				child.cast_shadow = shadow_mode


static func _load_car_scene(fallback: String) -> PackedScene:
	# Licensed car resources can be staged privately at build time. Load once
	# for all six vehicles; public builds retain the existing open asset.
	if not _sport_checked:
		_sport_checked = true
		var path := "res://assets/private_car/vortex_sport.bin"
		var key_path := "res://assets/private_car/car_key.gd"
		if FileAccess.file_exists(path) and ResourceLoader.exists(key_path):
			var key_script = load(key_path)
			var file := FileAccess.open_encrypted(path, FileAccess.READ, key_script.key())
			if file != null:
				var document := GLTFDocument.new()
				var state := GLTFState.new()
				if document.append_from_buffer(file.get_buffer(file.get_length()), "", state) == OK:
					var node := document.generate_scene(state)
					if node != null:
						var packed := PackedScene.new()
						if packed.pack(node) == OK:
							_sport_scene = packed
						node.free()
	if _sport_scene != null:
		return _sport_scene
	return load(fallback) as PackedScene


func _make_contact_shadow() -> void:
	# A small unlit road-contact shadow remains visible even on low quality,
	# where real-time car shadows are disabled. One quad per car, no light.
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.3, 4.8)
	contact_shadow = MeshInstance3D.new()
	contact_shadow.mesh = plane
	contact_shadow.material_override = _shared("contact_shadow", func():
		var material := ShaderMaterial.new()
		material.shader = CONTACT_SHADER
		return material)
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	contact_shadow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(contact_shadow)


func _override_materials(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nm := m.resource_name if m else ""
		var ov: Material = null
		match nm:
			"paint": ov = _paint(m)
			"sport_body":
				if m is BaseMaterial3D and m.albedo_texture != null:
					sport_paint = ShaderMaterial.new()
					sport_paint.shader = SPORT_SHADER
					sport_paint.set_shader_parameter("atlas", m.albedo_texture)
					sport_paint.set_shader_parameter("paint_color", color)
					ov = sport_paint
			"glass":
				if is_player:
					if finish_glass == null:
						finish_glass = _mk_glass()
						# Prepare the transparent shader while racing, rather than
						# switching shader variants at the finish line.
						finish_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					ov = finish_glass
				else:
					ov = _shared("glass", _mk_glass)
			"light_front": ov = _front()
			"light_rear": ov = _rear()
			"trim": ov = _shared("trim", func(): return _mk_simple(Color(0.05, 0.05, 0.055), 0.0, 0.7))
			"chrome": ov = _shared("chrome", func(): return _mk_simple(Color(0.9, 0.9, 0.92), 1.0, 0.12))
			"interior": ov = _shared("interior", func(): return _mk_simple(Color(0.07, 0.07, 0.08), 0.0, 0.95))
			"tyre": ov = _shared("tyre", func(): return _mk_simple(Color(0.035, 0.035, 0.04), 0.0, 0.9))
			"rim": ov = _shared("rim", func(): return _mk_simple(Color(0.48, 0.50, 0.53), 0.7, 0.38))
			"brake": ov = _shared("brake", func(): return _mk_simple(Color(0.75, 0.12, 0.08), 0.3, 0.5))
			"plate": ov = _shared("plate", func(): return _mk_simple(Color(0.95, 0.95, 0.9), 0.0, 0.5))
		if ov:
			mi.set_surface_override_material(i, ov)


func _make_finish_driver() -> void:
	# Lightweight helmeted driver, revealed through the windscreen at the finish.
	finish_driver = Node3D.new()
	finish_driver.name = "FinishDriver"
	finish_driver.position = Vector3(-0.35, 0.0, -0.05)
	# The opaque windshield hides the driver until its alpha changes at finish.
	# Keeping these meshes active avoids introducing them during the camera move.
	finish_driver.visible = true
	add_child(finish_driver)
	var suit := _shared("driver_suit", func(): return _mk_simple(Color(0.28, 0.31, 0.35), 0.0, 0.72))
	var helmet := _shared("driver_helmet", func(): return _mk_simple(Color(0.83, 0.85, 0.88), 0.08, 0.38))
	var visor := _shared("driver_visor", func(): return _mk_simple(Color(0.025, 0.04, 0.065), 0.2, 0.2))
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.18
	torso_mesh.height = 0.48
	var torso := MeshInstance3D.new()
	torso.mesh = torso_mesh
	torso.material_override = suit
	torso.position = Vector3(0, 0.64, 0.05)
	torso.rotation.x = -0.18
	finish_driver.add_child(torso)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.145
	head_mesh.height = 0.30
	head_mesh.radial_segments = 16
	head_mesh.rings = 8
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = helmet
	head.position = Vector3(0, 0.94, 0.07)
	finish_driver.add_child(head)
	var face_mesh := BoxMesh.new()
	face_mesh.size = Vector3(0.21, 0.09, 0.06)
	var face := MeshInstance3D.new()
	face.mesh = face_mesh
	face.material_override = visor
	face.position = Vector3(0, 0.95, -0.06)
	finish_driver.add_child(face)
	for side in [-1.0, 1.0]:
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.055
		arm_mesh.height = 0.38
		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = suit
		arm.position = Vector3(side * 0.15, 0.70, -0.12)
		arm.rotation.x = -0.85
		arm.rotation.z = side * 0.25
		finish_driver.add_child(arm)


func show_finish_driver() -> void:
	if finish_driver:
		finish_driver.visible = true
	if finish_glass:
		finish_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		finish_glass.albedo_color = Color(0.16, 0.22, 0.27, 0.20)
		finish_glass.metallic = 0.0
		finish_glass.roughness = 0.22


func _shared(key: String, maker: Callable) -> Material:
	if not shared.has(key):
		shared[key] = maker.call()
	return shared[key]


static func _mk_simple(col: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	return m


static func _mk_glass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.20, 0.28)
	m.metallic = 0.18
	m.metallic_specular = 0.6
	m.roughness = 0.12
	m.clearcoat_enabled = true
	m.clearcoat = 0.5
	m.clearcoat_roughness = 0.05
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.render_priority = 1
	return m


func _paint(source: Material = null) -> StandardMaterial3D:
	if mat_paint == null:
		# Each car retains its own tint with a softer satin-clearcoat finish.
		mat_paint = source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
		# Daylight and ACES compress bright paint toward pastel; use a richer
		# base coat and restrained neutral reflections. Preserve white paint.
		var white_paint := color.s < 0.15 and color.v > 0.8
		mat_paint.albedo_color = color.darkened(0.05 if white_paint else 0.30)
		mat_paint.metallic = 0.16
		mat_paint.metallic_specular = 0.22
		mat_paint.roughness = 0.48
		mat_paint.clearcoat_enabled = true
		mat_paint.clearcoat = 0.16
		mat_paint.clearcoat_roughness = 0.38
	return mat_paint


func _front() -> StandardMaterial3D:
	if mat_front == null:
		mat_front = StandardMaterial3D.new()
		mat_front.albedo_color = Color(0.85, 0.9, 1.0)
		mat_front.roughness = 0.15
		mat_front.metallic = 0.4
		mat_front.emission_enabled = true
		mat_front.emission = Color(0.9, 0.95, 1.0)
		mat_front.emission_energy_multiplier = 1.1
	return mat_front


func _rear() -> StandardMaterial3D:
	if mat_rear == null:
		mat_rear = StandardMaterial3D.new()
		mat_rear.albedo_color = Color(0.5, 0.03, 0.03)
		mat_rear.roughness = 0.25
		mat_rear.emission_enabled = true
		mat_rear.emission = Color(1.0, 0.08, 0.03)
		mat_rear.emission_energy_multiplier = 0.65
	return mat_rear


func _make_shield() -> void:
	shield = MeshInstance3D.new()
	var sm := SphereMesh.new()
	var sz: Vector3 = def.size
	sm.radius = maxf(sz.z, sz.x) * 0.62
	sm.height = sm.radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	shield.mesh = sm
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.6, 0.8, 1.0, 0.18)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.75, 1.0)
	m.emission_energy_multiplier = 1.6
	m.rim_enabled = true
	m.rim = 1.0
	m.rim_tint = 0.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	shield.material_override = m
	shield.position = Vector3(0, sz.y * 0.5, 0)
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.visible = false
	add_child(shield)


func _make_headlights() -> void:
	var sz: Vector3 = def.size
	for side in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(side * (sz.x * 0.5 - 0.3), sz.y * 0.42, -sz.z * 0.5 + 0.05)
		l.rotation = Vector3(deg_to_rad(-6.0), side * deg_to_rad(-3.0), 0)
		l.spot_range = 55.0
		l.spot_angle = 32.0
		l.spot_attenuation = 0.8
		l.light_color = Color(0.9, 0.95, 1.0)
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.light_specular = 0.3
		add_child(l)
		if side < 0:
			head_l = l
		else:
			head_r = l


func set_night(n: float) -> void:
	night = n
	var on := n > 0.3
	if head_l:
		head_l.light_energy = 6.0 if on else 0.0
		head_r.light_energy = 6.0 if on else 0.0
		head_l.visible = on
		head_r.visible = on
	if mat_front:
		mat_front.emission_energy_multiplier = 3.0 if on else 1.1


## Place and animate from the sim state. Call once per rendered frame.
func apply_state(c: CarState, track: RaceTrack, dt: float, pose: Dictionary = {}) -> void:
	var s := float(pose.get("s", c.s))
	var p := track.pos(s, float(pose.get("d", c.d)))
	var t := track.tangent(s)
	var yaw_g := atan2(-t.x, -t.z) - float(pose.get("yaw", c.yaw))
	if c.spin_t > 0.0:
		yaw_g -= c.spin_t * 7.0 * float(c.spin_dir)
	var roll := 0.0
	var pitch := asin(clampf(t.y, -0.5, 0.5))
	if c.wreck_t > 0.0:
		# Settle into a slight damaged tilt instead of repeatedly bouncing.
		wreck_roll = minf(wreck_roll + dt * 3.0, 1.0)
		roll = 0.12 * wreck_roll
		pitch += 0.04 * wreck_roll
	else:
		wreck_roll = 0.0
		# lean into corners and under braking
		roll = -c.steer * 0.035 * clampf(c.v / 30.0, 0.0, 1.0) - c.drift * 0.03 * signf(c.steer)
		pitch += (-0.02 if c.gas_on else 0.0) + (0.035 if c.braking else 0.0)
	p.y += float(pose.get("hop", c.hop))
	base_pos = p
	var b := Basis.from_euler(Vector3(pitch, yaw_g, roll))
	global_transform = Transform3D(b, p)
	var ground := track.pos(s, float(pose.get("d", c.d)))
	ground.y += 0.025
	contact_shadow.global_transform = Transform3D(Basis.from_euler(Vector3(asin(clampf(t.y, -0.5, 0.5)), yaw_g, 0.0)), ground)
	contact_shadow.transparency = clampf(float(pose.get("hop", c.hop)) / 1.5, 0.0, 1.0)
	# wheels
	spin += c.v * dt / visual_wheel_radius
	if spin > TAU * 100.0:
		spin -= TAU * 100.0
	# Match the simulation's speed-limited turning curvature. A fixed full-lock
	# wheel angle at highway speed makes tires appear to scrub sideways.
	var speed := maxf(absf(c.v), 1.0)
	var lateral_accel: float = c.def.grip * (29.0 if c.is_player and not c.autopilot and track.id == "tirane" else 22.0) * (1.0 + c.drift * 0.5) * (1.8 if c.hbrake_t > 0.0 else 1.0)
	var curvature := minf(0.12, lateral_accel / (speed * speed))
	var target_steer := -atan(c.steer * curvature * visual_wheelbase)
	steer_vis = lerpf(steer_vis, target_steer, minf(1.0, dt * 12.0))
	for nm in wheels:
		var w: MeshInstance3D = wheels[nm]
		var left: bool = nm.ends_with("l")
		var front: bool = nm.begins_with("wheel_f")
		var side := -1.0 if left else 1.0
		# In model space the car faces -Z, so forward rolling turns the bottom
		# of each tire toward +Z relative to the car.
		w.rotation = Vector3(-spin * side, (PI if left else 0.0) + (steer_vis if front else 0.0), 0.0)
	# lights
	if mat_rear:
		var base := 0.9 if night > 0.3 else 0.65
		mat_rear.emission_energy_multiplier = 3.5 if (c.braking or c.v < -0.1) else base
	if sport_paint:
		sport_paint.set_shader_parameter("brake_light", 1.0 if (c.braking or c.v < -0.1) else (0.2 if night > 0.3 else 0.0))
	# shield
	for jet in nitro_jets:
		jet.visible = c.nitro_t > 0.0
		jet.scale.z = 0.8 + 0.2 * sin(spin * 4.0)
	shield.visible = c.shield_t > 0.0
	if shield.visible:
		var a := 0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		(shield.material_override as StandardMaterial3D).albedo_color.a = a
	# respawn blink
	if c.invuln_t > 0.0:
		blink += dt
		model.visible = fmod(blink, 0.16) < 0.09
	else:
		blink = 0.0
		model.visible = true
	if finish_driver:
		finish_driver.visible = model.visible
	visible = not (c.wreck_t > 0.0 and c.wreck_t < 0.05)


func _make_nitro() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.7, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.2, 0.6, 1.0)
	material.emission_energy_multiplier = 5.0
	for side in [-1.0, 1.0]:
		var jet := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = 0.02
		mesh.top_radius = 0.14
		mesh.height = 1.6
		mesh.radial_segments = 8
		jet.mesh = mesh
		jet.material_override = material
		jet.rotation.x = PI / 2.0
		jet.position = Vector3(side * def.size.x * 0.3, 0.3, def.size.z * 0.5 + 0.6)
		jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		jet.visible = false
		add_child(jet)
		nitro_jets.append(jet)
