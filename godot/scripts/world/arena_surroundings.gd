class_name ArenaSurroundings
extends Node3D
## What stands around the points-mode square: the race's Tirana landmarks in
## their real bearings from the statue, grandstands (CrowdSpawner fills them),
## flags, lamps and trees. Everything sits outside the wall and the chase
## camera's reach; repeated things are MultiMeshes so phones pay a handful of
## draw calls for the crowd, flags, lamps and trees together.

const FLAG_SHADER := preload("res://shaders/flag_wave.gdshader")
## Landmarks of the race's Tirana that stand around Skanderbeg Square.
const LANDMARK_IDS := ["national_museum", "mosque", "clocktower", "plaza_tower",
	"international_hotel", "eyes_tirana", "cathedral", "bank_albania"]
## The race's statue faces 180 degrees, the arena's 0: the layout turns with it.
const LAYOUT_TURN := 180.0
## Stands start this far outside the wall: the chase camera trails a car by
## up to ~10 m, so it never ends up among the spectators.
const STAND_GAP := 12.0
const STAND_ROWS := 3
const STAND_STEP := 1.5          # depth of a stand row, metres
const STAND_RISE := 0.55         # height gained per row
## Landmarks keep clear of the wall, the stands and the trees behind them.
const LANDMARK_CLEARANCE := 34.0
## Footprint radius of each landmark (half the diagonal of its model's box).
const FOOTPRINT := {"national_museum": 56.0, "mosque": 15.0, "clocktower": 6.0,
	"plaza_tower": 22.0, "international_hotel": 32.0, "eyes_tirana": 26.0,
	"cathedral": 29.0, "bank_albania": 25.0}
var rng := RandomNumberGenerator.new()
var placed_landmarks: Array = []    # [{id, position, radius}]


func build(half_x: float, half_z: float, corner: float) -> void:
	rng.seed = 7071912                # same square every round
	_landmarks(half_x, half_z)
	var stands := stand_segments(half_x, half_z, corner)
	_stands(stands)
	_flags_and_lamps(stands)
	_trees(half_x, half_z)


# ------------------------------------------------------------------ landmarks
func _landmarks(half_x: float, half_z: float) -> void:
	var path := "res://assets/cities/tirane/props.json"
	if not FileAccess.file_exists(path):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var by_id := {}
	for anchor in data.get("landmarks", []):
		by_id[str(anchor.id)] = anchor
	if not by_id.has("skanderbeg"):
		return
	var centre: Dictionary = by_id.skanderbeg
	var turn := deg_to_rad(LAYOUT_TURN)
	var anchors := []
	var cluster_push := {}            # the clock tower follows its mosque
	for id in LANDMARK_IDS:
		if not by_id.has(id):
			continue
		var a: Dictionary = by_id[id]
		var offset := Vector2(float(a.x) - float(centre.x), float(a.z) - float(centre.z)).rotated(-turn)
		var radius := float(FOOTPRINT.get(id, 25.0))
		var pos := offset
		if id == "clocktower" and cluster_push.has("mosque"):
			pos = offset + cluster_push.mosque
		else:
			pos = _clear_of_square(offset, radius, half_x + LANDMARK_CLEARANCE, half_z + LANDMARK_CLEARANCE)
			cluster_push[id] = pos - offset
		anchors.append({"id": id, "x": pos.x, "y": 0.0, "z": pos.y, "yaw": float(a.get("yaw", 0.0)) + LAYOUT_TURN})
		placed_landmarks.append({"id": id, "position": pos, "radius": radius})
	var models := Landmarks.new()
	models.name = "Landmarks"
	add_child(models)
	models.load_anchors(anchors)


## Slides a footprint outward along its bearing until it clears the rectangle.
func _clear_of_square(offset: Vector2, radius: float, hx: float, hz: float) -> Vector2:
	var dir := offset.normalized() if offset.length() > 0.1 else Vector2.RIGHT
	var r := offset.length()
	for i in 200:
		var p := dir * r
		var nearest := Vector2(clampf(p.x, -hx, hx), clampf(p.y, -hz, hz))
		var outside := absf(p.x) > hx or absf(p.y) > hz
		if outside and p.distance_to(nearest) >= radius:
			return p
		r += 2.0
	return dir * r


# ------------------------------------------------------------------ stands
## Straight runs of grandstand: [origin, along, outward normal, length].
static func stand_segments(half_x: float, half_z: float, corner: float) -> Array:
	var segments := []
	var run_x := half_x - corner - 6.0
	var run_z := half_z - corner - 6.0
	for side in [-1.0, 1.0]:
		# Long sides: two stands with a gap in the middle, as at a street circuit.
		for half in [-1.0, 1.0]:
			var from := 8.0 if half > 0.0 else -run_x
			var to := run_x if half > 0.0 else -8.0
			segments.append([Vector3(from, 0.0, side * (half_z + STAND_GAP)), Vector3.RIGHT,
				Vector3(0.0, 0.0, side), to - from])
		segments.append([Vector3(side * (half_x + STAND_GAP), 0.0, -run_z), Vector3.BACK,
			Vector3(side, 0.0, 0.0), run_z * 2.0])
	return segments


func _stands(segments: Array) -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.62, 0.6, 0.57)
	concrete.roughness = 0.9
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.72, 0.1, 0.12)
	trim.roughness = 0.7
	for s in segments:
		var origin: Vector3 = s[0]
		var along: Vector3 = s[1]
		var out: Vector3 = s[2]
		var length: float = s[3]
		var mid := origin + along * length * 0.5
		var yaw := atan2(along.x, along.z) + PI * 0.5
		for row in STAND_ROWS:
			var height := STAND_RISE * (row + 1)
			var step := _box_node(Vector3(length, height, STAND_STEP), concrete)
			step.position = mid + out * (STAND_STEP * (row + 0.5)) + Vector3.UP * height * 0.5
			step.rotation.y = yaw
			add_child(step)
		# A red banner along the front of each stand.
		var banner := _box_node(Vector3(length, 0.5, 0.08), trim)
		banner.position = mid - out * 0.05 + Vector3.UP * 0.3
		banner.rotation.y = yaw
		add_child(banner)


func _box_node(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# ------------------------------------------------------------------ shared box helper
func _part(st: SurfaceTool, c: Vector3, size: Vector3, col: Color, tag: float, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(1, 1, -1)]],
		[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
		[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(-1, 1, -1)]],
		[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
		[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1)]],
	]
	for f in faces:
		var n: Vector3 = basis * (f[0] as Vector3)
		var vs: Array = f[1]
		for index in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = vs[index]
			st.set_normal(n)
			st.set_color(col)
			st.set_uv(Vector2(tag, 0.0))
			st.add_vertex(c + basis * Vector3(v.x * h.x, v.y * h.y, v.z * h.z))


func _flag_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 8
	for i in segments:
		var u0 := float(i) / segments
		var u1 := float(i + 1) / segments
		var quad := [Vector3(u0 * 2.1, 0, 0), Vector3(u1 * 2.1, 0, 0), Vector3(u1 * 2.1, 1.4, 0), Vector3(u0 * 2.1, 1.4, 0)]
		var uvs := [Vector2(u0, 1), Vector2(u1, 1), Vector2(u1, 0), Vector2(u0, 0)]
		for index in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.BACK)
			st.set_uv(uvs[index])
			st.add_vertex(quad[index])
	return st.commit()


func _pole_mesh(height: float, arm: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grey := Color(0.24, 0.25, 0.27)
	_part(st, Vector3(0, height * 0.5, 0), Vector3(0.14, height, 0.14), grey, 0.0)
	if arm:
		_part(st, Vector3(0, height - 0.05, -0.6), Vector3(0.1, 0.1, 1.2), grey, 0.0)
		_part(st, Vector3(0, height - 0.18, -1.15), Vector3(0.42, 0.18, 0.62), Color(1.0, 0.92, 0.72), 0.0)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.metallic = 0.5
	material.roughness = 0.45
	st.set_material(material)
	return st.commit()


func _flags_and_lamps(segments: Array) -> void:
	var flags: Array[Transform3D] = []
	var poles: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	for s in segments:
		var origin: Vector3 = s[0]
		var along: Vector3 = s[1]
		var out: Vector3 = s[2]
		var length: float = s[3]
		var back := out * (STAND_STEP * STAND_ROWS + 1.2)
		var count := int(length / 18.0)
		for i in count + 1:
			var p := origin + along * (length * i / maxf(1.0, count)) + back
			var pole_basis := Basis(Vector3.UP, atan2(out.x, out.z))   # arm over the square
			if i % 2 == 0:
				poles.append(Transform3D(Basis.IDENTITY, p))
				flags.append(Transform3D(Basis(Vector3.UP, atan2(-along.z, along.x)), p + Vector3.UP * 6.6))
			else:
				lamps.append(Transform3D(pole_basis, p))
	_multimesh("FlagPoles", _pole_mesh(8.0, false), poles)
	var flag_node := _multimesh("Flags", _flag_mesh(), flags, true)
	var flag_material := ShaderMaterial.new()
	flag_material.shader = FLAG_SHADER
	flag_node.material_override = flag_material
	_multimesh("Lamps", _pole_mesh(7.5, true), lamps)


func _multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], phases := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = phases
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if phases:
			mm.set_instance_custom_data(i, Color(0, 0, 0, rng.randf()))
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


# ------------------------------------------------------------------ trees
func _trees(half_x: float, half_z: float) -> void:
	var props := Props.new()
	var mesh: Mesh = props._tree_meshes()[0]
	props.free()
	var ring := STAND_GAP + STAND_STEP * STAND_ROWS + 9.0
	var hx := half_x + ring
	var hz := half_z + ring
	var transforms: Array[Transform3D] = []
	var perimeter := []
	var x := -hx
	while x <= hx:
		perimeter.append(Vector2(x, -hz))
		perimeter.append(Vector2(x, hz))
		x += 13.0
	var z := -hz + 13.0
	while z < hz:
		perimeter.append(Vector2(-hx, z))
		perimeter.append(Vector2(hx, z))
		z += 13.0
	for p in perimeter:
		var blocked := false
		for landmark in placed_landmarks:
			if (p as Vector2).distance_to(landmark.position) < float(landmark.radius) + 6.0:
				blocked = true
				break
		if blocked:
			continue
		var size := rng.randf_range(0.85, 1.2)
		var jitter := Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
		transforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, 0.0, p.y) + jitter))
	_multimesh("Trees", mesh, transforms)
