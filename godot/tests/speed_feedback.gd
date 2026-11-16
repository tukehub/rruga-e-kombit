extends Node3D

const SpeedFeedback = preload("res://scripts/game/speed_feedback.gd")
var failures := 0
var visuals: Array[CarVisual] = []
var race: Race
var fx: FxVisual
var post: SpeedFeedback

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	Quality.set_preset("high")
	var track := RaceTrack.load_city("tirane")
	race = Race.new(track, {"seed": 31, "laps": 1, "diff": 1})
	race.started = true
	for c in race.cars:
		var visual := CarVisual.new()
		add_child(visual)
		visual.setup(c.def, c.color, c.is_player)
		visual.apply_state(c, track, 0.0)
		visuals.append(visual)
		c.v = 35.0
		c.drift = 0.8
		c.nitro_t = 1.0
		c.scrape = 0.8
	fx = FxVisual.new()
	add_child(fx)
	fx.setup(race, track, visuals[race.cars.find(race.player)], visuals)
	fx.set_process(false)
	post = SpeedFeedback.new()
	add_child(post)
	var objects := identities(fx)
	var state_before := state_snapshot()
	fx._process(0.0)
	var counts := fx.driving.snapshot()
	check(counts.smoke == 6 and counts.exhaust == 3 and counts.scrape == 3 and counts.spray == 0, "high shares six rear-wheel smoke emitters and three boost/scrape emitters")
	var player_key := "%d:" % race.player.id
	for kind in ["smoke", "exhaust", "scrape"]:
		var found := false
		for slot: Dictionary in fx.driving.pools[kind]:
			found = found or (str(slot.key).begins_with(player_key) and slot.claimed)
		check(found, "player is prioritized in " + kind)
	race.wet = true
	fx._process(1.0)
	counts = fx.driving.snapshot()
	check(counts.smoke == 0 and counts.spray == 6, "wet road substitutes spray for dry tyre smoke")
	for slot: Dictionary in fx.driving.pools.spray:
		check(not (slot.node as GPUParticles3D).local_coords, "wheel spray trails in world space")
	# Stop emission on invalid states, and let existing particles finish once.
	for c in race.cars:
		c.hop = 1.0
		c.nitro_t = 0.0
	fx._process(1.0)
	check(all_stopped(), "airborne wheels emit neither spray nor wall sparks")
	for c in race.cars:
		c.hop = 0.0
		c.v = 0.0
	fx._process(1.0)
	check(all_stopped(), "stationary cars emit no wheel effects")
	for c in race.cars:
		c.v = 35.0
		c.nitro_t = 2.0
		c.wreck_t = 1.0
	fx._process(1.0)
	check(all_stopped(), "wrecked cars stop every driving emitter")
	for c in race.cars:
		c.wreck_t = 0.0
	for preset in ["low", "medium", "high"]:
		Quality.set_preset(preset)
		for stage in 4:
			Quality.set_pressure_stage(stage)
			fx._process(0.0)
			counts = fx.driving.snapshot()
			check(counts.spray <= int(Quality.p.driving_cars) * 2 and counts.exhaust <= int(Quality.p.driving_cars), "pressure obeys the effective particle budget")
			if int(Quality.p.driving_cars) == 0:
				check(all_stopped(), "disabled budgets hide existing tails immediately")
			check(identities(fx) == objects, "quality/pressure changes allocate no particle nodes, meshes or materials")
	Quality.set_preset("high")
	for visual in visuals:
		visual.position += Vector3(1000, 0, 0)
	fx._process(1.0)
	check(all_stopped(), "distant cars do not emit")
	for i in visuals.size():
		visuals[i].apply_state(race.cars[i], track, 0.0)
	fx._process(0.0)
	check(fx.driving.snapshot().spray == 6, "teleporting back reuses the pool")
	fx.setup(race, track, visuals[race.cars.find(race.player)], visuals)
	check(all_stopped() and identities(fx) == objects, "rebinding clears trails without rebuilding pools")
	fx._process(0.0)
	race.player.finished = true
	fx._process(0.0)
	check(all_stopped(), "finish clears driving effects")
	race.player.finished = false
	# Restore the explicit test inputs before checking visual-only behavior.
	race.wet = false
	for c in race.cars:
		c.nitro_t = 1.0
	check(state_snapshot() == state_before, "render effects do not change simulation state or RNG")
	post_checks()
	fx.queue_free()
	post.queue_free()
	for visual in visuals:
		visual.queue_free()
	await get_tree().process_frame
	# Verify the production lifecycle owns the effect, including pause/retry.
	Sfx.enabled = false
	Game.race_opts.city = "tirane"
	Game.race_opts.env = "day"
	var scene := RaceScene.new()
	add_child(scene)
	scene.set_process(false)
	scene.state = "race"
	scene.player.v = scene.player.def.vmax
	scene.speed_feedback.update(scene.player, true, 1.0)
	check(scene.speed_feedback.overlay.visible and scene.speed_feedback.layer < scene._ui_layer.layer, "production HUD and mirror draw above the speed pass")
	scene.toggle_pause()
	check(not scene.speed_feedback.overlay.visible, "pause removes the speed pass")
	scene.toggle_pause()
	var old_post := scene.speed_feedback
	scene.restart()
	check(scene.speed_feedback != old_post and not scene.speed_feedback.overlay.visible, "retry starts with a fresh inactive pass")
	scene.queue_free()
	await get_tree().process_frame
	Sfx.stop_all()
	print("SPEED FEEDBACK: renderer=%s; fixed GPU pools, conditions, quality and lifecycle; failures=%d" % [Quality.renderer, failures])
	get_tree().quit(1 if failures else 0)

func all_stopped() -> bool:
	for kind in fx.driving.pools:
		for slot: Dictionary in fx.driving.pools[kind]:
			var emitter: GPUParticles3D = slot.node
			if emitter.emitting or emitter.visible:
				return false
	return true

func identities(root: Node) -> Dictionary:
	var ids := {root.get_instance_id(): true}
	if root is GPUParticles3D:
		ids[root.process_material.get_instance_id()] = true
		ids[root.draw_pass_1.get_instance_id()] = true
		ids[root.draw_pass_1.material.get_instance_id()] = true
	for child in root.get_children():
		ids.merge(identities(child))
	return ids

func state_snapshot() -> Array:
	var result := [race.rng.state, race.events.duplicate(true)]
	for c in race.cars:
		result.append([c.s, c.d, c.v, c.health, c.drift, c.nitro_t, c.scrape])
	return result

func post_checks() -> void:
	var c := race.player
	c.v = 0.0
	c.nitro_t = 0.0
	post.update(c, true, 1.0)
	check(not post.overlay.visible and post.strength == 0.0, "stationary view is clean")
	c.v = c.def.vmax
	post.update(c, true, 1.0)
	var fast := post.strength
	check(fast > 0.5 and fast < 0.8 and post.overlay.visible, "speed ratio drives restrained blur")
	c.nitro_t = 2.0
	post.update(c, true, 1.0)
	check(post.strength > fast and post.strength <= 1.0, "nitro adds bounded feedback")
	Quality.set_preset("low")
	check(not post.overlay.visible and post.strength == 0.0, "low immediately disables the screen-texture pass")
	Quality.set_preset("high")
	post.update(c, true, 1.0)
	Quality.set_pressure_stage(2)
	check(not post.overlay.visible, "sustained pressure disables blur")
	Quality.set_pressure_stage(0)
	c.wreck_t = 1.0
	post.update(c, true, 1.0)
	check(not post.overlay.visible, "wreck clears speed feedback")
	c.wreck_t = 0.0
	post.update(c, false, 1.0)
	check(not post.overlay.visible, "intro/pause/finish clear feedback")
	check(post.overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "speed pass never intercepts touch")
