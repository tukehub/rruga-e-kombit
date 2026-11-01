class_name CarVisual
extends Node3D
## Renders one CarState: GLB model (body + 4 wheel nodes), paint/glass/light
## materials, wheel spin/steer, hop/spin/wreck motion, brake lights, shield.
## Sim frame: d>0 and yaw>0 are towards the track normal N = (-tz, tx) = RIGHT,
## so Godot yaw (counter-clockwise positive) = atan2(-tx, -tz) - yaw.

static var shared: Dictionary = {}

var def: Dictionary
var is_player := false
var color := Color.WHITE
var model: Node3D
var body: MeshInstance3D
var wheels: Dictionary = {}  # name -> MeshInstance3D
var mat_paint: StandardMaterial3D
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


func setup(p_def: Dictionary, p_color: Color, p_is_player: bool) -> void:
	def = p_def
	color = p_color
	is_player = p_is_player
	var scene: PackedScene = load(def.model)
	model = scene.instantiate()
	add_child(model)
	for ch in model.get_children():
		if ch is MeshInstance3D:
			if ch.name == "body":
				body = ch
			elif String(ch.name).begins_with("wheel"):
				wheels[String(ch.name)] = ch
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			ch.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
			_override_materials(ch)
	_make_nitro()
	_make_shield()
	if is_player:
		_make_headlights()


func _override_materials(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	if mesh == null:
		return
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		var nm := m.resource_name if m else ""
		var ov: Material = null
		match nm:
			"paint": ov = _paint()
			"glass": ov = _shared("glass", _mk_glass)
			"light_front": ov = _front()
			"light_rear": ov = _rear()
			"trim": ov = _shared("trim", func(): return _mk_simple(Color(0.05, 0.05, 0.055), 0.0, 0.7))
			"chrome": ov = _shared("chrome", func(): return _mk_simple(Color(0.9, 0.9, 0.92), 1.0, 0.12))
			"interior": ov = _shared("interior", func(): return _mk_simple(Color(0.07, 0.07, 0.08), 0.0, 0.95))
			"tyre": ov = _shared("tyre", func(): return _mk_simple(Color(0.035, 0.035, 0.04), 0.0, 0.9))
			"rim": ov = _shared("rim", func(): return _mk_simple(Color(0.8, 0.8, 0.84), 1.0, 0.22))
			"brake": ov = _shared("brake", func(): return _mk_simple(Color(0.75, 0.12, 0.08), 0.3, 0.5))
			"plate": ov = _shared("plate", func(): return _mk_simple(Color(0.95, 0.95, 0.9), 0.0, 0.5))
		if ov:
			mi.set_surface_override_material(i, ov)


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


func _paint() -> StandardMaterial3D:
	if mat_paint == null:
		mat_paint = StandardMaterial3D.new()
		mat_paint.albedo_color = color
		mat_paint.metallic = 0.35
		mat_paint.metallic_specular = 0.6
		mat_paint.roughness = 0.24
		mat_paint.clearcoat_enabled = true
		mat_paint.clearcoat = 0.9
		mat_paint.clearcoat_roughness = 0.05
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
		wreck_roll += dt * 9.0
		roll = sin(wreck_roll) * 0.35
		pitch += sin(wreck_roll * 0.7) * 0.2
		p.y += absf(sin(wreck_roll * 0.5)) * 0.5
	else:
		wreck_roll = 0.0
		# lean into corners and under braking
		roll = -c.steer * 0.035 * clampf(c.v / 30.0, 0.0, 1.0) - c.drift * 0.03 * signf(c.steer)
		pitch += (-0.02 if c.gas_on else 0.0) + (0.035 if c.braking else 0.0)
	p.y += float(pose.get("hop", c.hop))
	base_pos = p
	var b := Basis.from_euler(Vector3(pitch, yaw_g, roll))
	global_transform = Transform3D(b, p)
	# wheels
	spin += c.v * dt / float(def.wheel_r)
	if spin > TAU * 100.0:
		spin -= TAU * 100.0
	steer_vis = lerpf(steer_vis, -c.steer * 0.5, minf(1.0, dt * 12.0))
	for nm in wheels:
		var w: MeshInstance3D = wheels[nm]
		var left: bool = nm.ends_with("l")
		var front: bool = nm.begins_with("wheel_f")
		var side := -1.0 if left else 1.0
		w.rotation = Vector3(spin * side, (PI if left else 0.0) + (steer_vis if front else 0.0), 0.0)
	# lights
	if mat_rear:
		var base := 0.9 if night > 0.3 else 0.65
		mat_rear.emission_energy_multiplier = 3.5 if (c.braking or c.v < -0.1) else base
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
