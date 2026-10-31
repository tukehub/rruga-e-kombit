extends Node
## Entry point: boots the autoload flow and shows the menu.

func _ready() -> void:
	Game.set_root($Root)
	Quality.apply_viewport(get_viewport())
	if Settings.first_run:
		Settings.quality = "auto"
		Settings.first_run = false
		Settings.save()
	var start := "menu"
	var shots: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			start = a.substr(8)
		elif a.begins_with("--env="):
			Game.race_opts.env = a.substr(6)  # debug: force day/night/rain preset
		elif a.begins_with("--shots="):
			# debug: "--shots=2,8,20" saves user://shots/<scene>_<t>.png at those seconds, then quits
			for t in a.substr(8).split(","):
				shots.append(float(t))
	Game.goto(start)
	if not shots.is_empty():
		_debug_shots(start, shots)


func _debug_shots(tag: String, times: Array) -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	var t0 := Time.get_ticks_msec()
	for t in times:
		while Time.get_ticks_msec() - t0 < float(t) * 1000.0:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := "user://shots/%s_%04.1f.png" % [tag, float(t)]
		img.save_png(path)
		print("shot ", path, "  frame_ms avg=%.2f max=%.2f" % [Game.frame_ms_avg, Game.frame_ms_max])
		for n in get_tree().get_nodes_in_group("debug_ui"):
			print("  ui ", n.name, " pos=", n.position, " size=", n.size, " vp=", n.get_viewport_rect(), " parea=", n.get_parent_area_size())
	get_tree().quit()
