extends Node3D
## Muradie's stone mosque and the white balcony house near Flag Square.
## Both models face local -Z.

const STONE := Color("#d8c4a2")
const BRICK := Color("#9a6e50")
const WOOD := Color("#372722")
const PLASTER := Color("#e7e5dc")
const TRIM := Color("#c4ac8a")


func build(landmark_id: String, terrain: Terrain) -> void:
	if landmark_id == "muradie_mosque":
		_mosque()
		_mosque_garden(terrain)
	else:
		_house()
		_house_court(terrain)


func _mosque() -> void:
	var st := LandmarkKit.begin()
	LandmarkKit.box(st, Vector3(0, 3.35, 0), Vector3(12.0, 9.7, 12.0), STONE)
	LandmarkKit.box(st, Vector3(0, 0.32, 0), Vector3(12.7, 0.8, 12.7), STONE.darkened(0.14))
	for course in 23:
		var y := 0.84 + course * 0.32
		var tint := BRICK.lerp(STONE, 0.14 + 0.08 * sin(course * 1.9))
		LandmarkKit.box(st, Vector3(0, y, 0), Vector3(12.04, 0.076, 12.04), tint)
		for side in 4:
			var basis := Basis(Vector3.UP, side * PI / 2.0)
			for j in 7:
				var x := -5.2 + j * 1.62 + 0.27 * (course % 2)
				LandmarkKit.box(st, basis * Vector3(x, y + 0.15, -6.021), Vector3(0.035, 0.23, 0.013), STONE.darkened(0.14), basis)
	for y in [5.85, 7.81, 8.13]:
		LandmarkKit.box(st, Vector3(0, y, 0), Vector3(12.42, 0.18, 12.42), STONE.darkened(0.1))
	LandmarkKit.tube(st, Vector3(0, 8.16, 0), Vector3(0, 9.85, 0), 5.75, 5.54, STONE.darkened(0.11), 12)
	LandmarkKit.tube(st, Vector3(0, 9.82, 0), Vector3(0, 10.03, 0), 5.64, 5.68, STONE.darkened(0.23), 12)
	var minaret := Vector3(-6.45, 0, 3.8)
	for part in [[-0.8, 2.0, 1.43, 1.43], [2.0, 3.1, 1.43, 0.94], [3.1, 17.0, 0.94, 0.78],
			[17.0, 17.8, 0.8, 1.28], [17.8, 18.53, 1.28, 1.28], [18.53, 20.9, 0.69, 0.64]]:
		LandmarkKit.tube(st, minaret + Vector3(0, part[0], 0), minaret + Vector3(0, part[1], 0), part[2], part[3], STONE.darkened(0.12), 12)
	for y in [3.2, 6.5, 10.0, 13.5, 16.7, 18.4, 20.8]:
		var radius := 1.31 if y == 18.4 else (0.98 if y < 17.0 else 0.7)
		LandmarkKit.tube(st, minaret + Vector3(0, y, 0), minaret + Vector3(0, y + 0.07, 0), radius, radius, BRICK, 12)
	LandmarkKit.tube(st, minaret + Vector3(0, 20.9, 0), minaret + Vector3(0, 23.15, 0), 0.77, 0.055, Color("#3e494e"), 12)
	for side in 4:
		var basis := Basis(Vector3.UP, side * PI / 2.0)
		for x in [-3.5, 3.5]:
			_arch(st, basis, x, 0.84, 2.59, 0.74)
			_arch(st, basis, x, 4.22, 5.16, 0.45)
		if side == 0:
			_arch(st, basis, 0, 0.38, 2.8, 0.82)
		_arch(st, basis, 0, 6.12, 6.91, 0.42)
	# Paved threshold and low entrance steps.
	for i in 3:
		LandmarkKit.box(st, Vector3(0, i * 0.115 - 0.11, -7.06 + i * 0.36), Vector3(4.2, 0.27, 1.45), STONE.lightened(0.25))
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "MuradieMasonry", 850.0))
	var roof := LandmarkKit.begin()
	for row in 9:
		for col in 36:
			var a := _dome_point(row, col)
			var b := _dome_point(row, col + 1)
			var c := _dome_point(row + 1, col + 1)
			var d := _dome_point(row + 1, col)
			var tile := Color("#b98a5e").darkened(0.04 + 0.10 * (1.0 + sin(col * 5.5 + row * 3.0)) * 0.5)
			LandmarkKit.quad_facing(roof, a, b, c, d, tile, Vector3(a.x * 0.17, 1.0, a.z * 0.17))
	_add_tiles(roof, "MuradieDome")


func _dome_point(row: int, col: int) -> Vector3:
	var elevation := PI * 0.5 * row / 9.0
	var yaw := TAU * col / 36.0
	var radius := 5.51 * cos(elevation)
	return Vector3(cos(yaw) * radius, 10.03 + 1.87 * sin(elevation), sin(yaw) * radius)


func _arch(st: SurfaceTool, basis: Basis, x: float, bottom: float, spring: float, radius: float) -> void:
	var z := -6.043
	var dark := Color("#302927")
	LandmarkKit.box(st, basis * Vector3(x, (bottom + spring) * 0.5, z), Vector3(radius * 2, spring - bottom, 0.034), dark, basis)
	for sign_x in [-1.0, 1.0]:
		LandmarkKit.box(st, basis * Vector3(x + sign_x * (radius + 0.08), (bottom + spring) * 0.5, z - 0.01), Vector3(0.16, spring - bottom, 0.075), STONE.lightened(0.13), basis)
	for k in 10:
		var a := Vector3(cos(k * PI / 10), sin(k * PI / 10), 0)
		var b := Vector3(cos((k + 1) * PI / 10), sin((k + 1) * PI / 10), 0)
		var at := Vector3(x, spring, z - 0.025)
		var inner_a := basis * (at + a * radius)
		var inner_b := basis * (at + b * radius)
		LandmarkKit.quad_facing(st, basis * at, inner_a, inner_b, inner_b, dark, basis * Vector3.FORWARD)
		LandmarkKit.quad_facing(st, inner_a, inner_b, basis * (at + b * (radius + 0.18)), basis * (at + a * (radius + 0.18)), STONE.lightened(0.2 if k % 2 == 0 else 0.07), basis * Vector3.FORWARD)
	LandmarkKit.box(st, basis * Vector3(x, bottom - 0.05, z - 0.085), Vector3(radius * 2 + 0.42, 0.13, 0.24), STONE.lightened(0.17), basis)
	for bar in [-0.58, 0.0, 0.58]:
		LandmarkKit.box(st, basis * Vector3(x + bar * radius, (bottom + spring) * 0.5, z - 0.045), Vector3(0.037, spring - bottom + radius * 0.6, 0.04), BRICK.darkened(0.37), basis)
	for row in range(1, 4):
		LandmarkKit.box(st, basis * Vector3(x, lerpf(bottom, spring, row / 4.0), z - 0.045), Vector3(radius * 2, 0.034, 0.045), BRICK.darkened(0.37), basis)


func _house() -> void:
	var st := LandmarkKit.begin()
	var half := Vector2(8.7, 7.1)
	LandmarkKit.box(st, Vector3(0, 3.55, 0), Vector3(half.x * 2, 10.5, half.y * 2), PLASTER)
	for y in [0.28, 4.46, 8.49, 8.77]:
		LandmarkKit.box(st, Vector3(0, y, 0), Vector3(half.x * 2 + 0.24, 0.19, half.y * 2 + 0.24), TRIM)
	for side in 4:
		var basis := Basis(Vector3.UP, side * PI / 2)
		var depth := half.y if side % 2 == 0 else half.x
		var bays := range(-3, 4) if side % 2 == 0 else range(-2, 3)
		for bay: int in bays:
			for floor_i in 2:
				var x := bay * 2.36
				var door := bay == 0 and side == 0
				var y := (1.95 if door else 2.66) + floor_i * 3.72
				var h := 3.05 if door else 2.34
				var p := Vector3(x, y, -depth)
				LandmarkKit.box(st, basis * p, Vector3(1.68, h + 0.36, 0.25), TRIM, basis)
				LandmarkKit.box(st, basis * (p + Vector3.FORWARD * 0.137), Vector3(1.25, h, 0.095), WOOD, basis)
				LandmarkKit.box(st, basis * (p + Vector3(0, -h * 0.5, -0.22)), Vector3(1.78, 0.13, 0.31), TRIM.lightened(0.12), basis)
				LandmarkKit.box(st, basis * (p + Vector3.FORWARD * 0.205), Vector3(0.04, h, 0.028), WOOD.lightened(0.15), basis)
	# The reference balcony's pierced panels and squared porch columns.
	var front := -half.y - 2.05
	LandmarkKit.box(st, Vector3(0, 4.42, -half.y - 1), Vector3(7.25, 0.34, 2.25), TRIM)
	LandmarkKit.box(st, Vector3(0, 0.02, -half.y - 1.3), Vector3(7.45, 0.55, 2.8), TRIM)
	for x in [-3.12, 3.12]:
		LandmarkKit.box(st, Vector3(x, 2.16, front + 0.23), Vector3(0.48, 3.95, 0.5), PLASTER)
		for y in [0.48, 4.02]:
			LandmarkKit.box(st, Vector3(x, y, front + 0.23), Vector3(0.79, 0.3, 0.79), TRIM.darkened(0.17))
	for y in [4.68, 5.71]:
		LandmarkKit.box(st, Vector3(0, y, front), Vector3(7.25, 0.17, 0.22), TRIM)
	for i in 13:
		var x := (i - 6) * 0.57
		LandmarkKit.box(st, Vector3(x, 5.20, front), Vector3(0.17, 1.04, 0.17), TRIM)
		LandmarkKit.box(st, Vector3(x, 5.20, front), Vector3(0.45, 0.22, 0.17), TRIM)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "VloraHouseFacade", 850.0))
	var roof := LandmarkKit.begin()
	var a := Vector3(-9.43, 8.89, -7.85)
	var b := Vector3(9.43, 8.89, -7.85)
	var c := Vector3(9.43, 8.89, 7.85)
	var d := Vector3(-9.43, 8.89, 7.85)
	var left := Vector3(-3.0, 11.22, 0)
	var right := Vector3(3.0, 11.22, 0)
	var tile := Color("#a8563f")
	LandmarkKit.quad(roof, b, a, left, right, tile)
	LandmarkKit.quad(roof, d, c, right, left, tile)
	LandmarkKit.quad(roof, a, d, left, left, tile)
	LandmarkKit.quad(roof, c, b, right, right, tile)
	_add_tiles(roof, "VloraHouseTiles")


func _mosque_garden(terrain: Terrain) -> void:
	var paving := LandmarkKit.begin()
	var lawns := LandmarkKit.begin()
	for z in range(-14, 14, 2):
		for x in range(-14, 14, 2):
			if x >= -6 and x < 6 and z >= -6 and z < 6:
				continue
			var is_path := absf(x) < 3.0 or absf(z) < 3.0 or x == -14 or z == -14 or x == 12 or z == 12
			var material := paving if is_path else lawns
			var tint := Color("#d5cec0") if is_path else Color("#5f763e")
			_ground_tile(material, terrain, Vector2(x, z), 2.0, tint.lightened(0.07 * (1.0 + sin(x * 5.1 + z * 3.5))))
	var grass := LandmarkKit.material()
	grass.albedo_texture = preload("res://assets/textures/grass_diff.jpg")
	grass.uv1_triplanar = true
	grass.uv1_scale = Vector3.ONE * 0.24
	add_child(LandmarkKit.mesh_node(lawns, grass, "MuradieLawns", 440.0))
	add_child(LandmarkKit.mesh_node(paving, LandmarkKit.material(), "MuradiePaths", 440.0))


func _house_court(terrain: Terrain) -> void:
	var st := LandmarkKit.begin()
	for x in range(-12, 12, 2):
		for z in range(-14, -6, 2):
			_ground_tile(st, terrain, Vector2(x, z), 2.0, Color("#d0c7b7"))
	for x in range(-11, 12):
		if absi(x) < 2:
			continue
		var base := _ground(terrain, Vector2(x, -13.4)).y
		LandmarkKit.box(st, Vector3(x, base + 0.28, -13.4), Vector3(1.02, 0.57, 0.28), PLASTER)
		LandmarkKit.box(st, Vector3(x, base + 0.84, -13.4), Vector3(0.26, 0.62, 0.26), PLASTER)
		LandmarkKit.box(st, Vector3(x, base + 1.14, -13.4), Vector3(1.02, 0.15, 0.30), PLASTER)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "VloraHouseCourt", 440.0))
	var palms := Palms.new()
	add_child(palms)
	var entries := []
	for x in [-9.9, 9.9]:
		var p := _ground(terrain, Vector2(x, -10.4))
		entries.append([p.x, p.y, p.z, 1.42, x])
	palms.build(entries)


func _ground_tile(st: SurfaceTool, terrain: Terrain, corner: Vector2, size: float, tint: Color) -> void:
	var a := _ground(terrain, corner)
	var b := _ground(terrain, corner + Vector2(size, 0))
	var c := _ground(terrain, corner + Vector2(size, size))
	var d := _ground(terrain, corner + Vector2(0, size))
	LandmarkKit.quad_facing(st, a, b, c, d, tint, Vector3.UP)


func _ground(terrain: Terrain, point: Vector2) -> Vector3:
	var p := Vector3(point.x, 0.07, point.y)
	if terrain != null:
		var world := to_global(p)
		p.y += terrain.height_at(world.x, world.z) - global_position.y
	return p


func _add_tiles(st: SurfaceTool, mesh_name: String) -> void:
	var material := LandmarkKit.material(0.92, 0.0, false)
	material.albedo_texture = preload("res://assets/textures/rooftiles_diff.jpg")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.58
	add_child(LandmarkKit.mesh_node(st, material, mesh_name, 850.0))
