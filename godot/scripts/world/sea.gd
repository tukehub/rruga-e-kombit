class_name Sea
extends MeshInstance3D
## Open water for coastal and lake cities: one flat plane at the baked water
## surface (tools/pipeline/water.py) with the sea shader (analytic waves,
## turquoise shelf, shore foam). The terrain has already dropped the seabed
## under it and kept land above it, so the two never share a depth, and the
## surface sits under every road.

const SHADER := preload("res://shaders/sea.gdshader")
## Plane edge in metres: covers the chase camera's 6 km far plane from anywhere
## on the near grid.
const SIZE := 26000.0

var mat: ShaderMaterial


## Builds the water for `terrain`; returns false (and builds nothing) for a
## city without baked water.
func build(terrain: Terrain) -> bool:
	if not terrain.has_water:
		return false
	name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	mesh = plane
	position = Vector3(0.0, terrain.water_surface, 0.0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("shore", terrain.shore_tex)
	mat.set_shader_parameter("shore_origin", Vector2(float(terrain.near.x0), float(terrain.near.z0)))
	mat.set_shader_parameter("shore_size", float(terrain.near.cell) * (int(terrain.near.n) - 1))
	mat.set_shader_parameter("shore_span", terrain.water_span)
	material_override = mat
	return true


func set_env(wet: float, night: float) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("wetness", wet)
	mat.set_shader_parameter("night", night)
