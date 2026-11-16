class_name Results
extends Control
## Post-race standings from Game.last_result. The rows arrive one after
## another, first place first.

const ROW_STAGGER := 0.07
const FAN_TALLY_TIME := 1.2
var row_cells: Array = []      # one Array of the four cells per driver
var star_row: StarRow          # the stars a cup event earned
## The fan tally: what this race earned and the new total, counted up.
var fans_earned := 0
var fans_before := 0
var fans_total := 0
var fan_shown := 0.0: set = _show_fans
var fan_tally_delay := 0.0
var _fans_label: Label
var _fans_total_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var r: Dictionary = Game.last_result
	var place := int(r.get("place", 6))
	var n := int(r.get("n", 6))
	var city: Dictionary = Data.city(str(r.get("city", "tirane")))
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		mc.add_theme_constant_override("margin_" + side, 60)
	mc.add_theme_constant_override("margin_top", 30)
	mc.add_theme_constant_override("margin_bottom", 26)
	UiTheme.safe_area(self).add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mc.add_child(v)
	var points := str(r.get("mode", "race")) == "points"
	var event := Data.cup_event(str(r.get("event", "")))
	if points:
		v.add_child(UiTheme.label(Data.t("arena.title"), 23, UiTheme.CYAN))
	elif not event.is_empty():
		v.add_child(UiTheme.label(("%s · %s" % [Data.t("cup.tirana.name"), Data.t("cup.event.%s.name" % event.id)]).to_upper(), 23, UiTheme.CYAN))
	else:
		v.add_child(UiTheme.label(("%s · %s" % [Data.city_name(city.id), Data.env_label(str(r.get("env", city.env)))]).to_upper(), 23, UiTheme.CYAN))
	var col := UiTheme.AMBER if place == 1 else (UiTheme.TEXT if place <= 3 else UiTheme.MUTED)
	var place_row := HBoxContainer.new()
	place_row.add_theme_constant_override("separation", 24)
	place_row.add_child(UiTheme.headline(Data.ordinal(place), 64, col, HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(place_row)
	if not event.is_empty():
		var earned := int(r.get("stars", 0))
		star_row = StarRow.new(earned, 40.0)
		star_row.name = "EventStars"
		star_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		place_row.add_child(star_row)
		var goal_text := Data.t("cup.goal", Data.cup_goal_text(event)) + " · " + (Data.t("cup.goal_met") if bool(r.get("goal_met", false)) else Data.t("cup.goal_missed"))
		if earned > int(r.get("stars_before", 0)):
			goal_text += " · " + Data.t("cup.new_best")
		var goal := UiTheme.label(goal_text, 22, UiTheme.AMBER)
		goal.name = "EventGoal"
		goal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		place_row.add_child(goal)
	var msg := UiTheme.label(Data.place_msg(place, n), 25, UiTheme.MUTED)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(msg)
	v.add_child(UiTheme.spacer(4))
	var panel := UiTheme.panel(14)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	sc.add_child(grid)
	var headers := ["#", Data.t("results.column.driver"), Data.t("results.column.time"), Data.t("results.column.best_lap")]
	if points:
		headers = ["#", Data.t("results.column.driver"), Data.t("results.column.points"), Data.t("results.column.hits")]
	for column in headers.size():
		var l := UiTheme.label(str(headers[column]).to_upper(), 22, UiTheme.MUTED)
		if column == 1:  # the driver column takes the spare width
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
	var rows: Array = r.get("rows", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		var me := bool(row.get("is_player", false))
		var c := UiTheme.TEXT if me else UiTheme.MUTED
		grid.add_child(UiTheme.label(str(i + 1), 27, c, true))
		var nm := HBoxContainer.new()
		nm.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.color = Color.html(str(row.get("color", "ffffff")))
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.add_child(dot)
		nm.add_child(UiTheme.label(Data.t("results.you", str(row.name)) if me else str(row.name), 27, c, me))
		grid.add_child(nm)
		if points:
			grid.add_child(UiTheme.label(str(int(row.get("score", 0))), 25, c))
			grid.add_child(UiTheme.label(str(int(row.get("hits", 0))), 25, c))
		else:
			var finished := bool(row.get("finished", false))
			grid.add_child(UiTheme.label(Game.fmt_time(float(row.time)) if finished else Data.t("results.unfinished"), 25, c))
			grid.add_child(UiTheme.label(Game.fmt_time(float(row.get("best_lap", INF))), 25, c))
		var cells: Array = []
		for cell in 4:
			var control: Control = grid.get_child(grid.get_child_count() - 4 + cell)
			control.modulate.a = 0.0
			cells.append(control)
		row_cells.append(cells)
	var best := float(r.get("best_lap", INF))
	var record: Dictionary = Settings.stats.best_laps
	var rec_t := float(record.get(city.id, INF))
	var foot := Data.t("results.best_lap", Game.fmt_time(best))
	if points:
		foot = Data.t("results.points", int(r.get("score", 0)))
	elif best < INF and best <= rec_t:
		foot += "  ·  " + Data.t("results.new_record")
	elif rec_t < INF:
		foot += "  ·  " + Data.t("results.record", Game.fmt_time(rec_t))
	v.add_child(UiTheme.label(foot, 23, UiTheme.MUTED))
	if not points:
		fans_earned = maxi(0, int(r.get("fans", 0)))
		fans_before = maxi(0, int(r.get("fans_before", 0)))
		fans_total = maxi(fans_before, int(r.get("fans_total", fans_before + fans_earned)))
		var fan_row := HBoxContainer.new()
		fan_row.name = "FanTally"
		fan_row.add_theme_constant_override("separation", 18)
		_fans_label = UiTheme.headline("", 34, UiTheme.AMBER, HORIZONTAL_ALIGNMENT_LEFT)
		_fans_label.name = "FansEarned"
		fan_row.add_child(_fans_label)
		_fans_total_label = UiTheme.label("", 23, UiTheme.MUTED)
		_fans_total_label.name = "FansTotal"
		_fans_total_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		fan_row.add_child(_fans_total_label)
		v.add_child(fan_row)
		_show_fans(0.0)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var again := UiTheme.button(Data.t("results.again"), UiTheme.PINK.darkened(0.25), 200)
	again.pressed.connect(func(): Sfx.ui_click(); Game.start_race())
	hb.add_child(again)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var menu := UiTheme.button(Data.t("results.menu"), Color(0, 0, 0, 0), 180)
	menu.pressed.connect(func(): Sfx.ui_back(); Game.goto("menu"))
	hb.add_child(menu)
	if place == 1:
		Sfx.play("finish", "UI", -4.0)
	# The grid has to lay its rows out before they can slide to their places.
	await get_tree().process_frame
	for i in row_cells.size():
		for cell: Control in row_cells[i]:
			UiTheme.slide_in(cell, Vector2(36.0, 0.0), UiTheme.SLIDE_TIME, 0.12 + i * ROW_STAGGER)
	# Once the standings are in, count the fans up.
	if _fans_label != null:
		fan_tally_delay = 0.12 + row_cells.size() * ROW_STAGGER + UiTheme.SLIDE_TIME
		var tally := create_tween()
		tally.tween_property(self, "fan_shown", float(fans_earned), FAN_TALLY_TIME).set_delay(fan_tally_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if fans_earned > 0:
			tally.tween_callback(func() -> void: Sfx.play("pickup", "UI", -6.0))


## Earned fans shown so far, and the total moving up with them.
func _show_fans(value: float) -> void:
	fan_shown = clampf(value, 0.0, float(fans_earned))
	if _fans_label == null:
		return
	var shown := roundi(fan_shown)
	_fans_label.text = Data.t("results.fans", shown)
	_fans_total_label.text = Data.t("results.fans_total", fans_before + roundi(float(fans_total - fans_before) * (fan_shown / float(fans_earned)) if fans_earned > 0 else 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.ui_back()
		Game.goto("menu")
