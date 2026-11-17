class_name ArenaScene
extends Node3D
## Points mode: the walled square, its cars, the camera, sound and UI around
## the Arena simulation. States: countdown -> play -> over -> results.

const DT := 1.0 / 60.0
const GROUND_SHADER := preload("res://shaders/square_ground.gdshader")
const MAX_STEPS := 3
const WALL_HEIGHT := 1.5
const OVER_TIME := 3.2           # seconds between time up and the results
const STATUE_SCALE := 2.4        # the bronze, larger than life on the square
const STATUE_PLINTH := 4.0

var arena: Arena
var player: ArenaCar
var cars: Array[CarVisual] = []
var pads: Array[Sprite3D] = []
var cam: Camera3D
var statue: Node3D
## Weapons on the square, drawn by id: {id: Node3D}.
var weapon_nodes := {}
var _flashes: Array = []         # [{node, t}] short bursts from booms and zaps
var hud: ArenaHud
var input: RaceInput
var pause_ui: Control
var state := "countdown"
var paused := false
var acc := 0.0
var cd_t := 3.2
var cd_n := 4
var over_t := 0.0
var _cam_h := 0.0
var _cam_snap := true
var _kick := Vector2.ZERO
var _kick_v := Vector2.ZERO
var _snd_t := {}


func _ready() -> void:
	_build_world()
	var seed_value := randi() % 100000
	var minutes := float(Game.race_opts.get("points_minutes", 2))
	for a in Game.launch_options():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--minutes="):
			minutes = maxf(0.1, float(a.substr(10)))
	arena = Arena.new({"seed": seed_value, "time": minutes * 60.0, "diff": int(Game.race_opts.diff),
		"driver": int(Game.race_opts.driver), "player_car": str(Game.race_opts.car)})
	player = arena.player
	if "--auto" in Game.launch_options():
		player.autopilot = true
	print("ARENA seed=%d minutes=%.1f diff=%d car=%s driver=%d" % [seed_value, minutes, int(Game.race_opts.diff), str(Game.race_opts.car), int(Game.race_opts.driver)])
	for c in arena.cars:
		var visual := CarVisual.new()
		add_child(visual)
		visual.setup(c.def, (Color.html(c.def.color) if c.is_player else c.color), c.is_player, Game.cosmetics() if c.is_player else {})
		visual.apply_world(c, DT)
		cars.append(visual)
	for p in arena.pickups:
		var sprite := Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.pixel_size = 0.011
		sprite.position = Vector3(float(p.x), 1.5, float(p.z))
		sprite.texture = PowerupIcons.texture(str(p.type))
		add_child(sprite)
		pads.append(sprite)
	cam = Camera3D.new()
	cam.near = 0.3
	cam.far = 900.0
	cam.fov = 66.0
	add_child(cam)
	cam.current = true
	_build_ui()
	_follow_camera(0.0)


# ------------------------------------------------------------------ world
func _build_world() -> void:
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.2, 0.42, 0.78)
	sky_material.sky_horizon_color = Color(0.72, 0.8, 0.88)
	sky_material.ground_horizon_color = Color(0.62, 0.64, 0.66)
	sky_material.ground_bottom_color = Color(0.3, 0.3, 0.32)
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Mostly warm fill, a little of the sky's blue: the stone keeps its colours.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.85, 0.84)
	environment.ambient_light_sky_contribution = 0.3
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = bool(Quality.p.glow)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = float(Quality.p.shadow_dist)
	add_child(sun)
	# The square's paving, with room outside the wall so the horizon is not a cliff.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2((Arena.HALF_X + 60.0) * 2.0, (Arena.HALF_Z + 60.0) * 2.0)
	ground.mesh = plane
	# Rows of stone slabs in mixed colours, as the real square is paved.
	var paving := ShaderMaterial.new()
	paving.shader = GROUND_SHADER
	ground.material_override = paving
	ground.name = "SquarePaving"
	add_child(ground)
	add_child(_wall_mesh())
	# The island in the middle carries the statue.
	var island := MeshInstance3D.new()
	var drum := CylinderMesh.new()
	drum.top_radius = Arena.ISLAND
	drum.bottom_radius = Arena.ISLAND
	drum.height = 1.0
	drum.radial_segments = 48
	island.mesh = drum
	island.position.y = 0.5
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.48, 0.46)
	stone.albedo_texture = load("res://assets/landmarks/plinth_stone.jpg")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(0.17, 0.17, 0.17)
	island.material_override = stone
	add_child(island)
	# Skanderbeg on a tall plinth, well above the cars, the landmark of the square.
	var plinth := MeshInstance3D.new()
	var plinth_box := BoxMesh.new()
	plinth_box.size = Vector3(12.0, STATUE_PLINTH, 8.0)
	plinth.mesh = plinth_box
	plinth.position.y = 1.0 + STATUE_PLINTH * 0.5
	plinth.material_override = stone
	add_child(plinth)
	var statue_scene: PackedScene = load("res://assets/landmarks/skanderbeg_approx.glb")
	if statue_scene != null:
		statue = statue_scene.instantiate() as Node3D
		statue.name = "Skanderbeg"
		statue.position.y = 1.0 + STATUE_PLINTH
		statue.scale = Vector3.ONE * STATUE_SCALE
		add_child(statue)


## The barrier: the rounded rectangle of Arena.wall(), as a striped band.
func _wall_mesh() -> MeshInstance3D:
	var outline := PackedVector2Array()
	var inner := Vector2(Arena.HALF_X - Arena.CORNER, Arena.HALF_Z - Arena.CORNER)
	var corners := [Vector2(inner.x, inner.y), Vector2(-inner.x, inner.y), Vector2(-inner.x, -inner.y), Vector2(inner.x, -inner.y)]
	for k in 4:
		for step in 13:
			var angle := k * PI * 0.5 + step * PI * 0.5 / 12.0
			outline.append(corners[k] + Vector2(cos(angle), sin(angle)) * Arena.CORNER)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := 0.0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var length := a.distance_to(b)
		var normal := Vector3(-(a.x + b.x), 0.0, -(a.y + b.y)).normalized()
		var quad := [Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y), Vector3(b.x, WALL_HEIGHT, b.y), Vector3(a.x, WALL_HEIGHT, a.y)]
		var uvs := [Vector2(run / 6.0, 1.0), Vector2((run + length) / 6.0, 1.0), Vector2((run + length) / 6.0, 0.0), Vector2(run / 6.0, 0.0)]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normal)
			st.set_uv(uvs[index])
			st.add_vertex(quad[index])
		run += length
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_texture = _stripes()
	material.roughness = 0.7
	material.emission_enabled = true
	material.emission = Color(0.9, 0.15, 0.3)
	material.emission_energy_multiplier = 0.25
	mesh.material_override = material
	return mesh


func _stripes() -> ImageTexture:
	var image := Image.create(64, 16, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 16:
			image.set_pixel(x, y, Color(0.92, 0.16, 0.24) if (x + y) % 32 < 16 else Color(0.94, 0.94, 0.94))
	return ImageTexture.create_from_image(image)


# ------------------------------------------------------------------ ui
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var safe := UiTheme.safe_area(layer)
	safe.process_mode = Node.PROCESS_MODE_PAUSABLE
	input = RaceInput.new()
	input.show_boost = false
	safe.add_child(input)
	input.bind(player, arena)
	hud = ArenaHud.new()
	safe.add_child(hud)
	hud.setup(arena, player)
	input.bind_inventory(hud._slots)
	input.inventory_selected.connect(_select_slot)
	input.inventory_hold_changed.connect(hud.inventory_hold)
	hud.slot_selected.connect(_select_slot)
	hud.pause_pressed.connect(toggle_pause)
	pause_ui = Control.new()
	pause_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.theme = UiTheme.theme()
	pause_ui.visible = false
	pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(pause_ui)
	pause_ui.add_child(UiTheme.shade(0.7))
	var box := UiTheme.panel(22)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -200
	box.offset_right = 200
	box.offset_top = -150
	box.offset_bottom = 150
	UiTheme.safe_area(pause_ui).add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(column)
	column.add_child(UiTheme.headline(Data.t("pause.title"), 64))
	var resume := UiTheme.button(Data.t("pause.resume"), UiTheme.CYAN.darkened(0.4))
	resume.pressed.connect(func() -> void: Sfx.ui_click(); toggle_pause())
	column.add_child(resume)
	var quit := UiTheme.button(Data.t("pause.quit"))
	quit.pressed.connect(func() -> void:
		Sfx.ui_back()
		get_tree().paused = false
		Sfx.stop_loops()
		Game.goto("menu"))
	column.add_child(quit)


func _select_slot(index: int) -> void:
	if index > 0 and index < player.slots.size():
		player.ctrl.select = index
	elif index == 0 and player.slots.size() > 1:
		player.ctrl.cycle = true


func toggle_pause() -> void:
	if state in ["over", "results"]:
		return
	paused = not paused
	get_tree().paused = paused
	pause_ui.visible = paused
	input.reset_controls()
	input.visible = not paused
	if paused:
		Sfx.stop_loops()
	else:
		input.resume_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()


func _exit_tree() -> void:
	get_tree().paused = false
	Sfx.stop_loops()


# ------------------------------------------------------------------ frame
## How fast the round runs `since` seconds after the clock ran out.
static func over_time_scale(since: float) -> float:
	return RaceScene.finish_time_scale(since)


func _process(dt: float) -> void:
	if paused:
		return
	var elapsed := clampf(dt, 0.0, 0.1)
	input.set_driving_enabled(state == "play")
	input.poll(elapsed)
	match state:
		"countdown":
			cd_t -= elapsed
			var n := int(ceil(cd_t))
			if n != cd_n and n >= 1 and n <= 3:
				cd_n = n
				hud.center(str(n), Data.t("arena.goal"), 0.9)
				Sfx.play("beep", "UI", -4.0)
			if cd_t <= 0.0:
				arena.started = true
				arena.time = 0.0
				state = "play"
				acc = 0.0
				hud.center(Data.t("race.go"), "", 1.0)
				Sfx.play("go", "UI", -2.0)
		"play", "over":
			if state == "play":
				input.apply(player)
			else:
				over_t += elapsed
				elapsed *= over_time_scale(over_t)
			acc += elapsed
			var steps := 0
			while acc >= DT and steps < MAX_STEPS:
				arena.step(DT)
				acc -= DT
				steps += 1
			acc = minf(acc, DT)
			_events()
			if state == "over" and over_t >= OVER_TIME:
				_show_results()
				return
	for i in cars.size():
		cars[i].apply_world(arena.cars[i], dt)
	for i in pads.size():
		var p: Dictionary = arena.pickups[i]
		pads[i].visible = bool(p.alive)
		pads[i].position.y = 1.5 + 0.18 * sin(arena.time * 2.4 + i)
	_draw_weapons(dt)
	_follow_camera(dt)
	_engine_audio()
	Sfx.listener_pos = cam.global_position


# ------------------------------------------------------------------ weapons
func _draw_weapons(dt: float) -> void:
	var seen := {}
	for p in arena.projs:
		seen[p.id] = true
		var node: Node3D = weapon_nodes.get(p.id)
		if node == null:
			node = _projectile_node(str(p.kind))
			weapon_nodes[p.id] = node
		node.position = Vector3(float(p.x), 1.2, float(p.z))
		var velocity := Vector3(float(p.vx), 0.0, float(p.vz))
		if velocity.length() > 0.1 and not (node is Sprite3D):
			node.look_at(node.position + velocity, Vector3.UP)
	for m in arena.mines:
		seen[m.id] = true
		var node: Node3D = weapon_nodes.get(m.id)
		if node == null:
			node = _ground_node(str(m.kind))
			weapon_nodes[m.id] = node
		var flying := float(m.fly) > 0.0
		node.position = Vector3(float(m.x), 0.06 + (1.5 * sin(PI * float(m.fly) / 0.65) if flying else 0.0), float(m.z))
	for dm in arena.domes:
		seen[dm.id] = true
		var node: Node3D = weapon_nodes.get(dm.id)
		if node == null:
			node = _dome_node(float(dm.r))
			weapon_nodes[dm.id] = node
		node.position = Vector3(float(dm.x), 0.0, float(dm.z))
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		material.albedo_color.a = 0.18 if float(dm.warn) > 0.0 else 0.38 + 0.08 * sin(arena.time * 18.0)
	for id in weapon_nodes.keys():
		if not seen.has(id):
			(weapon_nodes[id] as Node3D).queue_free()
			weapon_nodes.erase(id)
	for i in range(_flashes.size() - 1, -1, -1):
		var flash: Dictionary = _flashes[i]
		flash.t = float(flash.t) + dt
		var node: MeshInstance3D = flash.node
		var k := float(flash.t) / 0.45
		node.scale = Vector3.ONE * (0.6 + k * 3.0) * float(flash.size)
		(node.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0, 0.8 * (1.0 - k))
		if k >= 1.0:
			node.queue_free()
			_flashes.remove_at(i)


func _glow(col: Color, alpha := 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(col, alpha)
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _projectile_node(kind: String) -> Node3D:
	if kind == "eagle":
		var sprite := Sprite3D.new()
		sprite.texture = PowerupIcons.texture("eagle")
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.shaded = false
		sprite.pixel_size = 0.008
		add_child(sprite)
		return sprite
	var dart := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.16 if kind == "bolt" else 0.12
	capsule.height = 1.6 if kind == "bolt" else 1.1
	dart.mesh = capsule
	dart.rotation.x = PI * 0.5
	dart.material_override = _glow(Data.pw_col(kind).lightened(0.3))
	var holder := Node3D.new()
	holder.add_child(dart)
	dart.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	add_child(holder)
	return holder


func _ground_node(kind: String) -> Node3D:
	var node := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	if kind == "oil":
		disc.top_radius = 3.0
		disc.bottom_radius = 3.0
		disc.height = 0.02
		var slick := StandardMaterial3D.new()
		slick.albedo_color = Color(0.05, 0.04, 0.08)
		slick.metallic = 0.6
		slick.roughness = 0.05
		node.material_override = slick
	else:
		disc.top_radius = 0.55
		disc.bottom_radius = 0.7
		disc.height = 0.25
		node.material_override = _glow(Data.pw_col("mine"))
	node.mesh = disc
	add_child(node)
	return node


func _dome_node(radius: float) -> Node3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.is_hemisphere = false
	node.mesh = sphere
	var material := _glow(Data.pw_col("shock"), 0.2)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	add_child(node)
	return node


func _burst(at: Vector3, col: Color, size := 1.0) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	node.mesh = sphere
	node.material_override = _glow(col, 0.8)
	node.position = at
	add_child(node)
	_flashes.append({"node": node, "t": 0.0, "size": size})


func _follow_camera(dt: float) -> void:
	# Behind the car, turning after it a little late; a blow knocks it aside.
	_kick_v += (-_kick * 150.0 - _kick_v * 9.0) * dt
	_kick += _kick_v * dt
	_cam_h = player.h if _cam_snap else lerp_angle(_cam_h, player.h, 1.0 - exp(-dt * 4.5))
	_cam_snap = false
	var forward := Vector3(-sin(_cam_h), 0.0, cos(_cam_h))
	var car := Vector3(player.x, player.hop, player.z)
	var back := 8.6 + (1.4 if player.nitro_t > 0.0 or player.ram_t > 0.0 else 0.0)
	cam.global_position = car - forward * back + Vector3(_kick.x, 3.5, _kick.y)
	cam.look_at(car + forward * 6.0 + Vector3.UP * 1.0, Vector3.UP)
	var want := 66.0 + clampf(absf(player.v) / 40.0, 0.0, 1.0) * 10.0 + (8.0 if player.nitro_t > 0.0 or player.ram_t > 0.0 else 0.0)
	cam.fov = lerpf(cam.fov, want, 1.0 - exp(-dt * 4.0))


func _kick_camera(direction: Vector2, amount: float) -> void:
	_kick_v = (_kick_v + direction.normalized() * amount * 9.0).limit_length(13.0)


func _engine_audio() -> void:
	var alive := player.wreck_t <= 0.0 and state != "over"
	var ratio := clampf(absf(player.v) / (float(player.def.vmax) * Arena.SPEED), 0.0, 1.3)
	if not alive:
		Sfx.set_loop("engine_loop", "Engine", 0.0)
		Sfx.set_loop("engine_idle_loop", "Engine", 0.0)
	else:
		Sfx.set_loop("engine_loop", "Engine", clampf(0.15 + ratio * 0.6, 0.0, 0.8) * (1.0 if player.gas_on else 0.55), 0.7 + ratio * 1.1)
		Sfx.set_loop("engine_idle_loop", "Engine", clampf(0.4 - ratio * 0.6, 0.0, 0.4), 1.0)
	Sfx.set_loop("screech_loop", "Tyres", clampf(player.drift * 0.8, 0.0, 0.7) if alive else 0.0, 0.9 + ratio * 0.2)
	Sfx.set_loop("scrape_loop", "Impacts", clampf(player.scrape * 0.5, 0.0, 0.3), 1.0)


func _limited(key: String, gap: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if float(_snd_t.get(key, -100.0)) + gap > now:
		return false
	_snd_t[key] = now
	return true


func _at(e: Dictionary) -> Vector3:
	return Vector3(float(e.get("x", 0.0)), 0.8, float(e.get("z", 0.0)))


func _events() -> void:
	for e in arena.take_events():
		var c: ArenaCar = e.get("car")
		match str(e.t):
			"score":
				var victim: ArenaCar = e.victim
				Sfx.play_at("impact_hard" if float(e.imp) > 10.0 else "impact_soft", _at(e), "Impacts", -2.0)
				if c == player:
					hud.pop("+%d" % int(e.pts))
					hud.feed(Data.t("arena.hit", [victim.name, int(e.pts)]) + (" ×%d" % int(e.combo) if int(e.combo) > 1 else ""), Data.pw_col("ram") if bool(e.ram) else UiTheme.AMBER)
					_kick_camera(-(e.dir as Vector2), 0.35)
					Sfx.haptic(30)
				elif victim == player:
					hud.flash(UiTheme.RED, 0.3)
					hud.feed(Data.t("arena.hit_by", c.name), UiTheme.RED)
					_kick_camera(e.dir, 0.9 if bool(e.ram) else 0.6)
					Sfx.haptic(60)
			"wreck":
				Sfx.play_at("wreck", _at(e), "Impacts", 0.0)
				var by: ArenaCar = e.by
				if c == player:
					hud.center(Data.t("race.wrecked.title"), Data.t("race.wrecked.sub"), 2.0)
					hud.flash(Color(1.0, 0.47, 0.12), 0.5)
					Sfx.haptic(120)
				elif by == player:
					hud.pop("+%d" % int(e.pts))
					hud.feed(Data.t("arena.wrecked", [c.name, int(e.pts)]), UiTheme.AMBER)
			"pickup":
				if c == player:
					Sfx.play("pickup", "Pickups", -3.0)
					hud.feed("+ " + Data.pw_name(str(e.type)), Data.pw_col(str(e.type)))
				pads[arena.pickups.find(e.p)].visible = false
			"pickup_back":
				pads[arena.pickups.find(e.p)].texture = PowerupIcons.texture(str(e.p.type))
			"fire":
				var sound: String = {"ram": "barge", "nitro": "nitro", "shield": "shield", "repair": "repair", "eagle": "fire_eagle",
					"bolt": "fire_bolt", "cluster": "fire_bolt", "barge": "barge", "mine": "mine_drop", "oil": "mine_drop", "shock": "zap"}.get(str(e.type), "fire_bolt")
				Sfx.play_at(sound, _at(e), "Pickups", -2.0)
				if c == player:
					Sfx.haptic(25)
			"wall":
				if c == player and _limited("wall", 0.4):
					Sfx.play("wall_impact", "Impacts", -4.0)
					_kick_camera(e.dir, minf(0.5, float(e.imp) / 40.0))
					Sfx.haptic(15)
			"bump":
				if (e.a == player or e.b == player) and _limited("bump", 0.2):
					Sfx.play("impact_soft", "Impacts", -6.0)
			"respawn":
				if c == player:
					Sfx.play("respawn", "Pickups", -6.0)
					_cam_snap = true
			"cycle":
				if c == player:
					Sfx.ui_click()
			"hit":
				var by: ArenaCar = e.by
				Sfx.play_at("impact_hard", _at(e), "Impacts", -3.0)
				if c == player:
					hud.flash(UiTheme.RED, 0.3)
					hud.feed(Data.t("arena.weapon_hit_you", [by.name if by != null else "?", Data.pw_name(str(e.kind))]), UiTheme.RED)
					_kick_camera(e.dir, 0.6)
					Sfx.haptic(50)
				elif by == player and int(e.pts) > 0:
					hud.pop("+%d" % int(e.pts))
					hud.feed(Data.t("arena.weapon_hit", [Data.pw_name(str(e.kind)), c.name, int(e.pts)]), Data.pw_col(str(e.kind)))
			"blocked":
				Sfx.play_at("shield", _at(e), "Pickups", -6.0)
				if c == player:
					hud.feed(Data.t("race.blocked.shield"), Data.pw_col("shield"))
			"boom":
				_burst(_at(e), Data.pw_col(str(e.kind)), 1.4 if e.kind in ["eagle", "mine"] else 0.7)
				Sfx.play_at("boom" if e.kind in ["eagle", "mine"] else "impact_hard", _at(e), "Impacts", -4.0)
			"zap":
				_burst(_at(e), Data.pw_col("shock"), 1.0)
				Sfx.play_at("zap", _at(e), "Impacts", -4.0)
			"slip":
				Sfx.play_at("impact_soft", _at(e), "Tyres", -4.0)
			"barge":
				_burst(_at(e), Data.pw_col("barge"), 3.0)
			"shock":
				if e.target == player:
					hud.center(Data.t("race.storm.title"), Data.t("race.storm.sub"), 1.6)
			"denied":
				if c == player:
					Sfx.play("denied", "UI", -8.0)
			"timeup":
				state = "over"
				over_t = 0.0
				input.set_driving_enabled(false)
				input.hide()
				hud.center(Data.t("arena.time_up"), Data.ordinal(player.place) + "!", OVER_TIME)
				Sfx.play("finish", "UI", -2.0)


func _show_results() -> void:
	state = "results"
	Sfx.stop_loops()
	var rows := []
	for c in arena.order:
		rows.append({"name": c.name, "color": c.color.to_html(false), "is_player": c == player, "score": c.score, "hits": c.hits_n, "wrecks": c.kills})
	Game.finish_race({"mode": "points", "city": "tirane", "place": player.place, "n": arena.cars.size(), "score": player.score, "rows": rows})
