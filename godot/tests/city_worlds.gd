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
		await get_tree().process_frame
		print("CITY WORLD: ", city.id, " loaded with six cars")
		Sfx.stop_all()
		scene.queue_free()
		await get_tree().process_frame
		count += 1
	print("CITY WORLDS: ", count, " loaded")
	get_tree().quit()
