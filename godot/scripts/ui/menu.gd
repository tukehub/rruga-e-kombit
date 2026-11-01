class_name Menu
extends Node3D
## Title / city / driver+car / settings / help / credits. Code-built UI over a
## small 3D garage showing the selected car.

var ui: Control
var pages := {}
var page := "title"
var back_to := "title"
var garage_car: CarVisual
var garage_pivot: Node3D
var _garage_t := 0.0
var _city_btns := {}
var _car_btns := {}
var _drv_btns := {}
var _diff_btns: Array[Button] = []
var _drv_tag: Label
var _car_desc: Label
var _city_info: Label
var _set_rows := {}


func _ready() -> void:
	Quality.apply_viewport(get_viewport())
	_build_garage()
	_build_ui()
	show_page("title")


# ------------------------------------------------------------------ garage
func _build_garage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = UiTheme.BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.3, 0.45)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.1
	e.glow_hdr_threshold = 1.1
	e.ssao_enabled = Quality.preset != "low"
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 35, 0)
	key.light_energy = 2.2
	key.light_color = Color(1.0, 0.95, 0.9)
	key.shadow_enabled = true
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-4, 2.5, -5)
	rim.light_color = UiTheme.CYAN
	rim.light_energy = 6.0
	rim.omni_range = 14.0
	add_child(rim)
	var fill := OmniLight3D.new()
	fill.position = Vector3(5, 1.5, 4)
	fill.light_color = UiTheme.PINK
	fill.light_energy = 4.0
	fill.omni_range = 14.0
	add_child(fill)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.06, 0.055, 0.08)
	fm.roughness = 0.25
	fm.metallic = 0.3
	ground.material_override = fm
	add_child(ground)
	garage_pivot = Node3D.new()
	add_child(garage_pivot)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(5.2, 1.9, 6.0)
	cam.look_at(Vector3(0.6, 0.6, 0))
	cam.fov = 38
	cam.current = true
	_set_garage_car(str(Game.race_opts.car))


func _set_garage_car(id: String) -> void:
	if garage_car:
		garage_car.queue_free()
	var def: Dictionary = Data.car(id)
	garage_car = CarVisual.new()
	garage_pivot.add_child(garage_car)
	garage_car.setup(def, Color.html(def.color), false)
	garage_car.set_night(1.0)


func _process(dt: float) -> void:
	_garage_t += dt
	garage_pivot.rotation.y = _garage_t * 0.25
	if garage_car:
		for nm in garage_car.wheels:
			var w: MeshInstance3D = garage_car.wheels[nm]
			w.rotation = Vector3(0.0, PI if String(nm).ends_with("l") else 0.0, 0.0)


# ------------------------------------------------------------------ ui
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.theme()
	layer.add_child(ui)
	pages.title = _page_title()
	pages.city = _page_city()
	pages.car = _page_car()
	pages.settings = _page_settings()
	pages.help = _page_help()
	pages.credits = _page_credits()
	for k in pages:
		ui.add_child(pages[k])


func show_page(name: String) -> void:
	page = name
	for k in pages:
		pages[k].visible = (k == name)
	if name == "settings":
		_refresh_settings()
	if name == "city":
		_refresh_city()
	if name == "car":
		_refresh_car()


func _page(shade_a: float) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	c.add_child(UiTheme.shade(shade_a))
	return c


func _margin(parent: Control, m := 36) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", m)
	mc.add_theme_constant_override("margin_right", m)
	mc.add_theme_constant_override("margin_top", m - 10)
	mc.add_theme_constant_override("margin_bottom", m - 10)
	parent.add_child(mc)
	return mc


func _eyebrow(text: String) -> Label:
	var l := UiTheme.label(text.to_upper(), 15, UiTheme.CYAN)
	l.add_theme_constant_override("line_spacing", 0)
	return l


func _bottombar(back_cb: Callable, next_text: String, next_cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var b := UiTheme.button("Kthehu", Color(0, 0, 0, 0), 160)
	b.pressed.connect(func(): Sfx.ui_back(); back_cb.call())
	h.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	if next_text != "":
		var n := UiTheme.button(next_text, UiTheme.PINK.darkened(0.25), 200)
		n.pressed.connect(func(): Sfx.ui_click(); next_cb.call())
		h.add_child(n)
	return h


func _seg(options: Array, on_pick: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in options.size():
		var b := UiTheme.button(str(options[i]))
		b.toggle_mode = true
		b.pressed.connect(func(): Sfx.ui_click(); on_pick.call(i))
		h.add_child(b)
	return h


func _seg_set(h: HBoxContainer, idx: int) -> void:
	for i in h.get_child_count():
		var b := h.get_child(i) as Button
		b.button_pressed = (i == idx)
		if i == idx:
			b.add_theme_stylebox_override("normal", UiTheme.flat(Color(UiTheme.CYAN, 0.3), UiTheme.CYAN, 12))
		else:
			b.remove_theme_stylebox_override("normal")


# ------------------------------------------------------------------ title
func _page_title() -> Control:
	var c := _page(0.35)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 70
	v.offset_top = -230
	v.offset_bottom = 230
	v.offset_right = 760
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	c.add_child(v)
	v.add_child(_eyebrow("Garë me fuqi"))
	var h := UiTheme.headline(Data.GAME_NAME.to_upper(), 112, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	h.add_theme_color_override("font_color", UiTheme.TEXT)
	v.add_child(h)
	var tag := UiTheme.label("Pa frena, pa patentë, pa mëshirë. Gjashtë qytete, pesë shoferë dhe asfalt që kafshon.", 20, UiTheme.MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size.x = 620
	v.add_child(tag)
	v.add_child(UiTheme.spacer(18))
	var play := UiTheme.button("Luaj", UiTheme.PINK.darkened(0.2), 300)
	play.add_theme_font_size_override("font_size", 34)
	play.custom_minimum_size.y = 72
	play.pressed.connect(func(): Sfx.ui_click(); show_page("city"))
	v.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for pair in [["Si luhet", "help"], ["Cilësimet", "settings"], ["Kredite", "credits"]]:
		var b := UiTheme.button(pair[0], Color(0, 0, 0, 0), 150)
		var target: String = pair[1]
		b.pressed.connect(func(): Sfx.ui_click(); back_to = "title"; show_page(target))
		row.add_child(b)
	var st: Dictionary = Settings.stats
	var foot := UiTheme.label("Gara: %d · Fitore: %d · Podiume: %d" % [int(st.races), int(st.wins), int(st.podiums)], 15, UiTheme.MUTED)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 70
	foot.offset_top = -40
	foot.offset_bottom = -16
	foot.offset_right = 600
	c.add_child(foot)
	var ver := UiTheme.label("v" + str(ProjectSettings.get_setting("application/config/version", "dev")), 14, UiTheme.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -300
	ver.offset_right = -24
	ver.offset_top = -40
	ver.offset_bottom = -16
	c.add_child(ver)
	return c


# ------------------------------------------------------------------ city
func _page_city() -> Control:
	var c := _page(0.7)
	var mc := _margin(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mc.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 30)
	v.add_child(top)
	var tl := VBoxContainer.new()
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_child(_eyebrow("Hapi 1 nga 2"))
	tl.add_child(UiTheme.headline("Ku luajmë?", 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	top.add_child(tl)
	var td := VBoxContainer.new()
	td.add_child(_eyebrow("Vështirësia"))
	var names := []
	for d in Data.DIFFS:
		names.append(d.name)
	var seg := _seg(names, func(i: int): Game.race_opts.diff = i; _refresh_city())
	td.add_child(seg)
	top.add_child(td)
	_diff_btns.clear()
	for b in seg.get_children():
		_diff_btns.append(b)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for city in Data.CITIES:
		var has_data := FileAccess.file_exists("res://assets/cities/%s/track.json" % city.id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.disabled = not has_data
		var neon := Color.html(city.neon)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 16
		inner.offset_top = 10
		inner.offset_right = -16
		inner.offset_bottom = -10
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_theme_constant_override("separation", 2)
		inner.add_child(UiTheme.label(str(city.region).to_upper(), 13, neon))
		inner.add_child(UiTheme.headline(city.name, 38, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
		var sub := UiTheme.label(("%s · %d xhiro" % [Data.ENV[city.env].label, int(city.laps)]) if has_data else "Së shpejti", 15, UiTheme.MUTED if has_data else UiTheme.AMBER)
		inner.add_child(sub)
		b.add_child(inner)
		b.pressed.connect(func():
			Sfx.ui_click()
			Game.race_opts.city = city.id
			_refresh_city())
		grid.add_child(b)
		_city_btns[city.id] = {"btn": b, "neon": neon}
	_city_info = UiTheme.label("", 17, UiTheme.MUTED)
	_city_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_city_info)
	v.add_child(_bottombar(func(): show_page("title"), "Vazhdo", func(): show_page("car")))
	return c


func _refresh_city() -> void:
	for id in _city_btns:
		var e: Dictionary = _city_btns[id]
		var b: Button = e.btn
		var sel: bool = (id == Game.race_opts.city)
		b.button_pressed = sel
		var neon: Color = e.neon
		b.add_theme_stylebox_override("normal", UiTheme.flat(Color(neon, 0.22 if sel else 0.05), neon if sel else Color(1, 1, 1, 0.14), 16, 2))
		b.add_theme_stylebox_override("hover", UiTheme.flat(Color(neon, 0.3 if sel else 0.12), neon, 16, 2))
		b.add_theme_stylebox_override("pressed", UiTheme.flat(Color(neon, 0.3), neon, 16, 2))
	var city: Dictionary = Data.city(Game.race_opts.city)
	_city_info.text = "%s  —  %s" % [city.blurb, ", ".join(city.landmarks)]
	for i in _diff_btns.size():
		var b := _diff_btns[i]
		var sel: bool = (i == int(Game.race_opts.diff))
		b.button_pressed = sel
		if sel:
			b.add_theme_stylebox_override("normal", UiTheme.flat(Color(UiTheme.CYAN, 0.3), UiTheme.CYAN, 12))
		else:
			b.remove_theme_stylebox_override("normal")


# ------------------------------------------------------------------ car
func _page_car() -> Control:
	var c := _page(0.25)
	var mc := _margin(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	mc.add_child(v)
	v.add_child(_eyebrow("Hapi 2 nga 2"))
	v.add_child(UiTheme.headline("Shoferi dhe makina", 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 30)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 560
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	left.add_child(_eyebrow("Kush je ti"))
	var drow := HFlowContainer.new()
	drow.add_theme_constant_override("h_separation", 8)
	drow.add_theme_constant_override("v_separation", 8)
	left.add_child(drow)
	for i in Data.DRIVERS.size():
		var d: Dictionary = Data.DRIVERS[i]
		var b := UiTheme.button(d.name)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func(): Sfx.ui_click(); Game.race_opts.driver = idx; _refresh_car())
		drow.add_child(b)
		_drv_btns[i] = b
	_drv_tag = UiTheme.label("", 16, UiTheme.MUTED)
	left.add_child(_drv_tag)
	left.add_child(UiTheme.spacer(6))
	left.add_child(_eyebrow("Makina"))
	var clist := VBoxContainer.new()
	clist.add_theme_constant_override("separation", 6)
	left.add_child(clist)
	for car in Data.CARS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.custom_minimum_size.y = 52
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -14
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 12)
		var sw := ColorRect.new()
		sw.color = Color.html(car.color)
		sw.custom_minimum_size = Vector2(16, 16)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(sw)
		var nm := UiTheme.label(car.name, 22, UiTheme.TEXT, true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(nm)
		var stats := UiTheme.label("%d km/h · %s" % [int(float(car.vmax) * 3.6), _car_trait(car)], 14, UiTheme.MUTED)
		stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(stats)
		b.add_child(h)
		b.pressed.connect(func():
			Sfx.ui_click()
			Game.race_opts.car = car.id
			_set_garage_car(car.id)
			_refresh_car())
		clist.add_child(b)
		_car_btns[car.id] = b
	_car_desc = UiTheme.label("", 16, UiTheme.MUTED)
	_car_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_car_desc)
	v.add_child(_bottombar(func(): show_page("city"), "Nisu!", func(): Game.start_race()))
	return c


func _car_trait(car: Dictionary) -> String:
	if float(car.grip) >= 1.1:
		return "kap si ngjitës"
	if float(car.hp) >= 140.0:
		return "tank"
	if float(car.vmax) >= 61.0:
		return "raketë"
	if float(car.acc) >= 18.0:
		return "niset si plumb"
	return "e balancuar"


func _refresh_car() -> void:
	for i in _drv_btns:
		var b: Button = _drv_btns[i]
		var d: Dictionary = Data.DRIVERS[i]
		var sel: bool = (i == int(Game.race_opts.driver))
		b.button_pressed = sel
		var col := Color.html(d.col)
		if sel:
			b.add_theme_stylebox_override("normal", UiTheme.flat(Color(col, 0.35), col, 12))
		else:
			b.add_theme_stylebox_override("normal", UiTheme.flat(Color(col, 0.08), Color(col, 0.4), 12))
	var drv: Dictionary = Data.DRIVERS[clampi(int(Game.race_opts.driver), 0, Data.DRIVERS.size() - 1)]
	_drv_tag.text = "„%s“" % drv.tag
	for id in _car_btns:
		var b: Button = _car_btns[id]
		var sel: bool = (id == Game.race_opts.car)
		b.button_pressed = sel
		b.add_theme_stylebox_override("normal", UiTheme.flat(Color(UiTheme.CYAN, 0.22) if sel else Color(1, 1, 1, 0.05), UiTheme.CYAN if sel else Color(1, 1, 1, 0.12), 12))
	_car_desc.text = str(Data.car(Game.race_opts.car).desc)


# ------------------------------------------------------------------ settings
func _page_settings() -> Control:
	var c := _page(0.75)
	var mc := _margin(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mc.add_child(v)
	v.add_child(UiTheme.headline("Cilësimet", 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	_set_row(list, "steer", "Timoni", ["Anim", "Prekje"], func(i): Settings.touch_steer = (i == 1))
	_set_row(list, "sens", "Ndjeshmëria e animit", Settings.TILT_LABELS, func(i): Settings.tilt_sens = i)
	_set_row(list, "invert", "Anim i kundërt", ["Jo", "Po"], func(i): Settings.tilt_invert = (i == 1))
	_set_row(list, "assist", "Ndihmë në timon", ["Jo", "Po"], func(i): Settings.assist = (i == 1))
	_set_row(list, "weather", "Mot dhe dritë dinamike", ["Jo", "Po"], func(i): Settings.dynamic_weather = (i == 1))
	_set_row(list, "haptics", "Dridhje", ["Jo", "Po"], func(i): Settings.haptics = (i == 1))
	_set_row(list, "quality", "Cilësia grafike", ["Auto", "E ulët", "Mesatare", "E lartë"], func(i):
		Settings.quality = ["auto", "low", "medium", "high"][i]
		Quality.set_preset(Settings.quality)
		Quality.apply_viewport(get_viewport()))
	_set_row(list, "fps", "Trego FPS", ["Jo", "Po"], func(i): Settings.show_fps = (i == 1))
	_set_slider(list, "master", "Volumi", func(x): Settings.vol_master = x)
	_set_slider(list, "engine", "Motori", func(x): Settings.vol_engine = x)
	_set_slider(list, "tyres", "Gomat", func(x): Settings.vol_tyres = x)
	_set_slider(list, "impacts", "Përplasjet", func(x): Settings.vol_impacts = x)
	_set_slider(list, "pickups", "Fuqitë", func(x): Settings.vol_pickups = x)
	var done := UiTheme.button("Gati", UiTheme.PINK.darkened(0.25), 200)
	done.pressed.connect(func():
		Sfx.ui_click()
		Settings.save()
		Sfx.apply_volumes()
		show_page(back_to))
	var h := HBoxContainer.new()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	h.add_child(done)
	v.add_child(h)
	return c


func _set_row(list: VBoxContainer, key: String, title: String, options: Array, on_pick: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(title, 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var seg := _seg(options, func(i: int):
		on_pick.call(i)
		_refresh_settings())
	h.add_child(seg)
	list.add_child(h)
	_set_rows[key] = seg


func _set_slider(list: VBoxContainer, key: String, title: String, on_change: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UiTheme.label(title, 20)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(320, 36)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(x: float): on_change.call(x); Sfx.apply_volumes())
	s.drag_ended.connect(func(_c): Sfx.ui_click())
	h.add_child(s)
	list.add_child(h)
	_set_rows[key] = s


func _refresh_settings() -> void:
	_seg_set(_set_rows.weather, 1 if Settings.dynamic_weather else 0)
	_seg_set(_set_rows.steer, 1 if Settings.touch_steer else 0)
	_seg_set(_set_rows.sens, int(Settings.tilt_sens))
	_seg_set(_set_rows.invert, 1 if Settings.tilt_invert else 0)
	_seg_set(_set_rows.assist, 1 if Settings.assist else 0)
	_seg_set(_set_rows.haptics, 1 if Settings.haptics else 0)
	_seg_set(_set_rows.quality, maxi(0, ["auto", "low", "medium", "high"].find(Settings.quality)))
	_seg_set(_set_rows.fps, 1 if Settings.show_fps else 0)
	(_set_rows.master as HSlider).set_value_no_signal(Settings.vol_master)
	(_set_rows.engine as HSlider).set_value_no_signal(Settings.vol_engine)
	(_set_rows.tyres as HSlider).set_value_no_signal(Settings.vol_tyres)
	(_set_rows.impacts as HSlider).set_value_no_signal(Settings.vol_impacts)
	(_set_rows.pickups as HSlider).set_value_no_signal(Settings.vol_pickups)
	var qb: Button = _set_rows.quality.get_child(0)
	qb.text = "Auto (%s)" % {"low": "e ulët", "medium": "mesatare", "high": "e lartë"}.get(Quality.detected, Quality.detected)


# ------------------------------------------------------------------ help
func _page_help() -> Control:
	var c := _page(0.8)
	var mc := _margin(c, 60)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mc.add_child(v)
	v.add_child(UiTheme.headline("Si luhet", 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 10)
	sc.add_child(inner)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", UiTheme.body())
	rt.add_theme_font_override("bold_font", UiTheme.body_bold())
	rt.add_theme_font_size_override("normal_font_size", 19)
	rt.add_theme_font_size_override("bold_font_size", 19)
	var cy := "#" + UiTheme.CYAN.to_html(false)
	rt.text = ("[b]Garë:[/b] mblidh fuqitë që shkëlqejnë në rrugë (deri në tre), godit kundërshtarët dhe mbërri i pari. " +
		"Kur makina bëhet copë, rikthehesh pas dy sekondash.\n\n" +
		"[b]Me telefon:[/b] anoje telefonin majtas-djathtas për të kthyer · mbaj gishtin në gjysmën e [color=%s]djathtë[/color] për gaz " % cy +
		"dhe në të [color=%s]majtën[/color] për frena (frena + kthesë = drift) · [color=%s]GJUAJ[/color] në mes përdor fuqinë · " % [cy, cy] +
		"[color=%s]PRAPA[/color] e gjuan pas · prek fuqitë e vogla për t’i ndërruar. Në Cilësimet mund të zgjedhësh timonin me prekje.\n\n" % cy +
		"[b]Me tastierë:[/b] ←/→ ose A/D timoni · ↑/W gazi · ↓/S frena dhe drift · Hapësirë gjuaj · Shift ose X gjuaj prapa · Q/E ndërro fuqinë · Esc pauzë.")
	inner.add_child(rt)
	inner.add_child(_eyebrow("Fuqitë"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 6)
	inner.add_child(grid)
	for k in Data.PW_KEYS:
		var pw: Dictionary = Data.PW[k]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var dot := ColorRect.new()
		dot.color = Color.html(pw.col)
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var l := UiTheme.label("%s — %s" % [pw.name, pw.desc], 16, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 520
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		grid.add_child(h)
	var done := UiTheme.button("Kuptova", UiTheme.PINK.darkened(0.25), 200)
	done.pressed.connect(func(): Sfx.ui_click(); show_page(back_to))
	var hb := HBoxContainer.new()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(done)
	v.add_child(hb)
	return c


# ------------------------------------------------------------------ credits
func _page_credits() -> Control:
	var c := _page(0.8)
	var mc := _margin(c, 60)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mc.add_child(v)
	v.add_child(UiTheme.headline("Kredite dhe licenca", 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_override("normal_font", UiTheme.body())
	rt.add_theme_font_override("bold_font", UiTheme.body_bold())
	rt.add_theme_font_size_override("normal_font_size", 17)
	rt.add_theme_font_size_override("bold_font_size", 17)
	rt.text = FileAccess.get_file_as_string("res://assets/CREDITS.txt") if FileAccess.file_exists("res://assets/CREDITS.txt") else "—"
	rt.text += "\n\n[b]Licenca e motorit Godot (MIT)[/b]\n" + Engine.get_license_text()
	for license_path in ["res://assets/fonts/OFL-BigShouldersDisplay.txt", "res://assets/fonts/OFL-ChakraPetch.txt"]:
		rt.text += "\n\n" + FileAccess.get_file_as_string(license_path)
	sc.add_child(rt)
	var done := UiTheme.button("Kthehu", Color(0, 0, 0, 0), 200)
	done.pressed.connect(func(): Sfx.ui_back(); show_page(back_to))
	var hb := HBoxContainer.new()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(done)
	v.add_child(hb)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if page == "title":
			return
		Sfx.ui_back()
		match page:
			"city": show_page("title")
			"car": show_page("city")
			_: show_page(back_to)
		get_viewport().set_input_as_handled()
