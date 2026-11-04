class_name PlazaTower
extends Node3D
## A low-draw-call interpretation of Tirana's unbranded Plaza/TID Tower.
## The roughly 85 m tower transitions from an elliptical base to a rectangular
## top, with light inclined concrete panels and inset dark glazing. It is an
## architectural approximation, not a scan of the original building.

func _ready() -> void:
	_build()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	st.set_color(col)
	for p in [a, b, c, a, c, d]:
		st.add_vertex(p)


func _perimeter(i: int, y: float, depth: float = 0.0) -> Vector3:
	# Evenly spaced angles keep the facade strips continuous along all floors.
	var angle := TAU * float(i) / 32.0
	var x := cos(angle)
	var z := sin(angle)
	var square_factor := 1.0 / maxf(absf(x), absf(z))
	var blend := clampf(y / 85.0, 0.0, 1.0)
	var factor := lerpf(1.0, square_factor, blend * 0.8)
	return Vector3(x * factor * (16.2 + depth), y, z * factor * (14.7 + depth))


func _build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glazing := SurfaceTool.new()
	glazing.begin(Mesh.PRIMITIVE_TRIANGLES)
	var panel := Color(0.72, 0.70, 0.66)
	var glass := Color(0.12, 0.18, 0.21)
	var mullion := Color(0.40, 0.40, 0.38)
	for floor_index in 25:
		var y0 := 0.3 + floor_index * 3.38
		var y1 := y0 + 3.37
		for i in 32:
			var a := _perimeter(i, y0)
			var b := _perimeter(i + 1, y0)
			var c := _perimeter(i + 1, y1)
			var d := _perimeter(i, y1)
			# Facade alternates glass and solid areas in a changing stepped rhythm.
			var window_cell := (i + floor_index + floori(float(floor_index) / 4.0)) % 3 != 0
			_quad(glazing if window_cell else st, a, b, c, d, glass if window_cell else panel)
			if window_cell:
				# Narrow concrete spandrels and vertical edge frames add depth without
				# generating one node per window, for mobile draw-call efficiency.
				var bottom_top := y0 + 0.3
				_quad(st, _perimeter(i, y0, 0.04), _perimeter(i + 1, y0, 0.04), _perimeter(i + 1, bottom_top, 0.04), _perimeter(i, bottom_top, 0.04), panel)
				var p := _perimeter(i, y0, 0.05)
				var q := _perimeter(i, y1, 0.05)
				_quad(st, p, p.lerp(_perimeter(i + 1, y0, 0.05), 0.035), q.lerp(_perimeter(i + 1, y1, 0.05), 0.035), q, mullion)
	var roof := Color(0.60, 0.60, 0.57)
	for i in 32:
		_quad(st, Vector3(0, 85, 0), _perimeter(i, 85), _perimeter(i + 1, 85), Vector3(0, 85, 0), roof)
	st.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = load("res://assets/textures/landmark_concrete.jpg")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(0.55, 0.55, 0.55)
	material.roughness = 0.92
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(material)
	var model := MeshInstance3D.new()
	model.name = "PlazaTowerArchitecture"
	model.mesh = st.commit()
	model.visibility_range_end = 1800.0
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)
	glazing.generate_normals()
	var glazing_material := StandardMaterial3D.new()
	glazing_material.vertex_color_use_as_albedo = true
	glazing_material.roughness = 0.22
	glazing_material.metallic = 0.1
	glazing_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	glazing.set_material(glazing_material)
	var windows := MeshInstance3D.new()
	windows.name = "PlazaGlazing"
	windows.mesh = glazing.commit()
	windows.visibility_range_end = 1800.0
	windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(windows)
