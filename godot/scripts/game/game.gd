extends Node
## Scene flow: menu -> race -> results. Holds the options for the next race
## and the result of the last one.

signal scene_changed(name: String)

const SCENES := {
	"menu": "res://scenes/menu.tscn",
	"race": "res://scenes/race.tscn",
	"arena": "res://scenes/arena.tscn",
	"results": "res://scenes/results.tscn",
}


## Debug/benchmark options ("--scene=race", "--benchmark=60", ...), wherever
## they were given. A desktop run passes them after "--". An exported APK
## cannot: Godot appends its own engine flags ("--xr-mode off --fullscreen")
## behind the preset's extra arguments, and a "--" there would hide those
## from the engine. So the APK bakes the options in bare, and both lists count.
static func launch_options() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()

var _fact_bag: Array = []
var _last_fact := ""

var race_opts := {
	"city": "tirane",
	"env": "",          # "" = city default
	"laps": 0,          # 0 = city default
	"reverse": false,   # travel the same circuit in the opposite direction
	"diff": 1,
	"car": "benxi",
	"mode": "race",        # "race", or "points": the square, by score
	"event": "",           # a cup event id: its own laps, weather, rivals, direction
	"tutorial": false,     # set by the tutorial event only
	"points_minutes": 2,
}
var last_result: Dictionary = {}
var current := ""
var _root: Node = null
## The online session (lobby or race), null when playing alone.
var net: NetSession = null
## An online race this phone has left the screen of (finished, results up)
## but still steps with empty input, so the others never wait for it.
var _net_tail: NetRace = null
var _net_tail_ticks := 0
const NET_TAIL_MAX_TICKS := 60 * 240
var _loading := false
var frame_ms_avg := 0.0
var frame_ms_max := 0.0
var _ft_acc := 0.0
var _ft_n := 0
var _ft_max := 0.0
var _ft_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A saved city this build lacks, or one still locked, falls back to home.
	race_opts.city = Settings.city_id if Data.city_available(Settings.city_id) and Progress.city_open(Settings.city_id) else Progress.HOME_CITY
	# A saved paint the player no longer owns falls back to the first one.
	race_opts.car = Settings.car_id if Progress.owns("paint", Settings.car_id) else str(Data.CARS[0].id)
	race_opts.diff = Settings.difficulty
	race_opts.env = Settings.env_override
	race_opts.laps = Settings.laps_override
	race_opts.reverse = Settings.reverse_lap


func _process(dt: float) -> void:
	_step_net_tail()
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


const TRANSITION_FADE_IN := 0.14
const TRANSITION_FADE_OUT := 0.3


## The heavy files a scene loads while it builds, read on loader threads
## first so the loading ring shows real progress and the build finds them
## cached instead of blocking on the disk.
func _warm_paths(name: String) -> Array:
	var city := "res://assets/cities/%s/" % str(race_opts.city)
	var paths := []
	match name:
		"race":
			paths = [city + "buildings.glb", city + "roads.glb", city + "splat.png",
				"res://assets/landmarks/skanderbeg_approx.glb", "res://assets/foliage/tree_small_02_mobile.glb"]
		"arena":
			paths = ["res://assets/landmarks/skanderbeg_approx.glb"]
	return paths.filter(func(p: String) -> bool: return ResourceLoader.exists(p))


func goto(name: String) -> void:
	if _loading or not SCENES.has(name):
		return
	_loading = true
	Announcer.clear()
	# Constructing and freeing the city can block the main thread. Show a
	# transition first and give the renderer a frame to present it.
	var overlay := _transition_overlay(name)
	add_child(overlay)
	var ring := overlay.find_child("LoadingRing", true, false) as LoadingRing
	var cover := overlay.get_child(0) as Control
	cover.modulate.a = 0.0
	var fade_in := UiTheme.fade(cover, 1.0, TRANSITION_FADE_IN)
	if fade_in != null:
		await fade_in.finished
	await get_tree().process_frame
	# Read the scene and its heavy files on loader threads (75% of the ring).
	var paths := [SCENES[name]] + _warm_paths(name)
	# The headless renderer used by the tests cannot create textures from
	# several threads; there the files load on this thread, one per frame.
	var threaded := DisplayServer.get_name() != "headless"
	if threaded:
		for p in paths:
			ResourceLoader.load_threaded_request(p)
	else:
		for i in paths.size():
			ResourceLoader.load(paths[i])
			ring.set_progress(0.75 * float(i + 1) / paths.size())
			await get_tree().process_frame
	while threaded:
		var total := 0.0
		var waiting := false
		for p in paths:
			var progress := []
			if ResourceLoader.load_threaded_get_status(p, progress) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				waiting = true
				total += float(progress[0]) if not progress.is_empty() else 0.0
			else:
				total += 1.0
		ring.set_progress(0.75 * total / paths.size())
		if not waiting:
			break
		await get_tree().process_frame
	# Held until the new scene has taken its own references.
	var held := paths.map(func(p: String) -> Resource: return ResourceLoader.load_threaded_get(p) if threaded else load(p))
	ring.set_progress(0.8)
	await get_tree().process_frame
	for c in _root.get_children():
		c.queue_free()
	await get_tree().process_frame
	var ps := held[0] as PackedScene
	if ps == null:
		ps = load(SCENES[name])
	ring.set_progress(0.85)
	await get_tree().process_frame
	var inst := ps.instantiate()
	_root.add_child(inst)
	current = name
	held.clear()
	ring.set_progress(1.0)
	await get_tree().process_frame
	# The new scene is live from here; the cover fades off it without
	# swallowing touches.
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade_out := UiTheme.fade(cover, 0.0, TRANSITION_FADE_OUT)
	if fade_out != null:
		fade_out.finished.connect(overlay.queue_free)
	else:
		overlay.queue_free()
	_loading = false
	scene_changed.emit(name)


## The loading screen: the scene's name top left, a random fact in a card at
## the bottom left, and the badge in its progress ring in the bottom right
## corner, the way console and mobile racers keep a loading screen calm.
func _transition_overlay(name: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "TransitionOverlay"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := TextureRect.new()
	bg.name = "Cover"
	var grad := Gradient.new()
	grad.set_color(0, Color("12182a"))
	grad.set_color(1, Color("05070c"))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.25, 0.2)
	tex.fill_to = Vector2(1.1, 1.1)
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(bg)
	# The name, huge and faint, fills the empty middle like key art would.
	var mark := UiTheme.headline(Data.GAME_NAME.to_upper(), 300, Color(1, 1, 1, 0.035), HORIZONTAL_ALIGNMENT_RIGHT)
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	mark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mark.offset_right = -40
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(mark)
	var safe := UiTheme.safe_area(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 44 if side in ["left", "right"] else 36)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	var label := UiTheme.headline(Data.GAME_NAME.to_upper() if name in ["menu", "results"] else Data.t("loading.title"), 54, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	label.name = "LoadingTitle"
	column.add_child(label)
	var accent := ColorRect.new()
	accent.color = UiTheme.CYAN
	accent.custom_minimum_size = Vector2(72, 4)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(accent)
	var info := UiTheme.label(_loading_info(name), 26, UiTheme.MUTED)
	info.name = "LoadingInfo"
	column.add_child(info)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 32)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.flat(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1), 16, 1))
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(card)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 22)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 6)
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(facts)
	var fact_label := UiTheme.label(Data.t("loading.fact_heading"), 24, UiTheme.CYAN)
	fact_label.name = "LoadingFactHeading"
	facts.add_child(fact_label)
	var fact := UiTheme.label(_next_loading_fact(), 32, Color.WHITE)
	fact.name = "LoadingFact"
	fact.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact.custom_minimum_size.x = 640
	facts.add_child(fact)
	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(push)
	var ring := LoadingRing.new(150.0)
	ring.name = "LoadingRing"
	ring.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(ring)
	return layer


## What is being loaded, under the title: city, laps and weather, or the
## square and the round's length.
func _loading_info(name: String) -> String:
	match name:
		"race":
			var weather := Data.t("env.rainy") if str(race_setting("env")) == "rainy" else Data.t("env.day")
			return Data.t("loading.race_info", [Data.city_name(str(race_opts.city)), int(race_setting("laps")) if int(race_setting("laps")) > 0 else city_laps(str(race_opts.city)), weather])
		"arena":
			return Data.t("loading.arena_info", int(race_opts.points_minutes))
	return ""


func _next_loading_fact() -> String:
	if _fact_bag.is_empty():
		_fact_bag = Data.t_list("loading.facts").duplicate()
		_fact_bag.shuffle()
		if _fact_bag.size() > 1 and _fact_bag.back() == _last_fact:
			var first: String = _fact_bag[0]
			_fact_bag[0] = _fact_bag.back()
			_fact_bag[_fact_bag.size() - 1] = first
	_last_fact = _fact_bag.pop_back()
	return _last_fact


## What the player's car wears: owned rim and livery, else the free ones.
func cosmetics() -> Dictionary:
	return {
		"rim": Settings.rim_id if Progress.owns("rim", Settings.rim_id) else Data.shop_free("rim")[0],
		"livery": Settings.livery_id if Progress.owns("livery", Settings.livery_id) else Data.shop_free("livery")[0],
	}


## Play a cup event. Its settings are the event's; the player's own race
## choices are left as they were.
func start_event(id: String) -> void:
	if Data.cup_event(id).is_empty():
		return
	race_opts.event = id
	race_opts.mode = "race"
	# The cup is Tirana's, whatever city the race page shows.
	race_opts.city = Progress.HOME_CITY
	goto("race")


## A race setting, from the cup event being played or from the player's choice.
func race_setting(key: String) -> Variant:
	var event := Data.cup_event(str(race_opts.event))
	if not event.is_empty() and event.has(key):
		return event[key]
	return race_opts[key]


## True while an online race is on (this phone's or the background one).
func is_online() -> bool:
	return net != null and net.started


## Starts the online race everyone in the lobby agreed on: the host's settings
## become this phone's race options for the scene.
func start_online() -> void:
	if net == null or not net.started:
		return
	var c := net.config
	race_opts.event = ""
	race_opts.mode = "race"
	race_opts.city = str(c.get("city", "tirane"))
	race_opts.laps = int(c.get("laps", 0))
	race_opts.diff = int(c.get("diff", 1))
	race_opts.env = str(c.get("env", "day"))
	race_opts.reverse = bool(c.get("reverse", false))
	goto("race")


## The scene is done with its online race (results up): keep stepping it
## with empty input until every human has finished, the session closes or
## four minutes pass, then leave the session.
func keep_net_race(net_race: NetRace) -> void:
	_net_tail = net_race
	_net_tail_ticks = 0


## Leaves any online session now.
func leave_online() -> void:
	_net_tail = null
	if net != null:
		net.close()
		net = null


func _step_net_tail() -> void:
	if _net_tail == null or net == null:
		return
	var closed := false
	for e in net.poll():
		closed = closed or e.t == "closed"
	var empty := CarState.Ctrl.new().pack([])
	for k in 4:
		if not _net_tail.step(empty):
			break
		_net_tail_ticks += 1
	var all_done := _net_tail.race.humans.all(func(c: CarState) -> bool: return c.finished or not c.is_player)
	if closed or all_done or _net_tail_ticks > NET_TAIL_MAX_TICKS:
		leave_online()


func start_race() -> void:
	if not str(race_opts.event).is_empty():
		start_event(str(race_opts.event))
		return
	Settings.city_id = race_opts.city
	Settings.car_id = race_opts.car
	Settings.difficulty = race_opts.diff
	Settings.env_override = race_opts.env
	Settings.laps_override = race_opts.laps
	Settings.reverse_lap = bool(race_opts.reverse)
	Settings.save()
	goto("arena" if str(race_opts.mode) == "points" else "race")


func finish_race(result: Dictionary) -> void:
	last_result = result
	if str(result.get("mode", "race")) == "points":
		goto("results")
		return
	# The fans a race earned are the player's to keep; the results page counts
	# them up from what the player had before.
	var earned := maxi(0, int(result.get("fans", 0)))
	result["fans"] = earned
	result["fans_before"] = Progress.fans
	Progress.add_fans(earned)
	result["fans_total"] = Progress.fans
	var event := Data.cup_event(str(result.get("event", "")))
	if not event.is_empty():
		result["stars"] = Data.cup_stars(event, result)
		result["stars_before"] = Progress.stars(event.id)
		result["goal_met"] = Data.cup_goal_met(event, result)
		Progress.set_stars(event.id, int(result.stars))
		result["cities_unlocked"] = Progress.unlock_earned_cities().filter(func(id: String): return Data.city_available(id))
	Settings.record_result(result.get("city", ""), int(result.get("place", 6)), float(result.get("best_lap", INF)))
	goto("results")


func city_env(city_id: String) -> String:
	if str(race_setting("env")) != "":
		return str(race_setting("env"))
	return Data.city(city_id).env


func city_laps(city_id: String) -> int:
	if int(race_setting("laps")) > 0:
		return int(race_setting("laps"))
	return int(Data.city(city_id).laps)


static func fmt_time(t: float) -> String:
	if t == INF or t < 0.0:
		return "--:--.---"
	var m := int(t / 60.0)
	var s := t - m * 60.0
	return "%d:%06.3f" % [m, s]
