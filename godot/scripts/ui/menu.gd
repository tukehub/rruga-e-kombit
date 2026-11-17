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
var _drv_btns := {}
var _diff_btns: Array[Button] = []
var _lap_value: Label
var _lap_minus: Button
var _direction: Button
var _weather: Button
var _mode: Button
var _cup_button: Button
var _cup_stars: Label
var cup_cards: Array[Button] = []
## The choices the mode button steps through: a race, or points for 2 or 3 minutes.
const MODES := [{"mode": "race", "minutes": 0}, {"mode": "points", "minutes": 2}, {"mode": "points", "minutes": 3}]
var _lap_plus: Button
var _drv_tag: Label
var _drv_name: LineEdit
var _fans_label: Label
var _buy_btn: Button
var _garage_tabs: HBoxContainer
var _garage_lists := {}          # tab -> its list
var _shop_btns := {}             # "kind:id" -> button
var _garage_tab := "paint"
## A shop item tried on but not bought: {"kind", "id"}, or empty.
var _preview := {}
const GARAGE_TABS := ["paint", "rim", "livery", "driver"]
var _car_desc: Label
var _set_rows := {}


func _ready() -> void:
	Quality.apply_viewport(get_viewport())
	_build_garage()
	_build_ui()
	# Back from a cup race, the cup is where the player was.
	show_page("cup" if not str(Game.race_opts.event).is_empty() else "title")


# ------------------------------------------------------------------ garage
func _build_garage() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("273445")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.85, 1.0)
	e.ambient_light_energy = 0.95
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.5
	e.glow_bloom = 0.1
	e.glow_hdr_threshold = 1.1
	e.ssao_enabled = bool(Quality.p.ssao)
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 35, 0)
	key.light_energy = 2.7
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
	fm.albedo_color = Color(0.22, 0.27, 0.33)
	fm.roughness = 0.25
	fm.metallic = 0.3
	ground.material_override = fm
	add_child(ground)
	garage_pivot = Node3D.new()
	garage_pivot.position.x = 4.0
	add_child(garage_pivot)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(8.0, 3.3, 11.0)
	cam.look_at(Vector3(0.0, 0.65, 0.0))
	cam.fov = 38
	cam.current = true
	_set_garage_car(str(Game.race_opts.car))


func _set_garage_car(id: String) -> void:
	if garage_car:
		garage_car.queue_free()
	var def: Dictionary = Data.car(id)
	garage_car = CarVisual.new()
	garage_pivot.add_child(garage_car)
	garage_car.setup(def, Color.html(def.color), false, {"rim": garage_choice("rim"), "livery": garage_choice("livery")})
	garage_car.set_night(0.0)


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
	ui = UiTheme.safe_area(layer)
	ui.theme = UiTheme.theme()
	pages.title = _page_title()
	pages.car = _page_car()
	pages.cup = _page_cup()
	pages.settings = _page_settings()
	pages.help = _page_help()
	pages.credits = _page_credits()
	for k in pages:
		ui.add_child(pages[k])


func show_page(name: String) -> void:
	if name == "city":
		name = "title"
	Game.race_opts.city = "tirane"
	var changed := page != name
	page = name
	for k in pages:
		pages[k].visible = (k == name)
	# The page shown is right at once; only its arrival is animated. Going
	# back to the title comes in from the left, everything else from the right.
	if changed and pages.has(name):
		UiTheme.slide_in(pages[name], Vector2(-56.0 if name == "title" else 56.0, 0.0))
	if name == "settings":
		_refresh_settings()
	if name in ["cup", "title"]:
		_refresh_cup()
	if name == "title":
		_refresh_city()
	if name == "car":
		_refresh_car()
	elif not _preview.is_empty():
		# Leaving the garage puts back what the player owns.
		_preview = {}
		_set_garage_car(str(Game.race_opts.car))


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
	var l := UiTheme.label(text.to_upper(), 22, UiTheme.CYAN)
	l.add_theme_constant_override("line_spacing", 0)
	return l


func _bottombar(back_cb: Callable, next_text: String, next_cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var b := UiTheme.button(Data.t("common.back"), Color(0, 0, 0, 0), 160)
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
	var c := _page(0.15)
	var panel := UiTheme.panel(24)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 28
	panel.offset_right = 592
	panel.offset_top = 24
	panel.offset_bottom = -24
	panel.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.025, 0.055, 0.09, 0.9), Color(1, 1, 1, 0.16), 24))
	c.add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	v.add_child(_eyebrow(Data.t("menu.eyebrow")))
	v.add_child(UiTheme.headline(Data.GAME_NAME.to_upper(), 96, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var tag := UiTheme.label(Data.t("menu.tagline"), 26, UiTheme.TEXT)
	v.add_child(tag)
	v.add_child(UiTheme.spacer(4))
	var lap_row := HBoxContainer.new()
	lap_row.add_theme_constant_override("separation", 8)
	var lap_title := UiTheme.label(Data.t("menu.laps"), 25, UiTheme.CYAN)
	lap_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lap_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lap_row.add_child(lap_title)
	_lap_minus = UiTheme.button("−")
	_lap_minus.custom_minimum_size = Vector2(52, 48)
	_lap_minus.pressed.connect(func(): _change_laps(-1))
	lap_row.add_child(_lap_minus)
	_lap_value = UiTheme.headline("", 30, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_lap_value.custom_minimum_size = Vector2(42, 48)
	_lap_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lap_row.add_child(_lap_value)
	_lap_plus = UiTheme.button("+")
	_lap_plus.custom_minimum_size = Vector2(52, 48)
	_lap_plus.pressed.connect(func(): _change_laps(1))
	lap_row.add_child(_lap_plus)
	v.add_child(lap_row)
	_direction = UiTheme.button("")
	_direction.name = "RaceDirection"
	_direction.custom_minimum_size.y = 48
	_direction.pressed.connect(func():
		Sfx.ui_click()
		Game.race_opts.reverse = not bool(Game.race_opts.reverse)
		_refresh_city())
	# Direction and weather share one row so the page keeps its height.
	var options_row := HBoxContainer.new()
	options_row.add_theme_constant_override("separation", 10)
	_direction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_direction.add_theme_font_size_override("font_size", 22)
	options_row.add_child(_direction)
	_weather = UiTheme.button("")
	_weather.name = "RaceWeather"
	_weather.custom_minimum_size.y = 48
	_weather.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weather.add_theme_font_size_override("font_size", 22)
	_weather.pressed.connect(func():
		Sfx.ui_click()
		Game.race_opts.env = "day" if str(Game.race_opts.env) == "rainy" else "rainy"
		_refresh_city())
	options_row.add_child(_weather)
	v.add_child(options_row)
	_mode = UiTheme.button("")
	_mode.name = "GameMode"
	_mode.custom_minimum_size.y = 48
	_mode.add_theme_font_size_override("font_size", 22)
	_mode.pressed.connect(func():
		Sfx.ui_click()
		var next: Dictionary = MODES[(mode_index() + 1) % MODES.size()]
		Game.race_opts.mode = next.mode
		if int(next.minutes) > 0:
			Game.race_opts.points_minutes = next.minutes
		_refresh_city())
	v.add_child(_mode)
	var names := [Data.t("diff.0"), Data.t("diff.1"), Data.t("diff.2")]
	var difficulty := _seg(names, func(i: int): Game.race_opts.diff = i; _refresh_city())
	_diff_btns.clear()
	for b in difficulty.get_children():
		b.custom_minimum_size = Vector2(150, 50)
		_diff_btns.append(b)
	v.add_child(difficulty)
	# The cup and a free race share the main row.
	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 10)
	_cup_button = UiTheme.button(Data.t("menu.cup"), UiTheme.AMBER.darkened(0.5))
	_cup_button.name = "CupButton"
	_cup_button.custom_minimum_size.y = 70
	_cup_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cup_button.add_theme_font_size_override("font_size", 28)
	_cup_button.pressed.connect(func(): Sfx.ui_click(); show_page("cup"))
	play_row.add_child(_cup_button)
	var play := UiTheme.button(Data.t("menu.start"), UiTheme.CYAN.darkened(0.45))
	play.custom_minimum_size.y = 70
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.add_theme_font_size_override("font_size", 34)
	play.pressed.connect(func():
		Sfx.ui_click()
		Game.race_opts.city = "tirane"
		Game.race_opts.event = ""
		Game.start_race())
	play_row.add_child(play)
	v.add_child(play_row)
	var customize := UiTheme.button(Data.t("menu.customize"))
	customize.custom_minimum_size.y = 52
	customize.pressed.connect(func(): Sfx.ui_click(); show_page("car"))
	v.add_child(customize)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for pair in [[Data.t("help.title"), "help"], [Data.t("settings.title"), "settings"], [Data.t("credits.button"), "credits"]]:
		var b := UiTheme.button(pair[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 50
		b.add_theme_font_size_override("font_size", 22)
		var target: String = pair[1]
		b.pressed.connect(func(): Sfx.ui_click(); back_to = "title"; show_page(target))
		row.add_child(b)
	return c


# ------------------------------------------------------------------ cup
func _page_cup() -> Control:
	var c := _page(0.55)
	var mc := _margin(c, 32)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	mc.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_eyebrow(Data.t("cup.eyebrow", Data.CUPS.tirana.size())))
	titles.add_child(UiTheme.headline(Data.t("cup.tirana.name"), 56, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	_cup_stars = UiTheme.headline("", 34, UiTheme.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_cup_stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_cup_stars)
	var rules := UiTheme.label(Data.t("cup.rules"), 20, UiTheme.MUTED)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rules)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	cup_cards.clear()
	var number := 0
	for event: Dictionary in Data.CUPS.tirana:
		number += 1
		grid.add_child(_cup_card(number, event))
	var back := UiTheme.button(Data.t("common.back"))
	back.custom_minimum_size = Vector2(200, 52)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): Sfx.ui_back(); show_page("title"))
	v.add_child(back)
	return c


func _cup_card(number: int, event: Dictionary) -> Button:
	var card := UiTheme.button("")
	card.name = "Cup_" + str(event.id)
	card.set_meta("event", event.id)
	card.custom_minimum_size = Vector2(380, 156)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("normal", UiTheme.flat(Color(0.03, 0.06, 0.1, 0.85), Color(1, 1, 1, 0.18), 14))
	card.pressed.connect(func():
		Sfx.ui_click()
		Game.race_opts.city = "tirane"
		Game.start_event(str(event.id)))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14 if side in ["left", "right"] else 10)
	card.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)
	var name_label := UiTheme.label("%d · %s" % [number, Data.t("cup.event.%s.name" % event.id)], 26, UiTheme.TEXT)
	name_label.name = "EventName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	var stars := StarRow.new(0, 24.0)
	stars.name = "Stars"
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(stars)
	var where := Data.t("cup.laps", int(event.laps)) + " · " + Data.env_label(str(event.env)) + " · " + Data.t("diff.%d" % int(event.diff))
	if bool(event.reverse):
		where += " · " + Data.t("cup.reverse")
	var conditions := UiTheme.label(where, 19, UiTheme.MUTED)
	conditions.name = "Conditions"
	column.add_child(conditions)
	var goal := UiTheme.label(Data.t("cup.goal", Data.cup_goal_text(event)), 19, UiTheme.AMBER)
	goal.name = "Goal"
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(goal)
	for label: Label in [name_label, conditions, goal]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cup_cards.append(card)
	return card


func _refresh_cup() -> void:
	var earned := 0
	var possible := 0
	for card in cup_cards:
		var stars := Progress.stars(str(card.get_meta("event")))
		(card.find_child("Stars", true, false) as StarRow).earned = stars
		earned += stars
		possible += Progress.MAX_STARS
	if _cup_stars != null:
		_cup_stars.text = "%d / %d" % [earned, possible]
	if _cup_button != null:
		_cup_button.text = Data.t("menu.cup_stars", [earned, possible])


func mode_index() -> int:
	for i in MODES.size():
		if MODES[i].mode == str(Game.race_opts.mode) and (MODES[i].mode == "race" or int(MODES[i].minutes) == int(Game.race_opts.points_minutes)):
			return i
	return 0


func _refresh_city() -> void:
	var points := str(Game.race_opts.mode) == "points"
	_mode.text = Data.t("menu.mode.points", int(Game.race_opts.points_minutes)) if points else Data.t("menu.mode.race")
	# The square has no laps, direction or weather to choose.
	_direction.disabled = points
	_weather.disabled = points
	_direction.text = Data.t("menu.direction.reverse") if bool(Game.race_opts.reverse) else Data.t("menu.direction.normal")
	_weather.text = Data.t("menu.weather.rain") if str(Game.race_opts.env) == "rainy" else Data.t("menu.weather.sun")
	var laps := Game.city_laps("tirane")
	_lap_value.text = str(laps)
	_lap_minus.disabled = laps <= 1 or points
	_lap_plus.disabled = laps >= 9 or points
	for i in _diff_btns.size():
		var b := _diff_btns[i]
		var selected: bool = i == int(Game.race_opts.diff)
		b.button_pressed = selected
		b.add_theme_stylebox_override("normal", UiTheme.flat(Color(UiTheme.CYAN, 0.25) if selected else Color(1, 1, 1, 0.06), UiTheme.CYAN if selected else Color(1, 1, 1, 0.2), 12))


func _change_laps(amount: int) -> void:
	Sfx.ui_click()
	Game.race_opts.laps = clampi(Game.city_laps("tirane") + amount, 1, 9)
	_refresh_city()


# ------------------------------------------------------------------ paint / driver
func _page_car() -> Control:
	var c := _page(0.25)
	var mc := _margin(c, 32)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	mc.add_child(v)
	v.add_child(_eyebrow(Data.t("garage.eyebrow", Data.GAME_NAME)))
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiTheme.headline(Data.t("garage.title"), 50, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_fans_label = UiTheme.headline("", 34, UiTheme.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	_fans_label.name = "GarageFans"
	_fans_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_fans_label)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var panel := UiTheme.panel(20)
	panel.custom_minimum_size.x = 560
	body.add_child(panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	panel.add_child(left)
	# One tab per thing to choose; the shop items sit among the owned ones.
	var tab_names := [Data.t("garage.tab.paint"), Data.t("garage.tab.rim"), Data.t("garage.tab.livery"), Data.t("garage.tab.driver")]
	_garage_tabs = _seg(tab_names, func(i: int): _show_garage_tab(GARAGE_TABS[i]))
	for b in _garage_tabs.get_children():
		(b as Button).custom_minimum_size = Vector2(124, 46)
		(b as Button).add_theme_font_size_override("font_size", 21)
	left.add_child(_garage_tabs)
	_garage_lists.clear()
	_shop_btns.clear()
	for kind in Data.SHOP_KINDS:
		var grid := GridContainer.new()
		grid.name = "Shop_" + kind
		grid.columns = 3 if kind != "livery" else 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		left.add_child(grid)
		_garage_lists[kind] = grid
		for item: Dictionary in Data.shop_items(kind):
			var b := _shop_button(kind, item)
			grid.add_child(b)
			_shop_btns[kind + ":" + str(item.id)] = b
	var drivers := VBoxContainer.new()
	drivers.add_theme_constant_override("separation", 10)
	left.add_child(drivers)
	_garage_lists["driver"] = drivers
	var driver_grid := GridContainer.new()
	driver_grid.columns = 3
	driver_grid.add_theme_constant_override("h_separation", 10)
	driver_grid.add_theme_constant_override("v_separation", 8)
	drivers.add_child(driver_grid)
	for i in Data.DRIVERS.size():
		var d: Dictionary = Data.DRIVERS[i]
		var b := UiTheme.button(Settings.driver_name(i))
		b.custom_minimum_size = Vector2(164, 50)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func(): Sfx.ui_click(); Game.race_opts.driver = idx; _refresh_car())
		driver_grid.add_child(b)
		_drv_btns[i] = b
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	drivers.add_child(name_row)
	name_row.add_child(UiTheme.label(Data.t("garage.driver_name"), 22, UiTheme.TEXT))
	_drv_name = LineEdit.new()
	_drv_name.name = "DriverName"
	_drv_name.max_length = Settings.NAME_MAX
	_drv_name.placeholder_text = Data.t("garage.driver_name.hint")
	_drv_name.custom_minimum_size = Vector2(260, 50)
	_drv_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_drv_name.select_all_on_focus = true
	_drv_name.add_theme_font_size_override("font_size", 24)
	_drv_name.text_changed.connect(func(text: String) -> void: rename_driver(int(Game.race_opts.driver), text, false))
	_drv_name.text_submitted.connect(func(text: String) -> void: rename_driver(int(Game.race_opts.driver), text, true))
	_drv_name.focus_exited.connect(func() -> void: rename_driver(int(Game.race_opts.driver), _drv_name.text, true))
	name_row.add_child(_drv_name)
	_drv_tag = UiTheme.label("", 22, UiTheme.MUTED)
	_drv_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drivers.add_child(_drv_tag)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	_car_desc = UiTheme.label("", 23, UiTheme.TEXT)
	_car_desc.name = "ItemName"
	_car_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_car_desc)
	_buy_btn = UiTheme.button("", UiTheme.AMBER.darkened(0.45))
	_buy_btn.name = "BuyButton"
	_buy_btn.custom_minimum_size.y = 56
	_buy_btn.pressed.connect(_buy_preview)
	left.add_child(_buy_btn)
	v.add_child(_bottombar(func(): show_page("title"), Data.t("menu.start"), func(): Game.race_opts.city = "tirane"; Game.race_opts.event = ""; Game.start_race()))
	_show_garage_tab("paint")
	return c


func _shop_button(kind: String, item: Dictionary) -> Button:
	var b := UiTheme.button("")
	b.name = "%s_%s" % [kind, item.id]
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(164, 64) if kind != "livery" else Vector2(250, 64)
	b.add_theme_font_size_override("font_size", 20)
	b.tooltip_text = Data.shop_name(kind, str(item.id))
	if kind == "paint" or kind == "rim":
		# A swatch of the colour on the left of the button.
		b.icon = _swatch(Color.html(str(item.color)))
	var id := str(item.id)
	b.pressed.connect(func(): Sfx.ui_click(); _pick_item(kind, id))
	return b


func _swatch(col: Color) -> ImageTexture:
	var image := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for x in 28:
		for y in 28:
			var inside := Vector2(x - 13.5, y - 13.5).length() <= 12.5
			image.set_pixel(x, y, col if inside else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _show_garage_tab(tab: String) -> void:
	_garage_tab = tab
	for key in _garage_lists:
		(_garage_lists[key] as Control).visible = key == tab
	_seg_set(_garage_tabs, GARAGE_TABS.find(tab))
	_refresh_car()


## The item a garage car shows for `kind`: a previewed one, or the choice.
func garage_choice(kind: String) -> String:
	if _preview.get("kind", "") == kind:
		return str(_preview.id)
	match kind:
		"paint":
			return str(Game.race_opts.car)
		"rim":
			return str(Game.cosmetics().rim)
		"livery":
			return str(Game.cosmetics().livery)
	return ""


## Owned: wear it. Not owned: show it on the car with its price.
func _pick_item(kind: String, id: String) -> void:
	if Progress.owns(kind, id):
		_preview = {}
		_choose(kind, id)
	else:
		_preview = {"kind": kind, "id": id}
	_set_garage_car(garage_choice("paint"))
	_refresh_car()


func _choose(kind: String, id: String) -> void:
	match kind:
		"paint":
			Game.race_opts.car = id
		"rim":
			Settings.rim_id = id
			Settings.save()
		"livery":
			Settings.livery_id = id
			Settings.save()


func _buy_preview() -> void:
	if _preview.is_empty():
		return
	var kind := str(_preview.kind)
	var id := str(_preview.id)
	if not Progress.buy(kind, id):
		Sfx.play("denied", "UI", -6.0)
		return
	Sfx.play("pickup", "UI", -4.0)
	_preview = {}
	_choose(kind, id)
	_set_garage_car(garage_choice("paint"))
	_refresh_car()


## Gives driver `index` the typed name; `commit` (enter, leaving the field)
## saves it and shows the cleaned name, or the default when left empty.
func rename_driver(index: int, text: String, commit: bool) -> void:
	Settings.set_driver_name(index, text)
	if _drv_btns.has(index):
		(_drv_btns[index] as Button).text = Settings.driver_name(index)
	if commit:
		Settings.save()
		if _drv_name != null:
			_drv_name.text = Settings.driver_name(index)


func _refresh_car() -> void:
	if _drv_tag == null:
		return
	for i in _drv_btns:
		var b: Button = _drv_btns[i]
		var selected: bool = i == int(Game.race_opts.driver)
		b.button_pressed = selected
		b.add_theme_stylebox_override("normal", UiTheme.flat(Color(UiTheme.CYAN, 0.25) if selected else Color(1, 1, 1, 0.05), UiTheme.CYAN if selected else Color(1, 1, 1, 0.15), 12))
	_drv_tag.text = Data.t("driver.%d.tag" % clampi(int(Game.race_opts.driver), 0, Data.DRIVERS.size() - 1))
	if _drv_name != null and not _drv_name.has_focus():
		_drv_name.text = Settings.driver_name(int(Game.race_opts.driver))
	for key in _shop_btns:
		var b: Button = _shop_btns[key]
		var kind: String = key.get_slice(":", 0)
		var id: String = key.get_slice(":", 1)
		var owned := Progress.owns(kind, id)
		var shown := garage_choice(kind) == id
		var worn := owned and shown
		b.button_pressed = shown
		var label := Data.shop_name(kind, id) if kind != "paint" else ""
		if not owned:
			label = (label + " · " if not label.is_empty() else "") + Data.t("garage.price", Data.shop_price(kind, id))
		b.text = label
		var border := UiTheme.CYAN if worn else (UiTheme.AMBER if shown else Color(1, 1, 1, 0.2 if owned else 0.1))
		b.add_theme_stylebox_override("normal", UiTheme.flat(Color(UiTheme.CYAN, 0.2) if worn else Color(1, 1, 1, 0.06 if owned else 0.02), border, 12, 2 if shown else 1))
		b.add_theme_color_override("font_color", UiTheme.TEXT if owned else UiTheme.AMBER)
	_fans_label.text = Data.t("garage.fans", Progress.fans)
	# What is shown, and whether it can be bought.
	if _preview.is_empty():
		_buy_btn.visible = false
		var kind := _garage_tab if _garage_tab != "driver" else "paint"
		_car_desc.text = "%s · %s" % [Data.CAR_MODEL, Data.shop_name(kind, garage_choice(kind))] if _garage_tab != "driver" else "%s · %s" % [Data.CAR_MODEL, Data.car_name(str(Game.race_opts.car))]
	else:
		var kind := str(_preview.kind)
		var id := str(_preview.id)
		var price := Data.shop_price(kind, id)
		_car_desc.text = Data.t("garage.preview", Data.shop_name(kind, id))
		_buy_btn.visible = true
		_buy_btn.disabled = price > Progress.fans
		_buy_btn.text = Data.t("garage.buy", price) if price <= Progress.fans else Data.t("garage.need", price - Progress.fans)


# ------------------------------------------------------------------ settings
func _page_settings() -> Control:
	var c := _page(0.75)
	var mc := _margin(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mc.add_child(v)
	v.add_child(UiTheme.headline(Data.t("settings.title"), 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	list.add_child(preload("res://scripts/ui/control_settings.gd").new())
	list.add_child(UiTheme.spacer(12))
	var no_yes := [Data.t("common.no"), Data.t("common.yes")]
	_set_row(list, "assist", Data.t("settings.assist"), no_yes, func(i): Settings.assist = (i == 1))
	_set_row(list, "handling", Data.t("settings.handling"), [Data.t("settings.handling.arcade"), Data.t("settings.handling.pro")], func(i):
		Settings.handling = Data.HANDLING.keys()[i])
	_set_row(list, "weather", Data.t("settings.weather"), no_yes, func(i): Settings.dynamic_weather = (i == 1))
	_set_row(list, "haptics", Data.t("settings.haptics"), no_yes, func(i): Settings.haptics = (i == 1))
	_set_row(list, "announcer", Data.t("settings.announcer"), no_yes, func(i): Settings.announcer = (i == 1))
	_set_row(list, "quality", Data.t("settings.quality"), [Data.t("quality.auto"), Data.t("quality.low"), Data.t("quality.medium"), Data.t("quality.high")], func(i):
		Settings.quality = ["auto", "low", "medium", "high"][i]
		Quality.configure_from_settings()
		Quality.apply_viewport(get_viewport()))
	_set_row(list, "frame_target", Data.t("settings.frame_target"), [Data.t("settings.fps_60"), Data.t("settings.fps_30")], func(i):
		Settings.frame_target = 60 if i == 0 else 30
		Quality.configure_from_settings()
		Quality.apply_viewport(get_viewport()))
	_set_row(list, "adaptive_quality", Data.t("settings.adaptive"), no_yes, func(i):
		Settings.adaptive_quality = i == 1
		Quality.configure_from_settings()
		Quality.apply_viewport(get_viewport()))
	_set_row(list, "fps", Data.t("settings.show_fps"), no_yes, func(i): Settings.show_fps = (i == 1))
	_set_slider(list, "master", Data.t("settings.volume.master"), func(x): Settings.vol_master = x)
	_set_slider(list, "engine", Data.t("settings.volume.engine"), func(x): Settings.vol_engine = x)
	_set_slider(list, "tyres", Data.t("settings.volume.tyres"), func(x): Settings.vol_tyres = x)
	_set_slider(list, "impacts", Data.t("settings.volume.impacts"), func(x): Settings.vol_impacts = x)
	_set_slider(list, "pickups", Data.t("settings.volume.pickups"), func(x): Settings.vol_pickups = x)
	_set_slider(list, "voice", Data.t("settings.volume.voice"), func(x): Settings.vol_voice = x)
	var done := UiTheme.button(Data.t("settings.done"), UiTheme.PINK.darkened(0.25), 200)
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
	var l := UiTheme.label(title, 25)
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
	var l := UiTheme.label(title, 25)
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
	_seg_set(_set_rows.assist, 1 if Settings.assist else 0)
	_seg_set(_set_rows.handling, maxi(0, Data.HANDLING.keys().find(Settings.handling)))
	_seg_set(_set_rows.haptics, 1 if Settings.haptics else 0)
	_seg_set(_set_rows.announcer, 1 if Settings.announcer else 0)
	_seg_set(_set_rows.quality, maxi(0, ["auto", "low", "medium", "high"].find(Settings.quality)))
	_seg_set(_set_rows.fps, 1 if Settings.show_fps else 0)
	_seg_set(_set_rows.frame_target, 1 if Settings.frame_target == 30 else 0)
	_seg_set(_set_rows.adaptive_quality, 1 if Settings.adaptive_quality else 0)
	(_set_rows.master as HSlider).set_value_no_signal(Settings.vol_master)
	(_set_rows.engine as HSlider).set_value_no_signal(Settings.vol_engine)
	(_set_rows.tyres as HSlider).set_value_no_signal(Settings.vol_tyres)
	(_set_rows.impacts as HSlider).set_value_no_signal(Settings.vol_impacts)
	(_set_rows.pickups as HSlider).set_value_no_signal(Settings.vol_pickups)
	(_set_rows.voice as HSlider).set_value_no_signal(Settings.vol_voice)
	var qb: Button = _set_rows.quality.get_child(0)
	qb.text = Data.t("quality.auto_detected", Data.t("quality.%s" % Quality.detected).to_lower())


# ------------------------------------------------------------------ help
func _page_help() -> Control:
	var c := _page(0.8)
	var mc := _margin(c, 60)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	mc.add_child(v)
	v.add_child(UiTheme.headline(Data.t("help.title"), 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
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
	rt.add_theme_font_size_override("normal_font_size", 25)
	rt.add_theme_font_size_override("bold_font_size", 25)
	var cy := "#" + UiTheme.CYAN.to_html(false)
	rt.text = "\n\n".join(PackedStringArray([Data.t("help.goal"), Data.t("help.steering", cy), Data.t("help.setup"),
		Data.t("help.powers", [cy, cy]), Data.t("help.inventory"), Data.t("help.warnings"),
		Data.t("help.drift"), Data.t("help.keyboard")]))
	inner.add_child(rt)
	inner.add_child(_eyebrow(Data.t("help.powers_title")))
	var grid := GridContainer.new()
	grid.columns = 1
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
		var l := UiTheme.label("%s — %s" % [Data.pw_name(k), Data.pw_desc(k)], 24, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 900
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		grid.add_child(h)
	var done := UiTheme.button(Data.t("help.done"), UiTheme.PINK.darkened(0.25), 200)
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
	v.add_child(UiTheme.headline(Data.t("credits.title"), 44, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
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
	rt.add_theme_font_size_override("normal_font_size", 23)
	rt.add_theme_font_size_override("bold_font_size", 23)
	rt.text = FileAccess.get_file_as_string("res://assets/CREDITS.txt") if FileAccess.file_exists("res://assets/CREDITS.txt") else "—"
	rt.text += "\n\n" + Data.t("credits.engine_license") + "\n" + Engine.get_license_text()
	for license_path in ["res://assets/fonts/OFL-BigShouldersDisplay.txt", "res://assets/fonts/OFL-ChakraPetch.txt"]:
		rt.text += "\n\n" + FileAccess.get_file_as_string(license_path)
	sc.add_child(rt)
	var done := UiTheme.button(Data.t("common.back"), Color(0, 0, 0, 0), 200)
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
			"car": show_page("title")
			"cup": show_page("title")
			_: show_page(back_to)
		get_viewport().set_input_as_handled()
