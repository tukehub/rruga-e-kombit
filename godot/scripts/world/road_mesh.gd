class_name RoadMesh
extends Node3D
## Builds the race road from a RaceTrack: asphalt surface with UV (u across,
## v along), kerbs, a skirt down to the terrain, and start/finish line.

const ROAD_SHADER := preload("res://shaders/road.gdshader")
const KERB_H := 0.14
const KERB_W := 0.5
const SKIRT := 6.0

var surface_mat: ShaderMaterial
var kerb_mat: StandardMaterial3D
var skirt_mat: StandardMaterial3D
var surface: MeshInstance3D
var length := 0.0


func build(track: RaceTrack, hw: float, wet: float) -> void:
	length = track.L
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
	kerb_mat.roughness = 0.6
	skirt_mat = StandardMaterial3D.new()
	skirt_mat.albedo_color = Color(0.22, 0.21, 0.2)
	skirt_mat.roughness = 0.95

	_build_surface(track, hw)
	_build_kerbs(track, hw)
	_build_skirt(track, hw)


func set_wet(w: float) -> void:
	surface_mat.set_shader_parameter("wetness", w)


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
			var seg_col := Color(0.85, 0.12, 0.1) if (i / 3) % 2 == 0 else Color(0.95, 0.95, 0.92)
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
				pts.append(p + n * (outer + SKIRT) + Vector3(0, -2.2, 0))
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
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
