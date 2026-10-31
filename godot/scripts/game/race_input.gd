class_name RaceInput
extends Control
## Touch + tilt controls for the race. Covers the whole screen (mouse_filter
## PASS so HUD buttons above still work). Right half = gas, left half = brake,
## centre-bottom button fires forward, a second button fires backwards.
## Steering: accelerometer roll (phone held like a wheel) or, with
## Settings.touch_steer, horizontal finger drag on the brake half.

signal fire_pressed(back: bool)

const DEAD_DEG := 2.2
const TILT_SMOOTH := 14.0
const PAD_FULL_PX := 160.0

var steer := 0.0
var gas := false
var brake := false
var fire := false
var back := false
var tilt_ok := false
var roll_deg := 0.0

var _fire_btn: Button
var _back_btn: Button
var _touches := {}           # index -> {"zone": String, "x0": float}
var _pad_steer := 0.0
var _kb := false
var _desktop := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_desktop = OS.get_name() not in ["Android", "iOS"]
	_fire_btn = _mk_button("GJUAJ", Vector2(0.5, 1.0), Vector2(-70, -150), Vector2(140, 92), Color(0.95, 0.35, 0.1))
	_fire_btn.button_down.connect(func(): fire = true; fire_pressed.emit(false))
	_fire_btn.button_up.connect(func(): fire = false)
	_back_btn = _mk_button("PRAPA", Vector2(0.5, 1.0), Vector2(-50, -48), Vector2(100, 40), Color(0.3, 0.55, 0.95))
	_back_btn.button_down.connect(func(): back = true; fire_pressed.emit(true))
	_back_btn.button_up.connect(func(): back = false)


func is_desktop() -> bool:
	return _desktop


func _mk_button(text: String, anchor: Vector2, off: Vector2, size: Vector2, col: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.anchor_left = anchor.x
	b.anchor_right = anchor.x
	b.anchor_top = anchor.y
	b.anchor_bottom = anchor.y
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + size.x
	b.offset_bottom = off.y + size.y
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.55)
	sb.border_color = Color(col.lightened(0.3), 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(col.lightened(0.2), 0.85)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color.WHITE)
	add_child(b)
	return b


func set_slot_label(forward: String, backward: String) -> void:
	_fire_btn.text = forward if forward != "" else "GJUAJ"
	_back_btn.text = backward if backward != "" else "PRAPA"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			var zone := "gas" if st.position.x >= size.x * 0.5 else "brake"
			_touches[st.index] = {"zone": zone, "x0": st.position.x}
		else:
			_touches.erase(st.index)
		_recount()
		accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _touches.has(sd.index) and Settings.touch_steer and _touches[sd.index].zone == "brake":
			_pad_steer = clampf((sd.position.x - float(_touches[sd.index].x0)) / PAD_FULL_PX, -1.0, 1.0)
		accept_event()


func _recount() -> void:
	gas = false
	brake = false
	for t in _touches.values():
		if t.zone == "gas":
			gas = true
		else:
			brake = true
	if not brake and Settings.touch_steer:
		_pad_steer = 0.0


func _process(dt: float) -> void:
	# keyboard (desktop testing)
	var kb_steer := Input.get_axis("ui_left", "ui_right")
	var kb_gas := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var kb_brake := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)
	_kb = kb_steer != 0.0 or kb_gas or kb_brake
	if _desktop:
		if kb_gas:
			gas = true
		elif _touches.is_empty():
			gas = false
		if kb_brake:
			brake = true
		elif _touches.is_empty():
			brake = false
	if kb_steer != 0.0:
		steer = kb_steer
		return
	if Settings.touch_steer:
		steer = _pad_steer
		return
	# tilt: component of gravity along the screen's horizontal axis -> roll
	var g := Input.get_accelerometer()
	var mag := g.length()
	if mag < 0.5:
		tilt_ok = false
		steer = move_toward(steer, 0.0, dt * TILT_SMOOTH)
		return
	tilt_ok = true
	# landscape: the screen x axis is the device's long axis; Godot already
	# reports the accelerometer in screen orientation on Android
	var lat := clampf(g.x / mag, -1.0, 1.0)
	var roll := asin(lat) * (-1.0 if Settings.tilt_invert else 1.0)
	roll_deg = rad_to_deg(roll)
	var full := deg_to_rad(float(Settings.TILT_FULL[clampi(Settings.tilt_sens, 0, 2)]))
	var dead := deg_to_rad(DEAD_DEG)
	var target := 0.0
	if absf(roll) >= dead:
		target = clampf((roll - signf(roll) * dead) / (full - dead), -1.0, 1.0)
	steer += (target - steer) * minf(1.0, dt * TILT_SMOOTH)


## Write the current controls into a CarState.
func apply(c: CarState) -> void:
	c.ctrl.steer = steer
	c.ctrl.gas = gas
	c.ctrl.brake = brake
	c.ctrl.fire = fire
	c.ctrl.back = back
	fire = false
	back = false
