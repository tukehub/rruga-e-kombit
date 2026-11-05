@tool
extends Node3D
class_name PineForestMultiMesh
## Builds from supplied real tree positions; it never randomly plants on the road.
const TREE_SCENE: PackedScene = preload("res://assets/trees/pine_tree_01_mobile.glb")
const CHUNK_SIZE := 160.0
var planted_transforms: Array[Transform3D] = []

func build_forest(transforms: Array[Transform3D]) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    planted_transforms = transforms.duplicate()
    if transforms.is_empty():
        return
    var root := TREE_SCENE.instantiate()
    var parts: Array = []
    _collect_meshes(root, Transform3D.IDENTITY, parts)
    var chunks := {}
    for tree in transforms:
        var key := Vector2i(floori(tree.origin.x / CHUNK_SIZE), floori(tree.origin.z / CHUNK_SIZE))
        if not chunks.has(key):
            chunks[key] = []
        chunks[key].append(tree)
    for key: Vector2i in chunks:
        var origin := Vector3((key.x + 0.5) * CHUNK_SIZE, 0, (key.y + 0.5) * CHUNK_SIZE)
        for part in parts:
            var mesh: ArrayMesh = part[0].duplicate(true)
            for surface in mesh.get_surface_count():
                var source := mesh.surface_get_material(surface)
                if source is BaseMaterial3D:
                    var material: BaseMaterial3D = source.duplicate()
                    var material_name := material.resource_name.to_lower()
                    if "needle" in material_name or "foliage" in material_name or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
                        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
                        material.alpha_scissor_threshold = 0.5
                        material.cull_mode = BaseMaterial3D.CULL_DISABLED
                    mesh.surface_set_material(surface, material)
            var mm := MultiMesh.new()
            mm.transform_format = MultiMesh.TRANSFORM_3D
            mm.mesh = mesh
            mm.instance_count = chunks[key].size()
            for i in mm.instance_count:
                var t: Transform3D = chunks[key][i] * part[1]
                t.origin -= origin
                mm.set_instance_transform(i, t)
            var node := MultiMeshInstance3D.new()
            node.name = "PineChunk_%d_%d" % [key.x, key.y]
            node.position = origin
            node.multimesh = mm
            node.visibility_range_end = 220.0
            node.visibility_range_end_margin = 25.0
            # Mobile performance: no per-tree dynamic shadow pass.
            node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(node)
    root.free()

func _collect_meshes(node: Node, parent_transform: Transform3D, parts: Array) -> void:
    var t := parent_transform
    if node is Node3D:
        t = parent_transform * node.transform
    if node is MeshInstance3D and node.mesh != null:
        parts.append([node.mesh, t])
    for child in node.get_children():
        _collect_meshes(child, t, parts)
