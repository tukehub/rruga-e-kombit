class_name ArenaHud
extends Control
## Points mode HUD: score, multiplier and place (top-left), the clock
## (top-centre), the scoreboard, health, the carried pickups and messages.

signal slot_selected(index: int)
signal pause_pressed

const SLOT_N := 3

var arena: Arena
var player: ArenaCar
var _score: Label
var _combo: Label
var _place: Label
var _clock: Label
var _health: ColorRect
var _health_text: Label
var _board: VBoxContainer
var _board_rows: Array[Dictionary] = []
var _slots: Array[Button] = []
var _hold_bars: Array[ColorRect] = []
var _slot_key := ""
var _center: Label
var _center_sub: Label
var _center_t := 0.0
var _pop: Label
var _pop_t := 0.0
var _feed: VBoxContainer
var _flash: ColorRect
var _flash_a := 0.0


func setup(p_arena: Arena, p_player: ArenaCar) -> void:
	arena = p_arena
	player = p_player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 0, 0, 0)
	add_child(_flash)
	# score block
	var score_panel := _panel(Vector2(16, 12))
	var score_column := VBoxContainer.new()
	score_column.add_theme_constant_override("separation", -4)
	score_panel.add_child(score_column)
	score_column.add_child(UiTheme.label(Data.t("arena.points"), 16, UiTheme.CYAN))
	var score_row := HBoxContainer.new()
	score_row.add_theme_constant_override("separation", 12)
	score_column.add_child(score_row)
	_score = UiTheme.headline("0", 50, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	_score.custom_minimum_size.x = 150
	score_row.add_child(_score)
	_combo = UiTheme.headline("", 34, UiTheme.AMBER, HORIZONTAL_ALIGNMENT_LEFT)
	_combo.custom_minimum_size.x = 48
	score_row.add_child(_combo)
	_place = UiTheme.label("", 22, UiTheme.MUTED)
	score_column.add_child(_place)
	# clock
	var clock_panel := _panel(Vector2.ZERO)
	clock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	clock_panel.offset_left = -80
	clock_panel.offset_right = 80
	clock_panel.offset_top = 12
	var clock_column := VBoxContainer.new()
	clock_column.add_theme_constant_override("separation", 0)
	clock_panel.add_child(clock_column)
	_clock = UiTheme.headline("0:00", 46, UiTheme.TEXT)
	clock_column.add_child(_clock)
	var bar_back := ColorRect.new()
	bar_back.color = Color(1, 1, 1, 0.15)
	bar_back.custom_minimum_size = Vector2(136, 6)
	clock_column.add_child(bar_back)
	_health = ColorRect.new()
	_health.color = UiTheme.GREEN
	_health.size = Vector2(136, 6)
	bar_back.add_child(_health)
	_health_text = UiTheme.label("", 16, UiTheme.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	clock_column.add_child(_health_text)
	# scoreboard
	var board_panel := _panel(Vector2(16, 132))
	board_panel.custom_minimum_size.x = 250
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", -2)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_panel.add_child(_board)
	for i in arena.cars.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var number := UiTheme.label(str(i + 1), 20, UiTheme.MUTED)
		number.custom_minimum_size.x = 18
		row.add_child(number)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		var name_label := UiTheme.label("", 20, UiTheme.TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(name_label)
		var points := UiTheme.label("", 20, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT)
		points.custom_minimum_size.x = 70
		row.add_child(points)
		_board.add_child(row)
		_board_rows.append({"dot": dot, "name": name_label, "points": points})
	# pause
	var pause := UiTheme.button(Data.t("hud.pause"))
	pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause.offset_left = -76
	pause.offset_right = -16
	pause.offset_top = 12
	pause.offset_bottom = 68
	pause.pressed.connect(func() -> void: pause_pressed.emit())
	add_child(pause)
	# carried pickups
	var inventory := HBoxContainer.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory.offset_left = -118
	inventory.offset_right = 118
	inventory.offset_top = -76
	inventory.offset_bottom = -18
	inventory.alignment = BoxContainer.ALIGNMENT_CENTER
	inventory.add_theme_constant_override("separation", 8)
	add_child(inventory)
	for i in SLOT_N:
		var button := UiTheme.button("")
		button.custom_minimum_size = Vector2(72, 58)
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 40)
		button.add_theme_stylebox_override("normal", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.65 if i == 0 else 0.48), UiTheme.CYAN if i == 0 else Color(1, 1, 1, 0.3), 12, 2))
		var index := i
		button.pressed.connect(func() -> void: slot_selected.emit(index))
		button.visible = false
		inventory.add_child(button)
		_slots.append(button)
		var hold_bar := ColorRect.new()
		hold_bar.color = UiTheme.CYAN
		hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(hold_bar)
		_hold_bars.append(hold_bar)
	# messages
	_center = UiTheme.headline("", 96)
	_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center.offset_left = -500
	_center.offset_right = 500
	_center.offset_top = -150
	_center.offset_bottom = -40
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.modulate.a = 0.0
	add_child(_center)
	_center_sub = UiTheme.label("", 26, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	_center_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_center_sub.offset_left = -500
	_center_sub.offset_right = 500
	_center_sub.offset_top = -36
	_center_sub.offset_bottom = 4
	_center_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_sub.modulate.a = 0.0
	add_child(_center_sub)
	_pop = UiTheme.headline("", 54, UiTheme.AMBER)
	_pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pop.offset_left = -300
	_pop.offset_right = 300
	_pop.offset_top = 30
	_pop.offset_bottom = 100
	_pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pop.modulate.a = 0.0
	add_child(_pop)
	_feed = VBoxContainer.new()
	_feed.position = Vector2(20, 340)
	_feed.size.x = 360
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	_process(0.0)


func _panel(at: Vector2) -> PanelContainer:
	var panel := UiTheme.panel(12)
	panel.position = at
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.5), Color(1, 1, 1, 0.14), 12, 1))
	add_child(panel)
	return panel


static func clock_text(seconds: float) -> String:
	var whole := int(ceil(maxf(0.0, seconds)))
	return "%d:%02d" % [whole / 60, whole % 60]


func feed(text: String, col := UiTheme.TEXT, ttl := 2.6) -> void:
	var line := UiTheme.label(text, 18, col)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 360
	line.set_meta("ttl", ttl)
	_feed.add_child(line)
	while _feed.get_child_count() > 4:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()


func center(text: String, sub := "", seconds := 1.6) -> void:
	_center.text = text
	_center_sub.text = sub
	_center.modulate.a = 1.0
	_center_sub.modulate.a = 1.0 if not sub.is_empty() else 0.0
	_center_t = seconds


func pop(text: String) -> void:
	_pop.text = text
	_pop.modulate.a = 1.0
	_pop_t = 1.0


func flash(col: Color, alpha := 0.4) -> void:
	_flash.color = Color(col, 0.0)
	_flash_a = minf(alpha, 0.5)


func inventory_hold(index: int, fraction: float) -> void:
	for i in _hold_bars.size():
		_hold_bars[i].position = Vector2(4, _slots[i].size.y - 6)
		_hold_bars[i].size = Vector2(maxf(0.0, _slots[i].size.x - 8) * (fraction if i == index else 0.0), 3)


func _process(dt: float) -> void:
	if arena == null:
		return
	_score.text = str(player.score)
	var live := arena.time - player.combo_t <= Arena.COMBO_WINDOW and player.combo > 1
	_combo.text = "×%d" % player.combo if live else ""
	_place.text = Data.t("arena.place", [player.place, arena.cars.size()])
	_clock.text = clock_text(arena.time_left())
	_clock.add_theme_color_override("font_color", UiTheme.RED if arena.time_left() <= 10.0 and arena.started else UiTheme.TEXT)
	var share := clampf(player.health / player.max_hp, 0.0, 1.0)
	_health.size.x = 136.0 * share
	_health.color = UiTheme.GREEN if share > 0.5 else (UiTheme.AMBER if share > 0.25 else UiTheme.RED)
	_health_text.text = Data.t("combat.health", roundi(share * 100.0))
	for i in mini(_board_rows.size(), arena.order.size()):
		var c: ArenaCar = arena.order[i]
		var row: Dictionary = _board_rows[i]
		(row.dot as ColorRect).color = c.color
		(row.name as Label).text = c.name
		(row.points as Label).text = str(c.score)
		var tint := UiTheme.CYAN if c == player else UiTheme.TEXT
		(row.name as Label).add_theme_color_override("font_color", tint)
		(row.points as Label).add_theme_color_override("font_color", tint)
	var key := ""
	for item in player.slots:
		key += str(item.type) + ","
	if key != _slot_key:
		_slot_key = key
		for i in SLOT_N:
			var button := _slots[i]
			button.visible = i < player.slots.size()
			button.icon = PowerupIcons.texture(str(player.slots[i].type)) if button.visible else null
	if _center_t > 0.0:
		_center_t -= dt
		var a := clampf(_center_t / 0.35, 0.0, 1.0)
		_center.modulate.a = a
		if not _center_sub.text.is_empty():
			_center_sub.modulate.a = a
	if _pop_t > 0.0:
		_pop_t -= dt
		_pop.modulate.a = clampf(_pop_t / 0.4, 0.0, 1.0)
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - dt * 1.4)
		_flash.color.a = _flash_a
	for line in _feed.get_children():
		var ttl := float(line.get_meta("ttl")) - dt
		line.set_meta("ttl", ttl)
		line.modulate.a = clampf(ttl / 0.4, 0.0, 1.0)
		if ttl <= 0.0:
			line.queue_free()
