class_name RaceInput
extends Control
## Two thumbs: relative steering on one side, brake and contextual items on the
## other. Pointer ownership lasts until release, even outside a control's rect.

signal fire_pressed(back: bool)
signal action_denied(reason: String)
signal inventory_selected(index: int)
signal inventory_hold_changed(index: int, fraction: float)

const Rules = preload("res://scripts/sim/combat_rules.gd")
const DISCARD_HOLD := 0.65

const DEAD_DEG := 2.2
const TILT_SMOOTH := 14.0
const EDGE := 20.0
const GAP := 12.0
const STEER_SLOT_CLEARANCE := 206.0
const HUD_CLEARANCE := 344.0

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
var _boost_btn: Button
var _boost_fill: ColorRect
var _auto_label: Label
var _steer_marker: ColorRect
var _touches := {}
var _pad_steer := 0.0
var _steer_finger := -1
var _steer_origin := 0.0
var _desktop := false
var _cycle := false
var _driving_enabled := false
var _suspended := false
var _car: CarState
var _race: Race
var _settings_signature := {}
var _inventory_buttons: Array[Button] = []
var _inventory_finger := -1
var _boost := false
var _discard: Dictionary = {}
var _denial_t := 0.0
var _last_denial := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop = OS.get_name() not in ["Android", "iOS"]
	_fire_btn = _mk_button(Data.t("input.no_power"), "fire", Color("ffbc57"))
	_back_btn = _mk_button(Data.t("input.back"), "back", Color("8edbff"))
	_gas_btn = _mk_button(Data.t("input.gas"), "gas", Color("77e8b0"))
	_brake_btn = _mk_button(Data.t("input.brake"), "brake", Color("ff9c94"))
	_steer_btn = _mk_button(Data.t("input.steer"), "steer", Color("b8d9ef"))
	_boost_btn = _mk_button(Data.t("input.drift", 0), "boost", UiTheme.GREEN)
	_boost_fill = ColorRect.new()
	_boost_fill.color = UiTheme.GREEN
	_boost_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boost_btn.add_child(_boost_fill)
	_auto_label = UiTheme.label(Data.t("input.auto_gas"), 15, Color("77e8b0"), false, HORIZONTAL_ALIGNMENT_CENTER)
	_auto_label.add_theme_font_override("font", UiTheme.body_bold())
	_auto_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_auto_label.add_theme_constant_override("outline_size", 2)
	_auto_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brake_btn.add_child(_auto_label)
	_steer_marker = ColorRect.new()
	_steer_marker.color = UiTheme.CYAN
	_steer_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steer_btn.add_child(_steer_marker)
	_settings_signature = Settings.input_config()
	Settings.changed.connect(_settings_changed)
	resized.connect(_resized)
	_layout_buttons()
	sync_actions()


func bind(car: CarState, race: Race) -> void:
	reset_controls()
	_car = car
	_race = race
	sync_actions()


func is_desktop() -> bool:
	return _desktop


func bind_inventory(buttons: Array[Button]) -> void:
	_inventory_buttons = buttons
	# Native mouse emulation only owns the first finger. Inventory shares the
	# same pointer-ID route as steering so the other thumb can select/discard.
	for button in buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_driving_enabled(enabled: bool) -> void:
	if _driving_enabled == enabled:
		return
	_driving_enabled = enabled
	if not enabled:
		reset_controls()
	sync_actions()


## Only an explicit race resume releases the focus-loss suspension.
func resume_controls() -> void:
	_suspended = false
	reset_controls()


func _can_drive() -> bool:
	return _driving_enabled and not _suspended and _car != null and _race != null and _race.started and not _car.finished


func _can_act() -> bool:
	return _can_drive() and _car.wreck_t <= 0.0 and _car.spin_t <= 0.0


## This is the single geometry contract for drawing and hit testing. Layout
## offsets move both thumb groups inward/upward without covering the inventory.
func control_rect(zone: String) -> Rect2:
	var scale := float(Settings.CONTROL_SCALES[Settings.control_size])
	if zone.begins_with("slot"):
		var index := int(zone.trim_prefix("slot"))
		if index < 0 or index >= _inventory_buttons.size():
			return Rect2()
		var button: Button = _inventory_buttons[index]
		if not is_instance_valid(button) or not button.is_visible_in_tree():
			return Rect2()
		return get_global_transform_with_canvas().affine_inverse() * button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
	if zone == "boost":
		var boost_size := Vector2(100, 58) * scale
		var left := size.x * 0.5 - 76.0 - boost_size.x if Settings.left_handed else size.x * 0.5 + 76.0
		return Rect2(Vector2(left, size.y - 18.0 - boost_size.y), boost_size)
	var manual := not Settings.auto_accel
	var pedal := Vector2(108 if manual else 156, 96 if manual else 92) * scale
	var action := Vector2(228 if manual else 200, 68) * scale
	var rear := Vector2(action.x, 56 * scale)
	var gap := GAP * scale
	var stack_height := pedal.y + action.y + rear.y + 2.0 * gap
	# Mirrored actions also need to clear the taller standings panel on the left.
	var max_rise := maxf(EDGE, size.y - HUD_CLEARANCE - stack_height)
	var bottom := minf(EDGE + Settings.control_offset_y * 70.0, max_rise)
	bottom = minf(bottom, maxf(0.0, size.y - stack_height))
	var inset := EDGE + Settings.control_offset_x * 70.0
	inset = minf(inset, maxf(EDGE, size.x * 0.5 - STEER_SLOT_CLEARANCE - 112.0))
	var rect := Rect2()
	match zone:
		"gas":
			if not manual:
				return rect
			rect = Rect2(Vector2(size.x - inset - pedal.x, size.y - bottom - pedal.y), pedal)
		"brake":
			var left := size.x - inset - (pedal.x * 2.0 + gap if manual else pedal.x)
			rect = Rect2(Vector2(left, size.y - bottom - pedal.y), pedal)
		"fire":
			rect = Rect2(Vector2(size.x - inset - action.x, size.y - bottom - pedal.y - gap - action.y), action)
		"back":
			rect = Rect2(Vector2(size.x - inset - rear.x, size.y - bottom - stack_height), rear)
		"steer":
			var width := minf(360.0 * scale, maxf(0.0, size.x * 0.5 - STEER_SLOT_CLEARANCE - inset))
			rect = Rect2(Vector2(inset, size.y - bottom - 128.0 * scale), Vector2(width, 128.0 * scale))
	if Settings.left_handed and rect.has_area():
		rect.position.x = size.x - rect.end.x
	return rect


func zone_at(local_position: Vector2) -> String:
	if not _can_drive():
		return ""
	for zone in ["gas", "brake", "fire", "back", "boost", "steer"]:
		if zone == "steer" and not Settings.touch_steer:
			continue
		if zone == "back" and not _back_btn.visible:
			continue
		if control_rect(zone).has_point(local_position):
			return zone
	for i in mini(_inventory_buttons.size(), _car.slots.size()):
		if control_rect("slot%d" % i).has_point(local_position):
			return "slot%d" % i
	return ""


func _resized() -> void:
	reset_controls()
	_layout_buttons()


func _settings_changed() -> void:
	var signature := Settings.input_config()
	if signature == _settings_signature:
		return
	_settings_signature = signature
	reset_controls()
	_layout_buttons()
	sync_actions()


func _layout_buttons() -> void:
	for pair in [[_fire_btn, "fire"], [_back_btn, "back"], [_gas_btn, "gas"], [_brake_btn, "brake"], [_steer_btn, "steer"], [_boost_btn, "boost"]]:
		var button: Button = pair[0]
		if button == null:
			continue
		var rect := control_rect(pair[1])
		button.add_theme_font_size_override("font_size", roundi((16.0 if pair[1] == "boost" else 21.0) * float(Settings.CONTROL_SCALES[Settings.control_size])))
		button.position = rect.position
		button.size = rect.size
		button.modulate.a = Settings.control_opacity
	if _steer_btn != null:
		_steer_btn.visible = Settings.touch_steer
		_gas_btn.visible = not Settings.auto_accel
	if _auto_label != null:
		_auto_label.position = Vector2(0, _brake_btn.size.y - 24)
		_auto_label.size = Vector2(_brake_btn.size.x, 20)
		_auto_label.visible = Settings.auto_accel
	_update_marker()


func _mk_button(text: String, zone: String, col: Color) -> Button:
	var button := Button.new()
	button.name = zone.capitalize() + "Control"
	button.text = text
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	# Buttons draw feedback; pointer IDs handle real simultaneous touches.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.toggle_mode = true
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30)
	var normal := UiTheme.flat(Color(0.025, 0.045, 0.06, 0.64), Color(col, 0.8), 14, 2)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	var pressed := UiTheme.flat(Color(col.darkened(0.5), 0.85), col.lightened(0.25), 14, 2)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", UiTheme.flat(Color(0.025, 0.045, 0.06, 0.48), Color(col, 0.25), 14, 2))
	button.add_theme_font_override("font", UiTheme.body_bold())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.7, 0.75, 0.78))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	button.add_theme_constant_override("outline_size", 2)
	if zone == "boost":
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
			style.content_margin_top = 3
			style.content_margin_bottom = 7
			button.add_theme_stylebox_override(state, style)
	add_child(button)
	return button


func action_available(backward: bool) -> bool:
	return _can_act() and bool(_race.item_status(_car, backward).ready)


func sync_actions() -> void:
	if _fire_btn == null:
		return
	var type := _car.slot_type() if _car != null else ""
	_fire_btn.text = Data.t("input.fire.%s" % type) if Data.has_text("input.fire.%s" % type) else Data.t("input.no_power")
	if type == "repair" and _car.health >= _car.max_hp * 0.97:
		_fire_btn.text = Data.t("input.full")
	elif type == "shock" and _race != null and _race.leader() == _car:
		_fire_btn.text = Data.t("hint.deny.first")
	_fire_btn.icon = PowerupIcons.texture(type) if Data.PW.has(type) else null
	_back_btn.icon = _fire_btn.icon
	_back_btn.text = Data.t("input.back.%s" % type) if Data.has_text("input.back.%s" % type) else Data.t("input.back")
	_back_btn.visible = type in ["eagle", "bolt", "mine", "nitro"]
	_back_btn.add_theme_color_override("font_color", UiTheme.AMBER if type == "nitro" else Color.WHITE)
	_fire_btn.disabled = not action_available(false)
	_back_btn.disabled = not action_available(true)
	if _car != null:
		var why: String = _race.item_status(_car).reason
		if why in ["no_target", "too_far"]:
			_fire_btn.text = Data.t("input.no_rival") if why == "no_target" else Data.t("hint.deny.too_far")
		if type == "eagle" and not bool(_race.item_status(_car, true).ready):
			_back_btn.text = Data.t("input.no_rival")
		_boost_btn.text = Data.t("input.turbo") if _car.skill_charge >= 1.0 else Data.t("input.drift", floori(_car.skill_charge * 100.0))
		_boost_btn.disabled = not _can_act() or not Rules.boost_status(_race, _car).is_empty()
		_boost_fill.position = Vector2(8, _boost_btn.size.y - 7)
		_boost_fill.size = Vector2((_boost_btn.size.x - 16) * _car.skill_charge, 3)
	else:
		_boost_btn.disabled = true


func _request_action(backward: bool) -> void:
	if not action_available(backward):
		if _race != null and _car != null:
			_deny(str(_race.item_status(_car, backward).reason))
		return
	if backward:
		back = true
	else:
		fire = true
	fire_pressed.emit(backward)


func _deny(reason: String) -> void:
	if _denial_t <= 0.0 or _last_denial != reason:
		_denial_t = 0.65
		_last_denial = reason
		action_denied.emit(reason)


func _request_boost() -> void:
	var why := Rules.boost_status(_race, _car)
	if why.is_empty() and _can_act():
		_boost = true
	else:
		_deny(why)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if _handle_touch(event, local):
			get_viewport().set_input_as_handled()
	elif _can_drive() and event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_request_action(false)
			KEY_SHIFT, KEY_X:
				_request_action(true)
			KEY_Q, KEY_E:
				_cycle = true
			KEY_B:
				_request_boost()
			_:
				return
		get_viewport().set_input_as_handled()


## Direct harnesses use local coordinates; real input uses the canvas transform.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event, event.position)


func _handle_touch(event: InputEvent, local: Vector2) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			var zone := zone_at(local)
			if zone.is_empty() or (zone == "steer" and _steer_finger != -1):
				return false
			if zone.begins_with("slot") and _inventory_finger != -1:
				return false
			_touches[touch.index] = {"zone": zone}
			if zone in ["fire", "back"]:
				_request_action(zone == "back")
			elif zone == "boost":
				_request_boost()
			elif zone.begins_with("slot"):
				_inventory_finger = touch.index
				var index := int(zone.trim_prefix("slot"))
				_touches[touch.index].merge({"elapsed": 0.0, "discarded": false, "canceled": false, "item": _car.slots[index]})
			elif zone == "steer":
				_steer_finger = touch.index
				_steer_origin = local.x
				_pad_steer = 0.0
		else:
			if not _touches.has(touch.index):
				return false
			var zone: String = _touches[touch.index].zone
			if zone.begins_with("slot"):
				_inventory_finger = -1
				var held: Dictionary = _touches[touch.index]
				var index := int(zone.trim_prefix("slot"))
				if not touch.canceled and not held.canceled and not held.discarded and index < _car.slots.size() and is_same(held.item, _car.slots[index]):
					inventory_selected.emit(index)
				inventory_hold_changed.emit(-1, 0.0)
				if touch.canceled:
					if is_same(_discard, held.item):
						_discard = {}
					if is_same(_car.ctrl.discard, held.item):
						_car.ctrl.discard = {}
			if touch.index == _steer_finger:
				_steer_finger = -1
			if touch.canceled:
				if zone == "fire":
					fire = false
					if _car != null:
						_car.ctrl.fire = false
				elif zone == "back":
					back = false
					if _car != null:
						_car.ctrl.back = false
				elif zone == "boost":
					_boost = false
					_car.ctrl.boost = false
			_touches.erase(touch.index)
		_recount()
		return true
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return false
		if drag.index == _steer_finger:
			var full := minf(control_rect("steer").size.x * 0.4, float(Settings.TOUCH_TRAVEL[Settings.touch_sens]) * float(Settings.CONTROL_SCALES[Settings.control_size]))
			_pad_steer = clampf((local.x - _steer_origin) / maxf(1.0, full), -1.0, 1.0)
			if absf(_pad_steer) < 0.06:
				_pad_steer = 0.0
			_update_marker()
		var zone: String = _touches[drag.index].zone
		if zone.begins_with("slot") and not control_rect(zone).grow(16).has_point(local):
			_touches[drag.index].canceled = true
			inventory_hold_changed.emit(-1, 0.0)
		return true
	return false


func _poll_inventory(dt: float) -> void:
	for held: Dictionary in _touches.values():
		if not str(held.zone).begins_with("slot") or held.canceled or held.discarded:
			continue
		var index := int(str(held.zone).trim_prefix("slot"))
		if not _can_act() or index >= _car.slots.size() or not is_same(held.item, _car.slots[index]):
			held.canceled = true
			inventory_hold_changed.emit(-1, 0.0)
			_deny("inventory_changed" if _can_act() else str(_race.item_status(_car).reason))
			continue
		held.elapsed += dt
		inventory_hold_changed.emit(index, minf(1.0, float(held.elapsed) / DISCARD_HOLD))
		if float(held.elapsed) >= DISCARD_HOLD:
			_discard = held.item
			held.discarded = true
			inventory_hold_changed.emit(-1, 0.0)


func _held(zone: String) -> bool:
	for touch in _touches.values():
		if touch.zone == zone:
			return true
	return false


func _recount(kb_gas := false, kb_brake := false) -> void:
	brake = _can_drive() and (_held("brake") or kb_brake)
	gas = _can_drive() and ((not brake) if Settings.auto_accel else (_held("gas") or kb_gas))
	if _steer_finger == -1:
		_pad_steer = 0.0
	for pair in [[_gas_btn, "gas"], [_brake_btn, "brake"], [_fire_btn, "fire"], [_back_btn, "back"], [_steer_btn, "steer"], [_boost_btn, "boost"]]:
		var button: Button = pair[0]
		if button != null:
			button.set_pressed_no_signal(_held(pair[1]))
	if _auto_label != null:
		_auto_label.text = Data.t("input.gas_cut") if brake or not gas else Data.t("input.auto_gas")
	_update_marker()


func _update_marker() -> void:
	if _steer_marker != null:
		_steer_marker.size = Vector2(16, 4)
		_steer_marker.position = Vector2(_steer_btn.size.x * (0.5 + _pad_steer * 0.38) - 8, _steer_btn.size.y - 17)


static func read_tilt_sensor() -> Vector3:
	var sensor := Input.get_gravity()
	return sensor if sensor.length() >= 0.5 else Input.get_accelerometer()


static func tilt_angle(sensor: Vector3) -> float:
	if not sensor.is_finite() or sensor.length() < 0.5:
		return NAN
	return asin(clampf(sensor.x / sensor.length(), -1.0, 1.0))


static func calibrate_tilt() -> bool:
	var neutral := tilt_angle(read_tilt_sensor())
	if not is_finite(neutral):
		return false
	Settings.tilt_center = neutral
	Settings.save()
	return true


func _sample_tilt(sensor: Vector3, dt: float) -> void:
	var angle := tilt_angle(sensor)
	tilt_ok = is_finite(angle)
	if not tilt_ok:
		roll_deg = 0.0
		steer = move_toward(steer, 0.0, dt * TILT_SMOOTH)
		return
	var roll := (angle - Settings.tilt_center) * (-1.0 if Settings.tilt_invert else 1.0)
	roll_deg = rad_to_deg(roll)
	var full := deg_to_rad(float(Settings.TILT_FULL[Settings.tilt_sens]))
	var dead := deg_to_rad(DEAD_DEG)
	var target := 0.0
	if absf(roll) >= dead:
		target = clampf((roll - signf(roll) * dead) / (full - dead), -1.0, 1.0)
	steer += (target - steer) * minf(1.0, dt * TILT_SMOOTH)


## RaceScene polls before each frame's fixed simulation steps.
func poll(dt: float) -> void:
	_denial_t = maxf(0.0, _denial_t - dt)
	if not Settings.touch_steer:
		_sample_tilt(read_tilt_sensor(), dt)
	if not _can_drive():
		steer = 0.0
		gas = false
		brake = false
		sync_actions()
		return
	_poll_inventory(dt)
	var kb_steer := 0.0
	if _desktop:
		kb_steer = float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
	_recount(_desktop and (Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)), _desktop and (Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)))
	if kb_steer != 0.0:
		steer = kb_steer
	elif Settings.touch_steer:
		steer = _pad_steer
	sync_actions()


func apply(car: CarState) -> void:
	if not _can_drive():
		return
	car.ctrl.steer = steer
	car.ctrl.gas = gas
	car.ctrl.brake = brake
	# A render frame may not contain a fixed tick. Latch each tap until consumed.
	car.ctrl.fire = car.ctrl.fire or (fire and _can_act())
	car.ctrl.back = car.ctrl.back or (back and _can_act())
	car.ctrl.cycle = car.ctrl.cycle or _cycle
	car.ctrl.boost = car.ctrl.boost or (_boost and _can_act())
	if not _discard.is_empty() and _can_act():
		car.ctrl.discard = _discard
	fire = false
	back = false
	_cycle = false
	_boost = false
	_discard = {}


func reset_controls() -> void:
	_touches.clear()
	_inventory_finger = -1
	_steer_finger = -1
	_pad_steer = 0.0
	steer = 0.0
	gas = false
	brake = false
	fire = false
	back = false
	_cycle = false
	_boost = false
	_discard = {}
	inventory_hold_changed.emit(-1, 0.0)
	if _car != null:
		_car.ctrl.steer = 0.0
		_car.ctrl.gas = false
		_car.ctrl.brake = false
		_car.ctrl.fire = false
		_car.ctrl.back = false
		_car.ctrl.cycle = false
		_car.ctrl.select = 0
		_car.ctrl.boost = false
		_car.ctrl.discard = {}
	for button in [_gas_btn, _brake_btn, _fire_btn, _back_btn, _steer_btn, _boost_btn]:
		if button != null:
			button.set_pressed_no_signal(false)
	_update_marker()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
		reset_controls()
