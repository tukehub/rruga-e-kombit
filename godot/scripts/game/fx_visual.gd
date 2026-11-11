class_name FxVisual
extends Node3D
## Visuals for the sim's transient objects: projectiles (eagle/bolt), mines
## and shock domes. Nodes are pooled per id so the sim stays visual-free.
## Also spawns short-lived explosion flashes from "boom"/"zap" events.

var race: Race
var track: RaceTrack
var _nodes: Dictionary = {}  # id -> Node3D
var _flashes: Array = []     # [{unit, t, ttl, r}]
var _t := 0.0
var _skid_car: CarVisual
var _skid_previous := {}
var _skid_next := 0
var _skid_count := 0
var _skids: MultiMesh
const MAX_SKIDS := 320
const FLASH_POOL := 8
const RING_POOL := 6
# Sparks outlive the flash itself; the unit stays visible until they are gone.
const FLASH_SPARK_TAIL := 0.35
var _flash_pool: Array = []   # [{root, core, halo, ring, light, sparks}]
var _flash_next := 0
var _ring_pool: Array = []   # [{root, node, mat, tween}]
var _ring_next := 0
var _free: Dictionary = {}   # kind -> hidden nodes ready for reuse
var _node_key: Dictionary = {}  # id -> kind

static var _mats: Dictionary = {}
static var _glow_tex: GradientTexture2D
static var _quad: QuadMesh


## Soft round falloff shared by every glow.
static func _glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.4))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.width = 64
		_glow_tex.height = 64
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
	return _glow_tex


## Camera-facing additive glow: the neon halo behind the combat effects.
## Colours above 1.0 are intentional so the halo feeds the bloom pass.
static func glow_material(col: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _glow_texture()
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, 1.0)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.disable_fog = true
	return m


static func glow_quad(mat: Material, size: float) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
	var q := MeshInstance3D.new()
	q.mesh = _quad
	q.material_override = mat
	q.scale = Vector3(size, size, size)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return q


## Additive solid colour for shockwave rings, cores and trails.
static func add_material(col: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, alpha)
	m.disable_fog = true
	return m


static func _tint(node: MeshInstance3D, col: Color, energy: float, alpha: float) -> void:
	(node.material_override as StandardMaterial3D).albedo_color = Color(col.r * energy, col.g * energy, col.b * energy, alpha)


static func _set_alpha(node: MeshInstance3D, alpha: float) -> void:
	(node.material_override as StandardMaterial3D).albedo_color.a = alpha


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
	_build_pools()


## Everything combat spawns is created once here, hidden, and reused, so no
## node, mesh or material is allocated when something fires or blows up.
func _build_pools() -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	# Each explosion is a hot core, a soft halo, a shockwave ring along the
	# ground, a light and a burst of sparks.
	var wave := TorusMesh.new()
	wave.inner_radius = 0.9
	wave.outer_radius = 1.0
	wave.rings = 32
	wave.ring_segments = 4
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.22, 0.22)
	var spark_mat := glow_material(Color.WHITE, 2.5)
	spark_mat.vertex_color_use_as_albedo = true
	spark_mesh.material = spark_mat
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	for i in FLASH_POOL:
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var core := _mk(sph, add_material(Color.WHITE, 1.0, 0.8))
		root.add_child(core)
		var halo := glow_quad(glow_material(Color.WHITE, 1.0), 1.0)
		root.add_child(halo)
		var ring := _mk(wave, add_material(Color.WHITE, 1.0, 0.9))
		ring.position.y = -0.55
		root.add_child(ring)
		var light := OmniLight3D.new()
		light.shadow_enabled = false
		root.add_child(light)
		var sparks := CPUParticles3D.new()
		sparks.emitting = false
		sparks.one_shot = true
		sparks.explosiveness = 1.0
		sparks.amount = 18
		sparks.lifetime = 0.55
		sparks.mesh = spark_mesh
		sparks.direction = Vector3.UP
		sparks.spread = 180.0
		sparks.initial_velocity_min = 5.0
		sparks.initial_velocity_max = 15.0
		sparks.gravity = Vector3(0.0, -16.0, 0.0)
		sparks.damping_min = 1.5
		sparks.damping_max = 3.0
		sparks.scale_amount_curve = shrink
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(sparks)
		_flash_pool.append({"root": root, "core": core, "halo": halo, "ring": ring, "light": light, "sparks": sparks})
	var torus := TorusMesh.new()
	torus.inner_radius = 0.88
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 8
	for i in RING_POOL:
		var material := add_material(Color.WHITE, 1.0, 0.8)
		var root := Node3D.new()
		root.visible = false
		add_child(root)
		var node := _mk(torus, material)
		root.add_child(node)
		var halo := glow_quad(glow_material(Color.WHITE, 1.0), 1.5)
		root.add_child(halo)
		_ring_pool.append({"root": root, "node": node, "mat": material, "halo": halo, "tween": null})
	for kind in ["bolt", "bolt", "bolt", "eagle", "eagle"]:
		_release(kind, _make_proj({"kind": kind}))
	for i in 3:
		_release("mine", _make_mine({}))


func _acquire(key: String) -> Node3D:
	var pool: Array = _free.get(key, [])
	if pool.is_empty():
		return null
	var n: Node3D = pool.pop_back()
	n.visible = true
	return n


func _release(key: String, n: Node3D) -> void:
	n.visible = false
	if not _free.has(key):
		_free[key] = []
	_free[key].append(n)


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
		root.add_child(glow_quad(glow_material(Color.html(Data.PW.eagle.col), 1.6), 3.2))
		root.add_child(_trail(Color.html(Data.PW.eagle.col), 0.24, 9.0))
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
		root.add_child(glow_quad(glow_material(Color(0.55, 0.8, 1.0), 1.8), 1.9))
		root.add_child(_trail(Color(0.6, 0.85, 1.0), 0.13, 6.0))
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
	# The warning light blinks with its own halo once the mine is armed.
	d.add_child(glow_quad(glow_material(Color.html(Data.PW.mine.col), 1.8), 1.3))
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
	(mi.material_override as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_ADD
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
	if not Data.PW.has(kind) or get_tree() == null or _ring_pool.is_empty():
		return
	var color := Color.html(Data.PW[kind].col)
	# Reuse the oldest ring when every pooled one is still animating.
	var slot: Dictionary = _ring_pool[_ring_next]
	_ring_next = (_ring_next + 1) % _ring_pool.size()
	if slot.tween != null and slot.tween.is_valid():
		slot.tween.kill()
	var root: Node3D = slot.root
	var node: MeshInstance3D = slot.node
	var material: StandardMaterial3D = slot.mat
	root.transform = Transform3D.IDENTITY
	node.transform = Transform3D.IDENTITY
	root.position = _wpos(c.s, c.d, 0.35)
	var tan := track.tangent(c.s)
	if tan.length_squared() > 0.001:
		root.look_at(root.position + tan, Vector3.UP)
	material.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.8)
	var halo: MeshInstance3D = slot.halo
	_tint(halo, color, 2.0, 1.0)
	halo.scale = Vector3.ONE * 1.5
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
	root.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(node, "scale", stretch, duration).from(Vector3(0.35, 0.35, 0.35)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	# A burst of light at the car as the ability goes off.
	tween.tween_property(halo, "scale", Vector3.ONE * 5.5, duration).from(Vector3.ONE * 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(halo.material_override, "albedo_color:a", 0.0, duration)
	if kind == "repair":
		tween.tween_property(root, "position:y", root.position.y + 1.5, duration)
	elif kind in ["eagle", "bolt", "nitro"]:
		tween.tween_property(root, "position", root.position + tan * (-3.0 if back else 3.0), duration)
	tween.chain().tween_callback(root.hide)
	slot.tween = tween


func boom(pos: Vector3, col: Color, r: float = 3.0, ttl: float = 0.45) -> void:
	if _flash_pool.is_empty():
		return
	# Reuse the oldest flash when every pooled one is still fading.
	var unit: Dictionary = _flash_pool[_flash_next]
	_flash_next = (_flash_next + 1) % _flash_pool.size()
	for i in range(_flashes.size() - 1, -1, -1):
		if _flashes[i].unit == unit:
			_flashes.remove_at(i)
	_tint(unit.core, col.lerp(Color.WHITE, 0.55), 2.2, 0.8)
	_tint(unit.halo, col, 2.0, 1.0)
	_tint(unit.ring, col, 2.5, 0.9)
	var light: OmniLight3D = unit.light
	light.light_color = col
	light.omni_range = r * 3.0
	var sparks: CPUParticles3D = unit.sparks
	sparks.color = col.lerp(Color.WHITE, 0.3)
	var root: Node3D = unit.root
	root.position = pos
	root.visible = true
	sparks.restart()
	sparks.emitting = true
	var flash := {"unit": unit, "t": 0.0, "ttl": ttl, "r": r}
	_flashes.append(flash)
	_animate_flash(flash)


func _animate_flash(f: Dictionary) -> void:
	var unit: Dictionary = f.unit
	var k := clampf(float(f.t) / float(f.ttl), 0.0, 1.0)
	var grow := 1.0 - (1.0 - k) * (1.0 - k)
	var fade := (1.0 - k) * (1.0 - k)
	var r := float(f.r)
	var core: MeshInstance3D = unit.core
	core.scale = Vector3.ONE * (0.3 + r * 0.8 * grow)
	_set_alpha(core, 0.8 * fade)
	var halo: MeshInstance3D = unit.halo
	halo.scale = Vector3.ONE * r * (1.4 + 2.2 * grow)
	_set_alpha(halo, fade)
	var ring: MeshInstance3D = unit.ring
	var spread := 0.6 + r * 2.4 * grow
	ring.scale = Vector3(spread, 0.25, spread)
	_set_alpha(ring, 0.9 * (1.0 - k))
	(unit.light as OmniLight3D).light_energy = 6.0 * (1.0 - k)


## Tapered additive streak behind a projectile, whose root faces -Z.
func _trail(col: Color, radius: float, length: float) -> MeshInstance3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = length
	cone.radial_segments = 6
	cone.cap_top = false
	cone.cap_bottom = false
	var streak := _mk(cone, add_material(col, 1.6, 0.45))
	streak.rotation.x = PI * 0.5
	streak.position.z = length * 0.5 + 0.8
	return streak


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
			var key := "eagle" if p.kind == "eagle" else "bolt"
			n = _acquire(key)
			if n == null:
				n = _make_proj(p)
			_nodes[p.id] = n
			_node_key[p.id] = key
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
			n = _acquire("mine")
			if n == null:
				n = _make_mine(m)
			_nodes[m.id] = n
			_node_key[m.id] = "mine"
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
			# Domes are sized at build time, so they recycle per radius.
			var key := "dome%s" % str(dm.r)
			n = _acquire(key)
			if n == null:
				n = _make_dome(dm)
			_nodes[dm.id] = n
			_node_key[dm.id] = key
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
			_release(str(_node_key.get(id, "")), _nodes[id])
			_nodes.erase(id)
			_node_key.erase(id)
	for i in range(_flashes.size() - 1, -1, -1):
		var f: Dictionary = _flashes[i]
		f.t += dt
		_animate_flash(f)
		if float(f.t) >= float(f.ttl) + FLASH_SPARK_TAIL:
			(f.unit.root as Node3D).visible = false
			_flashes.remove_at(i)
