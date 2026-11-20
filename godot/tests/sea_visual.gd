extends Node
## Optional rendered check of Vlorë's bay (needs a real or software Vulkan
## device): the production race scene, framed from the road nearest the water
## and from above the shore. Captures go to user://shots/sea_*.png.
##   godot --path godot --rendering-method mobile res://tests/sea_visual.tscn

var scene: RaceScene
var camera: Camera3D
var views: Array = []
var frame := 0


func _ready() -> void:
	Quality.set_preset("medium")
	Game.race_opts.city = "vlore"
	Game.race_opts.env = "day"
	scene = load("res://scenes/race.tscn").instantiate()
	add_child(scene)
	assert(scene.sea != null, "Vlorë needs its sea")
	# The road sample closest to open water, and the direction to it.
	var best := INF
	var road := Vector3.ZERO
	var water := Vector3.ZERO
	for i in range(0, scene.track.M, 3):
		var p := Vector3(scene.track.X[i], scene.track.Y[i], scene.track.Z[i])
		for a in 24:
			var dir := Vector3(cos(a * TAU / 24.0), 0.0, sin(a * TAU / 24.0))
			for r in range(40, 700, 30):
				var q := p + dir * r
				if scene.terrain.is_water(q.x, q.z):
					if r < best:
						best = r
						road = p
						water = q
					break
	assert(best < INF, "the Vlorë loop should see the bay")
	var seaward := (water - road).normalized()
	var surface := scene.terrain.water_surface
	views = [
		{"name": "road", "eye": road + Vector3(0, 6, 0) - seaward * 10.0, "at": Vector3(water.x, surface, water.z) + seaward * 150.0},
		{"name": "shore", "eye": Vector3(water.x, surface + 35.0, water.z) - seaward * 120.0, "at": Vector3(water.x, surface, water.z) + seaward * 60.0},
		{"name": "bay", "eye": road + Vector3(0, 220, 0) - seaward * 250.0, "at": Vector3(water.x, surface, water.z) + seaward * 900.0},
	]
	# Lungomare: along the promenade at driver height, and from above the
	# apartment blocks toward the bay.
	var palms := scene.props.get_node_or_null("Palms")
	assert(palms != null, "Lungomare needs its palms")
	var crowns := palms.get_node("PalmCrowns") as MultiMeshInstance3D
	var mid := crowns.multimesh.get_instance_transform(crowns.multimesh.instance_count / 2).origin
	var i := scene.track.nearest(mid.x, mid.z, 80.0)
	var ahead := (i + 45) % scene.track.M
	var at_road := Vector3(scene.track.X[i], scene.track.Y[i], scene.track.Z[i])
	var at_ahead := Vector3(scene.track.X[ahead], scene.track.Y[ahead], scene.track.Z[ahead])
	var to_sea := (mid - at_road)
	to_sea.y = 0.0
	to_sea = to_sea.normalized()
	views.append({"name": "lungomare", "eye": at_road + Vector3(0, 2.2, 0) - (at_ahead - at_road).normalized() * 12.0, "at": at_ahead + Vector3(0, 2.0, 0)})
	views.append({"name": "lungomare_high", "eye": at_road - to_sea * 140.0 + Vector3(0, 75, 0), "at": at_road + to_sea * 60.0})
	views.append({"name": "lungomare_side", "eye": at_road + to_sea * 2.0 + Vector3(0, 2.0, 0), "at": at_road - to_sea * 60.0 + Vector3(0, 14, 0)})
	print("SEA VISUAL: shore ", best, " m from the road at ", road)
	camera = Camera3D.new()
	camera.far = 6000.0
	scene.add_child(camera)
	camera.make_current()


func _process(_dt: float) -> void:
	frame += 1
	scene.set_process(false)
	camera.make_current()
	var view_i := (frame - 20) / 10
	if frame < 20 or view_i >= views.size():
		if view_i >= views.size():
			print("SEA VISUAL: ", views.size(), " views; renderer=", RenderingServer.get_current_rendering_method())
			get_tree().quit()
		return
	var v: Dictionary = views[view_i]
	camera.position = v.eye
	camera.look_at(v.at)
	if (frame - 20) % 10 == 9:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://shots")
		get_viewport().get_texture().get_image().save_png("user://shots/sea_%s.png" % v.name)
