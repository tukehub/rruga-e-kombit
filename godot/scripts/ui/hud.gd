class_name Hud
extends Control
## In-race HUD: position / lap / clock (top-left), live standings, minimap
## (top-right), speed + health gauge (bottom-right), power-up slots
## (bottom-centre), event feed, centre messages, hit flash. All text Albanian.

signal slot_selected(index: int)
signal pause_pressed

const SLOT_N := 3
const ARC_START := deg_to_rad(135.0)
const ARC_SWEEP := deg_to_rad(270.0)
const Feedback = preload("res://scripts/ui/combat_feedback.gd")
const RouteGuide = preload("res://scripts/sim/route_guide.gd")

var race: Race
var player: CarState
var track: RaceTrack

var _pos: Label
var _pos_n: Label
var _lap: Label
var _time: Label
var _board: VBoxContainer
var _board_key := ""
var _board_gaps: Array[Label] = []
## The cars the proximity list shows right now, in its row order.
var _board_cars: Array[CarState] = []
var _standings: PanelContainer
const STANDINGS_WIDTH := 270.0
## The speed and health card, beside the pedals.
const GAUGE_SIZE := Vector2(156, 92)
## The race's touch controls, to put the speed card beside the pedals; null
## puts it bottom right.
var controls: Control
var _feed: VBoxContainer
var _center: Label
var _center_sub: Label
var _center_t := 0.0
var _flash: ColorRect
var _flash_a := 0.0
var _flash_col := Color.WHITE
var _speed: Label
var _speed_unit: Label
var _gauge: Control
var _slot_name: Label
var _slots: Array[Button] = []
var _slot_key := ""
var combat: Control
var _target_hint: Label
var _hold_index := -1
var _hold_fraction := 0.0
var _hold_bars: Array[ColorRect] = []
var _inventory: HBoxContainer
var _minimap: Control
var _mm_dots: Control
var _mm_flag: Control
var _me: Label
var _fps: Label
var diagnostic_fps := false
var _pop: Label
var _pop_t := 0.0
var _pause: Button
var _mm_pts := PackedVector2Array()
var _mm_rect := Rect2()
var _mm_scale := 1.0
var _mm_min := Vector2.ZERO
var _route_guide: RouteGuide
var _corner_caption: Label
var _corner_panel: PanelContainer


func animate_pickup(kind: String, index: int) -> void:
	# A brief icon travels into the newly filled slot without covering the road.
	var icon := TextureRect.new()
	icon.texture = PowerupIcons.texture(kind)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = Vector2(44, 44)
	icon.position = Vector2(size.x * 0.5 - 22, size.y - 155)
	add_child(icon)
	var count := mini(3, maxi(1, player.slots.size()))
	var center_x := size.x * 0.5 + (48.0 if Settings.left_handed else -48.0)
	var destination := Vector2(center_x - (count * 80.0 - 8.0) * 0.5 + clampi(index, 0, 2) * 80.0 + 21, size.y - 62)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(icon, "position", destination, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(icon, "scale", Vector2(0.68, 0.68), 0.32)
	tween.tween_property(icon, "modulate:a", 0.0, 0.1).set_delay(0.25)
	tween.chain().tween_callback(icon.queue_free)


func _ready() -> void:
	add_to_group("debug_ui")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	_build()
	combat = preload("res://scripts/ui/combat_hud.gd").new()
	add_child(combat)
	# Health lives in the speed card, under the bar it labels.
	var health: Label = combat._health
	health.reparent(_gauge, false)
	health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	health.offset_top = -24
	health.offset_bottom = -4
	health.add_theme_font_size_override("font_size", 15)


func setup(p_race: Race, p_player: CarState, p_track: RaceTrack, p_guide: RouteGuide = null) -> void:
	race = p_race
	player = p_player
	track = p_track
	_route_guide = p_guide if p_guide != null else RouteGuide.new(track)
	_me.text = player.name
	_me.add_theme_color_override("font_color", player.color.lightened(0.2))
	_build_minimap()
	combat.setup(race, player)


func _build() -> void:
	# Screen edges carry information; the road and car remain uncovered.
	var status := UiTheme.panel(12)
	status.position = Vector2(16, 12)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	status.add_child(h)
	_pos = UiTheme.headline("6", 48, UiTheme.TEXT)
	h.add_child(_pos)
	_pos_n = UiTheme.label("/6", 24, UiTheme.MUTED)
	_pos_n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_pos_n)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	_lap = UiTheme.label(Data.t("hud.lap", [1, 2]), 23, UiTheme.CYAN)
	v.add_child(_lap)
	_time = UiTheme.label("0:00.000", 23, UiTheme.TEXT)
	v.add_child(_time)
	var standings := UiTheme.panel(12)
	standings.name = "Standings"
	standings.position = Vector2(16, 102)
	standings.custom_minimum_size.x = STANDINGS_WIDTH
	standings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# No box: three shadowed lines, the car ahead, you, the car behind.
	standings.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(standings)
	_standings = standings
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 3)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standings.add_child(bv)
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 0)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(_board)
	_feed = VBoxContainer.new()
	_feed.position = Vector2(20, 330)
	_feed.size.x = 360
	_feed.add_theme_constant_override("separation", 2)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	var cv := VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cv.offset_top = 170
	cv.offset_left = -340
	cv.offset_right = 340
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cv)
	_center = UiTheme.headline("", 80, UiTheme.AMBER)
	_center.modulate.a = 0.0
	cv.add_child(_center)
	_center_sub = UiTheme.label("", 26, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	_center_sub.modulate.a = 0.0
	cv.add_child(_center_sub)
	_pop = UiTheme.headline("", 40, UiTheme.AMBER)
	_pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pop.offset_left = -200
	_pop.offset_right = 200
	_pop.offset_top = -100
	_pop.modulate.a = 0.0
	add_child(_pop)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_pause = UiTheme.button(Data.t("hud.pause"))
	_pause.add_theme_font_override("font", UiTheme.body_bold())
	_pause.add_theme_font_size_override("font_size", 30)
	_pause.add_theme_stylebox_override("normal", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.8), Color(1, 1, 1, 0.65), 12))
	_pause.add_theme_stylebox_override("hover", UiTheme.flat(Color(0.04, 0.08, 0.12, 0.9), UiTheme.CYAN, 12))
	_pause.add_theme_stylebox_override("pressed", UiTheme.flat(Color(0.02, 0.12, 0.17, 0.95), UiTheme.CYAN, 12))
	_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause.offset_left = -76
	_pause.offset_right = -16
	_pause.offset_top = 12
	_pause.offset_bottom = 64
	_pause.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause)
	_minimap = Control.new()
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -180
	_minimap.offset_right = -16
	_minimap.offset_top = 78
	_minimap.offset_bottom = 208
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	_minimap.resized.connect(func():
		if track != null:
			_build_minimap())
	add_child(_minimap)
	# The track and flag are static and drawn once; only the dots layer between
	# them is redrawn every frame.
	_mm_dots = _minimap_layer(_draw_minimap_dots)
	_mm_flag = _minimap_layer(_draw_minimap_flag)
	_corner_panel = UiTheme.panel(7)
	_corner_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_corner_panel.offset_top = -36
	_corner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var corner_style := UiTheme.flat(Color(0.02, 0.035, 0.05, 0.8), Color(1, 1, 1, 0.15), 7, 1)
	corner_style.content_margin_top = 0
	corner_style.content_margin_bottom = 0
	_corner_panel.add_theme_stylebox_override("panel", corner_style)
	_minimap.add_child(_corner_panel)
	_corner_caption = UiTheme.label("", 16, Color.WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
	_corner_caption.add_theme_font_override("font", UiTheme.body_bold())
	_corner_caption.clip_text = true
	_corner_panel.add_child(_corner_caption)
	# Compact digital speed and damage bar, rather than an opaque corner dial.
	_gauge = Control.new()
	_gauge.name = "SpeedCard"
	_gauge.size = GAUGE_SIZE
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)
	var speed_back := Panel.new()
	speed_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_back.add_theme_stylebox_override("panel", UiTheme.glass())
	_gauge.add_child(speed_back)
	_speed = UiTheme.headline("0", 38, UiTheme.TEXT)
	_speed.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_speed.offset_top = -2
	_speed.offset_bottom = 42
	_gauge.add_child(_speed)
	_speed_unit = UiTheme.label(Data.t("hud.speed_unit"), 14, UiTheme.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_speed_unit.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_speed_unit.offset_top = 38
	_speed_unit.offset_bottom = 56
	_gauge.add_child(_speed_unit)
	_me = UiTheme.label("", 22)
	_me.visible = false
	add_child(_me)
	_slot_name = UiTheme.label("", 23, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_slot_name.offset_left = -210
	_slot_name.offset_right = 210
	_slot_name.offset_top = -108
	_slot_name.offset_bottom = -78
	add_child(_slot_name)
	_target_hint = UiTheme.label("", 16, UiTheme.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_target_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_target_hint.offset_left = -136
	_target_hint.offset_right = 136
	_target_hint.offset_top = -134
	_target_hint.offset_bottom = -110
	_target_hint.clip_text = true
	_target_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_target_hint.add_theme_constant_override("outline_size", 3)
	add_child(_target_hint)
	var inventory := HBoxContainer.new()
	_inventory = inventory
	inventory.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory.offset_left = -166
	inventory.offset_right = 70
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
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_stylebox_override("normal", UiTheme.glass())
		button.add_theme_stylebox_override("hover", UiTheme.glass())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var index := i
		button.pressed.connect(func(): slot_selected.emit(index))
		inventory.add_child(button)
		_slots.append(button)
		var hold_bar := ColorRect.new()
		hold_bar.color = UiTheme.CYAN
		hold_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(hold_bar)
		_hold_bars.append(hold_bar)
		if i == 0:
			# The selected item: the same glass, a full cyan edge.
			var selected := UiTheme.glass()
			selected.border_color = UiTheme.CYAN
			selected.set_border_width_all(2)
			button.add_theme_stylebox_override("normal", selected)
			button.add_theme_stylebox_override("hover", selected)
	_fps = UiTheme.label("", 18, UiTheme.TEXT)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fps.offset_left = -350
	_fps.offset_right = -140
	_fps.offset_top = 140
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_fps)
	for label in [_slot_name, _speed_unit, _center_sub, _fps]:
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		label.add_theme_constant_override("outline_size", 4)


func _build_minimap() -> void:
	_mm_pts.clear()
	var step := maxi(1, track.M / 200)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for i in range(0, track.M, step):
		var p := Vector2(track.X[i], track.Z[i])
		_mm_pts.append(p)
		mn = mn.min(p)
		mx = mx.max(p)
	var sz := _minimap.size
	var ext := (mx - mn).max(Vector2(1, 1))
	var map_size := Vector2(sz.x, maxf(40.0, sz.y - 38.0))
	_mm_scale = minf((map_size.x - 24.0) / ext.x, (map_size.y - 24.0) / ext.y)
	_mm_min = mn
	_mm_rect = Rect2((map_size - ext * _mm_scale) * 0.5, ext * _mm_scale)
	_minimap.queue_redraw()
	if _mm_flag != null:
		_mm_flag.queue_redraw()


func _mm(p: Vector3) -> Vector2:
	return _mm_rect.position + (Vector2(p.x, p.z) - _mm_min) * _mm_scale


func _minimap_layer(draw_fn: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.draw.connect(draw_fn)
	_minimap.add_child(layer)
	return layer


func _draw_minimap() -> void:
	if _mm_pts.is_empty() or race == null:
		return
	var pts := PackedVector2Array()
	for p in _mm_pts:
		pts.append(_mm_rect.position + (p - _mm_min) * _mm_scale)
	pts.append(pts[0])
	_minimap.draw_polyline(pts, Color(0, 0, 0, 0.6), 9.0, true)
	_minimap.draw_polyline(pts, Color(UiTheme.CYAN, 0.85), 3.5, true)
	# Start and finish share this circuit point.
	var p0 := _mm(track.pos(0.0, 0.0))
	_minimap.draw_circle(p0, 5.0, Color(0.02, 0.02, 0.02, 0.9))
	_minimap.draw_circle(p0, 3.0, Color(1.0, 0.84, 0.18))


func _draw_minimap_dots() -> void:
	if _mm_pts.is_empty() or race == null:
		return
	for c in race.cars:
		if c == player:
			continue
		var q := _mm(track.pos(c.s, c.d))
		_mm_dots.draw_circle(q, 4.0, Color(0, 0, 0, 0.7))
		_mm_dots.draw_circle(q, 3.0, c.color)
	var pp := _mm(track.pos(player.s, player.d))
	_mm_dots.draw_circle(pp, 6.5, Color(0, 0, 0, 0.8))
	_mm_dots.draw_circle(pp, 5.0, Color.WHITE)


func _draw_minimap_flag() -> void:
	if _mm_pts.is_empty() or race == null:
		return
	# High-contrast checkered flag stays visible even when cars cover the line.
	var p0 := _mm(track.pos(0.0, 0.0))
	var flag := Vector2(clampf(p0.x + 7.0, 2.0, _minimap.size.x - 20.0), clampf(p0.y - 20.0, 2.0, _minimap.size.y - 18.0))
	_mm_flag.draw_line(p0, flag + Vector2(1, 15), Color(0.02, 0.02, 0.02, 0.9), 3.0, true)
	_mm_flag.draw_line(p0, flag + Vector2(1, 15), Color(1.0, 0.84, 0.18), 1.5, true)
	_mm_flag.draw_rect(Rect2(flag - Vector2(1, 1), Vector2(18, 14)), Color(0.02, 0.02, 0.02, 0.95))
	_mm_flag.draw_rect(Rect2(flag, Vector2(16, 12)), Color.WHITE)
	_mm_flag.draw_rect(Rect2(flag, Vector2(8, 6)), Color(0.04, 0.04, 0.04))
	_mm_flag.draw_rect(Rect2(flag + Vector2(8, 6), Vector2(8, 6)), Color(0.04, 0.04, 0.04))


func _draw_gauge() -> void:
	if player == null:
		return
	var hp := clampf(player.health / player.max_hp, 0.0, 1.0)
	var col := UiTheme.GREEN if hp > 0.5 else (UiTheme.AMBER if hp > 0.25 else UiTheme.RED)
	var bar := Rect2(12, 60, GAUGE_SIZE.x - 24, 5)
	_gauge.draw_rect(bar, Color(0.01, 0.02, 0.03, 0.65))
	_gauge.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp, bar.size.y)), col)
	if player.shield_t > 0.0:
		_gauge.draw_line(bar.position - Vector2(0, 3), Vector2(bar.end.x, bar.position.y - 3), UiTheme.CYAN, 2.0)


func feed(text: String, col := UiTheme.TEXT, ttl := 2.6) -> void:
	var l := UiTheme.label(text, 16, col)
	l.custom_minimum_size.y = 32
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.set_meta("ttl", ttl)
	_feed.add_child(l)
	while _feed.get_child_count() > 2:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))


func center(text: String, sub := "", dur := 1.6) -> void:
	_center.text = text
	_center_sub.text = sub
	_center.modulate.a = 1.0
	_center_sub.modulate.a = 1.0 if sub != "" else 0.0
	_center_t = dur
	_center.scale = Vector2.ONE


func finish_place(place: String, time: String) -> void:
	center(place, time, 3.6)
	_center.pivot_offset = _center.size * 0.5
	_center.scale = Vector2(0.65, 0.65)
	var tween := create_tween()
	tween.tween_property(_center, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_center, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE)


func pop(text: String) -> void:
	_pop.text = text
	_pop.modulate.a = 1.0
	_pop_t = 1.1


func flash(col: Color, a := 0.45) -> void:
	_flash_col = col
	_flash_a = minf(a, 0.55)


func inventory_hold(index: int, fraction: float) -> void:
	_hold_index = index
	_hold_fraction = fraction
	for i in _hold_bars.size():
		_hold_bars[i].position = Vector2(4, _slots[i].size.y - 6)
		_hold_bars[i].size = Vector2(maxf(0.0, _slots[i].size.x - 8) * (fraction if i == index else 0.0), 3)


func _process(dt: float) -> void:
	if race == null or player == null:
		return
	# Put short feedback above the steering thumb, opposite the item stack.
	# Bounded wrapping prevents long explanations covering the driving controls.
	_feed.position = Vector2(size.x - 380.0 if Settings.left_handed else 20.0, 330)
	_inventory.offset_left = -70 if Settings.left_handed else -166
	_inventory.offset_right = 166 if Settings.left_handed else 70
	_slot_name.offset_left = _inventory.offset_left
	_slot_name.offset_right = _inventory.offset_right
	# fades
	if _center_t > 0.0:
		_center_t -= dt
		if _center_t <= 0.0:
			_center.modulate.a = 0.0
			_center_sub.modulate.a = 0.0
		elif _center_t < 0.35:
			var a := _center_t / 0.35
			_center.modulate.a = a
			_center_sub.modulate.a = a
	if _pop_t > 0.0:
		_pop_t -= dt
		_pop.modulate.a = clampf(_pop_t / 0.4, 0.0, 1.0)
		_pop.offset_top = -120.0 - (1.1 - _pop_t) * 40.0
	if _flash_a > 0.0:
		_flash_a = maxf(0.0, _flash_a - dt * 3.0)
		_flash.color = Color(_flash_col, _flash_a)
	for ch in _feed.get_children():
		var ttl := float(ch.get_meta("ttl")) - dt
		ch.set_meta("ttl", ttl)
		if ttl <= 0.0:
			_feed.remove_child(ch)
			ch.queue_free()
		elif ttl < 0.4:
			ch.modulate.a = ttl / 0.4
	# text
	_pos.text = str(player.place)
	_pos_n.text = "/%d" % race.cars.size()
	var lap := clampi(player.lap + 1, 1, race.laps)
	_lap.text = Data.t("hud.finished") if player.finished else Data.t("hud.lap", [lap, race.laps])
	_time.text = Game.fmt_time(player.finish_time if player.finished else race.time)
	_update_corner_caption()
	_speed.text = str(roundi(absf(player.v) * 3.6))
	# standings: only the car ahead, you and the car behind
	_board_cars = neighbours(race.order, player)
	var key := ""
	for c in _board_cars:
		key += str(c.id) + ("f" if c.finished else "") + ","
	if key != _board_key:
		_board_key = key
		_board_gaps.clear()
		for ch in _board.get_children():
			_board.remove_child(ch)
			ch.queue_free()
		for c in _board_cars:
			var place := race.order.find(c) + 1
			var mine := c == player
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var n := _shadowed(UiTheme.label(str(place), 23, UiTheme.CYAN if mine else UiTheme.TEXT, false))
			n.custom_minimum_size.x = 24
			row.add_child(n)
			var dot := ColorRect.new()
			dot.color = c.color
			dot.custom_minimum_size = Vector2(8, 8)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var nm := _shadowed(UiTheme.label(c.name + (" ✓" if c.finished else ""), 23, UiTheme.CYAN if mine else UiTheme.TEXT))
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(nm)
			var gap := _shadowed(UiTheme.label("", 20, UiTheme.CYAN if mine else UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT))
			gap.custom_minimum_size.x = 70
			row.add_child(gap)
			_board_gaps.append(gap)
			_board.add_child(row)
	for i in mini(_board_cars.size(), _board_gaps.size()):
		_board_gaps[i].text = gap_text(_board_cars[i])
	_place_gauge()
	# slots
	var sk := "slots:"
	for s in player.slots:
		sk += s.type + str(s.ammo) + ","
	if sk != _slot_key:
		_slot_key = sk
		for i in SLOT_N:
			var b := _slots[i]
			if i < player.slots.size():
				var s = player.slots[i]
				var pw: Dictionary = Data.PW[s.type]
				b.icon = PowerupIcons.texture(s.type)
				b.text = str(s.ammo) if s.type == "bolt" else ""
				b.tooltip_text = Data.pw_name(s.type)
				b.add_theme_color_override("font_color", Color.html(pw.col).lightened(0.25))
				b.visible = true
			else:
				# An empty slot stays as a faint frame: three places, always.
				b.text = ""
				b.icon = null
				b.tooltip_text = ""
				b.visible = true
			b.modulate.a = 1.0 if i < player.slots.size() else 0.4
		_slot_name.text = Data.pw_name(player.slots[0].type).to_upper() if not player.slots.is_empty() else ""
	if _hold_index >= 0:
		_target_hint.text = Data.t("hud.hold_to_drop", roundi(_hold_fraction * 100.0))
		_target_hint.modulate = UiTheme.CYAN
	else:
		var status := race.item_status(player)
		_target_hint.text = Feedback.target_hint(race, player, status)
		_target_hint.modulate = UiTheme.MUTED if bool(status.ready) else UiTheme.AMBER
	_mm_dots.queue_redraw()
	_gauge.queue_redraw()
	# Frame times are for development builds only.
	if OS.is_debug_build() and (Settings.show_fps or diagnostic_fps):
		_fps.text = Data.t("hud.fps", [Game.frame_ms_avg, Game.frame_ms_max, Engine.get_frames_per_second()])
	else:
		_fps.text = ""


func _update_corner_caption() -> void:
	_corner_panel.visible = race.started and not player.finished
	if not _corner_panel.visible:
		return
	var corner := _route_guide.next(player.s, clampf(absf(player.v) * 3.0 + 40.0, 90.0, 200.0))
	if corner.is_empty():
		_corner_caption.text = Data.t("hud.corner.straight")
		_corner_caption.modulate = UiTheme.MUTED
		return
	if player.progress + float(corner.distance) > race.laps * race.L:
		_corner_caption.text = Data.t("hud.corner.finish", maxi(0, roundi(race.laps * race.L - player.progress)))
		_corner_caption.modulate = UiTheme.AMBER
		return
	_corner_caption.text = "%s %s" % ["→" if corner.direction == "right" else "←", "%dm" % roundi(corner.distance) if float(corner.distance) > 5.0 else Data.t("hud.corner.now")]
	_corner_caption.modulate = UiTheme.AMBER if int(corner.severity) >= 2 else Color.WHITE


## The car ahead of `me`, `me`, and the car behind, as far as they exist.
static func neighbours(order: Array, me: CarState) -> Array[CarState]:
	var out: Array[CarState] = []
	var i := order.find(me)
	if i < 0:
		return out
	for k in [i - 1, i, i + 1]:
		if k >= 0 and k < order.size():
			out.append(order[k])
	return out


## "TI" for the player, else metres ahead (+) or behind (-) on race progress.
func gap_text(c: CarState) -> String:
	if c == player:
		return Data.t("hud.you")
	var metres := roundi(c.progress - player.progress)
	return "+%dm" % metres if metres > 0 else "%dm" % metres


## A thin outline and a soft drop shadow, readable over sky and road alike.
static func _shadowed(label: Label) -> Label:
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The speed card sits immediately beside the pedals, on the side away from
## the screen edge, its bottom level with theirs.
func _place_gauge() -> void:
	var gap := 12.0
	if controls == null or not controls.has_method("control_rect"):
		_gauge.position = size - GAUGE_SIZE - Vector2(20, 20)
		return
	var pedals: Rect2 = controls.control_rect("brake")
	var gas: Rect2 = controls.control_rect("gas")
	if gas.has_area():
		pedals = pedals.merge(gas)
	var x := pedals.end.x + gap if Settings.left_handed else pedals.position.x - gap - GAUGE_SIZE.x
	_gauge.position = Vector2(x, pedals.end.y - GAUGE_SIZE.y)
