class_name FlamurtariStadium
extends Node3D
## Stadiumi Flamurtari, Vlorë, after the mapped footprint (OSM way 228375173
## and its four stand outlines) and photographs of the main stand.
## Local frame: origin at the centre spot, +Z along the pitch, the main stand's
## facade faces -X, across its plaza toward Bulevardi Ismail Qemali.
##
## Main facade, measured from a frontal photograph (17 m to the roof band):
## 52 m of red cladding behind grey horizontal louvres, darker below 9.5 m;
## a black roof band; a protruding 30 x 11.3 m glazed centre with white
## horizontal mullions, staggered red bars and three glass double doors;
## FLAMURTARI in red letters with the striped club shield above the glass.
## Floodlight masts at the four corners. Five materials, five draw calls.

const FRONT := -72.0             # facade plane, local x
const HALF := 24.0               # half width of the facade block
## The facade block sits centred on the plaza between the two buildings that
## flank it (OSM 1083265737 north, 1083173083 south), 6 m south of halfway.
const FACADE_Z := 6.0
const TOP := 17.2
const BAND := 15.3               # roof band starts here
const GLASS_HALF := 15.0
const GLASS_TOP := 11.3
const BLACK := Color(0.045, 0.045, 0.05)
const WHITE := Color(0.88, 0.88, 0.86)
const RED := Color(0.72, 0.05, 0.07)
const CONCRETE := Color(0.55, 0.54, 0.51)
const SEAT_RED := Color(0.55, 0.06, 0.07)
const SEAT_BLACK := Color(0.08, 0.08, 0.09)

## Red bars across the glazing: [z from, z to, height], read off the photo.
const BARS := [[-14.6, -7.7, 9.2], [4.5, 13.1, 9.8], [-5.9, 2.8, 8.3], [8.0, 13.1, 7.75],
	[-11.2, -5.9, 7.0], [-2.4, 6.25, 5.75], [9.9, 13.3, 4.5], [-13.1, -9.6, 3.6]]
const DOORS := [-6.9, 0.0, 7.2]
const WINDOWS := [-20.5, -14.6, 15.4, 20.5]


var facade_root: Node3D


func _ready() -> void:
	facade_root = Node3D.new()
	facade_root.name = "MainFacade"
	facade_root.position.z = FACADE_Z
	add_child(facade_root)
	_facade()
	_body()
	_glazing()
	_sign()
	_floodlights()


## The louvred cladding: front and the two returns of the facade block.
func _facade() -> void:
	var st := LandmarkKit.begin()
	var back := FRONT + 12.0
	var low := -4.0  # foundations hide uneven ground
	# Corners from the left end (-z) so the louvre UVs run left to right.
	LandmarkKit.quad_facing(st, Vector3(FRONT, low, -HALF), Vector3(FRONT, low, HALF), Vector3(FRONT, BAND, HALF), Vector3(FRONT, BAND, -HALF), Color.WHITE, Vector3.LEFT)
	LandmarkKit.quad_facing(st, Vector3(FRONT, low, HALF), Vector3(back, low, HALF), Vector3(back, BAND, HALF), Vector3(FRONT, BAND, HALF), Color.WHITE, Vector3.BACK)
	LandmarkKit.quad_facing(st, Vector3(back, low, -HALF), Vector3(FRONT, low, -HALF), Vector3(FRONT, BAND, -HALF), Vector3(back, BAND, -HALF), Color.WHITE, Vector3.FORWARD)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/louvre_facade.gdshader")
	mat.set_shader_parameter("grey_below", 9.5 - low)
	# The UVs start at the foundation, hence the grey line at 9.5 m - low.
	facade_root.add_child(LandmarkKit.mesh_node(st, mat, "StadiumLouvres"))


func _body() -> void:
	var st := LandmarkKit.begin()
	var fst := LandmarkKit.begin()
	# Black roof band over the facade block, wrapping its returns.
	LandmarkKit.box(fst, Vector3(FRONT + 6.0, (BAND + TOP) * 0.5, 0), Vector3(12.6, TOP - BAND, HALF * 2.0 + 0.6), BLACK)
	# The rest of the main stand behind and beside the facade block.
	LandmarkKit.box(st, Vector3(-50.0, 3.5, 0), Vector3(28.0, 15.0, 118.0), CONCRETE.darkened(0.25))
	LandmarkKit.box(st, Vector3(-50.0, 11.4, 0), Vector3(28.4, 0.8, 118.4), BLACK)
	# Main stand seating, raked down to the pitch.
	_rake(st, Vector3(-36.0, 1.2, -56.0), Vector3(-36.0, 1.2, 56.0), Vector3(-1, 0, 0), 22.0, 12.0, 18)
	# East stand and the two ends: open terraces with a concrete back wall.
	_rake(st, Vector3(37.0, 0.8, 52.0), Vector3(37.0, 0.8, -52.0), Vector3(1, 0, 0), 16.0, 8.0, 12)
	LandmarkKit.box(st, Vector3(54.5, 1.5, 0), Vector3(1.2, 11.0, 106.0), CONCRETE)
	_rake(st, Vector3(-33.0, 0.8, -56.0), Vector3(33.0, 0.8, -56.0), Vector3(0, 0, -1), 12.0, 6.0, 9)
	_rake(st, Vector3(33.0, 0.8, 56.0), Vector3(-33.0, 0.8, 56.0), Vector3(0, 0, 1), 12.0, 6.0, 9)
	LandmarkKit.box(st, Vector3(0, 0.5, -68.5), Vector3(68.0, 9.0, 1.0), CONCRETE)
	LandmarkKit.box(st, Vector3(0, 0.5, 68.5), Vector3(68.0, 9.0, 1.0), CONCRETE)
	# Pitch: mown stripes, white lines, a grey apron.
	LandmarkKit.box(st, Vector3(0, -1.0, 0), Vector3(74.0, 2.3, 112.0), Color(0.36, 0.36, 0.34))
	for i in 15:
		var shade := Color(0.20, 0.42, 0.18) if i % 2 == 0 else Color(0.24, 0.48, 0.21)
		LandmarkKit.box(st, Vector3(0, 0.17, -52.5 + 7.0 * (i + 0.5)), Vector3(68.0, 0.05, 7.0), shade)
	for line in [[Vector3(-34, 0.2, 0), Vector3(0.15, 0.03, 105)], [Vector3(34, 0.2, 0), Vector3(0.15, 0.03, 105)],
			[Vector3(0, 0.2, -52.5), Vector3(68, 0.03, 0.15)], [Vector3(0, 0.2, 52.5), Vector3(68, 0.03, 0.15)],
			[Vector3(0, 0.2, 0), Vector3(68, 0.03, 0.15)]]:
		LandmarkKit.box(st, line[0], line[1], WHITE)
	# Glazing frame: header under the sign, jambs, a plinth.
	var gx := FRONT - 1.2
	LandmarkKit.box(fst, Vector3(gx + 0.6, GLASS_TOP + 0.3, 0), Vector3(1.4, 0.7, GLASS_HALF * 2.0 + 0.8), BLACK)
	for z in [-GLASS_HALF - 0.2, GLASS_HALF + 0.2]:
		LandmarkKit.box(fst, Vector3(gx + 0.6, GLASS_TOP * 0.5 - 1.0, z), Vector3(1.4, GLASS_TOP + 2.0, 0.45), BLACK)
	# White horizontal mullions; thin dark vertical ones.
	for y in [1.0, 3.1, 4.75, 6.4, 8.05, 9.7]:
		LandmarkKit.box(fst, Vector3(gx - 0.04, y, 0), Vector3(0.12, 0.13, GLASS_HALF * 2.0), WHITE)
	for k in 12:
		LandmarkKit.box(fst, Vector3(gx - 0.02, GLASS_TOP * 0.5 + 1.5, -GLASS_HALF + 2.5 * (k + 0.5)), Vector3(0.08, GLASS_TOP - 3.0, 0.07), Color(0.18, 0.18, 0.19))
	for bar in BARS:
		LandmarkKit.box(fst, Vector3(gx - 0.1, bar[2], (bar[0] + bar[1]) * 0.5), Vector3(0.14, 0.62, bar[1] - bar[0]), RED)
	# Three double doors with white frames.
	for z in DOORS:
		LandmarkKit.box(fst, Vector3(gx - 0.06, 2.95, z), Vector3(0.14, 0.18, 3.4), WHITE)
		for dz in [-1.65, 0.0, 1.65]:
			LandmarkKit.box(fst, Vector3(gx - 0.06, 1.45, z + dz), Vector3(0.14, 2.9, 0.14), WHITE)
	# Small windows with white blinds in the cladding above.
	for z in WINDOWS:
		LandmarkKit.box(fst, Vector3(FRONT - 0.05, 12.9, z), Vector3(0.1, 1.35, 2.3), Color(0.30, 0.30, 0.31))
		for r in 5:
			LandmarkKit.box(fst, Vector3(FRONT - 0.1, 12.35 + r * 0.27, z), Vector3(0.06, 0.12, 2.05), Color(0.86, 0.86, 0.84))
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.8), "StadiumBody"))
	facade_root.add_child(LandmarkKit.mesh_node(fst, LandmarkKit.material(0.8), "StadiumFacadeTrim"))


## A raked block of seating rows, rising `depth` metres away from the pitch.
func _rake(st: SurfaceTool, from: Vector3, to: Vector3, out: Vector3, depth: float, rise: float, rows: int) -> void:
	for r in rows:
		var t0 := float(r) / rows
		var t1 := float(r + 1) / rows
		var col := SEAT_RED if (r / 2) % 2 == 0 else SEAT_BLACK
		var a := from + out * depth * t0 + Vector3.UP * rise * t0
		var b := to + out * depth * t0 + Vector3.UP * rise * t0
		var c := to + out * depth * t1 + Vector3.UP * rise * t1
		var d := from + out * depth * t1 + Vector3.UP * rise * t1
		# Tread then riser, both facing up/inward.
		var mid := (rise / rows)
		LandmarkKit.quad_facing(st, a + Vector3.UP * mid, b + Vector3.UP * mid, c, d, col, Vector3.UP)
		LandmarkKit.quad_facing(st, a, b, b + Vector3.UP * mid, a + Vector3.UP * mid, col.darkened(0.3), -out)
	# Underside / back so the rake reads as solid from outside.
	var top_a := from + out * depth + Vector3.UP * rise
	var top_b := to + out * depth + Vector3.UP * rise
	LandmarkKit.quad_facing(st, to + out * depth + Vector3.DOWN * 3.0, from + out * depth + Vector3.DOWN * 3.0, top_a, top_b, CONCRETE, out)


func _glazing() -> void:
	var st := LandmarkKit.begin()
	var gx := FRONT - 1.2
	var dark := Color(0.10, 0.11, 0.12)
	LandmarkKit.quad_facing(st, Vector3(gx, -1.0, -GLASS_HALF), Vector3(gx, -1.0, GLASS_HALF), Vector3(gx, GLASS_TOP, GLASS_HALF), Vector3(gx, GLASS_TOP, -GLASS_HALF), dark, Vector3.LEFT)
	# The glazing's two returns, each facing outward.
	LandmarkKit.quad_facing(st, Vector3(FRONT, -1.0, GLASS_HALF), Vector3(gx, -1.0, GLASS_HALF), Vector3(gx, GLASS_TOP, GLASS_HALF), Vector3(FRONT, GLASS_TOP, GLASS_HALF), dark, Vector3.BACK)
	LandmarkKit.quad_facing(st, Vector3(gx, -1.0, -GLASS_HALF), Vector3(FRONT, -1.0, -GLASS_HALF), Vector3(FRONT, GLASS_TOP, -GLASS_HALF), Vector3(gx, GLASS_TOP, -GLASS_HALF), dark, Vector3.FORWARD)
	# Mirror glass: the sky and street show in it as in the photographs.
	var mat := LandmarkKit.material(0.06, 0.9)
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	facade_root.add_child(LandmarkKit.mesh_node(st, mat, "StadiumGlass"))


func _sign() -> void:
	var label := Label3D.new()
	label.name = "StadiumName"
	label.text = Data.t("sign.flamurtari")
	label.font = preload("res://assets/fonts/ChakraPetch-Bold.ttf")
	label.font_size = 160
	label.pixel_size = 0.0185
	label.outline_size = 0
	# Illuminated letters, as on the stand: unlit so they read from the road.
	label.modulate = Color(0.86, 0.08, 0.10)
	label.shaded = false
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	label.position = Vector3(FRONT - 0.2, 12.75, 2.2)
	label.rotation.y = -PI * 0.5
	label.visibility_range_end = 900.0
	facade_root.add_child(label)
	# Club shield beside the name: gold rim, white edge, red and black stripes.
	var st := LandmarkKit.begin()
	var x := FRONT - 0.25
	var cz := -9.6
	var cy := 12.75
	var outline := func(scale: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for k in 13:
			var t := float(k) / 12.0
			# Flat top edge then sides curving to a point at the bottom.
			pts.append(Vector2(lerpf(-0.9, 0.9, t), 1.05) * scale)
		for k in range(1, 12):
			var a := PI * float(k) / 12.0
			pts.append(Vector2(0.9 * cos(a) * (1.0 - 0.15 * sin(a)), -0.1 - 1.0 * sin(a) ** 1.4) * scale)
		return pts
	for layer in [[1.0, Color(0.85, 0.66, 0.20), 0.0], [0.88, WHITE, -0.03]]:
		var poly: PackedVector2Array = outline.call(layer[0])
		var tris := Geometry2D.triangulate_polygon(poly)
		for i in range(0, tris.size(), 3):
			var p := []
			for j in [0, 2, 1]:
				var v: Vector2 = poly[tris[i + j]]
				p.append(Vector3(x + layer[2], cy + v.y, cz - v.x))
			st.set_color(layer[1])
			st.set_normal(Vector3.LEFT)
			for v in p:
				st.add_vertex(v)
	# Stripes clipped to the inner shield.
	var inner: PackedVector2Array = outline.call(0.76)
	for k in 5:
		var strip := PackedVector2Array([Vector2(-0.69 + k * 0.276, 1.2), Vector2(-0.69 + (k + 1) * 0.276, 1.2), Vector2(-0.69 + (k + 1) * 0.276, -1.4), Vector2(-0.69 + k * 0.276, -1.4)])
		for piece in Geometry2D.intersect_polygons(strip, inner):
			var tris := Geometry2D.triangulate_polygon(piece)
			for i in range(0, tris.size(), 3):
				st.set_color(RED if k % 2 == 0 else SEAT_BLACK)
				st.set_normal(Vector3.LEFT)
				for j in [0, 2, 1]:
					var v: Vector2 = piece[tris[i + j]]
					st.add_vertex(Vector3(x - 0.06, cy + v.y, cz - v.x))
	facade_root.add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.5, 0.2, false), "StadiumShield", 900.0))


func _floodlights() -> void:
	var st := LandmarkKit.begin()
	for corner in [Vector2(-44, -58), Vector2(-44, 58), Vector2(44, -58), Vector2(44, 58)]:
		var base := Vector3(corner.x, -2.0, corner.y)
		var top := Vector3(corner.x, 33.0, corner.y)
		LandmarkKit.tube(st, base, top, 0.55, 0.32, Color(0.62, 0.63, 0.64))
		# Lamp panel facing the centre spot, tilted down.
		var to_centre := Vector3(-corner.x, 0, -corner.y).normalized()
		var basis := Basis.looking_at(-to_centre + Vector3(0, -0.45, 0), Vector3.UP)
		LandmarkKit.box(st, top + to_centre * 0.6 + Vector3(0, 2.2, 0), Vector3(5.6, 4.6, 0.4), Color(0.30, 0.31, 0.32), basis)
		for r in 4:
			for c in 5:
				var local := Vector3(-2.2 + c * 1.1, 0.4 + r * 1.05, -0.25)
				LandmarkKit.box(st, top + to_centre * 0.6 + Vector3(0, 0.6, 0) + basis * local, Vector3(0.8, 0.75, 0.12), Color(0.95, 0.95, 0.88), basis)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.5, 0.4), "StadiumFloodlights", 2500.0))
