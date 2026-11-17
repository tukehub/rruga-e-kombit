class_name CrowdSpawner
extends Node3D
## Spectators around Skanderbeg Square, packed in groups along the first two
## rows of the grandstands outside the wall, facing the statue. Models come
## from CROWD_DIR (tools/optimize_crowd.py writes them); there is one
## MultiMeshInstance3D per model per stand, so stands out of view are culled
## and far stands drop to the meshes' automatic LODs. crowd_spectator.gdshader
## animates them, no skeletons.
## Barrier geometry comes from Arena (HALF_X x HALF_Z rounded rectangle,
## CORNER radius); the stands from ArenaSurroundings.stand_segments().

const CROWD_DIR := "res://assets/models/crowd/"
const SHADER := preload("res://shaders/crowd_spectator.gdshader")
const MIN_GAP := 0.62              # metres between two people's feet
const ROWS_USED := 2               # front rows of the stands only

## People per quality preset; the stands hold ~1,400 at most.
@export var counts := {"low": 260, "medium": 420, "high": 620}
@export var cluster_size := Vector2i(6, 20)
@export var cluster_gap := Vector2(0.8, 3.5)    # metres between two groups
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
	var count := int(counts.get(Quality.preset, counts.medium))
	var spots := _scatter(count)
	spectators = spots.size()
	# Deal the people out across the models, one MultiMesh per model per stand.
	var chunks := {}
	for spot in spots:
		var key := Vector2i(rng.randi() % meshes.size(), int(spot.stand))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(spot)
	var keys := chunks.keys()
	keys.sort()
	for key in keys:
		_build_multimesh(meshes[key.x], chunks[key], key.y)


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


## Groups of people along the front stand rows: [{position, basis, stand}].
## Every stand row is filled with groups and gaps, then whole groups are
## dropped at random until `count` remain, so it stays clustered, not thin.
func _scatter(count: int) -> Array:
	var segments := ArenaSurroundings.stand_segments(Arena.HALF_X, Arena.HALF_Z, Arena.CORNER)
	var groups: Array = []
	for stand in segments.size():
		var seg: Array = segments[stand]
		var origin: Vector3 = seg[0]
		var along: Vector3 = seg[1]
		var out: Vector3 = seg[2]
		var length: float = seg[3]
		for row in ROWS_USED:
			var at := rng.randf_range(0.4, 2.0)
			while at < length - 0.4:
				var group: Array = []
				for k in rng.randi_range(cluster_size.x, cluster_size.y):
					if at > length - 0.4:
						break
					var p := origin + along * at
					p += out * (ArenaSurroundings.STAND_STEP * (row + 0.5) + rng.randf_range(-0.22, 0.22))
					p.y = ArenaSurroundings.STAND_RISE * (row + 1)
					# Face the statue at the middle of the square: model front is +Z.
					var to_centre := Vector3(-p.x, 0.0, -p.z).normalized()
					var basis := Basis.looking_at(to_centre, Vector3.UP, true)
					basis = basis.rotated(Vector3.UP, rng.randf_range(-0.3, 0.3))
					group.append({"position": p, "stand": stand,
						"basis": basis.scaled(Vector3.ONE * rng.randf_range(0.93, 1.06))})
					at += rng.randf_range(0.62, 0.82)
				groups.append(group)
				at += rng.randf_range(cluster_gap.x, cluster_gap.y)
	var total := 0
	for g in groups:
		total += g.size()
	while total > count and not groups.is_empty():
		var drop: Array = groups.pop_at(rng.randi() % groups.size())
		total -= drop.size()
	var placed: Array = []
	for g in groups:
		for spot in g:
			if _free(spot.position, placed):
				placed.append(spot)
	return placed


func _free(p: Vector3, placed: Array) -> bool:
	for other in placed:
		if Vector2(p.x, p.z).distance_to(Vector2(other.position.x, other.position.z)) < MIN_GAP:
			return false
	return true


func _build_multimesh(model: Dictionary, spots: Array, stand: int) -> void:
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
	node.name = "Crowd_%s_%d" % [model.name, stand]
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if model.texture != null:
		material.set_shader_parameter("albedo_tex", model.texture)
	node.material_override = material
	add_child(node)
	models.append(node)
