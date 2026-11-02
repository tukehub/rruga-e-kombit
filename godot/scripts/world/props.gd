class_name Props
extends Node3D
## Street lamps, trees and landmark placeholders from <city>/props.json.
## Lamps along the track get real OmniLights (nearest N to the player, from
## the quality preset); the rest are emissive meshes only.

var lamp_mm: MultiMeshInstance3D
var tree_mm: MultiMeshInstance3D
var trunk_mm: MultiMeshInstance3D
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
	# A rounded broadleaf crown, rather than the old stacked conifers.  The
	# small irregularities make a three-dimensional silhouette from every angle.
	# One shared 32-triangle mesh still renders in a single MultiMesh draw call.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 8
	var rings := 3
	var vertex := func(ring: int, segment: int) -> void:
		var phi := PI * float(ring) / float(rings)
		var angle := TAU * float(segment) / float(segments)
		var uneven := 1.0 + 0.09 * sin(angle * 3.0 + phi * 1.7) + 0.05 * cos(angle * 5.0 - phi)
		var unit := Vector3(sin(phi) * cos(angle), cos(phi), sin(phi) * sin(angle))
		var normal := Vector3(unit.x / 2.5, unit.y / 2.35, unit.z / 2.5).normalized()
		st.set_normal(normal)
		var variation := 0.025 * sin(angle * 3.0 + phi * 2.0)
		st.set_color(Color(0.15 + variation, 0.27 + unit.y * 0.04 + variation, 0.105 + variation * 0.5))
		st.add_vertex(Vector3(unit.x * 2.5 * uneven, 4.8 + unit.y * 2.35, unit.z * 2.5 * uneven))
	for ring in rings:
		for segment in segments:
			# Skip the degenerate triangles at the two poles.
			if ring > 0:
				vertex.call(ring, segment)
				vertex.call(ring, segment + 1)
				vertex.call(ring + 1, segment + 1)
			if ring < rings - 1:
				vertex.call(ring, segment)
				vertex.call(ring + 1, segment + 1)
				vertex.call(ring + 1, segment)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.vertex_color_use_as_albedo = true
	canopy_mat.roughness = 0.95
	st.set_material(canopy_mat)
	var canopy := st.commit()
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st2, Vector3(0, 1.5, 0), Vector3(0.48, 3.0, 0.48), Color(0.30, 0.22, 0.15))
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.vertex_color_use_as_albedo = true
	trunk_mat.roughness = 0.9
	st2.set_material(trunk_mat)
	return [canopy, st2.commit()]


# Shared cutout leaf clusters form a genuinely volumetric crown.  Only a small
# grove near the start uses them; the existing inexpensive crown is the far LOD.
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
	var selected: Dictionary = {}
	if city_id == "tirane":
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/tirane/track.json"))
		var start: Array = route.pts[0]
		var candidates := []
		for i in keep:
			var t: Array = trees[i]
			var distance := Vector2(float(t[0]) - float(start[0]), float(t[2]) - float(start[2])).length_squared()
			if distance < 150.0 * 150.0:
				candidates.append([distance, i])
		candidates.sort_custom(func(a, b): return a[0] < b[0])
		for i in mini(24, candidates.size()):
			selected[candidates[i][1]] = true
	var pilot := MultiMesh.new()
	pilot.transform_format = MultiMesh.TRANSFORM_3D
	pilot.mesh = _pilot_leaf_mesh() if not selected.is_empty() else null
	pilot.instance_count = selected.size()
	var pilot_index := 0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = meshes[0]
	mm.instance_count = keep - selected.size()
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = meshes[1]
	mm2.instance_count = keep
	var base_index := 0
	for i in keep:
		var t: Array = trees[i]
		var sc := float(t[3])
		var y := float(t[1])
		if terrain:
			y = terrain.height_at(float(t[0]), float(t[2]))
		# Small shape variations preserve the existing positions and sizes while
		# avoiding identical crowns along the street.
		var breadth := 0.91 + 0.18 * (0.5 + 0.5 * sin(float(i) * 2.31))
		var height := 0.94 + 0.12 * (0.5 + 0.5 * sin(float(i) * 1.73))
		var b := Basis(Vector3.UP, float(i) * 1.37).scaled(Vector3(sc * breadth, sc * height, sc * (2.0 - breadth)))
		var tr := Transform3D(b, Vector3(float(t[0]), y, float(t[2])))
		if selected.has(i):
			pilot.set_instance_transform(pilot_index, tr)
			pilot_index += 1
		else:
			mm.set_instance_transform(base_index, tr)
			base_index += 1
		mm2.set_instance_transform(i, tr)
	if pilot.instance_count > 0:
		var detail := MultiMeshInstance3D.new()
		detail.multimesh = pilot
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail.visibility_range_end = float(Quality.p.props_dist) * 1.3
		detail.visibility_range_end_margin = 80.0
		add_child(detail)
	tree_mm = MultiMeshInstance3D.new()
	tree_mm.multimesh = mm
	tree_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Quality.preset != "low" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree_mm.visibility_range_end = float(Quality.p.props_dist) * 1.3
	tree_mm.visibility_range_end_margin = 80.0
	add_child(tree_mm)
	trunk_mm = MultiMeshInstance3D.new()
	trunk_mm.multimesh = mm2
	trunk_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trunk_mm.visibility_range_end = float(Quality.p.props_dist)
	trunk_mm.visibility_range_end_margin = 60.0
	add_child(trunk_mm)


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
