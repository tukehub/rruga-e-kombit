extends Node3D
## Street-facing Vlorë buildings, built in metres with their front along -Z.

const IVORY := Color("#edddc3")
const CORAL := Color("#bb625b")
const DEEP_RED := Color("#9d463a")
const GLASS := Color("#426577")
const TIMBER := Color("#44332c")


func build(id: String) -> void:
	match id:
		"vlore_municipality":
			_municipality()
		"petro_marko":
			_theatre()
		"lungomare_gateway":
			_gateway()
		"skela_corner":
			_skela_frontage()
		"skela_roundabout":
			_roundabout()


func _municipality() -> void:
	var st := LandmarkKit.begin()
	# The projecting three-bay entrance block and lower wings under deep eaves.
	LandmarkKit.box(st, Vector3(0, 7.9, 2), Vector3(46, 18.6, 20), CORAL)
	LandmarkKit.box(st, Vector3(0, 8.5, -8.8), Vector3(15.5, 18.0, 2.1), CORAL.lightened(0.07))
	_roof(st, Vector2(24, 11), 17.42, 2.0, Color("#683c34"), 2)
	for y in [0.2, 4.7, 5.22, 10.9, 15.96, 17.18]:
		LandmarkKit.box(st, Vector3(0, y, 1.9), Vector3(46.5, 0.25, 20.7), IVORY)
		LandmarkKit.box(st, Vector3(0, y, -9.28), Vector3(16.0, 0.26, 1.76), IVORY)
	for x: float in [-21.0, -17.25, -13.5, -9.75, 9.75, 13.5, 17.25, 21.0]:
		_window(st, Vector3(x, 2.45, -8.03), 1.12, 2.15, IVORY, TIMBER)
		_window(st, Vector3(x, 8.0, -8.03), 1.42, 2.55, IVORY, GLASS)
		_window(st, Vector3(x, 13.4, -8.03), 1.3, 2.25, IVORY, GLASS)
		LandmarkKit.box(st, Vector3(x, 9.38, -8.08), Vector3(1.95, 0.21, 0.45), IVORY)
	for side: float in [-1.0, 1.0]:
		var basis := Basis(Vector3.UP, -side * PI * 0.5)
		for x: float in [-5.0, 0.0, 5.0]:
			for y: float in [2.45, 8.0, 13.4]:
				_window(st, basis * Vector3(x, y, -23.02) + Vector3.BACK * 2.0, 1.5, 2.4, IVORY, GLASS, basis)
	for x: float in [-5.05, 0.0, 5.05]:
		_arch(st, Vector3(x, 0.15, -9.88), 1.42, 2.45)
		_window(st, Vector3(x, 8.02, -9.88), 1.8, 3.1, IVORY, GLASS)
		_window(st, Vector3(x, 13.3, -9.88), 1.62, 2.9, IVORY, GLASS)
	for x: float in [-7.42, -2.52, 2.52, 7.42]:
		for y: float in [2.35, 8.0, 13.5]:
			LandmarkKit.box(st, Vector3(x, y, -9.95), Vector3(0.48, 4.13, 0.58), IVORY)
			for end: float in [-2.12, 2.12]:
				LandmarkKit.box(st, Vector3(x, y + end, -9.95), Vector3(0.76, 0.22, 0.72), IVORY)
	for y: float in [0.22, 5.2, 10.94, 16.95]:
		LandmarkKit.box(st, Vector3(0, y, -10.48), Vector3(16.0, 0.27, 1.32), IVORY)
	for x in 36:
		LandmarkKit.box(st, Vector3((x - 17.5) * 0.43, 5.79, -11.04), Vector3(0.14, 0.98, 0.15), IVORY)
	LandmarkKit.box(st, Vector3(0, 6.26, -11.04), Vector3(15.7, 0.12, 0.23), IVORY)
	for step in 3:
		LandmarkKit.box(st, Vector3(0, 0.10 * step, -12.0 + step * 0.36), Vector3(14.4, 0.25, 1.45), IVORY.darkened(0.12))
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "MunicipalityFacade", 950.0))
	_sign(Data.t("sign.vlore_municipality"), Vector3(0, 15.85, -10.12), 0.52, IVORY)
	_flag(Vector3(-13.5, 6.1, -8.43))


func _theatre() -> void:
	var st := LandmarkKit.begin()
	LandmarkKit.box(st, Vector3(0, 5.0, 1.0), Vector3(35.0, 12.2, 23.0), DEEP_RED)
	LandmarkKit.box(st, Vector3(0, 4.6, -10.7), Vector3(26.0, 9.7, 1.8), DEEP_RED.lightened(0.07))
	for y: float in [0.25, 8.42, 9.42, 10.78]:
		LandmarkKit.box(st, Vector3(0, y, -10.64), Vector3(35.4, 0.26, 0.76), IVORY)
	for x: float in [-11.5, -5.75, 0.0, 5.75, 11.5]:
		LandmarkKit.tube(st, Vector3(x, 0.25, -12.15), Vector3(x, 8.45, -12.15), 0.47, 0.40, IVORY, 10)
		for y: float in [0.38, 8.23]:
			LandmarkKit.box(st, Vector3(x, y, -12.15), Vector3(1.23, 0.35, 1.21), IVORY)
	for x: float in [-8.65, -2.9, 2.9, 8.65]:
		_window(st, Vector3(x, 2.35, -11.63), 2.22, 3.98, IVORY, TIMBER)
		_window(st, Vector3(x, 6.37, -11.63), 2.10, 1.72, IVORY, GLASS)
	for x: float in [-14.75, 14.75]:
		_window(st, Vector3(x, 2.64, -10.53), 2.1, 3.6, IVORY, TIMBER)
	LandmarkKit.box(st, Vector3(0, 9.0, -11.87), Vector3(26.0, 1.47, 1.32), IVORY)
	LandmarkKit.box(st, Vector3(0, 9.09, -12.55), Vector3(20.0, 0.93, 0.18), DEEP_RED.darkened(0.10))
	for i in 3:
		LandmarkKit.box(st, Vector3(0, 0.10 * i, -14.05 + i * 0.44), Vector3(26.0, 0.3, 1.55), IVORY.darkened(0.13))
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "PetroMarkoTheatre", 850.0))
	_sign(Data.t("sign.petro_marko"), Vector3(0, 9.08, -12.66), 0.68, Color.WHITE)


func _gateway() -> void:
	var st := LandmarkKit.begin()
	var pale := Color("#d8d5cb")
	var red := Color("#b05e49")
	var base := Vector3(0, 3.0, 0)
	LandmarkKit.box(st, base, Vector3(43, 8.2, 19.6), pale)
	for floor_i in 2:
		for col in 11:
			var x := (col - 5) * 3.72
			_window(st, Vector3(x, 1.9 + 3.6 * floor_i, -9.87), 3.27, 2.83, pale.darkened(0.36), GLASS)
	LandmarkKit.box(st, Vector3(0, 6.98, -9.75), Vector3(43.5, 0.9, 1.08), red)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * 13.9, 7.0, -1.4)
		_apartment(st, at, 14.5, 15.5, 5, pale, red)
		LandmarkKit.box(st, at + Vector3(side * 8.1, 6.45, 2.0), Vector3(5.0, 12.9, 13.7), pale.darkened(0.09))
	for beam in [Vector3(13.7, 2.6, 4.3), Vector3(13.9, 0.57, 4.45)]:
		LandmarkKit.box(st, Vector3(0, 16.8 if beam.y > 1.0 else 15.2, -3.4), beam, GLASS if beam.y > 1.0 else red)
	for x in range(-6, 7, 2):
		LandmarkKit.box(st, Vector3(x, 16.8, -5.57), Vector3(0.16, 2.7, 0.12), pale)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.80), "LungomareTwinWings", 950.0))


func _skela_frontage() -> void:
	var st := LandmarkKit.begin()
	var cream := Color("#e7d6b3")
	for side: float in [-1.0, 1.0]:
		_apartment(st, Vector3(side * 13.0, 2.9, absf(side) * 0.6), 22, 14, 6, cream, cream.darkened(0.20))
	var blue := Color("#476378")
	LandmarkKit.box(st, Vector3(0, 1.43, -0.3), Vector3(47, 3.37, 14.6), blue)
	for x in range(-22, 23, 4):
		_window(st, Vector3(x, 1.56, -7.65), 3.25, 2.45, cream, GLASS)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "SkelaBalconies", 750.0))


func _apartment(st: SurfaceTool, at: Vector3, width: float, depth: float, floors: int, wall: Color, accent: Color) -> void:
	var h := floors * 3.0
	var front := -depth * 0.5
	LandmarkKit.box(st, at + Vector3.UP * (h * 0.5), Vector3(width, h, depth), wall)
	for side: float in [-1.0, 1.0]:
		LandmarkKit.box(st, at + Vector3(side * (width * 0.5 - 0.52), h * 0.5, front - 0.15), Vector3(0.95, h, 0.5), accent)
	for floor_i in floors:
		var y := floor_i * 3.0
		for bay: float in [-0.29, 0.0, 0.29]:
			_window(st, at + Vector3(bay * width, y + 1.48, front - 0.02), width * 0.21, 1.76, wall.darkened(0.10), GLASS)
		LandmarkKit.box(st, at + Vector3(0, y + 0.14, front - 0.68), Vector3(width + 0.34, 0.26, 1.52), wall)
		LandmarkKit.box(st, at + Vector3(0, y + 0.92, front - 1.42), Vector3(width - 0.4, 0.25, 0.12), wall.darkened(0.17))
	LandmarkKit.box(st, at + Vector3(0, h + 0.36, 0.0), Vector3(width + 0.37, 0.74, depth + 0.47), wall)


func _roundabout() -> void:
	const RADIUS := 7.3
	var st := LandmarkKit.begin()
	LandmarkKit.tube(st, Vector3.DOWN * 0.30, Vector3.UP * 0.31, RADIUS, RADIUS, IVORY.darkened(0.22), 48)
	LandmarkKit.tube(st, Vector3.UP * 0.30, Vector3.UP * 0.49, RADIUS - 0.20, RADIUS - 0.51, Color("#697849"), 48)
	for i in 19:
		var angle := i * 2.399963
		var r := 3.95 + 1.85 * (0.5 + 0.5 * sin(i * 3.6))
		var at := Vector3(cos(angle) * r, 0.48, sin(angle) * r)
		LandmarkKit.sphere(st, at, Vector3(0.89, 0.59 + 0.14 * sin(i), 0.88), Color("#3f552e"), 4, 6)
	LandmarkKit.tube(st, Vector3.ZERO, Vector3.UP * 16.3, 0.095, 0.052, Color("#92989d"), 10)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "SkelaPlantedIsland", 620.0))
	var grove := Palms.new()
	add_child(grove)
	var entries := []
	for i in 14:
		var angle := i * 2.399963
		var radius := sqrt((i + 1) / 14.0) * 5.65
		entries.append([cos(angle) * radius, 0.49, sin(angle) * radius, 0.57 + 0.65 * (0.5 + 0.5 * cos(i * 6.0)), angle])
	grove.build(entries)
	_flag(Vector3(0, 15.58, 0), 2.7)


func _window(st: SurfaceTool, at: Vector3, width: float, height: float, trim: Color, fill: Color, basis := Basis.IDENTITY) -> void:
	LandmarkKit.box(st, at, Vector3(width + 0.24, height + 0.24, 0.18), trim, basis)
	LandmarkKit.box(st, at + basis * Vector3.FORWARD * 0.115, Vector3(width, height, 0.075), fill, basis)
	LandmarkKit.box(st, at + basis * Vector3.FORWARD * 0.16, Vector3(0.055, height, 0.025), trim.darkened(0.18), basis)


func _arch(st: SurfaceTool, at: Vector3, radius: float, spring: float) -> void:
	LandmarkKit.box(st, at + Vector3(0, spring * 0.5, 0), Vector3(radius * 2.0, spring, 0.16), TIMBER)
	for side: float in [-1.0, 1.0]:
		LandmarkKit.box(st, at + Vector3(side * (radius + 0.16), spring * 0.5, -0.14), Vector3(0.32, spring, 0.46), IVORY)
	var center := at + Vector3(0, spring, -0.13)
	for i in 12:
		var a := Vector3(cos(i * PI / 12), sin(i * PI / 12), 0)
		var b := Vector3(cos((i + 1) * PI / 12), sin((i + 1) * PI / 12), 0)
		LandmarkKit.quad_facing(st, center, center + a * radius, center + b * radius, center + b * radius, TIMBER, Vector3.FORWARD)
		LandmarkKit.quad_facing(st, center + a * radius, center + a * (radius + 0.30), center + b * (radius + 0.30), center + b * radius, IVORY, Vector3.FORWARD)


func _roof(st: SurfaceTool, half: Vector2, base: float, rise: float, color: Color, offset_z: float) -> void:
	var a := Vector3(-half.x, base, -half.y + offset_z)
	var b := Vector3(half.x, base, -half.y + offset_z)
	var c := Vector3(half.x, base, half.y + offset_z)
	var d := Vector3(-half.x, base, half.y + offset_z)
	var left := Vector3(-half.x * 0.72, base + rise, offset_z)
	var right := Vector3(half.x * 0.72, base + rise, offset_z)
	for pad in [[a,b,right,left], [c,d,left,right], [d,a,left,left], [b,c,right,right]]:
		LandmarkKit.quad_facing(st, pad[0], pad[1], pad[2], pad[3], color, Vector3.UP)


func _sign(message: String, at: Vector3, height: float, tint: Color) -> void:
	var label := Label3D.new()
	label.text = message
	label.position = at
	label.rotation.y = PI
	label.font_size = 64
	label.pixel_size = height / 53.0
	label.modulate = tint
	label.outline_size = 0
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	add_child(label)


func _flag(at: Vector3, width := 1.85) -> void:
	var flag := MeshInstance3D.new()
	var cloth := QuadMesh.new()
	cloth.size = Vector2(width, width * 0.70)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = LandmarkKit.albanian_flag()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	flag.mesh = cloth
	flag.material_override = mat
	flag.position = at + Vector3(width / 2.0, -width * 0.35, 0)
	add_child(flag)
