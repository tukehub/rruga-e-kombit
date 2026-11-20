extends Node
## Optional rendered check of Vlorë's landmarks (needs a real or software
## Vulkan device): each seen from the race line at driver height, and from a
## closer three-quarter view. Captures go to user://shots/vlore_*.png.
##   godot --path godot --rendering-method mobile res://tests/vlore_landmarks_visual.tscn

const IDS := ["flamurtari", "independence", "independence_museum", "flagpole_big"]

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
	var landmarks: Node3D = null
	for child in scene.props.get_children():
		if child is Landmarks:
			landmarks = child
	# Each model's front: the stadium facade looks along -X, the others -Z.
	var fronts := {"flamurtari": [Vector3(-72, 9, 6), Vector3.LEFT], "independence": [Vector3(0, 8, 0), Vector3.FORWARD],
		"independence_museum": [Vector3(0, 5, -6), Vector3.FORWARD], "flagpole_big": [Vector3(0, 20, 0), Vector3.FORWARD]}
	for id in IDS:
		var root := landmarks.get_node(id) as Node3D
		var face: Vector3 = root.global_transform * (fronts[id][0] as Vector3)
		var out: Vector3 = root.global_basis * (fronts[id][1] as Vector3)
		out.y = 0.0
		out = out.normalized()
		var side := out.cross(Vector3.UP)
		var i := scene.track.nearest(face.x, face.z, 400.0)
		var road := Vector3(scene.track.X[i], scene.track.Y[i], scene.track.Z[i])
		var ahead := Vector3(scene.track.X[(i + 30) % scene.track.M], scene.track.Y[i], scene.track.Z[(i + 30) % scene.track.M])
		views.append({"name": id + "_road", "eye": road + Vector3(0, 2.4, 0) - (ahead - road).normalized() * 30.0, "at": face})
		views.append({"name": id + "_near", "eye": face + out * 38.0 + side * 16.0 + Vector3(0, 3.0, 0), "at": face})
		print("LANDMARK: ", id, " front ", snappedf(Vector2(face.x - road.x, face.z - road.z).length(), 0.1), " m from the race line")
	camera = Camera3D.new()
	camera.far = 6000.0
	scene.add_child(camera)
	for layer in scene.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false


func _process(_dt: float) -> void:
	frame += 1
	scene.set_process(false)
	camera.make_current()
	var view_i := (frame - 20) / 10
	if frame < 20:
		return
	if view_i >= views.size():
		print("VLORE LANDMARKS VISUAL: ", views.size(), " views; renderer=", RenderingServer.get_current_rendering_method())
		get_tree().quit()
		return
	var v: Dictionary = views[view_i]
	camera.position = v.eye
	camera.look_at(v.at)
	if (frame - 20) % 10 == 9:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://shots")
		get_viewport().get_texture().get_image().save_png("user://shots/vlore_%s.png" % v.name)
