extends Node
## Tirana Cup (README 6.2): the events in Data.CUPS, the star rules, the cup
## page, playing an event with its own settings, and the stars it saves.

const PROGRESS_FILE := "user://progress_cup_test.cfg"

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

func button(root: Node, label: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n.text == label:
			return n
	return null

func clean() -> void:
	for suffix in ["", ".tmp", ".damaged"]:
		if FileAccess.file_exists(PROGRESS_FILE + suffix):
			DirAccess.remove_absolute(PROGRESS_FILE + suffix)

func outcome(place: int, extra := {}) -> Dictionary:
	var o := {"finished": true, "place": place, "hits": 0, "takedowns": 0, "wrecks": 0, "fans": 0}
	o.merge(extra, true)
	return o

func _ready() -> void:
	Quality.set_preset("low")
	var sound := Sfx.enabled
	Sfx.enabled = false
	var real_progress: String = Progress.path
	clean()
	Progress.path = PROGRESS_FILE
	Progress.load_progress()
	var saved_opts := Game.race_opts.duplicate()
	var saved_settings := [Settings.laps_override, Settings.env_override, Settings.difficulty, Settings.reverse_lap]

	# The events.
	var events: Array = Data.CUPS.tirana
	check(events.size() >= 4 and events.size() <= 6, "the Tirana Cup has 4 to 6 events")
	var ids := []
	for event: Dictionary in events:
		check(not ids.has(event.id), "event ids are unique")
		ids.append(event.id)
		check(int(event.laps) >= 1 and int(event.laps) <= 9 and int(event.diff) >= 0 and int(event.diff) <= 2, "%s has laps and a difficulty in range" % event.id)
		check(Data.ENV.has(event.env) and event.reverse is bool, "%s has known weather and a direction" % event.id)
		check(str(event.goal.kind) in ["clean", "hits", "wrecks", "fans"], "%s has a known goal" % event.id)
		check(Data.has_text("cup.event.%s.name" % event.id) and not Data.cup_goal_text(event).is_empty(), "%s has a name and a goal text" % event.id)
		check(Data.cup_event(event.id) == event, "%s can be found by id" % event.id)
	check(Data.cup_event("nope").is_empty(), "an unknown id finds nothing")
	check(events.any(func(e: Dictionary) -> bool: return e.reverse) and events.any(func(e: Dictionary) -> bool: return e.env != "day"), "the cup varies direction and weather")
	var diffs := events.map(func(e: Dictionary) -> int: return int(e.diff))
	var sorted_diffs := diffs.duplicate()
	sorted_diffs.sort()
	check(diffs == sorted_diffs and diffs[0] == 0 and diffs[-1] == 2, "the rivals get harder through the cup")

	# Star rules.
	var clean_event := {"id": "x", "goal": {"kind": "clean", "n": 0}}
	check(Data.cup_stars(clean_event, outcome(1)) == 3, "a clean win is three stars")
	check(Data.cup_stars(clean_event, outcome(1, {"wrecks": 1})) == 2, "a win that misses the goal is two")
	check(Data.cup_stars(clean_event, outcome(2)) == 1 and Data.cup_stars(clean_event, outcome(3)) == 1, "second and third are one star, goal or not")
	check(Data.cup_stars(clean_event, outcome(4)) == 0 and Data.cup_stars(clean_event, outcome(6)) == 0, "fourth and below earn none")
	check(Data.cup_stars(clean_event, outcome(1, {"finished": false})) == 0, "an unfinished race earns none")
	check(Data.cup_stars({}, outcome(1)) == 0, "no event, no stars")
	var hits := {"goal": {"kind": "hits", "n": 3}}
	check(Data.cup_goal_met(hits, outcome(1, {"hits": 3})) and not Data.cup_goal_met(hits, outcome(1, {"hits": 2})), "a hits goal counts hits")
	var wrecks := {"goal": {"kind": "wrecks", "n": 1}}
	check(Data.cup_goal_met(wrecks, outcome(1, {"takedowns": 1})) and not Data.cup_goal_met(wrecks, outcome(1, {"wrecks": 3})), "a wrecks goal counts rivals wrecked, not your own wrecks")
	var fans := {"goal": {"kind": "fans", "n": 700}}
	check(Data.cup_goal_met(fans, outcome(1, {"fans": 700})) and not Data.cup_goal_met(fans, outcome(1, {"fans": 699})), "a fans goal counts the race's fans")
	# Takedowns are counted by the simulation.
	var race := Race.new(RaceTrack.load_city("tirane"), {"seed": 3})
	race.started = true
	var rival: CarState = race.cars.filter(func(c: CarState) -> bool: return not c.is_player)[0]
	race.wreck(rival, race.player, "eagle")
	race.wreck(race.player, null, "wall")
	check(race.player.takedowns == 1 and race.player.wrecks == 1 and rival.takedowns == 0, "a wreck counts for the car that caused it")

	# The game: the cup page, an event, the stars.
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	var menu: Menu = Game._root.get_child(0)
	check(menu.page == "title" and menu._cup_button.is_visible_in_tree() and (menu._cup_button.get_meta(&"sub") as Label).text == "0/%d yje" % (events.size() * 3), "the title page offers the cup with the stars won so far")
	var race_card := menu.pages.title.find_child("RaceCard", true, false) as Button
	check(race_card != null and race_card.is_visible_in_tree(), "a free race is still one tap away")
	menu._cup_button.pressed.emit()
	await get_tree().process_frame
	check(menu.page == "cup" and menu.cup_cards.size() == events.size(), "the cup page shows a card per event")
	for i in events.size():
		var card := menu.cup_cards[i]
		var event: Dictionary = events[i]
		check((card.find_child("EventName", true, false) as Label).text == "%d · %s" % [i + 1, Data.t("cup.event.%s.name" % event.id)], "card %d names its event" % (i + 1))
		var conditions := (card.find_child("Conditions", true, false) as Label).text
		check(conditions.contains(Data.env_label(event.env)) and conditions.contains(Data.t("diff.%d" % event.diff)) and conditions.contains(Data.t("cup.laps", event.laps)) and conditions.contains(Data.t("cup.reverse")) == bool(event.reverse), "card %d lists laps, weather, rivals and direction" % (i + 1))
		check((card.find_child("Goal", true, false) as Label).text.contains(Data.cup_goal_text(event)), "card %d states its goal" % (i + 1))
		check((card.find_child("Stars", true, false) as StarRow).earned == 0 and not card.disabled, "card %d starts open, with no stars" % (i + 1))
	var cup_rect: Rect2 = menu.pages.cup.get_global_rect()
	for card in menu.cup_cards:
		check(cup_rect.encloses(card.get_global_rect()), "the cards fit on the screen")

	# Play the reversed event: two laps, normal rivals.
	var third_index := events.find(Data.cup_event("tirana_3"))
	var third: Dictionary = events[third_index]
	Game.race_opts.laps = 7
	Game.race_opts.env = "day"
	Game.race_opts.reverse = false
	Game.race_opts.diff = 0
	menu.cup_cards[third_index].pressed.emit()
	await wait_scene("race")
	var scene = Game._root.get_child(0)
	scene.set_process(false)
	check(str(Game.race_opts.event) == third.id, "the event is the one being played")
	check(scene.race.laps == int(third.laps) and scene.env_id == str(third.env) and scene.race.diff == Data.DIFFS[int(third.diff)], "the race takes the event's laps, weather and rivals")
	var forward := RaceTrack.load_city("tirane")
	check((scene.track.tangent(0.0).dot(forward.tangent(0.0)) < -0.99) == bool(third.reverse), "and its direction")
	check(Game.race_opts.laps == 7 and Game.race_opts.diff == 0 and not Game.race_opts.reverse, "the player's own race choices are untouched")
	check(Settings.laps_override == saved_settings[0] and Settings.difficulty == saved_settings[2], "and not saved over")
	# Win it, meeting the goal.
	var player: CarState = scene.player
	player.finished = true
	player.finish_time = 120.0
	player.takedowns = int(third.goal.n)
	player.fans = 400.0
	for c in scene.race.cars:
		if c != player:
			c.progress = -50.0
	scene.race.compute_order()
	check(player.place == 1, "the player is first")
	scene._show_results()
	await wait_scene("results")
	var result: Dictionary = Game.last_result
	check(str(result.event) == third.id and int(result.stars) == 3 and bool(result.goal_met) and int(result.stars_before) == 0, "a win that meets the goal earns three stars")
	check(Progress.stars(third.id) == 3 and Progress.fans == 400, "the stars and the fans are saved")
	var saved := ConfigFile.new()
	saved.load(PROGRESS_FILE)
	check(int(saved.get_value("progress", "cup_stars", {}).get(third.id, 0)) == 3, "on disk")
	var results: Results = Game._root.get_child(0)
	var texts := results.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	check(results.star_row != null and results.star_row.earned == 3, "the results show three stars")
	check(texts.has(("%s · %s" % [Data.t("cup.tirana.name"), Data.t("cup.event.%s.name" % third.id)]).to_upper()), "and name the event")
	var goal_line: String = (results.find_child("EventGoal", true, false) as Label).text
	check(goal_line.contains(Data.t("cup.goal_met")) and goal_line.contains(Data.t("cup.new_best")), "the goal is marked met, and a new best")

	# Again replays the same event; a worse result keeps the best.
	button(results, "Përsërit").pressed.emit()
	await wait_scene("race")
	scene = Game._root.get_child(0)
	scene.set_process(false)
	check(scene.race.laps == int(third.laps) and str(Game.race_opts.event) == third.id, "again replays the event")
	player = scene.player
	player.finished = true
	player.finish_time = 140.0
	for c in scene.race.cars:
		if c != player:
			c.finished = true
			c.finish_time = 100.0 + c.id
	scene.race.compute_order()
	scene._show_results()
	await wait_scene("results")
	check(int(Game.last_result.stars) == 0 and Progress.stars(third.id) == 3, "a last place keeps the earlier three stars")
	results = Game._root.get_child(0)
	check(not (results.find_child("EventGoal", true, false) as Label).text.contains(Data.t("cup.new_best")), "and is not a new best")

	# Back to the menu: the cup page, with the stars on its card.
	button(results, "Menyja").pressed.emit()
	await wait_scene("menu")
	menu = Game._root.get_child(0)
	check(menu.page == "cup", "after a cup race the menu opens on the cup")
	check((menu.cup_cards[third_index].find_child("Stars", true, false) as StarRow).earned == 3 and menu._cup_stars.text == "3 / %d" % (events.size() * 3), "the card and the total show the stars")
	menu.show_page("title")
	check((menu._cup_button.get_meta(&"sub") as Label).text == "3/%d yje" % (events.size() * 3), "the title page's cup card shows them too")
	# A free race leaves the cup behind.
	Game.race_opts.mode = "race"
	button(menu, "Nisu!").pressed.emit()
	await wait_scene("race")
	scene = Game._root.get_child(0)
	scene.set_process(false)
	check(str(Game.race_opts.event).is_empty() and scene.race.laps == 7 and scene.race.diff == Data.DIFFS[0], "a free race uses the player's own choices again")
	scene.toggle_pause()
	button(scene, "Dil").pressed.emit()
	await wait_scene("menu")
	check((Game._root.get_child(0) as Menu).page == "title", "after a free race the menu opens on the title")

	main.queue_free()
	Game.race_opts = saved_opts
	Settings.laps_override = saved_settings[0]
	Settings.env_override = saved_settings[1]
	Settings.difficulty = saved_settings[2]
	Settings.reverse_lap = saved_settings[3]
	Settings.save()
	Progress.path = real_progress
	Progress.load_progress()
	clean()
	await get_tree().create_timer(0.4).timeout
	Sfx.enabled = sound
	if failures == 0:
		print("CUP: events, star rules, cup page, event settings, stars saved and shown passed")
	get_tree().quit(1 if failures else 0)
