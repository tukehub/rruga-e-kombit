class_name RaceScene
extends Node3D
## One race: builds the city, runs the simulation at a fixed 60 Hz step,
## drives car visuals, camera, HUD, audio, pause and the finish hand-off.
## States: intro -> countdown -> race -> finish -> results.

const DT := 1.0 / 60.0
const MAX_CATCHUP_STEPS := 3
const RenderPose = preload("res://scripts/game/render_pose.gd")
const CombatFeedback = preload("res://scripts/ui/combat_feedback.gd")
const RouteGuide = preload("res://scripts/sim/route_guide.gd")
const RouteSigns = preload("res://scripts/world/route_signs.gd")
const SpeedFeedback = preload("res://scripts/game/speed_feedback.gd")
var speed_feedback: SpeedFeedback

var city_id := "tirane"
var env_id := "night"
var track: RaceTrack
var race: Race
var player: CarState
var cars: Array[CarVisual] = []
var sky: SkyEnv
var terrain: Terrain
var road: RoadMesh
var route_guide: RouteGuide
var cam: ChaseCam
var views: RaceViews
var hud: Hud
var input: RaceInput
var effects: FxVisual
var buildings: Buildings
var props: Props
var pine_forest: Node3D
var side_roads: Node3D
var scenery_visible := true
var _weather_clock := 0.0
var _weather_step := 0
var _light_clock := 0.0
var _env_pushed := Vector2(-1.0, -1.0)
var pickups: PickupVisual
var pause_ui: Control
var _pause_box: Control
var _controls_ui: Control
var _ui_layer: CanvasLayer

var state := "intro"
var acc := 0.0
var dropped_sim_time := 0.0
var _previous_poses: Array[Dictionary] = []
var cd_t := 0.0
var cd_n := 4
var fin_t := 0.0
var finish_speed_limit := 0.0
var last500 := false
var paused := false
var _snd_t := {}
var _seen_tip := false
var _tilt_missing_t := 0.0


func _ready() -> void:
	city_id = str(Game.race_opts.city)
	env_id = Game.city_env(city_id)
	Quality.apply_viewport(get_viewport())
	_build_world()
	_build_race()
	_build_ui()
	Quality.budget_changed.connect(_apply_render_budget)
	_begin()


func _apply_render_budget() -> void:
	Quality.apply_viewport(get_viewport())
	CarVisual.update_headlight_budget(cars, cam.global_position)


func _begin() -> void:
	Quality.reset_observation()
	get_tree().paused = false
	paused = false
	state = "intro"
	cam.start_intro()
	hud.center(Data.city_name(city_id), Data.t("race.intro", [Data.env_label(env_id), race.laps]), 2.6)


## Restart in place: terrain, buildings, props, road and sky stay loaded; only
## the race, its cars, the camera and the UI are rebuilt.
func restart() -> void:
	Sfx.stop_loops()
	if not scenery_visible:
		set_scenery_visible(true)
	for cv in cars:
		cv.queue_free()
	cars.clear()
	_previous_poses.clear()
	for node: Node in [pickups, effects, cam, views, speed_feedback, _ui_layer]:
		node.queue_free()
	_snd_t.clear()
	acc = 0.0
	dropped_sim_time = 0.0
	cd_t = 0.0
	cd_n = 4
	fin_t = 0.0
	finish_speed_limit = 0.0
	last500 = false
	_tilt_missing_t = 0.0
	_weather_clock = 0.0
	_weather_step = 0
	_light_clock = 0.0
	# Dynamic weather may have moved on; return to the race's own sky.
	if sky.env_id != env_id or sky._transition < 1.0:
		sky._transition = 1.0
		sky.apply(env_id)
	_env_pushed = Vector2(-1.0, -1.0)
	_build_race()
	_build_ui()
	_begin()


func _build_world() -> void:
	var splat: Texture2D = load("res://assets/cities/%s/splat.png" % city_id)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.load_city(city_id, splat)
	track = RaceTrack.load_city(city_id, bool(Game.race_opts.reverse))
	route_guide = RouteGuide.new(track)
	var tj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/%s/track.json" % city_id))
	sky = SkyEnv.new()
	add_child(sky)
	sky.apply(env_id)
	road = RoadMesh.new()
	add_child(road)
	road.build(track, float(tj.get("hw", track.half_w)), sky.wet, terrain.height_at)
	var route_signs := RouteSigns.new()
	route_signs.name = "RouteSigns"
	road.add_child(route_signs)
	route_signs.build(track, route_guide, terrain.height_at)
	buildings = Buildings.new()
	var side_path := "res://assets/cities/%s/roads.glb" % city_id
	if Quality.preset != "low" and ResourceLoader.exists(side_path):
		var side_scene: PackedScene = load(side_path)
		side_roads = side_scene.instantiate()
		add_child(side_roads)
		for node in side_roads.find_children("*", "MeshInstance3D", true, false):
			var ribbon := node as MeshInstance3D
			ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ribbon.visibility_range_end = 750.0
			ribbon.visibility_range_end_margin = 75.0
	var bld := buildings
	add_child(bld)
	bld.load_city(city_id)
	bld.set_env(sky.night, sky.wet)
	props = Props.new()
	add_child(props)
	props.load_city(city_id, terrain)
	props.set_night(sky.night)
	pine_forest = get_node_or_null("PineForest") as Node3D
	_setup_pines()
	terrain.set_env(sky.wet, 0.0, sky.night)
	road.set_wet(sky.wet)


func _setup_pines() -> void:
	# Replace a sparse selection of the existing mapped Tirana trees, instead of
	# scattering trees randomly over the road, buildings, or other cities.
	if city_id != "tirane" or pine_forest == null or not pine_forest.has_method("build_forest"):
		return
	var limit := 8 if Quality.preset == "low" else (24 if Quality.preset == "medium" else 32)
	var candidates := {}
	for ref: Dictionary in props._tree_refs:
		var world: Transform3D = ref.world
		var p := world.origin
		var idx := track.nearest(p.x, p.z, 60.0)
		if idx < 0:
			continue
		var distance := Vector2(track.X[idx] - p.x, track.Z[idx] - p.z).length()
		if distance < track.half_w + 15.0 or distance > 55.0:
			continue
		var near_landmark := false
		for anchor in props.landmarks:
			if Vector2(float(anchor.x) - p.x, float(anchor.z) - p.z).length_squared() < 65.0 * 65.0:
				near_landmark = true
				break
		if near_landmark:
			continue
		var bucket := mini(limit - 1, int(float(idx) / float(track.M) * limit))
		var score := absf(distance - 38.0)
		if not candidates.has(bucket) or score < float(candidates[bucket].score):
			candidates[bucket] = {"ref": ref, "score": score}
	var transforms: Array[Transform3D] = []
	var buckets := candidates.keys()
	buckets.sort()
	for bucket in buckets:
		var ref: Dictionary = candidates[bucket].ref
		var hidden: Transform3D = ref.local
		hidden.basis = Basis.from_scale(Vector3.ZERO)
		ref.mm.set_instance_transform(ref.index, hidden)
		var position: Vector3 = (ref.world as Transform3D).origin
		var chunk := Vector2i(floori(position.x / Props.TREE_CHUNK_SIZE), floori(position.z / Props.TREE_CHUNK_SIZE))
		props._tree_chunks[chunk].erase(ref)
		props._tree_refs.erase(ref)
		transforms.append(ref.world)
	pine_forest.call("build_forest", transforms)


func _build_race() -> void:
	var seed_value := int(Time.get_unix_time_from_system()) % 100000
	var laps := Game.city_laps(city_id)
	for a in Game.launch_options():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))  # debug: replay a logged race
		elif a.begins_with("--laps="):
			laps = maxi(1, int(a.substr(7)))  # debug: short races
	var opts := {
		"laps": laps,
		"diff": int(Game.race_opts.diff),
		"seed": seed_value,
		"wet": sky.wet,
		"assist": Settings.assist,
		"brake_assist": Settings.assist,
		"driver": int(Game.race_opts.driver),
		"player_car": str(Game.race_opts.car),
	}
	race = Race.new(track, opts)
	race.started = false
	player = race.player
	if "--auto" in Game.launch_options():
		player.autopilot = true  # debug: let the AI drive the player car
	# One line per race in the log (adb logcat -s godot) is enough to replay it.
	print("RACE seed=%d city=%s reverse=%s env=%s laps=%d diff=%d assist=%s car=%s driver=%d" % [
		seed_value, city_id, str(bool(Game.race_opts.reverse)), env_id, race.laps, int(Game.race_opts.diff),
		str(Settings.assist), str(Game.race_opts.car), int(Game.race_opts.driver)])
	for c in race.cars:
		var cv := CarVisual.new()
		add_child(cv)
		cv.setup(c.def, (Color.html(c.def.color) if c.is_player else c.color), c.is_player)
		cv.set_night(sky.night)
		cv.apply_state(c, track, DT)
		cars.append(cv)
		_previous_poses.append(RenderPose.capture(c))
	pickups = PickupVisual.new()
	add_child(pickups)
	pickups.setup(race, track)
	effects = FxVisual.new()
	add_child(effects)
	effects.setup(race, track, cars[race.cars.find(player)], cars)
	cam = ChaseCam.new()
	add_child(cam)
	cam.setup(track)
	cam.current = true
	cam.follow(player, 0.0)


func _build_ui() -> void:
	speed_feedback = SpeedFeedback.new()
	add_child(speed_feedback)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui_layer = layer
	var safe := UiTheme.safe_area(layer)
	# Layout updates may run while paused; racing HUD/audio/input must not.
	safe.process_mode = Node.PROCESS_MODE_PAUSABLE
	views = RaceViews.new()
	add_child(views)
	views.setup(cam, cars[race.cars.find(player)], safe)
	input = RaceInput.new()
	safe.add_child(input)
	input.bind(player, race)
	hud = Hud.new()
	safe.add_child(hud)
	hud.setup(race, player, track, route_guide)
	input.bind_inventory(hud._slots)
	input.inventory_selected.connect(func(i: int): hud.slot_selected.emit(i))
	input.inventory_hold_changed.connect(hud.inventory_hold)
	input.action_denied.connect(_action_denied)
	hud.slot_selected.connect(func(i: int):
		if i > 0 and i < player.slots.size():
			player.ctrl.select = i
		elif i == 0 and player.slots.size() > 1:
			player.ctrl.cycle = true)
	hud.pause_pressed.connect(toggle_pause)
	_build_pause(layer)


func _build_pause(layer: CanvasLayer) -> void:
	pause_ui = Control.new()
	pause_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.theme = UiTheme.theme()
	pause_ui.visible = false
	pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_ui)
	pause_ui.add_child(UiTheme.shade(0.7))
	var safe := UiTheme.safe_area(pause_ui)
	var box := UiTheme.panel(22)
	_pause_box = box
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -220
	box.offset_right = 220
	box.offset_top = -255
	box.offset_bottom = 255
	safe.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)
	v.add_child(UiTheme.headline(Data.t("pause.title"), 64))
	v.add_child(UiTheme.spacer(6))
	var b_resume := UiTheme.button(Data.t("pause.resume"), UiTheme.CYAN.darkened(0.4))
	b_resume.pressed.connect(func(): Sfx.ui_click(); toggle_pause())
	v.add_child(b_resume)
	var b_controls := UiTheme.button(Data.t("controls.title"))
	b_controls.pressed.connect(func():
		_pause_box.hide()
		_controls_ui.show()
		Sfx.ui_click())
	v.add_child(b_controls)
	var b_compare := UiTheme.button(Data.t("pause.hide_scenery"))
	b_compare.pressed.connect(func():
		set_scenery_visible(not scenery_visible)
		b_compare.text = Data.t("pause.hide_scenery") if scenery_visible else Data.t("pause.show_scenery")
		Sfx.ui_click())
	v.add_child(b_compare)
	var b_restart := UiTheme.button(Data.t("pause.restart"))
	b_restart.pressed.connect(func(): Sfx.ui_click(); restart())
	v.add_child(b_restart)
	var b_quit := UiTheme.button(Data.t("pause.quit"))
	b_quit.pressed.connect(func(): Sfx.ui_back(); get_tree().paused = false; Sfx.stop_loops(); Game.goto("menu"))
	v.add_child(b_quit)
	_build_control_settings(safe)


func _build_control_settings(parent: Control) -> void:
	_controls_ui = UiTheme.panel(22)
	_controls_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_controls_ui.offset_left = 40
	_controls_ui.offset_right = -40
	_controls_ui.offset_top = 20
	_controls_ui.offset_bottom = -20
	parent.add_child(_controls_ui)
	var margins := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 16)
	_controls_ui.add_child(margins)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margins.add_child(column)
	column.add_child(UiTheme.headline(Data.t("controls.title"), 40, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var settings_panel := preload("res://scripts/ui/control_settings.gd").new()
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_panel)
	var back_button := UiTheme.button(Data.t("pause.back"))
	back_button.pressed.connect(_close_control_settings)
	column.add_child(back_button)
	_controls_ui.hide()


func _close_control_settings() -> void:
	Settings.save()
	_controls_ui.hide()
	_pause_box.show()
	Sfx.ui_back()


func set_scenery_visible(enabled: bool) -> void:
	scenery_visible = enabled
	buildings.visible = enabled
	props.visible = enabled
	if pine_forest:
		pine_forest.visible = enabled
	terrain.visible = enabled
	if side_roads:
		side_roads.visible = enabled
	# Keep the display on for both halves of the comparison.
	hud.diagnostic_fps = true


func toggle_pause() -> void:
	if state in ["finish", "results"]:
		return
	paused = not paused
	get_tree().paused = paused
	pause_ui.visible = paused
	input.set_driving_enabled(false)
	input.reset_controls()
	_clear_pending_actions()
	input.visible = not paused
	_controls_ui.hide()
	_pause_box.show()
	if paused:
		Sfx.stop_loops()
		speed_feedback.update(player, false, 0.0)
	else:
		Quality.reset_observation(2.0)
		input.resume_controls()
		input.set_driving_enabled(state == "race")


func _clear_pending_actions() -> void:
	if player != null:
		player.ctrl.steer = 0.0
		player.ctrl.gas = false
		player.ctrl.brake = false
		player.ctrl.fire = false
		player.ctrl.back = false
		player.ctrl.cycle = false
		player.ctrl.select = 0
		player.ctrl.boost = false
		player.ctrl.discard = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if input != null and not paused and state in ["intro", "race", "countdown"]:
			toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if paused and _controls_ui.visible:
			_close_control_settings()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()


static func _timing_plan(accumulator: float, elapsed: float) -> Dictionary:
	# At most three 60 Hz ticks run per rendered frame, so 20 FPS and above stay
	# in real time. A longer stall sheds (and tracks) the excess whole ticks: the
	# race slows for that frame instead of the car jumping many ticks at once.
	# The sub-tick remainder is kept so render interpolation stays continuous.
	var total := maxf(0.0, accumulator) + maxf(0.0, elapsed)
	var whole := int(floor((total + 0.000000001) / DT))
	var steps := mini(MAX_CATCHUP_STEPS, whole)
	return {"steps": steps, "debt": maxf(0.0, total - whole * DT), "dropped": (whole - steps) * DT}


func _process(dt: float) -> void:
	if paused:
		return
	var elapsed := maxf(dt, 0.0)
	if DisplayServer.get_name() != "headless":
		Quality.observe_frame(elapsed, state == "race")
	dt = minf(dt, 0.1)
	# Children process after this node: poll here so steering and pedals reach
	# the simulation in the same frame instead of the next one.
	input.set_driving_enabled(state == "race")
	input.poll(dt)
	_recover_missing_tilt(dt)
	_update_weather(dt)
	match state:
		"intro":
			cam.follow(player, dt)
			if not cam.intro:
				state = "countdown"
				cd_t = 3.2
				cd_n = 4
				if not _seen_tip:
					_seen_tip = true
					var steering_tip := Data.t("race.tip.touch") if Settings.touch_steer else Data.t("race.tip.tilt")
					var gas_tip := Data.t("race.tip.auto_gas") if Settings.auto_accel else Data.t("race.tip.manual_gas")
					hud.feed(Data.t("race.tip", [steering_tip, gas_tip]), UiTheme.AMBER, 5.0)
		"countdown":
			cd_t -= dt
			var n := int(ceil(cd_t))
			if n != cd_n and n >= 1 and n <= 3:
				cd_n = n
				hud.center(str(n), "", 0.9)
				Sfx.play("beep", "UI", -4.0)
			if cd_t <= 0.0:
				race.started = true
				state = "race"
				hud.center(Data.t("race.go"), "", 1.0)
				Sfx.play("go", "UI", -2.0)
				acc = 0.0
				if not Settings.touch_steer and not input.tilt_ok and not input.is_desktop():
					_recover_missing_tilt(1.0)
			_engine_audio(0.12 + (0.25 if input.gas else 0.0), input.gas, true, 0.0, dt)
			cam.follow(player, dt)
		"race", "finish":
			if state == "race":
				input.apply(player)
			var plan := _timing_plan(acc, elapsed)
			acc = float(plan.debt)
			dropped_sim_time += float(plan.dropped)
			for n in int(plan.steps):
				for i in race.cars.size():
					_previous_poses[i] = RenderPose.capture(race.cars[i])
				race.step(DT)
				if state == "finish":
					finish_speed_limit = maxf(6.0, finish_speed_limit - 8.0 * DT)
					player.v = minf(player.v, finish_speed_limit)
			_events()
			input.sync_actions()
			if state == "race" and not last500:
				var left := race.laps * race.L - player.progress
				if player.lap == race.laps - 1 and left > 0.0 and left < 500.0:
					last500 = true
					hud.center(Data.t("race.last_500"), "", 2.0)
					Sfx.play("lap", "UI", -4.0)
			var player_index := race.cars.find(player)
			var player_pose := RenderPose.sample(_previous_poses[player_index], player, acc / DT, track.L)
			if state == "finish":
				cam.follow_finish(player, dt, player_pose)
			else:
				cam.follow(player, dt, player_pose)
			_engine_audio(absf(player.v) / float(player.def.vmax), player.gas_on, player.wreck_t <= 0.0, player.scrape, dt)
			if state == "finish":
				fin_t += dt
				if fin_t > 4.2:
					_show_results()
	for i in cars.size():
		var pose := {}
		if state in ["race", "finish"]:
			pose = RenderPose.sample(_previous_poses[i], race.cars[i], acc / DT, track.L)
		cars[i].apply_state(race.cars[i], track, dt, pose)
	CarVisual.update_headlight_budget(cars, cam.global_position)
	var view_pose := {}
	if state in ["race", "finish"]:
		view_pose = RenderPose.sample(_previous_poses[race.cars.find(player)], player, acc / DT, track.L)
	views.update_pose(player, view_pose, dt)
	speed_feedback.update(player, state == "race", dt)
	sky.follow(cam.global_position)
	if sky.wet > 0.01:
		sky.set_rain_ground(track.pos(player.s, player.d), track.tangent(player.s))
	Sfx.listener_pos = cam.global_position


func _recover_missing_tilt(dt: float) -> void:
	if state != "race" or Settings.touch_steer or input.is_desktop() or input.tilt_ok:
		_tilt_missing_t = 0.0
		return
	# Allow a brief sensor warm-up after resume or changing steering mode.
	_tilt_missing_t += dt
	if _tilt_missing_t >= 1.0:
		Settings.touch_steer = true
		Settings.save()
		_tilt_missing_t = 0.0
		hud.feed(Data.t("race.tilt_missing"), UiTheme.AMBER, 6.0)


func _near_vol(s: float) -> float:
	return clampf(1.0 - absf(track.wrap_s(s - player.s)) / 220.0, 0.0, 1.0)


func _limited(key: String, gap: float) -> bool:
	var t := race.time
	if float(_snd_t.get(key, 0.0)) > t:
		return false
	_snd_t[key] = t + gap
	return true


func _vol_db(v: float) -> float:
	return linear_to_db(clampf(v, 0.001, 1.0))


func _wpos(s: float, d: float, dy := 0.0) -> Vector3:
	var p := track.pos(s, d)
	p.y += dy
	return p


func _events() -> void:
	for e in race.take_events():
		var c: CarState = e.get("car")
		if e.t in ["boom", "zap", "barge", "repair"]:
			var s_pos: float = float(e.get("s", c.s if c != null else 0.0))
			var d_pos: float = float(e.get("d", c.d if c != null else 0.0))
			var kind: String = str(e.get("kind", e.t))
			var color := Color.html(Data.PW[kind].col) if Data.PW.has(kind) else Color(1, 0.5, 0.15)
			effects.boom(_wpos(s_pos, d_pos, 0.7), color, 3.0)
		match e.t:
			"pickup":
				if c == player:
					hud.animate_pickup(str(e.type), int(e.get("slot", player.slots.size() - 1)))
					Sfx.play("pickup", "Pickups", -3.0)
					var replaced := str(e.get("replaced", ""))
					hud.feed((Data.pw_name(replaced) + " → " if not replaced.is_empty() else "+ ") + Data.pw_name(e.type), Color.html(Data.PW[e.type].col), 2.6)
					if not Settings.seen_pw(e.type):
						hud.feed(Data.pw_desc(e.type), Color.html(Data.PW[e.type].col), 4.5)
						Settings.mark_pw(e.type)
				else:
					Sfx.play_at("pickup", _wpos(c.s, c.d, 1.0), "Pickups", -10.0)
			"fire":
				effects.powerup_used(c, str(e.type), bool(e.back))
				var vol := _near_vol(c.s)
				if vol > 0.05:
					var snd: String = {"eagle": "fire_eagle", "bolt": "fire_bolt", "barge": "barge", "mine": "mine_drop",
						"shock": "zap", "nitro": ("impact_soft" if e.back else "nitro"), "shield": "shield", "repair": "repair"}.get(e.type, "fire_bolt")
					Sfx.play_at(snd, _wpos(c.s, c.d, 0.8), "Pickups", _vol_db(vol))
				if c == player:
					Sfx.haptic(25)
			"hit":
				var col := Color.html(Data.PW[e.kind].col) if Data.PW.has(e.kind) else Color.WHITE
				var softened := bool(e.get("recovering", false))
				if not softened or _limited("soft_impact_%d" % c.id, 0.2):
					Sfx.play_at("impact_hard", _wpos(c.s, c.d, 0.8), "Impacts", _vol_db(_near_vol(c.s)) - (5.0 if softened else 0.0))
				if c == player:
					if not softened or _limited("chain_feedback", 0.35):
						hud.flash(Color(1.0, 0.88, 0.23, 1.0) if e.kind == "shock" else Color(0.9, 0.12, 0.12, 1.0), 0.16 if softened else 0.5)
						cam.add_shake(0.12 if softened else (1.2 if e.kind == "eagle" else 0.6))
						Sfx.haptic(15 if softened else 60)
					if not softened or _limited("chain_hit", 0.8):
						hud.feed(Data.t("race.hit_softened") if softened else "%s → %s" % [e.by.name if e.by else "?", player.name], col)
				elif e.by == player:
					var pts := int(Race.FANS.get(e.kind, 0))
					hud.feed("%s → %s  +%d" % [player.name, c.name, pts], col)
					hud.pop("+%d" % pts)
			"blocked":
				Sfx.play_at("shield", _wpos(c.s, c.d, 0.8), "Pickups", _vol_db(_near_vol(c.s) * 0.6))
				if c == player:
					hud.feed(Data.t("race.blocked.shield") if str(e.get("why", "shield")) == "shield" else Data.t("race.blocked.recovery"), Color.html(Data.PW.shield.col))
				elif e.by == player:
					hud.feed(Data.t("race.rival_protected", c.name), Color.html(Data.PW.shield.col))
			"recovery":
				if c == player:
					hud.feed(Data.t("race.recovery"), UiTheme.CYAN, 3.0)
			"discard":
				if c == player:
					hud.feed(Data.t("race.discarded", Data.pw_name(e.type)), UiTheme.MUTED, 2.0)
					Sfx.ui_click()
			"drift_ready":
				if c == player:
					hud.pop(Data.t("race.drift_ready"))
					Sfx.play("pickup", "Pickups", -8.0)
			"drift_boost":
				effects.powerup_used(c, "nitro", false)
				Sfx.play_at("nitro", _wpos(c.s, c.d, 0.8), "Pickups", _vol_db(_near_vol(c.s)))
				if c == player:
					hud.pop(Data.t("race.drift_boost"))
			"wreck":
				Sfx.play_at("wreck", _wpos(c.s, c.d, 0.6), "Impacts", _vol_db(_near_vol(c.s)))
				if c == player:
					hud.center(Data.t("race.wrecked.title"), Data.t("race.wrecked.sub"), 2.2)
					hud.flash(Color(1.0, 0.47, 0.12), 1.0)
					cam.add_shake(1.6)
					Sfx.haptic(120)
				elif e.by == player:
					hud.feed(Data.t("race.wrecked_by_you", [c.name, int(Race.FANS.wreck)]), UiTheme.AMBER)
					hud.pop(Data.t("race.ko", int(Race.FANS.wreck)))
				elif _near_vol(c.s) > 0.6:
					hud.feed(Data.t("race.wrecked_other", c.name), UiTheme.MUTED, 1.8)
			"assist_brake":
				hud.feed(Data.t("race.assist_brake"), UiTheme.CYAN, 3.5)
			"respawn":
				if c == player:
					Sfx.play("respawn", "Pickups", -6.0)
			"wall":
				if c == player and _limited("wall", 0.45):
					Sfx.play("wall_impact", "Impacts", _vol_db(clampf(float(e.imp) / 20.0, 0.3, 1.0)))
					cam.add_shake(minf(0.15, float(e.imp) / 120.0))
					Sfx.haptic(15)
			"bump":
				if (e.a == player or e.b == player) and _limited("bump", 0.22):
					Sfx.play("impact_soft", "Impacts", -3.0)
			"boom":
				var big: bool = e.kind != "bolt"
				Sfx.play_at("boom" if big else "impact_hard", _wpos(float(e.s), float(e.d), 0.5), "Impacts", _vol_db(_near_vol(float(e.s)) * 0.8))
			"zap":
				if _limited("zap", 0.2):
					Sfx.play_at("zap", _wpos(c.s, c.d, 0.8), "Impacts", _vol_db(_near_vol(c.s)))
			"barge":
				if c == player:
					cam.add_shake(0.5)
			"shock":
				if e.target == player:
					hud.center(Data.t("race.storm.title"), Data.t("race.storm.sub"), 1.6)
					hud.feed(Data.t("race.storm.by", c.name), Color.html(Data.PW.shock.col))
				elif c == player:
					hud.feed(Data.t("race.storm.for", e.target.name), Color.html(Data.PW.shock.col))
			"nitro":
				if c == player and not e.back:
					hud.flash(Color(0.22, 1.0, 0.42), 0.5)
			"repair":
				if c == player:
					hud.feed(Data.t("race.repaired"), Color.html(Data.PW.repair.col))
			"denied":
				if c == player:
					_action_denied(str(e.why))
			"cycle":
				if c == player:
					Sfx.ui_click()
			"lap":
				if c == player:
					Sfx.play("lap", "UI", -4.0)
					hud.center(Data.t("race.final_lap") if e.lap == race.laps else Data.t("race.lap", [e.lap, race.laps]), "", 1.6)
			"finish":
				if c == player and state == "race":
					state = "finish"
					input.set_driving_enabled(false)
					input.hide()
					fin_t = 0.0
					finish_speed_limit = maxf(6.0, player.v)
					player.autopilot = true
					cam.cabin = false
					cam.set_cull_mask_value(RaceViews.PLAYER_LAYER, true)
					cars[race.cars.find(player)].show_finish_driver()
					views.cabin_overlay.visible = false
					views.view_button.disabled = true
					Sfx.play("finish", "UI", -2.0)
					hud.flash(Color(1.0, 0.71, 0.28), 0.7)
					hud.finish_place(Data.ordinal(player.place) + "!", Game.fmt_time(player.finish_time))


func _action_denied(reason: String) -> void:
	if paused or state != "race" or not _limited("denied", 0.65):
		return
	Sfx.play("denied", "UI", -9.0)
	hud.feed(CombatFeedback.reason(reason), UiTheme.AMBER, 3.5)


func _engine_audio(ratio: float, gas_on: bool, alive: bool, scrape: float, dt: float) -> void:
	var r := clampf(ratio, 0.0, 1.3)
	if not alive:
		Sfx.set_loop("engine_loop", "Engine", 0.0)
		Sfx.set_loop("engine_idle_loop", "Engine", 0.0)
	else:
		var load := 1.0 if gas_on else 0.55
		Sfx.set_loop("engine_loop", "Engine", clampf(0.15 + r * 0.6, 0.0, 0.8) * load, 0.7 + r * 1.1)
		Sfx.set_loop("engine_idle_loop", "Engine", clampf(0.4 - r * 0.6, 0.0, 0.4), 1.0)
	Sfx.set_loop("wind_loop", "Tyres", clampf(r - 0.35, 0.0, 0.6), 0.8 + r * 0.4)
	var tyre_slip := maxf(player.drift * 0.8, (clampf(r * 0.55, 0.0, 0.55) if player.braking else 0.0)) if player and alive else 0.0
	Sfx.set_loop("screech_loop", "Tyres", clampf(tyre_slip, 0.0, 0.7), 0.9 + r * 0.2)
	Sfx.set_loop("scrape_loop", "Impacts", clampf(scrape * 0.5, 0.0, 0.3), 1.0)
	Sfx.set_loop("rain_loop", "Tyres", 0.35 * sky.wet, 1.0)


func _show_results() -> void:
	state = "results"
	Sfx.stop_loops()
	race.estimate()  # projected finishing times for cars still on track
	var rows := []
	for c in race.order:
		rows.append({
			"name": c.name, "car": c.def.id, "color": c.color.to_html(false), "is_player": c.is_player,
			"finished": c.finished, "time": c.finish_time if c.finished else c.est,
			"best_lap": c.best_lap, "fans": int(c.fans), "wrecks": c.wrecks, "hits": c.hits,
		})
	Game.finish_race({
		"city": city_id, "env": env_id, "place": player.place, "n": race.cars.size(),
		"best_lap": player.best_lap, "time": player.finish_time, "rows": rows,
	})


func _update_weather(dt: float) -> void:
	if Settings.dynamic_weather and state == "race":
		_weather_clock += dt
		if _weather_clock >= 70.0:
			_weather_clock = 0.0
			var cycle := ["dusk", "rain", "night", "golden", "day"]
			sky.transition_to(cycle[_weather_step % cycle.size()], 18.0)
			_weather_step += 1
			hud.feed(Data.t("race.weather_changing", Data.env_label(sky.env_id)), UiTheme.CYAN, 3.0)
	_light_clock += dt
	if _light_clock >= 0.15:
		_light_clock = 0.0
		props.update_lights(track.pos(player.s, player.d), track.tangent(player.s))
	sky.advance(dt)
	race.wet = sky.wet > 0.5
	# Material uniforms and car lamps only need a push while the weather moves.
	var env_now := Vector2(sky.wet, sky.night)
	if env_now != _env_pushed:
		_env_pushed = env_now
		road.set_wet(sky.wet)
		terrain.set_env(sky.wet, 0.0, sky.night)
		buildings.set_env(sky.night, sky.wet)
		props.set_night(sky.night)
		for car in cars:
			car.set_night(sky.night)
