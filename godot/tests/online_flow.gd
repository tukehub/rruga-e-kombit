extends Node
## Plan 7.3 end to end: the real menu hosts a lobby, a second phone (a
## scripted NetSession here) joins it over a socket, the host starts, the
## real race scene runs the online race in lockstep with the other phone
## through the countdown and into racing with no desync, the other phone
## leaves and a bot takes its car, and leaving returns to the menu. Also the
## new title page and the loading screen.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func wait_scene(want: String) -> bool:
	for i in 60:
		await get_tree().process_frame
		if Game.current == want and not Game._loading:
			return true
	check(false, "scene " + want)
	return false


func scripted(tick: int) -> PackedByteArray:
	var c := CarState.Ctrl.new()
	c.steer = sin(tick * 0.03) * 0.5
	c.gas = true
	return c.pack([])


func _ready() -> void:
	Quality.set_preset("low")
	var sound := Sfx.enabled
	Sfx.enabled = false
	Announcer.output = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait_scene("menu")
	var menu: Menu = Game._root.get_child(0)

	# --- the title page: badge, name, fans, settings, and four cards
	menu.show_page("title")
	check(menu._name_chip.text == Settings.display_name() and menu._fans_chip.text == str(Progress.fans), "the top bar shows your name and fans")
	for card in ["GarageCard", "CupButton", "OnlineCard", "RaceCard", "SettingsButton", "HelpButton"]:
		check(menu.pages.title.find_child(card, true, false) != null, "the title page has %s" % card)
	var options: int = menu.pages.title.find_children("*", "Button", true, false).size()
	check(options <= 8, "the title page keeps to a few big targets (%d buttons)" % options)
	(menu.pages.title.find_child("RaceCard", true, false) as Button).pressed.emit()
	check(menu.page == "race" and menu._direction.is_visible_in_tree() and menu.pages.race.find_child("StartRace", true, false) != null, "race options moved one tap deeper")
	menu.show_page("settings")
	check(menu.pages.settings.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.text == Data.t("credits.button")), "credits live in the settings")

	# --- the loading screen
	var ov: CanvasLayer = Game._transition_overlay("race")
	var ring := ov.find_child("LoadingRing", true, false) as LoadingRing
	check(ring != null and ring.custom_minimum_size.x >= 120.0, "the loading screen has the badge in a ring")
	add_child(ov)
	await get_tree().process_frame
	var vp := get_viewport().get_visible_rect().size
	var r: Rect2 = ring.get_global_rect()
	check(r.end.x > vp.x * 0.8 and r.end.y > vp.y * 0.75, "in the bottom right corner (%s of %s)" % [r, vp])
	ring.set_progress(0.5)
	ring.set_progress(0.3)
	for i in 120:
		ring.advance(1.0 / 60.0)
	check(is_equal_approx(ring.target, 0.5) and absf(ring.shown - 0.5) < 0.02, "the ring eases to the progress and never runs back")
	check((ov.find_child("LoadingInfo", true, false) as Label).text.contains(Data.city_name("tirane")), "it says what is loading")
	ov.queue_free()

	# --- typing the host's address on a phone keyboard
	check(Menu.normalize_address("192,168,1,20", "") == "192.168.1.20", "commas count as dots")
	check(Menu.normalize_address(" 192 168 1 20 ", "") == "192.168.1.20", "so do spaces")
	check(Menu.normalize_address("192..168.1.20.", "") == "192.168.1.20", "stray dots are tidied")
	check(Menu.normalize_address("20", "192.168.1.7") == "192.168.1.20", "the last number alone is enough on the same Wi-Fi")
	check(Menu.normalize_address("20", "") == "20", "without a network of our own it is left alone")
	check(Menu.normalize_address("127.0.0.1", "10.0.0.5") == "127.0.0.1", "a full address is kept")

	# --- hosting
	menu.show_page("online")
	check(menu._lobby_idle.visible and not menu._lobby_start.visible, "the lobby offers to create or join a game")
	var port := 40000 + randi() % 20000
	menu.lobby_host(port)
	check(Game.net != null and Game.net.is_host and menu._lobby_room.visible, "creating a game opens a room on this phone")
	check(menu._lobby_start.visible and menu._lobby_start.disabled, "alone, the race cannot start")
	var client := NetSession.new()
	check(client.join("Ben", "127.0.0.1", port, "benxi") == OK, "a second phone joins")
	for i in 300:
		client.poll()
		await get_tree().process_frame
		if Game.net.names.size() == 2 and client.slot == 1:
			break
	check(menu._lobby_rows[1].text.contains("Ben") and not menu._lobby_start.disabled, "the host sees them and may start: %s" % menu._lobby_rows[1].text)
	menu._lobby_bots = 1
	menu._refresh_lobby()
	menu.lobby_start()

	# --- racing: the other phone steps its own copy alongside the scene
	var other: NetRace = null
	for i in 600:
		for e in client.poll():
			if e.t == "start":
				var track := RaceTrack.load_city(str(client.config.city), bool(client.config.reverse))
				other = NetRace.new(Race.new(track, NetRace.race_options(client.config)), client.lockstep)
		if other != null:
			for k in 2:
				if not other.step(scripted(other.lockstep.tick)):
					break
		await get_tree().process_frame
		if other != null and Game.current == "race" and not Game._loading and Game._root.get_child(0).state == "race" and other.lockstep.tick > NetRace.COUNTDOWN_TICKS + 240:
			break
	var scene = Game._root.get_child(0)
	check(Game.current == "race" and scene.net != null, "the host's race scene runs the online race")
	check(scene.race.humans.size() == 2 and scene.race.cars.size() == 3 and scene.race.humans[1].name == "Ben", "two humans and one bot")
	check(scene.player == scene.race.humans[0] and other != null and other.local_car() == other.race.humans[1], "each phone drives its own car")
	check(scene.state == "race" and scene.race.started and other != null and other.race.started, "both left the countdown together")
	check(scene.net.lockstep.desync_tick < 0 and other != null and other.lockstep.desync_tick < 0, "no desync")
	check(other != null and scene.race.humans[1].progress > 20.0, "the other phone's car moves on the host's screen")
	check(scene._net_badge != null and scene._net_badge.is_visible_in_tree() and scene._net_badge.text.contains("ms"), "a badge shows the connection: %s" % (scene._net_badge.text if scene._net_badge else "none"))
	check(scene.input.control_rect("steer").size.y >= RaceInput.STEER_HEIGHT * 0.85, "the steering pad is the taller one")
	# Same tick, same race.
	if other != null:
		var tick := mini(scene.net.lockstep.tick, other.lockstep.tick)
		check(tick > NetRace.COUNTDOWN_TICKS, "both are racing")

	# --- the other phone stops sending: the race waits and says for whom
	for i in 60:
		await get_tree().process_frame
	check(scene._net_badge.text == Data.t("online.badge.waiting", "Ben"), "a silent phone is named while the race waits: %s" % scene._net_badge.text)

	# --- the other phone leaves; a bot takes its car
	client.close()
	for i in 240:
		await get_tree().process_frame
		if not scene.race.humans[1].is_player:
			break
	check(not scene.race.humans[1].is_player, "the leaver's car turns bot")
	check(scene.net.lockstep.desync_tick < 0, "still no desync")
	Game.leave_online()
	Game.goto("menu")
	await wait_scene("menu")
	check(Game.net == null, "leaving closes the session")

	Sfx.stop_all()
	await get_tree().create_timer(0.3).timeout
	Announcer.output = true
	Sfx.enabled = sound
	print("online_flow: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
