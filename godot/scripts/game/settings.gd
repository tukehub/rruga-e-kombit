extends Node
## Persistent player settings (user://settings.cfg).

signal changed

const PATH := "user://settings.cfg"
const PRESENTATION_VERSION := 1

# tilt sensitivity: index into TILT_FULL (degrees for full steer)
const TILT_FULL := [32.0, 23.0, 15.0]
const TILT_LABELS := ["E ulët", "Normale", "E lartë"]

var tilt_sens := 1
var tilt_invert := false
var touch_steer := true         # visible touch pad; tilt remains selectable
var assist := true
var difficulty := 1
var dynamic_weather := false
var haptics := true
var quality := "auto"           # "auto" | "low" | "medium" | "high"
var vol_master := 1.0
var vol_engine := 0.8
var vol_tyres := 0.7
var vol_impacts := 1.0
var vol_pickups := 0.9
var vol_ui := 0.8
var show_fps := false
var mirror := false            # rear-view mirror: a second scene render
var car_id := "benxi"
var driver := 0
var city_id := "tirane"
var env_override := "day"       # daylight for the focused Tirana build
var presentation_version := 0
var laps_override := 0          # 0 = city default
var reverse_lap := false
var first_run := true
var stats := {"races": 0, "wins": 0, "podiums": 0, "best_laps": {}}
var seen_pws: Array = []        # power-up ids whose one-time tip was shown


func seen_pw(type: String) -> bool:
	return seen_pws.has(type)


func mark_pw(type: String) -> void:
	if not seen_pws.has(type):
		seen_pws.append(type)


func _ready() -> void:
	load_settings()
	# Apply the readability pass once to existing installs, including saved night
	# and weather choices. Subsequent player settings remain persistent.
	if presentation_version < PRESENTATION_VERSION:
		city_id = "tirane"
		env_override = "day"
		dynamic_weather = false
		touch_steer = true
		presentation_version = PRESENTATION_VERSION
		save()


func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	tilt_sens = cf.get_value("input", "tilt_sens", tilt_sens)
	tilt_invert = cf.get_value("input", "tilt_invert", tilt_invert)
	touch_steer = cf.get_value("input", "touch_steer", touch_steer)
	assist = cf.get_value("game", "assist", assist)
	difficulty = cf.get_value("game", "difficulty", difficulty)
	haptics = cf.get_value("game", "haptics", haptics)
	dynamic_weather = cf.get_value("game", "dynamic_weather", dynamic_weather)
	quality = cf.get_value("video", "quality", quality)
	show_fps = cf.get_value("video", "show_fps", show_fps)
	mirror = bool(cf.get_value("video", "mirror", mirror))
	vol_master = cf.get_value("audio", "master", vol_master)
	vol_engine = cf.get_value("audio", "engine", vol_engine)
	vol_tyres = cf.get_value("audio", "tyres", vol_tyres)
	vol_impacts = cf.get_value("audio", "impacts", vol_impacts)
	vol_pickups = cf.get_value("audio", "pickups", vol_pickups)
	vol_ui = cf.get_value("audio", "ui", vol_ui)
	car_id = cf.get_value("race", "car", car_id)
	driver = cf.get_value("race", "driver", driver)
	city_id = cf.get_value("race", "city", city_id)
	env_override = cf.get_value("race", "env", env_override)
	laps_override = cf.get_value("race", "laps", laps_override)
	reverse_lap = bool(cf.get_value("race", "reverse", reverse_lap))
	first_run = cf.get_value("meta", "first_run", first_run)
	stats = cf.get_value("meta", "stats", stats)
	seen_pws = cf.get_value("meta", "seen_pws", seen_pws)
	presentation_version = cf.get_value("meta", "presentation_version", 0)


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("input", "tilt_sens", tilt_sens)
	cf.set_value("input", "tilt_invert", tilt_invert)
	cf.set_value("input", "touch_steer", touch_steer)
	cf.set_value("game", "assist", assist)
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "haptics", haptics)
	cf.set_value("game", "dynamic_weather", dynamic_weather)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("video", "mirror", mirror)
	cf.set_value("audio", "master", vol_master)
	cf.set_value("audio", "engine", vol_engine)
	cf.set_value("audio", "tyres", vol_tyres)
	cf.set_value("audio", "impacts", vol_impacts)
	cf.set_value("audio", "pickups", vol_pickups)
	cf.set_value("audio", "ui", vol_ui)
	cf.set_value("race", "car", car_id)
	cf.set_value("race", "driver", driver)
	cf.set_value("race", "city", city_id)
	cf.set_value("race", "env", env_override)
	cf.set_value("race", "laps", laps_override)
	cf.set_value("race", "reverse", reverse_lap)
	cf.set_value("meta", "first_run", first_run)
	cf.set_value("meta", "stats", stats)
	cf.set_value("meta", "seen_pws", seen_pws)
	cf.set_value("meta", "presentation_version", presentation_version)
	cf.save(PATH)
	changed.emit()


func record_result(city: String, place: int, best_lap: float) -> void:
	stats.races = int(stats.races) + 1
	if place == 1:
		stats.wins = int(stats.wins) + 1
	if place <= 3:
		stats.podiums = int(stats.podiums) + 1
	var bl: Dictionary = stats.best_laps
	if best_lap < INF and (not bl.has(city) or best_lap < float(bl[city])):
		bl[city] = best_lap
	save()
