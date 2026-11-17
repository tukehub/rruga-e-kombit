class_name CrowdSpawner
extends Node3D
## Spectators around Skanderbeg Square. One MultiMeshInstance3D per optimised
## model in CROWD_DIR (tools/optimize_crowd.py writes them), so the whole
## crowd costs one draw call per model. People stand in small clusters on the
## first two rows of the grandstands outside the wall, facing the statue;
## crowd_spectator.gdshader animates them, no skeletons.
## Barrier geometry comes from Arena (HALF_X x HALF_Z rounded rectangle,
## CORNER radius); the stands from ArenaSurroundings.stand_segments().

const CROWD_DIR := "res://assets/models/crowd/"
const SHADER := preload("res://shaders/crowd_spectator.gdshader")
const MIN_GAP := 0.62              # metres between two people's feet
const ROWS_USED := 2               # front rows of the stands only

@export var target_count := 110    # 80 on the low preset
@export var cluster_size := Vector2i(3, 9)
@export var crowd_seed := 1912

var rng := RandomNumberGenerator.new()
var spectators := 0
var models: Array[MultiMeshInstance3D] = []


func _ready() -> void:
	spawn()


func spawn() -> void:
	for m in models:
		m.queue_free()
	models.clear()
	rng.seed = crowd_seed
	var meshes := _load_models()
	if meshes.is_empty():
		push_warning("CrowdSpawner: no *_opt.glb in " + CROWD_DIR)
		return
	var count := 80 if Quality.preset == "low" else target_count
	var spots := _scatter(count)
	spectators = spots.size()
	# Deal the people out across the models.
	var per_model: Array = []
	for i in meshes.size():
		per_model.append([])
	for i in spots.size():
		per_model[rng.randi() % meshes.size()].append(spots[i])
	for i in meshes.size():
		_build_multimesh(meshes[i], per_model[i], i)


## [{mesh, texture}] for every optimised spectator model.
func _load_models() -> Array:
	var found := []
	var names := PackedStringArray()
	var dir := DirAccess.open(CROWD_DIR)
	if dir == null:
		return found
	for file in dir.get_files():
		# Exported builds list "x.glb.import" (or .remap) instead of "x.glb".
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.ends_with("_opt.glb") and not name in names:
			names.append(name)
	names.sort()
	for name in names:
		var scene := load(CROWD_DIR + name) as PackedScene
		if scene == null:
			continue
		var root := scene.instantiate()
		var mesh_node := _first_mesh(root)
		if mesh_node != null:
			var texture: Texture2D = null
			var material := mesh_node.get_active_material(0)
			if material is BaseMaterial3D:
				texture = (material as BaseMaterial3D).albedo_texture
			found.append({"name": name.get_basename(), "mesh": mesh_node.mesh, "texture": texture})
		root.free()
	return found


func _first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var m := _first_mesh(child)
		if m != null:
			return m
	return null


## Clusters of people along the front stand rows: [{position, basis}].
func _scatter(count: int) -> Array:
	var segments := ArenaSurroundings.stand_segments(Arena.HALF_X, Arena.HALF_Z, Arena.CORNER)
	var total := 0.0
	for s in segments:
		total += float(s[3])
	var placed: Array = []
	var attempts := 0
	while placed.size() < count and attempts < count * 20:
		attempts += 1
		# A cluster: pick a stand by length, a spot on it, then a few friends.
		var pick := rng.randf() * total
		var seg: Array = segments[0]
		for s in segments:
			pick -= float(s[3])
			if pick <= 0.0:
				seg = s
				break
		var origin: Vector3 = seg[0]
		var along: Vector3 = seg[1]
		var out: Vector3 = seg[2]
		var length: float = seg[3]
		var centre := rng.randf_range(2.0, length - 2.0)
		var size := mini(rng.randi_range(cluster_size.x, cluster_size.y), count - placed.size())
		for k in size:
			var row := rng.randi() % ROWS_USED
			var offset := centre + (k - size * 0.5) * rng.randf_range(0.62, 0.9)
			if offset < 0.4 or offset > length - 0.4:
				continue
			var p := origin + along * offset
			p += out * (ArenaSurroundings.STAND_STEP * (row + 0.5) + rng.randf_range(-0.25, 0.25))
			p.y = ArenaSurroundings.STAND_RISE * (row + 1)
			if not _free(p, placed):
				continue
			# Face the statue at the middle of the square: model front is +Z.
			var to_centre := Vector3(-p.x, 0.0, -p.z).normalized()
			var basis := Basis.looking_at(to_centre, Vector3.UP, true)
			basis = basis.rotated(Vector3.UP, rng.randf_range(-0.25, 0.25))
			placed.append({"position": p, "basis": basis.scaled(Vector3.ONE * rng.randf_range(0.93, 1.06))})
	return placed


func _free(p: Vector3, placed: Array) -> bool:
	for other in placed:
		if Vector2(p.x, p.z).distance_to(Vector2(other.position.x, other.position.z)) < MIN_GAP:
			return false
	return true


func _build_multimesh(model: Dictionary, spots: Array, index: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = model.mesh
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(spots[i].basis, spots[i].position))
		# r phase, g speed, b outfit/tint seed.
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), rng.randf(), 0.0))
	var node := MultiMeshInstance3D.new()
	node.name = "Crowd_" + str(model.name)
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if model.texture != null:
		material.set_shader_parameter("albedo_tex", model.texture)
	node.material_override = material
	add_child(node)
	models.append(node)
