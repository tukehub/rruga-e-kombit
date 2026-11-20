extends Node
## Touch steering on the round wheel. Rotate mode follows the finger round the
## hub; the case that used to fail (finger on the left of the wheel, turned
## hard left to the limit, read as a right turn) and its causes: an angle seam
## at 9 o'clock, rotation read as sideways travel, and hidden travel past the
## lock. Slide mode keeps the old sideways drag without the hidden travel.

var failures := 0
var controls: RaceInput
var race: Race


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func hub() -> Vector2:
	return controls.control_rect("steer").get_center()


func rim(clock_deg: float, radius_frac := 0.8) -> Vector2:
	# 0 = 12 o'clock, clockwise; screen y points down.
	var r := controls.control_rect("steer").size.x * 0.5 * radius_frac
	var a := deg_to_rad(clock_deg - 90.0)
	return hub() + Vector2(cos(a), sin(a)) * r


func press(at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 1
	e.position = at
	e.pressed = true
	controls._gui_input(e)


func release() -> void:
	var e := InputEventScreenTouch.new()
	e.index = 1
	e.position = hub()
	e.pressed = false
	controls._gui_input(e)


func move(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 1
	e.position = at
	controls._gui_input(e)


## Moves the finger round the rim from `from` to `to` (clock degrees) in
## small steps, as a real drag does; returns the most-right steer seen.
func sweep(from: float, to: float, step := 4.0) -> float:
	var most_right := -2.0
	var a := from
	var dir := signf(to - from)
	while (to - a) * dir > 0.0:
		a += dir * minf(step, absf(to - a))
		move(rim(a))
		most_right = maxf(most_right, controls._pad_steer)
	return most_right


func _ready() -> void:
	var previous := Settings.input_config()
	Settings.load_input_config({"auto_accel": true, "touch_steer": true, "steer_mode": "wheel", "left_handed": false, "control_size": 1, "control_offset_x": 0.0, "control_offset_y": 0.0, "touch_sens": 1})
	Settings.changed.emit()
	race = Race.new(RaceTrack.load_city("tirane"), {"seed": 19})
	race.started = true
	controls = RaceInput.new()
	add_child(controls)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.size = Vector2(1280, 720)
	controls.bind(race.player, race)
	controls.set_driving_enabled(true)
	var lock := float(Settings.TOUCH_TRAVEL[Settings.touch_sens])

	# --- the reported case: finger on the left, turned hard left
	press(rim(270.0))
	check(controls._steer_finger == 1 and controls._pad_steer == 0.0, "grabbing the wheel's left side does not steer by itself")
	var worst := sweep(270.0, 270.0 - lock * 1.6)
	check(worst <= 0.0, "turning left from the left side never reads as right (worst %.2f)" % worst)
	check(controls._pad_steer == -1.0, "turned past the limit it holds full left")
	sweep(270.0 - lock * 1.6, 270.0 - lock * 1.6 + 15.0)
	check(controls._pad_steer > -1.0 and controls._pad_steer < -0.7, "turning back answers at once: nothing stored past the lock (%.2f)" % controls._pad_steer)
	release()
	check(controls._pad_steer == 0.0, "letting go centres")

	# --- the 9 o'clock seam: where an absolute angle jumps from +180 to -180
	press(rim(250.0))
	sweep(250.0, 290.0)
	var across := controls._pad_steer
	check(absf(across - 40.0 / lock) < 0.03, "turning right across 9 o'clock is a smooth +40 degrees (%.2f)" % across)
	sweep(290.0, 250.0)
	check(controls._pad_steer == 0.0, "and back again is centre")
	release()

	# --- a real wheel: up on the left is right, down on the left is left
	press(rim(270.0))
	sweep(270.0, 320.0)
	check(controls._pad_steer > 0.4, "pushing the left rim up turns right")
	release()
	press(rim(180.0))
	sweep(180.0, 140.0)
	check(controls._pad_steer < -0.3, "pushing the bottom rim right turns left, like a real wheel")
	release()
	press(rim(0.0))
	sweep(0.0, -40.0)
	check(controls._pad_steer < -0.3, "pulling the top rim left turns left")
	release()

	# --- the hub: no angle there, so the sideways move steers
	press(hub())
	move(hub() + Vector2(8, 0))
	move(hub() + Vector2(16, 0))
	check(controls._pad_steer > 0.1, "a drag starting on the hub still steers right")
	release()
	press(rim(90.0, 0.6))
	move(rim(270.0, 0.6))
	check(controls._pad_steer < 0.0, "a jump from right to left straight over the hub reads as its sideways move: left")
	release()

	# --- sensitivity: high locks sooner
	Settings.load_input_config({"touch_sens": 2})
	press(rim(0.0))
	sweep(0.0, 70.0)
	var high := controls._pad_steer
	release()
	Settings.load_input_config({"touch_sens": 0})
	press(rim(0.0))
	sweep(0.0, 70.0)
	var low := controls._pad_steer
	release()
	check(high > low + 0.2, "higher sensitivity needs less turning (%.2f vs %.2f)" % [high, low])
	Settings.load_input_config({"touch_sens": 1})

	# --- slide mode: sideways drag, no hidden travel past the limit
	Settings.load_input_config({"steer_mode": "slide"})
	var full := controls.steer_travel()
	press(hub())
	move(hub() + Vector2(-full * 2.5, 0))
	check(controls._pad_steer == -1.0, "sliding far left is full left")
	move(hub() + Vector2(-full * 2.5 + full * 0.25, 0))
	check(absf(controls._pad_steer + 0.75) < 0.02, "a quarter back is three quarters left at once (%.2f)" % controls._pad_steer)
	release()

	# --- the setting: saved, and older files get the wheel
	check(Settings.input_config().steer_mode == "slide", "the mode is part of the saved controls")
	Settings.load_input_config({"steer_mode": "nonsense"})
	check(Settings.steer_mode == "wheel", "an unknown mode falls back to rotating the wheel")
	Settings.load_input_config(previous)
	print("wheel_steering: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
