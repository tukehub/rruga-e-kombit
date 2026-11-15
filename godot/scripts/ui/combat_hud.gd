extends Control
## Compact threat/status information in the gap below the mirror. Only the
## border pulses at critical health; no additional full-screen flashes.

const Rules = preload("res://scripts/sim/combat_rules.gd")
var race: Race
var player: CarState
var _effects: HBoxContainer
var _states := {}
var _warning: PanelContainer
var _warning_text: Label
var _health: Label
var _warning_clock := 0.0
var _critical_clock := 0.0
var _critical := false
var _was_urgent := false
var threat := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects = HBoxContainer.new()
	_effects.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_effects.offset_left = -130
	_effects.offset_right = 330
	_effects.offset_top = 99
	_effects.offset_bottom = 137
	_effects.add_theme_constant_override("separation", 8)
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_effects)
	for key in ["shield", "nitro", "recovery"]:
		var panel := UiTheme.panel(8)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.custom_minimum_size = Vector2(140, 36)
		var style := UiTheme.flat(Color(0.015, 0.025, 0.04, 0.86), Color(1, 1, 1, 0.25), 8, 1)
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		panel.add_theme_stylebox_override("panel", style)
		_effects.add_child(panel)
		var content := Control.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(content)
		var label := UiTheme.label("", 16, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.offset_bottom = -4
		content.add_child(label)
		var bar := ProgressBar.new()
		bar.step = 0.001
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size.y = 4
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = -4
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for state in ["background", "fill"]:
			var color: Color = Color(1, 1, 1, 0.12) if state == "background" else {"shield": UiTheme.CYAN, "nitro": UiTheme.GREEN, "recovery": UiTheme.VIOLET}[key]
			var bar_style := UiTheme.flat(color, Color.TRANSPARENT, 2)
			for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
				bar_style.set_content_margin(side, 0)
			bar.add_theme_stylebox_override(state, bar_style)
		content.add_child(bar)
		_states[key] = {"panel": panel, "label": label, "bar": bar}
		panel.hide()
	_warning = UiTheme.panel(10)
	_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_warning.offset_left = -130
	_warning.offset_right = 330
	_warning.offset_top = 140
	_warning.offset_bottom = 174
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var warning_style := UiTheme.flat(Color(0.025, 0.035, 0.055, 0.9), Color(1, 1, 1, 0.2), 10, 1)
	warning_style.content_margin_top = 0
	warning_style.content_margin_bottom = 0
	_warning.add_theme_stylebox_override("panel", warning_style)
	add_child(_warning)
	_warning_text = UiTheme.label("", 18, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
	_warning_text.add_theme_font_override("font", UiTheme.body_bold())
	_warning.add_child(_warning_text)
	_warning.hide()
	_health = UiTheme.label("", 18, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	_health.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_health.offset_left = -323
	_health.offset_right = -167
	_health.offset_top = 102
	_health.offset_bottom = 125
	_health.add_theme_font_override("font", UiTheme.body_bold())
	_health.add_theme_color_override("font_outline_color", Color.BLACK)
	_health.add_theme_constant_override("outline_size", 3)
	add_child(_health)


func setup(p_race: Race, p_player: CarState) -> void:
	race = p_race
	player = p_player


func _state(key: String, seconds: float, duration: float, title: String) -> void:
	var entry: Dictionary = _states[key]
	(entry.panel as Control).visible = seconds > 0.0 and race.started and not player.finished
	(entry.label as Label).text = "%s %.1f s" % [title, maxf(0.0, seconds)]
	(entry.bar as ProgressBar).value = clampf(seconds / duration, 0.0, 1.0)


func _process(dt: float) -> void:
	if race == null or player == null:
		return
	_state("shield", player.shield_t, Rules.SHIELD_DURATION, Data.t("combat.shield"))
	_state("nitro", player.nitro_t, player.nitro_duration, Data.t("combat.drift") if player.nitro_from_drift else Data.t("combat.nitro"))
	_state("recovery", maxf(player.recovery_t, player.invuln_t), Rules.RECOVERY_DURATION if player.recovery_t > 0.0 else 2.5, Data.t("combat.recovery") if player.recovery_t > 0.0 else Data.t("combat.protected"))
	var hp := clampf(player.health / player.max_hp, 0.0, 1.0)
	var active := race.started and not player.finished and player.wreck_t <= 0.0
	var critical := active and hp <= 0.25
	_health.text = Data.t("combat.critical", roundi(hp * 100.0)) if critical else Data.t("combat.health", roundi(hp * 100.0))
	_health.modulate = UiTheme.RED if critical else UiTheme.MUTED
	_critical_clock = maxf(0.0, _critical_clock - dt)
	if critical and (not _critical or _critical_clock <= 0.0):
		Sfx.play("denied", "UI", -15.0, 0.8)
		_critical_clock = 8.0
	_critical = critical
	queue_redraw()
	threat = race.incoming_threat(player)
	_warning.visible = active and not threat.is_empty()
	_warning_clock = maxf(0.0, _warning_clock - dt)
	if not _warning.visible:
		_warning_clock = 0.0
		_was_urgent = false
		return
	if bool(threat.urgent) and not _was_urgent:
		_warning_clock = minf(_warning_clock, 0.1)
	_was_urgent = bool(threat.urgent)
	var guarded := bool(threat.shielded)
	var color := UiTheme.CYAN if guarded else (UiTheme.RED if bool(threat.urgent) else UiTheme.AMBER)
	_warning_text.modulate = color
	var direction := Data.t("dir.behind") if bool(threat.behind) else Data.t("dir.ahead")
	if int(threat.side) != 0:
		direction += " · " + (Data.t("dir.right") if int(threat.side) > 0 else Data.t("dir.left"))
	_warning_text.text = "%s · %s · %.1f s" % [Data.t("combat.guarded") if guarded else Data.t("combat.incoming"), direction, float(threat.eta)]
	if int(threat.count) > 1:
		_warning_text.text += " ×%d" % int(threat.count)
	if not guarded and _warning_clock <= 0.0:
		Sfx.play("beep", "UI", -13.0, 1.4 if bool(threat.urgent) else 1.15)
		_warning_clock = 0.4 if bool(threat.urgent) else 1.0


func _draw() -> void:
	if _critical:
		var alpha := 0.24 + 0.08 * sin(race.time * PI)
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(UiTheme.RED, alpha), false, 6.0)
