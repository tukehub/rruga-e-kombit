extends Node

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func wait_scene(want: String) -> bool:
	for i in 30:
		await get_tree().process_frame
		if Game.current == want and not Game._loading:
			return true
	check(false, "scene " + want)
	return false

func button(root: Node, label: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n.text == label:
			return n
	return null

func _ready() -> void:
	Quality.set_preset("low")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	var menu: Menu = Game._root.get_child(0)
	menu.show_page("city")
	menu.show_page("car")
	Game.race_opts.laps = 1
	button(menu, "Nisu!").pressed.emit()
	await wait_scene("race")
	var scene = Game._root.get_child(0)
	scene.set_process(false)
	scene.player.autopilot = true
	scene.input.gas = true
	scene.toggle_pause()
	check(scene.paused and not scene.input.gas, "pause resets input")
	scene.toggle_pause()
	# Exercise actual intro, countdown, race, finish and results hand-off.
	for batch in 120:
		for i in 600:
			scene._process(1.0 / 60.0)
			if scene.state == "results":
				break
		if scene.state == "results":
			break
		await get_tree().process_frame
	check(scene.player.finished, "player completes real race")
	await wait_scene("results")
	check(Game.last_result.get("rows", []).size() == 6, "six result rows")
	var results: Node = Game._root.get_child(0)
	button(results, "Përsërit").pressed.emit()
	await wait_scene("race")
	scene = Game._root.get_child(0)
	scene.toggle_pause()
	button(scene, "Dil").pressed.emit()
	await wait_scene("menu")
	check(not get_tree().paused, "return to menu unpauses")
	print("FLOW: menu -> race -> results -> retry -> quit -> menu; failures=", failures)
	Sfx.stop_all()
	main.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(1 if failures else 0)
