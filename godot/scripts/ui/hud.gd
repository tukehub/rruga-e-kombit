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
var _minimap: Control
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
	var destination := Vector2(size.x * 0.5 - 112 + clampi(index, 0, 2) * 80, size.y - 70)
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


func setup(p_race: Race, p_player: CarState, p_track: RaceTrack) -> void:
	race = p_race
	player = p_player
	track = p_track
	_me.text = player.name
	_me.add_theme_color_override("font_color", player.color.lightened(0.2))
	_build_minimap()


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
	_lap = UiTheme.label("XHIRO 1/2", 23, UiTheme.CYAN)
	v.add_child(_lap)
	_time = UiTheme.label("0:00.000", 23, UiTheme.TEXT)
	v.add_child(_time)
	var standings := UiTheme.panel(12)
	standings.position = Vector2(16, 102)
	standings.custom_minimum_size.x = 270
	standings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	standings.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.24), Color(1, 1, 1, 0.13), 12, 1))
	add_child(standings)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 3)
	standings.add_child(bv)
	bv.add_child(UiTheme.label("RENDITJA · ±m NGA TI", 18, UiTheme.CYAN))
	_board = VBoxContainer.new()
	_board.add_theme_constant_override("separation", 0)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(_board)
	_feed = VBoxContainer.new()
	_feed.position = Vector2(20, 344)
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
	_pause = UiTheme.button("II")
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
	# Compact digital speed and damage bar, rather than an opaque corner dial.
	_gauge = Control.new()
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_gauge.offset_left = -323
	_gauge.offset_right = -167
	_gauge.offset_top = 12
	_gauge.offset_bottom = 100
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)
	var speed_back := Panel.new()
	speed_back.size = Vector2(156, 78)
	speed_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_back.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.65), Color(1, 1, 1, 0.15), 12, 1))
	_gauge.add_child(speed_back)
	_speed = UiTheme.headline("0", 44, UiTheme.TEXT)
	_speed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed.offset_bottom = -28
	_gauge.add_child(_speed)
	_speed_unit = UiTheme.label("KM/H", 18, UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	_speed_unit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_speed_unit.offset_top = -34
	_speed_unit.offset_bottom = -10
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
	var inventory := HBoxContainer.new()
	inventory.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	inventory.offset_left = -126
	inventory.offset_right = 126
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
		button.add_theme_stylebox_override("normal", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.48), Color(1, 1, 1, 0.3), 12))
		var index := i
		button.pressed.connect(func(): slot_selected.emit(index))
		inventory.add_child(button)
		_slots.append(button)
	_fps = UiTheme.label("", 18, UiTheme.TEXT)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fps.offset_left = -350
	_fps.offset_right = -140
	_fps.offset_top = 112
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
	_mm_scale = minf((sz.x - 24.0) / ext.x, (sz.y - 24.0) / ext.y)
	_mm_min = mn
	_mm_rect = Rect2((sz - ext * _mm_scale) * 0.5, ext * _mm_scale)


func _mm(p: Vector3) -> Vector2:
	return _mm_rect.position + (Vector2(p.x, p.z) - _mm_min) * _mm_scale


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
	for c in race.cars:
		if c == player:
			continue
		var q := _mm(track.pos(c.s, c.d))
		_minimap.draw_circle(q, 4.0, Color(0, 0, 0, 0.7))
		_minimap.draw_circle(q, 3.0, c.color)
	var pp := _mm(track.pos(player.s, player.d))
	_minimap.draw_circle(pp, 6.5, Color(0, 0, 0, 0.8))
	_minimap.draw_circle(pp, 5.0, Color.WHITE)
	# High-contrast checkered flag stays visible even when cars cover the line.
	var flag := Vector2(clampf(p0.x + 7.0, 2.0, _minimap.size.x - 20.0), clampf(p0.y - 20.0, 2.0, _minimap.size.y - 18.0))
	_minimap.draw_line(p0, flag + Vector2(1, 15), Color(0.02, 0.02, 0.02, 0.9), 3.0, true)
	_minimap.draw_line(p0, flag + Vector2(1, 15), Color(1.0, 0.84, 0.18), 1.5, true)
	_minimap.draw_rect(Rect2(flag - Vector2(1, 1), Vector2(18, 14)), Color(0.02, 0.02, 0.02, 0.95))
	_minimap.draw_rect(Rect2(flag, Vector2(16, 12)), Color.WHITE)
	_minimap.draw_rect(Rect2(flag, Vector2(8, 6)), Color(0.04, 0.04, 0.04))
	_minimap.draw_rect(Rect2(flag + Vector2(8, 6), Vector2(8, 6)), Color(0.04, 0.04, 0.04))


func _draw_gauge() -> void:
	if player == null:
		return
	var hp := clampf(player.health / player.max_hp, 0.0, 1.0)
	var col := UiTheme.GREEN if hp > 0.5 else (UiTheme.AMBER if hp > 0.25 else UiTheme.RED)
	_gauge.draw_rect(Rect2(8, 82, 140, 6), Color(0.01, 0.02, 0.03, 0.65))
	_gauge.draw_rect(Rect2(8, 82, 140 * hp, 6), col)
	if player.shield_t > 0.0:
		_gauge.draw_line(Vector2(8, 78), Vector2(148, 78), UiTheme.CYAN, 3.0)


func feed(text: String, col := UiTheme.TEXT, ttl := 2.6) -> void:
	var l := UiTheme.label(text, 22, col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
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


func _process(dt: float) -> void:
	if race == null or player == null:
		return
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
	_lap.text = "MBËRRITE" if player.finished else "XHIRO %d/%d" % [lap, race.laps]
	_time.text = Game.fmt_time(player.finish_time if player.finished else race.time)
	_speed.text = str(roundi(absf(player.v) * 3.6))
	# standings
	var key := ""
	for c in race.order:
		key += str(c.id) + ("f" if c.finished else "") + ","
	if key != _board_key:
		_board_key = key
		_board_gaps.clear()
		for ch in _board.get_children():
			_board.remove_child(ch)
			ch.queue_free()
		var i := 0
		for c in race.order:
			i += 1
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var n := UiTheme.label(str(i), 23, UiTheme.TEXT, false)
			n.custom_minimum_size.x = 24
			row.add_child(n)
			var dot := ColorRect.new()
			dot.color = c.color
			dot.custom_minimum_size = Vector2(8, 8)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var nm := UiTheme.label(c.name + (" ✓" if c.finished else ""), 23, UiTheme.CYAN if c == player else UiTheme.TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			nm.add_theme_constant_override("outline_size", 3)
			row.add_child(nm)
			var gap := UiTheme.label("", 20, UiTheme.CYAN if c == player else UiTheme.TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT)
			gap.custom_minimum_size.x = 70
			gap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			gap.add_theme_constant_override("outline_size", 3)
			row.add_child(gap)
			_board_gaps.append(gap)
			_board.add_child(row)
	for i in mini(race.order.size(), _board_gaps.size()):
		var c: CarState = race.order[i]
		var metres := roundi(c.progress - player.progress)
		_board_gaps[i].text = "TI" if c == player else ("+%dm" % metres if metres > 0 else "%dm" % metres)
	# slots
	var sk := ""
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
				b.tooltip_text = str(pw.name)
				b.add_theme_color_override("font_color", Color.html(pw.col).lightened(0.25))
				b.visible = true
			else:
				b.text = ""
				b.icon = null
				b.tooltip_text = ""
				b.visible = false
		_slot_name.text = Data.PW[player.slots[0].type].name.to_upper() if not player.slots.is_empty() else ""
	_minimap.queue_redraw()
	_gauge.queue_redraw()
	if Settings.show_fps or diagnostic_fps:
		_fps.text = "%.1f ms  (max %.1f)  %d fps" % [Game.frame_ms_avg, Game.frame_ms_max, Engine.get_frames_per_second()]
	else:
		_fps.text = ""
