class_name IndependenceHouse
extends Node3D
## Shtëpia e Pavarësisë (Muzeu Kombëtar i Pavarësisë), Vlorë, after
## photographs: a two-storey pale yellow house under a terracotta hip roof,
## white cornice, floor band and corner pilasters, dark wooden louvred
## shutters, a wooden balcony on two white columns over the door, and
## Albanian flags hung from the openings. It stands on a light gravel square
## with palms, the old well and a bust on a stone pedestal.
## Local frame: the balcony front faces -Z.

const W := 15.0          # facade width
const D := 12.0          # depth
const FLOOR := 4.4
const EAVES := 9.2
const RIDGE := 12.0
const WALL := Color(0.91, 0.80, 0.50)
const TRIM := Color(0.95, 0.94, 0.90)
const WOOD := Color(0.30, 0.18, 0.10)
const ROOF := Color(0.80, 0.42, 0.28)
const BAYS := [-5.4, -2.7, 0.0, 2.7, 5.4]


func _ready() -> void:
	_walls()
	_roof()
	_flags()
	_grounds()


func _walls() -> void:
	var st := LandmarkKit.begin()
	var hw := W * 0.5
	var hd := D * 0.5
	# Plastered walls, sunk a little below ground for uneven terrain.
	LandmarkKit.box(st, Vector3(0, (EAVES - 2.0) * 0.5, 0), Vector3(W, EAVES + 2.0, D), WALL)
	# White trims: plinth, floor band, cornice, corner pilasters.
	LandmarkKit.box(st, Vector3(0, -0.6, 0), Vector3(W + 0.25, 1.8, D + 0.25), TRIM.darkened(0.08))
	LandmarkKit.box(st, Vector3(0, FLOOR, 0), Vector3(W + 0.2, 0.32, D + 0.2), TRIM)
	LandmarkKit.box(st, Vector3(0, EAVES - 0.25, 0), Vector3(W + 0.5, 0.5, D + 0.5), TRIM)
	for x in [-hw, hw]:
		for z in [-hd, hd]:
			LandmarkKit.box(st, Vector3(x, EAVES * 0.5, z), Vector3(0.6, EAVES, 0.6), TRIM)
	# Openings on all four sides: front bays as photographed, plainer sides.
	for face in 4:
		var basis := Basis(Vector3.UP, PI * 0.5 * face)
		# Front and back walls stand D/2 from the centre, the ends W/2.
		var half := hd if face % 2 == 0 else hw
		var bays: Array = BAYS if face % 2 == 0 else [-3.0, 0.0, 3.0]
		for x in bays:
			for level in 2:
				var front := face == 0
				var door: bool = front and level == 0 and (x == 0.0 or x == -2.7)
				var balcony_door: bool = front and level == 1 and x == 0.0
				var y0 := 0.35 if door else (0.9 if level == 0 else FLOOR + (0.35 if balcony_door else 0.8))
				var y1 := FLOOR - 0.75 if level == 0 else EAVES - 1.2
				_opening(st, basis, Vector3(x, 0, -half), y0, y1, door or balcony_door)
	# Balcony on two white columns over the entrance.
	LandmarkKit.box(st, Vector3(0, FLOOR + 0.05, -hd - 0.75), Vector3(4.2, 0.28, 1.5), TRIM)
	for x in [-1.6, 1.6]:
		LandmarkKit.tube(st, Vector3(x, -0.5, -hd - 1.25), Vector3(x, FLOOR - 0.1, -hd - 1.25), 0.22, 0.2, TRIM, 10)
		LandmarkKit.box(st, Vector3(x, FLOOR - 0.15, -hd - 1.25), Vector3(0.6, 0.18, 0.6), TRIM)
	# Wooden balustrade: rails and turned balusters.
	for rail in [[Vector3(0, FLOOR + 1.15, -hd - 1.47), Vector3(4.1, 0.1, 0.1)], [Vector3(0, FLOOR + 0.3, -hd - 1.47), Vector3(4.1, 0.08, 0.08)],
			[Vector3(-2.02, FLOOR + 1.15, -hd - 0.75), Vector3(0.1, 0.1, 1.45)], [Vector3(2.02, FLOOR + 1.15, -hd - 0.75), Vector3(0.1, 0.1, 1.45)]]:
		LandmarkKit.box(st, rail[0], rail[1], WOOD)
	for k in 21:
		LandmarkKit.box(st, Vector3(-2.0 + k * 0.2, FLOOR + 0.72, -hd - 1.47), Vector3(0.07, 0.8, 0.07), WOOD)
	for side in [-1.0, 1.0]:
		for k in 7:
			LandmarkKit.box(st, Vector3(side * 2.02, FLOOR + 0.72, -hd - 0.1 - k * 0.2), Vector3(0.07, 0.8, 0.07), WOOD)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.85), "HouseWalls", 1600.0))


## A window or door with a white surround and closed louvred wooden shutters.
func _opening(st: SurfaceTool, basis: Basis, at: Vector3, y0: float, y1: float, door: bool) -> void:
	var w := 1.3 if door else 1.1
	var face := at.z - 0.02
	var put := func(c: Vector3, size: Vector3, col: Color) -> void:
		LandmarkKit.box(st, basis * c, size, col, basis)
	put.call(Vector3(at.x, (y0 + y1) * 0.5, face), Vector3(w + 0.36, y1 - y0 + 0.3, 0.12), TRIM)
	put.call(Vector3(at.x, (y0 + y1) * 0.5, face - 0.07), Vector3(w, y1 - y0, 0.06), WOOD)
	# Louvres: lighter slats across each leaf, a dark split down the middle.
	var slats := int((y1 - y0) / 0.16)
	for k in slats:
		put.call(Vector3(at.x, y0 + 0.1 + k * 0.16, face - 0.11), Vector3(w - 0.12, 0.05, 0.03), WOOD.lightened(0.18))
	put.call(Vector3(at.x, (y0 + y1) * 0.5, face - 0.12), Vector3(0.05, y1 - y0, 0.04), WOOD.darkened(0.4))
	# Sill
	put.call(Vector3(at.x, y0 - 0.12, face - 0.08), Vector3(w + 0.5, 0.12, 0.3), TRIM)


func _roof() -> void:
	var st := LandmarkKit.begin()
	var ox := W * 0.5 + 0.8
	var oz := D * 0.5 + 0.8
	var ridge := (W - D) * 0.5
	var e := EAVES
	var a := Vector3(-ox, e, -oz)
	var b := Vector3(ox, e, -oz)
	var c := Vector3(ox, e, oz)
	var d := Vector3(-ox, e, oz)
	var r0 := Vector3(-ridge, RIDGE, 0)
	var r1 := Vector3(ridge, RIDGE, 0)
	# Front and back slopes are trapezoids, the ends triangles.
	LandmarkKit.quad(st, b, a, r0, r1, ROOF)
	LandmarkKit.quad(st, d, c, r1, r0, ROOF)
	_tri(st, a, d, r0, ROOF.darkened(0.05))
	_tri(st, c, b, r1, ROOF.darkened(0.05))
	# Soffit under the overhang and a thin white fascia.
	LandmarkKit.quad(st, a, b, c, d, TRIM.darkened(0.2))
	var mat := LandmarkKit.material(0.8)
	mat.albedo_texture = load("res://assets/textures/rooftiles_diff.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(LandmarkKit.mesh_node(st, mat, "HouseRoof", 1600.0))


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal((b - a).cross(c - a).normalized())
	for p in [a, c, b]:
		st.add_vertex(p)


## Flags hung from the openings and the balcony, as on national days.
func _flags() -> void:
	var hd := D * 0.5
	var places := [
		[Vector3(-5.4, 3.6, -hd - 0.2), 3.2],      # ground floor, left window
		[Vector3(-2.7, EAVES - 1.1, -hd - 0.2), 3.4],   # upper left
		[Vector3(-1.0, FLOOR + 1.1, -hd - 1.55), 2.6],   # balcony
		[Vector3(1.0, FLOOR + 1.1, -hd - 1.55), 2.6],
		[Vector3(2.7, EAVES - 1.1, -hd - 0.2), 3.4],    # upper right
		[Vector3(5.4, EAVES - 1.1, -hd - 0.2), 3.4],
	]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = LandmarkKit.albanian_flag()
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for place in places:
		var top: Vector3 = place[0]
		var length: float = place[1]
		var width := length * 0.7 * 0.62
		# Hung by one short edge: the flag's width runs down the wall, so the
		# eagle lies on its side, as on the photographed house.
		var a := top + Vector3(-width * 0.5, 0, -0.02)
		var b := top + Vector3(width * 0.5, 0, -0.02)
		var c := top + Vector3(width * 0.5, -length * 0.55, -0.12)
		var d := top + Vector3(-width * 0.5, -length * 0.55, -0.12)
		st.set_normal(Vector3.BACK)
		for p in [[a, Vector2(0, 0)], [c, Vector2(1, 1)], [b, Vector2(0, 1)], [a, Vector2(0, 0)], [d, Vector2(1, 0)], [c, Vector2(1, 1)]]:
			st.set_uv(p[1])
			st.add_vertex(p[0])
	add_child(LandmarkKit.mesh_node(st, mat, "HouseFlags", 900.0))


func _grounds() -> void:
	var st := LandmarkKit.begin()
	# A light gravel square whose edges slope down into the park, so uneven
	# ground meets it without a step.
	var gravel := Color(0.80, 0.77, 0.69)
	var t0 := [Vector3(-17, 0.04, -20), Vector3(17, 0.04, -20), Vector3(17, 0.04, 12), Vector3(-17, 0.04, 12)]
	var t1 := [Vector3(-21, -3.0, -24), Vector3(21, -3.0, -24), Vector3(21, -3.0, 16), Vector3(-21, -3.0, 16)]
	LandmarkKit.quad_facing(st, t0[0], t0[1], t0[2], t0[3], gravel, Vector3.UP)
	for k in 4:
		var n := (k + 1) % 4
		var out: Vector3 = (t0[k] + t0[n]) * 0.5
		out.y = 0.0
		LandmarkKit.quad_facing(st, t1[k], t1[n], t0[n], t0[k], gravel.darkened(0.05), out)
	# The old well: a round stone curb with an iron arch.
	var well := Vector3(4.8, 0, -hd_front() - 4.5)
	LandmarkKit.tube(st, well, well + Vector3(0, 0.8, 0), 0.9, 0.9, Color(0.82, 0.80, 0.75), 12)
	for side in [-1.0, 1.0]:
		LandmarkKit.tube(st, well + Vector3(side * 0.8, 0.8, 0), well + Vector3(side * 0.6, 2.3, 0), 0.05, 0.05, Color(0.2, 0.2, 0.2), 6)
	LandmarkKit.tube(st, well + Vector3(-0.6, 2.3, 0), well + Vector3(0.6, 2.3, 0), 0.05, 0.05, Color(0.2, 0.2, 0.2), 6)
	# A bust on a pale stone pedestal, front left.
	var bust := Vector3(-7.5, 0, -hd_front() - 6.0)
	LandmarkKit.box(st, bust + Vector3(0, 0.85, 0), Vector3(0.9, 1.7, 0.9), Color(0.85, 0.83, 0.78))
	LandmarkKit.sphere(st, bust + Vector3(0, 2.05, 0), Vector3(0.42, 0.38, 0.3), Color(0.2, 0.19, 0.17))
	LandmarkKit.sphere(st, bust + Vector3(0, 2.6, 0), Vector3(0.2, 0.25, 0.22), Color(0.2, 0.19, 0.17))
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.9), "HouseGrounds", 1400.0))
	# Palms round the square, from the promenade palm meshes.
	var grove := Palms.new()
	add_child(grove)
	grove.build([[-11.0, 0.0, -hd_front() - 3.0, 1.15, 0.4], [-10.0, 0.0, 4.0, 1.05, 2.1],
		[10.5, 0.0, -hd_front() - 2.5, 1.2, 1.3], [11.0, 0.0, 5.0, 1.0, 4.0], [-3.8, 0.0, -hd_front() - 9.0, 1.1, 5.2]])


func hd_front() -> float:
	return D * 0.5
