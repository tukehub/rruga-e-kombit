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

func _ready() -> void:
	Quality.set_preset("low")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	var menu: Menu = Game._root.get_child(0)
	menu.show_page("city")
	menu.show_page("car")
	Game.race_opts.laps = 1
	button(menu, "Nisu!").pressed.emit()
	check(Game.has_node("TransitionOverlay") and is_instance_valid(menu), "loading feedback appears before scene teardown")
	await wait_scene("race")
	var scene = Game._root.get_child(0)
	scene.set_process(false)
	scene.set_scenery_visible(false)
	check(not scene.buildings.visible and not scene.props.visible and not scene.terrain.visible and scene.road.visible, "scenery comparison hides world while keeping road")
	check(scene.side_roads == null or not scene.side_roads.visible, "scenery comparison hides side roads")
	scene.set_scenery_visible(true)
	check(scene.buildings.visible and scene.props.visible and scene.terrain.visible and scene.hud.diagnostic_fps, "scenery comparison restores world and keeps FPS display")
	check(scene.views.mirror_panel.visible, "rear mirror visible by default")
	var player_visual: CarVisual = scene.cars[scene.race.cars.find(scene.player)]
	check(player_visual.body.layers == 2, "player body isolated from rear mirror")
	for wheel in player_visual.wheels.values():
		check(wheel.layers == 2, "player wheel isolated from rear mirror")
	scene.views._toggle_view()
	check(scene.cam.cabin and scene.views.cabin_overlay.visible and not scene.cam.get_cull_mask_value(2), "cabin view hides own car and shows dashboard")
	scene.views._toggle_view()
	check(not scene.cam.cabin and scene.cam.get_cull_mask_value(2), "exterior view restores own car")
	scene.views._toggle_mirror()
	check(not scene.views.mirror_panel.visible and scene.views.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "mirror can be disabled")
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
	scene.views._toggle_mirror()
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
	scene.cam.cabin = true
	scene.race.emit({"t": "finish", "car": scene.player})
	scene._events()
	check(scene.state == "finish" and not scene.cam.cabin and scene.cam.get_cull_mask_value(2), "finish restores exterior view")
	var finish_progress: float = scene.player.progress
	for i in 120:
		scene._process(1.0 / 60.0)
	check(scene.player.v < 35.0 and scene.player.progress > finish_progress, "finished car slows while continuing forward")
	var forward := scene.track.tangent(scene.player.s)
	var car_at := scene.track.pos(scene.player.s, scene.player.d)
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
	scene.toggle_pause()
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
	await wait_scene("results")
	check(Game.last_result.get("rows", []).size() == 6, "six result rows")
	var results: Node = Game._root.get_child(0)
	button(results, "Përsërit").pressed.emit()
	await wait_scene("race")
	scene = Game._root.get_child(0)
	scene.toggle_pause()
	button(scene, "Dil").pressed.emit()
	await wait_scene("menu")
	check(not get_tree().paused, "return to menu unpauses")
	print("FLOW: menu -> race -> results -> retry -> quit -> menu; failures=", failures)
	Sfx.stop_all()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
