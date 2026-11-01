class_name RaceScene
extends Node3D
## One race: builds the city, runs the simulation at a fixed 60 Hz step,
## drives car visuals, camera, HUD, audio, pause and the finish hand-off.
## States: intro -> countdown -> race -> finish -> results.

const DT := 1.0 / 60.0

var city_id := "tirane"
var env_id := "night"
var track: RaceTrack
var race: Race
var player: CarState
var cars: Array[CarVisual] = []
var sky: SkyEnv
var terrain: Terrain
var road: RoadMesh
var cam: ChaseCam
var hud: Hud
var input: RaceInput
var effects: FxVisual
var buildings: Buildings
var props: Props
var _weather_clock := 0.0
var _weather_step := 0
var _light_clock := 0.0
var pickups: PickupVisual
var pause_ui: Control

var state := "intro"
var acc := 0.0
var cd_t := 0.0
var cd_n := 4
var fin_t := 0.0
var last500 := false
var paused := false
var _snd_t := {}
var _seen_tip := false


func _ready() -> void:
	city_id = str(Game.race_opts.city)
	env_id = Game.city_env(city_id)
	Quality.apply_viewport(get_viewport())
	_build_world()
	_build_race()
	_build_ui()
	get_tree().paused = false
	state = "intro"
	cam.start_intro()
	var city: Dictionary = Data.city(city_id)
	hud.center(city.name, "%s · %d xhiro" % [Data.ENV[env_id].label, race.laps], 2.6)


func _build_world() -> void:
	var splat: Texture2D = load("res://assets/cities/%s/splat.png" % city_id)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.load_city(city_id, splat)
	track = RaceTrack.load_city(city_id)
	var tj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/%s/track.json" % city_id))
	sky = SkyEnv.new()
	add_child(sky)
	sky.apply(env_id)
	road = RoadMesh.new()
	add_child(road)
	road.build(track, float(tj.get("hw", track.half_w)), sky.wet)
	buildings = Buildings.new()
	var side_path := "res://assets/cities/%s/roads.glb" % city_id
	if ResourceLoader.exists(side_path):
		var side_scene: PackedScene = load(side_path)
		add_child(side_scene.instantiate())
	var bld := buildings
	add_child(bld)
	bld.load_city(city_id)
	bld.set_env(sky.night, sky.wet)
	props = Props.new()
	add_child(props)
	props.load_city(city_id, terrain)
	props.set_night(sky.night)
	terrain.set_env(sky.wet, 0.0, sky.night)
	road.set_wet(sky.wet)


func _build_race() -> void:
	var opts := {
		"laps": Game.city_laps(city_id),
		"diff": int(Game.race_opts.diff),
		"seed": int(Time.get_unix_time_from_system()) % 100000,
		"wet": sky.wet,
		"assist": Settings.assist,
		"driver": int(Game.race_opts.driver),
		"player_car": str(Game.race_opts.car),
	}
	race = Race.new(track, opts)
	race.started = false
	player = race.player
	if "--auto" in OS.get_cmdline_user_args():
		player.autopilot = true  # debug: let the AI drive the player car
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--laps="):
			race.laps = maxi(1, int(a.substr(7)))  # debug: short races
	for c in race.cars:
		var cv := CarVisual.new()
		add_child(cv)
		cv.setup(c.def, (Color.html(c.def.color) if c.is_player else c.color), c.is_player)
		cv.set_night(sky.night)
		cv.apply_state(c, track, DT)
		cars.append(cv)
	pickups = PickupVisual.new()
	add_child(pickups)
	pickups.setup(race, track)
	effects = FxVisual.new()
	add_child(effects)
	effects.setup(race, track)
	cam = ChaseCam.new()
	add_child(cam)
	cam.setup(track)
	cam.current = true
	cam.follow(player, 0.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	input = RaceInput.new()
	layer.add_child(input)
	hud = Hud.new()
	layer.add_child(hud)
	hud.setup(race, player, track)
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
	var box := UiTheme.panel(22)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -220
	box.offset_right = 220
	box.offset_top = -170
	box.offset_bottom = 170
	pause_ui.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)
	v.add_child(UiTheme.headline("PAUZË", 64))
	v.add_child(UiTheme.spacer(6))
	var b_resume := UiTheme.button("Vazhdo", UiTheme.CYAN.darkened(0.4))
	b_resume.pressed.connect(func(): Sfx.ui_click(); toggle_pause())
	v.add_child(b_resume)
	var b_restart := UiTheme.button("Rifillo")
	b_restart.pressed.connect(func(): Sfx.ui_click(); get_tree().paused = false; Game.goto("race"))
	v.add_child(b_restart)
	var b_quit := UiTheme.button("Dil")
	b_quit.pressed.connect(func(): Sfx.ui_back(); get_tree().paused = false; Sfx.stop_loops(); Game.goto("menu"))
	v.add_child(b_quit)


func toggle_pause() -> void:
	if state in ["finish", "results"]:
		return
	paused = not paused
	get_tree().paused = paused
	pause_ui.visible = paused
	input.reset_controls()
	input.visible = not paused
	if paused:
		Sfx.stop_loops()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not paused and state in ["race", "countdown"]:
			toggle_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if paused:
		return
	dt = minf(dt, 0.1)
	_update_weather(dt)
	match state:
		"intro":
			cam.follow(player, dt)
			if not cam.intro:
				state = "countdown"
				cd_t = 3.2
				cd_n = 4
				if not Settings.touch_steer and not _seen_tip:
					_seen_tip = true
					hud.feed("Anoje telefonin për të kthyer · djathtas GAZ · majtas FRENA", UiTheme.AMBER, 4.5)
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
				hud.center("Hajde!", "", 1.0)
				Sfx.play("go", "UI", -2.0)
				acc = 0.0
				if not Settings.touch_steer and not input.tilt_ok and not input.is_desktop():
					hud.feed("Animi nuk po lexohet. Cilësimet → Timoni: Prekje", UiTheme.RED, 6.0)
			_engine_audio(0.12 + (0.25 if input.gas else 0.0), input.gas, true, 0.0, dt)
			cam.follow(player, dt)
		"race", "finish":
			if state == "race":
				input.apply(player)
			acc += dt
			var n := 0
			while acc >= DT and n < 5:
				race.step(DT)
				acc -= DT
				n += 1
			if n >= 5:
				acc = 0.0
			_events()
			if state == "race" and not last500:
				var left := race.laps * race.L - player.progress
				if player.lap == race.laps - 1 and left > 0.0 and left < 500.0:
					last500 = true
					hud.center("500 metrat e fundit!", "", 2.0)
					Sfx.play("lap", "UI", -4.0)
			cam.follow(player, dt)
			_engine_audio(absf(player.v) / float(player.def.vmax), player.gas_on, player.wreck_t <= 0.0, player.scrape, dt)
			if state == "finish":
				fin_t += dt
				if fin_t > 4.2:
					_show_results()
	for i in cars.size():
		cars[i].apply_state(race.cars[i], track, dt)
	sky.follow(cam.global_position)
	Sfx.listener_pos = cam.global_position


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
					Sfx.play("pickup", "Pickups", -3.0)
					hud.feed("+ " + Data.PW[e.type].name, Color.html(Data.PW[e.type].col), 1.6)
					if not Settings.seen_pw(e.type):
						hud.feed(Data.PW[e.type].desc, Color.html(Data.PW[e.type].col), 4.5)
						Settings.mark_pw(e.type)
				else:
					Sfx.play_at("pickup", _wpos(c.s, c.d, 1.0), "Pickups", -10.0)
			"fire":
				var vol := _near_vol(c.s)
				if vol > 0.05:
					var snd: String = {"eagle": "fire_eagle", "bolt": "fire_bolt", "barge": "barge", "mine": "mine_drop",
						"shock": "zap", "nitro": ("impact_soft" if e.back else "nitro"), "shield": "shield", "repair": "repair"}.get(e.type, "fire_bolt")
					Sfx.play_at(snd, _wpos(c.s, c.d, 0.8), "Pickups", _vol_db(vol))
				if c == player:
					Sfx.haptic(25)
			"hit":
				var col := Color.html(Data.PW[e.kind].col) if Data.PW.has(e.kind) else Color.WHITE
				Sfx.play_at("impact_hard", _wpos(c.s, c.d, 0.8), "Impacts", _vol_db(_near_vol(c.s)))
				if c == player:
					hud.flash(Color(1.0, 0.88, 0.23, 1.0) if e.kind == "shock" else Color(0.9, 0.12, 0.12, 1.0), 0.8)
					cam.add_shake(1.2 if e.kind == "eagle" else 0.6)
					hud.feed("%s → %s" % [e.by.name if e.by else "?", player.name], col)
					Sfx.haptic(60)
				elif e.by == player:
					var pts := int(Race.FANS.get(e.kind, 0))
					hud.feed("%s → %s  +%d" % [player.name, c.name, pts], col)
					hud.pop("+%d" % pts)
			"blocked":
				Sfx.play_at("shield", _wpos(c.s, c.d, 0.8), "Pickups", _vol_db(_near_vol(c.s) * 0.6))
				if c == player:
					hud.feed("Mburoja e priti!", Color.html(Data.PW.shield.col))
				elif e.by == player:
					hud.feed("%s kishte mburojë" % c.name, Color.html(Data.PW.shield.col))
			"wreck":
				Sfx.play_at("wreck", _wpos(c.s, c.d, 0.6), "Impacts", _vol_db(_near_vol(c.s)))
				if c == player:
					hud.center("U bëre copë!", "Rikthehesh pas dy sekondash", 2.2)
					hud.flash(Color(1.0, 0.47, 0.12), 1.0)
					cam.add_shake(1.6)
					Sfx.haptic(120)
				elif e.by == player:
					hud.feed("%s u bë copë!  +%d" % [c.name, int(Race.FANS.wreck)], UiTheme.AMBER)
					hud.pop("KO +%d" % int(Race.FANS.wreck))
				elif _near_vol(c.s) > 0.6:
					hud.feed("%s u bë copë" % c.name, UiTheme.MUTED, 1.8)
			"respawn":
				if c == player:
					Sfx.play("respawn", "Pickups", -6.0)
			"wall":
				if c == player and _limited("wall", 0.15):
					Sfx.play("impact_soft", "Impacts", _vol_db(clampf(float(e.imp) / 20.0, 0.3, 1.0)))
					cam.add_shake(minf(0.5, float(e.imp) / 40.0))
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
					hud.center("Stuhia!", "Kupola elektrike përpara", 1.6)
					hud.feed("%s lëshoi Stuhinë" % c.name, Color.html(Data.PW.shock.col))
				elif c == player:
					hud.feed("Stuhia për %s" % e.target.name, Color.html(Data.PW.shock.col))
			"nitro":
				if c == player and not e.back:
					hud.flash(Color(0.22, 1.0, 0.42), 0.5)
			"repair":
				if c == player:
					hud.feed("Usta Ramizi e rregulloi", Color.html(Data.PW.repair.col))
			"denied":
				if c == player:
					Sfx.play("denied", "UI", -6.0)
					hud.feed("Je i pari. S’ka kë të godasë Stuhia." if e.why == "first" else "Makina s’ka asnjë gërvishtje. Ende.", UiTheme.MUTED)
			"cycle":
				if c == player:
					Sfx.ui_click()
			"lap":
				if c == player:
					Sfx.play("lap", "UI", -4.0)
					hud.center("Xhiro e fundit!" if e.lap == race.laps else "Xhiro %d/%d" % [e.lap, race.laps], "", 1.6)
			"finish":
				if c == player and state == "race":
					state = "finish"
					fin_t = 0.0
					player.autopilot = true
					Sfx.play("finish", "UI", -2.0)
					hud.flash(Color(1.0, 0.71, 0.28), 0.7)
					hud.center(Data.ORD[clampi(player.place - 1, 0, Data.ORD.size() - 1)] + "!", Game.fmt_time(player.finish_time), 3.6)


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
	Sfx.set_loop("screech_loop", "Tyres", clampf(player.drift * 0.8, 0.0, 0.7) if player else 0.0, 0.9 + r * 0.2)
	Sfx.set_loop("scrape_loop", "Impacts", clampf(scrape, 0.0, 0.6), 1.0)
	Sfx.set_loop("rain_loop", "Tyres", 0.35 * sky.wet, 1.0)


func _show_results() -> void:
	state = "results"
	Sfx.stop_loops()
	var rows := []
	for c in race.order:
		rows.append({
			"name": c.name, "car": c.def.name, "color": c.color.to_html(false), "is_player": c.is_player,
			"finished": c.finished, "time": c.finish_time if c.finished else race.time + c.est,
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
			hud.feed("Moti po ndryshon: " + Data.ENV[sky.env_id].label, UiTheme.CYAN, 3.0)
	_light_clock += dt
	if _light_clock >= 0.15:
		_light_clock = 0.0
		props.update_lights(track.pos(player.s, player.d), track.tangent(player.s))
	sky.advance(dt)
	road.set_wet(sky.wet)
	terrain.set_env(sky.wet, 0.0, sky.night)
	buildings.set_env(sky.night, sky.wet)
	props.set_night(sky.night)
	race.wet = sky.wet > 0.5
	for car in cars:
		car.set_night(sky.night)
