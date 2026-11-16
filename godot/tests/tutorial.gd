extends Node
## Tutorial (README 6.4): the first cup event, one lap, rivals that never
## fire, set pickups, instructions by track position, and a way out.

const PROGRESS_FILE := "user://progress_tutorial_test.cfg"
const STEP := 1.0 / 60.0

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func wait_scene(want: String) -> bool:
	for i in 600:
		await get_tree().process_frame
		if Game.current == want and not Game._loading:
			return true
	check(false, "scene " + want)
	return false

func clean() -> void:
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(PROGRESS_FILE + suffix):
			DirAccess.remove_absolute(PROGRESS_FILE + suffix)

func _ready() -> void:
	Quality.set_preset("low")
	var sound := Sfx.enabled
	Sfx.enabled = false
	var real_progress: String = Progress.path
	clean()
	Progress.path = PROGRESS_FILE
	Progress.load_progress()
	var saved_opts := Game.race_opts.duplicate()

	# It is the first event of the cup, one lap, easy, with a goal like the rest.
	var event: Dictionary = Data.CUPS.tirana[0]
	check(bool(event.get("tutorial", false)) and int(event.laps) == 1 and int(event.diff) == 0 and not bool(event.reverse), "the tutorial is the cup's first event: one lap, easy rivals")
	check(Data.CUPS.tirana.filter(func(e: Dictionary) -> bool: return bool(e.get("tutorial", false))).size() == 1, "there is one tutorial")

	# The simulation: set pickups, no adaptive director, bots that never fire.
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 8, "laps": 1, "tutorial": true})
	check(race.tutorial and race.pickup_director == null, "the tutorial race keeps its own pickups")
	var stations := []
	for p in race.pickups:
		if stations.is_empty() or absf(float(stations[-1].s) - float(p.s)) > 1.0:
			stations.append({"s": p.s, "types": []})
		stations[-1].types.append(p.type)
	for i in stations.size():
		check(stations[i].types.size() == 3 and stations[i].types.all(func(t: String) -> bool: return t == Data.TUTORIAL_PICKUPS[i % Data.TUTORIAL_PICKUPS.size()]), "station %d carries the set pickup in every lane" % i)
	check(stations.size() >= 5 and stations[0].types[0] == "nitro" and stations[1].types[0] == "bolt", "the first pickups are nitro, then bolts")
	var again := Race.new(track, {"seed": 99, "laps": 1, "tutorial": true})
	check(again.pickups.map(func(p: Dictionary) -> String: return p.type) == race.pickups.map(func(p: Dictionary) -> String: return p.type), "the same pickups whatever the seed")
	race.started = true
	race.player.autopilot = true
	var fired_by_bots := 0
	var collected_by_bots := 0
	var steps := 0
	while not race.all_finished() and steps < 60 * 300:
		race.step(STEP)
		steps += 1
		for e in race.take_events():
			if e.t == "fire" and not e.car.is_player:
				fired_by_bots += 1
			if e.t == "pickup" and not e.car.is_player:
				collected_by_bots += 1
	check(race.all_finished() and fired_by_bots == 0, "a whole race goes by without a bot firing (%d pickups collected by bots)" % collected_by_bots)
	check(race.cars.all(func(c: CarState) -> bool: return c.is_player or c.skill_boosts == 0), "bots do not use the drift boost either")
	var normal := Race.new(track, {"seed": 8, "laps": 1})
	check(not normal.tutorial and normal.pickup_director != null and normal.pickups.map(func(p: Dictionary) -> String: return p.type) != race.pickups.map(func(p: Dictionary) -> String: return p.type), "other races keep random pickups and armed bots")

	# The game: the tutorial card, then the race with its instructions.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	var menu: Menu = Game._root.get_child(0)
	menu.show_page("cup")
	await get_tree().process_frame
	check((menu.cup_cards[0].find_child("EventName", true, false) as Label).text == "1 · Mësimi", "the first card is the tutorial")
	menu.cup_cards[0].pressed.emit()
	await wait_scene("race")
	var scene = Game._root.get_child(0)
	scene.set_process(false)
	check(scene.race.tutorial and scene.race.laps == 1, "the tutorial race: one lap")
	var prompt: TutorialPrompt = scene.tutorial_prompt
	check(prompt != null and not prompt.visible, "the instructions wait while the name cards are shown")
	scene.cam.intro_t = 2.79
	scene._process(1.0 / 60.0)
	check(scene.state == "countdown" and prompt.is_visible_in_tree() and prompt.label.text == Data.t("tutorial.welcome"), "then start with a welcome")
	check(prompt.skip.is_visible_in_tree() and prompt.skip.text == "Kalo", "with a way out")
	await get_tree().process_frame
	var banner := prompt.get_global_rect()
	var screen := (prompt.get_parent() as Control).get_global_rect()
	check(banner.size.x >= TutorialPrompt.WIDTH - 1.0 and absf(banner.get_center().x - screen.get_center().x) < 2.0 and banner.size.y < 120.0, "the instruction is a wide, short banner across the top centre: %s" % banner)
	var plan: Array = scene.tutorial_steps
	var places := plan.map(func(step: Dictionary) -> float: return float(step.at))
	var sorted := places.duplicate()
	sorted.sort()
	check(places == sorted and plan.size() >= 5, "the instructions run along the lap in order (%d)" % plan.size())
	var texts := plan.map(func(step: Dictionary) -> String: return str(step.text))
	check(texts[0] == Data.t("tutorial.steer.touch") or texts[0] == Data.t("tutorial.steer.tilt"), "steering comes first")
	check(texts.has(Data.t("tutorial.drift")) and texts[-1] == Data.t("tutorial.finish"), "the sharp bend is announced and the finish comes last")
	check(texts.any(func(t: String) -> bool: return t == Data.t("tutorial.pickup", Data.pw_name("nitro"))), "the first pickup is announced before it is reached")
	for i in range(1, places.size()):
		check(places[i] - places[i - 1] >= 70.0, "instructions are far enough apart to read")
	check(places[-1] < scene.race.L, "every instruction comes before the line")
	# They appear as the car gets to each place.
	scene.state = "race"
	scene.race.started = true
	scene.player.progress = float(plan[1].at) + 1.0
	scene._tutorial_update()
	check(prompt.label.text == str(plan[1].text) and scene._tutorial_next == 2, "an instruction shows when its place is reached")
	scene.player.progress = float(plan[3].at) + 1.0
	scene._tutorial_update()
	check(prompt.label.text == str(plan[3].text) and scene._tutorial_next == 4, "skipped places do not stall the instructions")
	# Picking something up says how to use it.
	scene.race.emit({"t": "pickup", "car": scene.player, "type": "bolt", "slot": 0, "replaced": "", "p": scene.race.pickups[0]})
	scene._events()
	check(prompt.label.text.begins_with(Data.t("tutorial.use", Data.pw_name("bolt"))) and prompt.label.text.ends_with(Data.t("tutorial.back")), "a bolt in hand: how to fire it, both ways")
	scene.race.emit({"t": "pickup", "car": scene.player, "type": "shield", "slot": 0, "replaced": "", "p": scene.race.pickups[0]})
	scene._events()
	check(prompt.label.text == Data.t("tutorial.use", Data.pw_name("shield")), "a shield: only forward")
	var rival: CarState = scene.race.cars.filter(func(c: CarState) -> bool: return not c.is_player)[0]
	scene.race.emit({"t": "pickup", "car": rival, "type": "eagle", "slot": 0, "replaced": "", "p": scene.race.pickups[0]})
	scene._events()
	check(prompt.label.text == Data.t("tutorial.use", Data.pw_name("shield")), "a rival's pickup changes nothing")
	scene.race.emit({"t": "drift_ready", "car": scene.player})
	scene._events()
	check(prompt.label.text == Data.t("tutorial.turbo"), "a charged turbo is explained")

	# Leaving it: back to the cup, nothing earned.
	prompt.skip.pressed.emit()
	await wait_scene("menu")
	menu = Game._root.get_child(0)
	check(menu.page == "cup" and Progress.stars(event.id) == 0 and Progress.fans == 0, "skipping returns to the cup with nothing earned")
	check(not get_tree().paused, "and the game is not left paused")

	# Another event has no instructions.
	menu.cup_cards[1].pressed.emit()
	await wait_scene("race")
	scene = Game._root.get_child(0)
	scene.set_process(false)
	check(scene.tutorial_prompt == null and not scene.race.tutorial and scene.tutorial_steps.is_empty(), "other events have no tutorial")
	scene.toggle_pause()
	for b in scene.find_children("*", "Button", true, false):
		if b.text == "Dil":
			b.pressed.emit()
	await wait_scene("menu")

	main.queue_free()
	Game.race_opts = saved_opts
	Progress.path = real_progress
	Progress.load_progress()
	clean()
	await get_tree().create_timer(0.3).timeout
	Sfx.enabled = sound
	if failures == 0:
		print("TUTORIAL: first event, set pickups, unarmed bots, instructions along the lap and skip passed")
	get_tree().quit(1 if failures else 0)
