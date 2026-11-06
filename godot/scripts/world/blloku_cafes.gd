extends Node3D
## Unbranded café terraces alongside the Blloku portion of the race course.
## Instances share meshes so several cafés add only a few draw calls.
const FURNITURE: PackedScene = preload("res://assets/props/blloku_cafe_furniture.glb")

func _collect_furniture(node: Node, parent_transform: Transform3D, parts: Array) -> void:
	var combined := parent_transform
	if node is Node3D:
		combined = parent_transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		parts.append([node.mesh, combined])
	for child in node.get_children():
		_collect_furniture(child, combined, parts)

func _add_furniture(placements: Array[Transform3D]) -> void:
	if placements.is_empty():
		return
	var root := FURNITURE.instantiate()
	var parts: Array = []
	_collect_furniture(root, Transform3D.IDENTITY, parts)
	# Keep bounds local to small groups: one MultiMesh for the whole Blloku
	# stretch could disappear at either end when its center is out of range.
	var chunks := {}
	for placement in placements:
		var key := Vector2i(floori(placement.origin.x / 80.0), floori(placement.origin.z / 80.0))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(placement)
	for key: Vector2i in chunks:
		var chunk_origin := Vector3((key.x + 0.5) * 80.0, 0, (key.y + 0.5) * 80.0)
		for part in parts:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part[0]
			mm.instance_count = chunks[key].size()
			for i in mm.instance_count:
				var t: Transform3D = chunks[key][i] * part[1]
				t.origin -= chunk_origin
				mm.set_instance_transform(i, t)
			var instance := MultiMeshInstance3D.new()
			instance.name = "CafeFurniture_%d_%d" % [key.x, key.y]
			instance.position = chunk_origin
			instance.multimesh = mm
			instance.visibility_range_end = 160.0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
	root.free()

func _group(mesh: Mesh, transforms: Array, color: Color) -> void:
	if transforms.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.visibility_range_end = 450.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func build(cafes: Array) -> void:
	var decks: Array[Transform3D] = []
	var awnings := [[], [], []]
	var walls := [[], [], []]
	var windows: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	var furniture: Array[Transform3D] = []
	for i in cafes.size():
		var cafe = cafes[i]
		if cafe.size() < 4:
			continue
		var origin := Vector3(float(cafe[0]), float(cafe[1]), float(cafe[2]))
		var base := Transform3D(Basis(Vector3.UP, float(cafe[3])), origin)
		# Blloku's natural ground sits below the conformed race surface. Put
		# each terrace on a solid raised deck so its tables and canopy remain
		# visible over the road edge, while the deck reaches the ground.
		decks.append(base * Transform3D(Basis.from_scale(Vector3(5.5, 1.5, 3.0)), Vector3(0, 0.75, 0)))
		base.origin.y += 1.5
		var style := i % 3
		var outside := 1.0 if i % 2 == 0 else -1.0
		awnings[style].append(base * Transform3D(Basis.from_scale(Vector3(5.0, 0.18, 2.5)), Vector3(0, 2.5, 0)))
		# Each terrace faces a different small shop outside the racing barriers.
		walls[style].append(base * Transform3D(Basis.from_scale(Vector3(0.35, 3.2, 3.0)), Vector3(outside * 3.05, 1.6, 0)))
		windows.append(base * Transform3D(Basis.from_scale(Vector3(0.08, 1.8, 1.9)), Vector3(outside * 2.85, 1.65, 0)))
		for x in [-2.3, 2.3]:
			posts.append(base * Transform3D(Basis.from_scale(Vector3(0.12, 2.5, 0.12)), Vector3(x, 1.25, 0)))
		for x in [-1.25, 1.25]:
			furniture.append(base * Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)))
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var platforms := BoxMesh.new()
	platforms.size = Vector3.ONE
	_group(platforms, decks, Color("988b7a"))
	var canopy_colors := [Color("a84e3f"), Color("47745f"), Color("b89a65")]
	var facade_colors := [Color("e3d2b8"), Color("c5d1c3"), Color("d9c1ac")]
	for i in 3:
		var awning_mesh := BoxMesh.new()
		awning_mesh.size = Vector3.ONE
		_group(awning_mesh, awnings[i], canopy_colors[i])
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = Vector3.ONE
		_group(wall_mesh, walls[i], facade_colors[i])
	var glass := BoxMesh.new()
	glass.size = Vector3.ONE
	_group(glass, windows, Color("48616a"))
	var supports := BoxMesh.new()
	supports.size = Vector3.ONE
	_group(supports, posts, Color("474a48"))
	_add_furniture(furniture)
