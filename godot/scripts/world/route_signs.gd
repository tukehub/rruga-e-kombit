extends Node3D
## Opaque batched chevrons outside the collision corridor. One shared board
## mesh/material and one pole mesh cover the whole route, including reverse.

const Guide = preload("res://scripts/sim/route_guide.gd")
const SIGN_SHADER := preload("res://shaders/turn_board.gdshader")
var boards: MultiMeshInstance3D
var posts: MultiMeshInstance3D
var placements: Array[Dictionary] = []

func build(track: RaceTrack, guide: Guide, height_at := Callable()) -> void:
	var sign_mesh := QuadMesh.new()
	sign_mesh.size = Vector2(2.2, 1.25)
	var material := ShaderMaterial.new()
	material.shader = SIGN_SHADER
	sign_mesh.material = material
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.045
	pole_mesh.bottom_radius = 0.055
	pole_mesh.height = 1.6
	pole_mesh.radial_segments = 6
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.16, 0.17, 0.17)
	pole_mat.roughness = 0.85
	pole_mesh.material = pole_mat
	var sign_transforms: Array[Transform3D] = []
	var pole_transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for turn: Dictionary in guide.turns:
		# Advance board plus three outside-corner chevrons. All are beyond the
		# barrier, and face the approach rather than the curved apex tangent.
		var approach := track.tangent(float(turn.start) - 24.0)
		approach.y = 0.0
		approach = approach.normalized()
		var facing := Basis.looking_at(approach, Vector3.UP)
		for offset: float in [-36.0, -6.0, 2.0, 10.0]:
			var s := float(turn.start) + offset if offset == -36.0 else float(turn.apex) + offset
			var d := -float(turn.side) * (track.half_w + 1.75)
			var p := track.pos(s, d)
			if height_at.is_valid():
				p.y = maxf(p.y, float(height_at.call(p.x, p.z)))
			var board := Transform3D(facing, p + Vector3.UP * 1.55)
			sign_transforms.append(board)
			pole_transforms.append(Transform3D(Basis.IDENTITY, p + Vector3.UP * 0.8))
			colors.append(Color(1.0 if int(turn.side) > 0 else 0.0, float(int(turn.severity) - 1) * 0.5, 0, 1))
			placements.append({"s": track.mod_s(s), "d": d, "direction": turn.direction, "transform": board})
	boards = _batch(sign_mesh, sign_transforms, colors)
	boards.name = "CornerChevrons"
	posts = _batch(pole_mesh, pole_transforms, [])
	posts.name = "CornerPosts"

func _batch(mesh: Mesh, transforms: Array[Transform3D], custom: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = not custom.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_custom_data:
			mm.set_instance_custom_data(i, custom[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Each batched route has a large AABB; vertex work is tiny (four board
	# vertices each) and opaque. Don't fade the entire route by its centre.
	add_child(node)
	return node
