extends Node3D
## Unbranded interpretations based on the mapped Tirana building footprints.
## Museum proportions and mosaic: https://www.mhk.gov.al/national-historical-museum-celebrates-the-35th-anniversary-with-retro-exhibition/
## Prime minister's building: https://tiranatriennale.com/pages/building.html?id=prime-ministers-office

func _mat(col: Color, stone := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	if stone:
		m.albedo_texture = load("res://assets/textures/landmark_ashlar.jpg")
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.2, 0.2, 0.2)
	return m

func _box(pos: Vector3, size: Vector3, material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var node := MeshInstance3D.new()
	node.mesh = box
	node.position = pos
	node.material_override = material
	node.visibility_range_end = 1800.0
	add_child(node)

func _batch(parts: Array[Transform3D], material: Material) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = parts.size()
	for i in parts.size():
		mm.set_instance_transform(i, parts[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.visibility_range_end = 1800.0
	add_child(node)

func _t(pos: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), pos)

func build(id: String) -> void:
	var ivory := _mat(Color("e1ded2"), true)
	var trim := _mat(Color("d6d4c8"))
	var glass := _mat(Color("425864"))
	if id == "national_museum":
		# The large mosaic panel, pale piers and dark glazing face the square.
		_box(Vector3(0, 10.5, -4), Vector3(90, 21, 35), ivory)
		_box(Vector3(0, 0.55, 11.5), Vector3(94, 1.1, 12), trim)
		_box(Vector3(0, 4.7, 14.1), Vector3(84, 7.5, 0.25), glass)
		var piers: Array[Transform3D] = []
		for i in 15:
			piers.append(_t(Vector3(-42 + 6 * i, 5.2, 14.5), Vector3(0.8, 8.5, 1.1)))
		_batch(piers, trim)
		var image := StandardMaterial3D.new()
		image.albedo_texture = load("res://assets/landmarks/national_museum_mosaic.jpg")
		image.roughness = 1.0
		image.cull_mode = BaseMaterial3D.CULL_DISABLED
		var panel := QuadMesh.new()
		panel.size = Vector2(37, 11)
		var artwork := MeshInstance3D.new()
		artwork.name = "MuseumMosaic"
		artwork.mesh = panel
		artwork.material_override = image
		artwork.position = Vector3(0, 15.1, 13.61)
		artwork.visibility_range_end = 1800.0
		add_child(artwork)
	elif id == "prime_minister":
		# Pale rationalist three-storey facade and flanking wings.
		_box(Vector3(0, 8, 0), Vector3(70, 16, 30), ivory)
		_box(Vector3(0, 16.5, 0), Vector3(72, 1, 32), trim)
		_box(Vector3(0, 0.6, 16.5), Vector3(38, 1.2, 6), trim)
		_box(Vector3(0, 5.5, 15.1), Vector3(8, 9, 0.5), trim)
		var windows: Array[Transform3D] = []
		for floor_index in 3:
			for col in 16:
				var x := -30.0 + col * 4.0
				if absf(x) < 5 and floor_index == 0:
					continue
				windows.append(_t(Vector3(x, 3.2 + 4.4 * floor_index, 15.12), Vector3(1.9, 2.8, 0.12)))
		_batch(windows, glass)
