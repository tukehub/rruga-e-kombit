extends Node

const Governor = preload("res://scripts/game/performance_governor.gd")
const SettingsScript = preload("res://scripts/game/settings.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func frames(g, seconds: float, dt: float) -> void:
	for i in ceili(seconds / dt):
		g.observe(dt)

func _ready() -> void:
	var sound_before := Sfx.enabled
	Sfx.enabled = false
	var saved := {"quality": Settings.quality, "frame_target": Settings.frame_target, "adaptive_quality": Settings.adaptive_quality, "mirror": Settings.mirror}
	governor_checks()
	Settings.frame_target = 30
	Settings.adaptive_quality = false
	Settings.quality = "medium"
	Settings.save()
	var physics_hz := Engine.physics_ticks_per_second
	check(Engine.max_fps == 30 and Quality.frame_target == 30, "battery option caps rendering at30FPS")
	check(Engine.physics_ticks_per_second == physics_hz and physics_hz == 60, "render cap never changes the60Hz simulation")
	var loaded := SettingsScript.new()
	loaded.load_settings()
	check(loaded.frame_target == 30 and not loaded.adaptive_quality, "frame/adaptive preferences persist")
	loaded.free()
	var config := ConfigFile.new()
	config.load(Settings.PATH)
	config.set_value("video", "frame_target", 144)
	config.save(Settings.PATH)
	loaded = SettingsScript.new()
	loaded.load_settings()
	check(loaded.frame_target == 60, "unsupported saved frame targets fall back to60")
	loaded.free()
	Settings.frame_target = 60
	Settings.mirror = false
	Settings.save()
	Quality.configure_from_settings()
	var immutable := JSON.stringify(Quality.PRESETS)
	Game.race_opts.city = "tirane"
	Game.race_opts.env = "rain"
	Game.race_opts.laps = 1
	var scene := RaceScene.new()
	add_child(scene)
	scene.set_process(false)
	scene.state = "race"
	scene.race.started = true
	var race := scene.race
	var c := race.player
	c.progress = 500.0
	c.s = race.track.mod_s(c.progress)
	c.v = 30.0
	c.shield_t = 8.0
	c.nitro_t = 2.6
	scene.sky.apply("rain")
	scene._update_weather(0.0)
	for visual in scene.cars:
		visual.set_night(1.0)
	scene.cam.intro = false
	scene.cam._snap = true
	for i in 120:
		scene.cam.follow(c, 1.0 / 60.0)
	scene.views._toggle_mirror()
	populate(race)
	var fx := scene.effects
	var before := object_ids(fx)
	var resources := resource_ids(fx)
	fx._process(0.0)
	check(fx._nodes.size() == 99 and int(fx.snapshot().allocated_units) == 131, "legal maximum inventory burst and driving emitters fit prewarmed hard pools")
	for i in 100:
		fx.powerup_used(c, Data.PW_KEYS[i % Data.PW_KEYS.size()], false)
		fx.boom(race.track.pos(c.s, c.d), Color.ORANGE)
	fx._process(0.0)
	for preset in ["low", "medium", "high"]:
		Quality.set_preset(preset)
		for stage in 4:
			Quality.set_pressure_stage(stage)
			fx._t = 0.0
			fx._process(0.0)
			scene.props.update_lights(race.track.pos(c.s, c.d), race.track.tangent(c.s))
			check(fx._nodes.size() == 99, "adaptive budgets preserve every legal core combat object")
			check(visible_lights(fx) <= int(Quality.p.fx_light_limit), "combined projectile/flash lights respect one shared budget")
			check(fx._flashes.size() <= int(Quality.p.fx_flash_limit), "active flashes follow budget")
			check(scene.sky.rain._streak_mat.get_shader_parameter("density") == Quality.p.rain_density, "rain changes density without rebuilding meshes")
			check(scene.views.viewport.size.x == int(Quality.p.mirror_width) and scene.views.enabled and Settings.mirror, "mirror budget keeps the saved on preference")
			var scale := get_viewport().scaling_3d_scale
			check(scale >= 0.6 - 0.00001 and scale <= float(Quality.PRESETS[preset].scale) + 0.00001, "dynamic3D scale is bounded by preset and readability floor")
			check(scene.cars[race.cars.find(c)].head_l.visible and scene.cars[race.cars.find(c)].contact_shadow.visible, "functional headlights and contact survive pressure")
			for dome: Dictionary in race.domes:
				var node: Node3D = fx._nodes[dome.id]
				check(node.visible and node.get_node("ring").visible, "warning domes remain visible at every budget")
			check(object_ids(fx) == before and resource_ids(fx) == resources, "combined rain/combat/lights/mirror pressure allocates no new effect nodes/meshes/materials")
	Settings.adaptive_quality = true
	Settings.save()
	Quality.governor.reset(60, false, 0.0)
	for i in 125:
		Quality.observe_frame(0.04)
	check(Quality.pressure_stage == 1 and scene.views.viewport.size.x == 192, "measured sustained load reaches scene consumers through budget signals")
	check(is_equal_approx(get_viewport().scaling_3d_scale, float(Quality.p.scale)) and is_equal_approx(scene.sky.rain._streak_mat.get_shader_parameter("density"), 0.85), "automatic adjustment changes3D rendering and rain together")
	check(Settings.quality == "medium" and Settings.mirror and JSON.stringify(Quality.PRESETS) == immutable, "automatic adjustment preserves player preferences and preset definitions")
	Settings.adaptive_quality = false
	Settings.save()
	# Exhaustion is an explicit priority decision, never a constructor fallback.
	for i in 80:
		race.projs.append({"id": 2000 + i, "kind": "eagle", "s": race.track.mod_s(c.s + 180 + i), "d": 0.0, "dir": 1.0, "speed": 70.0, "target": null, "owner": race.cars[0], "life": 7.0, "born": race.time})
	race.projs.append({"id": 9999, "kind": "eagle", "s": race.track.mod_s(c.s - 20), "d": 1.0, "dir": 1.0, "speed": 70.0, "target": c, "owner": race.cars[0], "life": 7.0, "born": race.time})
	fx._process(0.0)
	check(fx._nodes.has(9999) and fx._nodes.size() == 99 and fx.snapshot().saturated_frames > 0, "oversized streams retain player homing threat within fixed caps")
	check(object_ids(fx) == before and resource_ids(fx) == resources, "pool exhaustion cannot create visuals")
	for dome: Dictionary in race.domes:
		dome.r = 2.0 + float(dome.id % 5)
	fx._process(0.0)
	check(resource_ids(fx) == resources, "different dome radii scale shared geometry")
	race.projs.clear()
	race.mines.clear()
	race.domes.clear()
	fx._process(1.0)
	check(fx._nodes.is_empty() and fx._flashes.is_empty(), "expired effects return to pools")
	fx.setup(race, race.track)
	check(object_ids(fx) == before and resource_ids(fx) == resources, "rebinding a race reuses prebuilt pools")
	check(JSON.stringify(Quality.PRESETS) == immutable, "runtime adaptation never mutates preset definitions")
	print("VISUAL PERFORMANCE POOL: ", JSON.stringify(fx.snapshot()))
	scene.queue_free()
	await get_tree().process_frame
	var menu := Menu.new()
	add_child(menu)
	menu.show_page("settings")
	(menu._set_rows.frame_target.get_child(1) as Button).pressed.emit()
	check(Settings.frame_target == 30 and Engine.max_fps == 30, "menu battery choice reaches the render cap")
	(menu._set_rows.adaptive_quality.get_child(1) as Button).pressed.emit()
	check(Settings.adaptive_quality and Quality.adaptive_enabled, "menu exposes ongoing load adaptation")
	(menu._set_rows.frame_target.get_child(0) as Button).pressed.emit()
	check(Engine.max_fps == 60, "menu can restore60FPS immediately")
	menu.queue_free()
	await get_tree().process_frame
	for key in saved:
		Settings.set(key, saved[key])
	Settings.save()
	Sfx.stop_all()
	Sfx.enabled = sound_before
	print("VISUAL PERFORMANCE: governor,30/60FPS persistence and combined bounded workload; failures=", failures)
	get_tree().quit(1 if failures else 0)

func governor_checks() -> void:
	var g := Governor.new()
	g.reset(60)
	frames(g, 20, 1.0 / 60.0)
	check(g.stage == 0, "steady target frame cadence doesn't degrade quality")
	g.observe(0.8)
	frames(g, 3, 1.0 / 60.0)
	check(g.stage == 0, "isolated loading hitch doesn't degrade quality")
	frames(g, 5, 0.04)
	check(g.stage == 1, "sustained overload steps down after repeated windows")
	var old := g.stage
	frames(g, 3, 0.04)
	check(g.stage == old, "cooldown prevents fast quality oscillation")
	frames(g, 30, 0.04)
	check(g.stage == 3, "sustained load reaches a bounded floor")
	g.reset(60, true, 0)
	frames(g, 14, 1.0 / 60.0)
	check(g.stage == 2, "slow recovery restores only one quality step")
	g.reset(60, true, 2)
	for i in 100:
		g.observe(0.1, false)
	check(g.stage == 2 and g.warmup == 2.0, "paused time doesn't change quality or consume resume grace")
	g.reset(30)
	frames(g, 30, 1.0 / 30.0)
	check(g.stage == 0, "normal30FPS is measured against its own frame budget")
	g.reset(60)
	for i in 600:
		g.observe(1.0 / 60.0 if i % 2 == 0 else 1.0 / 30.0)
	check(g.stage > 0, "persistent alternating missed refreshes also trigger adaptation")
	g.reset(60)
	for i in 100:
		g.observe(0.5)
	check(g.stage > 0, "repeated very long frames cannot be mistaken for isolated hitches")
	var safe := g.stage
	g.observe(NAN)
	g.observe(-1.0)
	check(g.stage == safe, "invalid measurements are ignored")

func populate(race: Race) -> void:
	var c := race.player
	var id := 1
	for kind in ["bolt", "eagle"]:
		for i in int(FxVisual.POOL_CAPS[kind]):
			race.projs.append({"id": id, "kind": kind, "s": race.track.mod_s(c.s + (i % 12) * 5 - 15), "d": float(i % 3 - 1) * 3.0, "dir": 1.0, "speed": 75.0, "target": c if kind == "eagle" and i == 0 else null, "owner": race.cars[0], "life": 7.0, "born": race.time})
			id += 1
	for i in 24:
		race.mines.append({"id": id, "s": race.track.mod_s(c.s + i * 3), "d": 2.0, "fly": 0.0, "fly0": 0.0, "arm": 0.0, "life": 45.0, "born": 0.0, "owner": race.cars[0]})
		id += 1
	for i in 3:
		race.domes.append({"id": id, "s": race.track.mod_s(c.s + 35 + i * 20), "d": float(i - 1) * 5.0, "r": 4.8, "warn": 1.0, "life": 9.0, "hit_set": {}, "owner": race.cars[0]})
		id += 1

func object_ids(root: Node) -> Dictionary:
	var result := {root.get_instance_id(): true}
	for child in root.get_children():
		result.merge(object_ids(child))
	return result

func resource_ids(root: Node) -> Dictionary:
	var result := {}
	if root is MeshInstance3D:
		if root.mesh != null: result[root.mesh.get_instance_id()] = true
		if root.material_override != null: result[root.material_override.get_instance_id()] = true
	elif root is CPUParticles3D:
		if root.mesh != null: result[root.mesh.get_instance_id()] = true
	elif root is GPUParticles3D:
		if root.draw_pass_1 != null:
			result[root.draw_pass_1.get_instance_id()] = true
			result[root.draw_pass_1.material.get_instance_id()] = true
		if root.process_material != null: result[root.process_material.get_instance_id()] = true
	for child in root.get_children():
		result.merge(resource_ids(child))
	return result

func visible_lights(root: Node) -> int:
	var count := 1 if root is Light3D and root.is_visible_in_tree() else 0
	for child in root.get_children():
		count += visible_lights(child)
	return count
