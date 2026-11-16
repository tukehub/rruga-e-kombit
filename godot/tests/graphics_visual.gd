extends Node3D
## Optional rendered section 3 smoke check. Run with --fixed-fps 60 and either
## --rendering-method mobile or forward_plus. Screenshots go to user://shots.

var scene: RaceScene
var frame := 0
var phases := ["drift", "wet_boost", "low"]
var phase := -1

func _ready() -> void:
	Sfx.enabled = false
	Quality.adaptive_enabled = false
	Quality.set_preset("medium")
	Game.race_opts.city = "tirane"
	Game.race_opts.env = "day"
	Game.race_opts.reverse = false
	scene = RaceScene.new()
	add_child(scene)
	scene.set_process(false)
	scene.state = "race"
	scene.race.started = true
	scene.cam.intro = false
	scene.cam.cabin = false
	# Compile the atlas-only shader even when the private GLB is absent.
	var swatch := MeshInstance3D.new()
	swatch.mesh = SphereMesh.new()
	var atlas := GradientTexture2D.new()
	atlas.gradient = Gradient.new()
	atlas.gradient.set_color(0, Color(0.02, 0.45, 0.9))
	atlas.gradient.set_color(1, Color(0.02, 0.45, 0.9))
	var material := ShaderMaterial.new()
	material.shader = CarVisual.SPORT_SHADER
	material.set_shader_parameter("atlas", atlas)
	swatch.material_override = material
	swatch.position = scene.track.pos(scene.player.s, scene.player.d + 4.0) + Vector3.UP
	add_child(swatch)

func _process(_dt: float) -> void:
	var next_phase := frame / 36
	if next_phase >= phases.size():
		scene.queue_free()
		set_process(false)
		await get_tree().process_frame
		Sfx.stop_all()
		get_tree().quit()
		return
	if next_phase != phase:
		phase = next_phase
		Quality.set_preset("low" if phase == 2 else "medium")
		scene.race.wet = phase == 1
		scene.road.set_wet(1.0 if phase == 1 else 0.0)
		for c in scene.race.cars:
			c.v = 48.0
			c.drift = 0.8
			c.nitro_t = 1.0 if phase == 1 else 0.0
			c.scrape = 0.6
			c.d = -4.0 if c.is_player else c.d
			scene.cars[scene.race.cars.find(c)].apply_state(c, scene.track, 0.0)
		var pos := scene.track.pos(scene.player.s, scene.player.d)
		scene.cam.global_position = pos - scene.track.tangent(scene.player.s) * 8.0 + Vector3(0, 3, 0)
		scene.cam.look_at(pos + scene.track.tangent(scene.player.s) * 12.0 + Vector3.UP)
	scene.speed_feedback.update(scene.player, true, 1.0 / 60.0)
	frame += 1
	if frame % 36 == 0:
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://shots")
		var path := "user://shots/graphics_%s_%s.png" % [Quality.renderer, phases[phase]]
		image.save_png(path)
		print("GRAPHICS VISUAL: ", path, " emitters=", scene.effects.driving.snapshot(), " speed=", scene.speed_feedback.strength)
