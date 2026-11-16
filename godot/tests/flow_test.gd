extends Node

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func wait_scene(want: String) -> bool:
	for i in 30:
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

const PROGRESS_FILE := "user://progress_flow_test.cfg"

func _ready() -> void:
	Quality.set_preset("low")
	# Earned fans go to a test file, never the player's own.
	var real_progress: String = Progress.path
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(PROGRESS_FILE + suffix):
			DirAccess.remove_absolute(PROGRESS_FILE + suffix)
	Progress.path = PROGRESS_FILE
	Progress.load_progress()
	Progress.fans = 500
	Progress.save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	# Each transition draws from a shuffled bag, with no repeated fact until
	# the bag is exhausted and no repeat at the boundary between bags.
	Game._fact_bag.clear()
	Game._last_fact = ""
	var seen_facts := {}
	var previous_fact := ""
	var facts := Data.t_list("loading.facts")
	for i in facts.size() * 2:
		var fact: String = Game._next_loading_fact()
		check(fact != previous_fact, "loading facts should not repeat consecutively")
		if i < facts.size():
			check(not seen_facts.has(fact), "loading facts should not repeat before a full cycle")
			seen_facts[fact] = true
		previous_fact = fact
	var preview: CanvasLayer = Game._transition_overlay("race")
	var title := preview.find_child("LoadingTitle", true, false) as Label
	var heading := preview.find_child("LoadingFactHeading", true, false) as Label
	var fact := preview.find_child("LoadingFact", true, false) as Label
	check(title != null and title.text == "Gara po fillon", "loading transition displays the requested title")
	check(heading != null and heading.text == "Fakt rastesor:", "loading transition displays the fact heading")
	check(fact != null and fact.text in facts, "loading transition displays a random fact")
	check(fact != null and fact.get_theme_font_size("font_size") > 23, "loading fact uses larger text")
	preview.free()
	var menu: Menu = Game._root.get_child(0)
	menu.show_page("settings")
	check(button(menu, "Kalibro animin") != null, "main settings includes shared control configuration")
	Game.race_opts.reverse = false
	Game.race_opts.laps = 0
	menu.show_page("title")
	check(menu._direction.text == "Drejtimi: Normal", "forward direction is shown")
	menu._direction.pressed.emit()
	check(bool(Game.race_opts.reverse) and menu._direction.text == "Drejtimi: Kundërt", "direction selector chooses reverse")
	var env_before := str(Game.race_opts.env)
	menu._weather.pressed.emit()
	check(str(Game.race_opts.env) == "rainy" and menu._weather.text == "Moti: Shi", "weather selector chooses rain")
	menu._weather.pressed.emit()
	check(str(Game.race_opts.env) == "day" and menu._weather.text == "Moti: Diell", "weather selector returns to sun")
	Game.race_opts.env = env_before
	var default_laps := Game.city_laps("tirane")
	menu._lap_plus.pressed.emit()
	check(int(Game.race_opts.laps) == default_laps + 1 and menu._lap_value.text == str(default_laps + 1), "lap selector updates race options")
	menu._lap_minus.pressed.emit()
	menu._lap_minus.pressed.emit()
	check(int(Game.race_opts.laps) == 1 and menu._lap_minus.disabled, "lap selector bounds minimum")
	Game.race_opts.laps = 9
	menu._refresh_city()
	check(menu._lap_plus.disabled and menu._lap_value.text == "9", "lap selector bounds maximum")
	Game.race_opts.laps = 1
	menu._refresh_city()
	menu.show_page("city")
	menu.show_page("car")
	button(menu, "Nisu!").pressed.emit()
	check(Game.has_node("TransitionOverlay") and is_instance_valid(menu), "loading feedback appears before scene teardown")
	await wait_scene("race")
	var scene = Game._root.get_child(0)
	scene.set_process(false)
	check(scene.race.laps == 1 and Settings.laps_override == 1, "selected laps applied and saved")
	# Intro cinematic: one name card per racer, front of the grid first.
	var cards: IntroCards = scene.intro_cards
	check(scene.state == "intro" and is_instance_valid(cards) and cards.cards.size() == scene.race.cars.size() + 1, "the intro shows a heading and one name card per racer")
	var grid_order := IntroCards.grid_order(scene.race.cars)
	var card_names := []
	var player_cards := 0
	for i in range(1, cards.cards.size()):
		var card_car: CarState = cards.cards[i].get_meta("car")
		check(card_car == grid_order[i - 1] and (cards.cards[i].find_child("DriverName", true, false) as Label).text == card_car.name, "card %d names the driver in that grid slot" % i)
		card_names.append(card_car.name)
		if card_car.is_player:
			player_cards += 1
	check(grid_order[0].progress >= grid_order[-1].progress and player_cards == 1 and scene.race.traffic.all(func(t: CarState) -> bool: return not card_names.has(t.name)), "cards run from the front row back, the player once, no traffic")
	check(cards.mouse_filter == Control.MOUSE_FILTER_IGNORE and not cards.leaving, "the cards do not take touches and stay for the sweep")
	scene.cam.intro_t = 2.79
	scene._process(1.0 / 60.0)
	check(scene.state == "countdown" and cards.leaving, "the cards leave when the countdown starts")
	await get_tree().create_timer(IntroCards.LEAVE_TIME + 0.2).timeout
	check(not is_instance_valid(cards), "the cards are removed after fading out")
	# Finish slow motion: slow on the line, back to full speed, briefly.
	check(is_equal_approx(scene.finish_time_scale(0.0), scene.FINISH_SLOW_SCALE) and scene.FINISH_SLOW_SCALE < 0.5 and scene.FINISH_SLOW_SCALE > 0.1, "the finish starts in slow motion")
	check(is_equal_approx(scene.finish_time_scale(scene.FINISH_SLOW_HOLD), scene.FINISH_SLOW_SCALE), "slow motion holds for a moment")
	var mid_scale: float = scene.finish_time_scale(scene.FINISH_SLOW_HOLD + scene.FINISH_SLOW_EASE * 0.5)
	check(mid_scale > scene.FINISH_SLOW_SCALE and mid_scale < 1.0, "time eases back")
	check(is_equal_approx(scene.finish_time_scale(scene.FINISH_SLOW_HOLD + scene.FINISH_SLOW_EASE), 1.0) and scene.finish_time_scale(10.0) == 1.0, "full speed returns")
	check(scene.FINISH_SLOW_HOLD + scene.FINISH_SLOW_EASE < 1.5, "slow motion is brief, well before the results")
	var forward_track := RaceTrack.load_city("tirane")
	check(Settings.reverse_lap and scene.track.tangent(0.0).dot(forward_track.tangent(0.0)) < -0.99, "reverse selection persists and applies to race")
	scene.set_scenery_visible(false)
	check(not scene.buildings.visible and not scene.props.visible and not scene.terrain.visible and scene.road.visible, "scenery comparison hides world while keeping road")
	check(scene.side_roads == null or not scene.side_roads.visible, "scenery comparison hides side roads")
	scene.set_scenery_visible(true)
	check(scene.buildings.visible and scene.props.visible and scene.terrain.visible and scene.hud.diagnostic_fps, "scenery comparison restores world and keeps FPS display")
	check(scene.views.mirror_panel.visible == Settings.mirror, "rear mirror follows the saved setting")
	var traffic_counts: Dictionary = Data.traffic(Quality.preset)
	check(scene.race.traffic.size() == int(traffic_counts.parked) + int(traffic_counts.moving), "the race places the quality preset's traffic")
	check(scene.traffic_cars.size() == scene.race.traffic.size() and scene.cars.size() == scene.race.cars.size(), "every traffic car is drawn, apart from the racers")
	if scene.views.enabled:
		scene.views._toggle_mirror()
	check(scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "disabled mirror renders nothing")
	var player_visual: CarVisual = scene.cars[scene.race.cars.find(scene.player)]
	check(player_visual.body.layers == 2, "player body isolated from rear mirror")
	for wheel in player_visual.wheels.values():
		check(wheel.layers == 2, "player wheel isolated from rear mirror")
	scene.views._toggle_view()
	check(scene.cam.view == ChaseCam.View.CABIN and scene.views.cabin_overlay.visible and not scene.cam.get_cull_mask_value(2), "cabin view hides own car and shows dashboard")
	check(scene.views.view_button.text == Data.t("view.camera.cabin"), "view button names the cabin view")
	scene.views._toggle_view()
	check(scene.cam.view == ChaseCam.View.BUMPER and not scene.views.cabin_overlay.visible and not scene.cam.get_cull_mask_value(2), "bumper view hides own car and the dashboard")
	check(scene.views.view_button.text == Data.t("view.camera.bumper"), "view button names the bumper view")
	scene.views._toggle_view()
	check(scene.cam.view == ChaseCam.View.CHASE and scene.cam.get_cull_mask_value(2), "exterior view restores own car")
	check(scene.views.view_button.text == Data.t("view.camera.chase"), "view button names the chase view")
	scene.views._toggle_mirror()
	check(scene.views.mirror_panel.visible and Settings.mirror, "mirror can be enabled and the choice is saved")
	scene.views._toggle_mirror()
	check(not scene.views.mirror_panel.visible and not Settings.mirror and scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "mirror can be disabled")
	scene.views._toggle_mirror()
	check(scene.views.mirror_panel.visible, "mirror can be reenabled")
	# Enabling refreshes immediately, then schedules one rear pass every three
	# rendered frames; leaving it off schedules none.
	scene.views.update_pose(scene.player, {}, 1.0 / 60.0)
	check(scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "reenabled mirror refreshes")
	scene.views.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for i in 2:
		scene.views.update_pose(scene.player, {}, 1.0 / 60.0)
		check(scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "mirror skips intermediate frame")
	scene.views.update_pose(scene.player, {}, 1.0 / 60.0)
	check(scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_ONCE, "mirror updates on third frame")
	scene.views._toggle_mirror()
	scene.views.update_pose(scene.player, {}, 1.0 / 60.0)
	check(scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "disabled mirror schedules no rendering")
	# Standings report live distances from the player on the full race progress,
	# so the same calculation also works across the start line and multiple laps.
	var opponent: CarState = scene.race.cars[1]
	var saved_progress := opponent.progress
	opponent.progress = scene.player.progress + 12.0
	scene.hud._process(0.016)
	var opponent_row: int = scene.race.order.find(opponent)
	check(scene.hud._board_gaps[opponent_row].text == "+12m", "leaderboard distance ahead")
	opponent.progress = scene.player.progress - 32.0
	scene.hud._process(0.016)
	check(scene.hud._board_gaps[opponent_row].text == "-32m", "leaderboard distance behind updates")
	opponent.progress = saved_progress
	# A 120 Hz render frame between fixed simulation steps should visibly move
	# the car without advancing the simulation. The camera must follow that
	# same rendered pose, rather than the newer raw simulation position.
	scene.state = "race"
	scene.race.started = true
	scene.player.autopilot = true
	scene.player.v = 30.0
	scene.cam.intro = false
	scene._process(1.0 / 60.0)
	var progress_after_step: float = scene.player.progress
	var player_index: int = scene.race.cars.find(scene.player)
	var before: Vector3 = scene.cars[player_index].base_pos
	scene.cam._snap = true
	scene._process(1.0 / 120.0)
	var after: Vector3 = scene.cars[player_index].base_pos
	check(is_equal_approx(scene.player.progress, progress_after_step), "render-only frame leaves simulation unchanged")
	check(after.distance_to(before) > 0.05, "car advances on frame without simulation step")
	var pose: Dictionary = scene.RenderPose.sample(scene._previous_poses[player_index], scene.player, scene.acc / scene.DT, scene.track.L)
	var pose_s: float = pose.s
	var car_pos: Vector3 = scene.track.pos(pose_s, pose.d)
	car_pos.y += float(pose.hop)
	var psi: float = scene.track.heading(pose_s) + float(pose.yaw) * 0.5
	var tangent: Vector3 = scene.track.tangent(pose_s)
	var expected_look := Vector3(car_pos.x - sin(psi) * 12.0, car_pos.y + 1.0 + tangent.y * 12.0, car_pos.z + cos(psi) * 12.0)
	check(scene.cam.look.distance_to(expected_look) < 0.001, "camera follows rendered car pose")
	# A slow frame that reaches the 5-step cap should preserve the fraction of
	# the next step; a longer stall should drop only excess whole steps.
	scene.acc = 0.0
	scene._process(0.09)
	check(absf(scene.acc - (0.09 - 5.0 * scene.DT)) < 0.000001, "slow frame preserves fractional simulation step")
	var before_stall: float = scene.acc
	scene._process(0.1)
	check(absf(scene.acc - before_stall) < 0.000001, "stall drops excess whole simulation steps only")
	# Finishing from cabin view restores the car, slows it while it continues
	# along the circuit, and moves the camera to look back at its front.
	scene.race.take_events()
	scene.player.finished = true
	scene.player.finish_time = 80.0
	scene.player.v = 40.0
	scene.views.set_view(ChaseCam.View.CABIN)
	scene.race.emit({"t": "finish", "car": scene.player})
	scene._events()
	check(scene.state == "finish" and scene.cam.view == ChaseCam.View.CHASE and scene.cam.get_cull_mask_value(2) and not scene.views.cabin_overlay.visible, "finish restores exterior view")
	check(not scene.input.visible and not scene.input.gas, "finish hides and clears driving controls")
	var finish_visual: CarVisual = scene.cars[scene.race.cars.find(scene.player)]
	check(finish_visual.finish_driver.visible and finish_visual.finish_glass.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "finish reveals driver through windshield")
	var finish_progress: float = scene.player.progress
	var camera_before: Vector3 = scene.cam.global_position
	var finish_time: float = scene.race.time
	var drawn_before: Vector3 = finish_visual.base_pos
	scene.acc = 0.0
	scene._process(1.0 / 60.0)
	# In slow motion the first frame is a fraction of a simulation step: the
	# drawn car still moves, by interpolation.
	check(finish_visual.base_pos.distance_to(drawn_before) > 0.01, "car continues moving on the first finish frame")
	check(scene.cam.global_position.distance_to(camera_before) < 2.0, "finish camera starts without a jump")
	for i in 29:
		scene._process(1.0 / 60.0)
	var slow_time: float = scene.race.time - finish_time
	check(slow_time > 0.5 * scene.FINISH_SLOW_SCALE * 0.8 and slow_time < 0.5 * scene.FINISH_SLOW_SCALE * 1.2, "the race runs in slow motion after the line (%.3f s in 0.5 s)" % slow_time)
	check(scene.player.progress > finish_progress, "the car keeps travelling in slow motion")
	for i in 150:
		scene._process(1.0 / 60.0)
	var late_time: float = scene.race.time
	for i in 60:
		scene._process(1.0 / 60.0)
	check(absf((scene.race.time - late_time) - 1.0) < 0.05 and scene.state == "finish", "full speed is back before the results")
	# The spider camera follows a 3.8-second arc; direction and approach side
	# can put its halfway point near the side of the car on a reversed lap.
	check(scene.player.v < 35.0 and scene.player.progress > finish_progress, "finished car slows while continuing forward")
	var forward: Vector3 = scene.track.tangent(scene.player.s)
	var car_at: Vector3 = scene.track.pos(scene.player.s, scene.player.d)
	check((scene.cam.global_position - car_at).dot(forward) > 0.0, "finish camera moves in front of car")
	# Rebuild so the flow test starts with an untouched race.
	Game.goto("race")
	await wait_scene("race")
	scene = Game._root.get_child(0)
	scene.set_process(false)
	# The cinematic's last frame meets the chase camera without a position cut.
	scene.cam.intro_t = 2.8
	scene.cam._intro_cam(scene.player, 0.0)
	var intro_end: Vector3 = scene.cam.global_position
	scene.cam.follow(scene.player, 0.0)
	check(intro_end.distance_to(scene.cam.global_position) < 0.01, "intro joins chase camera smoothly")
	scene.cam.start_intro()
	scene.player.autopilot = true
	scene.input.gas = true
	scene.toggle_pause()
	check(scene.paused and not scene.input.gas, "pause resets input")
	check(not scene.hud.can_process() and not scene.input.can_process() and scene.pause_ui.can_process(), "combat HUD/input pause while pause controls stay interactive")
	button(scene, "Kontrollet").pressed.emit()
	check(scene._controls_ui.visible and not scene._pause_box.visible and get_tree().paused, "control configuration opens over the preserved paused race")
	var previous_input := Settings.input_config()
	var control_settings: Node = scene._controls_ui.find_children("*", "OptionButton", true, false)[0].get_parent().get_parent()
	var accel: OptionButton = control_settings._choices.auto_accel.node
	accel.item_selected.emit(1)
	var hand: OptionButton = control_settings._choices.left_handed.node
	hand.item_selected.emit(1)
	check(Settings.auto_accel and Settings.left_handed and not scene.input.gas and not scene.player.ctrl.gas, "paused control changes cannot accelerate the car")
	button(scene, "Kthehu te pauza").pressed.emit()
	check(not scene._controls_ui.visible and scene._pause_box.visible and scene.paused, "returning from controls keeps the race paused")
	Settings.load_input_config(previous_input)
	Settings.save()
	scene.toggle_pause()
	var previous_state: String = scene.state
	var desktop_before: bool = scene.input.is_desktop()
	scene.state = "race"
	scene.input._desktop = false
	scene.input.tilt_ok = false
	Settings.touch_steer = false
	scene._recover_missing_tilt(0.5)
	check(not Settings.touch_steer, "tilt fallback allows sensors to warm up after resume")
	scene._recover_missing_tilt(0.51)
	check(Settings.touch_steer and scene.input._steer_btn.visible, "missing mobile tilt restores usable touch steering during the race")
	scene.input._desktop = desktop_before
	scene.state = previous_state
	Settings.load_input_config(previous_input)
	Settings.save()
	# Exercise actual intro, countdown, race, finish and results hand-off.
	for batch in 120:
		for i in 600:
			scene._process(1.0 / 60.0)
			if scene.state == "results":
				break
		if scene.state == "results":
			break
		await get_tree().process_frame
	check(scene.player.finished, "player completes real race")
	var earned_in_race := int(scene.player.fans)
	await wait_scene("results")
	check(Game.last_result.get("rows", []).size() == 6, "six result rows")
	var results: Results = Game._root.get_child(0)
	# 6.1: the race's fans are kept, and the results count them up.
	check(earned_in_race > 0 and int(Game.last_result.fans) == earned_in_race, "the result carries the fans the race earned (%d)" % earned_in_race)
	check(int(Game.last_result.fans_before) == 500 and Progress.fans == 500 + earned_in_race and int(Game.last_result.fans_total) == Progress.fans, "the fans are added to the player's total")
	var fan_file := ConfigFile.new()
	fan_file.load(PROGRESS_FILE)
	check(int(fan_file.get_value("progress", "fans", 0)) == 500 + earned_in_race, "and saved at once")
	check(results.fans_earned == earned_in_race and results.fans_total == 500 + earned_in_race, "the results page knows both numbers")
	check(results._fans_label.text == "+0 FANË" and results._fans_total_label.text == "Gjithsej: 500 fanë", "the tally starts from what the player had")
	await get_tree().create_timer(results.fan_tally_delay + Results.FAN_TALLY_TIME * 0.4).timeout
	var midway := int(results._fans_label.text.trim_prefix("+").get_slice(" ", 0))
	check(midway > 0 and midway < earned_in_race, "the tally counts up (%d of %d)" % [midway, earned_in_race])
	await get_tree().create_timer(Results.FAN_TALLY_TIME).timeout
	check(results._fans_label.text == "+%d FANË" % earned_in_race and results._fans_total_label.text == "Gjithsej: %d fanë" % (500 + earned_in_race), "the tally ends on the earned fans and the new total")
	button(results, "Përsërit").pressed.emit()
	await wait_scene("race")
	scene = Game._root.get_child(0)
	# Restarting from the pause menu rebuilds the race but keeps the city loaded.
	var kept_buildings: Node = scene.buildings
	var old_race: Race = scene.race
	scene.toggle_pause()
	button(scene, "Rifillo").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	check(Game._root.get_child(0) == scene and scene.buildings == kept_buildings, "restart keeps the loaded city")
	check(scene.race != old_race and scene.cars.size() == 6 and scene.state == "intro", "restart begins a fresh race")
	check(not scene.paused and not get_tree().paused, "restart resumes the game")
	scene.toggle_pause()
	button(scene, "Dil").pressed.emit()
	await wait_scene("menu")
	check(not get_tree().paused, "return to menu unpauses")
	check(Progress.fans == 500 + earned_in_race, "a race quit from pause earns nothing")
	Progress.path = real_progress
	Progress.load_progress()
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(PROGRESS_FILE + suffix):
			DirAccess.remove_absolute(PROGRESS_FILE + suffix)
	print("FLOW: menu -> race -> results -> retry -> quit -> menu; failures=", failures)
	Sfx.stop_all()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
