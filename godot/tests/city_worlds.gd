extends Node
## Load each real city through the production race scene, including terrain and GLBs.

func _ready() -> void:
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
		if city.id == "tirane":
			# Ensure grouping keeps every tree and creates local batches that the
			# renderer can cull independently.
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/tirane/props.json"))
			var count_expected := int(data.trees.size() * float(Quality.p.tree_mul))
			var trunks := 0
			var crowns := 0
			var batches := 0
			for node in scene.props.get_children():
				if not node is MultiMeshInstance3D:
					continue
				if str(node.name).begins_with("TreeTrunk"):
					batches += 1
					trunks += node.multimesh.instance_count
				elif str(node.name).begins_with("TreeCanopy") or str(node.name).begins_with("TreeDetail"):
					crowns += node.multimesh.instance_count
			assert(batches > 1 and trunks == count_expected and crowns == count_expected)
		await get_tree().process_frame
		print("CITY WORLD: ", city.id, " loaded with six cars")
		Sfx.stop_all()
		scene.queue_free()
		await get_tree().process_frame
		count += 1
	print("CITY WORLDS: ", count, " loaded")
	get_tree().quit()
