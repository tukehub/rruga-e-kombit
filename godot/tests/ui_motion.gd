extends Node
## UI motion (README 5.2): the UiTheme helpers, animated menu pages, the
## scene transition fade, staggered result rows and standings.

const MenuScript = preload("res://scripts/ui/menu.gd")
const ResultsScript = preload("res://scripts/ui/results.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = control.size * 0.5
		control.gui_input.emit(event)

func _ready() -> void:
	var sound := Sfx.enabled
	Sfx.enabled = false

	# fade
	var box := ColorRect.new()
	box.size = Vector2(100, 40)
	box.position = Vector2(200, 100)
	check(UiTheme.fade(box, 0.25) == null and is_equal_approx(box.modulate.a, 0.25), "outside the tree a fade lands at once")
	add_child(box)
	# Let the start-up hitch pass before timing anything.
	for i in 5:
		await get_tree().process_frame
	var tween := UiTheme.fade(box, 1.0)
	check(tween != null and is_equal_approx(box.modulate.a, 0.25), "a fade starts from the current alpha")
	await wait(UiTheme.FADE_TIME * 0.4)
	check(box.modulate.a > 0.25 and box.modulate.a < 1.0, "a fade passes through the values between")
	await wait(UiTheme.FADE_TIME)
	check(is_equal_approx(box.modulate.a, 1.0), "a fade ends on its target")
	UiTheme.fade(box, 0.0)
	UiTheme.fade(box, 1.0)
	await wait(UiTheme.FADE_TIME * 1.5)
	check(is_equal_approx(box.modulate.a, 1.0), "a newer fade replaces the one in flight")

	# slide_in
	var rest := box.position
	UiTheme.slide_in(box, Vector2(48, 0))
	check(box.position.is_equal_approx(rest + Vector2(48, 0)) and is_zero_approx(box.modulate.a), "a slide starts offset and invisible")
	await wait(UiTheme.SLIDE_TIME * 0.4)
	check(box.position.x > rest.x and box.position.x < rest.x + 48.0 and box.modulate.a > 0.0, "a slide moves toward its place")
	UiTheme.slide_in(box, Vector2(48, 0))
	check(box.position.is_equal_approx(rest + Vector2(48, 0)), "restarting a slide keeps the true resting place")
	await wait(UiTheme.SLIDE_TIME * 1.4)
	check(box.position.is_equal_approx(rest) and is_equal_approx(box.modulate.a, 1.0), "a slide ends in place, fully visible")
	UiTheme.slide_in(box, Vector2(0, 30), UiTheme.SLIDE_TIME, 0.2)
	await wait(0.1)
	check(box.position.is_equal_approx(rest + Vector2(0, 30)), "a delayed slide waits")
	await wait(0.2 + UiTheme.SLIDE_TIME * 1.4)
	check(box.position.is_equal_approx(rest), "a delayed slide arrives")
	var loose := Control.new()
	loose.position = Vector2(5, 5)
	check(UiTheme.slide_in(loose) == null and loose.position == Vector2(5, 5) and loose.modulate.a == 1.0, "outside the tree a slide lands at once")
	loose.free()
	box.queue_free()

	# press
	var button := UiTheme.button("Provë")
	check(button.has_meta("press_motion"), "every themed button has the press motion")
	add_child(button)
	await get_tree().process_frame
	button.button_down.emit()
	await wait(UiTheme.PRESS_TIME * 2.5)
	check(is_equal_approx(button.scale.x, UiTheme.PRESS_SCALE) and UiTheme.PRESS_SCALE < 1.0 and button.pivot_offset.is_equal_approx(button.size * 0.5), "a pressed button gives a little, about its centre")
	button.button_up.emit()
	await wait(UiTheme.PRESS_TIME * 2.5)
	check(is_equal_approx(button.scale.x, 1.0), "a released button springs back")
	UiTheme.press(button)
	check(button.button_down.get_connections().size() == 1, "the press motion is attached once")
	button.queue_free()

	# Menu pages: the right page at once, its arrival animated.
	var menu: Menu = MenuScript.new()
	add_child(menu)
	await get_tree().process_frame
	await wait(UiTheme.SLIDE_TIME * 1.5)
	menu.show_page("settings")
	var settings: Control = menu.pages.settings
	check(settings.visible and not menu.pages.title.visible and menu.page == "settings", "the new page is the visible one immediately")
	check(is_zero_approx(settings.modulate.a) and settings.position.x > 20.0, "a page comes in from the right")
	await wait(UiTheme.SLIDE_TIME * 1.5)
	check(is_equal_approx(settings.modulate.a, 1.0) and settings.position.is_equal_approx(Vector2.ZERO), "the page settles in place")
	menu.show_page("settings")
	check(is_equal_approx(settings.modulate.a, 1.0), "showing the same page again does not replay the motion")
	menu.show_page("title")
	var title: Control = menu.pages.title
	check(title.visible and not settings.visible and title.position.x < -20.0, "going back to the title comes in from the left")
	menu.show_page("car")
	check(not title.visible and menu.pages.car.visible, "leaving a page mid-slide still hides it")
	menu.show_page("title")
	await wait(UiTheme.SLIDE_TIME * 1.5)
	check(title.position.is_equal_approx(Vector2.ZERO) and is_equal_approx(title.modulate.a, 1.0), "an interrupted page still settles in place")
	menu.queue_free()

	# Results: rows arrive one after another, first place first.
	var saved_result := Game.last_result
	var rows := []
	for i in 6:
		rows.append({"name": "Shofer %d" % i, "color": "ffffff", "is_player": i == 2, "finished": true, "time": 80.0 + i, "best_lap": 40.0 + i})
	Game.last_result = {"city": "tirane", "env": "day", "place": 3, "n": 6, "best_lap": 42.0, "time": 82.0, "rows": rows}
	var results: Results = ResultsScript.new()
	add_child(results)
	check(results.row_cells.size() == 6 and results.row_cells.all(func(cells: Array) -> bool: return cells.size() == 4), "every result row has its four cells")
	check(results.row_cells.all(func(cells: Array) -> bool: return cells.all(func(c: Control) -> bool: return is_zero_approx(c.modulate.a))), "result rows start hidden")
	await get_tree().process_frame
	await wait(0.12 + UiTheme.SLIDE_TIME * 0.9)
	var first: Control = results.row_cells[0][1]
	var last: Control = results.row_cells[5][1]
	check(first.modulate.a > 0.6 and last.modulate.a < 0.2, "the first row is in while the last is still to come")
	await wait(5 * ResultsScript.ROW_STAGGER + UiTheme.SLIDE_TIME)
	check(results.row_cells.all(func(cells: Array) -> bool: return cells.all(func(c: Control) -> bool: return is_equal_approx(c.modulate.a, 1.0))), "every row ends fully visible")
	var column_x: float = results.row_cells[0][1].position.x
	check(results.row_cells.all(func(cells: Array) -> bool: return is_equal_approx(cells[1].position.x, column_x)), "rows settle back into their column")
	results.queue_free()
	Game.last_result = saved_result

	# Standings: always the full list with names and metres apart.
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 31})
	race.started = true
	var hud := Hud.new()
	add_child(hud)
	hud.setup(race, race.player, track)
	hud._process(0.0)
	await get_tree().process_frame
	check(hud._board.get_child_count() == race.cars.size() and hud._standings.size.x >= Hud.STANDINGS_WIDTH, "the standings show every racer at full width")
	for row in hud._board.get_children():
		check(row.get_children().all(func(c: Control) -> bool: return c.visible), "each row shows place, colour, name and gap")
	check(hud._board_gaps.all(func(l: Label) -> bool: return l.text == Data.t("hud.you") or l.text.ends_with("m")), "gaps are in metres")
	hud.queue_free()

	# Scene changes fade through the loading cover.
	check(Game.TRANSITION_FADE_IN > 0.0 and Game.TRANSITION_FADE_OUT > 0.0 and Game.TRANSITION_FADE_IN + Game.TRANSITION_FADE_OUT < 0.6, "scene changes fade in and out, briefly")
	var root := Node.new()
	add_child(root)
	var old_root: Node = Game._root
	Game.set_root(root)
	var changed := []
	var note := func(scene: String) -> void: changed.append(scene)
	Game.scene_changed.connect(note)
	Game.goto("menu")
	var overlay := Game.get_node_or_null("TransitionOverlay")
	check(overlay != null, "a scene change puts up the cover")
	var cover := overlay.get_child(0) as ColorRect
	check(is_zero_approx(cover.modulate.a) and cover.mouse_filter == Control.MOUSE_FILTER_STOP, "the cover starts clear and blocks touches while loading")
	await wait(Game.TRANSITION_FADE_IN * 0.5)
	check(root.get_child_count() == 0 and cover.modulate.a > 0.0 and cover.modulate.a < 1.0, "the cover fades in before the scene is swapped")
	while changed.is_empty():
		await get_tree().process_frame
	check(changed == ["menu"] and root.get_child_count() == 1, "the new scene is in place")
	check(is_instance_valid(overlay) and cover.mouse_filter == Control.MOUSE_FILTER_IGNORE and cover.modulate.a > 0.5, "the cover is still fading off and lets touches through")
	await wait(Game.TRANSITION_FADE_OUT + 0.15)
	check(not is_instance_valid(overlay), "the cover is gone after the fade")
	Game.scene_changed.disconnect(note)
	root.queue_free()
	Game.set_root(old_root)
	Sfx.enabled = sound
	await wait(0.3)

	if failures == 0:
		print("UI MOTION: helpers, menu pages, transition fade, result rows and standings passed")
	get_tree().quit(1 if failures else 0)
