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
	return _tree_meshes()[0]


func _build_trees(trees: Array, terrain: Terrain, city_id: String) -> void:
	var meshes := _tree_meshes()
	var keep := int(trees.size() * float(Quality.p.tree_mul))
	var selected: Dictionary = {}
	if city_id == "tirane":
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/tirane/track.json"))
		# Prefer trees along the first ~250 m of road, rather than trees behind
		# buildings that happen to be close to the start in a straight line.
		# Keep their mapped positions, with a margin beyond the 10 m road edge.
		var points: Array = route.pts
		var start: Array = points[0]
		var segments := []
		var along_m := 0.0
		for j in range(1, points.size()):
			var a: Array = points[j - 1]
			var b: Array = points[j]
			var p0 := Vector2(float(a[0]), float(a[2]))
			var p1 := Vector2(float(b[0]), float(b[2]))
			var length := p0.distance_to(p1)
			segments.append([p0, p1, along_m, length])
			along_m += length
			if along_m >= 250.0:
				break
		var candidates := []
		for i in keep:
			var t: Array = trees[i]
			var pos := Vector2(float(t[0]), float(t[2]))
			if pos.distance_squared_to(Vector2(float(start[0]), float(start[2]))) > 300.0 * 300.0:
				continue
			var nearest := INF
			var along := 0.0
			for segment in segments:
				var p0: Vector2 = segment[0]
				var p1: Vector2 = segment[1]
				var direction := p1 - p0
				var denom := direction.length_squared()
				var fraction := clampf((pos - p0).dot(direction) / denom, 0.0, 1.0) if denom > 0.0 else 0.0
				var d := pos.distance_squared_to(p0 + direction * fraction)
				if d < nearest:
					nearest = d
					along = float(segment[2]) + fraction * float(segment[3])
			if nearest >= 14.0 * 14.0 and nearest <= 34.0 * 34.0:
				candidates.append([along, nearest, i])
		candidates.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
		for i in mini(24, candidates.size()):
			selected[candidates[i][2]] = true
	# A single world-sized MultiMesh has one bounding box and cannot cull its
	# individual trees. Split by location so camera/frustum and distance culling
	# can omit whole groups, including from the rear-view camera.
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
			chunks[key] = {"normal": [], "pilot": [], "trunk": []}
		var centre := Vector3((key.x + 0.5) * TREE_CHUNK_SIZE, 0, (key.y + 0.5) * TREE_CHUNK_SIZE)
		var tr := Transform3D(basis, Vector3(float(t[0]), y, float(t[2])) - centre)
		chunks[key]["pilot" if selected.has(i) else "normal"].append(tr)
		chunks[key]["trunk"].append(tr)
	var pilot_mesh := _pilot_leaf_mesh() if not selected.is_empty() else null
	for key: Vector2i in chunks:
		var origin := Vector3((key.x + 0.5) * TREE_CHUNK_SIZE, 0, (key.y + 0.5) * TREE_CHUNK_SIZE)
		var groups: Dictionary = chunks[key]
		_tree_chunk(meshes[0], groups.normal, origin, float(Quality.p.props_dist) * 1.3, Quality.preset != "low", "TreeCanopy")
		if pilot_mesh != null:
			_tree_chunk(pilot_mesh, groups.pilot, origin, float(Quality.p.props_dist) * 1.3, false, "TreeDetail")


func _tree_chunk(mesh: Mesh, transforms: Array, origin: Vector3, distance: float, shadows: bool, node_name: String) -> void:
	if transforms.is_empty():
		return
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


func set_night(n: float) -> void:
	night = n
	if lamp_emis:
		lamp_emis.emission_energy_multiplier = 6.0 * n


## Move the real lights to the nearest lamps ahead of the player.
func update_lights(player_pos: Vector3, forward: Vector3) -> void:
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
