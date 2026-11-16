extends Node3D
## One continuous chevron band along the outside of every bend, from where
## the turn starts to where it ends, just beyond the barrier, on posts. The
## chevrons point the way the race goes, so the band reads as the bend
## itself. The whole route is one mesh and one batch of posts.

const Guide = preload("res://scripts/sim/route_guide.gd")
const BAND_SHADER := preload("res://shaders/turn_band.gdshader")
const OUTSIDE := 1.75        # metres beyond the road edge
const LEAD := 8.0            # the band starts this far before the bend and ends as far after
const STEP := 1.0            # metres between band vertices, along the road centre
const BOTTOM := 0.55         # band height above the ground
const TOP := 1.75
const CHEVRON := 1.4         # metres of band per chevron
const POST_EVERY := 10.0

var band: MeshInstance3D
var posts: MultiMeshInstance3D
## One entry per bend: {"turn", "from", "to" (lap metres), "d", "points" (band bottoms)}.
var bands: Array[Dictionary] = []


func build(track: RaceTrack, guide: Guide, height_at := Callable()) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post_transforms: Array[Transform3D] = []
	for turn: Dictionary in guide.turns:
		var from := float(turn.start) - LEAD
		var length := float(turn.span) + LEAD * 2.0
		var d := -float(turn.side) * (track.half_w + OUTSIDE)
		var count := maxi(2, ceili(length / STEP) + 1)
		var points: Array[Vector3] = []
		for i in count:
			var s := from + length * float(i) / float(count - 1)
			var p := track.pos(s, d)
			if height_at.is_valid():
				p.y = maxf(p.y, float(height_at.call(p.x, p.z)))
			points.append(p)
		# A strip of quads; u runs along the race direction in chevrons.
		var u := 0.0
		for i in count - 1:
			var a := points[i]
			var b := points[i + 1]
			var next_u := u + a.distance_to(b) / CHEVRON
			var quad := [a + Vector3.UP * BOTTOM, b + Vector3.UP * BOTTOM, b + Vector3.UP * TOP, a + Vector3.UP * TOP]
			var uvs := [Vector2(u, 1.0), Vector2(next_u, 1.0), Vector2(next_u, 0.0), Vector2(u, 0.0)]
			var normal := (b - a).cross(Vector3.UP).normalized()
			for k in [0, 1, 2, 0, 2, 3]:
				st.set_normal(normal)
				st.set_uv(uvs[k])
				st.add_vertex(quad[k])
			u = next_u
		var travelled := 0.0
		var next_post := 0.0
		for i in count:
			if i > 0:
				travelled += points[i - 1].distance_to(points[i])
			if travelled >= next_post or i == count - 1:
				post_transforms.append(Transform3D(Basis.IDENTITY, points[i] + Vector3.UP * 0.6))
				next_post = travelled + POST_EVERY
		bands.append({"turn": turn, "from": track.mod_s(from), "to": track.mod_s(from + length), "length": length, "d": d, "points": points})
	band = MeshInstance3D.new()
	band.name = "CornerBands"
	band.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = BAND_SHADER
	band.material_override = material
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.045
	pole_mesh.bottom_radius = 0.055
	pole_mesh.height = 1.2
	pole_mesh.radial_segments = 6
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.16, 0.17, 0.17)
	pole_mat.roughness = 0.85
	pole_mesh.material = pole_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pole_mesh
	mm.instance_count = post_transforms.size()
	for i in post_transforms.size():
		mm.set_instance_transform(i, post_transforms[i])
	posts = MultiMeshInstance3D.new()
	posts.name = "CornerPosts"
	posts.multimesh = mm
	posts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(posts)
