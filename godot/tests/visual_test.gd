extends Node3D
## Windowed visual smoke test: build Tirana, place 6 cars on the grid, shoot
## screenshots from several vantage points into user://shots/, then quit.
## Run:  Godot_v4.4.1-stable_win64.exe --path godot res://tests/visual_test.tscn -- env=night

var env_id := "day"
var tag := ""
var cam: Camera3D
var track: RaceTrack
var race: Race
var cars: Array[CarVisual] = []
var sky: SkyEnv
var shots: Array = []
var only_shots: PackedStringArray = []
var cam_near := 0.2
var frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("env="):
			env_id = a.substr(4)
		elif a.begins_with("tag="):
			tag = a.substr(4)
	Quality.set_preset("high")
	Quality.apply_viewport(get_viewport())
	var t0 := Time.get_ticks_msec()
	var city := "tirane"
	var splat: Texture2D = load("res://assets/cities/%s/splat.png" % city)
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.load_city(city, splat)
	print("terrain ", Time.get_ticks_msec() - t0, " ms")
	track = RaceTrack.new()
	var tj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/%s/track.json" % city))
	track.build(tj)
	var road := RoadMesh.new()
	add_child(road)
	road.build(track, float(tj.hw), false)
	print("road ", Time.get_ticks_msec() - t0, " ms")
	var bld := Buildings.new()
	add_child(bld)
	bld.load_city(city)
	print("buildings ", Time.get_ticks_msec() - t0, " ms")
	var props := Props.new()
	add_child(props)
	props.load_city(city, terrain)
	print("props ", Time.get_ticks_msec() - t0, " ms")
	sky = SkyEnv.new()
	add_child(sky)
	sky.apply(env_id)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("gie="):
			sky.env.sdfgi_energy = float(a.substr(4))
			continue
		if a.begins_with("sunind="):
			sky.sun.light_indirect_energy = float(a.substr(7))
			continue
		if a.begins_with("exp="):
			sky.env.tonemap_exposure = float(a.substr(4))
			continue
		if a.begins_with("ang="):
			sky.sun.light_angular_distance = float(a.substr(4))
			continue
		if a.begins_with("near="):
			cam_near = float(a.substr(5))
			continue
		if a.begins_with("op="):
			sky.sun.shadow_opacity = float(a.substr(3))
			continue
		if a.begins_with("shadow="):
			# shadow=<splits 1|2|4>:<max_dist>:<bias>:<normal_bias>:<blend 0|1>
			var f := a.substr(7).split(":")
			var sp := int(f[0])
			sky.sun.directional_shadow_mode = (DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sp >= 4
				else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if sp == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL)
			sky.sun.directional_shadow_max_distance = float(f[1])
			sky.sun.shadow_bias = float(f[2])
			sky.sun.shadow_normal_bias = float(f[3])
			sky.sun.directional_shadow_blend_splits = f[4] == "1"
			continue
		if a.begins_with("shots="):
			only_shots = a.substr(6).split(",")
			continue
		match a:
			"noglow": sky.env.glow_enabled = false
			"nosdfgi": sky.env.sdfgi_enabled = false
			"giocc": sky.env.sdfgi_use_occlusion = true
			"shadowdbg":
				sky.sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sky.sun.directional_shadow_max_distance = 80.0
				sky.sun.directional_shadow_blend_splits = false
				sky.sun.shadow_bias = 0.02
				sky.sun.shadow_normal_bias = 1.0
				sky.sun.shadow_opacity = 1.0
			"ginosky": sky.env.sdfgi_read_sky_light = false
			"ginoground":
				for mi in terrain.find_children("*", "MeshInstance3D", true, false) + road.find_children("*", "MeshInstance3D", true, false):
					(mi as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			"noambient": sky.env.ambient_light_energy = 0.0
			"shadowprobe":
				# reference caster next to the player's grid slot
				var probe := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(1.6, 1.2, 3.5)
				probe.mesh = bm
				probe.material_override = CarVisual._mk_simple(Color(0.9, 0.3, 0.2), 0.0, 0.6)
				probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				probe.position = track.pos(-9.0, -4.0) + track.normal(0.0) * -4.5 - track.tangent(0.0) * 1.5 + Vector3(0, 0.6, 0)
				add_child(probe)
				print("sun: enabled=", sky.sun.shadow_enabled, " mode=", sky.sun.directional_shadow_mode,
					" dist=", sky.sun.directional_shadow_max_distance, " fwd=", -sky.sun.global_transform.basis.z,
					" bias=", sky.sun.shadow_bias, "/", sky.sun.shadow_normal_bias, " opacity=", sky.sun.shadow_opacity)
			"nosun": sky.sun.light_energy = 0.0
			"shadowpole":
				# tall poles -> long, unmistakable ground shadows in track_300 / grid_rear
				for sp in [[300.0, 7.0], [300.0, -7.0], [320.0, 0.0], [-9.0, 0.0], [-30.0, 6.0]]:
					var pole := MeshInstance3D.new()
					var pm := BoxMesh.new()
					pm.size = Vector3(0.5, 8.0, 0.5)
					pole.mesh = pm
					pole.material_override = CarVisual._mk_simple(Color(0.95, 0.2, 0.1), 0.0, 0.6)
					pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
					pole.position = track.pos(sp[0], sp[1]) + Vector3(0, 4.0, 0)
					add_child(pole)
			"plainsun":
				# default-configured DirectionalLight3D replaces the SkyEnv sun
				sky.sun.visible = false
				var dl := DirectionalLight3D.new()
				dl.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
				dl.light_energy = 1.5
				dl.shadow_enabled = true
				add_child(dl)
				var mode := ""
				for b in OS.get_cmdline_user_args():
					if b.begins_with("plain="):
						mode = b.substr(6)
				# copy SkyEnv sun properties group by group to find the one that kills shadows
				if "pos" in mode:
					dl.look_at_from_position((sky.preset.sun_dir as Vector3).normalized() * 100.0, Vector3.ZERO, Vector3.UP)
				if "dir" in mode:
					dl.look_at_from_position(Vector3.ZERO, -(sky.preset.sun_dir as Vector3).normalized(), Vector3.UP)
				if "col" in mode:
					dl.light_color = sky.sun.light_color
					dl.light_energy = sky.sun.light_energy
					dl.light_indirect_energy = sky.sun.light_indirect_energy
				if "ang" in mode:
					dl.light_angular_distance = sky.sun.light_angular_distance
				if "opa" in mode:
					dl.shadow_opacity = sky.sun.shadow_opacity
				if "qual" in mode:
					Quality.apply_sun(dl)
				print("plainsun pos=", dl.global_position, " fwd=", -dl.global_transform.basis.z, " mode=", dl.directional_shadow_mode,
					" dist=", dl.directional_shadow_max_distance, " bias=", dl.shadow_bias, "/", dl.shadow_normal_bias)
			"nofog":
				sky.env.fog_enabled = false
				sky.env.volumetric_fog_enabled = false
			"flatsky":
				sky.env.background_mode = Environment.BG_COLOR
				sky.env.background_color = Color(0.5, 0.6, 0.7)
				sky.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
				sky.env.ambient_light_color = Color(0.6, 0.65, 0.7)
				sky.env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	terrain.set_env(sky.wet, 0.0, sky.night)
	road.set_wet(sky.wet)
	bld.set_env(sky.night, sky.wet)
	props.set_night(sky.night)
	print("sky ", Time.get_ticks_msec() - t0, " ms")
	# race for grid positions
	race = Race.new(track, {"laps": 2, "diff": 1, "seed": 7, "player_car": "benxi", "driver": 0})
	race.started = false  # parked on the grid for inspection
	for c in race.cars:
		var cv := CarVisual.new()
		add_child(cv)
		cv.setup(c.def, (Color.html(c.def.color) if c.is_player else c.color), c.is_player)
		cv.set_night(sky.night)
		cv.apply_state(c, track, 0.016)
		cars.append(cv)
	print("cars ", Time.get_ticks_msec() - t0, " ms")
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = cam_near
	cam.far = 6000.0
	add_child(cam)
	var p0 := track.pos(0.0, 0.0)
	var t := track.tangent(0.0)
	shots = [
		{"name": "grid_rear", "pos": p0 - t * 30.0 + Vector3(0, 5.0, 0), "look": p0 - t * 5.0 + Vector3(0, 1, 0)},
		{"name": "grid_side", "pos": p0 + track.normal(0.0) * -14.0 + Vector3(0, 2.0, 0) - t * 14, "look": p0 - t * 14 + Vector3(0, 0.8, 0)},
		{"name": "car_close", "pos": track.pos(-9.0, -4.0) + Vector3(0, 1.3, 0) + track.normal(0.0) * -5.0 - t * 4.0, "look": track.pos(-9.0, -4.0) + Vector3(0, 0.6, 0)},
		{"name": "car_front", "pos": track.pos(-9.0, -4.0) + Vector3(0, 1.2, 0) + track.normal(0.0) * -3.0 + t * 6.0, "look": track.pos(-9.0, -4.0) + Vector3(0, 0.6, 0)},
		{"name": "track_300", "pos": track.pos(300.0, 0.0) - track.tangent(300.0) * 12.0 + Vector3(0, 4.5, 0), "look": track.pos(300.0, 0.0) + track.tangent(300.0) * 30.0},
		{"name": "track_1500", "pos": track.pos(1500.0, 0.0) - track.tangent(1500.0) * 12.0 + Vector3(0, 4.5, 0), "look": track.pos(1500.0, 0.0) + track.tangent(1500.0) * 30.0},
		{"name": "aerial", "pos": p0 + Vector3(-250, 160, 250), "look": p0 + Vector3(100, 0, -100)},
	]
	if not only_shots.is_empty():
		shots = shots.filter(func(s): return s.name in only_shots)
	print("ready ", Time.get_ticks_msec() - t0, " ms")


func _process(dt: float) -> void:
	frame += 1
	# drive bots a bit so the scene isn't static
	race.step(dt)
	for i in cars.size():
		cars[i].apply_state(race.cars[i], track, dt)
	var si := (frame - 10) / 25
	if frame < 10:
		return
	if si >= shots.size():
		print("frame_ms avg over run: ", Game.frame_ms_avg)
		get_tree().quit()
		return
	var sh: Dictionary = shots[si]
	cam.global_position = sh.pos
	cam.look_at(sh.look, Vector3.UP)
	sky.follow(cam.global_position)
	if (frame - 10) % 25 == 24:
		var img := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://shots")
		var path := "user://shots/%s%s_%s.png" % [env_id, tag, sh.name]
		img.save_png(path)
		print("saved ", ProjectSettings.globalize_path(path), "  ", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, " ms process, ",
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " prims, ",
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " draws")
