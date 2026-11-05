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

func _batch(parts: Array[Transform3D], material: Material, batch_name := "") -> void:
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
	if not batch_name.is_empty():
		node.name = batch_name
	node.multimesh = mm
	node.visibility_range_end = 1800.0
	add_child(node)

func _t(pos: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), pos)


func _museum_stone() -> StandardMaterial3D:
	# Pale, fine-jointed exterior marble; derived from Poly Haven CC0 material.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.88, 0.86, 0.82)
	m.albedo_texture = load("res://assets/textures/museum_marble_diff.jpg")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/museum_marble_nor.jpg")
	m.normal_scale = 0.18
	m.roughness = 0.82
	m.roughness_texture = load("res://assets/textures/museum_marble_rough.jpg")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.55, 0.55, 0.55)
	return m


func _build_museum() -> void:
	# The mapped outer footprint is roughly 90 x 65 m in this local frame.
	# Its square-facing mosaic volume projects forward above the recessed portico.
	var stone := _museum_stone()
	var pale := _mat(Color("d5d4ce"))
	var dark := _mat(Color("303a3b"))
	var glass := _mat(Color("35494b"))
	var reveals := _mat(Color("888d87"))
	_box(Vector3(0, 0.45, 0), Vector3(90, 0.9, 64), pale)
	# A continuous slab and parapet retain the correctly broad, flat silhouette.
	_box(Vector3(0, 21.1, 0), Vector3(90, 0.65, 64), stone)
	_box(Vector3(0, 5.3, 0), Vector3(90, 0.5, 64), stone)
	_box(Vector3(0, 13.25, -31.75), Vector3(90, 15.5, 0.5), stone)
	# Deep-shaded ground storey under the heavy upper marble volumes.
	_box(Vector3(0, 2.9, 0), Vector3(88.6, 4.6, 62.6), dark)
	_box(Vector3(0, 2.85, 31.35), Vector3(88, 4.35, 0.08), glass)
	# Side elevations have genuine openings in the wall: tall recessed glazing
	# and narrow shadowed reveals between long white marble-clad piers.
	var masonry: Array[Transform3D] = []
	var side_windows: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var mullions: Array[Transform3D] = []
	var ground_panes: Array[Transform3D] = []
	var ground_walls: Array[Transform3D] = []
	for side in [-1.0, 1.0]:
		var wall_x: float = side * 44.75
		masonry.append(_t(Vector3(wall_x, 6.65, 0), Vector3(0.5, 2.2, 63)))
		masonry.append(_t(Vector3(wall_x, 20.0, 0), Vector3(0.5, 1.6, 63)))
		for n in 11:
			var z := -28.0 + n * 5.6
			side_windows.append(_t(Vector3(side * 44.48, 13.1, z), Vector3(0.08, 10.7, 1.0)))
			for y in [9.8, 15.2, 18.0]:
				mullions.append(_t(Vector3(side * 44.56, y, z), Vector3(0.07, 0.12, 1.0)))
			for edge in [-1.0, 1.0]:
				frames.append(_t(Vector3(side * 44.83, 13.1, z + edge * 0.62), Vector3(0.30, 11.2, 0.18)))
			var ground_panel := _t(Vector3(side * 44.35, 2.75, z), Vector3(0.08, 3.8, 4.8))
			if n % 3 == 0:
				ground_walls.append(ground_panel)
			else:
				ground_panes.append(ground_panel)
		for n in 12:
			var z := -30.8 + n * 5.6
			masonry.append(_t(Vector3(wall_x, 13.1, z), Vector3(0.5, 11.0, 4.45)))
		for n in 12:
			var z := -30.5 + n * 5.5
			frames.append(_t(Vector3(side * 44.5, 2.85, z), Vector3(0.35, 4.5, 0.5)))
	_batch(masonry, stone, "MuseumSideMasonry")
	_batch(side_windows, glass, "MuseumRecessedWindows")
	_batch(frames, reveals, "MuseumWindowReveals")
	_batch(mullions, reveals, "MuseumWindowMullions")
	_batch(ground_panes, glass, "MuseumGroundGlazing")
	_batch(ground_walls, _mat(Color("59645e")), "MuseumGroundStone")
	# Side wings frame the projecting mosaic. Their restrained slit windows
	# echo the elevations in the reference photograph.
	_box(Vector3(-31.8, 13.25, 31.75), Vector3(26.4, 15.5, 0.5), stone)
	_box(Vector3(31.8, 13.25, 31.75), Vector3(26.4, 15.5, 0.5), stone)
	_box(Vector3(0, 15.05, 32.1), Vector3(37.4, 11.1, 4.2), stone)
	var piers: Array[Transform3D] = []
	for i in 7:
		piers.append(_t(Vector3(-16.8 + i * 5.6, 4.3, 32.0), Vector3(1.0, 7.7, 1.4)))
	_batch(piers, stone, "MuseumPorticoPiers")
	# Projecting panel is the existing credited photograph of the real mosaic.
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
	artwork.position = Vector3(0, 15.05, 34.22)
	artwork.visibility_range_end = 1800.0
	add_child(artwork)

func build(id: String) -> void:
	var ivory := _mat(Color("e1ded2"), true)
	var trim := _mat(Color("d6d4c8"))
	var glass := _mat(Color("425864"))
	if id == "national_museum":
		_build_museum()
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
