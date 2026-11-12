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
# the entire collection has been shown. Sources and dated updates:
# docs/loading-facts.md (reviewed 2026-11-12).
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
	"Mjalti i ruajtur mirë mund të qëndrojë për vite pa u prishur.",
	"Delfinët flenë me një gjysmë të trurit zgjuar.",
	"Pinguini perandor e mban vezën mbi këmbë.",
	"Gjirafat dhe njerëzit kanë shtatë rruaza në qafë.",
	"Disa bretkosa mund të ngrijnë pjesërisht dhe të mbijetojnë.",
	"Hëna largohet nga Toka me disa centimetra në vit.",
	"Në Saturn, një vit zgjat rreth 29 vjet tokësore.",
	"Në Mars, perëndimet e diellit mund të duken blu.",
	"Dielli përmban shumicën dërrmuese të masës së sistemit diellor.",
	"Yjet e detit nuk kanë tru si i yni.",
	"Një lepur nuk mund të vjellë.",
	"Kuajt mund të dremisin në këmbë.",
	"Lakuriqët e natës janë gjitarët e vetëm që fluturojnë aktivisht.",
	"Lidhjet mes rrënjëve të bimëve dhe kërpudhave quhen mikoriza.",
	"Qumështi i hipopotamit nuk është rozë.",
	"Milingonat nuk kanë mushkëri.",
	"Hunda e njeriut mund të dallojë shumë lloje aromash.",
	"Luledielli i ri mund ta ndjekë diellin gjatë ditës.",
	"Akullnajat ruajnë flluska ajri nga e shkuara.",
	"Antarktida është shkretëtira më e madhe në botë.",
	"Kanadaja ka më shumë liqene se çdo shtet tjetër.",
	"Në Zelandën e Re jetojnë më shumë dele sesa njerëz.",
	"Grenlanda është ishulli më i madh në botë.",
	"Një ylber është rreth i plotë; toka zakonisht fsheh pjesën e poshtme.",
	"Bubullima është tingulli i ajrit të nxehur nga rrufeja.",
	"Kristalet e borës zakonisht kanë gjashtë krahë.",
	"Kokrra e kafesë është fara e një fruti.",
	"Arrëmyshku dhe lulja e arrëmyshkut vijnë nga i njëjti frut.",
	"Kikiriku rritet nën tokë dhe është bishtajore.",
	"Karota dikur kultivohej edhe në ngjyrë vjollcë.",
	"Kripa e zakonshme përbëhet nga natrium dhe klor.",
	"Spanjishtja vendos një pikëpyetje të përmbysur në fillim të pyetjes.",
	"Pianoja prodhon tingull kur çekiçët e saj godasin telat.",
	"Shahu ka 64 fusha.",
	"Origami është arti japonez i palosjes së letrës.",
	"Kleopatra jetoi më afër uljes në Hënë sesa ndërtimit të Piramidës së Madhe.",
	"Lufta anglo-zanzibarase e vitit 1896 zgjati më pak se një orë.",
	"Disa kandilë deti janë biolumineshentë: prodhojnë dritë.",
	"Disa peshq mund të ndryshojnë gjininë gjatë jetës.",
	"Poli i Veriut ndodhet mbi oqean, jo mbi tokë.",
	# Space and the solar system.
	"Jupiteri është planeti më i madh i sistemit diellor.",
	"Merkuri është planeti më i vogël i sistemit diellor.",
	"Dendësia mesatare e Saturnit është më e ulët se ajo e ujit.",
	"Urani rrotullohet pothuajse i shtrirë në anë.",
	"Një vit në Neptun zgjat rreth 165 vjet tokësore.",
	"Një ditë në Mars zgjat rreth 24 orë e 39 minuta.",
	"Marsi ka dy hëna: Fobosin dhe Deimosin.",
	"Merkuri dhe Venera nuk kanë hëna natyrore.",
	"Hëna na tregon pothuajse gjithmonë të njëjtën faqe.",
	"Graviteti në sipërfaqen e Hënës është rreth një e gjashta e atij në Tokë.",
	"Dritës së Diellit i duhen rreth 8 minuta e 20 sekonda të arrijë në Tokë.",
	"Viti-dritë mat largësinë, jo kohën.",
	"Dielli është një yll dhe energjinë e prodhon nga shkrirja bërthamore.",
	"Plutoni u klasifikua si planet xhuxh në vitin 2006.",
	"Ceresi është planeti xhuxh në brezin e asteroidëve mes Marsit dhe Jupiterit.",
	"Unazat e Saturnit përbëhen kryesisht nga copa akulli.",
	# Water, wildlife and Earth.
	"Uji mbulon rreth 71 për qind të sipërfaqes së Tokës.",
	"Oqeanet mbajnë rreth 96,5 për qind të gjithë ujit të Tokës.",
	"Akulli noton sepse është më pak i dendur se uji i lëngshëm.",
	"Vetëm rreth 2,5 për qind e ujit të Tokës është ujë i ëmbël.",
	"Koralet janë kafshë.",
	"Te kuajt e detit, mashkulli i mban vezët në një qeskë dhe lind të vegjlit.",
	"Balena blu është kafsha më e madhe e njohur që ka jetuar në Tokë.",
	"Skeleti i peshkaqenëve përbëhet nga kërc, jo nga kocka.",
	"Thellësia mesatare e oqeanit është rreth 3,7 kilometra.",
	"Paqësori është oqeani më i madh i Tokës.",
	"Pika më e thellë e njohur e oqeanit ndodhet në Hendekun e Marianës.",
	"Baticat dhe zbaticat ndikohen nga graviteti i Hënës dhe i Diellit.",
	"Bërthama e brendshme e Tokës është e ngurtë; bërthama e jashtme është e lëngshme.",
	"Shumica e tërmeteve ndodhin pranë kufijve të pllakave tektonike.",
	"Disa gurë shtufi mund të notojnë në ujë falë poreve të mbushura me ajër.",
	"Obsidiani është qelq natyror që formohet nga ftohja e shpejtë e lavës.",
	# Regional nature and cultural heritage.
	"Berati iu shtua pasurisë botërore të UNESCO-s në vitin 2008.",
	"Qendra historike e Gjirokastrës hyri në listën e UNESCO-s në vitin 2005.",
	"Butrinti hyri në listën e pasurive botërore të UNESCO-s në vitin 1992.",
	"Liqeni i Ohrit ndahet mes Shqipërisë dhe Maqedonisë së Veriut.",
	"Iso-polifonia popullore shqiptare është në listën përfaqësuese të UNESCO-s që nga viti 2008.",
	"Mjeshtëria e xhubletës u përfshi në listën e UNESCO-s për ruajtje urgjente në vitin 2022.",
	"Lahuta tradicionale shqiptare ka një tel.",
	"Vjosa i ka burimet në malet e Pindit në Greqi.",
	"Vjosa derdhet në detin Adriatik.",
	"Alfabeti i shqipes ka 36 shkronja.",
	# Science, measurements and everyday curiosities.
	"Drita në vakum udhëton saktësisht 299 792 458 metra në sekondë.",
	"Sistemi Ndërkombëtar i Njësive ka shtatë njësi bazë.",
	"Që nga viti 2019, kilogrami përcaktohet përmes konstantës së Plankut.",
	"Zero kelvin përkon me −273,15 gradë Celsius.",
	"Hidrogjeni është elementi i parë në tabelën periodike.",
	"Simboli kimik i arit është Au, nga fjala latine ‘aurum’.",
	"Emri i heliumit vjen nga fjala greke për Diellin.",
	"Diamanti dhe grafiti përbëhen nga i njëjti element: karboni.",
	"Tingulli ka nevojë për një mjedis për t'u përhapur; nuk udhëton në vakum.",
	"Lazeri e ka marrë emrin nga një shkurtim në anglisht për përforcimin e dritës.",
	"Sistemi binar i numërimit përdor vetëm shifrat 0 dhe 1.",
	"Një bajt përbëhet nga tetë bite.",
	"Në një zar standard, faqet përballë kanë gjithsej shtatë pika.",
	"Në gjeometrinë e rrafshit, këndet e një trekëndëshi kanë shumën 180 gradë.",
	# Recent milestones carry dates so they remain accurate as the pool grows.
	"Në vitin 2025, Lugina e Vjosës u shpall rezervë biosfere e UNESCO-s.",
	"Në vitin 2025, arti i lahutës shqiptare hyri në listën e UNESCO-s për ruajtje urgjente.",
	"Më 2 mars 2025, mjeti Blue Ghost u ul me sukses në Hënë.",
	"Në mars 2025, Euclid publikoi të dhëna që përfshinin rreth 26 milionë galaktika.",
	"Teleskopi SPHEREx, i nisur në mars 2025, vëzhgon qiellin në 102 ngjyra infra të kuqe.",
	"Në shtator 2025, arkivi i NASA-s arriti në 6 000 ekzoplanete të konfirmuara.",
	"Në tetor 2026, zbulimet me të dhënat e teleskopit TESS arritën në 1 000 planete të konfirmuara.",
	"Në dhjetor 2025, SPHEREx përfundoi hartën e tij të parë infra të kuqe të gjithë qiellit.",
]
var _fact_bag: Array = []
var _last_fact := ""

var race_opts := {
	"city": "tirane",
	"env": "",          # "" = city default
	"laps": 0,          # 0 = city default
	"reverse": false,   # travel the same circuit in the opposite direction
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
	race_opts.reverse = Settings.reverse_lap


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
	Settings.reverse_lap = bool(race_opts.reverse)
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
