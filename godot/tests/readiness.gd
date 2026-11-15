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
		check(car.mat_paint != null or car.sport_paint != null, "paint material " + def.id)
		if car.mat_paint != null:
			var tint: Color = car.mat_paint.albedo_color
			check(tint.v > 0.25 and (paint.s < 0.15 or absf(tint.h - paint.h) < 0.03), "selected car paint " + def.id)
		elif car.sport_paint != null:
			var tint: Color = car.sport_paint.get_shader_parameter("paint_color")
			check(tint.is_equal_approx(paint), "selected sport car paint " + def.id)
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
			# At the road contact point, a forward-rolling tire's surface moves
			# backwards relative to the car. Check actual transformed geometry,
			# including the mirrored wheel instead of assuming Euler-angle signs.
			state.v = 12.0
			car.apply_state(state, visual_track, 0.0)
			var initial_bases := {}
			var contact_points := {}
			for name in ["wheel_rl", "wheel_rr"]:
				var wheel: MeshInstance3D = car.wheels[name]
				initial_bases[name] = wheel.transform.basis
				contact_points[name] = wheel.transform.basis.inverse() * Vector3.DOWN
			car.apply_state(state, visual_track, 0.01)
			for name in ["wheel_rl", "wheel_rr"]:
				var wheel: MeshInstance3D = car.wheels[name]
				var after_contact: Vector3 = wheel.transform.basis * contact_points[name]
				var before_contact: Vector3 = initial_bases[name] * contact_points[name]
				check(after_contact.z > before_contact.z, "rear tire rolls opposite forward motion " + name)
				initial_bases[name] = wheel.transform.basis
				contact_points[name] = wheel.transform.basis.inverse() * Vector3.DOWN
			state.v = -12.0
			car.apply_state(state, visual_track, 0.01)
			for name in ["wheel_rl", "wheel_rr"]:
				var wheel: MeshInstance3D = car.wheels[name]
				var after_contact: Vector3 = wheel.transform.basis * contact_points[name]
				var before_contact: Vector3 = initial_bases[name] * contact_points[name]
				check(after_contact.z < before_contact.z, "rear tire rolls opposite reverse motion " + name)
			# Reset for the existing exact elapsed-time checks.
			car.spin = 0.0
			state.v = 12.0
			state.steer = 0.4
			state.braking = true
			car.apply_state(state, visual_track, 0.01)
			var fl: MeshInstance3D = car.wheels.wheel_fl
			var fr: MeshInstance3D = car.wheels.wheel_fr
			var rl: MeshInstance3D = car.wheels.wheel_rl
			var rr: MeshInstance3D = car.wheels.wheel_rr
			check(fl.rotation.x > 0.1 and fr.rotation.x < -0.1, "front wheels spin " + def.id)
			check(rl.rotation.x > 0.1 and rr.rotation.x < -0.1, "rear wheels spin " + def.id)
			check(absf(fr.rotation.y) > 0.001 and absf(rr.rotation.y) < 0.001, "only front wheels steer " + def.id)
			check((car.mat_rear != null and car.mat_rear.emission_energy_multiplier > 1.0) or (car.sport_paint != null and float(car.sport_paint.get_shader_parameter("brake_light")) > 0.9), "brake lights respond " + def.id)
			check(absf(car.spin - state.v * 0.01 / (rl.mesh.get_aabb().size.y * 0.5)) < 0.001, "wheel rotation matches tire radius " + def.id)
			state.steer = 1.0
			state.v = 4.0
			car.apply_state(state, visual_track, 0.5)
			var low_speed_angle := absf(fr.rotation.y)
			state.v = 40.0
			car.apply_state(state, visual_track, 0.5)
			check(absf(fr.rotation.y) < low_speed_angle * 0.25, "front wheel angle follows speed-limited turning " + def.id)
			state.hop = 1.5
			car.apply_state(state, visual_track, 0.01)
			check(car.contact_shadow.transparency > 0.99, "contact shadow fades when airborne " + def.id)
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
	# A very tight inside bend must not accelerate progress toward 3x speed.
	var bend_track := RaceTrack.load_city("tirane")
	bend_track.K.fill(0.1)
	var bend_race := Race.new(bend_track, {"seed": 42})
	bend_race.started = true
	var bend_car := bend_race.player
	bend_car.progress = 100.0
	bend_car.s = bend_track.mod_s(100.0)
	bend_car.d = 8.0
	bend_car.yaw = 0.0
	bend_car.v = 30.0
	bend_car.ctrl.gas = false
	bend_race.physics(bend_car, 1.0 / 60.0)
	check(bend_car.progress - 100.0 <= 0.625, "inside bend keeps track progress bounded")
	var sim_count := 0
	for city in Data.CITIES:
		if not FileAccess.file_exists("res://assets/cities/%s/track.json" % city.id):
			print("UNAVAILABLE CITY: ", city.id)
			continue
		var track := RaceTrack.load_city(city.id)
		for difficulty in 3:
			var race := Race.new(track, {"laps": 1, "diff": difficulty, "seed": 42, "no_player": true})
			race.started = true
			var estimated := false
			for step in 36000:
				race.step(1.0 / 60.0)
				race.take_events()
				if not estimated and race.order[0].finished:
					# Results can appear while rivals are still racing. Their
					# projected times are absolute race times past the clock.
					estimated = true
					race.estimate()
					for c in race.cars:
						var ok := is_equal_approx(c.est, c.finish_time) if c.finished else (is_finite(c.est) and c.est > race.time)
						check(ok, "finishing estimate " + city.id + " difficulty " + str(difficulty))
				if race.all_finished():
					break
			check(estimated, "estimate exercised " + city.id + " difficulty " + str(difficulty))
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
	combat.player.yaw = 0.4
	effects._process(0.1)
	check(effects._skids.visible_instance_count == 0, "skid starts at wheel contacts")
	var first_left: Vector3 = effects._skid_previous[-1]
	var first_right: Vector3 = effects._skid_previous[1]
	check(first_left.distance_to(first_right) > 1.0, "skids start at separate tyres")
	combat.player.progress += 2.0
	combat.player.s = combat.track.mod_s(combat.player.progress)
	combat.player.d += 0.6
	effects._process(0.1)
	check(effects._skids.visible_instance_count == 2, "hard braking joins both tyre paths")
	check(first_left.distance_to(effects._skid_previous[-1]) > 1.0, "skid follows tyre movement through a turn")
	combat.player.progress += 100.0
	combat.player.s = combat.track.mod_s(combat.player.progress)
	effects._process(0.1)
	check(effects._skids.visible_instance_count == 2, "skids do not connect teleports")
	combat.player.braking = false
	effects._process(0.1)
	check(effects._skid_previous.is_empty(), "skid stops when braking ends")
	combat.player.braking = true
	effects._process(0.1)
	check(effects._skids.visible_instance_count == 2, "new braking does not bridge the gap")
	combat.player.braking = false
	# Real target-required items only spend ammunition in a valid encounter.
	for i in combat.cars.size():
		var rival: CarState = combat.cars[i]
		if rival == combat.player:
			continue
		rival.progress = combat.player.progress + 8.0 + i * 20.0
		rival.s = combat.track.mod_s(rival.progress)
		rival.d = combat.player.d
	combat.compute_order()
	for type in Data.PW_KEYS:
		effects.powerup_used(combat.player, type, false)
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
	var previous_input := Settings.input_config()
	Settings.auto_accel = false
	Settings.touch_steer = true
	Settings.left_handed = false
	var controls := RaceInput.new()
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.size = Vector2(1280, 720)
	var test_car := combat.player
	test_car.wreck_t = 0.0
	test_car.spin_t = 0.0
	test_car.slots = [{"type": "bolt", "ammo": 3}]
	controls.bind(test_car, combat)
	controls.set_driving_enabled(true)
	check(not controls.control_rect("gas").intersects(controls.control_rect("fire")), "gas and fire do not overlap")
	check(not controls.control_rect("brake").intersects(controls.control_rect("gas")), "manual pedals do not overlap")
	check(not controls.control_rect("brake").intersects(controls.control_rect("steer")), "brake and steering do not overlap")
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.position = controls.control_rect("gas").get_center()
	touch.pressed = true
	controls._gui_input(touch)
	check(controls.gas and not controls.brake, "manual accelerator pedal")
	touch = touch.duplicate()
	touch.index = 2
	touch.position = controls.control_rect("brake").get_center()
	controls._gui_input(touch)
	check(controls.gas and controls.brake, "manual simultaneous gas/brake")
	touch = touch.duplicate()
	touch.index = 3
	touch.position = controls.control_rect("fire").get_center()
	controls._gui_input(touch)
	check(controls.gas and controls.brake and controls.fire, "manual item action preserves held pedals")
	touch = touch.duplicate()
	touch.index = 5
	touch.position = controls.control_rect("steer").get_center()
	controls._gui_input(touch)
	check(controls._pad_steer == 0.0, "steering starts neutral under the thumb")
	var steering_drag := InputEventScreenDrag.new()
	steering_drag.index = 5
	steering_drag.position = touch.position + Vector2(90, 0)
	controls._gui_input(steering_drag)
	check(controls.gas and controls.brake and controls._pad_steer > 0.5, "relative steering preserves held pedals")
	touch = touch.duplicate()
	touch.index = 2
	touch.pressed = false
	controls._gui_input(touch)
	check(controls.gas and not controls.brake, "one release preserves other held pedal")
	controls.reset_controls()
	check(not controls.gas and not controls.brake, "focus/pause clears held touches")
	# Multiple render frames may pass without a simulation tick. Each one-shot
	# action must survive those frames and then be consumed exactly once.
	test_car.wreck_t = 0.0
	test_car.spin_t = 0.0
	test_car.slots = [{"type": "bolt", "ammo": 3}, {"type": "nitro", "ammo": 1}]
	controls.fire = true
	controls.apply(test_car)
	controls.apply(test_car)
	check(test_car.ctrl.fire, "forward fire persists until simulation tick")
	combat.step(1.0 / 60.0)
	check(not test_car.ctrl.fire and int(test_car.slots[0].ammo) == 2, "forward fire consumed once")
	controls.apply(test_car)
	combat.step(1.0 / 60.0)
	check(int(test_car.slots[0].ammo) == 2, "forward fire does not repeat")
	controls.back = true
	controls._cycle = true
	controls.apply(test_car)
	controls.apply(test_car)
	check(test_car.ctrl.back and test_car.ctrl.cycle, "back fire and cycle persist until simulation tick")
	combat.step(1.0 / 60.0)
	check(not test_car.ctrl.back and not test_car.ctrl.cycle, "back fire and cycle consumed")
	check(test_car.slots.size() == 1 and test_car.slots[0].type == "bolt", "cycle and back fire execute once in simulation order")
	touch = touch.duplicate()
	touch.index = 4
	touch.pressed = true
	touch.position = controls.size * 0.5
	controls._gui_input(touch)
	check(not controls.gas and not controls.brake, "clear road is not an invisible pedal")
	controls.queue_free()
	Settings.load_input_config(previous_input)
	Settings.changed.emit()
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
	sky.apply("rainy")
	check(sky.wet == 1.0 and sky.rain.emitting and sky.night < 0.3, "daytime rain preset is wet, raining and bright")
	check(sky.rain.get_child_count() == 2, "rain draws streaks and splashes")
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
