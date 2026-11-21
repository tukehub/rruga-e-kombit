class_name Palms
extends Node3D
## Procedural date palms for a seafront promenade (props.json "palms":
## [x, y, z, scale, yaw]). Two shared meshes, a slightly leaning tapered trunk
## and a crown of split fan fronds, drawn as two MultiMeshes: two draw calls
## for the whole promenade. No textures.

const TRUNK_HEIGHT := 7.5


static func trunk_mesh() -> ArrayMesh:
	var st := LandmarkKit.begin()
	const RINGS := 18
	const SIDES := 8
	for row in RINGS:
		for col in SIDES:
			var a := _trunk_point(row, col, RINGS, SIDES)
			var b := _trunk_point(row, col + 1, RINGS, SIDES)
			var c := _trunk_point(row + 1, col + 1, RINGS, SIDES)
			var d := _trunk_point(row + 1, col, RINGS, SIDES)
			var bark := Color("#72604d").lerp(Color("#9c8264"), 0.48 + 0.36 * sin(col * 8.17 + row * 6.23))
			if row % 3 == 1:
				bark = bark.darkened(0.20)
			LandmarkKit.quad_facing(st, a, b, c, d, bark, Vector3(cos(TAU * col / SIDES), 0, sin(TAU * col / SIDES)))
	return st.commit()


static func _trunk_point(row: int, col: int, rings: int, sides: int) -> Vector3:
	var t := float(row) / rings
	var yaw := TAU * (float(col) + (0.18 if row % 2 == 0 else 0.0)) / sides
	var flare := 0.19 * exp(-t * 17.0) + 0.07 * pow(t, 12.0)
	var scars := 0.018 * cos(col * TAU * 3.0 / sides + row * 4.7) + 0.028 * (row % 3)
	var radius := lerpf(0.22, 0.145, t) + flare + scars
	return Vector3(0.55 * t * t + cos(yaw) * radius, t * TRUNK_HEIGHT, sin(yaw) * radius)


static func crown_mesh() -> ArrayMesh:
	var st := LandmarkKit.begin()
	var crown := Vector3(0.55, TRUNK_HEIGHT, 0)
	for f in 18:
		var dry := f >= 15
		var angle := f * 2.399963 + 0.11 * sin(f * 4.5)
		var direction := Vector3(cos(angle), 0, sin(angle))
		var side := Vector3(-direction.z, 0, direction.x)
		var tier := float(f % 5) / 4.0
		var rise := lerpf(1.40, -0.56, tier) if not dry else -1.05
		var span := (1.62 + 0.40 * sin(f * 2.14)) * (0.76 if dry else 1.0)
		var split := crown + direction * span + Vector3.UP * rise
		var color := Color("#3f572e").lerp(Color("#7f9347"), 0.55 + 0.38 * cos(f * 4.7))
		if dry:
			color = Color("#8e6842").lerp(Color("#b18b56"), tier)
		LandmarkKit.tube(st, crown - Vector3.UP * 0.18, split, 0.067, 0.025, color.darkened(0.25), 4)
		# Fan palms divide into narrow, folded leaflets. Lower tiers droop
		# past the living crown and show the tawny fronds from the road.
		var previous_web := split
		for blade in 7:
			var fan := (blade - 3) / 3.0
			var ray := (direction + side * fan * 1.25).normalized()
			var lateral := Vector3(-ray.z, 0, ray.x)
			var length := (1.73 - 0.50 * absf(fan)) * (0.85 + 0.24 * sin(f * 2.0 + blade * 4.2))
			var fold := split + ray * (length * 0.45) + Vector3.UP * (0.27 - tier * 0.44)
			var tip := split + ray * length + Vector3.UP * (-0.32 - tier * 0.70 if not dry else -1.18)
			var width := 0.107 - 0.025 * absf(fan)
			var tint := color.lightened(0.08 * (1.0 + sin(blade * 3.1)))
			var web := fold.lerp(tip, 0.31)
			if blade > 0:
				LandmarkKit.quad_facing(st, split, previous_web, web, web, color.darkened(0.08), Vector3.UP)
			previous_web = web
			LandmarkKit.quad_facing(st, split, fold - lateral * width, tip, fold + Vector3.UP * 0.035, tint, Vector3.UP)
			LandmarkKit.quad_facing(st, split, fold + Vector3.UP * 0.035, tip, fold + lateral * width, tint.darkened(0.17), Vector3.UP)
	return st.commit()


func build(entries: Array) -> void:
	if entries.is_empty():
		return
	name = "Palms"
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.vertex_color_use_as_albedo = true
	trunk_mat.vertex_color_is_srgb = true
	trunk_mat.roughness = 0.9
	var crown_mat := StandardMaterial3D.new()
	crown_mat.vertex_color_use_as_albedo = true
	crown_mat.vertex_color_is_srgb = true
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
