class_name RoadMesh
extends Node3D
## Builds the race road from a RaceTrack: asphalt surface with UV (u across,
## v along), kerbs, a skirt down to the terrain, and start/finish line.

const ROAD_SHADER := preload("res://shaders/road.gdshader")
const KERB_H := 0.14
const KERB_W := 0.5
const BARRIER_H := 0.5
const SKIRT := 6.0
const KERB_RED := Color(0.58, 0.075, 0.055)
const KERB_WHITE := Color(0.72, 0.72, 0.68)

var surface_mat: ShaderMaterial
var kerb_mat: StandardMaterial3D
var skirt_mat: StandardMaterial3D
var surface: MeshInstance3D
var length := 0.0
var barrier_mat: StandardMaterial3D
var _terrain_height := Callable()


func build(track: RaceTrack, hw: float, wet: float, terrain_height := Callable()) -> void:
	length = track.L
	_terrain_height = terrain_height
	surface_mat = ShaderMaterial.new()
	surface_mat.shader = ROAD_SHADER
	surface_mat.set_shader_parameter("tex_asphalt", load("res://assets/textures/asphalt_diff.jpg"))
	surface_mat.set_shader_parameter("tex_asphalt_n", load("res://assets/textures/asphalt_nor.jpg"))
	surface_mat.set_shader_parameter("tex_asphalt_r", load("res://assets/textures/asphalt_rough.jpg"))
	surface_mat.set_shader_parameter("half_w", hw)
	surface_mat.set_shader_parameter("track_len", track.L)
	surface_mat.set_shader_parameter("wetness", wet)

	kerb_mat = StandardMaterial3D.new()
	kerb_mat.vertex_color_use_as_albedo = true
	kerb_mat.roughness = 0.86
	skirt_mat = StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(0.46, 0.44, 0.40)
	skirt_mat.albedo_texture = load("res://assets/textures/concrete_diff.jpg")
	skirt_mat.roughness = 0.95

	_build_surface(track, hw)
	_build_kerbs(track, hw)
	_build_edge_barriers(track, hw)
	_build_skirt(track, hw)
	set_wet(wet)


func add_paved_median(track: RaceTrack, start: float, length_m: float) -> void:
	# Traversable chamfered curbs keep the race's continuous road width.
	var mesh := LandmarkKit.begin()
	var steps := maxi(1, ceili(length_m / 3.0))
	var lateral := [-0.97, -0.68, 0.68, 0.97]
	var heights := [0.021, 0.105, 0.105, 0.021]
	var curb := Color("#cec5ac")
	var brick := Color("#b1a18a")
	for i in steps:
		var a := length_m * i / steps
		var b := length_m * (i + 1) / steps
		var width_a := maxf(0.03, smoothstep(0.0, 6.0, minf(a, length_m - a)))
		var width_b := maxf(0.03, smoothstep(0.0, 6.0, minf(b, length_m - b)))
		var row_a: Array[Vector3] = []
		var row_b: Array[Vector3] = []
		for j in lateral.size():
			row_a.append(track.pos(start + a, lateral[j] * width_a) + Vector3.UP * heights[j] * width_a)
			row_b.append(track.pos(start + b, lateral[j] * width_b) + Vector3.UP * heights[j] * width_b)
		for j in lateral.size() - 1:
			var color := brick.lerp(brick.darkened(0.08), 0.5 + 0.5 * sin(i * 2.1)) if j == 1 else curb
			LandmarkKit.quad_facing(mesh, row_a[j], row_b[j], row_b[j + 1], row_a[j + 1], color, Vector3.UP)
	var mat := LandmarkKit.material(0.89)
	mat.albedo_texture = preload("res://assets/textures/cobble_diff.jpg")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 1.6
	var median := LandmarkKit.mesh_node(mesh, mat, "LungomarePavedMedian", 1400.0)
	median.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(median)


func set_wet(w: float) -> void:
	surface_mat.set_shader_parameter("wetness", w)
	var wet := clampf(w, 0.0, 1.0)
	kerb_mat.roughness = lerpf(0.86, 0.67, wet)
	kerb_mat.albedo_color = Color.WHITE.darkened(wet * 0.12)
	skirt_mat.albedo_color = Color(0.46, 0.44, 0.40).darkened(wet * 0.16)
	skirt_mat.roughness = lerpf(0.95, 0.82, wet)
	if barrier_mat != null:
		barrier_mat.roughness = lerpf(0.88, 0.7, wet)
		barrier_mat.albedo_color = Color.WHITE.darkened(wet * 0.1)


func _build_surface(track: RaceTrack, hw: float) -> void:
	var M := track.M
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# ring of M+1 (closed) cross sections with 5 verts each: -hw-KERB_W, -hw, 0, hw, hw+KERB_W
	var xs := [-hw - KERB_W - 0.6, -hw, 0.0, hw, hw + KERB_W + 0.6]
	var ring := xs.size()
	for i in M + 1:
		var k := i % M
		var s := i * track.ds
		var p := Vector3(track.X[k], track.Y[k], track.Z[k])
		var nx := track.NX[k]
		var nz := track.NZ[k]
		var up := Vector3(track.TX[k], track.TY[k], track.TZ[k]).cross(Vector3(nx, 0.0, nz)).normalized()
		if up.y < 0.0:
			up = -up
		for xi in ring:
			var d: float = xs[xi]
			var ys := -0.02 if (xi == 0 or xi == ring - 1) else 0.0
			var v := p + Vector3(nx, 0.0, nz) * d + Vector3(0, ys, 0)
			st.set_normal(up)
			st.set_uv(Vector2(d, s))
			st.set_color(Color(1, 1, 1, 1.0 if abs(d) <= hw else 0.0))
			st.add_vertex(v)
	for i in M:
		var a := i * ring
		var b := (i + 1) * ring
		for xi in ring - 1:
			# clockwise = front face in Godot
			st.add_index(a + xi)
			st.add_index(b + xi)
			st.add_index(a + xi + 1)
			st.add_index(a + xi + 1)
			st.add_index(b + xi)
			st.add_index(b + xi + 1)
	st.generate_tangents()
	surface = MeshInstance3D.new()
	surface.mesh = st.commit()
	surface.material_override = surface_mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)


func _build_kerbs(track: RaceTrack, hw: float) -> void:
	var M := track.M
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := 0
	for side: float in [-1.0, 1.0]:
		for i in M:
			var k0 := i
			var k1 := (i + 1) % M
			var seg_col := KERB_RED if (i / 3) % 2 == 0 else KERB_WHITE
			seg_col = seg_col.darkened(0.04 + 0.035 * (1.0 + sin(i * 0.37)))
			var pts: Array[Vector3] = []
			for k: int in [k0, k1]:
				var p := Vector3(track.X[k], track.Y[k], track.Z[k])
				var n := Vector3(track.NX[k], 0.0, track.NZ[k]) * side
				pts.append(p + n * hw)                                  # inner bottom
				pts.append(p + n * hw + Vector3(0, KERB_H, 0))         # inner top
				pts.append(p + n * (hw + KERB_W) + Vector3(0, KERB_H, 0))  # outer top
				pts.append(p + n * (hw + KERB_W) + Vector3(0, -0.05, 0))   # outer bottom
			# quads between cross sections 0..3 and 4..7
			for q in 3:
				var a := pts[q]
				var b := pts[q + 1]
				var c := pts[q + 5]
				var d := pts[q + 4]
				var nrm := (b - a).cross(d - a).normalized()
				if side > 0.0:
					nrm = -nrm
				for v in [a, b, c, d]:
					st.set_normal(nrm)
					st.set_color(seg_col)
					st.add_vertex(v)
				if side > 0.0:
					st.add_index(idx); st.add_index(idx + 2); st.add_index(idx + 1)
					st.add_index(idx); st.add_index(idx + 3); st.add_index(idx + 2)
				else:
					st.add_index(idx); st.add_index(idx + 1); st.add_index(idx + 2)
					st.add_index(idx); st.add_index(idx + 2); st.add_index(idx + 3)
				idx += 4
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = kerb_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_edge_barriers(track: RaceTrack, hw: float) -> void:
	# Low solid panels follow the existing road edge. They are visual only: the
	# simulation retains its existing collision boundary and handling.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx := 0
	for side: float in [-1.0, 1.0]:
		for i in track.M:
			var j := (i + 1) % track.M
			var color := KERB_RED if int(i * track.ds / 8.0) % 2 == 0 else KERB_WHITE
			var a := Vector3(track.X[i], track.Y[i], track.Z[i]) + Vector3(track.NX[i], 0.0, track.NZ[i]) * side * (hw + KERB_W)
			var b := Vector3(track.X[j], track.Y[j], track.Z[j]) + Vector3(track.NX[j], 0.0, track.NZ[j]) * side * (hw + KERB_W)
			var normal := Vector3(track.NX[i], 0.0, track.NZ[i]) * -side
			for point in [a, b, b + Vector3.UP * BARRIER_H, a + Vector3.UP * BARRIER_H]:
				st.set_color(color.darkened(0.18 if point.y < a.y + BARRIER_H * 0.5 else 0.0))
				st.set_normal(normal)
				st.add_vertex(point)
			for index in [0, 1, 2, 0, 2, 3]:
				st.add_index(idx + index)
			idx += 4
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	barrier_mat = mat
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var barrier := MeshInstance3D.new()
	barrier.name = "RoadsideBarriers"
	barrier.mesh = st.commit()
	barrier.material_override = mat
	barrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(barrier)


func _build_skirt(track: RaceTrack, hw: float) -> void:
	# a sloped shoulder that drops to terrain level so the road never floats
	var M := track.M
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outer := hw + KERB_W + 0.6
	var idx := 0
	for side: float in [-1.0, 1.0]:
		for i in M:
			var k0 := i
			var k1 := (i + 1) % M
			var pts: Array[Vector3] = []
			for k: int in [k0, k1]:
				var p := Vector3(track.X[k], track.Y[k], track.Z[k])
				var n := Vector3(track.NX[k], 0.0, track.NZ[k]) * side
				pts.append(p + n * outer + Vector3(0, -0.02, 0))
				var edge := p + n * (outer + SKIRT)
				edge.y = float(_terrain_height.call(edge.x, edge.z)) + 0.015 if _terrain_height.is_valid() else p.y - 2.2
				pts.append(edge)
			var a := pts[0]
			var b := pts[1]
			var c := pts[3]
			var d := pts[2]
			var nrm := (b - a).cross(d - a).normalized()
			if side > 0.0:
				nrm = -nrm
			if nrm.y < 0.0:
				nrm = -nrm
			for v in [a, b, c, d]:
				st.set_normal(nrm)
				st.set_uv(Vector2(v.x, v.z) * 0.25)
				st.add_vertex(v)
			if side > 0.0:
				st.add_index(idx); st.add_index(idx + 2); st.add_index(idx + 1)
				st.add_index(idx); st.add_index(idx + 3); st.add_index(idx + 2)
			else:
				st.add_index(idx); st.add_index(idx + 1); st.add_index(idx + 2)
				st.add_index(idx); st.add_index(idx + 2); st.add_index(idx + 3)
			idx += 4
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = skirt_mat
	mi.name = "RoadShoulders"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
