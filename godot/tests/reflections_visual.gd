extends Node3D
## Render with --fixed-fps 60 --rendering-method mobile (or forward_plus).
var scene: RaceScene
var menu: Menu
var frame := 0
var phase := -1
var phases := ["garage", "day_off", "day", "landmark", "night", "low"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.enabled = false
	Quality.adaptive_enabled = false
	Quality.set_preset("medium")
	menu = Menu.new()
	add_child(menu)
	menu.ui.hide()
	menu.set_process(false)
	menu.garage_pivot.rotation.y = -0.7

func _process(_dt: float) -> void:
	var next := frame / 40
	if next >= phases.size():
		scene.queue_free()
		set_process(false)
		await get_tree().process_frame
		Sfx.stop_all()
		get_tree().quit()
		return
	if next != phase:
		phase = next
		if phase == 1:
			menu.free()
			Game.race_opts.city = "tirane"
			Game.race_opts.env = "day"
			Game.race_opts.reverse = false
			scene = RaceScene.new()
			add_child(scene)
			scene.set_process(false)
			scene.hud.center("", "", 0.0)
			scene.cam.intro = false
			scene.cam.cabin = false
		if phase > 0:
			Quality.set_preset("high" if phase == 3 else ("low" if phase == 5 else "medium"))
			if phase == 4:
				scene.sky.apply("night")
				scene._update_weather(0.0)
			var c := scene.player
			if phase == 3:
				var probe := scene.reflections.landmarks[1]
				var idx := scene.track.nearest(probe.position.x, probe.position.z)
				c.s = float(idx) * scene.track.ds
				c.d = -3.0
			var visual := scene.cars[scene.race.cars.find(c)]
			visual.apply_state(c, scene.track, 0.0)
			var pos := visual.global_position
			scene.cam.global_position = pos - scene.track.tangent(c.s) * 7.0 + scene.track.normal(c.s) * 3.0 + Vector3(0, 2.7, 0)
			scene.cam.look_at(pos + Vector3(0, 0.6, 0))
	if phase > 0:
		if scene.paused:
			scene.toggle_pause()
		if phase == 1:
			scene.reflections.hide()
		else:
			scene.reflections.show()
			scene.reflections.follow(scene.cars[scene.race.cars.find(scene.player)].global_position, 1.0 / 60.0)
	frame += 1
	if frame % 40 == 0:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://shots")
		var path := "user://shots/reflections_%s_%s.png" % [Quality.renderer, phases[phase]]
		image.save_png(path)
		print("REFLECTIONS VISUAL: ", path)
