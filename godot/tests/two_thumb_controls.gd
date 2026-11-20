extends Node

const SafeArea = preload("res://scripts/ui/safe_area.gd")
const SettingsScript = preload("res://scripts/game/settings.gd")
var failures := 0
var controls: RaceInput
var race: Race


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func touch(index: int, zone: String, pressed := true, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = controls.control_rect(zone).get_center()
	event.pressed = pressed
	event.canceled = canceled
	controls._gui_input(event)


func drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	controls._gui_input(event)


func configure(values: Dictionary) -> void:
	Settings.load_input_config(values)
	Settings.changed.emit()


func _ready() -> void:
	var previous := Settings.input_config()
	configure({"auto_accel": true, "touch_steer": true, "left_handed": false, "control_size": 1, "control_opacity": 0.9, "control_offset_x": 0.0, "control_offset_y": 0.0, "touch_sens": 1})
	race = Race.new(RaceTrack.load_city("tirane"), {"seed": 19})
	controls = RaceInput.new()
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.size = Vector2(1280, 720)
	controls.bind(race.player, race)
	var car := race.player
	car.slots = [{"type": "bolt", "ammo": 3}]
	controls.set_driving_enabled(true)
	controls.poll(0.016)
	check(not controls.gas and not controls.action_available(false), "countdown cannot accelerate or fire")
	race.started = true
	controls.set_driving_enabled(false)
	controls.poll(0.016)
	check(not controls.gas, "intro/disabled input cannot start automatic gas")
	controls.set_driving_enabled(true)
	controls.poll(0.016)
	check(controls.gas and controls.control_rect("gas").size == Vector2.ZERO and not controls._gas_btn.visible, "auto gas needs no third thumb or invisible pedal")
	var origin := controls.control_rect("steer").get_center()
	touch(1, "steer")
	drag(1, origin + Vector2(85, 0))
	touch(2, "fire")
	controls.poll(0.016)
	controls.apply(car)
	controls.apply(car)
	check(controls._touches.size() == 2 and car.ctrl.gas and car.ctrl.steer > 0.5 and car.ctrl.fire, "two fingers steer, accelerate and fire together")
	race.step(1.0 / 60.0)
	check(car.slots.size() == 1 and int(car.slots[0].ammo) == 2 and not car.ctrl.fire, "item tap survives render frames and fires exactly once")
	controls.poll(0.016)
	controls.apply(car)
	race.step(1.0 / 60.0)
	check(int(car.slots[0].ammo) == 2, "held firing thumb does not repeat")
	touch(2, "fire", false)
	touch(2, "brake")
	controls.poll(0.016)
	controls.apply(car)
	check(car.ctrl.brake and not car.ctrl.gas and car.ctrl.steer > 0.5, "two thumbs brake and steer while auto gas yields")
	drag(2, Vector2(640, 100))
	check(controls.brake, "pedal ownership survives dragging outside")
	touch(3, "steer")
	drag(3, origin - Vector2(100, 0))
	check(controls._steer_finger == 1 and controls._pad_steer > 0.5 and not controls._touches.has(3), "extra steering finger cannot hijack the owner")
	touch(1, "steer", false, true)
	controls.poll(0.016)
	check(controls.steer == 0.0 and controls.brake, "canceling steering preserves the other thumb")
	touch(2, "brake", false, true)
	controls.poll(0.016)
	check(controls.gas and not controls.brake, "canceling brake releases it")
	touch(2, "fire")
	controls.apply(car)
	touch(2, "fire", false, true)
	check(not controls.fire and not car.ctrl.fire, "canceled item tap clears a pending simulation action")

	# Focus loss may happen between rendering and the next simulation tick.
	touch(1, "steer")
	touch(2, "fire")
	controls.apply(car)
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	controls.poll(0.016)
	check(not controls.gas and not car.ctrl.gas and not car.ctrl.fire and controls._touches.is_empty(), "focus loss clears continuous and pending actions")
	controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	controls.poll(0.016)
	check(not controls.gas, "returning focus alone does not restart the car")
	controls.resume_controls()
	controls.poll(0.016)
	check(controls.gas, "explicit resume restores automatic gas")
	car.finished = true
	controls.poll(0.016)
	check(not controls.gas and not controls.action_available(false), "finish suppresses driving and items")
	car.finished = false
	controls.set_driving_enabled(false)
	controls.poll(0.016)
	check(not controls.gas and controls._touches.is_empty(), "pause/control editing leaves no held inputs")
	controls.set_driving_enabled(true)

	# Actions expose the real selected item; nitro only goes forward.
	for type in Data.PW_KEYS:
		car.slots = [{"type": type, "ammo": 1}]
		car.health = car.max_hp * 0.5
		car.progress = -100.0
		controls.sync_actions()
		var directional: bool = type in ["eagle", "bolt", "mine"]
		check(controls._back_btn.visible == directional and controls.action_available(true) == directional, "reverse readiness matches item " + type)
		check(controls._fire_btn.icon != null and controls.action_available(false), "selected item has a usable labeled icon " + type)
		if type == "nitro":
			check(controls._fire_btn.text == "NITRO" and not controls._back_btn.visible, "nitro has no backward use")
		if not directional:
			touch(4, "back")
			check(not controls.back, "hidden reverse action cannot fire " + type)
	car.slots = [{"type": "repair", "ammo": 1}]
	car.health = car.max_hp
	controls.sync_actions()
	check(controls._fire_btn.disabled and controls._fire_btn.text == "E PLOTË", "repair unavailable at full health")
	car.slots = [{"type": "shock", "ammo": 1}]
	car.progress = 1000.0
	race.compute_order()
	controls.sync_actions()
	check(controls._fire_btn.disabled and controls._fire_btn.text == "JE I PARI", "leading racer cannot waste lightning")
	car.slots = [{"type": "bolt", "ammo": 1}]
	car.wreck_t = 1.0
	check(not controls.action_available(false), "wrecked car cannot use items")
	car.wreck_t = 0.0
	car.spin_t = 1.0
	check(not controls.action_available(false), "spinning car cannot use items")
	car.spin_t = 0.0
	car.slots.clear()
	controls.sync_actions()
	check(not controls._fire_btn.visible and not controls._back_btn.visible, "an empty inventory shows no fire button at all")

	configure({"auto_accel": false})
	controls.poll(0.016)
	check(not controls.gas and controls._gas_btn.visible, "manual mode coasts without a pedal touch")
	touch(1, "steer")
	touch(2, "gas")
	controls.poll(0.016)
	check(controls.gas and controls._touches.size() == 2, "manual steering and gas use two thumbs")
	# Changes to input geometry must release pointers; unrelated settings must not.
	configure({"left_handed": true})
	check(not controls.gas and controls._touches.is_empty(), "layout change releases old touch rectangles")
	touch(2, "gas")
	Settings.changed.emit()
	check(controls.gas and controls._touches.size() == 1, "unrelated settings save does not drop a held pedal")
	controls.size = Vector2(1440, 720)
	check(not controls.gas and controls._touches.is_empty(), "safe area/resize clears touches")
	for code in [KEY_D, KEY_RIGHT, KEY_A, KEY_LEFT]:
		var key := InputEventKey.new()
		key.keycode = code
		key.pressed = true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		controls.poll(0.016)
		check(controls.steer == (1.0 if code in [KEY_D, KEY_RIGHT] else -1.0), "advertised keyboard steering works")
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		controls.poll(0.016)
		check(controls.steer == 0.0, "releasing keyboard steering centers the wheel")
	_test_layouts()
	_test_tilt()
	_test_safe_area()
	_test_persistence()
	controls.queue_free()
	configure(previous)
	Settings.save()
	await get_tree().process_frame
	print("TWO THUMB CONTROLS: multitouch, lifecycle, items, layouts, calibration, safe areas and persistence; failures=", failures)
	get_tree().quit(1 if failures else 0)


func _test_layouts() -> void:
	for width in [1160.0, 1280.0, 1560.0, 1920.0]:
		controls.size = Vector2(width, 650)
		for manual in [false, true]:
			for handed in [false, true]:
				for scale in [0, 1, 2]:
					configure({"auto_accel": not manual, "left_handed": handed, "control_size": scale, "control_offset_x": 1.0, "control_offset_y": 1.0})
					var zones := ["steer", "brake", "fire", "back", "boost"]
					if manual:
						zones.append("gas")
					var bounds := Rect2(Vector2.ZERO, controls.size)
					var inventory := Rect2(Vector2(width * 0.5 + (-70 if handed else -166), 650 - 76), Vector2(236, 58))
					for i in zones.size():
						var rect := controls.control_rect(zones[i])
						check(bounds.encloses(rect) and rect.size.x >= (72 if zones[i] == "boost" else 90) and rect.size.y >= 50, "controls stay inside safe viewport with usable targets")
						check(not rect.intersects(inventory), "thumb controls never cover inventory buttons")
						check(not rect.intersects(Rect2(0, 0, 300, 330)) and not rect.intersects(Rect2(width - 184, 0, 184, 310)), "mirrored and raised controls clear standings and view buttons")
						for j in range(i + 1, zones.size()):
							check(not rect.intersects(controls.control_rect(zones[j])), "all thumb control targets are disjoint")
					var pad := controls.control_rect("steer")
					check((pad.get_center().x > width * 0.5) == handed, "handedness mirrors steering")
					check(controls._steer_btn.position == pad.position and controls._steer_btn.size.is_equal_approx(pad.size), "drawn and hit steering rectangles match")
	configure({"control_offset_x": 0.0, "control_offset_y": 0.0, "control_size": 1, "left_handed": false})


func _test_tilt() -> void:
	var neutral := Vector3(sin(0.2), 0, cos(0.2)) * 9.8
	configure({"touch_steer": false, "tilt_center": RaceInput.tilt_angle(neutral), "tilt_invert": false, "tilt_sens": 1})
	controls._sample_tilt(neutral, 1.0)
	check(controls.tilt_ok and absf(controls.steer) < 0.001, "calibrated holding angle is neutral")
	var tilted := Vector3(sin(0.45), 0, cos(0.45)) * 9.8
	controls._sample_tilt(tilted, 1.0)
	check(controls.steer > 0.5, "tilt is relative to calibrated neutral")
	configure({"tilt_invert": true})
	controls._sample_tilt(tilted, 1.0)
	check(controls.steer < -0.5, "inversion applies after neutral subtraction")
	controls._sample_tilt(Vector3.ZERO, 1.0)
	check(not controls.tilt_ok and controls.steer == 0.0, "missing tilt sensor releases steering")
	check(not is_finite(RaceInput.tilt_angle(Vector3(NAN, 0, 0))), "invalid sensor samples are rejected")


func _test_safe_area() -> void:
	var bounds := Rect2(0, 0, 1280, 720)
	var screen_transform := Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2(40, 20))
	var safe := SafeArea.logical_rect(bounds, Rect2i(120, 60, 2400, 1320), screen_transform)
	check(safe.is_equal_approx(Rect2(40, 20, 1200, 660)), "notches/insets map from physical pixels into stretched logical UI")
	check(SafeArea.logical_rect(bounds, Rect2i(), screen_transform) == bounds, "absent native safe area preserves full UI")
	check(SafeArea.logical_rect(bounds, Rect2i(9000, 9000, 20, 20), screen_transform) == bounds, "invalid native safe area cannot hide all controls")
	# Exercise the real nested canvas input path at a scaled and inset origin.
	var parent := Control.new()
	parent.position = Vector2(37, 23)
	parent.scale = Vector2(0.8, 0.8)
	add_child(parent)
	controls.reparent(parent, false)
	controls.position = Vector2.ZERO
	configure({"touch_steer": true, "auto_accel": false})
	var event := InputEventScreenTouch.new()
	event.index = 7
	event.pressed = true
	event.position = controls.get_global_transform_with_canvas() * controls.control_rect("gas").get_center()
	controls._input(event)
	check(controls.gas, "touch input matches scaled/inset safe content")
	controls.reset_controls()
	controls.reparent(self, false)
	parent.queue_free()


func _test_persistence() -> void:
	configure({"auto_accel": false, "left_handed": true, "control_size": 2, "control_opacity": 0.65, "control_offset_x": 0.4, "control_offset_y": 0.7, "touch_sens": 2, "tilt_center": 0.23})
	Settings.save()
	var loaded := SettingsScript.new()
	loaded.load_settings()
	check(loaded.input_config() == Settings.input_config(), "all input preferences survive a real config save/load")
	loaded.free()
	var legacy := SettingsScript.new()
	legacy.load_input_config({"tilt_sens": 1, "touch_steer": false})
	check(legacy.auto_accel and not legacy.touch_steer and legacy.control_size == 1, "older settings gain auto gas without resetting steering choice")
	legacy.load_input_config({"control_size": 99, "touch_sens": -10, "tilt_sens": 99, "control_opacity": -1, "control_offset_x": 4, "control_offset_y": -4, "tilt_center": NAN})
	check(legacy.control_size == 2 and legacy.touch_sens == 0 and legacy.tilt_sens == 2 and legacy.control_opacity == 0.45 and legacy.control_offset_x == 1.0 and legacy.control_offset_y == 0.0 and is_finite(legacy.tilt_center), "input settings are bounded and finite")
	legacy.free()
