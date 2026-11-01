class_name Terrain
extends Node3D
## Heightmap terrain from the pipeline's near/far float32 grids.
## Near grid (15 m cells, 9 km) is split into chunks with 2 LODs; the far
## grid (90 m cells, 80 km) is a single coarse ring mesh for the horizon.
## Shading is a 4-channel splat (R road, G vegetation, B water, A urban).

const CHUNK := 40                 # near-grid cells per chunk edge (600 m)
const SHADER := preload("res://shaders/terrain.gdshader")

var near := {}
var far := {}
var near_h: PackedFloat32Array
var far_h: PackedFloat32Array
var sea_level := -50.0
var mat: ShaderMaterial
var chunks: Array[MeshInstance3D] = []
var chunk_pos: PackedVector2Array = []
var far_mesh: MeshInstance3D


func load_city(city_id: String, splat: Texture2D) -> void:
	var dir := "res://assets/cities/%s/" % city_id
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "terrain.json"))
	near = meta.near
	far = meta.far
	sea_level = float(meta.get("sea_level", -50.0))
	near_h = FileAccess.get_file_as_bytes(dir + "terrain_near.bin").to_float32_array()
	far_h = FileAccess.get_file_as_bytes(dir + "terrain_far.bin").to_float32_array()
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("splat", splat)
	mat.set_shader_parameter("splat_span", float(meta.splat.span))
	mat.set_shader_parameter("tex_grass", load("res://assets/textures/grass_diff.jpg"))
	mat.set_shader_parameter("tex_grass_n", load("res://assets/textures/grass_nor.jpg"))
	mat.set_shader_parameter("tex_rock", load("res://assets/textures/rock_diff.jpg"))
	mat.set_shader_parameter("tex_rock_n", load("res://assets/textures/rock_nor.jpg"))
	mat.set_shader_parameter("tex_urban", load("res://assets/textures/concrete_diff.jpg"))
	mat.set_shader_parameter("tex_urban_n", load("res://assets/textures/concrete_nor.jpg"))
	mat.set_shader_parameter("tex_road", load("res://assets/textures/asphalt_diff.jpg"))
	mat.set_shader_parameter("sea_level", sea_level)
	_build_near()
	_build_far()


func set_env(wet: float, snow: float, night: float) -> void:
	mat.set_shader_parameter("wetness", wet)
	mat.set_shader_parameter("snow", snow)
	mat.set_shader_parameter("night", night)


## Bilinear height lookup on the near grid, falling back to far grid.
func height_at(x: float, z: float) -> float:
	var h := _sample(near, near_h, x, z)
	if is_nan(h):
		h = _sample(far, far_h, x, z)
	return h if not is_nan(h) else 0.0


func _sample(g: Dictionary, h: PackedFloat32Array, x: float, z: float) -> float:
	var n := int(g.n)
	var cell := float(g.cell)
	var fx := (x - float(g.x0)) / cell
	var fz := (z - float(g.z0)) / cell
	if fx < 0.0 or fz < 0.0 or fx >= n - 1 or fz >= n - 1:
		return NAN
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var h00 := h[iz * n + ix]
	var h10 := h[iz * n + ix + 1]
	var h01 := h[(iz + 1) * n + ix]
	var h11 := h[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _grid_mesh(g: Dictionary, h: PackedFloat32Array, cx0: int, cz0: int, cells: int, step: int, skirt: float, hole := Rect2(), origin := Vector3.ZERO) -> ArrayMesh:
	var n := int(g.n)
	var cell := float(g.cell)
	var x0 := float(g.x0)
	var z0 := float(g.z0)
	var m := cells / step + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(m * m)
	norms.resize(m * m)
	uvs.resize(m * m)
	for j in m:
		var gz := mini(cz0 + j * step, n - 1)
		for i in m:
			var gx := mini(cx0 + i * step, n - 1)
			var y := h[gz * n + gx]
			var px := x0 + gx * cell
			var pz := z0 + gz * cell
			verts[j * m + i] = Vector3(px, y, pz) - origin
			# central differences for the normal
			var xl := h[gz * n + maxi(gx - step, 0)]
			var xr := h[gz * n + mini(gx + step, n - 1)]
			var zu := h[maxi(gz - step, 0) * n + gx]
			var zd := h[mini(gz + step, n - 1) * n + gx]
			var d := 2.0 * cell * step
			norms[j * m + i] = Vector3(-(xr - xl) / d, 1.0, -(zd - zu) / d).normalized()
			uvs[j * m + i] = Vector2(px, pz)
	var idx := PackedInt32Array()
	idx.resize((m - 1) * (m - 1) * 6)
	var k := 0
	for j in m - 1:
		for i in m - 1:
			var a := j * m + i
			if hole.has_area():
				# skip quads fully inside `hole` (xz); straddling quads stay as overlap
				var lo := verts[a]
				var hi := verts[a + m + 1]
				if hole.has_point(Vector2(lo.x, lo.z)) and hole.has_point(Vector2(hi.x, hi.z)):
					continue
			# Godot front faces are clockwise
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + m
			idx[k + 3] = a + 1; idx[k + 4] = a + m + 1; idx[k + 5] = a + m
			k += 6
	idx.resize(k)
	if skirt > 0.0:
		# drop the border vertices to hide LOD cracks
		for j in m:
			for i in m:
				if i == 0 or j == 0 or i == m - 1 or j == m - 1:
					verts[j * m + i].y -= skirt
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _build_near() -> void:
	var n := int(near.n)
	var cell := float(near.cell)
	var nc := (n - 1) / CHUNK
	for cz in nc:
		for cx in nc:
			var center := Vector3(float(near.x0) + (cx + 0.5) * CHUNK * cell, 0, float(near.z0) + (cz + 0.5) * CHUNK * cell)
			var lod_distance := 1600.0 if Quality.preset == "high" else (850.0 if Quality.preset == "medium" else 500.0)
			var mi := MeshInstance3D.new()
			mi.position = center
			mi.mesh = _grid_mesh(near, near_h, cx * CHUNK, cz * CHUNK, CHUNK, 1, 0.0, Rect2(), center)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = lod_distance
			mi.visibility_range_end_margin = 150.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			add_child(mi)
			# coarse LOD for the same chunk
			var lo := MeshInstance3D.new()
			lo.mesh = _grid_mesh(near, near_h, cx * CHUNK, cz * CHUNK, CHUNK, 4, 1.5, Rect2(), center)
			lo.position = center
			lo.material_override = mat
			lo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lo.visibility_range_begin = lod_distance
			lo.visibility_range_begin_margin = 150.0
			add_child(lo)
			chunks.append(mi)
			chunk_pos.append(Vector2(float(near.x0) + (cx + 0.5) * CHUNK * cell, float(near.z0) + (cz + 0.5) * CHUNK * cell))


func _build_far() -> void:
	# far grid, decimated 2x, only outside the near grid: the far DSM is not
	# carved to the road and would poke through it (measured up to +5 m in Tirana)
	var n := int(far.n)
	var step := 2
	var span := float(near.cell) * (int(near.n) - 1)
	var hole := Rect2(float(near.x0), float(near.z0), span, span)
	var mi := MeshInstance3D.new()
	mi.mesh = _grid_mesh(far, far_h, 0, 0, (n - 1) / step * step, step, 0.0, hole)
	mi.material_override = mat
	mi.position.y = -2.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	far_mesh = mi
