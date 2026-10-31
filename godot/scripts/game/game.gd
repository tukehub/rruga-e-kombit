extends Node
## Scene flow: menu -> race -> results. Holds the options for the next race
## and the result of the last one.

signal scene_changed(name: String)

const SCENES := {
	"menu": "res://scenes/menu.tscn",
	"race": "res://scenes/race.tscn",
	"results": "res://scenes/results.tscn",
}

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
	for c in _root.get_children():
		c.queue_free()
	await get_tree().process_frame
	var ps: PackedScene = load(SCENES[name])
	var inst := ps.instantiate()
	_root.add_child(inst)
	current = name
	_loading = false
	scene_changed.emit(name)


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
