class_name FxVisual
extends Node3D
## Visuals for the sim's transient objects: projectiles (eagle/bolt), mines
## and shock domes. Nodes are pooled per id so the sim stays visual-free.
## Also spawns short-lived explosion flashes from "boom"/"zap" events.

var race: Race
var track: RaceTrack
var _nodes: Dictionary = {}  # id -> Node3D
var _flashes: Array = []     # [{node, t, ttl, r}]
var _t := 0.0
var _skid_car: CarVisual
var _skid_previous := {}
var _skid_next := 0
var _skid_count := 0
var _skids: MultiMesh
const MAX_SKIDS := 320

static var _mats: Dictionary = {}


static func _mat(key: String, col: Color, energy: float, alpha: float = 1.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


func setup(p_race: Race, p_track: RaceTrack, p_car: CarVisual = null) -> void:
	race = p_race
	track = p_track
	_skid_car = p_car
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.18, 1.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.07, 0.065, 0.06, 0.34)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	plane.material = mat
	_skids = MultiMesh.new()
	_skids.transform_format = MultiMesh.TRANSFORM_3D
	_skids.mesh = plane
	_skids.instance_count = MAX_SKIDS
	_skids.visible_instance_count = 0
	var marks := MultiMeshInstance3D.new()
	marks.multimesh = _skids
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)


func _mk(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mi


func _make_proj(p: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	if p.kind == "eagle":
		# Keep Shqiponja recognizable after firing, as in the Three.js version.
		var icon := Sprite3D.new()
		icon.name = "Icon"
		icon.texture = PowerupIcons.texture("eagle")
		icon.pixel_size = 0.0085
		icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		icon.shaded = false
		icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(icon)
		var l := OmniLight3D.new()
		l.light_color = Color.html(Data.PW.eagle.col)
		l.light_energy = 2.0
		l.omni_range = 7.0
		l.shadow_enabled = false
		root.add_child(l)
	else:
		var bolt := CylinderMesh.new()
		bolt.top_radius = 0.08
		bolt.bottom_radius = 0.16
		bolt.height = 3.2
		bolt.radial_segments = 8
		var beam := _mk(bolt, _mat("bolt", Color(0.70, 0.88, 1.0), 2.6))
		beam.rotation.x = PI * 0.5
		root.add_child(beam)
		var l := OmniLight3D.new()
		l.light_color = Color.html(Data.PW.bolt.col)
		l.light_energy = 1.6
		l.omni_range = 6.0
		l.shadow_enabled = false
		root.add_child(l)
	return root


func _make_mine(_m: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.7
	cyl.height = 0.35
	root.add_child(_mk(cyl, _mat("mine", Color(0.25, 0.26, 0.3), 0.3)))
	var dot := SphereMesh.new()
	dot.radius = 0.14
	dot.height = 0.28
	var d := _mk(dot, _mat("mine_dot", Color.html(Data.PW.mine.col), 3.5))
	d.position.y = 0.22
	d.name = "dot"
	root.add_child(d)
	return root


func _make_dome(dm: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var sph := SphereMesh.new()
	sph.radius = float(dm.r)
	sph.height = float(dm.r) * 2.0
	var mi := _mk(sph, _mat("dome", Color.html(Data.PW.shock.col), 1.2, 0.22))
	mi.name = "shell"
	root.add_child(mi)
	var ring := TorusMesh.new()
	ring.inner_radius = float(dm.r) - 0.25
	ring.outer_radius = float(dm.r) + 0.25
	var r := _mk(ring, _mat("dome_ring", Color.html(Data.PW.shock.col), 3.0))
	r.position.y = 0.1
	r.name = "ring"
	root.add_child(r)
	return root


func powerup_used(c: CarState, kind: String, back: bool) -> void:
	# Small, short-lived energy geometry; the established projectile, shield,
	# nitro and mine visuals continue to show the ability after activation.
	if not Data.PW.has(kind) or get_tree() == null:
		return
	var color := Color.html(Data.PW[kind].col)
	var root := Node3D.new()
	add_child(root)
	root.position = _wpos(c.s, c.d, 0.35)
	var tan := track.tangent(c.s)
	if tan.length_squared() > 0.001:
		root.look_at(root.position + tan, Vector3.UP)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.2
	var node := _mk(ring, material)
	root.add_child(node)
	var stretch := Vector3.ONE
	var duration := 0.4
	match kind:
		"eagle":
			node.rotation.x = PI * 0.5
			stretch = Vector3(1.4, 1.4, 1.4)
		"bolt":
			node.rotation.x = PI * 0.5
			stretch = Vector3(0.7, 0.7, 0.7)
			duration = 0.22
		"barge": stretch = Vector3(4.0, 1.0, 4.0)
		"mine":
			root.position -= tan * (4.0 if back else -4.0)
			stretch = Vector3(1.5, 1.0, 1.5)
		"shock": stretch = Vector3(3.0, 1.0, 3.0)
		"nitro":
			root.position -= tan * 2.0
			node.rotation.x = PI * 0.5
			stretch = Vector3(1.0, 1.0, 2.0)
		"shield": stretch = Vector3(1.8, 1.8, 1.8)
		"repair":
			root.position.y += 0.8
			stretch = Vector3(1.6, 1.0, 1.6)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "scale", stretch, duration).from(Vector3(0.35, 0.35, 0.35)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	if kind == "repair":
		tween.tween_property(root, "position:y", root.position.y + 1.5, duration)
	elif kind in ["eagle", "bolt", "nitro"]:
		tween.tween_property(root, "position", root.position + tan * (-3.0 if back else 3.0), duration)
	tween.chain().tween_callback(root.queue_free)


func boom(pos: Vector3, col: Color, r: float = 3.0, ttl: float = 0.45) -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 4.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := _mk(sph, m)
	mi.position = pos
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 6.0
	l.omni_range = r * 3.0
	l.shadow_enabled = false
	mi.add_child(l)
	add_child(mi)
	_flashes.append({"node": mi, "t": 0.0, "ttl": ttl, "r": r})


func _wpos(s: float, d: float, y: float) -> Vector3:
	var p := track.pos(s, d)
	p.y += y
	return p


func _update_skids(dt: float) -> void:
	var c := race.player
	if c == null or c.wreck_t > 0.0 or c.hop > 0.15 or absf(c.v) <= 10.0 or not (c.drift > 0.25 or c.braking):
		_skid_previous.clear()
		return
	var road := track.pos(c.s, c.d)
	var tangent := track.tangent(c.s)
	var flat := Vector3(tangent.x, 0.0, tangent.z).normalized()
	var normal := track.normal(c.s)
	for side in [-1, 1]:
		var wheel_name := "wheel_rl" if side < 0 else "wheel_rr"
		var pos: Vector3
		if is_instance_valid(_skid_car) and _skid_car.wheels.has(wheel_name):
			# The wheel mesh pivot follows the rendered car, including heading/yaw.
			pos = (_skid_car.wheels[wheel_name] as Node3D).global_position
		else:
			# Tests and callers without a visual use the same approximate rear axle.
			var forward := flat * cos(c.yaw) + normal * sin(c.yaw)
			var right := normal * cos(c.yaw) - flat * sin(c.yaw)
			pos = road - forward * float(c.def.size.z) * 0.33 + right * float(side) * float(c.def.size.x) * 0.36
		pos.y = road.y + (pos - road).dot(flat) * tangent.y + 0.045
		if _skid_previous.has(side):
			var previous: Vector3 = _skid_previous[side]
			var delta := pos - previous
			var length := delta.length()
			# Break after a teleport or long stall rather than drawing across the map.
			if length >= 0.3 and length <= maxf(3.0, absf(c.v) * dt * 2.5 + 1.0):
				var basis := Basis.looking_at(-delta.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1.0, 1.0, length))
				_skids.set_instance_transform(_skid_next, Transform3D(basis, (previous + pos) * 0.5))
				_skid_next = (_skid_next + 1) % MAX_SKIDS
				_skid_count = mini(_skid_count + 1, MAX_SKIDS)
				_skids.visible_instance_count = _skid_count
			elif length < 0.3:
				continue
		_skid_previous[side] = pos


func _process(dt: float) -> void:
	if race == null:
		return
	_t += dt
	_update_skids(dt)
	var live: Dictionary = {}
	for p in race.projs:
		var n: Node3D = _nodes.get(p.id)
		if n == null:
			n = _make_proj(p)
			_nodes[p.id] = n
		live[p.id] = true
		var pos := _wpos(float(p.s), float(p.d), 0.9 if p.kind == "eagle" else 0.7)
		var tan := track.tangent(float(p.s)) * float(p.dir)
		n.position = pos
		if tan.length_squared() > 0.001:
			n.look_at(pos + tan, Vector3.UP)
		if p.kind == "bolt":
			n.rotation.z = _t * 20.0
		else:
			var icon := n.get_node_or_null("Icon") as Sprite3D
			if icon:
				icon.rotation.z = sin(_t * 15.0) * 0.15
	for m in race.mines:
		var n: Node3D = _nodes.get(m.id)
		if n == null:
			n = _make_mine(m)
			_nodes[m.id] = n
		live[m.id] = true
		var air := 0.0
		if float(m.fly) > 0.0 and float(m.fly0) > 0.0:
			var f := 1.0 - float(m.fly) / float(m.fly0)
			air = sin(f * PI) * 2.5
		n.position = _wpos(float(m.s), float(m.d), 0.18 + air)
		n.rotation.y = _t * 2.0
		var dot := n.get_node_or_null("dot") as MeshInstance3D
		if dot:
			dot.visible = float(m.arm) <= 0.0 and fmod(_t * 3.0, 1.0) < 0.5
	for dm in race.domes:
		var n: Node3D = _nodes.get(dm.id)
		if n == null:
			n = _make_dome(dm)
			_nodes[dm.id] = n
		live[dm.id] = true
		n.position = _wpos(float(dm.s), float(dm.d), 0.0)
		var warn := float(dm.warn) > 0.0
		var shell := n.get_node_or_null("shell") as MeshInstance3D
		var ring := n.get_node_or_null("ring") as MeshInstance3D
		if shell:
			shell.visible = not warn
			var pulse := 1.0 + 0.04 * sin(_t * 9.0)
			shell.scale = Vector3.ONE * pulse
		if ring:
			ring.scale = Vector3.ONE * (0.4 + 0.6 * (1.0 - float(dm.warn)) if warn else 1.0)
			ring.visible = (not warn) or fmod(_t * 6.0, 1.0) < 0.5
	for id in _nodes.keys():
		if not live.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		f.t += dt
		var k: float = clampf(f.t / f.ttl, 0.0, 1.0)
		var mi: MeshInstance3D = f.node
		mi.scale = Vector3.ONE * (0.3 + float(f.r) * k)
		var mat := mi.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.8 * (1.0 - k)
		for ch in mi.get_children():
			if ch is OmniLight3D:
				ch.light_energy = 6.0 * (1.0 - k)
		if k >= 1.0:
			mi.queue_free()
			_flashes.remove_at(i)
