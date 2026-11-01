extends Node3D
## Optional rendered smoke test; run with Forward+ and a real/software Vulkan device.
var sky: SkyEnv
var camera: Camera3D
var frame := 0

func _ready() -> void:
	Quality.set_preset("medium")
	Quality.apply_viewport(get_viewport())
	sky = SkyEnv.new()
	add_child(sky)
	sky.apply("night")
	sky.transition_to("day", 2.0)
	camera = Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8, 4, 10)
	camera.look_at(Vector3(0, 1, 0))
	var car := CarVisual.new()
	add_child(car)
	car.setup(Data.CARS[0], Color("236b99"), true)
	car.set_night(1.0)
	var ground := MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(60, 60)
	ground.material_override = CarVisual._mk_simple(Color("202633"), 0.2, 0.08)
	add_child(ground)

func _process(_dt: float) -> void:
	frame += 1
	if frame == 5:
		sky.advance(1.0)
	if frame == 10:
		sky.advance(1.0)
	if frame in [4, 8, 12]:
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("user://shots")
		get_viewport().get_texture().get_image().save_png("user://shots/weather_%d.png" % frame)
	if frame == 13:
		print("WEATHER VISUAL: night -> blended sky -> day; renderer=", RenderingServer.get_current_rendering_method())
		get_tree().quit()
