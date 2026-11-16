extends Node

var failures := 0
var controls: RaceInput
var hud: Hud
var race: Race
var denied: Array[String] = []
var selections: Array[int] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func touch(index: int, zone: String, pressed := true, canceled := false, real_dispatch := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	event.position = controls.control_rect(zone).get_center()
	if real_dispatch:
		event.position = controls.get_global_transform_with_canvas() * event.position
		get_viewport().push_input(event, true)
	else:
		controls._gui_input(event)

func hold(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.0:
		var dt := minf(remaining, 0.05)
		controls.poll(dt)
		remaining -= dt

func slots() -> void:
	controls.reset_controls()
	race.player.slots = [{"type": "bolt", "ammo": 3}, {"type": "repair", "ammo": 1}, {"type": "mine", "ammo": 1}]
	hud._process(0.0)

func _ready() -> void:
	var old_input := Settings.input_config()
	var sound_before := Sfx.enabled
	Sfx.enabled = false
	Settings.load_input_config({"touch_steer": true, "auto_accel": true, "left_handed": false, "control_size": 1, "control_offset_x": 0.0, "control_offset_y": 0.0})
	var track := RaceTrack.load_city("tirane")
	race = Race.new(track, {"seed": 31, "adaptive_pickups": false})
	race.started = true
	var car := race.player
	var layer := CanvasLayer.new()
	add_child(layer)
	var host := Control.new()
	host.size = Vector2(1280, 720)
	host.position = Vector2(30, 20)
	host.scale = Vector2(0.9, 0.9)
	host.process_mode = Node.PROCESS_MODE_PAUSABLE
	layer.add_child(host)
	controls = RaceInput.new()
	host.add_child(controls)
	controls.bind(car, race)
	controls.set_driving_enabled(true)
	hud = Hud.new()
	host.add_child(hud)
	hud.setup(race, car, track)
	controls.bind_inventory(hud._slots)
	controls.action_denied.connect(func(reason: String): denied.append(reason))
	controls.inventory_hold_changed.connect(hud.inventory_hold)
	controls.inventory_selected.connect(func(i: int):
		selections.append(i)
		if i > 0: car.ctrl.select = i
		elif car.slots.size() > 1: car.ctrl.cycle = true)
	slots()
	await get_tree().process_frame
	# Real viewport dispatch with an inset/scaled UI and two independent fingers.
	touch(1, "steer", true, false, true)
	touch(2, "slot1", true, false, true)
	touch(2, "slot1", false, false, true)
	check(controls._touches.size() == 1 and controls._steer_finger == 1 and selections == [1], "second thumb selects inventory through real input while steering stays owned")
	race.step(1.0 / 60.0)
	check(car.slot_type() == "repair", "inventory selection reaches fixed-step simulation")
	controls.reset_controls()
	slots()
	await get_tree().process_frame
	var token: Dictionary = car.slots[2]
	touch(1, "steer")
	touch(2, "slot2")
	hold(0.3)
	controls.apply(car)
	check(car.ctrl.discard.is_empty() and hud._hold_fraction > 0.4, "short hold gives visible progress without discarding")
	hold(0.36)
	controls.apply(car)
	controls.apply(car)
	check(is_same(car.ctrl.discard, token) and controls.gas and controls._steer_finger == 1, "deliberate hold latches the exact item with steering and automatic gas intact")
	race.step(1.0 / 60.0)
	check(car.slots.size() == 2 and car.slot_type() == "bolt" and car.slots[1].type == "repair", "one hold discards only the chosen item")
	var selected_count := selections.size()
	touch(2, "slot2", false)
	check(selections.size() == selected_count, "release after discard cannot cycle or select another item")
	slots()
	await get_tree().process_frame
	touch(2, "slot1")
	hold(0.66)
	controls.apply(car)
	touch(2, "slot1", false, true)
	check(car.ctrl.discard.is_empty() and controls._discard.is_empty(), "OS cancellation retracts a hold still waiting for simulation")
	slots()
	touch(2, "slot1")
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = controls.control_rect("slot1").get_center() + Vector2(200, -120)
	controls._gui_input(drag)
	hold(1.0)
	controls.apply(car)
	touch(2, "slot1", false)
	check(car.ctrl.discard.is_empty() and selections.size() == selected_count, "dragging out cancels discard and tap selection")
	slots()
	touch(2, "slot1")
	car.slots.push_front(car.slots.pop_back())
	hold(0.7)
	controls.apply(car)
	check(car.ctrl.discard.is_empty() and denied.has("inventory_changed"), "inventory reordering cancels a stale held slot")
	slots()
	touch(2, "slot1")
	touch(3, "slot2")
	check(controls._inventory_finger == 2 and not controls._touches.has(3), "only one inventory finger can commit a discard at a time")
	hold(0.66)
	controls.apply(car)
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(car.ctrl.discard.is_empty() and controls._touches.is_empty() and hud._hold_index == -1, "focus loss clears pending discard and progress")
	controls.resume_controls()
	slots()
	touch(2, "slot1")
	hold(0.66)
	controls.apply(car)
	controls.set_driving_enabled(false)
	check(car.ctrl.discard.is_empty() and not controls._boost, "pause/finish clears pending inventory and reward actions")
	controls.set_driving_enabled(true)
	car.skill_charge = 1.0
	car.nitro_t = 0.0
	touch(1, "steer")
	touch(2, "boost")
	controls.poll(0.016)
	controls.apply(car)
	controls.apply(car)
	check(car.ctrl.boost and car.ctrl.gas and controls._steer_finger == 1, "earned boost uses the second thumb and stays latched between ticks")
	race.step(1.0 / 60.0)
	check(car.skill_boosts == 1 and car.skill_charge == 0.0 and not car.ctrl.boost, "reward is spent exactly once at a real fixed tick")
	controls.poll(0.016)
	controls.apply(car)
	race.step(1.0 / 60.0)
	check(car.skill_boosts == 1, "held reward button cannot repeat")
	controls.reset_controls()
	car.slots.clear()
	controls.sync_actions()
	touch(2, "fire")
	check(denied.has("empty") and not controls.fire and controls._fire_btn.disabled, "tapping disabled empty action explains it without firing")
	touch(2, "fire", false)
	car.slots = [{"type": "repair", "ammo": 1}]
	car.health = car.max_hp
	controls.sync_actions()
	touch(2, "fire")
	check(denied.has("full") and not controls.fire, "unusable repair explains why through the same input route")
	controls.reset_controls()
	car.nitro_t = 1.1
	car.nitro_duration = 2.6
	car.shield_t = 4.0
	car.recovery_t = 2.0
	car.health = car.max_hp * 0.2
	race.projs = [{"id": 900, "kind": "eagle", "owner": race.cars[0], "target": car, "s": track.mod_s(car.s - 20), "d": car.d, "dir": 1.0, "speed": 75.0, "life": 5.0, "born": 0.0}]
	hud.combat._process(0.0)
	await get_tree().process_frame
	check(hud.combat._states.shield.panel.visible and hud.combat._states.shield.label.text.contains("4.0"), "shield duration is numeric and visible")
	check(absf(hud.combat._states.nitro.bar.value - 1.1 / 2.6) < 0.002 and hud.combat._states.recovery.panel.visible, "turbo and recovery bars reflect real simulation timers")
	check(hud.combat._critical and hud.combat._health.text.contains("20%"), "critical health has explicit percentage and persistent edge feedback")
	check(hud.combat._warning.visible, "live homing warning is visible with simultaneous duration indicators")
	for entry: Dictionary in hud.combat._states.values():
		check(not entry.panel.get_global_rect().intersects(hud.combat._warning.get_global_rect()), "duration cards do not overlap the threat warning")
	check(not hud.combat._health.get_global_rect().intersects(hud._fps.get_global_rect()), "health percentage and optional FPS have separate header space")
	car.health = car.max_hp
	hud.combat._process(0.0)
	check(not hud.combat._critical, "repair removes critical-health feedback immediately")
	car.finished = true
	hud.combat._process(0.0)
	check(not hud.combat._states.shield.panel.visible and not hud.combat._warning.visible, "finish hides combat alerts and duration bars")
	for handed in [false, true]:
		Settings.load_input_config({"left_handed": handed, "control_size": 2, "control_offset_x": 1.0, "control_offset_y": 1.0})
		Settings.changed.emit()
		host.size = Vector2(1160, 650)
		hud.feed("Shëndeti është plot. Ruaje Ustën ose mbaj slotin për ta lëshuar.")
		hud.feed("Rimarrje: goditjet e tjera nuk të bllokojnë timonin")
		hud._process(0.0)
		await get_tree().process_frame
		for zone in ["steer", "fire", "back", "brake", "boost"]:
			check(not controls.control_rect(zone).intersects(hud._feed.get_rect()), "wrapped combat feedback clears mirrored/inset thumb controls")
		for i in car.slots.size():
			check(not controls.control_rect("boost").intersects(controls.control_rect("slot%d" % i)), "earned boost and real inventory targets stay separate")
		check(controls._boost_btn.size.is_equal_approx(controls.control_rect("boost").size), "drawn boost button matches its hit target: drawn=%s target=%s" % [controls._boost_btn.size, controls.control_rect("boost").size])
		check(hud._feed.size.y >= 20.0 and hud._feed.get_child_count() > 0, "combat explanations remain visible after layout")
		var explanation: Label = hud._feed.get_child(0)
		check(explanation.get_line_count() >= 2 and explanation.get_visible_line_count() == 2, "full denial explanation wraps onto two visible lines")
	# Driving controls show an icon instead of a word (README 5.1).
	Settings.auto_accel = false
	Settings.touch_steer = true
	Settings.changed.emit()
	await get_tree().process_frame
	for zone in ["gas", "brake", "steer"]:
		var button: Button = controls.get("_%s_btn" % zone)
		var face: RaceInput.ControlFace = controls._faces[zone]
		check(button.text.is_empty() and button.visible, "the %s control carries no word" % zone)
		check(face.get_parent() == button and face.size.is_equal_approx(button.size), "the %s face fills its button" % zone)
		check(button.position.is_equal_approx(controls.control_rect(zone).position) and button.size.is_equal_approx(controls.control_rect(zone).size), "the %s button still matches its hit rectangle" % zone)
	for zone in ["gas", "brake"]:
		var face: RaceInput.ControlFace = controls._faces[zone]
		check(face.icon != null and not face.wheel, "the %s control shows an icon" % zone)
		check(Rect2(Vector2.ZERO, face.size).encloses(face.icon_rect()) and face.icon_rect().size.x >= 40.0, "the %s icon is large and inside the button" % zone)
	check(controls._faces.gas.icon != controls._faces.brake.icon, "gas and brake have different icons")
	var wheel: RaceInput.ControlFace = controls._faces.steer
	check(wheel.wheel and wheel.icon == null and wheel.wheel_radius() >= 50.0 and wheel.wheel_radius() * 2.0 < wheel.size.x, "the steering pad draws a half wheel that fits it")
	controls._pad_steer = 0.6
	controls._update_marker()
	check(is_equal_approx(wheel.steer, 0.6), "the half wheel turns with the thumb")
	controls._pad_steer = 0.0
	controls._update_marker()
	check(wheel.steer == 0.0, "the half wheel centres again")
	for zone in ["fire", "back", "boost"]:
		check(controls._faces.has(zone) and controls._faces[zone].icon == null, "the %s button keeps its own item icon and status line" % zone)
	# A held control shrinks and lights its ring; the hit rectangle stays put.
	var brake_face: RaceInput.ControlFace = controls._faces.brake
	var brake_rect := controls.control_rect("brake")
	controls._show_pressed("brake", controls._brake_btn, true)
	check(controls._brake_btn.button_pressed, "a held control shows its pressed style at once")
	await get_tree().create_timer(RaceInput.PRESS_TIME * 3.0).timeout
	check(is_equal_approx(controls._brake_btn.scale.x, RaceInput.PRESS_SCALE) and RaceInput.PRESS_SCALE < 1.0 and RaceInput.PRESS_SCALE > 0.85, "a held control shrinks a little")
	check(is_equal_approx(brake_face.glow, 1.0), "a held control lights its ring")
	check(controls._brake_btn.pivot_offset.is_equal_approx(brake_rect.size * 0.5), "the press scales about the centre")
	check(controls.control_rect("brake") == brake_rect and controls._brake_btn.size.is_equal_approx(brake_rect.size), "pressing does not move the hit rectangle")
	controls._show_pressed("brake", controls._brake_btn, false)
	await get_tree().create_timer(RaceInput.PRESS_TIME * 4.0).timeout
	check(is_equal_approx(controls._brake_btn.scale.x, 1.0) and is_zero_approx(brake_face.glow) and not controls._brake_btn.button_pressed, "a released control returns to rest")
	controls._show_pressed("brake", controls._brake_btn, true)
	controls.reset_controls()
	await get_tree().create_timer(RaceInput.PRESS_TIME * 4.0).timeout
	check(is_equal_approx(controls._brake_btn.scale.x, 1.0) and is_zero_approx(brake_face.glow), "resetting the controls releases the press feedback")
	Settings.load_input_config(old_input)
	Settings.changed.emit()
	layer.queue_free()
	await get_tree().process_frame
	Sfx.enabled = sound_before
	print("COMBAT UI: real two-pointer inventory, holds/cancellation, stale actions, earned boost, explanations and status indicators; failures=", failures)
	get_tree().quit(1 if failures else 0)
