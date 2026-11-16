extends Node

const Guide = preload("res://scripts/sim/route_guide.gd")
const Signs = preload("res://scripts/world/route_signs.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	var sound_before := Sfx.enabled
	Sfx.enabled = false
	Quality.set_preset("low")
	cluster_checks()
	var guides: Array = []
	for reverse in [false, true]:
		var track := RaceTrack.load_city("tirane", reverse)
		var guide := Guide.new(track)
		check(guide.turns.size() >= 5, "both race directions have a useful corner plan")
		guides.append({"track": track, "guide": guide})
		for turn: Dictionary in guide.turns:
			var apex := float(turn.apex)
			var physical_turn := (track.tangent(apex + 3.0) - track.tangent(apex - 3.0)).dot(track.normal(apex))
			check(physical_turn * int(turn.side) > 0.0, "corner arrow matches the actual driver's right frame")
			check(turn.direction == ("right" if physical_turn > 0.0 else "left"), "direction names match road geometry")
			check(float(turn.angle) >= Guide.MIN_ANGLE and float(turn.span) > 0.0 and int(turn.severity) in [1, 2, 3], "corner plans filter insignificant wiggles")
		var terrain := sampled_terrain("tirane")
		var signs := Signs.new()
		add_child(signs)
		signs.build(track, guide, terrain.height_at)
		check(signs.get_child_count() == 2 and signs.band.mesh != null and signs.posts.multimesh.instance_count > 0, "whole route is one band mesh and one batch of posts")
		check(signs.bands.size() == guide.turns.size(), "every bend has its band")
		for i in signs.bands.size():
			var band: Dictionary = signs.bands[i]
			var turn: Dictionary = band.turn
			var points: Array = band.points
			# Continuous: from before the bend starts to after it ends, without gaps.
			check(float(band.length) >= float(turn.span) + Signs.LEAD * 2.0 - 0.01, "the band runs the whole bend")
			check(absf(track.wrap_s(float(band.from) - (float(turn.start) - Signs.LEAD))) < 0.01, "and starts just before it")
			for k in range(1, points.size()):
				check((points[k] as Vector3).distance_to(points[k - 1]) < 4.0, "the band is smooth, even round the outside of a tight bend")
			check(absf(float(band.d)) > track.half_w + RoadMesh.KERB_W + 1.0 and float(band.d) * int(turn.side) < 0.0, "the band stands outside the barrier on the outside of the bend")
			for k in [0, points.size() / 2, points.size() - 1]:
				var p: Vector3 = points[k]
				var s_at := float(band.from) + float(band.length) * float(k) / float(points.size() - 1)
				var road_point := track.pos(s_at, float(band.d))
				check(absf(p.y - maxf(road_point.y, terrain.height_at(road_point.x, road_point.z))) < 0.001, "the band follows the real ground")
		signs.free()
		terrain.free()
	# Match physical apex locations rather than assuming reverse indices line up.
	for turn: Dictionary in guides[0].guide.turns:
		var point: Vector3 = guides[0].track.pos(float(turn.apex), 0.0)
		var closest := {}
		var best := INF
		for opposite: Dictionary in guides[1].guide.turns:
			var gap := point.distance_to(guides[1].track.pos(float(opposite.apex), 0.0))
			if gap < best:
				best = gap
				closest = opposite
		if best < 20.0:
			check(int(turn.side) == -int(closest.side), "reverse lap flips a physical corner's direction")
	for city in ["tirane", "berat", "gjirokaster", "shkoder", "tetove", "vlore"]:
		ground_checks(city)
	damage_checks()
	await caption_checks()
	Sfx.stop_all()
	Sfx.enabled = sound_before
	print("ROUTE READABILITY: forward/reverse corners, whole-lap shoulders, damage/repair/contact and HUD; failures=", failures)
	get_tree().quit(1 if failures else 0)

func cluster_checks() -> void:
	var track := RaceTrack.load_city("tirane")
	track.K.fill(0.0)
	for i in 15:
		track.K[i] = 0.04
		track.K[track.M - 1 - i] = 0.04
	var guide := Guide.new(track)
	check(guide.turns.size() == 1, "one corner crossing the lap seam produces one cue")
	check(float(guide.next(track.L - 5.0).distance) == 0.0 and float(guide.next(5.0).distance) == 0.0, "seam corner stays active on both sides of start")
	var start := float(guide.turns[0].start)
	var cue := guide.next(start - 40.0)
	check(absf(float(cue.distance) - 40.0) < 0.001 and guide.next(start - 201.0).is_empty(), "lookahead uses forward distance with a finite horizon")
	cue.direction = "changed"
	check(guide.turns[0].direction == "right", "HUD callers cannot mutate the shared plan")
	track.K.fill(0.0)
	track.K[100] = 0.01
	check(Guide.new(track).turns.is_empty(), "a single weak sample doesn't announce a corner")
	for i in range(200, 220): track.K[i] = -0.025
	for i in range(224, 240): track.K[i] = -0.025
	for i in range(241, 260): track.K[i] = 0.025
	guide = Guide.new(track)
	check(guide.turns.size() == 2 and guide.turns[0].direction == "left" and guide.turns[1].direction == "right", "short weak gaps merge while chicanes keep separate directions")

func sampled_terrain(city: String) -> Terrain:
	# Read the same baked lookup data without building thousands of terrain nodes.
	var dir := "res://assets/cities/%s/" % city
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "terrain.json"))
	var terrain := Terrain.new()
	terrain.near = meta.near
	terrain.far = meta.far
	terrain.near_h = FileAccess.get_file_as_bytes(dir + "terrain_near.bin").to_float32_array()
	terrain.far_h = FileAccess.get_file_as_bytes(dir + "terrain_far.bin").to_float32_array()
	return terrain

func ground_checks(city: String) -> void:
	var track := RaceTrack.load_city(city)
	var terrain := sampled_terrain(city)
	var road := RoadMesh.new()
	add_child(road)
	road.build(track, track.half_w, 0.0, terrain.height_at)
	var mesh: ArrayMesh = road.get_node("RoadShoulders").mesh
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_gap := 0.0
	for i in range(0, vertices.size(), 4):
		for j in [1, 2]:
			var v := vertices[i + j]
			max_gap = maxf(max_gap, absf(v.y - terrain.height_at(v.x, v.z) - 0.015))
	check(vertices.size() == track.M * 8 and max_gap < 0.001, "every shoulder edge in %s meets sampled terrain" % city)
	var surface_before := road.surface.mesh.get_instance_id()
	var dry := road.kerb_mat.roughness
	road.set_wet(1.0)
	check(road.kerb_mat.roughness < dry and road.kerb_mat.roughness > 0.6 and road.surface.mesh.get_instance_id() == surface_before, "wet material response is restrained and doesn't rebuild geometry")
	road.set_wet(0.0)
	check(is_equal_approx(road.kerb_mat.roughness, dry), "dry material returns without accumulating tint changes")
	road.free()
	terrain.free()

func damage_checks() -> void:
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 41, "adaptive_pickups": false})
	race.started = true
	var c := race.player
	var visual := CarVisual.new()
	add_child(visual)
	visual.setup(c.def, c.color, true)
	var rival := CarVisual.new()
	add_child(rival)
	rival.setup(c.def, Color.BLUE, false)
	var ids := resources(visual)
	c.health = c.max_hp * 0.25
	visual.apply_state(c, track, 0.0)
	check(is_equal_approx(visual.damage_amount, 0.75) and rival.damage_amount == 0.0, "damage wear is persistent and isolated per car")
	if visual.sport_paint != null:
		check(is_equal_approx(visual.sport_paint.get_shader_parameter("body_damage"), 0.75), "sports paint receives wear without replacing trim or lamp materials")
	for i in 120:
		c.s = float(i) * track.L / 120.0
		c.d = float(i % 3 - 1) * 4.0
		visual.apply_state(c, track, 1.0 / 60.0)
		var ground := track.pos(c.s, c.d) + Vector3.UP * 0.025
		check(visual.contact_shadow.global_position.distance_to(ground) < 0.001 and visual.contact_shadow.visible, "contact patch stays on the road throughout a lap")
		check(is_equal_approx(visual.damage_amount, 0.75), "wear doesn't fade with transient hit feedback")
	c.hop = 1.5
	visual.apply_state(c, track, 0.0)
	check(visual.contact_shadow.transparency == 1.0 and visual.global_position.y > visual.contact_shadow.global_position.y + 1.0, "airborne car contact fades without lifting the patch off the road")
	c.hop = 0.0
	c.slots = [{"type": "repair", "ammo": 1}]
	race.use_item(c, false)
	visual.apply_state(c, track, 0.0)
	check(visual.damage_amount == 0.0, "actual repair consumption restores clean paint")
	c.health = 0.0
	c.wreck_t = 0.01
	visual.apply_state(c, track, 0.0)
	race.physics(c, 0.02)
	visual.apply_state(c, track, 0.0)
	check(visual.damage_amount == 0.0 and c.invuln_t > 0.0, "actual respawn restores clean paint with existing protection")
	check(resources(visual) == ids, "damage/repair/respawn allocate no extra visual resources")
	visual.free()
	rival.free()
	var source := CarVisual._sport_scene
	CarVisual._sport_checked = true
	CarVisual._sport_scene = null
	visual = CarVisual.new()
	add_child(visual)
	visual.setup(c.def, c.color, false)
	var clean := visual.mat_paint.albedo_color
	var roughness := visual.mat_paint.roughness
	c.health = c.max_hp * 0.2
	visual.apply_state(c, track, 0.0)
	check(visual.mat_paint.albedo_color.v < clean.v and visual.mat_paint.roughness > roughness, "public fallback car also expresses damage")
	c.health = c.max_hp
	visual.apply_state(c, track, 0.0)
	check(visual.mat_paint.albedo_color == clean and is_equal_approx(visual.mat_paint.roughness, roughness), "fallback repair returns original paint exactly")
	visual.free()
	CarVisual._sport_scene = source

func caption_checks() -> void:
	var track := RaceTrack.load_city("tirane")
	var guide := Guide.new(track)
	guide.turns = [{"start": 20.0, "span": 25.0, "direction": "right", "severity": 2}]
	var race := Race.new(track, {"laps": 1, "adaptive_pickups": false})
	var hud := Hud.new()
	add_child(hud)
	hud.setup(race, race.player, track, guide)
	await get_tree().process_frame
	hud._process(0.0)
	check(not hud._corner_panel.visible, "no corner prompts before countdown")
	race.started = true
	race.player.v = 30.0
	race.player.progress = track.L - 30.0
	race.player.s = track.L - 30.0
	hud._process(0.0)
	check(hud._corner_caption.text.begins_with("FUND"), "final-lap guidance doesn't advertise a turn beyond the finish")
	race.laps = 2
	hud._process(0.0)
	check(hud._corner_caption.text.begins_with("→") and hud._corner_caption.text.contains("50m"), "same seam turn stays available on earlier laps")
	check(hud._mm_rect.end.y < hud._corner_panel.position.y, "minimap geometry leaves caption space")
	race.player.s = 30.0
	hud._process(0.0)
	check(hud._corner_caption.text.contains("TANI"), "active corner is identified as current")
	race.player.s = 300.0
	hud._process(0.0)
	check(hud._corner_caption.text == "VIJO DREJT", "straight route doesn't invent a distant corner")
	race.player.finished = true
	hud._process(0.0)
	check(not hud._corner_panel.visible, "finished race clears direction prompts")
	hud.queue_free()
	await get_tree().process_frame

func resources(node: Node) -> Dictionary:
	var ids := {node.get_instance_id(): true}
	if node is MeshInstance3D:
		if node.mesh != null: ids[node.mesh.get_instance_id()] = true
		if node.material_override != null: ids[node.material_override.get_instance_id()] = true
	for child in node.get_children(): ids.merge(resources(child))
	return ids
