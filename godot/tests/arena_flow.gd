extends Node
## Points mode in the real game: chosen on the title page, played in its own
## scene with the shared touch controls, ended by the clock, shown in results.

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func wait_scene(want: String) -> bool:
	for i in 600:
		await get_tree().process_frame
		if Game.current == want and not Game._loading:
			return true
	check(false, "scene " + want)
	return false

func button(root: Node, label: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n.text == label:
			return n
	return null

func _ready() -> void:
	Quality.set_preset("low")
	var sound := Sfx.enabled
	Sfx.enabled = false
	var saved_opts := Game.race_opts.duplicate()
	var saved_input := Settings.input_config()
	Settings.load_input_config({"touch_steer": true, "auto_accel": true, "left_handed": false, "control_size": 1, "control_offset_x": 0.0, "control_offset_y": 0.0})
	Game.race_opts.mode = "race"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	var menu: Menu = Game._root.get_child(0)

	# The mode is on the title page, in plain sight.
	var mode: Button = menu._mode
	check(mode != null and mode.is_visible_in_tree() and mode.text == "Mënyra: Garë" and not mode.disabled, "the title page shows the mode, a race by default")
	mode.pressed.emit()
	check(str(Game.race_opts.mode) == "points" and int(Game.race_opts.points_minutes) == 2 and mode.text == "Mënyra: Pikë · 2 min", "one tap chooses points for two minutes")
	check(menu._direction.disabled and menu._weather.disabled and menu._lap_plus.disabled and menu._lap_minus.disabled, "race-only choices are switched off for points")
	mode.pressed.emit()
	check(int(Game.race_opts.points_minutes) == 3 and mode.text == "Mënyra: Pikë · 3 min", "another tap makes it three minutes")
	mode.pressed.emit()
	check(str(Game.race_opts.mode) == "race" and not menu._direction.disabled and not menu._weather.disabled, "a third tap returns to the race and its choices")
	mode.pressed.emit()
	button(menu, "Nisu!").pressed.emit()
	await wait_scene("arena")
	var scene: ArenaScene = Game._root.get_child(0)
	scene.set_process(false)

	# The scene: the square, six cars, the shared controls, the points HUD.
	check(scene.arena != null and is_equal_approx(scene.arena.time_limit, 120.0) and scene.arena.cars.size() == 6, "a two-minute round with six cars")
	check(scene.cars.size() == 6 and scene.pads.size() == Arena.PADS.size(), "every car and every pickup pad is drawn")
	check(scene.state == "countdown" and not scene.arena.started, "the round waits for the countdown")
	var visual: CarVisual = scene.cars[scene.arena.cars.find(scene.player)]
	check(visual.global_position.distance_to(Vector3(scene.player.x, 0.0, scene.player.z)) < 0.01, "the player's car is drawn where the simulation has it")
	var ahead := Vector3(-sin(scene.player.h), 0.0, cos(scene.player.h))
	check((-visual.global_transform.basis.z).dot(ahead) > 0.99, "the car model points the way the car drives")
	check((scene.player.x * ahead.x + scene.player.z * ahead.z) < 0.0, "which is toward the middle of the square")
	var to_car := Vector3(scene.player.x, 0.0, scene.player.z) - scene.cam.global_position
	check(to_car.dot(ahead) > 5.0 and scene.cam.global_position.y > 2.0 and (-scene.cam.global_transform.basis.z).dot(ahead) > 0.9, "the camera sits behind and above the car, looking ahead")
	check(not scene.input._boost_btn.visible and scene.input._steer_btn.visible and scene.input._brake_btn.visible, "the driving controls are the race's, without the drift boost")
	check(scene.hud._clock.text == "2:00" and scene.hud._score.text == "0" and scene.hud._board_rows.size() == 6, "the HUD shows the clock, the score and the scoreboard")
	check(ArenaHud.clock_text(61.2) == "1:02" and ArenaHud.clock_text(0.0) == "0:00" and ArenaHud.clock_text(-3.0) == "0:00", "the clock counts whole seconds down")

	# Countdown, then driving.
	var guard := 0
	while scene.state == "countdown" and guard < 400:
		scene._process(1.0 / 60.0)
		guard += 1
	check(scene.state == "play" and scene.arena.started and guard > 150 and guard < 230, "the countdown takes about three seconds")
	scene._process(1.0 / 60.0)
	check(scene.input._can_drive(), "the controls come alive at the start")
	var start := Vector2(scene.player.x, scene.player.z)
	scene.input.gas = true
	scene.input.steer = 0.0
	for i in 89:
		scene.input.gas = true
		scene._process(1.0 / 60.0)
	scene.hud._process(0.0)
	check(Vector2(scene.player.x, scene.player.z).distance_to(start) > 5.0 and scene.player.v > 5.0, "the gas drives the player's car")
	check(visual.global_position.distance_to(Vector3(scene.player.x, scene.player.hop, scene.player.z)) < 0.01, "the drawn car follows")
	check(scene.arena.time > 1.4 and scene.arena.time < 1.6 and scene.hud._clock.text == "1:59", "the clock runs in real time")

	# A hit by the player reaches the HUD.
	var rival: ArenaCar = scene.arena.cars.filter(func(c: ArenaCar) -> bool: return c != scene.player)[0]
	scene.arena.take_events()
	scene.arena.score_hit(scene.player, rival, 15.0, Vector2(rival.x, rival.z))
	scene._events()
	scene.hud._process(0.0)
	check(scene.player.score == 15 * Arena.HIT_POINTS and scene.hud._score.text == str(scene.player.score), "a hit shows in the score at once")
	check(scene.hud._pop.text == "+%d" % scene.player.score and scene.hud._feed.get_child_count() >= 1, "and is called out")
	# A pickup shows in the hand and can be fired with the item button.
	scene.player.slots = [{"type": "ram", "ammo": 1}]
	scene.hud._process(0.0)
	scene.input.sync_actions()
	check(scene.hud._slots[0].visible and scene.hud._slots[0].icon != null and not scene.hud._slots[1].visible, "a carried pickup shows in the hand")
	check(scene.input._fire_btn.text == "DASHI" and scene.input._fire_btn.icon != null and not scene.input._fire_btn.disabled and not scene.input._back_btn.visible, "the item button names the ram charge and is ready")
	scene.input._request_action(false)
	scene._process(1.0 / 60.0)
	scene._process(1.0 / 60.0)
	check(scene.player.ram_t > 1.0 and scene.player.slots.is_empty(), "the item button fires it")

	# Pause and resume.
	scene.toggle_pause()
	check(scene.paused and get_tree().paused and scene.pause_ui.visible and not scene.input.visible, "pause stops the round")
	var paused_time: float = scene.arena.time
	scene._process(0.5)
	check(scene.arena.time == paused_time, "nothing runs while paused")
	button(scene, "Vazhdo").pressed.emit()
	check(not scene.paused and not get_tree().paused and scene.input.visible, "resume carries on")

	# Time up: a short slow motion, then the results.
	scene.arena.time = scene.arena.time_limit - 0.05
	for i in 6:
		scene._process(1.0 / 60.0)
	check(scene.state == "over" and scene.arena.over and not scene.input.visible, "the clock ends the round and takes the controls away")
	var place: int = scene.player.place
	var final_score: int = scene.player.score
	var over_time: float = scene.arena.time
	for i in 30:
		scene._process(1.0 / 60.0)
	check(scene.arena.time - over_time < 0.5 * 0.45, "the end plays in slow motion")
	scene.toggle_pause()
	check(not scene.paused, "there is no pausing after time is up")
	for i in 240:
		if scene.state == "results":
			break
		scene._process(1.0 / 60.0)
	check(scene.state == "results", "the results follow a few seconds later")
	await wait_scene("results")
	var result: Dictionary = Game.last_result
	check(str(result.mode) == "points" and int(result.place) == place and int(result.score) == final_score and result.rows.size() == 6, "the result carries the points and the place")
	var row_scores: Array = result.rows.map(func(row: Dictionary) -> int: return int(row.score))
	var by_score := row_scores.duplicate()
	by_score.sort()
	by_score.reverse()
	check(row_scores == by_score and result.rows.filter(func(row: Dictionary) -> bool: return bool(row.is_player)).size() == 1, "rows are in score order, the player among them")
	var results: Results = Game._root.get_child(0)
	var texts := results.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(texts.has("SHESHI SKËNDERBEJ · PIKË") and texts.has("PIKË") and texts.has("GODITJE") and not texts.has("KOHA"), "the results page shows points and hits, not lap times")
	check(texts.has("Pikët e tua: %d" % final_score) and texts.has(str(final_score)), "the player's points are on the page")
	check(not result.has("fans_total") and results._fans_label == null, "a points round earns no fans and shows no tally")

	# Again plays another round; the menu still has the mode chosen.
	button(results, "Përsërit").pressed.emit()
	await wait_scene("arena")
	scene = Game._root.get_child(0)
	check(scene is ArenaScene and scene.state == "countdown" and scene.player.score == 0, "again starts a fresh round")
	scene.toggle_pause()
	button(scene, "Dil").pressed.emit()
	await wait_scene("menu")
	check(not get_tree().paused, "leaving from pause does not leave the game paused")
	menu = Game._root.get_child(0)
	check(menu._mode.text == "Mënyra: Pikë · 3 min" or menu._mode.text == "Mënyra: Pikë · 2 min", "the menu remembers the mode for the session")

	Game.race_opts = saved_opts
	Settings.load_input_config(saved_input)
	Settings.changed.emit()
	main.queue_free()
	await get_tree().create_timer(0.5).timeout
	Sfx.enabled = sound
	print("ARENA FLOW: menu -> points round -> results -> again -> menu; failures=", failures)
	get_tree().quit(1 if failures else 0)
