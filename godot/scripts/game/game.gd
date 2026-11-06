extends Node
## Scene flow: menu -> race -> results. Holds the options for the next race
## and the result of the last one.

signal scene_changed(name: String)

const SCENES := {
	"menu": "res://scenes/menu.tscn",
	"race": "res://scenes/race.tscn",
	"results": "res://scenes/results.tscn",
}

# Independent, short curiosities for transitions; shuffled without repeats until
# the entire collection has been shown.
const LOADING_FACTS := [
	"Oktapodi ka tri zemra.",
	"Banania është botanikisht një manaferrë.",
	"Vombatët bëjnë jashtëqitje në formë kubi.",
	"Një ditë në Venus zgjat më shumë se viti i saj.",
	"Bletët mund të dallojnë fytyrat e njerëzve.",
	"Karkalecat e detit i kanë dhëmbët në stomak.",
	"Kulla Eifel zgjatet pak në vapë.",
	"Disa breshka marrin oksigjen edhe nga pjesa e pasme.",
	"Një re mund të peshojë qindra tonë.",
	"Peshkaqenët janë më të vjetër se pemët.",
	"Luleshtrydhja nuk është manaferrë në botanikë.",
	"Venera është planeti më i nxehtë i sistemit diellor.",
	"Fluturat ndiejnë shijen me këmbë.",
	"Një grup korbash në anglisht quhet ‘murder’.",
	"Zemra e karkalecit ndodhet në kokë.",
	"Ka më shumë pemë në Tokë sesa yje në Rrugën e Qumështit.",
	"Koalat kanë shenja gishtash të ngjashme me tonat.",
	"Bambu është bar, jo pemë.",
	"Një vit në Merkur zgjat rreth 88 ditë tokësore.",
	"Uji i nxehtë mund të ngrijë para ujit të ftohtë në disa kushte.",
	"Kallamari gjigant ka sy sa një pjatë e madhe.",
	"Deti i Vdekur është në të vërtetë një liqen.",
	"Të porsalindurit kanë më shumë kocka se të rriturit.",
	"Kërmijtë mund të kenë mijëra dhëmbë të vegjël.",
]
var _fact_bag: Array = []
var _last_fact := ""

var race_opts := {
	"city": "tirane",
	"env": "",          # "" = city default
	"laps": 0,          # 0 = city default
	"diff": 1,
	"car": "benxi",
	"driver": 0,
}
var last_result: Dictionary = {}
var current := ""
var _root: Node = null
var _loading := false
var frame_ms_avg := 0.0
var frame_ms_max := 0.0
var _ft_acc := 0.0
var _ft_n := 0
var _ft_max := 0.0
var _ft_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	race_opts.city = Settings.city_id
	race_opts.car = Settings.car_id
	race_opts.driver = Settings.driver
	race_opts.diff = Settings.difficulty
	race_opts.env = Settings.env_override
	race_opts.laps = Settings.laps_override


func _process(dt: float) -> void:
	# rolling frame time stats for the HUD / milestone reports
	var ms := dt * 1000.0
	_ft_acc += ms
	_ft_n += 1
	_ft_max = maxf(_ft_max, ms)
	_ft_t += dt
	if _ft_t >= 1.0:
		frame_ms_avg = _ft_acc / maxi(_ft_n, 1)
		frame_ms_max = _ft_max
		_ft_acc = 0.0
		_ft_n = 0
		_ft_max = 0.0
		_ft_t = 0.0


func set_root(root: Node) -> void:
	_root = root


func goto(name: String) -> void:
	if _loading or not SCENES.has(name):
		return
	_loading = true
	# Constructing and freeing the city can block the main thread. Show a
	# transition first and give the renderer a frame to present it.
	var overlay := _transition_overlay(name)
	add_child(overlay)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in _root.get_children():
		c.queue_free()
	await get_tree().process_frame
	var ps: PackedScene = load(SCENES[name])
	var inst := ps.instantiate()
	_root.add_child(inst)
	current = name
	await get_tree().process_frame
	overlay.queue_free()
	_loading = false
	scene_changed.emit(name)


func _transition_overlay(_name: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "TransitionOverlay"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.06, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	# Use a centered, width-constrained stack: long facts can wrap naturally on
	# narrower phones without covering the title or running off the screen.
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.anchor_left = 0.08
	content.anchor_right = 0.92
	content.anchor_top = 0.18
	content.anchor_bottom = 0.82
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(content)
	var label := Label.new()
	label.name = "LoadingTitle"
	label.text = "Gara po fillon"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	var fact_label := Label.new()
	fact_label.name = "LoadingFactHeading"
	fact_label.text = "Fakt rastesor:"
	fact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fact_label.add_theme_font_size_override("font_size", 36)
	fact_label.add_theme_color_override("font_color", Color("b8d9ef"))
	fact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(fact_label)
	var fact := Label.new()
	fact.name = "LoadingFact"
	fact.text = _next_loading_fact()
	fact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact.add_theme_font_size_override("font_size", 36)
	fact.add_theme_color_override("font_color", Color.WHITE)
	fact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(fact)
	return layer


func _next_loading_fact() -> String:
	if _fact_bag.is_empty():
		_fact_bag = LOADING_FACTS.duplicate()
		_fact_bag.shuffle()
		if _fact_bag.size() > 1 and _fact_bag.back() == _last_fact:
			var first: String = _fact_bag[0]
			_fact_bag[0] = _fact_bag.back()
			_fact_bag[_fact_bag.size() - 1] = first
	_last_fact = _fact_bag.pop_back()
	return _last_fact


func start_race() -> void:
	Settings.city_id = race_opts.city
	Settings.car_id = race_opts.car
	Settings.driver = race_opts.driver
	Settings.difficulty = race_opts.diff
	Settings.env_override = race_opts.env
	Settings.laps_override = race_opts.laps
	Settings.save()
	goto("race")


func finish_race(result: Dictionary) -> void:
	last_result = result
	Settings.record_result(result.get("city", ""), int(result.get("place", 6)), float(result.get("best_lap", INF)))
	goto("results")


func city_env(city_id: String) -> String:
	if race_opts.env != "":
		return race_opts.env
	return Data.city(city_id).env


func city_laps(city_id: String) -> int:
	if int(race_opts.laps) > 0:
		return int(race_opts.laps)
	return int(Data.city(city_id).laps)


static func fmt_time(t: float) -> String:
	if t == INF or t < 0.0:
		return "--:--.---"
	var m := int(t / 60.0)
	var s := t - m * 60.0
	return "%d:%06.3f" % [m, s]
