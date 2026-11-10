class_name RaceInput
extends Control
## Explicit corner pedals and firing buttons leave the road and car unobscured.
## Each finger owns one control until released. Steering uses tilt or the visible
## touch pad; touching elsewhere on the screen never accelerates or brakes.

signal fire_pressed(back: bool)

const DEAD_DEG := 2.2
const TILT_SMOOTH := 14.0
const EDGE := 20.0
const PEDAL_SIZE := Vector2(112, 128)
const FIRE_SIZE := Vector2(164, 64)
const STEER_SIZE := Vector2(260, 124)
# Preserve the existing right edge while letting the pad grow toward the
# brake. A 24-pixel clear strip still separates their touch targets.
const STEER_BASE_GAP := 48.0
const STEER_PEDAL_GAP := 24.0
const STEER_LEFT_EXPANSION := 100.0
# Where the pad starts, as a fraction of the screen width.
const STEER_LEFT_FRACTION := 0.17
# Wide phones leave free space between the pad and the item slots in the
# centre of the screen; the pad grows into it but never under the slots.
const STEER_RIGHT_EXPANSION := 70.0
const STEER_SLOT_CLEARANCE := 138.0
# Finger travel from the pad centre to full lock, so a wider pad is more
# forgiving without becoming slower to steer.
const STEER_FULL_LOCK := 130.0

var steer := 0.0
var gas := false
var brake := false
var fire := false
var back := false
var tilt_ok := false
var roll_deg := 0.0

var _fire_btn: Button
var _back_btn: Button
var _gas_btn: Button
var _brake_btn: Button
var _steer_btn: Button
var _touches := {}           # index -> {"zone": String}
var _pad_steer := 0.0
var _kb := false
var _desktop := false
var _cycle := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Input is captured only inside the named rectangles in _input(), so HUD
	# controls and the open road do not become invisible driving surfaces.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop = OS.get_name() not in ["Android", "iOS"]
	_fire_btn = _mk_button("GJUAJ PARA", "fire", Color("ffbc57"))
	_back_btn = _mk_button("GJUAJ PRAPA", "back", Color("8edbff"))
	_gas_btn = _mk_button("GAZ", "gas", Color("77e8b0"))
	_brake_btn = _mk_button("FRENA", "brake", Color("ff9c94"))
	_steer_btn = _mk_button("‹   TIMONI   ›", "steer", Color("b8d9ef"))
	_layout_buttons()
	resized.connect(_layout_buttons)


func is_desktop() -> bool:
	return _desktop


## Public layout contract used by input checks and the HUD safe regions.
func control_rect(zone: String) -> Rect2:
	match zone:
		"gas":
			return Rect2(Vector2(size.x - EDGE - PEDAL_SIZE.x, size.y - EDGE - PEDAL_SIZE.y), PEDAL_SIZE)
		"brake":
			return Rect2(Vector2(EDGE, size.y - EDGE - PEDAL_SIZE.y), PEDAL_SIZE)
		"fire":
			return Rect2(Vector2(size.x - EDGE - FIRE_SIZE.x, size.y - EDGE - PEDAL_SIZE.y - 16 - FIRE_SIZE.y), FIRE_SIZE)
		"back":
			return Rect2(Vector2(EDGE, size.y - EDGE - PEDAL_SIZE.y - 16 - FIRE_SIZE.y), FIRE_SIZE)
		"steer":
			# Expand left from the old pad while leaving its right edge in place.
			# On narrower displays, use only the space available before the brake.
			var base_margin := EDGE + PEDAL_SIZE.x + STEER_BASE_GAP
			var minimum_left := EDGE + PEDAL_SIZE.x + STEER_PEDAL_GAP
			var width := minf(STEER_SIZE.x, maxf(0.0, size.x - 2.0 * base_margin))
			var left := clampf(size.x * STEER_LEFT_FRACTION, base_margin, maxf(base_margin, size.x - base_margin - width))
			var expansion := minf(STEER_LEFT_EXPANSION, maxf(0.0, left - minimum_left))
			var right := left + width
			right = maxf(right, minf(right + STEER_RIGHT_EXPANSION, size.x * 0.5 - STEER_SLOT_CLEARANCE))
			return Rect2(Vector2(left - expansion, size.y - 28 - STEER_SIZE.y), Vector2(right - left + expansion, STEER_SIZE.y))
	return Rect2()


func zone_at(local_position: Vector2) -> String:
	for zone in ["gas", "brake", "fire", "back", "steer"]:
		if zone == "steer" and not Settings.touch_steer:
			continue
		if control_rect(zone).has_point(local_position):
			return zone
	return ""


func _layout_buttons() -> void:
	for pair in [[_fire_btn, "fire"], [_back_btn, "back"], [_gas_btn, "gas"], [_brake_btn, "brake"], [_steer_btn, "steer"]]:
		var b: Button = pair[0]
		if b == null:
			continue
		var rect := control_rect(pair[1])
		b.position = rect.position
		b.size = rect.size
	if _steer_btn != null:
		_steer_btn.visible = Settings.touch_steer


func _mk_button(text: String, zone: String, col: Color) -> Button:
	var b := Button.new()
	b.name = zone.capitalize() + "Control"
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	# Built-in mouse emulation only supports one touch. We draw with Buttons,
	# while pointer IDs below handle simultaneous pedal, steering and firing.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.toggle_mode = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.075, 0.10, 0.38)
	sb.border_color = Color(col, 0.72)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	var pressed := sb.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(col.darkened(0.35), 0.65)
	pressed.border_color = col.lightened(0.25)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_font_override("font", UiTheme.body_bold())
	b.add_theme_font_size_override("font_size", 22 if zone in ["fire", "back", "steer"] else 24)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	b.add_theme_constant_override("outline_size", 3)
	if zone in ["gas", "brake"]:
		for row in 3:
			var rib := ColorRect.new()
			rib.position = Vector2(28, 99 + row * 7)
			rib.size = Vector2(56, 3)
			rib.color = Color(col, 0.48)
			rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(rib)
	add_child(b)
	return b


func set_slot_label(_forward: String, _backward: String) -> void:
	# Action names stay stable. The HUD already shows the selected power-up;
	# replacing these labels with item names hides which direction they fire.
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if _handle_touch(event, local):
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				fire = true
				fire_pressed.emit(false)
			KEY_SHIFT, KEY_X:
				back = true
				fire_pressed.emit(true)
			KEY_Q, KEY_E:
				_cycle = true
			_:
				return
		get_viewport().set_input_as_handled()


## Kept for direct input harnesses; normal play routes through _input().
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event, event.position)


func _handle_touch(event: InputEvent, local: Vector2) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var zone := zone_at(local)
			if zone.is_empty():
				return false
			_touches[touch.index] = {"zone": zone}
			if zone == "fire":
				fire = true
				fire_pressed.emit(false)
			elif zone == "back":
				back = true
				fire_pressed.emit(true)
			elif zone == "steer":
				_set_pad(local.x)
		else:
			if not _touches.has(touch.index):
				return false
			_touches.erase(touch.index)
		_recount()
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return false
		if _touches[drag.index].zone == "steer":
			_set_pad(local.x)
		return true
	return false


func _set_pad(x: float) -> void:
	var rect := control_rect("steer")
	if rect.size.x <= 0.0:
		_pad_steer = 0.0
		return
	_pad_steer = clampf((x - rect.get_center().x) / minf(rect.size.x * 0.38, STEER_FULL_LOCK), -1.0, 1.0)
	if absf(_pad_steer) < 0.1:
		_pad_steer = 0.0


func _held(zone: String) -> bool:
	for touch in _touches.values():
		if touch.zone == zone:
			return true
	return false


func _recount() -> void:
	gas = _held("gas")
	brake = _held("brake")
	if not _held("steer"):
		_pad_steer = 0.0
	for pair in [[_gas_btn, "gas"], [_brake_btn, "brake"], [_fire_btn, "fire"], [_back_btn, "back"], [_steer_btn, "steer"]]:
		var button: Button = pair[0]
		if button != null:
			button.set_pressed_no_signal(_held(pair[1]))


## Called by RaceScene at the top of its frame, before the controls are applied.
func poll(dt: float) -> void:
	# Merge keyboard and touch state each frame so neither leaves a stuck pedal.
	var kb_steer := Input.get_axis("ui_left", "ui_right")
	var kb_gas := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var kb_brake := Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)
	_kb = kb_steer != 0.0 or kb_gas or kb_brake
	gas = _held("gas") or (_desktop and kb_gas)
	brake = _held("brake") or (_desktop and kb_brake)
	if _steer_btn != null:
		_steer_btn.visible = Settings.touch_steer
	if kb_steer != 0.0:
		steer = kb_steer
		return
	if Settings.touch_steer:
		steer = _pad_steer
		return
	var gravity := Input.get_accelerometer()
	var magnitude := gravity.length()
	if magnitude < 0.5:
		tilt_ok = false
		steer = move_toward(steer, 0.0, dt * TILT_SMOOTH)
		return
	tilt_ok = true
	# Android reports acceleration in the current screen orientation.
	var lateral := clampf(gravity.x / magnitude, -1.0, 1.0)
	var roll := asin(lateral) * (-1.0 if Settings.tilt_invert else 1.0)
	roll_deg = rad_to_deg(roll)
	var full := deg_to_rad(float(Settings.TILT_FULL[clampi(Settings.tilt_sens, 0, 2)]))
	var dead := deg_to_rad(DEAD_DEG)
	var target := 0.0
	if absf(roll) >= dead:
		target = clampf((roll - signf(roll) * dead) / (full - dead), -1.0, 1.0)
	steer += (target - steer) * minf(1.0, dt * TILT_SMOOTH)


func apply(car: CarState) -> void:
	car.ctrl.steer = steer
	car.ctrl.gas = gas
	car.ctrl.brake = brake
	# Keep one-shot actions latched until Race.step consumes them. A render
	# frame can end before the next fixed simulation tick runs.
	car.ctrl.fire = car.ctrl.fire or fire
	car.ctrl.back = car.ctrl.back or back
	car.ctrl.cycle = car.ctrl.cycle or _cycle
	fire = false
	back = false
	_cycle = false


func reset_controls() -> void:
	_touches.clear()
	_pad_steer = 0.0
	steer = 0.0
	gas = false
	brake = false
	fire = false
	back = false
	_cycle = false
	_recount()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_controls()
