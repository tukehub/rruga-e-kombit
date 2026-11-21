extends Node3D
## Low plaster façades, stone thresholds, balconies and wall lanterns on the
## return through Muradie. The street is widened for the race cars.

const WALLS := [Color("#a84432"), Color("#d6a057"), Color("#547861"), Color("#e6d9bd"), Color("#ce5735")]
const STONE := Color("#d3c5ae")
const SHUTTER := Color("#44312a")
const IRON := Color("#302a29")


func build(track: RaceTrack, start: float, length: float) -> void:
	var count := maxi(1, int(length / 10.0))
	var span := length / count
	var mesh := LandmarkKit.begin()
	var lanterns := LandmarkKit.begin()
	position = track.pos(start, 0.0)
	for side: float in [-1.0, 1.0]:
		for i in count:
			var s := start + (i + 0.5) * span
			var front := -track.normal(s) * side
			var basis := Basis.looking_at(front)
			var at := track.pos(s, side * (track.half_w + 4.8)) - position
			var color: Color = WALLS[(i + (2 if side > 0.0 else 0)) % WALLS.size()]
			var height := 6.6 + 0.7 * (i % 3)
			_facade(mesh, lanterns, at, basis, span - 0.75, height, color)
			if i % 3 == (1 if side > 0.0 else 0):
				_cafe_front(mesh, at, basis, span - 0.75, i)
	add_child(LandmarkKit.mesh_node(mesh, LandmarkKit.material(), "MuradieStreetFronts", 450.0))
	var glass := LandmarkKit.material()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	add_child(LandmarkKit.mesh_node(lanterns, glass, "WallLanterns", 300.0))


func _facade(st: SurfaceTool, lanterns: SurfaceTool, at: Vector3, basis: Basis, width: float, height: float, color: Color) -> void:
	LandmarkKit.box(st, at + basis * Vector3(0, (height - 2.5) * 0.5, 1.35), Vector3(width, height + 2.5, 7.0), color, basis)
	for y in [0.36, 3.25, height - 0.37]:
		LandmarkKit.box(st, at + basis * Vector3(0, y, -2.26), Vector3(width, 0.18, 0.3), STONE, basis)
	LandmarkKit.box(st, at + basis * Vector3(0, height + 0.10, 1.35), Vector3(width + 0.35, 0.31, 7.42), Color("#704439"), basis)
	for x: float in [-width * 0.31, 0.0, width * 0.31]:
		for y: float in [1.64, height - 1.82]:
			var opening := at + basis * Vector3(x, y, -2.2)
			var door := is_zero_approx(x) and y < 2.0
			var h := 2.81 if door else 1.56
			LandmarkKit.box(st, opening, Vector3(1.32, h + 0.19, 0.17), STONE, basis)
			LandmarkKit.box(st, opening + basis * Vector3.FORWARD * 0.11, Vector3(1.05, h, 0.08), SHUTTER, basis)
			LandmarkKit.box(st, opening + basis * Vector3.FORWARD * 0.153, Vector3(0.05, h, 0.027), SHUTTER.lightened(0.16), basis)
	# Steps, shallow balcony and iron railing cast shadows across the plaster.
	for i in 2:
		LandmarkKit.box(st, at + basis * Vector3(0, 0.07 + i * 0.12, -2.66 + i * 0.18), Vector3(1.83, 0.24, 0.96 - i * 0.32), STONE, basis)
	var floor_y := height - 2.7
	LandmarkKit.box(st, at + basis * Vector3(0, floor_y, -2.61), Vector3(2.35, 0.18, 0.92), STONE, basis)
	LandmarkKit.box(st, at + basis * Vector3(0, floor_y + 0.89, -3.05), Vector3(2.35, 0.065, 0.065), IRON, basis)
	for i in 10:
		LandmarkKit.box(st, at + basis * Vector3(-1.08 + i * 0.24, floor_y + 0.42, -3.05), Vector3(0.04, 0.84, 0.04), IRON, basis)
	var lamp := at + basis * Vector3(width * 0.41, 3.97, -2.80)
	LandmarkKit.box(st, lamp + basis * Vector3(0, 0.22, 0.30), Vector3(0.06, 0.06, 0.62), IRON, basis)
	for vertical in [-1.0, 1.0]:
		LandmarkKit.box(st, lamp + Vector3.UP * 0.20 * vertical, Vector3(0.26, 0.07, 0.26), IRON, basis)
	LandmarkKit.box(lanterns, lamp, Vector3(0.17, 0.34, 0.17), Color("#ffdaa0"), basis)
	# The pale sidewalk runs from the façades to the asphalt shoulder.
	LandmarkKit.box(st, at + basis * Vector3(0, -0.13, -3.51), Vector3(width + 0.75, 0.42, 2.60), STONE, basis)


func _cafe_front(st: SurfaceTool, at: Vector3, basis: Basis, width: float, seed: int) -> void:
	# Bougainvillea spills over the storefront and through the balcony rails.
	var vine := Color("#4e6038")
	for i in 26:
		var x := (i / 25.0 - 0.5) * width * 0.92
		var y := 3.58 + 0.25 * sin(i * 0.61 + seed)
		var p := at + basis * Vector3(x, y, -2.58 - 0.18 * sin(i * 0.70))
		LandmarkKit.sphere(st, p, Vector3(0.38, 0.27, 0.31), vine, 4, 6)
		for bloom in 3:
			var offset := Vector3(0.21 * cos(bloom * 2.4 + i), 0.19 * sin(i + bloom * 3.1), -0.15 - bloom * 0.057)
			var blossom := Color("#b3295d").lerp(Color("#e26d91"), 0.5 + 0.5 * sin(i + bloom * 4.2))
			if i < 4:
				blossom = Color("#e7ba52").lerp(Color("#eee0a8"), bloom * 0.3)
			LandmarkKit.sphere(st, p + basis * offset, Vector3(0.24, 0.19, 0.19), blossom, 4, 5)
	for x: float in [-width * 0.30, width * 0.30]:
		var p := at + basis * Vector3(x, 0.08, -3.73)
		LandmarkKit.box(st, p + Vector3.UP * 0.72, Vector3(0.72, 0.085, 0.57), Color("#856248"), basis)
		LandmarkKit.tube(st, p, p + Vector3.UP * 0.73, 0.075, 0.065, IRON, 6)
		for chair: float in [-0.65, 0.65]:
			var seat := p + basis * Vector3(chair, 0.39, 0.11)
			LandmarkKit.box(st, seat, Vector3(0.41, 0.085, 0.43), Color("#935345"), basis)
			LandmarkKit.box(st, seat + basis * Vector3(signf(chair) * 0.20, 0.24, 0), Vector3(0.075, 0.43, 0.42), Color("#a86157"), basis)
			for leg in [Vector3(-0.15, -0.17, -0.16), Vector3(0.15, -0.17, 0.16)]:
				LandmarkKit.box(st, seat + basis * leg, Vector3(0.038, 0.35, 0.038), IRON, basis)
