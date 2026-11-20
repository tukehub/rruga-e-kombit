class_name SeafrontPromenade
extends Node3D
## Lungomare's ground, from props.json "seafront" (tools/pipeline/seafront.py):
## stone paving along both pavements and, on the sea side, lawns cut by
## diagonal paths out to where the beach begins. One ribbon mesh following
## the terrain a few centimetres up, one material.

const SHADER := preload("res://shaders/seafront_ground.gdshader")
const LIFT := 0.16
const SEA_PAVING := 12.0     # metres of promenade paving beyond the road edge
const LAND_PAVING := 9.0
const KERB := 1.2            # leave the barriers their strip at the road edge
const STEP := 4.0            # lateral vertex spacing, to follow the ground

var mat: ShaderMaterial
var _clear: Array = []
const CLEAR_RADIUS := 26.0


## `keep_clear`: [x, z] points (landmarks) the ground leaves room around.
func build(data: Dictionary, terrain: Terrain, keep_clear: Array = []) -> void:
	_clear = keep_clear
	name = "SeafrontPromenade"
	var line: Array = data.get("line", [])
	if line.size() < 2:
		return
	var hw := float(data.get("hw", 10.0))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along := 0.0
	var prev: Array = []
	for i in line.size():
		var e: Array = line[i]
		var c := Vector3(float(e[0]), 0.0, float(e[2]))
		var n := Vector3(float(e[3]), 0.0, float(e[4]))
		if i > 0:
			along += c.distance_to(Vector3(float(prev[0]), 0.0, float(prev[2])))
		var sea_edge := float(e[5])
		if i > 0:
			var pn := Vector3(float(prev[3]), 0.0, float(prev[4]))
			var pc := Vector3(float(prev[0]), 0.0, float(prev[2]))
			var pal := along - c.distance_to(pc)
			var pedge := float(prev[5])
			# Sea side: paving, then lawn to the beach; both stop at buildings.
			var pave_a := minf(hw + SEA_PAVING, pedge)
			var pave_b := minf(hw + SEA_PAVING, sea_edge)
			if pave_a > hw + KERB + 1.0 and pave_b > hw + KERB + 1.0:
				_strip(st, terrain, pc, pn, c, n, pal, along, hw + KERB, pave_a, hw + KERB, pave_b, 0.0)
			if pedge > hw + SEA_PAVING + 2.0 and sea_edge > hw + SEA_PAVING + 2.0:
				_strip(st, terrain, pc, pn, c, n, pal, along, hw + SEA_PAVING, pedge, hw + SEA_PAVING, sea_edge, 1.0)
			# Land side: the pavement under the café terraces and palms.
			var land_a := minf(hw + LAND_PAVING, float(prev[6]) if prev.size() > 6 else hw + LAND_PAVING)
			var land_b := minf(hw + LAND_PAVING, float(e[6]) if e.size() > 6 else hw + LAND_PAVING)
			if land_a > hw + KERB + 1.0 and land_b > hw + KERB + 1.0:
				_strip(st, terrain, pc, -pn, c, -n, pal, along, hw + KERB, land_a, hw + KERB, land_b, 0.0)
		prev = e
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	var node := MeshInstance3D.new()
	node.name = "PromenadeGround"
	node.mesh = st.commit()
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 1200.0
	add_child(node)


func set_wet(wet: float) -> void:
	if mat != null:
		mat.set_shader_parameter("wetness", wet)


## A band between lateral offsets [r0, r1] (metres from the centreline along
## the normal), from sample a to sample b, split across to follow the terrain.
func _strip(st: SurfaceTool, terrain: Terrain, ca: Vector3, na: Vector3, cb: Vector3, nb: Vector3,
		ua: float, ub: float, a0: float, a1: float, b0: float, b1: float, lawn: float) -> void:
	var cuts := maxi(1, ceili(maxf(a1 - a0, b1 - b0) / STEP))
	for k in cuts:
		var t0 := float(k) / cuts
		var t1 := float(k + 1) / cuts
		var pts := []
		for q in [[ca, na, ua, lerpf(a0, a1, t0)], [cb, nb, ub, lerpf(b0, b1, t0)], [cb, nb, ub, lerpf(b0, b1, t1)], [ca, na, ua, lerpf(a0, a1, t1)]]:
			var p: Vector3 = (q[0] as Vector3) + (q[1] as Vector3) * float(q[3])
			p.y = terrain.height_at(p.x, p.z) + LIFT
			pts.append([p, Vector2(float(q[2]), float(q[3]))])
		var mid: Vector3 = ((pts[0][0] as Vector3) + (pts[2][0] as Vector3)) * 0.5
		var blocked := false
		for q in _clear:
			if Vector2(mid.x - float(q[0]), mid.z - float(q[1])).length() < CLEAR_RADIUS:
				blocked = true
		if blocked:
			continue
		# Wind so the face looks up, whichever side of the road this is.
		var up := ((pts[1][0] as Vector3) - (pts[0][0] as Vector3)).cross((pts[3][0] as Vector3) - (pts[0][0] as Vector3)).y > 0.0
		var order := [0, 1, 2, 0, 2, 3] if not up else [0, 2, 1, 0, 3, 2]
		st.set_color(Color(lawn, 0, 0))
		st.set_normal(Vector3.UP)
		for j in order:
			st.set_uv(pts[j][1])
			st.add_vertex(pts[j][0])
