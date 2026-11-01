class_name Results
extends Control
## Post-race standings from Game.last_result.


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
	add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mc.add_child(v)
	v.add_child(UiTheme.label(("%s · %s" % [city.name, Data.ENV[str(r.get("env", city.env))].label]).to_upper(), 23, UiTheme.CYAN))
	var ord: String = Data.ORD[clampi(place - 1, 0, Data.ORD.size() - 1)]
	var col := UiTheme.AMBER if place == 1 else (UiTheme.TEXT if place <= 3 else UiTheme.MUTED)
	v.add_child(UiTheme.headline(ord, 64, col, HORIZONTAL_ALIGNMENT_LEFT))
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
	for h in ["#", "Shoferi", "Koha", "Xhiro më e mirë"]:
		var l := UiTheme.label(h.to_upper(), 22, UiTheme.MUTED)
		if h == "Shoferi":
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
		nm.add_child(UiTheme.label(str(row.name) + (" (ti)" if me else ""), 27, c, me))
		grid.add_child(nm)
		var finished := bool(row.get("finished", false))
		grid.add_child(UiTheme.label(Game.fmt_time(float(row.time)) if finished else "Pa përfunduar", 25, c))
		grid.add_child(UiTheme.label(Game.fmt_time(float(row.get("best_lap", INF))), 25, c))
	var best := float(r.get("best_lap", INF))
	var record: Dictionary = Settings.stats.best_laps
	var rec_t := float(record.get(city.id, INF))
	var foot := "Xhiro jote më e mirë: %s" % Game.fmt_time(best)
	if best < INF and best <= rec_t:
		foot += "  ·  REKORD I RI!"
	elif rec_t < INF:
		foot += "  ·  Rekordi: %s" % Game.fmt_time(rec_t)
	v.add_child(UiTheme.label(foot, 23, UiTheme.MUTED))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var again := UiTheme.button("Përsërit", UiTheme.PINK.darkened(0.25), 200)
	again.pressed.connect(func(): Sfx.ui_click(); Game.start_race())
	hb.add_child(again)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	var menu := UiTheme.button("Menyja", Color(0, 0, 0, 0), 180)
	menu.pressed.connect(func(): Sfx.ui_back(); Game.goto("menu"))
	hb.add_child(menu)
	if place == 1:
		Sfx.play("finish", "UI", -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Sfx.ui_back()
		Game.goto("menu")
