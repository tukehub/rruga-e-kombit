class_name Props
extends Node3D
## Street lamps, trees and landmark placeholders from <city>/props.json.
## Lamps along the track get real OmniLights (nearest N to the player, from
## the quality preset); the rest are emissive meshes only.

var lamp_mm: MultiMeshInstance3D
const TREE_CHUNK_SIZE := 400.0
var track_lamps: Array = []          # [x,y,z,yaw]
var lights: Array[OmniLight3D] = []
var light_slots := 0
var lamp_emis: StandardMaterial3D
var night := 1.0
var landmarks: Array = []

# A small near-camera 3D pool travels around the circuit; distant trees use
# low-cost cutouts.  No per-tree nodes or 3D trees are created per frame.
const NEAR_TREE_LIMIT := 24
const NEAR_TREE_RADIUS := 90.0
var _tree_refs: Array = []
var _tree_chunks := {}
var _near_marked: Array = []
var _near_leaves: MultiMesh
var _near_branches: MultiMesh
var _tree_lod_last := 0



func load_city(city_id: String, terrain: Terrain) -> void:
	var path := "res://assets/cities/%s/props.json" % city_id
	if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
		return
	var p: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	track_lamps = p.get("track_lamps", [])
	landmarks = p.get("landmarks", [])
	var models := Landmarks.new()
	add_child(models)
	models.load_anchors(landmarks)
	_build_lamps(p.get("lamps", []), track_lamps)
	_build_trees(p.get("trees", []), terrain, city_id)
	light_slots = int(Quality.p.lamp_lights)
	for i in light_slots:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.55)
		l.light_energy = 0.0
		l.omni_range = 22.0
		l.omni_attenuation = 1.6
		l.shadow_enabled = false
		l.light_specular = 0.6
		add_child(l)
		lights.append(l)


func _lamp_mesh() -> ArrayMesh:
	# pole (thin box) + head (emissive box), built as two surfaces
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 4.0, 0), Vector3(0.14, 8.0, 0.14), Color(0.25, 0.26, 0.28))
	_box(st, Vector3(0, 8.0, 1.2), Vector3(0.12, 0.12, 2.4), Color(0.25, 0.26, 0.28))
	var pole_mat := StandardMaterial3D.new()
	pole_mat.vertex_color_use_as_albedo = true
	pole_mat.roughness = 0.5
	pole_mat.metallic = 0.6
	st.set_material(pole_mat)
	var mesh := st.commit()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st2, Vector3(0, 7.9, 2.3), Vector3(0.5, 0.22, 0.9), Color(1, 1, 1))
	lamp_emis = StandardMaterial3D.new()
	lamp_emis.albedo_color = Color(0.9, 0.85, 0.7)
	lamp_emis.emission_enabled = true
	lamp_emis.emission = Color(1.0, 0.82, 0.55)
	lamp_emis.emission_energy_multiplier = 6.0
	st2.set_material(lamp_emis)
	st2.commit(mesh)
	return mesh


static func _box(st: SurfaceTool, c: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
		[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
		[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
		[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
		[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var vs: Array = f[1]
		var quad: Array[Vector3] = []
		for v in vs:
			quad.append(c + Vector3(v.x * h.x, v.y * h.y, v.z * h.z))
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(quad[0])
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(quad[1])
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(quad[2])
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(quad[0])
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(quad[2])
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(quad[3])


func _build_lamps(lamps: Array, tl: Array) -> void:
	var mesh := _lamp_mesh()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var all := []
	for l in lamps:
		all.append([l[0], l[1], l[2], 0.0])
	for l in tl:
		all.append(l)
	mm.instance_count = all.size()
	for i in all.size():
		var l: Array = all[i]
		var yaw := float(l[3]) if l.size() > 3 else 0.0
		var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(l[0], l[1], l[2]))
		mm.set_instance_transform(i, t)
	lamp_mm = MultiMeshInstance3D.new()
	lamp_mm.multimesh = mm
	lamp_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp_mm.visibility_range_end = float(Quality.p.props_dist)
	lamp_mm.visibility_range_end_margin = 60.0
	add_child(lamp_mm)


func _tree_meshes() -> Array:
	# Crossed photographic cutouts provide volume at a small geometry cost.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI * 0.5]:
		var axis := Vector3(cos(angle), 0.0, sin(angle)) * 2.7
		var points := [-axis, axis, axis + Vector3.UP * 8.4, -axis + Vector3.UP * 8.4]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3(-sin(angle), 0.0, cos(angle)))
			st.set_uv(uvs[index])
			st.add_vertex(points[index])
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/foliage/photographic_tree.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	st.set_material(material)
	return [st.commit()]


func _pilot_leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1949
	for i in 160:
		var az := rng.randf_range(0.0, TAU)
		var y := rng.randf_range(-1.0, 1.0)
		var r := sqrt(maxf(0.0, 1.0 - y * y)) * rng.randf_range(0.28, 1.0)
		var centre := Vector3(cos(az) * r * 2.15, 4.9 + y * 1.9, sin(az) * r * 2.15)
		var rot := rng.randf_range(0.0, TAU)
		var axis := Vector3(cos(rot), 0.0, sin(rot))
		var up := Vector3(0.0, 1.0, 0.0).rotated(axis, rng.randf_range(-0.65, 0.65))
		var right := axis * rng.randf_range(0.45, 0.70)
		up *= rng.randf_range(0.65, 0.95)
		var normal := right.cross(up).normalized()
		var corners := [centre - right - up, centre + right - up, centre + right + up, centre - right + up]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normal)
			st.set_uv(uvs[index])
			st.add_vertex(corners[index])
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/foliage/polyhaven_tree_leaves.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.45
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	st.set_material(material)
	return st.commit()


func _build_trees(trees: Array, terrain: Terrain, city_id: String) -> void:
	var meshes := _tree_meshes()
	var keep := int(trees.size() * float(Quality.p.tree_mul))
	# Keep spatial batches so the renderer culls distant cutout trees.
	var chunks := {}
	for i in keep:
		var t: Array = trees[i]
		var sc := float(t[3])
		var y := float(t[1])
		if terrain:
			y = terrain.height_at(float(t[0]), float(t[2]))
		var breadth := 0.91 + 0.18 * (0.5 + 0.5 * sin(float(i) * 2.31))
		var height := 0.94 + 0.12 * (0.5 + 0.5 * sin(float(i) * 1.73))
		var basis := Basis(Vector3.UP, float(i) * 1.37).scaled(Vector3(sc * breadth, sc * height, sc * (2.0 - breadth)))
		var key := Vector2i(floori(float(t[0]) / TREE_CHUNK_SIZE), floori(float(t[2]) / TREE_CHUNK_SIZE))
		if not chunks.has(key):
			chunks[key] = []
		var origin := Vector3((key.x + 0.5) * TREE_CHUNK_SIZE, 0, (key.y + 0.5) * TREE_CHUNK_SIZE)
		var world_pos := Vector3(float(t[0]), y, float(t[2]))
		chunks[key].append({"local": Transform3D(basis, world_pos - origin), "world": Transform3D(basis, world_pos)})
	_tree_refs.clear()
	_tree_chunks.clear()
	_near_marked.clear()
	for key: Vector2i in chunks:
		var origin := Vector3((key.x + 0.5) * TREE_CHUNK_SIZE, 0, (key.y + 0.5) * TREE_CHUNK_SIZE)
		var entries: Array = chunks[key]
		var transforms := []
		for entry in entries:
			transforms.append(entry.local)
		var node := _tree_chunk(meshes[0], transforms, origin, float(Quality.p.props_dist) * 1.3, Quality.preset != "low", "TreeCanopy")
		if city_id == "tirane":
			var refs := []
			for i in entries.size():
				var ref := {"mm": node.multimesh, "index": i, "local": entries[i].local, "world": entries[i].world}
				_tree_refs.append(ref)
				refs.append(ref)
			_tree_chunks[key] = refs
	if city_id == "tirane" and not _tree_refs.is_empty():
		var packed: PackedScene = load("res://assets/foliage/tree_small_02_mobile.glb")
		var model := packed.instantiate()
		var branches := _find_tree_mesh(model)
		model.free()
		if branches != null:
			_near_leaves = _make_tree_pool(_pilot_leaf_mesh(), "Tree3DLeaves")
			_near_branches = _make_tree_pool(branches, "Tree3DBranches")


func _make_tree_pool(mesh: Mesh, node_name: String) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = NEAR_TREE_LIMIT
	mm.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node, true)
	return mm


func _update_tree_lod(player_pos: Vector3, force := false) -> void:
	if _near_leaves == null or _near_branches == null:
		return
	var now := Time.get_ticks_msec()
	if not force and now - _tree_lod_last < 400:
		return
	_tree_lod_last = now
	var candidates := []
	var x_min := floori((player_pos.x - NEAR_TREE_RADIUS) / TREE_CHUNK_SIZE)
	var x_max := floori((player_pos.x + NEAR_TREE_RADIUS) / TREE_CHUNK_SIZE)
	var z_min := floori((player_pos.z - NEAR_TREE_RADIUS) / TREE_CHUNK_SIZE)
	var z_max := floori((player_pos.z + NEAR_TREE_RADIUS) / TREE_CHUNK_SIZE)
	for x in range(x_min, x_max + 1):
		for z in range(z_min, z_max + 1):
			for ref in _tree_chunks.get(Vector2i(x, z), []):
				var world: Transform3D = ref.world
				var delta := Vector2(world.origin.x - player_pos.x, world.origin.z - player_pos.z)
				var distance := delta.length_squared()
				if distance <= NEAR_TREE_RADIUS * NEAR_TREE_RADIUS:
					candidates.append([distance, ref])
	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for ref in _near_marked:
		ref.mm.set_instance_transform(ref.index, ref.local)
	_near_marked.clear()
	var count := mini(NEAR_TREE_LIMIT, candidates.size())
	for i in count:
		var ref: Dictionary = candidates[i][1]
		var hidden: Transform3D = ref.local
		hidden.basis = Basis.from_scale(Vector3.ZERO)
		ref.mm.set_instance_transform(ref.index, hidden)
		_near_leaves.set_instance_transform(i, ref.world)
		_near_branches.set_instance_transform(i, ref.world)
		_near_marked.append(ref)
	_near_leaves.visible_instance_count = count
	_near_branches.visible_instance_count = count


func _find_tree_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh
	for child in node.get_children():
		var found := _find_tree_mesh(child)
		if found != null:
			return found
	return null


func _tree_chunk(mesh: Mesh, transforms: Array, origin: Vector3, distance: float, shadows: bool, node_name: String) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.position = origin
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Include the chunk half-diagonal to avoid popping nearby trees at its edge.
	node.visibility_range_end = distance + TREE_CHUNK_SIZE * 0.71
	node.visibility_range_end_margin = 80.0
	add_child(node, true)
	return node


func set_night(n: float) -> void:
	night = n
	if lamp_emis:
		lamp_emis.emission_energy_multiplier = 6.0 * n


## Move the real lights to the nearest lamps ahead of the player.
func update_lights(player_pos: Vector3, forward: Vector3) -> void:
	_update_tree_lod(player_pos)
	if lights.is_empty() or track_lamps.is_empty():
		return
	var cand := []
	for l in track_lamps:
		var p := Vector3(l[0], l[1], l[2])
		var to := p - player_pos
		var dist := to.length()
		if dist > 140.0:
			continue
		# favour lamps ahead
		var ahead := to.normalized().dot(forward)
		cand.append([dist - ahead * 30.0, p])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	for i in lights.size():
		var l := lights[i]
		if i < cand.size():
			var p: Vector3 = cand[i][1]
			l.global_position = p + Vector3(0, 7.7, 0) + Vector3(0, 0, 0)
			l.light_energy = 2.2 * night
			l.visible = night > 0.05
		else:
			l.visible = false
