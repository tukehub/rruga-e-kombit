extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	Quality.set_preset("medium")
	Settings.dynamic_weather = true
	for def in Data.CARS:
		var car := CarVisual.new()
		add_child(car)
		car.setup(def, Color.WHITE, true)
		check(car.body != null and car.wheels.size() == 4, "car meshes " + def.id)
		var triangles := 0
		for mi in car.model.get_children():
			if mi is MeshInstance3D:
				for i in mi.mesh.get_surface_count():
					triangles += mi.mesh.surface_get_array_index_len(i) / 3
		check(triangles >= 25000 and triangles <= 60000, "car triangle budget " + def.id)
		car.queue_free()
	var sim_count := 0
	for city in Data.CITIES:
		if not FileAccess.file_exists("res://assets/cities/%s/track.json" % city.id):
			print("UNAVAILABLE CITY: ", city.id)
			continue
		var track := RaceTrack.load_city(city.id)
		for difficulty in 3:
			var race := Race.new(track, {"laps": 1, "diff": difficulty, "seed": 42, "no_player": true})
			race.started = true
			for step in 36000:
				race.step(1.0 / 60.0)
				race.take_events()
				if race.all_finished():
					break
			check(race.cars.size() == 6 and race.all_finished(), "full race " + city.id + " difficulty " + str(difficulty))
			for c in race.cars:
				check(is_finite(c.s) and is_finite(c.v), "finite simulation")
			sim_count += 1
	var combat := Race.new(RaceTrack.load_city("tirane"), {"seed": 7})
	combat.started = true
	var effects := FxVisual.new()
	add_child(effects)
	effects.setup(combat, combat.track)
	for type in Data.PW_KEYS:
		combat.player.health = 1.0
		combat.player.slots = [{"type": type, "ammo": 1}]
		combat.use_item(combat.player, false)
		check(combat.player.slots.is_empty(), "power-up consumed " + type)
		effects._process(0.016)
	effects.boom(combat.track.pos(0, 0), Color.CYAN)
	effects._process(1.0)
	combat.projs.clear()
	combat.mines.clear()
	combat.domes.clear()
	effects._process(0.016)
	check(effects._nodes.is_empty(), "expired combat visuals reclaimed")
	effects.queue_free()
	var controls := RaceInput.new()
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.size = Vector2(1920, 1080)
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = Vector2(1600, 500)
	touch.pressed = true
	controls._gui_input(touch)
	check(controls.gas and not controls.brake, "right touch gas")
	touch = touch.duplicate()
	touch.index = 2
	touch.position.x = 300
	controls._gui_input(touch)
	check(controls.gas and controls.brake, "simultaneous gas/brake")
	controls.reset_controls()
	check(not controls.gas and not controls.brake, "focus/pause clears held touches")
	controls.queue_free()
	var sky := SkyEnv.new()
	add_child(sky)
	sky.apply("day")
	sky.transition_to("rain", 2.0)
	sky.advance(1.0)
	check(sky.wet > 0.4 and sky.wet < 0.6, "interpolated wet road")
	sky.advance(1.0)
	check(sky.wet == 1.0 and sky.rain.emitting, "rain transition")
	sky.transition_to("day", 2.0)
	sky.advance(2.0)
	check(sky.wet == 0.0 and not sky.rain.emitting, "dry transition")
	sky.queue_free()
	var models := Landmarks.new()
	add_child(models)
	for id in ["skanderbeg", "pyramid", "mother_teresa", "blloku_sign", "independence", "castle_berat", "mangalem", "gorica", "castle_gjirokaster", "stone_roofs", "rozafa", "painted_mosque"]:
		var model := Node3D.new()
		models.add_child(model)
		models.build(model, id)
		check(model.get_child_count() > 0, "landmark " + id)
	models.queue_free()
	await get_tree().process_frame
	print("READINESS: ", sim_count, " complete simulations; failures=", failures)
	get_tree().quit(1 if failures else 0)
