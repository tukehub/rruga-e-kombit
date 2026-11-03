class_name Landmarks
extends Node3D
## Original geometric interpretations, placed at surveyed OSM/DEM anchors.
## No downloaded photographs or proprietary meshes.

var _materials := {}

func _material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var key := str(color) + str(metal)
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75 if metal == 0.0 else 0.3
		m.metallic = metal
		_materials[key] = m
	return _materials[key]

func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, metal := 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _material(color, metal)
	n.position = pos
	n.visibility_range_end = 2200.0
	parent.add_child(n)
	return n

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, pos, color)


func _boxes(parent: Node3D, parts: Array, color: Color, metal := 0.0) -> void:
	# Batch repeated architectural features so windows and balconies do not
	# become hundreds of individual draw calls on phones.
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	unit.material = _material(color, metal)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = unit
	instances.instance_count = parts.size()
	for i in parts.size():
		var p: Vector3 = parts[i][0]
		var sz: Vector3 = parts[i][1]
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(sz), p))
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.visibility_range_end = 2200.0
	parent.add_child(node)


func _pyramid_stone() -> StandardMaterial3D:
	if not _materials.has("pyramid_stone"):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/landmark_concrete.jpg")
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
		mat.roughness = 0.9
		_materials["pyramid_stone"] = mat
	return _materials["pyramid_stone"]


func _ashlar_stone() -> StandardMaterial3D:
	if not _materials.has("ashlar_stone"):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://assets/textures/landmark_ashlar.jpg")
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
		mat.roughness = 0.92
		_materials["ashlar_stone"] = mat
	return _materials["ashlar_stone"]


func _pyramid_roof(parent: Node3D) -> void:
	# Four sloping glazed planes and batched, individual concrete stair treads.
	# The coloured pavilions remain separate, as on the renovated building.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := [Vector3(-26, 2, -26), Vector3(26, 2, -26), Vector3(26, 2, 26), Vector3(-26, 2, 26)]
	var inner := [Vector3(-4, 16, -4), Vector3(4, 16, -4), Vector3(4, 16, 4), Vector3(-4, 16, 4)]
	for i in 4:
		var j := (i + 1) % 4
		for p in [outer[i], inner[i], outer[j], outer[j], inner[i], inner[j]]:
			st.add_vertex(p)
	st.generate_normals()
	var roof := _part(parent, st.commit(), Vector3.ZERO, Color("e2e1dc"))
	roof.material_override = _pyramid_stone()
	(_pyramid_stone() as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	var treads := []
	for i in 37:
		var r := 25.0 - i * 0.56
		var y := 2.7 + i * 0.36
		for side in [-1.0, 1.0]:
			for offset in [-7.0, 0.0, 7.0]:
				if r < absf(offset) + 2.5:
					continue
				treads.append([Vector3(side * r, y, offset), Vector3(0.58, 0.17, 4.4)])
				treads.append([Vector3(offset, y, side * r), Vector3(4.4, 0.17, 0.58)])
	_boxes(parent, treads, Color("ebe9e2"))
	var steps := parent.get_child(parent.get_child_count() - 1) as MultiMeshInstance3D
	(steps.multimesh.mesh as BoxMesh).material = _pyramid_stone()


func _downtown_glazing(parent: Node3D) -> void:
	# Opaque glazing avoids expensive transparency sorting; a single MultiMesh
	# supplies small variations between panes without a draw call per window.
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("819ca8")
	mat.roughness = 0.27
	mat.metallic = 0.12
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	var transforms := []
	for side in [-1.0, 1.0]:
		for floor_no in 37:
			var y := 5.0 + floor_no * 3.65
			for col in 12:
				transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(2.74, 3.25, 1)), Vector3(-16.5 + col * 3.0, y, side * 15.03)))
			for col in 9:
				var basis := Basis(Vector3.UP, PI * 0.5).scaled(Vector3(1, 3.25, 2.95))
				transforms.append(Transform3D(basis, Vector3(side * 18.53, y, -12.0 + col * 3.0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var shade := 0.80 + float((i * 37 + floori(float(i) / 11.0)) % 17) * 0.011
		mm.set_instance_color(i, Color(shade, shade, shade, 1.0))
	var panes := MultiMeshInstance3D.new()
	panes.name = "DowntownGlazing"
	panes.multimesh = mm
	panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panes.visibility_range_end = 1300.0
	parent.add_child(panes)


func _university_arches(parent: Node3D) -> void:
	# The front elevation has arched entrance openings and an arched top row.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for base in [Vector3(-6.5, 6.3, -9.26), Vector3(0, 6.3, -9.26), Vector3(6.5, 6.3, -9.26), Vector3(-8, 26.75, -9.26), Vector3(-4, 26.75, -9.26), Vector3(0, 26.75, -9.26), Vector3(4, 26.75, -9.26), Vector3(8, 26.75, -9.26)]:
		var radius := 1.6 if base.y < 10.0 else 1.05
		for i in 12:
			var a := PI * float(i) / 12.0
			var b := PI * float(i + 1) / 12.0
			st.add_vertex(base)
			st.add_vertex(base + Vector3(cos(a) * radius, sin(a) * radius, 0))
			st.add_vertex(base + Vector3(cos(b) * radius, sin(b) * radius, 0))
	st.generate_normals()
	var arches := _part(parent, st.commit(), Vector3.ZERO, Color("3f5055"))
	(arches.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED

func _column(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 16
	return _part(parent, mesh, pos, color)

func load_anchors(anchors: Array) -> void:
	for anchor in anchors:
		var root := Node3D.new()
		root.name = str(anchor.id)
		add_child(root)
		root.position = Vector3(anchor.x, anchor.y, anchor.z)
		root.rotation.y = deg_to_rad(float(anchor.get("yaw", 0)))
		build(root, str(anchor.id))

func build(root: Node3D, id: String) -> void:
	var stone := Color("b7aa91")
	var bronze := Color("546656")
	match id:
		"pyramid":
			# Low, broad white pyramid with sloping stairways and a glass centre.
			var base := _box(root, Vector3(0, 1, 0), Vector3(58, 2, 58), Color("d7d2c9"))
			base.material_override = _pyramid_stone()
			_pyramid_roof(root)
			_box(root, Vector3(0, 10, 0), Vector3(8, 14, 8), Color("667f8b"))
			# MVRDV's 2023 renovation introduced small colourful pavilions
			# amongst the white stairways. Keep them within the monument footprint.
			_boxes(root, [
				[Vector3(-19, 8.0, -17), Vector3(6.2, 5.2, 5.4)],
				[Vector3(16, 8.0, 18), Vector3(5.6, 5.2, 5.8)],
			], Color("e3ac54"))
			_boxes(root, [
				[Vector3(18, 8.0, -15), Vector3(5.6, 5.2, 5.8)],
				[Vector3(-16, 8.0, 17), Vector3(6.0, 5.2, 5.4)],
			], Color("a6bbc2"))
			_boxes(root, [
				[Vector3(-17, 8.5, -19.8), Vector3(3.1, 2.7, 0.15)],
				[Vector3(18, 8.5, -18.0), Vector3(3.1, 2.7, 0.15)],
				[Vector3(-16, 8.5, 19.8), Vector3(3.1, 2.7, 0.15)],
				[Vector3(16, 8.5, 21.0), Vector3(3.1, 2.7, 0.15)],
			], Color("607983"), 0.1)
		"downtown_one":
			# MVRDV's 140 m tower has a pale grid and projecting balconies that
			# form a pixelated outline of Albania on the main facades.
			_box(root, Vector3(0, 70, 0), Vector3(37, 140, 30), Color("718d9a"))
			_downtown_glazing(root)
			_box(root, Vector3(0, 3, 0), Vector3(49, 6, 39), Color("d6d4c9"))
			var grid := []
			for side in [-1.0, 1.0]:
				for i in 13:
					grid.append([Vector3(-18.0 + i * 3.0, 71, side * 15.12), Vector3(0.26, 138, 0.26)])
				for i in 37:
					grid.append([Vector3(0, 5.0 + i * 3.65, side * 15.14), Vector3(37, 0.22, 0.24)])
			_boxes(root, grid, Color("d5d2c8"))
			var rows := ["000110000", "001111000", "011111100", "001111110", "001111100", "000111110", "001111100", "001111100", "000111000", "000111000", "000110000", "000100000"]
			var balconies := []
			for side in [-1.0, 1.0]:
				for row in rows.size():
					for col in rows[row].length():
						if rows[row].substr(col, 1) == "1":
							var p := Vector3((col - 4) * 3.6, 122.0 - row * 9.0, side * 16.6)
							balconies.append([p, Vector3(3.0, 0.42, 3.2)])
							balconies.append([p + Vector3(0, 1.1, side * 1.55), Vector3(3.0, 1.7, 0.15)])
			_boxes(root, balconies, Color("dedbd1"))
		"eyes_tirana":
			# Four offset dark glazed volumes with the distinctive recessed bands.
			_box(root, Vector3(0, 4, 0), Vector3(35, 8, 38), Color("283541"))
			for i in 4:
				var x := 3.0 if i % 2 == 1 else -3.0
				_box(root, Vector3(x, 23 + i * 30, 0), Vector3(29, 28, 29), Color("25394b"))
				var fins := []
				for side in [-1.0, 1.0]:
					for col in 10:
						fins.append([Vector3(x - 13.5 + col * 3.0, 23 + i * 30, side * 14.58), Vector3(0.23, 28, 0.2)])
				_boxes(root, fins, Color("171d29"))
			_box(root, Vector3(0, 129, 0), Vector3(25, 2, 26), Color("262a35"))
		"polytechnic":
			# Mother Teresa Square: central tower with two symmetrical lower wings.
			var stone_col := Color("c9c0ad")
			var main := _box(root, Vector3(0, 15, 0), Vector3(24, 30, 18), stone_col)
			main.material_override = _ashlar_stone()
			for side in [-1.0, 1.0]:
				var wing := _box(root, Vector3(side * 28, 8, 0), Vector3(32, 16, 18), stone_col)
				wing.material_override = _ashlar_stone()
			_box(root, Vector3(0, 0.6, -12), Vector3(88, 1.2, 7), Color("b6ae9f"))
			var windows := []
			for side in [-1.0, 1.0]:
				for row in 3:
					for col in 5:
						windows.append([Vector3(side * (15.0 + col * 5.7), 4.5 + row * 4.2, -9.1), Vector3(2.0, 2.7, 0.2)])
			for row in 5:
				for col in 5:
					windows.append([Vector3(-8.0 + col * 4, 8.5 + row * 4.0, -9.1), Vector3(2.1, 2.5, 0.2)])
			for col in [-6.5, 0.0, 6.5]:
				windows.append([Vector3(col, 3.7, -9.15), Vector3(3.2, 5.2, 0.2)])
			_boxes(root, windows, Color("3f5055"))
			var reveals := []
			for window in windows:
				var p: Vector3 = window[0]
				var sz: Vector3 = window[1]
				for edge in [-1.0, 1.0]:
					reveals.append([p + Vector3(edge * sz.x * 0.5, 0, -0.06), Vector3(0.12, sz.y, 0.12)])
				reveals.append([p + Vector3(0, sz.y * 0.5, -0.06), Vector3(sz.x, 0.12, 0.12)])
			_boxes(root, reveals, Color("e2d6c4"))
			_university_arches(root)
			_boxes(root, [
				[Vector3(0, 30.1, 0), Vector3(24.8, 0.5, 18.8)],
				[Vector3(-28, 16.1, 0), Vector3(32.8, 0.5, 18.8)],
				[Vector3(28, 16.1, 0), Vector3(32.8, 0.5, 18.8)],
			], Color("e2d6c4"))
		"toptani":
			# Main mass based on the six-storey, approximately 36 m OSM footprint.
			_box(root, Vector3(0, 18, 0), Vector3(85, 36, 55), Color("697f86"))
			var cladding := []
			for side in [-1.0, 1.0]:
				for i in 20:
					cladding.append([Vector3(-40 + i * 4.2, 18, side * 27.6), Vector3(0.3, 35, 0.2)])
				for i in 7:
					cladding.append([Vector3(0, 3 + i * 5, side * 27.62), Vector3(85, 0.4, 0.2)])
			_boxes(root, cladding, Color("b7b3a8"))
		"cathedral":
			# Orthodox cathedral and separate bell tower. Dome 32.2 m, tower 46 m.
			_column(root, Vector3(0, 9, 0), 17, 18, Color("ddd8c8"))
			_column(root, Vector3(0, 20, 0), 12, 4, Color("d0c8b5"))
			var dome := SphereMesh.new()
			dome.radius = 11.0
			dome.height = 22.0
			dome.is_hemisphere = true
			dome.radial_segments = 24
			dome.rings = 12
			_part(root, dome, Vector3(0, 21.2, 0), Color("96a3a2"), 0.1)
			_column(root, Vector3(0, 31.7, 0), 0.3, 1.0, Color("c6ac6d"))
			_column(root, Vector3(22, 21, 0), 2.0, 42, Color("d7d0c0"))
			_column(root, Vector3(22, 44, 0), 2.5, 4, Color("b6aa8d"), 0.3)
		"bank_albania":
			var bank := _box(root, Vector3(0, 8, 0), Vector3(36, 16, 30), Color("d3c4ac"))
			bank.material_override = _ashlar_stone()
			_box(root, Vector3(0, 16.5, 0), Vector3(38, 1, 32), Color("e3d7c3"))
			_box(root, Vector3(0, 10, -15.4), Vector3(22, 11, 1.0), Color("c1aa8e"))
			for x in [-14.0, -9.0, -4.0, 1.0, 6.0, 11.0, 16.0]:
				_box(root, Vector3(x, 9, -15.6), Vector3(2.6, 7, 0.3), Color("6f7b7c"))
		"international_hotel":
			_box(root, Vector3(0, 24, 0), Vector3(50, 48, 23), Color("d4d3cc"))
			_box(root, Vector3(0, 3, 0), Vector3(56, 6, 32), Color("c7c4ba"))
			# The hotel's characteristic continuous window bands run around its
			# perimeter. Show them on every side, including the race approach.
			var windows := []
			for floor_no in 14:
				var y := 4.8 + floor_no * 3.05
				for side in [-1.0, 1.0]:
					windows.append([Vector3(0, y, side * 11.6), Vector3(48, 1.8, 0.18)])
					windows.append([Vector3(side * 25.1, y, 0), Vector3(0.18, 1.8, 22)])
			_boxes(root, windows, Color("728b96"))
		"skanderbeg":
			_box(root, Vector3(0, 1.6, 0), Vector3(10, 3.2, 6), stone)
			# Horse body, four legs, head and raised neck; mounted rider and sword.
			_box(root, Vector3(0, 5.0, 0), Vector3(2, 2, 4.5), bronze)
			for x in [-0.65, 0.65]:
				for z in [-1.5, 1.5]:
					_column(root, Vector3(x, 3.7, z), 0.25, 2.2, bronze)
			var neck := _box(root, Vector3(0, 6, -1.9), Vector3(0.8, 2.5, 0.9), bronze)
			neck.rotation.x = -0.3
			_box(root, Vector3(0, 7.2, -2.4), Vector3(0.8, 0.8, 1.3), bronze)
			_column(root, Vector3(0, 7, 0), 0.65, 2.2, bronze)
			_column(root, Vector3(0, 8.6, 0), 0.45, 0.8, bronze)
			var sword := _box(root, Vector3(1.0, 9, -0.5), Vector3(0.12, 3, 0.15), Color("b8b6a0"))
			sword.rotation.z = -0.3
		"castle_berat", "castle_gjirokaster", "rozafa":
			_box(root, Vector3(0, 4, 0), Vector3(85, 8, 38), stone.darkened(0.2))
			for x in [-42.0, -14.0, 14.0, 42.0]:
				_box(root, Vector3(x, 7, -18), Vector3(10, 14, 10), stone)
				for dx in [-3.0, 0.0, 3.0]:
					_box(root, Vector3(x + dx, 14.5, -18), Vector3(1.5, 2, 10), stone)
			for x in range(-40, 41, 5):
				_box(root, Vector3(x, 9, 18), Vector3(2, 2, 3), stone)
		"mangalem", "gorica", "stone_roofs":
			for row in 3:
				for col in 5:
					var p := Vector3(col * 10 - 20, row * 3.0, row * 11)
					_box(root, p + Vector3(0, 4, 0), Vector3(8, 8, 9), Color("e4dbc6"))
					_box(root, p + Vector3(0, 8.2, 0), Vector3(9, 0.7, 10), Color("686b68"))
					for x in [-2.5, 0.0, 2.5]:
						_box(root, p + Vector3(x, 5.2, -4.55), Vector3(1.3, 2, 0.1), Color("353a41"))
		"painted_mosque", "mosque", "mosque_lead":
			_box(root, Vector3(0, 5, 0), Vector3(18, 10, 18), Color("e5dbc1"))
			_column(root, Vector3(0, 12, 0), 8.0, 5, Color("738e93"), 0.8)
			_column(root, Vector3(13, 12, 0), 1.2, 24, stone)
			_column(root, Vector3(13, 25, 0), 1.8, 4, Color("58787b"), 0)
			if id == "painted_mosque":
				for side in [-1.0, 1.0]:
					for x in range(-7, 8, 3):
						_box(root, Vector3(x, 5.5, side * 9.05), Vector3(2, 6, 0.15), Color("b76a4f"))
						_box(root, Vector3(x, 6, side * 9.15), Vector3(1, 3, 0.15), Color("4c8788"))
		"independence":
			_box(root, Vector3(0, 1, 0), Vector3(18, 2, 12), stone)
			for i in 5:
				_column(root, Vector3(i * 2 - 4, 4.5, 0), 0.8, 5, bronze)
			_column(root, Vector3(0, 11, 0), 1, 16, bronze)
			_box(root, Vector3(2, 17, 0), Vector3(4, 3, 0.2), Color("a4282e"))
		"mother_teresa":
			_box(root, Vector3(0, 0.2, 0), Vector3(80, 0.4, 55), stone)
			for side in [-1.0, 1.0]:
				_box(root, Vector3(side * 36, 9, 12), Vector3(12, 18, 45), Color("d8c8b0"))
		"clocktower":
			_box(root, Vector3(0, 12, 0), Vector3(5, 24, 5), stone)
			_column(root, Vector3(0, 25, 0), 4, 3, Color("85664e"), 0)
		"bridge_gorica":
			_box(root, Vector3(0, 5, 0), Vector3(70, 2, 8), stone)
			for x in range(-30, 31, 10):
				_box(root, Vector3(x, 1.5, 0), Vector3(2, 7, 8), stone)
		"blloku_sign":
			var label := Label3D.new()
			label.text = "BLLOKU"
			label.font_size = 96
			label.pixel_size = 0.04
			label.position.y = 6
			label.modulate = Color("ff2d6f")
			root.add_child(label)
		_:
			_column(root, Vector3(0, 9, 0), 0.15, 18, stone)
			_box(root, Vector3(2, 16, 0), Vector3(4, 2.5, 0.1), Color("b3272e"))
