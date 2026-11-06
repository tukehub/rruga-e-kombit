class_name LanaRiver
extends Node3D
## A short OSM-based section of the Lana by Namazgja and Downtown One.
## This is scenery only: the existing road and driving surface are unchanged.
## Centreline: OpenStreetMap contributors, way 733080610, ODbL.

const CENTRE := [
	Vector2(657.6, 128.0), Vector2(549.4, 240.4), Vector2(526.2, 267.3),
	Vector2(515.9, 276.3), Vector2(497.1, 288.4), Vector2(473.9, 301.7),
	Vector2(448.8, 314.4), Vector2(414.2, 330.1), Vector2(383.5, 342.5),
	Vector2(351.7, 352.9), Vector2(294.6, 367.3),
]
const DEPTH := 2.6
const INNER := 10.0
const OUTER := 23.0
var rail_transforms: Array[Transform3D] = []


static func _cross_section(p: Vector2) -> Vector2:
	# Return distance to the river and a taper near its two scenery endpoints.
	if p.x < 270.0 or p.x > 680.0 or p.y < 105.0 or p.y > 390.0:
		return Vector2(INF, 0.0)
	var distance := INF
	var taper := 0.0
	for i in CENTRE.size() - 1:
		var a: Vector2 = CENTRE[i]
		var b: Vector2 = CENTRE[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < distance:
			distance = d
			taper = 1.0
			if i == 0:
				taper = smoothstep(0.0, 0.3, t)
			elif i == CENTRE.size() - 2:
				taper = 1.0 - smoothstep(0.45, 1.0, t)
	return Vector2(distance, taper)


static func channel_depth(x: float, z: float) -> float:
	var section := _cross_section(Vector2(x, z))
	return DEPTH * section.y * (1.0 - smoothstep(INNER, OUTER, section.x))


func build(terrain: Terrain) -> void:
	name = "LanaRiverAndBridge"
	_build_water(terrain)
	_build_bridge_rails()


func _build_water(terrain: Terrain) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points: Array[Vector2] = []
	# Subdivide the mapped river line so the water follows the ground elevation.
	for i in CENTRE.size() - 1:
		var a: Vector2 = CENTRE[i]
		var b: Vector2 = CENTRE[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / 7.0))
		for j in steps:
			points.append(a.lerp(b, float(j) / steps))
	points.append(CENTRE.back())
	var previous: Array[Vector3] = []
	for i in points.size():
		var p := points[i]
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var taper := _cross_section(p).y
		var width := 7.0 * taper
		var height := terrain.height_at(p.x, p.y) - 1.15 * taper
		var left := Vector3(p.x + normal.x * width, height, p.y + normal.y * width)
		var right := Vector3(p.x - normal.x * width, height, p.y - normal.y * width)
		if not previous.is_empty():
			for v in [previous[0], previous[1], right, previous[0], right, left]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(v.x * 0.08, v.z * 0.08))
				st.add_vertex(v)
		previous = [left, right]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.34, 0.31)
	material.roughness = 0.3
	material.metallic = 0.06
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var water := MeshInstance3D.new()
	water.name = "LanaWater"
	water.mesh = st.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_bridge_rails() -> void:
	# Track centreline crosses the river at this mapped location. Rails sit
	# beyond the existing kerbs and are visual only; no colliders are added.
	var centre := Vector3(541.0, 109.0, 249.0)
	var along := Vector3(0.23, -0.035, 0.973).normalized()
	var across := Vector3(along.z, 0.0, -along.x).normalized()
	var frame := Basis(across, along.cross(across).normalized(), along)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.66, 0.63)
	mat.roughness = 0.68
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.14, 25.0)
	mesh.material = mat
	var rail_mm := MultiMesh.new()
	rail_mm.transform_format = MultiMesh.TRANSFORM_3D
	rail_mm.mesh = mesh
	rail_mm.instance_count = 2
	rail_transforms.clear()
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var transform := Transform3D(frame, centre + across * side * 12.1 + Vector3.UP * 0.98)
		rail_transforms.append(transform)
		rail_mm.set_instance_transform(i, transform)
	var rails := MultiMeshInstance3D.new()
	rails.name = "BridgeRails"
	rails.multimesh = rail_mm
	rails.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rails)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 0.95, 0.14)
	post_mesh.material = mat
	var post_mm := MultiMesh.new()
	post_mm.transform_format = MultiMesh.TRANSFORM_3D
	post_mm.mesh = post_mesh
	post_mm.instance_count = 14
	for i in 14:
		var side := -1.0 if i < 7 else 1.0
		var offset := float(i % 7 - 3) * 4.0
		post_mm.set_instance_transform(i, Transform3D(frame, centre + across * side * 12.1 + along * offset + Vector3.UP * 0.5))
	var posts := MultiMeshInstance3D.new()
	posts.name = "BridgePosts"
	posts.multimesh = post_mm
	posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(posts)
