extends Node
## Load each real city through the production race scene, including terrain and GLBs.

func _ready() -> void:
	_test_tree_lod()
	Quality.set_preset("low")
	var count := 0
	for city in Data.CITIES:
		if not FileAccess.file_exists("res://assets/cities/%s/track.json" % city.id):
			continue
		Game.race_opts.city = city.id
		var scene: RaceScene = load("res://scenes/race.tscn").instantiate()
		add_child(scene)
		scene.set_process(false)
		assert(scene.cars.size() == 6 and scene.track.L > 1000)
		assert(scene.terrain != null and scene.buildings != null and scene.road != null)
		assert(scene.road.get_node_or_null("RoadsideBarriers") != null, "road edges should be visible")
		if city.id == "tirane":
			var landmark_root: Node = null
			for child in scene.props.get_children():
				if child is Landmarks:
					landmark_root = child
					break
			assert(landmark_root != null)
			assert(landmark_root.get_node_or_null("skanderbeg/SkanderbegBronze") != null, "the square needs its detailed equestrian monument")
			var stadium := landmark_root.get_node_or_null("air_albania/AirAlbaniaStadium/AirAlbaniaArchitecture") as MeshInstance3D
			assert(stadium != null and stadium.mesh != null, "the Air Albania stadium must load in Tirana")
			assert(stadium.mesh.get_aabb().size.y >= 111.0, "the stadium's corner tower should be visible at realistic height")
			var plaza := landmark_root.get_node_or_null("plaza_tower/PlazaTower/PlazaTowerArchitecture") as MeshInstance3D
			assert(plaza != null and plaza.mesh != null, "Plaza hotel must load in Tirana")
			assert(plaza.mesh.get_aabb().size.y >= 84.0, "Plaza tower should have its approximately 85m height")
			assert(landmark_root.get_node_or_null("namazgja/ReligiousLandmark") != null, "Namazgja mosque must load in Tirana")
			assert(landmark_root.get_node_or_null("cathedral/ReligiousLandmark") != null, "Orthodox cathedral must load in Tirana")
			assert(landmark_root.get_node_or_null("prime_minister/CivicLandmark") != null, "Prime minister's office must load in Tirana")
			var mosaic := landmark_root.get_node_or_null("national_museum/CivicLandmark/MuseumMosaic") as MeshInstance3D
			assert(mosaic != null and mosaic.material_override != null, "Museum and mosaic must load in Tirana")
			assert((mosaic.mesh as QuadMesh).size.is_equal_approx(Vector2(37, 11)) and mosaic.position.z > 34.0, "Museum mosaic should keep its real proportions on the projecting frontage")
			var windows := landmark_root.get_node_or_null("national_museum/CivicLandmark/MuseumRecessedWindows") as MultiMeshInstance3D
			var piers := landmark_root.get_node_or_null("national_museum/CivicLandmark/MuseumPorticoPiers") as MultiMeshInstance3D
			var marble := landmark_root.get_node_or_null("national_museum/CivicLandmark/MuseumSideMasonry") as MultiMeshInstance3D
			assert(windows != null and windows.multimesh.instance_count == 22, "Museum's two side elevations should have recessed windows")
			assert(piers != null and piers.multimesh.instance_count == 7, "Museum should have a recessed columned entrance")
			assert(marble != null and marble.multimesh.mesh != null, "Museum side masonry must load")
			var stone := marble.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
			assert(stone != null and stone.albedo_texture != null and stone.normal_enabled and stone.roughness_texture != null, "Museum marble needs color, normal and roughness maps")
			assert(scene.props.get_node_or_null("BllokuCafes") != null, "The Blloku route needs its café terraces")
			# Ensure grouping keeps every tree and creates local batches that the
			# renderer can cull independently.
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/tirane/props.json"))
			var count_expected := int(data.trees.size() * float(Quality.p.tree_mul))
			var crowns := 0
			var batches := 0
			for node in scene.props.get_children():
				if not node is MultiMeshInstance3D:
					continue
				if str(node.name).begins_with("TreeCanopy") or str(node.name).begins_with("TreeDetail"):
					batches += 1
					crowns += node.multimesh.instance_count
			assert(batches > 1 and crowns == count_expected)
		await get_tree().process_frame
		print("CITY WORLD: ", city.id, " loaded with six cars")
		Sfx.stop_all()
		scene.queue_free()
		await get_tree().process_frame
		count += 1
	print("CITY WORLDS: ", count, " loaded")
	get_tree().quit()


func _test_tree_lod() -> void:
	Quality.set_preset("high")
	var props := Props.new()
	add_child(props)
	var trees := []
	for i in 40:
		trees.append([float(i), 0.0, 0.0, 1.0])
		trees.append([1000.0 + float(i), 0.0, 0.0, 1.0])
	props._build_trees(trees, null, "tirane")
	assert(props._near_leaves != null and props._near_branches != null)
	props._update_tree_lod(Vector3.ZERO, true)
	assert(props._near_marked.size() == Props.NEAR_TREE_LIMIT)
	assert(props._near_leaves.visible_instance_count == Props.NEAR_TREE_LIMIT and props._near_branches.visible_instance_count == Props.NEAR_TREE_LIMIT)
	var old_refs := props._near_marked.duplicate()
	for ref in old_refs:
		assert((ref.world as Transform3D).origin.x < 100.0)
		if DisplayServer.get_name() != "headless":
			assert((ref.mm.get_instance_transform(ref.index) as Transform3D).basis.is_equal_approx(Basis.from_scale(Vector3.ZERO)))
	props._update_tree_lod(Vector3(1000, 0, 0), true)
	assert(props._near_marked.size() == Props.NEAR_TREE_LIMIT)
	for ref in old_refs:
		assert(not props._near_marked.has(ref))
		if DisplayServer.get_name() != "headless":
			assert((ref.mm.get_instance_transform(ref.index) as Transform3D).is_equal_approx(ref.local))
	for ref in props._near_marked:
		assert((ref.world as Transform3D).origin.x > 900.0)
	props._update_tree_lod(Vector3(5000, 0, 0), true)
	assert(props._near_marked.is_empty() and props._near_leaves.visible_instance_count == 0 and props._near_branches.visible_instance_count == 0)
	props.queue_free()
	var ahead_props := Props.new()
	add_child(ahead_props)
	var road_trees := []
	for i in 40:
		road_trees.append([float(i + 1) * 3.0, 0.0, 0.0, 1.0])
		road_trees.append([-float(i + 1) * 3.0, 0.0, 0.0, 1.0])
	ahead_props._build_trees(road_trees, null, "tirane")
	ahead_props._update_tree_lod(Vector3.ZERO, true, Vector3.RIGHT)
	var selected := ahead_props._near_marked.duplicate()
	var ahead_count := 0
	for ref in selected:
		if (ref.world as Transform3D).origin.x > 0.0:
			ahead_count += 1
	assert(ahead_count > Props.NEAR_TREE_LIMIT / 2)
	ahead_props._update_tree_lod(Vector3(0.5, 0, 0), true, Vector3.RIGHT)
	for ref in selected:
		assert(ahead_props._near_marked.has(ref))
	# Nearby trees stay detailed when the car turns toward the other side.
	ahead_props._update_tree_lod(Vector3.ZERO, true, Vector3.LEFT)
	for ref in ahead_props._tree_refs:
		if absf((ref.world as Transform3D).origin.x) < Props.TREE_PROTECTED_RADIUS:
			assert(ahead_props._near_marked.has(ref))
	ahead_props.queue_free()
	print("TREE LOD: moving pool passed")
