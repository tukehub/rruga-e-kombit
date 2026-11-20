class_name Palms
extends Node3D
## Procedural date palms for a seafront promenade (props.json "palms":
## [x, y, z, scale, yaw]). Two shared meshes, a slightly leaning ringed trunk
## and a crown of drooping fronds, drawn as two MultiMeshes: two draw calls
## for the whole promenade. No textures.

const TRUNK_HEIGHT := 7.5
const FRONDS := 14


static func trunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 10
	var sides := 8
	for r in rings:
		for k in sides:
			for corner in [[0, 0], [1, 0], [1, 1], [0, 0], [1, 1], [0, 1]]:
				var t := float(r + corner[1]) / rings
				var a := TAU * float(k + corner[0]) / sides
				var radius := lerpf(0.30, 0.17, t) * (1.06 if (r + corner[1]) % 2 == 0 else 0.97)
				# A gentle lean, as seafront palms grow toward the light.
				var lean := Vector3(0.55 * t * t, 0, 0)
				var n := Vector3(cos(a), 0.15, sin(a)).normalized()
				st.set_color(Color("6b5640").lerp(Color("8a7458"), 0.5 + 0.5 * sin(t * 40.0)))
				st.set_normal(n)
				st.add_vertex(lean + Vector3(cos(a) * radius, t * TRUNK_HEIGHT, sin(a) * radius))
	return st.commit()


static func crown_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.55, TRUNK_HEIGHT, 0)
	var segs := 6
	for f in FRONDS:
		var yaw := TAU * f / FRONDS + 0.3 * sin(f * 2.3)
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var length := 4.6 + 0.6 * sin(f * 1.7)
		var rise := 1.6 + 0.4 * cos(f * 1.3)
		var green := Color("3f6b2a").lerp(Color("5f8a34"), 0.5 + 0.5 * sin(f * 3.1))
		for s in segs:
			var p := []
			for e in [s, s + 1]:
				var t := float(e) / segs
				# Up and out, then drooping past the tip.
				var centre := top + dir * (length * t) + Vector3.UP * (rise * t - 3.6 * t * t)
				var half := 0.75 * sin(PI * minf(1.0, t * 1.1 + 0.08))
				p.append([centre - side * half, centre + side * half])
			var n := (side.cross(p[1][0] - p[0][0])).normalized()
			if n.y < 0.0:
				n = -n
			st.set_color(green.darkened(0.15 + 0.25 * float(s) / segs))
			for v in [p[0][0], p[0][1], p[1][1], p[0][0], p[1][1], p[1][0]]:
				st.set_normal(n)
				st.add_vertex(v)
	return st.commit()


func build(entries: Array) -> void:
	if entries.is_empty():
		return
	name = "Palms"
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.vertex_color_use_as_albedo = true
	trunk_mat.roughness = 0.9
	var crown_mat := StandardMaterial3D.new()
	crown_mat.vertex_color_use_as_albedo = true
	crown_mat.roughness = 0.75
	crown_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var parts := [[trunk_mesh(), trunk_mat, "PalmTrunks"], [crown_mesh(), crown_mat, "PalmCrowns"]]
	for part in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = entries.size()
		for i in entries.size():
			var e: Array = entries[i]
			var s := float(e[3])
			var basis := Basis(Vector3.UP, float(e[4])).scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(float(e[0]), float(e[1]), float(e[2]))))
		var inst := MultiMeshInstance3D.new()
		inst.name = part[2]
		inst.multimesh = mm
		inst.material_override = part[1]
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Quality.preset == "high" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.visibility_range_end = maxf(400.0, float(Quality.p.props_dist) * 1.3)
		add_child(inst)
