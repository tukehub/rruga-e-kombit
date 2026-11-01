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
			_box(root, Vector3(0, 1, 0), Vector3(58, 2, 58), Color("d7d2c9"))
			for level in 10:
				var span := 52.0 - level * 4.2
				_box(root, Vector3(0, 2.6 + level * 1.25, 0), Vector3(span, 1.25, span), Color("e7e4dc"))
			_box(root, Vector3(0, 10, 0), Vector3(11, 15, 11), Color("667f8b"))
			for side in [-1.0, 1.0]:
				var stair := _box(root, Vector3(side * 13, 8, 0), Vector3(27, 0.7, 6), Color("f4f2e9"))
				stair.rotation.z = side * 0.48
				var stair2 := _box(root, Vector3(0, 8, side * 13), Vector3(6, 0.7, 27), Color("f4f2e9"))
				stair2.rotation.x = -side * 0.48
		"downtown_one":
			# Tall glazed slab with an original pattern of projecting white volumes.
			_box(root, Vector3(0, 69, 0), Vector3(35, 138, 26), Color("6e8896"))
			_box(root, Vector3(0, 3, 0), Vector3(44, 6, 34), Color("c5c7c4"))
			for row in 9:
				for col in 3:
					if (row * 3 + col * 5) % 4 != 0:
						var x := -11.0 + col * 11.0 + (3.0 if row % 2 == 0 else -1.0)
						_box(root, Vector3(x, 14.0 + row * 13.0, -14.0), Vector3(8, 7.5, 4), Color("deded8"))
		"eyes_tirana":
			# Four subtly rotated glass volumes give a stepped silhouette.
			_box(root, Vector3(0, 4, 0), Vector3(35, 8, 38), Color("c5cac9"))
			for i in 4:
				var section := _box(root, Vector3(0, 24 + i * 30, 0), Vector3(31 + i * 2, 30, 30 + i * 2), Color("8aa4ad"))
				section.rotation.y = deg_to_rad(float(i - 1) * 5.0)
				for side in [-1.0, 1.0]:
					var rim := _box(root, Vector3(side * (16 + i), 24 + i * 30, 0), Vector3(1.2, 29, 31 + i * 2), Color("e2e1db"))
					rim.rotation.y = deg_to_rad(float(i - 1) * 5.0)
		"bank_albania":
			_box(root, Vector3(0, 8, 0), Vector3(36, 16, 30), Color("d3c4ac"))
			_box(root, Vector3(0, 16.5, 0), Vector3(38, 1, 32), Color("e3d7c3"))
			_box(root, Vector3(0, 10, -15.4), Vector3(22, 11, 1.0), Color("c1aa8e"))
			for x in [-14.0, -9.0, -4.0, 1.0, 6.0, 11.0, 16.0]:
				_box(root, Vector3(x, 9, -15.6), Vector3(2.6, 7, 0.3), Color("6f7b7c"))
		"international_hotel":
			_box(root, Vector3(0, 24, 0), Vector3(50, 48, 23), Color("d4d3cc"))
			_box(root, Vector3(0, 3, 0), Vector3(56, 6, 32), Color("c7c4ba"))
			for floor_no in 9:
				_box(root, Vector3(0, 8 + floor_no * 4.1, -11.6), Vector3(45, 2.5, 0.2), Color("728b96"))
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
