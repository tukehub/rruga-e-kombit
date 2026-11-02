extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	Quality.set_preset("medium")
	Settings.dynamic_weather = true
	var visual_track := RaceTrack.load_city("tirane")
	for def in Data.CARS:
		var car := CarVisual.new()
		add_child(car)
		var paint := Color.html(def.color)
		car.setup(def, paint, true)
		check(car.body != null and car.wheels.size() == 4, "car meshes " + def.id)
		check(car.mat_paint != null and car.mat_paint.albedo_color.is_equal_approx(paint), "selected car paint " + def.id)
		for wheel_name in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
			check(car.wheels.has(wheel_name), "named wheel " + def.id + " " + wheel_name)
			if not car.wheels.has(wheel_name):
				continue
			var wheel: MeshInstance3D = car.wheels[wheel_name]
			var expected_left: bool = wheel_name.ends_with("l")
			var expected_front: bool = wheel_name.begins_with("wheel_f")
			check((wheel.position.x < -0.1 if expected_left else wheel.position.x > 0.1), "wheel left/right position " + wheel_name)
			check((wheel.position.z < -0.1 if expected_front else wheel.position.z > 0.1), "wheel front/rear position " + wheel_name)
			check(wheel.position.y > 0.1 and wheel.position.y < def.size.y, "wheel height " + wheel_name)
		if car.wheels.size() == 4:
			var state := CarState.new(0, def, "test", true, paint)
			state.v = 12.0
			state.steer = 0.4
			state.braking = true
			car.apply_state(state, visual_track, 0.01)
			var fl: MeshInstance3D = car.wheels.wheel_fl
			var fr: MeshInstance3D = car.wheels.wheel_fr
			var rl: MeshInstance3D = car.wheels.wheel_rl
			var rr: MeshInstance3D = car.wheels.wheel_rr
			check(fl.rotation.x < -0.1 and fr.rotation.x > 0.1, "front wheels spin " + def.id)
			check(rl.rotation.x < -0.1 and rr.rotation.x > 0.1, "rear wheels spin " + def.id)
			check(absf(fr.rotation.y) > 0.001 and absf(rr.rotation.y) < 0.001, "only front wheels steer " + def.id)
			check(car.mat_rear != null and car.mat_rear.emission_energy_multiplier > 1.0, "brake lights respond " + def.id)
		var triangles := 0
		for mi in car.model.get_children():
			if mi is MeshInstance3D:
				for i in mi.mesh.get_surface_count():
					triangles += mi.mesh.surface_get_array_index_len(i) / 3
		check(triangles >= 3000 and triangles <= 60000, "car triangle budget " + def.id)
		car.queue_free()
	# Render interpolation must advance smoothly even when a frame contains no
	# simulation step, cross the start line correctly, and snap on respawn.
	var render_pose = load("res://scripts/game/render_pose.gd")
	var sample_car := CarState.new(0, Data.CARS[0], "test", true, Color.WHITE)
	sample_car.progress = 99.0
	sample_car.s = 99.0
	var previous: Dictionary = render_pose.capture(sample_car)
	sample_car.progress = 101.0
	sample_car.s = 1.0
	check(is_equal_approx(float(render_pose.sample(previous, sample_car, 0.25, 100.0).s), 99.5), "render interpolation before lap wrap")
	check(is_equal_approx(float(render_pose.sample(previous, sample_car, 0.75, 100.0).s), 0.5), "render interpolation after lap wrap")
	sample_car.progress = 120.0
	sample_car.s = 20.0
	check(is_equal_approx(float(render_pose.sample(previous, sample_car, 0.0, 100.0).s), 20.0), "render interpolation snaps teleport")
	previous.wreck_t = 0.01
	sample_car.progress = 100.0
	sample_car.s = 0.0
	check(is_equal_approx(float(render_pose.sample(previous, sample_car, 0.0, 100.0).s), 0.0), "render interpolation snaps respawn")
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
	combat.player.v = 20.0
	combat.player.braking = true
	effects._process(0.1)
	check(effects._skids.visible_instance_count == 2, "hard braking leaves two tire marks")
	combat.player.braking = false
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
	controls.size = Vector2(1280, 720)
	check(controls.control_rect("gas").size.x > 96.0 and controls.control_rect("gas").size.y > 112.0, "larger pedals")
	check(not controls.control_rect("gas").intersects(controls.control_rect("fire")), "gas and fire do not overlap")
	check(not controls.control_rect("brake").intersects(controls.control_rect("back")), "brake and rear fire do not overlap")
	check(not controls.control_rect("brake").intersects(controls.control_rect("steer")), "brake and steering do not overlap")
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = controls.control_rect("gas").get_center()
	touch.pressed = true
	controls._gui_input(touch)
	check(controls.gas and not controls.brake, "accelerator pedal")
	touch = touch.duplicate()
	touch.index = 2
	touch.position = controls.control_rect("brake").get_center()
	controls._gui_input(touch)
	check(controls.gas and controls.brake, "simultaneous gas/brake")
	touch = touch.duplicate()
	touch.index = 3
	touch.position = controls.control_rect("fire").get_center()
	controls._gui_input(touch)
	check(controls.gas and controls.brake and controls.fire, "fire while both pedals held")
	touch = touch.duplicate()
	touch.index = 2
	touch.pressed = false
	controls._gui_input(touch)
	check(controls.gas and not controls.brake, "one release preserves other held pedal")
	controls.reset_controls()
	check(not controls.gas and not controls.brake, "focus/pause clears held touches")
	touch = touch.duplicate()
	touch.index = 4
	touch.pressed = true
	touch.position = controls.size * 0.5
	controls._gui_input(touch)
	check(not controls.gas and not controls.brake, "clear road is not an invisible pedal")
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
