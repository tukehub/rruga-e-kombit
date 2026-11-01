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
var _pop: Label
var _pop_t := 0.0
var _pause: Button
var _mm_pts := PackedVector2Array()
var _mm_rect := Rect2()
var _mm_scale := 1.0
var _mm_min := Vector2.ZERO


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
	# ---- top-left: position, lap, time
	var tl := UiTheme.panel(14)
	tl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tl.position = Vector2(16, 14)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tl)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	tl.add_child(h)
	_pos = UiTheme.headline("6", 58, UiTheme.TEXT)
	_pos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_pos)
	_pos_n = UiTheme.label("/6", 22, UiTheme.MUTED, true)
	_pos_n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	h.add_child(_pos_n)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	_lap = UiTheme.label("XHIRO 1/2", 20, UiTheme.CYAN, true)
	v.add_child(_lap)
	_time = UiTheme.label("0:00.000", 22, UiTheme.TEXT)
	v.add_child(_time)
	# ---- standings under it
	_board = VBoxContainer.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_board.position = Vector2(20, 96)
	_board.add_theme_constant_override("separation", 1)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	# ---- feed (left, lower-middle)
	_feed = VBoxContainer.new()
	_feed.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_feed.position = Vector2(20, 0)
	_feed.offset_top = 30
	_feed.add_theme_constant_override("separation", 2)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	# ---- centre message
	var cv := VBoxContainer.new()
	cv.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cv.offset_top = 150
	cv.offset_left = -500
	cv.offset_right = 500
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cv)
	_center = UiTheme.headline("", 150, UiTheme.AMBER)
	_center.modulate.a = 0.0
	cv.add_child(_center)
	_center_sub = UiTheme.label("", 22, UiTheme.AMBER, false, HORIZONTAL_ALIGNMENT_CENTER)
	_center_sub.modulate.a = 0.0
	cv.add_child(_center_sub)
	_pop = UiTheme.headline("", 44, UiTheme.AMBER)
	_pop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pop.offset_left = -200
	_pop.offset_right = 200
	_pop.offset_top = -120
	_pop.modulate.a = 0.0
	add_child(_pop)
	# ---- flash overlay
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	# ---- top-right: pause + minimap
	_pause = UiTheme.button("II")
	_pause.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pause.offset_left = -72
	_pause.offset_right = -16
	_pause.offset_top = 14
	_pause.offset_bottom = 58
	_pause.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause)
	_minimap = Control.new()
	_minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -216
	_minimap.offset_right = -16
	_minimap.offset_top = 70
	_minimap.offset_bottom = 270
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)
	# ---- bottom-right: gauge
	_gauge = Control.new()
	_gauge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_gauge.offset_left = -190
	_gauge.offset_right = -20
	_gauge.offset_top = -190
	_gauge.offset_bottom = -20
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	add_child(_gauge)
	_speed = UiTheme.headline("0", 54, UiTheme.TEXT)
	_speed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed.offset_top = 30
	_speed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gauge.add_child(_speed)
	_speed_unit = UiTheme.label("KM/H", 14, UiTheme.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
	_speed_unit.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_unit.offset_top = -48
	_speed_unit.offset_left = -40
	_speed_unit.offset_right = 40
	_gauge.add_child(_speed_unit)
	_me = UiTheme.label("", 16, UiTheme.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_me.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_me.offset_left = -200
	_me.offset_right = -24
	_me.offset_top = -214
	_me.offset_bottom = -190
	add_child(_me)
	# ---- bottom-centre: slots (above the fire button which sits at y -150..-58)
	_slot_name = UiTheme.label("", 18, UiTheme.CYAN, true, HORIZONTAL_ALIGNMENT_CENTER)
	_slot_name.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_slot_name.offset_left = -160
	_slot_name.offset_right = 160
	_slot_name.offset_top = -236
	_slot_name.offset_bottom = -210
	add_child(_slot_name)
	var sh := HBoxContainer.new()
	sh.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	sh.offset_left = -118
	sh.offset_right = 118
	sh.offset_top = -210
	sh.offset_bottom = -158
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 10)
	add_child(sh)
	for i in SLOT_N:
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiTheme.display())
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_stylebox_override("normal", UiTheme.flat(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.2), 10))
		b.add_theme_stylebox_override("hover", UiTheme.flat(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.3), 10))
		b.add_theme_stylebox_override("pressed", UiTheme.flat(Color(1, 1, 1, 0.25), Color.WHITE, 10))
		var idx := i
		b.pressed.connect(func(): slot_selected.emit(idx))
		sh.add_child(b)
		_slots.append(b)
	# ---- fps
	_fps = UiTheme.label("", 14, UiTheme.MUTED)
	_fps.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_fps.offset_left = -120
	_fps.offset_right = 120
	_fps.offset_top = 8
	_fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_fps)


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
	# start line
	var p0 := _mm(track.pos(0.0, 0.0))
	_minimap.draw_circle(p0, 4.0, Color.WHITE)
	for c in race.cars:
		if c == player:
			continue
		var q := _mm(track.pos(c.s, c.d))
		_minimap.draw_circle(q, 4.0, Color(0, 0, 0, 0.7))
		_minimap.draw_circle(q, 3.0, c.color)
	var pp := _mm(track.pos(player.s, player.d))
	_minimap.draw_circle(pp, 6.5, Color(0, 0, 0, 0.8))
	_minimap.draw_circle(pp, 5.0, Color.WHITE)


func _draw_gauge() -> void:
	if player == null:
		return
	var c := _gauge.size * 0.5
	var r := minf(c.x, c.y) - 8.0
	_gauge.draw_circle(c, r + 6.0, Color(0, 0, 0, 0.45))
	_gauge.draw_arc(c, r, ARC_START, ARC_START + ARC_SWEEP, 48, Color(1, 1, 1, 0.12), 8.0, true)
	var vf := clampf(absf(player.v) / (float(player.def.vmax) * 1.05), 0.0, 1.0)
	if vf > 0.005:
		var col := UiTheme.CYAN.lerp(UiTheme.PINK, vf)
		if player.nitro_t > 0.0:
			col = UiTheme.GREEN
		_gauge.draw_arc(c, r, ARC_START, ARC_START + ARC_SWEEP * vf, 48, col, 8.0, true)
	var hp := clampf(player.health / player.max_hp, 0.0, 1.0)
	var hcol := UiTheme.GREEN if hp > 0.5 else (UiTheme.AMBER if hp > 0.25 else UiTheme.RED)
	_gauge.draw_arc(c, r - 14.0, ARC_START, ARC_START + ARC_SWEEP, 48, Color(1, 1, 1, 0.1), 5.0, true)
	if hp > 0.005:
		_gauge.draw_arc(c, r - 14.0, ARC_START, ARC_START + ARC_SWEEP * hp, 48, hcol, 5.0, true)
	if player.shield_t > 0.0:
		_gauge.draw_arc(c, r + 3.0, 0.0, TAU, 64, Color(UiTheme.CYAN, 0.5 + 0.3 * sin(Time.get_ticks_msec() * 0.01)), 2.0, true)


func feed(text: String, col := UiTheme.TEXT, ttl := 2.6) -> void:
	var l := UiTheme.label(text, 18, col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.set_meta("ttl", ttl)
	_feed.add_child(l)
	while _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
		_feed.remove_child(_feed.get_child(0))


func center(text: String, sub := "", dur := 1.6) -> void:
	_center.text = text
	_center_sub.text = sub
	_center.modulate.a = 1.0
	_center_sub.modulate.a = 1.0 if sub != "" else 0.0
	_center_t = dur
	_center.scale = Vector2.ONE


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
		for ch in _board.get_children():
			_board.remove_child(ch)
			ch.queue_free()
		var i := 0
		for c in race.order:
			i += 1
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			var n := UiTheme.label(str(i), 15, UiTheme.MUTED if c != player else UiTheme.TEXT, true)
			n.custom_minimum_size.x = 16
			row.add_child(n)
			var dot := ColorRect.new()
			dot.color = c.color
			dot.custom_minimum_size = Vector2(8, 8)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(dot)
			var nm := UiTheme.label(c.name + (" ✓" if c.finished else ""), 15, UiTheme.TEXT if c == player else UiTheme.MUTED)
			nm.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
			nm.add_theme_constant_override("outline_size", 3)
			row.add_child(nm)
			_board.add_child(row)
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
				b.text = pw.name.to_upper().left(6) + ("" if s.type != "bolt" else " ×%d" % s.ammo)
				b.add_theme_color_override("font_color", Color.html(pw.col).lightened(0.25))
				b.visible = true
			else:
				b.text = ""
				b.visible = i == 0
		_slot_name.text = Data.PW[player.slots[0].type].name.to_upper() if not player.slots.is_empty() else ""
	_minimap.queue_redraw()
	_gauge.queue_redraw()
	if Settings.show_fps:
		_fps.text = "%.1f ms  (max %.1f)  %d fps" % [Game.frame_ms_avg, Game.frame_ms_max, Engine.get_frames_per_second()]
	else:
		_fps.text = ""
