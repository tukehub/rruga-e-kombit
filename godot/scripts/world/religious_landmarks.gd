extends Node3D
## Original, low-draw-call interpretations based on exterior reference imagery.
## Cathedral: https://orthodoxalbania.org/2020/en/2014/05/29/the-complex-of-new-cathedral-of-tirana-resurrection-of-christ-the-synodical-and-the-cultural-centre/
## Namazgja: https://commons.wikimedia.org/wiki/Category:Great_Namazg%C3%A2h_Mosque_of_Tirana

var _mats := {}

func _mat(key: String, color: Color, texture := false, metallic := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.78 if metallic == 0.0 else 0.52
		mat.metallic = metallic
		if texture:
			mat.albedo_texture = load("res://assets/textures/landmark_ashlar.jpg")
			mat.uv1_triplanar = true
			mat.uv1_scale = Vector3(0.28, 0.28, 0.28)
		_mats[key] = mat
	return _mats[key]

func _mesh(m: Mesh, p: Vector3, mat: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = m
	part.material_override = mat
	part.position = p
	part.visibility_range_end = 1500.0
	add_child(part)
	return part

func _box(p: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(m, p, mat)

func _cylinder(p: Vector3, r: float, height: float, mat: Material, top := -1.0, segments := 24) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r
	m.top_radius = r if top < 0 else top
	m.height = height
	m.radial_segments = segments
	return _mesh(m, p, mat)

func _dome(p: Vector3, r: float, mat: Material) -> MeshInstance3D:
	# SphereMesh's hemisphere mode stretches vertically in the mobile renderer.
	# Build an actual half-sphere so the measured height stays equal to radius.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 32
	var rings := 12
	for row in rings:
		for col in segments:
			for q in [[row, col], [row + 1, col + 1], [row, col + 1], [row, col], [row + 1, col], [row + 1, col + 1]]:
				var elevation := float(q[0]) / rings * PI * 0.5
				var azimuth := float(q[1]) / segments * TAU
				var n := Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
				st.set_normal(n)
				st.set_uv(Vector2(float(q[1]) / segments, float(q[0]) / rings))
				st.add_vertex(n * r)
	return _mesh(st.commit(), p, mat)

func _batch(parts: Array, mat: Material) -> void:
	if parts.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = mat
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = parts.size()
	for i in parts.size():
		instances.set_instance_transform(i, parts[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = instances
	node.visibility_range_end = 1500.0
	add_child(node)

func _transform(p: Vector3, size: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), p)

func build(id: String) -> void:
	var stone := _mat("stone", Color("ded9c9"), true)
	var trim := _mat("trim", Color("e9e1cf"))
	var dark := _mat("darkglass", Color("344752"), false, 0.08)
	var metal := _mat("gold", Color("bda465"), false, 0.45)
	if id == "cathedral":
		_build_cathedral(stone, trim, dark, metal)
	elif id == "namazgja":
		_build_namazgja(stone, trim, dark, metal)

func _build_cathedral(stone: Material, trim: Material, glass: Material, gold: Material) -> void:
	# Circular nave and gold-covered dome. Official dimensions: 32.2 m tall
	# dome, 46 m bell tower, and 26 m dome interior diameter.
	_cylinder(Vector3(0, 8.0, 0), 18.0, 16.0, stone)
	_cylinder(Vector3(0, 16.8, 0), 14.2, 2.0, trim)
	_cylinder(Vector3(0, 18.5, 0), 13.0, 3.0, stone)
	_dome(Vector3(0, 19.2, 0), 13.0, gold)
	_cylinder(Vector3(0, 32.8, 0), 0.3, 1.4, gold, 0.18, 12)
	var frame := []
	var panes := []
	# Narrow windows and repeated piers follow the round drum and drum rim.
	for i in 32:
		var a := TAU * i / 32.0
		var direction := Vector3(sin(a), 0, cos(a))
		panes.append(_transform(direction * 18.02 + Vector3(0, 9.2, 0), Vector3(1.55, 8.8, 0.12), a))
		frame.append(_transform(direction * 18.12 + Vector3(0, 9.2, 0), Vector3(0.22, 10.0, 0.2), a))
		if i % 2 == 0:
			panes.append(_transform(direction * 13.05 + Vector3(0, 18.6, 0), Vector3(0.95, 2.0, 0.1), a))
	_batch(panes, glass)
	_batch(frame, trim)
	# Wide white west-facing arched entrance; articulated frame and cross.
	_box(Vector3(0, 7.2, -18.1), Vector3(12.0, 12.4, 1.2), trim)
	_box(Vector3(0, 6.8, -18.76), Vector3(8.0, 10.7, 0.14), glass)
	_box(Vector3(0, 6.5, -18.88), Vector3(0.45, 8.0, 0.12), gold)
	_box(Vector3(0, 9.0, -18.90), Vector3(2.8, 0.45, 0.13), gold)
	# Bell tower has four candle-like columns around a narrow clock housing.
	var tx := 24.0
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			_cylinder(Vector3(tx + x, 20.0, z), 0.65, 40.0, trim, 0.56, 12)
	_cylinder(Vector3(tx, 40.3, 0), 3.4, 3.0, stone, 2.7, 16)
	_cylinder(Vector3(tx, 43.2, 0), 2.6, 3.2, gold, 0.25, 16)
	_box(Vector3(tx, 45.4, 0), Vector3(0.22, 1.3, 0.22), gold)
	_box(Vector3(tx, 45.7, 0), Vector3(0.9, 0.22, 0.22), gold)

func _build_namazgja(stone: Material, trim: Material, glass: Material, gold: Material) -> void:
	var roof := _mat("namazgja_roof", Color("8e9999"), false, 0.2)
	_box(Vector3(0, 1.0, 0), Vector3(49.0, 2.0, 49.0), stone)
	_box(Vector3(0, 9.0, 0), Vector3(42.0, 16.0, 42.0), stone)
	_box(Vector3(0, 17.0, 0), Vector3(40.0, 1.0, 40.0), trim)
	_cylinder(Vector3(0, 20.4, 0), 13.0, 6.0, stone)
	_dome(Vector3(0, 22.0, 0), 13.0, roof)
	_cylinder(Vector3(0, 35.5, 0), 0.32, 1.8, gold, 0.12, 12)
	# Four slender minarets and balconies frame the central dome.
	for x in [-22.0, 22.0]:
		for z in [-22.0, 22.0]:
			_cylinder(Vector3(x, 21.3, z), 1.25, 42.6, stone, 1.05, 12)
			_cylinder(Vector3(x, 34.0, z), 2.05, 1.0, trim, 1.9, 16)
			_cylinder(Vector3(x, 42.0, z), 1.15, 1.1, trim, 1.05, 12)
			_cylinder(Vector3(x, 46.4, z), 1.15, 7.7, roof, 0.04, 16)
			_cylinder(Vector3(x, 50.5, z), 0.16, 1.0, gold, 0.05, 8)
	# Half-domes around the central structure and a colonnaded entrance.
	for x in [-12.0, 12.0]:
		for z in [-12.0, 12.0]:
			_dome(Vector3(x, 16.6, z), 6.0, roof)
	var frames := []
	var panes := []
	for side in [-1.0, 1.0]:
		for i in 7:
			var x := -16.5 + i * 5.5
			panes.append(_transform(Vector3(x, 8.5, side * 21.03), Vector3(2.25, 8.0, 0.13)))
			frames.append(_transform(Vector3(x, 13.0, side * 21.10), Vector3(2.6, 0.32, 0.2)))
			var a := -16.5 + i * 5.5
			panes.append(_transform(Vector3(side * 21.03, 8.5, a), Vector3(2.25, 8.0, 0.13), PI * 0.5))
			frames.append(_transform(Vector3(side * 21.10, 13.0, a), Vector3(2.6, 0.32, 0.2), PI * 0.5))
	_batch(panes, glass)
	_batch(frames, trim)
