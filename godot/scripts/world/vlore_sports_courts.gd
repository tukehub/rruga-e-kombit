extends Node3D
## The blue tennis, red basketball and green football courts on the coastal road.

const WHITE := Color("#f0eee3")
const POST := Color("#435355")
const BASE := Color("#d8c9ae")


func build() -> void:
	var st := LandmarkKit.begin()
	var fence := LandmarkKit.begin()
	_court(st, fence, -44.0, Vector2(23, 33), Color("#258cc9"))
	_court(st, fence, -7.5, Vector2(20, 33), Color("#bf5149"))
	_court(st, fence, 37.0, Vector2(28, 48), Color("#559c49"))
	_tennis(st, fence, -44.0)
	_basketball(st, -7.5)
	_football(st, fence, 37.0)
	for z: float in [-62, -26, 11, 60]:
		for x: float in [-15.9, 15.9]:
			LandmarkKit.tube(st, Vector3(x, 0.33, z), Vector3(x, 11.4, z), 0.105, 0.085, POST, 6)
			LandmarkKit.box(st, Vector3(x, 11.35, z), Vector3(1.65, 0.13, 0.12), POST)
			for i in 4:
				var offset := (i - 1.5) * 0.32
				LandmarkKit.box(st, Vector3(x + offset, 11.54, z), Vector3(0.24, 0.22, 0.20), WHITE)
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(), "CourtSurfacesAndFixtures", 850.0))
	var mesh_material := ShaderMaterial.new()
	mesh_material.shader = preload("res://shaders/court_fence.gdshader")
	var net := LandmarkKit.mesh_node(fence, mesh_material, "ChainLink", 360.0)
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(net)


func _court(st: SurfaceTool, fence: SurfaceTool, z: float, size: Vector2, tint: Color) -> void:
	LandmarkKit.box(st, Vector3(0, -1.05, z), Vector3(size.x + 2.7, 2.73, size.y + 2.7), BASE)
	LandmarkKit.box(st, Vector3(0, 0.31, z), Vector3(size.x, 0.10, size.y), tint)
	var a := Vector3(-size.x * 0.5, 0.39, z - size.y * 0.5)
	var b := a + Vector3.RIGHT * size.x
	var c := b + Vector3.BACK * size.y
	var d := a + Vector3.BACK * size.y
	for edge in [[a, b], [b, c], [c, d], [d, a]]:
		_fence_line(st, fence, edge[0], edge[1], 2.35)


func _fence_line(st: SurfaceTool, fence: SurfaceTool, start: Vector3, end: Vector3, height: float) -> void:
	var top := Vector3.UP * height
	LandmarkKit.quad(fence, start, end, end + top, start + top, POST)
	var posts := maxi(1, ceili(start.distance_to(end) / 4.1))
	for i in posts:
		var at := start.lerp(end, float(i) / posts)
		LandmarkKit.box(st, at + top * 0.5, Vector3(0.09, height, 0.09), POST)
	LandmarkKit.tube(st, start + top, end + top, 0.038, 0.038, POST, 5)


func _tennis(st: SurfaceTool, fence: SurfaceTool, z: float) -> void:
	_border(st, Vector2(-5.49, z - 11.885), Vector2(10.97, 23.77))
	for x: float in [-4.12, 4.12]:
		_line(st, Vector2(x, z - 11.885), Vector2(x, z + 11.885))
	for offset: float in [-6.40, 6.40]:
		_line(st, Vector2(-4.12, z + offset), Vector2(4.12, z + offset))
	_line(st, Vector2(0, z - 6.40), Vector2(0, z + 6.40))
	_fence_line(st, fence, Vector3(-6.15, 0.37, z), Vector3(6.15, 0.37, z), 0.95)
	LandmarkKit.box(st, Vector3(0, 1.32, z), Vector3(12.3, 0.047, 0.05), WHITE)


func _basketball(st: SurfaceTool, z: float) -> void:
	_border(st, Vector2(-7.5, z - 14), Vector2(15, 28))
	_line(st, Vector2(-7.5, z), Vector2(7.5, z))
	_circle(st, Vector2(0, z), 1.8)
	for side: float in [-1.0, 1.0]:
		var hoop_z := z + side * 12.3
		var key_z := z + (8.2 if side > 0.0 else -14.0)
		_border(st, Vector2(-2.45, key_z), Vector2(4.90, 5.8))
		_circle(st, Vector2(0, hoop_z), 6.3, -PI * side)
		var post_z := z + side * 15.0
		LandmarkKit.tube(st, Vector3(0, 0.36, post_z), Vector3(0, 3.94, post_z), 0.105, 0.105, POST, 7)
		LandmarkKit.tube(st, Vector3(0, 3.94, post_z), Vector3(0, 3.94, hoop_z + side * 0.44), 0.07, 0.055, POST, 6)
		LandmarkKit.box(st, Vector3(0, 3.92, hoop_z + side * 0.44), Vector3(1.80, 1.0, 0.085), WHITE)
		var rim := Vector3(0, 3.41, hoop_z)
		for i in 10:
			var a := i * TAU / 10.0
			var b := (i + 1) * TAU / 10.0
			LandmarkKit.tube(st, rim + Vector3(cos(a), 0, sin(a)) * 0.24,
				rim + Vector3(cos(b), 0, sin(b)) * 0.24, 0.023, 0.023, Color("#db6c2a"), 5)


func _football(st: SurfaceTool, fence: SurfaceTool, z: float) -> void:
	_border(st, Vector2(-12, z - 21), Vector2(24, 42))
	_line(st, Vector2(-12, z), Vector2(12, z))
	_circle(st, Vector2(0, z), 3.0)
	for side: float in [-1.0, 1.0]:
		var goal_z := z + side * 21.0
		_border(st, Vector2(-5.0, goal_z - (5.5 if side > 0.0 else 0.0)), Vector2(10.0, 5.5))
		for x: float in [-2.12, 2.12]:
			LandmarkKit.box(st, Vector3(x, 1.47, goal_z), Vector3(0.12, 2.23, 0.12), WHITE)
		LandmarkKit.box(st, Vector3(0, 2.59, goal_z), Vector3(4.32, 0.13, 0.13), WHITE)
		var back := goal_z + side * 1.44
		LandmarkKit.quad(fence, Vector3(-2.12, 0.37, back), Vector3(2.12, 0.37, back),
			Vector3(2.12, 2.58, goal_z), Vector3(-2.12, 2.58, goal_z), WHITE)


func _border(st: SurfaceTool, at: Vector2, size: Vector2) -> void:
	var b := at + Vector2(size.x, 0)
	var c := at + size
	var d := at + Vector2(0, size.y)
	_line(st, at, b)
	_line(st, b, c)
	_line(st, c, d)
	_line(st, d, at)


func _circle(st: SurfaceTool, at: Vector2, radius: float, arc := TAU) -> void:
	for i in 28:
		var a := Vector2.from_angle(i * arc / 28.0)
		var b := Vector2.from_angle((i + 1) * arc / 28.0)
		_line(st, at + a * radius, at + b * radius)


func _line(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var edge := (b - a).normalized().orthogonal() * 0.038
	LandmarkKit.quad_facing(st, Vector3(a.x - edge.x, 0.366, a.y - edge.y),
		Vector3(b.x - edge.x, 0.366, b.y - edge.y),
		Vector3(b.x + edge.x, 0.366, b.y + edge.y),
		Vector3(a.x + edge.x, 0.366, a.y + edge.y), WHITE, Vector3.UP)
