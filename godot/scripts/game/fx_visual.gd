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


func setup(p_race: Race, p_track: RaceTrack) -> void:
	race = p_race
	track = p_track


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
		var body := CapsuleMesh.new()
		body.radius = 0.28
		body.height = 1.6
		var mi := _mk(body, _mat("eagle", Color.html(Data.PW.eagle.col), 3.0))
		mi.rotation.x = PI * 0.5
		root.add_child(mi)
		var glow := SphereMesh.new()
		glow.radius = 0.6
		glow.height = 1.2
		root.add_child(_mk(glow, _mat("eagle_glow", Color.html(Data.PW.eagle.col), 1.5, 0.3)))
		var l := OmniLight3D.new()
		l.light_color = Color.html(Data.PW.eagle.col)
		l.light_energy = 2.0
		l.omni_range = 7.0
		l.shadow_enabled = false
		root.add_child(l)
	else:
		var bolt := BoxMesh.new()
		bolt.size = Vector3(0.35, 0.35, 3.2)
		root.add_child(_mk(bolt, _mat("bolt", Color.html(Data.PW.bolt.col), 4.0)))
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


func _process(dt: float) -> void:
	if race == null:
		return
	_t += dt
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
