extends VBoxContainer
## The same input options are available before racing and without leaving pause.

var _choices := {}
var _sliders := {}
var _calibrate: Button
var _calibration_note: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	add_child(UiTheme.label(Data.t("controls.title").to_upper(), 25, UiTheme.CYAN, true))
	var levels := [Data.t("level.low"), Data.t("level.normal"), Data.t("level.high")]
	_choice("auto_accel", Data.t("controls.acceleration"), [Data.t("controls.acceleration.manual"), Data.t("controls.acceleration.auto")], [false, true])
	_choice("touch_steer", Data.t("controls.steering"), [Data.t("controls.steering.tilt"), Data.t("controls.steering.touch")], [false, true])
	_choice("left_handed", Data.t("controls.hand"), [Data.t("controls.hand.left"), Data.t("controls.hand.right")], [false, true])
	_choice("steer_mode", Data.t("controls.steer_mode"), [Data.t("controls.steer_mode.wheel"), Data.t("controls.steer_mode.slide")], ["wheel", "slide"])
	_choice("touch_sens", Data.t("controls.touch_sensitivity"), levels, [0, 1, 2])
	_choice("control_size", Data.t("controls.size"), [Data.t("controls.size.small"), Data.t("controls.size.normal"), Data.t("controls.size.large")], [0, 1, 2])
	_slider("control_opacity", Data.t("controls.opacity"), 0.45, 1.0)
	_slider("control_offset_x", Data.t("controls.offset_x"), 0.0, 1.0)
	_slider("control_offset_y", Data.t("controls.offset_y"), 0.0, 1.0)
	_choice("tilt_sens", Data.t("controls.tilt_sensitivity"), levels, [0, 1, 2])
	_choice("tilt_invert", Data.t("controls.tilt_invert"), [Data.t("common.no"), Data.t("common.yes")], [false, true])
	var calibration := HBoxContainer.new()
	calibration.add_theme_constant_override("separation", 12)
	add_child(calibration)
	_calibrate = UiTheme.button(Data.t("controls.calibrate"))
	_calibrate.pressed.connect(func():
		var ok := RaceInput.calibrate_tilt()
		_calibration_note.text = Data.t("controls.calibrated") if ok else Data.t("controls.no_sensor")
		_calibration_note.modulate = UiTheme.GREEN if ok else UiTheme.AMBER
		Sfx.ui_click())
	calibration.add_child(_calibrate)
	var neutral := UiTheme.button(Data.t("controls.neutral"))
	neutral.pressed.connect(func():
		Settings.tilt_center = 0.0
		Settings.save()
		_calibration_note.text = Data.t("controls.neutral_done")
		Sfx.ui_click())
	calibration.add_child(neutral)
	_calibration_note = UiTheme.label(Data.t("controls.calibration_note"), 20, UiTheme.MUTED)
	_calibration_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_calibration_note)
	var reset := UiTheme.button(Data.t("controls.reset_layout"))
	reset.pressed.connect(func():
		Settings.reset_control_layout()
		Settings.save()
		refresh()
		Sfx.ui_click())
	add_child(reset)
	var hint := UiTheme.label(Data.t("controls.hint"), 20, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	visibility_changed.connect(refresh)
	refresh()


func _row(title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := UiTheme.label(title, 23)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	add_child(row)
	return row


func _choice(key: String, title: String, labels: Array, values: Array) -> void:
	var row := _row(title)
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(250, 50)
	pick.add_theme_font_size_override("font_size", 23)
	for label in labels:
		pick.add_item(label)
	pick.item_selected.connect(func(i: int):
		Settings.set(key, values[i])
		Settings.save()
		refresh()
		Sfx.ui_click())
	row.add_child(pick)
	_choices[key] = {"node": pick, "values": values}


func _slider(key: String, title: String, lower: float, upper: float) -> void:
	var row := _row(title)
	var slider := HSlider.new()
	slider.min_value = lower
	slider.max_value = upper
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(250, 50)
	slider.focus_mode = Control.FOCUS_NONE
	var value := UiTheme.label("", 21, UiTheme.MUTED)
	value.custom_minimum_size.x = 60
	row.add_child(slider)
	row.add_child(value)
	slider.value_changed.connect(func(x: float):
		Settings.set(key, x)
		value.text = "%d%%" % roundi(x * 100.0)
		Settings.changed.emit())
	slider.drag_ended.connect(func(_changed: bool): Settings.save())
	_sliders[key] = {"node": slider, "label": value}


func refresh() -> void:
	for key in _choices:
		var entry: Dictionary = _choices[key]
		var pick: OptionButton = entry.node
		pick.select(maxi(0, entry.values.find(Settings.get(key))))
		pick.disabled = (key in ["touch_sens", "steer_mode"] and not Settings.touch_steer) or (key in ["tilt_sens", "tilt_invert"] and Settings.touch_steer)
	for key in _sliders:
		var entry: Dictionary = _sliders[key]
		(entry.node as HSlider).set_value_no_signal(float(Settings.get(key)))
		(entry.label as Label).text = "%d%%" % roundi(float(Settings.get(key)) * 100.0)
	if _calibrate != null:
		_calibrate.disabled = Settings.touch_steer
