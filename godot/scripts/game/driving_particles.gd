extends RefCounted
## Fixed GPU emitter pools owned by FxVisual. Continuous effects read the
## rendered car pose and simulation state; they never write to the simulation.

const KINDS := ["smoke", "exhaust", "spray", "scrape"]
const AMOUNTS := {"smoke": 32, "exhaust": 18, "spray": 24, "scrape": 16}
const LIFETIMES := {"smoke": 0.75, "exhaust": 0.22, "spray": 0.4, "scrape": 0.25}
var pools := {}
var allocated := 0

func _init(parent: Node3D, caps: Dictionary, texture: Texture2D) -> void:
	for kind in KINDS:
		pools[kind] = []
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE * (0.5 if kind == "smoke" else (0.18 if kind == "spray" else 0.12))
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if kind in ["exhaust", "scrape"] else BaseMaterial3D.BLEND_MODE_MIX
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = texture
		mesh.material = mat
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0, 0.15, 1)
		process.spread = 30.0
		process.initial_velocity_min = 1.0 if kind == "smoke" else 3.0
		process.initial_velocity_max = 3.0 if kind == "smoke" else 6.0
		process.gravity = Vector3(0, 0.9 if kind == "smoke" else -2.0, 0)
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(0.08, 0.02, 0.06)
		if kind == "exhaust":
			process.emission_box_extents.x = 0.5
		process.scale_min = 0.5
		process.scale_max = 1.5
		var color := Color(0.65, 0.68, 0.72, 0.24)
		match kind:
			"exhaust": color = Color(0.4, 1.4, 3.0, 0.85)
			"spray": color = Color(0.72, 0.83, 0.93, 0.35)
			"scrape": color = Color(3.0, 1.4, 0.25, 1.0)
		var gradient := Gradient.new()
		gradient.set_color(0, Color(color, 0.0))
		gradient.add_point(0.12, color)
		gradient.set_color(1, Color(color, 0.0))
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		process.color_ramp = ramp
		for i in int(caps[kind]):
			var emitter := GPUParticles3D.new()
			emitter.name = kind + str(i)
			emitter.emitting = false
			emitter.visible = false
			emitter.amount = int(AMOUNTS[kind])
			emitter.lifetime = float(LIFETIMES[kind])
			emitter.local_coords = false
			emitter.fixed_fps = 30
			emitter.interpolate = true
			emitter.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 24))
			emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			emitter.process_material = process
			emitter.draw_pass_1 = mesh
			parent.add_child(emitter)
			pools[kind].append({"node": emitter, "key": "", "claimed": false, "tail": 0.0})
			allocated += 1

func reset() -> void:
	for kind in KINDS:
		for slot: Dictionary in pools[kind]:
			var emitter: GPUParticles3D = slot.node
			emitter.emitting = false
			emitter.hide()
			slot.key = ""
			slot.tail = 0.0
			slot.claimed = false

func update(race: Race, visuals: Dictionary, focus: Vector3, dt: float) -> void:
	if int(Quality.p.driving_cars) <= 0 or not race.started or (race.player != null and race.player.finished):
		reset()
		return
	var candidates: Array[CarState] = []
	for c: CarState in race.cars:
		var visual: CarVisual = visuals.get(c)
		if is_instance_valid(visual) and visual.is_visible_in_tree() and c.wreck_t <= 0.0 and not c.finished and visual.global_position.distance_squared_to(focus) < 65.0 * 65.0:
			candidates.append(c)
	candidates.sort_custom(func(a: CarState, b: CarState):
		if a.is_player != b.is_player:
			return a.is_player
		return (visuals[a] as CarVisual).global_position.distance_squared_to(focus) < (visuals[b] as CarVisual).global_position.distance_squared_to(focus))
	for kind in KINDS:
		for slot: Dictionary in pools[kind]:
			slot.claimed = false
		var cars_used := 0
		for c in candidates:
			var grounded := c.hop < 0.15
			var moving := absf(c.v) > 10.0
			var active := false
			match kind:
				"smoke": active = grounded and moving and c.drift > 0.25 and not race.wet
				"exhaust": active = c.nitro_t > 0.0
				"spray": active = grounded and moving and race.wet
				"scrape": active = grounded and moving and c.scrape > 0.1
			if not active:
				continue
			var visual: CarVisual = visuals[c]
			for side in ([-1, 1] if kind in ["smoke", "spray"] else [0]):
				var pose := visual.global_transform
				var local := Vector3(0, 0.3, float(c.def.size.z) * 0.5 + 0.1)
				if side != 0:
					var wheel: Node3D = visual.wheels.get("wheel_rl" if side < 0 else "wheel_rr")
					local = visual.to_local(wheel.global_position) if wheel != null else Vector3(side * float(c.def.size.x) * 0.36, 0.3, float(c.def.size.z) * 0.33)
					local.y -= visual.visual_wheel_radius * 0.8
				elif kind == "scrape":
					local = Vector3(signf(c.d) * float(c.def.size.x) * 0.5, 0.35, 0.0)
				pose.origin = visual.to_global(local)
				_claim(kind, "%d:%d" % [c.id, side], pose)
			cars_used += 1
			if cars_used >= int(Quality.p.driving_cars):
				break
		for slot: Dictionary in pools[kind]:
			var emitter: GPUParticles3D = slot.node
			if not slot.claimed:
				emitter.emitting = false
				slot.tail = maxf(0.0, float(slot.tail) - dt)
				emitter.visible = slot.tail > 0.0

func _claim(kind: String, key: String, pose: Transform3D) -> void:
	var chosen: Dictionary = {}
	for slot: Dictionary in pools[kind]:
		if slot.key == key and not slot.claimed:
			chosen = slot
			break
	if chosen.is_empty():
		for slot: Dictionary in pools[kind]:
			if not slot.claimed:
				chosen = slot
				break
	if chosen.is_empty():
		return
	var emitter: GPUParticles3D = chosen.node
	# Drop stale world-space trails on slot reuse or teleport/respawn.
	var reset_trail: bool = chosen.key != key or emitter.global_position.distance_squared_to(pose.origin) > 20.0 * 20.0
	emitter.global_transform = pose
	if reset_trail:
		emitter.restart()
	emitter.show()
	emitter.emitting = true
	chosen.key = key
	chosen.claimed = true
	chosen.tail = emitter.lifetime

func snapshot() -> Dictionary:
	var counts := {}
	for kind in KINDS:
		counts[kind] = 0
		for slot: Dictionary in pools[kind]:
			if (slot.node as GPUParticles3D).emitting:
				counts[kind] += 1
	return counts
