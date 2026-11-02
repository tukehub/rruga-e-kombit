class_name Buildings
extends Node3D
## Loads <city>/buildings.glb (chunked by the pipeline), swaps the two
## importer materials (facade / roof) for the facade shader and a roof
## material, and applies per-chunk visibility ranges from the quality preset.

const FACADE_SHADER := preload("res://shaders/facade.gdshader")

var facade_mat: ShaderMaterial
var roof_mat: StandardMaterial3D
var chunk_nodes: Array[MeshInstance3D] = []


func load_city(city_id: String) -> void:
	var path := "res://assets/cities/%s/buildings.glb" % city_id
	if not ResourceLoader.exists(path):
		push_warning("no buildings for " + city_id)
		return
	facade_mat = ShaderMaterial.new()
	facade_mat.shader = FACADE_SHADER
	facade_mat.set_shader_parameter("tex_plaster", load("res://assets/textures/plaster_diff.jpg"))
	facade_mat.set_shader_parameter("tex_plaster_n", load("res://assets/textures/plaster_nor.jpg"))
	facade_mat.set_shader_parameter("tex_concrete", load("res://assets/textures/concrete_wall_diff.jpg"))
	if city_id == "tirane":
		# Trial more detailed windows around the first part of this circuit.
		facade_mat.set_shader_parameter("detail_preview", 1.0)
		facade_mat.set_shader_parameter("detail_origin", Vector2(77.72, 35.84))
	roof_mat = StandardMaterial3D.new()
	roof_mat.vertex_color_use_as_albedo = true
	roof_mat.albedo_texture = load("res://assets/textures/rooftiles_diff.jpg")
	roof_mat.uv1_triplanar = true
	roof_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	roof_mat.roughness = 0.85

	var scene: PackedScene = load(path)
	var inst := scene.instantiate()
	add_child(inst)
	_collect(inst)
	apply_quality()
	Quality.preset_changed.connect(func(_p): apply_quality())


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			var name := m.resource_name.to_lower() if m != null else ""
			if name.find("roof") >= 0:
				mi.set_surface_override_material(i, roof_mat)
			else:
				mi.set_surface_override_material(i, facade_mat)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		chunk_nodes.append(mi)
	for c in n.get_children():
		_collect(c)


func apply_quality() -> void:
	var dist := float(Quality.p.building_dist)
	for mi in chunk_nodes:
		mi.visibility_range_end = dist
		mi.visibility_range_end_margin = dist * 0.1
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func set_env(night: float, wet: float) -> void:
	if facade_mat:
		facade_mat.set_shader_parameter("night", night)
		facade_mat.set_shader_parameter("wetness", wet)
