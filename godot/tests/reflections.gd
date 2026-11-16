extends Node3D

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	Sfx.enabled = false
	Quality.set_preset("high")
	Game.race_opts.city = "tirane"
	Game.race_opts.env = "day"
	var scene := RaceScene.new()
	add_child(scene)
	scene.set_process(false)
	var reflections := scene.reflections
	var target := scene.track.pos(scene.player.s, scene.player.d)
	reflections.follow(target, 0.0)
	check(reflections.landmarks.size() == 3, "three mapped Tirana landmarks have street-side captures")
	var ids: Array[int] = [reflections.player_probe.get_instance_id()]
	for probe in reflections.landmarks:
		ids.append(probe.get_instance_id())
		check(probe.update_mode == ReflectionProbe.UPDATE_ONCE and not probe.enable_shadows, "landmarks use static shadow-free captures")
	check(reflections.player_probe.cull_mask == reflections.SCENERY_MASK, "capture mask includes static scenery only")
	check(has_scenery(scene.road) and has_scenery(scene.buildings) and has_scenery(scene.props), "road, buildings and landmarks populate the capture layer")
	for car in scene.cars:
		check(not has_scenery(car), "cars cannot reflect themselves or become ghosts in static probes")
	check(not has_scenery(scene.effects) and not has_scenery(scene.pickups) and not has_scenery(scene.sky), "particles, pickups and weather are excluded")
	for preset in ["low", "medium", "high"]:
		Quality.set_preset(preset)
		for stage in 4:
			Quality.set_pressure_stage(stage)
			reflections.follow(target, 2.0)
			check(reflections.player_probe.visible == bool(Quality.p.probe), "player probe follows effective budget")
			var active := int(reflections.player_probe.visible)
			for i in reflections.landmarks.size():
				check(reflections.landmarks[i].visible == (i < int(Quality.p.landmark_probes)), "landmark probes follow effective budget")
				active += int(reflections.landmarks[i].visible)
				check(reflections.landmarks[i].get_instance_id() == ids[i + 1], "quality changes reuse landmarks")
			check(active <= 4 and active <= 8, "even one large road mesh stays within the Mobile probe limit")
			check(reflections.player_probe.get_instance_id() == ids[0], "following probe is reused")
	Quality.set_preset("medium")
	reflections.follow(target, 1.0)
	var before := reflections.captures
	var origin := reflections.player_probe.position
	for i in 60:
		reflections.follow(target + Vector3(5, 0, 0), 1.0 / 60.0)
	check(reflections.captures == before and reflections.player_probe.position == origin, "small motion does not cause six new capture faces every frame")
	reflections.follow(target + Vector3(30, 0, 0), 0.0)
	check(reflections.captures == before + 1, "movement beyond the threshold refreshes after the interval")
	before = reflections.captures
	reflections.follow(target + Vector3(300, 0, 0), 0.0)
	check(reflections.captures == before + 1, "teleport immediately moves the probe to the player")
	Quality.set_preset("high")
	reflections.follow(target, 1.0)
	for i in 4:
		reflections.follow(target, 1.0)
	check(not reflections._dirty.has(true), "landmark refresh queue drains")
	scene.sky.apply("night")
	check(reflections._player_dirty and not reflections._dirty.has(false), "weather invalidates captures even with a stationary player")
	before = reflections.captures
	reflections.follow(target, 1.0)
	check(reflections.captures == before + 2, "weather refreshes the player and at most one static probe per interval")
	scene.sky.transition_to("day", 4.0)
	for i in 4:
		reflections.follow(target, 1.0)
	scene.sky.advance(1.1)
	check(reflections._player_dirty, "mid-transition lighting refreshes reflections")
	scene.sky.advance(4.0)
	check(is_equal_approx(scene.sky.env.ambient_light_energy, 0.325), "daylight uses reduced ambient fill")
	scene.sky.apply("night")
	check(scene.sky.env.ambient_light_energy >= 0.38 - 0.00001, "night retains a readable ambient floor")
	scene.restart()
	check(scene.reflections == reflections and not reflections._placed, "retry reuses world probes and resets the follow anchor")
	scene.queue_free()
	await get_tree().process_frame
	var menu := Menu.new()
	add_child(menu)
	check(menu.garage_env.background_mode == Environment.BG_SKY and menu.garage_env.sky.sky_material is PanoramaSkyMaterial, "garage uses the licensed HDRI")
	check((menu.garage_floor.material_override as StandardMaterial3D).roughness < 0.2, "garage floor has a glossy finish")
	check(has_scenery(menu.garage_floor) and not has_scenery(menu.garage_car), "garage captures the floor without self-reflecting the rotating car")
	for preset in ["low", "medium", "high"]:
		Quality.set_preset(preset)
		check(menu.garage_probe.visible == bool(Quality.p.probe), "garage responds to live quality changes")
		check(menu.garage_env.ssao_enabled == bool(Quality.p.ssao), "garage environment responds to the renderer budget")
	Quality.set_pressure_stage(2)
	check(not menu.garage_probe.visible, "pressure disables garage probe too")
	menu.queue_free()
	await get_tree().process_frame
	Sfx.stop_all()
	print("REFLECTIONS: renderer=%s; budgets, masks, movement, weather, retry and garage; failures=%d" % [Quality.renderer, failures])
	get_tree().quit(1 if failures else 0)

func has_scenery(root: Node) -> bool:
	if root is GeometryInstance3D and root.layers & (1 << 19):
		return true
	for child in root.get_children():
		if has_scenery(child):
			return true
	return false
