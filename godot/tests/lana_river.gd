extends Node
## Regression checks against the generated scene geometry and current track.

func _ready() -> void:
	Quality.set_preset("low")
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.load_city("tirane", load("res://assets/cities/tirane/splat.png"))
	var river := terrain.get_node("LanaRiverAndBridge")
	var water := river.get_node("LanaWater") as MeshInstance3D
	var vertices: PackedVector3Array = water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var checked := 0
	for v in vertices:
		if LanaRiver._cross_section(Vector2(v.x, v.z)).y < 0.95:
			continue
		assert(v.y > _rendered_ground(terrain, v.x, v.z) + 0.05, "Lana water must remain above the carved terrain")
		checked += 1
	assert(checked > 50, "the visible water must contain a long enough channel")
	var track := RaceTrack.load_city("tirane")
	var rails := river.get_node("BridgeRails") as MultiMeshInstance3D
	assert(rails.multimesh.instance_count == 2)
	for rail: Transform3D in river.rail_transforms:
		for offset in [-12.0, 0.0, 12.0]:
			var p := rail * Vector3(0, 0, offset)
			var nearest := track.nearest(p.x, p.z, 30.0)
			assert(nearest >= 0)
			assert(Vector2(p.x - track.X[nearest], p.z - track.Z[nearest]).length() > track.half_w + RoadMesh.KERB_W, "bridge rails must stay outside the road")
			assert(absf(p.y - track.Y[nearest] - 0.98) < 0.25, "bridge rails must follow the road slope")
	assert(river.find_children("*", "CollisionObject3D", true, false).is_empty(), "river must not add physical obstacles")
	print("LANA: ", checked, " water vertices above terrain; bridge rails clear road and follow slope")
	get_tree().quit()


func _rendered_ground(terrain: Terrain, x: float, z: float) -> float:
	var grid: Dictionary = terrain.near
	var cell := float(grid.cell)
	var fx := (x - float(grid.x0)) / cell
	var fz := (z - float(grid.z0)) / cell
	var gx := floori(fx)
	var gz := floori(fz)
	var cx := gx / Terrain.CHUNK
	var cz := gz / Terrain.CHUNK
	var chunks_per_side := (int(grid.n) - 1) / Terrain.CHUNK
	var chunk := terrain.chunks[cz * chunks_per_side + cx]
	var vertices: PackedVector3Array = chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var index := (gz % Terrain.CHUNK) * (Terrain.CHUNK + 1) + gx % Terrain.CHUNK
	var a := vertices[index].y + chunk.position.y
	var b := vertices[index + 1].y + chunk.position.y
	var c := vertices[index + Terrain.CHUNK + 1].y + chunk.position.y
	var d := vertices[index + Terrain.CHUNK + 2].y + chunk.position.y
	var u := fx - gx
	var v := fz - gz
	if u + v <= 1.0:
		return a * (1.0 - u - v) + b * u + c * v
	return d * (u + v - 1.0) + c * (1.0 - u) + b * (1.0 - v)
