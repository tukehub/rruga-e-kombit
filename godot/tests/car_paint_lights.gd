extends Node3D

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	var visuals: Array[CarVisual] = []
	for i in 6:
		var car := CarVisual.new()
		add_child(car)
		car.setup(Data.CARS[i], Color.html(Data.CARS[i].color), i == 0)
		car.position = Vector3(0.0, 0.0, float(i) * 10.0)
		visuals.append(car)
	var ids: Array[int] = []
	for car in visuals:
		ids.append(car.head_l.get_instance_id())
		ids.append(car.head_r.get_instance_id())
		check(car.mat_front != null and car.mat_front.emission_enabled, "every car has emissive lamps")
		if car.mat_paint != null:
			check(is_equal_approx(car.mat_paint.metallic, 0.6) and is_equal_approx(car.mat_paint.roughness, 0.25), "public paint uses the metallic base coat")
			check(car.mat_paint.clearcoat_enabled and car.mat_paint.clearcoat > 0.5 and car.mat_paint.normal_texture != null, "public paint includes clearcoat and flakes")
	for preset in ["low", "medium", "high"]:
		Quality.set_preset(preset)
		for stage in 4:
			Quality.set_pressure_stage(stage)
			for night in [0.0, 1.0]:
				for car in visuals:
					car.set_night(night)
				CarVisual.update_headlight_budget(visuals, Vector3.ZERO)
				var bots := 0
				for i in visuals.size():
					var car := visuals[i]
					check(car.head_l.get_instance_id() == ids[i * 2] and car.head_r.get_instance_id() == ids[i * 2 + 1], "quality changes reuse the same headlights")
					check(car.mat_front.emission_energy_multiplier > 0.0, "emissive lamps survive every budget")
					if car.mat_paint != null:
						check(car.mat_paint.normal_enabled == bool(Quality.p.paint_flakes), "flakes follow effective quality")
					if i > 0:
						bots += 2 if car.head_l.visible else 0
				check(bots <= int(Quality.p.fx_light_limit) and bots + 2 <= Quality.SPOT_LIGHTS_PER_MESH, "all bot beams fit the spot budget")
				check(visuals[0].head_l.visible == (night > 0.3), "player beams survive pressure and stop in daylight")
				check(night > 0.3 or bots == 0, "daylight disables bot road beams")
	Quality.set_preset("medium")
	CarVisual.update_headlight_budget(visuals, Vector3.ZERO)
	check(visuals[1].head_l.visible and not visuals[2].head_l.visible, "nearest rival gets medium's beam pair")
	CarVisual.update_headlight_budget(visuals, Vector3(0, 0, 50))
	check(visuals[5].head_l.visible and not visuals[1].head_l.visible, "moving focus reassigns the same lights")
	CarVisual.update_headlight_budget(visuals, Vector3(1000, 0, 0))
	for i in range(1, visuals.size()):
		check(not visuals[i].head_l.visible, "distant rivals never spend spot slots")
	var state := CarState.new(0, Data.CARS[0], "test", true, Color.WHITE)
	state.health = state.max_hp * 0.25
	visuals[0]._apply_damage(state)
	if visuals[0].mat_paint != null:
		check(visuals[0].mat_paint.roughness > 0.6 and visuals[0].mat_paint.clearcoat < 0.4, "damage dulls the glossy paint")
	state.health = state.max_hp
	visuals[0]._apply_damage(state)
	if visuals[0].mat_paint != null:
		check(is_equal_approx(visuals[0].mat_paint.roughness, 0.25) and is_equal_approx(visuals[0].mat_paint.clearcoat, 0.65), "repair restores the original finish")
	for car in visuals:
		car.queue_free()
	await get_tree().process_frame
	print("CAR PAINT / LIGHTS: renderer=%s; failures=%d" % [Quality.renderer, failures])
	get_tree().quit(1 if failures else 0)
