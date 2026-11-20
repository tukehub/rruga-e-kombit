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
## The steering wheel's side before the size setting; it sits in the bottom
## left corner WHEEL_MARGIN from both edges.
const WHEEL_SIZE := 260.0
const WHEEL_MARGIN := 28.0
## A touch this far from the hub, in wheel radii, still grabs the wheel.
const WHEEL_HIT := 1.2
## Full lock as drawn, and how fast the drawn wheel follows the thumb.
const WHEEL_LOCK_DEG := 135.0
const WHEEL_FOLLOW := 14.0
## See-through at rest so the road and apex show through; firmer while held.
const WHEEL_IDLE_ALPHA := 0.40
const WHEEL_HELD_ALPHA := 0.72
const WHEEL_FADE_IN := 0.12
const WHEEL_FADE_OUT := 0.25
const WHEEL_TEXTURE := preload("res://assets/ui/controls/steering_wheel.png")
## How fast the drift button fades in and out.
const BOOST_FADE := 6.0
## The HUD feed (top 330, two wrapped lines) ends above this: the wheel stays below.
const FEED_CLEARANCE := 418.0
## Rotate mode: closer to the hub than this (in wheel radii) the finger's
## angle is meaningless, so the sideways move steers instead.
const WHEEL_ANGLE_MIN_R := 0.3
## A turn bigger than this between two touch events is a jump across the
## hub, not a rotation.
const WHEEL_MAX_STEP_DEG := 80.0
const STEER_DEADZONE := 0.06

const DEAD_DEG := 2.2
const TILT_SMOOTH := 14.0
const EDGE := 20.0
const GAP := 12.0
const STEER_SLOT_CLEARANCE := 206.0
const HUD_CLEARANCE := 344.0
const ICONS := {
	"gas": preload("res://assets/ui/controls/gas.svg"),
	"brake": preload("res://assets/ui/controls/brake.svg"),
}
const PRESS_SCALE := 0.93
const PRESS_TIME := 0.09


## What a control shows instead of a word: its icon, or for the steering pad a
## half steering wheel that turns with the thumb, and a ring that lights up
## while the control is held. Drawn inside the button, so the hit rectangle
## from control_rect() is untouched.
class ControlFace extends Control:
	var icon: Texture2D
	var color := Color.WHITE
	var wheel := false
	var steer := 0.0: set = set_steer
	var glow := 0.0: set = set_glow

	func set_steer(value: float) -> void:
		if not is_equal_approx(steer, value):
			steer = value
			queue_redraw()

	func set_glow(value: float) -> void:
		glow = value
		queue_redraw()

	func icon_rect() -> Rect2:
		var side := minf(size.x, size.y) * 0.58
		return Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))

	## The steering wheel sprite, turned about its hub (wheel faces only).
	var wheel_sprite: TextureRect
	## Degrees the sprite is drawn at; eases toward steer * WHEEL_LOCK_DEG.
	var shown_deg := 0.0

	func _ready() -> void:
		if not wheel:
			return
		wheel_sprite = TextureRect.new()
		wheel_sprite.name = "WheelSprite"
		wheel_sprite.texture = WHEEL_TEXTURE
		wheel_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		wheel_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wheel_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wheel_sprite.modulate.a = WHEEL_IDLE_ALPHA
		add_child(wheel_sprite)
		resized.connect(_fit_wheel)
		_fit_wheel()
		advance(0.0)

	func _fit_wheel() -> void:
		wheel_sprite.position = Vector2.ZERO
		wheel_sprite.size = size
		wheel_sprite.pivot_offset = size / 2.0

	func _process(dt: float) -> void:
		if wheel:
			advance(dt)

	## Fades the wheel to its held or resting opacity.
	func fade_to(held: bool) -> void:
		if wheel_sprite == null:
			return
		var to := WHEEL_HELD_ALPHA if held else WHEEL_IDLE_ALPHA
		if has_meta("fade") and (get_meta("fade") as Tween) != null and (get_meta("fade") as Tween).is_valid():
			(get_meta("fade") as Tween).kill()
		if not is_inside_tree():
			wheel_sprite.modulate.a = to
			return
		var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(wheel_sprite, "modulate:a", to, WHEEL_FADE_IN if held else WHEEL_FADE_OUT)
		set_meta("fade", tween)

	## Turns the drawn wheel toward the thumb; released, steer returns to 0
	## and the wheel springs back to centre.
	func advance(dt: float) -> void:
		if wheel_sprite == null:
			return
		var target := clampf(steer, -1.0, 1.0) * WHEEL_LOCK_DEG
		var k := 1.0 if dt <= 0.0 else 1.0 - exp(-WHEEL_FOLLOW * dt)
		if absf(target - shown_deg) < 180.0:
			# Every spring-back (at most 135 degrees) and ordinary steering.
			shown_deg = rad_to_deg(lerp_angle(deg_to_rad(shown_deg), deg_to_rad(target), k))
		else:
			# Full lock to opposite lock is 270 degrees; lerp_angle would go
			# the short way, over the top, so ease straight across instead.
			shown_deg = lerpf(shown_deg, target, k)
		wheel_sprite.rotation_degrees = shown_deg

	func _draw() -> void:
		if wheel:
			return
		var centre := size * 0.5
		var ring := minf(size.x, size.y) * 0.42
		if glow > 0.01:
			draw_arc(centre, ring + 3.0, 0.0, TAU, 48, Color(color, 0.22 * glow), 7.0, true)
			draw_arc(centre, ring, 0.0, TAU, 48, Color(color.lightened(0.3), 0.95 * glow), 2.5, true)
		if icon != null:
			draw_texture_rect(icon, icon_rect(), false, Color.WHITE.lerp(color.lightened(0.5), glow))

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
var _faces := {}                 # zone -> ControlFace
var _touches := {}
var _pad_steer := 0.0
var _steer_finger := -1
var _steer_origin := 0.0
## Rotate mode: steering built up from the finger's turns about the hub, and
## where the finger was at the last event.
var _wheel_acc := 0.0
var _steer_last := Vector2.ZERO
var _desktop := false
var _cycle := false
var _driving_enabled := false
var _suspended := false
var _car: CarState
var _race                      # Race or Arena: whichever the car is in
## The drift boost belongs to races; the points mode switches its button off.
var show_boost := true
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
	# Driving controls carry an icon, not a word; the item buttons keep the
	# power-up's own icon and the line that says what a press will do.
	_gas_btn = _mk_button("", "gas", Color("77e8b0"))
	_brake_btn = _mk_button("", "brake", Color("ff9c94"))
	_steer_btn = _mk_button("", "steer", Color("b8d9ef"))
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
	_settings_signature = Settings.input_config()
	Settings.changed.connect(_settings_changed)
	resized.connect(_resized)
	_layout_buttons()
	sync_actions()


func bind(car: CarState, race) -> void:
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
		# Forward on top, backward under it, the pedals at the bottom.
		"fire":
			rect = Rect2(Vector2(size.x - inset - action.x, size.y - bottom - stack_height), action)
		"back":
			rect = Rect2(Vector2(size.x - inset - rear.x, size.y - bottom - pedal.y - gap - rear.y), rear)
		"steer":
			# A square holding the round wheel, in the bottom left corner;
			# the touch area is the circle around it (see zone_at).
			var margin_x := maxf(WHEEL_MARGIN, inset)
			var margin_y := maxf(WHEEL_MARGIN, bottom)
			var side := minf(WHEEL_SIZE * scale, minf(size.y * 0.42, maxf(0.0, size.x * 0.5 - STEER_SLOT_CLEARANCE - margin_x)))
			# Race messages appear above the wheel; never grow into them.
			side = minf(side, maxf(0.0, size.y - margin_y - FEED_CLEARANCE))
			rect = Rect2(Vector2(margin_x, size.y - margin_y - side), Vector2(side, side))
	if Settings.left_handed and rect.has_area():
		rect.position.x = size.x - rect.end.x
	return rect


func zone_at(local_position: Vector2) -> String:
	if not _can_drive():
		return ""
	for zone in ["gas", "brake", "fire", "back", "boost"]:
		if zone == "boost" and not (show_boost and _boost_btn.visible):
			continue
		if zone == "back" and not _back_btn.visible:
			continue
		if zone == "fire" and not _fire_btn.visible:
			continue
		if control_rect(zone).has_point(local_position):
			return zone
	for i in mini(_inventory_buttons.size(), _car.slots.size()):
		if control_rect("slot%d" % i).has_point(local_position):
			return "slot%d" % i
	if Settings.touch_steer and on_wheel(local_position):
		return "steer"
	return ""


## Thumb travel for full lock when sliding, and on the hub in rotate mode.
func steer_travel() -> float:
	return minf(control_rect("steer").size.x * 0.5, float(Settings.TOUCH_TRAVEL[Settings.touch_sens]) * float(Settings.CONTROL_SCALES[Settings.control_size]))


## Steering for the held finger now at `local`.
##
## Rotate (default): the wheel follows the finger round its hub. Each move
## adds only the small angle turned since the last event, wrapped to
## -180..180, so there is no seam where full left and full right meet (at 9
## and 3 o'clock an absolute angle would flip from one to the other). The
## total is clamped at full lock, so pushing on past the limit stores
## nothing and turning back answers at once. Near the hub, or on a jump
## across it, the angle means nothing and the sideways move steers instead.
##
## Slide: the sideways distance from where the finger landed; past full
## lock that anchor is dragged along, again so nothing has to be undone.
func steer_from_drag(local: Vector2) -> float:
	var full := maxf(1.0, steer_travel())
	var out := 0.0
	if Settings.steer_mode == "slide":
		var offset := local.x - _steer_origin
		if absf(offset) > full:
			_steer_origin = local.x - signf(offset) * full
		out = clampf((local.x - _steer_origin) / full, -1.0, 1.0)
	else:
		_wheel_acc = clampf(_wheel_acc + wheel_delta(_steer_last, local), -1.0, 1.0)
		out = _wheel_acc
	_steer_last = local
	return 0.0 if absf(out) < STEER_DEADZONE else out


## The steering change for a finger moving from `from` to `to` in rotate mode:
## clockwise is right, full lock at Settings.TOUCH_TRAVEL degrees (sensitivity).
func wheel_delta(from: Vector2, to: Vector2) -> float:
	var pad := control_rect("steer")
	var hub := pad.get_center()
	var a := from - hub
	var b := to - hub
	var near := pad.size.x * 0.5 * WHEEL_ANGLE_MIN_R
	if a.length() >= near and b.length() >= near:
		var turned := wrapf(b.angle() - a.angle(), -PI, PI)
		if absf(turned) <= deg_to_rad(WHEEL_MAX_STEP_DEG):
			return turned / deg_to_rad(float(Settings.TOUCH_TRAVEL[Settings.touch_sens]))
	return (to.x - from.x) / maxf(1.0, steer_travel())


## True inside the generous circle around the steering wheel's hub.
func on_wheel(local_position: Vector2) -> bool:
	var pad := control_rect("steer")
	return pad.has_area() and local_position.distance_to(pad.get_center()) <= pad.size.x * 0.5 * WHEEL_HIT


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
		button.pivot_offset = rect.size * 0.5
		button.modulate.a = 1.0 if pair[1] == "steer" else Settings.control_opacity
	if _steer_btn != null:
		_steer_btn.visible = Settings.touch_steer
		_boost_btn.visible = show_boost and _car != null and _car.skill_charge > 0.0
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
	# Every bottom control wears the same dark glass; a held control lights
	# up in its own colour.
	var glass_normal := UiTheme.glass()
	var glass_pressed := UiTheme.glass()
	glass_pressed.bg_color = Color(col.darkened(0.55), 0.82)
	glass_pressed.border_color = Color(col.lightened(0.2), 0.9)
	var glass_disabled := UiTheme.glass()
	glass_disabled.bg_color.a = 0.5
	glass_disabled.border_color.a = 0.15
	for style in [glass_normal, glass_pressed, glass_disabled]:
		style.content_margin_left = 8
		style.content_margin_right = 8
	var normal: StyleBox = glass_normal
	var pressed: StyleBox = glass_pressed
	var disabled: StyleBox = glass_disabled
	if zone == "steer":
		# The wheel is the whole picture: no box around it.
		normal = StyleBoxEmpty.new()
		pressed = StyleBoxEmpty.new()
		disabled = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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
	var face := ControlFace.new()
	face.name = "Face"
	face.color = col
	face.icon = ICONS.get(zone)
	face.wheel = zone == "steer"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(face)
	_faces[zone] = face
	return button


## Held controls shrink a little and light their ring; both ease in and out.
func _show_pressed(zone: String, button: Button, held: bool) -> void:
	button.set_pressed_no_signal(held)
	if bool(button.get_meta("shown_held", false)) == held:
		return
	button.set_meta("shown_held", held)
	var face: ControlFace = _faces[zone]
	if face.wheel:
		face.fade_to(held)
	if not is_inside_tree():
		button.scale = Vector2.ONE * (PRESS_SCALE if held else 1.0)
		face.glow = 1.0 if held else 0.0
		return
	if button.has_meta("press_tween"):
		var running: Tween = button.get_meta("press_tween")
		if running != null and running.is_valid():
			running.kill()
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE * (PRESS_SCALE if held else 1.0), PRESS_TIME)
	tween.tween_property(face, "glow", 1.0 if held else 0.0, PRESS_TIME if held else PRESS_TIME * 2.0)
	button.set_meta("press_tween", tween)


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
	_fire_btn.icon = PowerupIcons.texture(type) if Data.has_pw(type) else null
	# Nothing to fire: no button at all, the corner stays clear.
	_fire_btn.visible = Data.has_pw(type)
	_back_btn.icon = _fire_btn.icon
	_back_btn.text = Data.t("input.back.%s" % type) if Data.has_text("input.back.%s" % type) else Data.t("input.back")
	_back_btn.visible = _race != null and _race.has_back(type)
	_fire_btn.disabled = not action_available(false)
	_back_btn.disabled = not action_available(true)
	if _car != null:
		var why: String = _race.item_status(_car).reason
		if why in ["no_target", "too_far"]:
			_fire_btn.text = Data.t("input.no_rival") if why == "no_target" else Data.t("hint.deny.too_far")
		if type == "eagle" and not bool(_race.item_status(_car, true).ready):
			_back_btn.text = Data.t("input.no_rival")
		_boost_btn.text = Data.t("input.turbo") if _car.skill_charge >= 1.0 else Data.t("input.drift", floori(_car.skill_charge * 100.0))
		_boost_btn.disabled = not _can_act() or not str(_race.boost_status(_car)).is_empty()
		_boost_fill.position = Vector2(8, _boost_btn.size.y - 7)
		_boost_fill.size = Vector2((_boost_btn.size.x - 16) * _car.skill_charge, 3)
		_fade_boost(_car.skill_charge > 0.0)
	else:
		_boost_btn.disabled = true
		_fade_boost(false)


## The drift counter only shows while there is drift to show.
func _fade_boost(wanted: bool) -> void:
	var dt := get_process_delta_time() if is_inside_tree() else 1.0
	if dt <= 0.0:
		dt = 1.0 / 60.0
	var a := move_toward(_boost_btn.modulate.a, Settings.control_opacity if wanted else 0.0, dt * BOOST_FADE)
	_boost_btn.modulate.a = a
	# Tappable as soon as there is drift; only the look fades.
	_boost_btn.visible = show_boost and (wanted or a > 0.01)


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
	var why := str(_race.boost_status(_car))
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
				_steer_last = local
				_wheel_acc = 0.0
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
			_pad_steer = steer_from_drag(local)
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
			_show_pressed(pair[1], button, _held(pair[1]))
	if _auto_label != null:
		_auto_label.text = Data.t("input.gas_cut") if brake or not gas else Data.t("input.auto_gas")
	_update_marker()


func _update_marker() -> void:
	if _faces.has("steer"):
		(_faces["steer"] as ControlFace).steer = _pad_steer


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
	for pair in [[_gas_btn, "gas"], [_brake_btn, "brake"], [_fire_btn, "fire"], [_back_btn, "back"], [_steer_btn, "steer"], [_boost_btn, "boost"]]:
		if pair[0] != null:
			_show_pressed(pair[1], pair[0], false)
	_update_marker()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_suspended = true
		reset_controls()
