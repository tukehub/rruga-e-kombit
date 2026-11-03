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
	for i in 30:
		trees.append([float(i), 0.0, 0.0, 1.0])
		trees.append([1000.0 + float(i), 0.0, 0.0, 1.0])
	props._build_trees(trees, null, "tirane")
	assert(props._near_leaves != null and props._near_branches != null)
	props._update_tree_lod(Vector3.ZERO, true)
	assert(props._near_marked.size() == 24)
	assert(props._near_leaves.visible_instance_count == 24 and props._near_branches.visible_instance_count == 24)
	var old_refs := props._near_marked.duplicate()
	for ref in old_refs:
		assert((ref.world as Transform3D).origin.x < 100.0)
		if DisplayServer.get_name() != "headless":
			assert((ref.mm.get_instance_transform(ref.index) as Transform3D).basis.is_equal_approx(Basis.from_scale(Vector3.ZERO)))
	props._update_tree_lod(Vector3(1000, 0, 0), true)
	assert(props._near_marked.size() == 24)
	for ref in old_refs:
		assert(not props._near_marked.has(ref))
		if DisplayServer.get_name() != "headless":
			assert((ref.mm.get_instance_transform(ref.index) as Transform3D).is_equal_approx(ref.local))
	for ref in props._near_marked:
		assert((ref.world as Transform3D).origin.x > 900.0)
	props._update_tree_lod(Vector3(5000, 0, 0), true)
	assert(props._near_marked.is_empty() and props._near_leaves.visible_instance_count == 0 and props._near_branches.visible_instance_count == 0)
	props.queue_free()
	print("TREE LOD: moving pool passed")
