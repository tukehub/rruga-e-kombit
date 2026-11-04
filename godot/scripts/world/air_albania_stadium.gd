class_name AirAlbaniaStadium
extends Node3D
## Low-draw-call architectural approximation of Tirana's national stadium.
## The red-and-black octagonal shell and 112 m corner tower follow the visible
## design; dimensions/position use the OpenStreetMap footprint. No brand signs.

const RED := Color(0.55, 0.045, 0.055)
const CHARCOAL := Color(0.055, 0.065, 0.070)
const GLASS := Color(0.19, 0.25, 0.28)
const ROOF := Color(0.23, 0.25, 0.26)
const CONCRETE := Color(0.51, 0.50, 0.47)
const GRASS := Color(0.17, 0.30, 0.16)


func _ready() -> void:
	_build()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col)
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Chamfered oval-shaped octagonal envelope, ~160 x 200 m and 32 m high.
	var outer := [Vector2(-53, -99), Vector2(53, -99), Vector2(80, -70), Vector2(80, 70), Vector2(53, 99), Vector2(-53, 99), Vector2(-80, 70), Vector2(-80, -70)]
	var inner := [Vector2(-36, -72), Vector2(36, -72), Vector2(57, -51), Vector2(57, 51), Vector2(36, 72), Vector2(-36, 72), Vector2(-57, 51), Vector2(-57, -51)]
	for side in 8:
		var a: Vector2 = outer[side]
		var b: Vector2 = outer[(side + 1) % 8]
		var next_inner: Vector2 = inner[(side + 1) % 8]
		var ia: Vector2 = inner[side]
		var count := ceili(a.distance_to(b) / 4.2)
		for i in count:
			var p := a.lerp(b, float(i) / count)
			var q := a.lerp(b, float(i + 1) / count)
			for row in 4:
				var shade := (side * 31 + i * 11 + row * 17) % 19
				var colour := RED if shade < 8 else (GLASS if shade < 12 else CHARCOAL)
				var y0 := float(row) * 8.0 - 2.0
				var y1 := y0 + 7.85
				_quad(st, Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(q.x, y1, q.y), Vector3(p.x, y1, p.y), colour)
		# Continuous dark roof ring around the open football ground.
		_quad(st, Vector3(a.x, 30, a.y), Vector3(b.x, 30, b.y), Vector3(next_inner.x, 30, next_inner.y), Vector3(ia.x, 30, ia.y), ROOF)
		# Simple inner grandstand slopes, visible from high angles.
		var seat_col := RED.darkened(0.24) if side % 2 == 0 else CONCRETE.darkened(0.20)
		_quad(st, Vector3(ia.x, 30, ia.y), Vector3(next_inner.x, 30, next_inner.y), Vector3(next_inner.x * 0.72, 3, next_inner.y * 0.72), Vector3(ia.x * 0.72, 3, ia.y * 0.72), seat_col)
	_quad(st, Vector3(-32, 2.0, -53), Vector3(32, 2.0, -53), Vector3(32, 2.0, 53), Vector3(-32, 2.0, 53), GRASS)
	# Integrated 112 m corner tower. Batched rectangular panels distinguish the
	# real facade without hundreds of Nodes or alpha-blended glass on phones.
	var center := Vector2(-58, -58)
	var half := 14.0
	var corners := [center + Vector2(-half, -half), center + Vector2(half, -half), center + Vector2(half, half), center + Vector2(-half, half)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		for row in 28:
			for col in 7:
				var p := a.lerp(b, float(col) / 7.0)
				var q := a.lerp(b, float(col + 1) / 7.0)
				var seed := (row * 13 + col * 19 + side * 23 + floori(float(row) / 4.0) * 3) % 23
				var colour := RED if seed < 10 else (GLASS if seed < 16 else CHARCOAL)
				var y0 := float(row) * 4.0
				_quad(st, Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), Vector3(q.x, y0 + 3.86, q.y), Vector3(p.x, y0 + 3.86, p.y), colour)
	_quad(st, Vector3(corners[0].x, 112, corners[0].y), Vector3(corners[1].x, 112, corners[1].y), Vector3(corners[2].x, 112, corners[2].y), Vector3(corners[3].x, 112, corners[3].y), ROOF)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.72
	mat.metallic = 0.12
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var model := MeshInstance3D.new()
	model.name = "AirAlbaniaArchitecture"
	model.mesh = st.commit()
	model.visibility_range_end = 1600.0
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
