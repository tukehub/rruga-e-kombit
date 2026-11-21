extends Node3D
## The Uji i Ftohtë tunnel follows the race centreline. Its open bore is
## bordered by a rocky headland on the inland side and the bay on the west.

const ARCH_STEPS := 16
const SPRING := 3.5
const RISE := 3.4
const ROCK := Color("#aa9b81")
var _lights: Array[OmniLight3D] = []


func build(track: RaceTrack, portals: Array, reverse: bool, terrain: Terrain) -> void:
	var a: Array = portals[1 if reverse else 0]
	var b: Array = portals[0 if reverse else 1]
	var start := track.locate_xz(a[0], a[1]).x
	var length := track.mod_s(track.locate_xz(b[0], b[1]).x - start)
	var rings := ceili(length / 2.7)
	var inland := 1.0 if reverse else -1.0
	var half := track.half_w + 1.18
	var bore := LandmarkKit.begin()
	var headland := LandmarkKit.begin()
	var lit := LandmarkKit.begin()
	position = track.pos(start, 0.0)
	var previous := PackedVector3Array()
	var previous_outer := PackedVector3Array()
	for i in rings + 1:
		var s := start + length * i / rings
		var centre := track.pos(s, 0.0) - position
		var normal := track.normal(s)
		var inner := PackedVector3Array()
		var outer := PackedVector3Array()
		for j in ARCH_STEPS + 1:
			var angle := PI * float(j) / ARCH_STEPS
			var across := cos(angle)
			var rise := sin(angle)
			var bank := (1.0 + inland * across) * 0.5
			inner.append(centre + normal * (half * across) + Vector3.UP * (SPRING + RISE * rise))
			var spread := lerpf(16.5, 44.0, bank) + 1.1 * sin(j * 2.7 + i * 0.51)
			var top := 8.3 + 12.1 * rise + 4.4 * bank + 1.0 * sin(i * 0.56 + j)
			outer.append(centre + normal * (spread * across) + Vector3.UP * top)
		inner.push_back(centre - normal * half - Vector3.UP * 2.0)
		inner.insert(0, centre + normal * half - Vector3.UP * 2.0)
		for edge in 2:
			var d := (lerpf(16.5, 44.0, float(edge)) + 5.5) * inland * (float(edge) * 2.0 - 1.0)
			var foot := track.pos(s, d)
			foot.y = terrain.height_at(foot.x, foot.z) - 1.0
			if edge == int(inland > 0.0):
				outer.insert(0, foot - position)
			else:
				outer.push_back(foot - position)
		if i > 0:
			for j in inner.size() - 1:
				var toward := centre + Vector3.UP * 1.4 - (inner[j] + inner[j + 1]) * 0.5
				var interior := Color("#414247").lerp(Color("#9a907d"), 0.2 + 0.12 * cos(j * 2.1 + i * 0.67))
				LandmarkKit.quad_facing(bore, previous[j], inner[j], inner[j + 1], previous[j + 1], interior, toward)
				LandmarkKit.quad_facing(headland, previous_outer[j], outer[j], outer[j + 1], previous_outer[j + 1], _rock_tint(i, j), -toward)
		if i == 0 or i == rings:
			var facing := track.tangent(s) * (-1.0 if i == 0 else 1.0)
			for j in inner.size() - 1:
				var rim_a := inner[j].lerp(outer[j], 0.065)
				var rim_b := inner[j + 1].lerp(outer[j + 1], 0.065)
				LandmarkKit.quad_facing(bore, inner[j], rim_a, rim_b, inner[j + 1], Color("#817666"), facing)
				_portal_rock(headland, rim_a, rim_b, outer[j], outer[j + 1], facing, i, j)
		if i > 0 and i < rings and i % 5 == 0:
			var fixture := centre + Vector3.UP * (SPRING + RISE - 0.27)
			LandmarkKit.box(lit, fixture, Vector3(0.78, 0.08, 0.30), Color("#ffda96"), Basis.looking_at(track.tangent(s)))
			var light := OmniLight3D.new()
			light.position = fixture - Vector3.UP * 0.32
			light.omni_range = 10.0
			light.light_color = Color("#ffe0ae")
			light.light_energy = 0.72
			light.visible = false
			add_child(light)
			_lights.append(light)
		previous = inner
		previous_outer = outer
	var rock_mat := LandmarkKit.material()
	rock_mat.albedo_texture = preload("res://assets/textures/rock_diff.jpg")
	rock_mat.uv1_triplanar = true
	rock_mat.uv1_scale = Vector3.ONE * 0.22
	rock_mat.emission_enabled = true
	rock_mat.emission = Color("#8a745b")
	rock_mat.emission_energy_multiplier = 0.17
	add_child(LandmarkKit.mesh_node(headland, rock_mat, "CliffAndPortals", 1100.0))
	var liner := LandmarkKit.material()
	liner.albedo_texture = preload("res://assets/textures/concrete_wall_diff.jpg")
	liner.uv1_triplanar = true
	liner.uv1_scale = Vector3.ONE * 0.25
	add_child(LandmarkKit.mesh_node(bore, liner, "TunnelBore", 620.0))
	_seawall(track, start, length, -inland, terrain)
	var glow := LandmarkKit.material()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_child(LandmarkKit.mesh_node(lit, glow, "TunnelFixtures", 420.0))


func _portal_rock(st: SurfaceTool, rim_a: Vector3, rim_b: Vector3, outer_a: Vector3, outer_b: Vector3, facing: Vector3, ring: int, segment: int) -> void:
	var a := rim_a
	var b := rim_b
	for layer in range(1, 6):
		var t := layer / 5.0
		var ripple := 1.1 * sin(t * PI)
		var next_a := rim_a.lerp(outer_a, t) + facing * (ripple * sin(layer * 2.3 + segment * 1.3))
		var next_b := rim_b.lerp(outer_b, t) + facing * (ripple * sin(layer * 2.3 + (segment + 1) * 1.3))
		var shade := 0.88 + 0.12 * cos(layer * 2.1 + segment * 0.7)
		var tint := _rock_tint(ring + layer, segment).darkened(1.0 - shade)
		LandmarkKit.quad_facing(st, a, next_a, next_b, b, tint, facing)
		a = next_a
		b = next_b


func _seawall(track: RaceTrack, start: float, length: float, coast_side: float, terrain: Terrain) -> void:
	var st := LandmarkKit.begin()
	for approach in [start - 62.0, start + length]:
		for i in 20:
			var s: float = approach + i * 3.1
			var inside := (track.half_w + 0.95) * coast_side
			var outside := (track.half_w + 3.25) * coast_side
			var a := track.pos(s, outside) - position
			var b := track.pos(s + 3.1, outside) - position
			var a_base := a + position
			var b_base := b + position
			a_base.y = terrain.height_at(a_base.x, a_base.z) - 0.48
			b_base.y = terrain.height_at(b_base.x, b_base.z) - 0.48
			var tint := ROCK.lightened(0.13 + 0.04 * cos(i * 2.4))
			LandmarkKit.quad_facing(st, a_base - position, b_base - position, b, a, tint, track.normal(s) * coast_side)
			LandmarkKit.quad_facing(st, a, b, track.pos(s + 3.1, inside) - position, track.pos(s, inside) - position, tint.lightened(0.15), Vector3.UP)
	var mat := LandmarkKit.material()
	mat.albedo_texture = preload("res://assets/textures/concrete_wall_diff.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 0.34
	add_child(LandmarkKit.mesh_node(st, mat, "CoastalRetainingWall", 600.0))


func _process(_dt: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var budget := mini(2, int(Quality.p.fx_light_limit))
	var closest: OmniLight3D
	var second: OmniLight3D
	var closest_distance := 24.0 * 24.0
	var second_distance := closest_distance
	if camera != null and budget > 0:
		for light in _lights:
			var distance := light.global_position.distance_squared_to(camera.global_position)
			if distance < closest_distance:
				second = closest
				second_distance = closest_distance
				closest = light
				closest_distance = distance
			elif distance < second_distance:
				second = light
				second_distance = distance
	for light in _lights:
		light.visible = light == closest or (budget > 1 and light == second)


func _rock_tint(ring: int, segment: int) -> Color:
	var stone := ROCK.lightened((sin(ring * 2.1 + segment * 3.0) + 1.0) * 0.105)
	if segment > 4 and segment < 15:
		stone = stone.lerp(Color("#555b35"), 0.39 + 0.24 * sin(ring * 0.51 + segment * 0.83))
	return stone
