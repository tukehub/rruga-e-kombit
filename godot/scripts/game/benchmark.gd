class_name RaceBenchmark
extends RefCounted
## Writes measured frame/process/GPU samples after world loading and warm-up.
## Hardware identity is included so desktop results cannot be mistaken for phone results.

static func _stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	var values := samples.duplicate()
	values.sort()
	var sum := 0.0
	for value in values:
		sum += value
	return {"samples": values.size(), "mean_ms": sum / values.size(),
		"median_ms": values[values.size() / 2],
		"p95_ms": values[mini(values.size() - 1, int(values.size() * 0.95))],
		"max_ms": values[-1]}

static func run(tree: SceneTree, seconds: float) -> void:
	while Game._loading or Game.current != "race":
		await tree.process_frame
	var vp := tree.root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var warmup := Time.get_ticks_msec()
	while Time.get_ticks_msec() - warmup < 3000:
		await tree.process_frame
	var frame: Array[float] = []
	var process: Array[float] = []
	var physics: Array[float] = []
	var gpu: Array[float] = []
	var start := Time.get_ticks_msec()
	var previous := Time.get_ticks_usec()
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		frame.append((now - previous) / 1000.0)
		previous = now
		process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
	var report := {"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"model": OS.get_model_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "quality": Quality.preset,
		"resolution": str(tree.root.size), "seconds": seconds,
		"frame": _stats(frame), "process": _stats(process), "physics": _stats(physics), "gpu_time": _stats(gpu)}
	var file := FileAccess.open("user://profile.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PROFILE: ", JSON.stringify(report))
	tree.quit()
