extends Node
## Persistent player settings (user://settings.cfg).

signal changed

const PATH := "user://settings.cfg"
const PRESENTATION_VERSION := 1
# Version of the file layout. 1 added `handling`; an older file predates the
# choice and keeps the arcade handling it always had. 2 added the rim and
# livery the player drives with; older files start with the free ones. 3 added
# the announcer switch and its level; older files start with it on, full. 4
# added names the player gives the drivers; older files keep the defaults.
const VERSION := 4
## Longest name a driver can be given (fits the standings and name cards).
const NAME_MAX := 14

# tilt sensitivity: index into TILT_FULL (degrees for full steer)
const TILT_FULL := [32.0, 23.0, 15.0]
const CONTROL_SCALES := [0.9, 1.0, 1.15]
const TOUCH_TRAVEL := [125.0, 100.0, 75.0]

var tilt_sens := 1
var tilt_invert := false
var touch_steer := true         # visible touch pad; tilt remains selectable
var auto_accel := true
var left_handed := false
var touch_sens := 1
var control_size := 1
var control_opacity := 0.9
var control_offset_x := 0.0
var control_offset_y := 0.0
var tilt_center := 0.0          # neutral sensor angle, before inversion
var assist := true
var handling := "arcade"        # id in Data.HANDLING: "arcade" | "pro"
var difficulty := 1
var dynamic_weather := false
var haptics := true
var announcer := true
var quality := "auto"           # "auto" | "low" | "medium" | "high"
var frame_target := 60          # rendering only; simulation stays at60Hz
var adaptive_quality := true
var vol_master := 1.0
var vol_engine := 0.8
var vol_tyres := 0.7
var vol_impacts := 1.0
var vol_pickups := 0.9
var vol_ui := 0.8
var vol_music := 0.7
var vol_voice := 1.0
var show_fps := false
var mirror := false            # rear-view mirror: a second scene render
var car_id := "benxi"
var rim_id := "silver"          # Data.RIMS; owned ones only, see Game.cosmetics()
var livery_id := "none"         # Data.LIVERIES
var driver := 0
var driver_names := {}        # driver index (String) -> the player's name for them
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


func load_settings(path := PATH) -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	var file_version := int(cf.get_value("meta", "version", 0))
	var input_values := {}
	for key in input_config():
		input_values[key] = cf.get_value("input", key, get(key))
	load_input_config(input_values)
	assist = cf.get_value("game", "assist", assist)
	handling = Data.HANDLING_DEFAULT if file_version < 1 else Data.handling_id(str(cf.get_value("game", "handling", handling)))
	difficulty = cf.get_value("game", "difficulty", difficulty)
	haptics = cf.get_value("game", "haptics", haptics)
	if file_version >= 3:
		announcer = bool(cf.get_value("game", "announcer", announcer))
		vol_voice = clampf(float(cf.get_value("audio", "voice", vol_voice)), 0.0, 1.0)
	dynamic_weather = cf.get_value("game", "dynamic_weather", dynamic_weather)
	quality = cf.get_value("video", "quality", quality)
	frame_target = 30 if int(cf.get_value("video", "frame_target", frame_target)) == 30 else 60
	adaptive_quality = bool(cf.get_value("video", "adaptive_quality", adaptive_quality))
	show_fps = cf.get_value("video", "show_fps", show_fps)
	mirror = bool(cf.get_value("video", "mirror", mirror))
	vol_master = cf.get_value("audio", "master", vol_master)
	vol_engine = cf.get_value("audio", "engine", vol_engine)
	vol_tyres = cf.get_value("audio", "tyres", vol_tyres)
	vol_impacts = cf.get_value("audio", "impacts", vol_impacts)
	vol_pickups = cf.get_value("audio", "pickups", vol_pickups)
	vol_ui = cf.get_value("audio", "ui", vol_ui)
	vol_music = clampf(float(cf.get_value("audio", "music", vol_music)), 0.0, 1.0)
	car_id = cf.get_value("race", "car", car_id)
	if file_version >= 2:
		rim_id = str(cf.get_value("race", "rim", rim_id))
		livery_id = str(cf.get_value("race", "livery", livery_id))
	driver = cf.get_value("race", "driver", driver)
	driver_names = {}
	if file_version >= 4:
		var names = cf.get_value("race", "driver_names", {})
		if names is Dictionary:
			for k in names:
				set_driver_name(int(k), str(names[k]))
	city_id = cf.get_value("race", "city", city_id)
	env_override = cf.get_value("race", "env", env_override)
	laps_override = cf.get_value("race", "laps", laps_override)
	reverse_lap = bool(cf.get_value("race", "reverse", reverse_lap))
	first_run = cf.get_value("meta", "first_run", first_run)
	stats = cf.get_value("meta", "stats", stats)
	seen_pws = cf.get_value("meta", "seen_pws", seen_pws)
	presentation_version = cf.get_value("meta", "presentation_version", 0)


func save(path := PATH) -> void:
	var cf := ConfigFile.new()
	for key in input_config():
		cf.set_value("input", key, get(key))
	cf.set_value("game", "assist", assist)
	cf.set_value("game", "handling", Data.handling_id(handling))
	cf.set_value("game", "difficulty", difficulty)
	cf.set_value("game", "haptics", haptics)
	cf.set_value("game", "announcer", announcer)
	cf.set_value("game", "dynamic_weather", dynamic_weather)
	cf.set_value("video", "quality", quality)
	cf.set_value("video", "frame_target", frame_target)
	cf.set_value("video", "adaptive_quality", adaptive_quality)
	cf.set_value("video", "show_fps", show_fps)
	cf.set_value("video", "mirror", mirror)
	cf.set_value("audio", "master", vol_master)
	cf.set_value("audio", "engine", vol_engine)
	cf.set_value("audio", "tyres", vol_tyres)
	cf.set_value("audio", "impacts", vol_impacts)
	cf.set_value("audio", "pickups", vol_pickups)
	cf.set_value("audio", "ui", vol_ui)
	cf.set_value("audio", "music", vol_music)
	cf.set_value("audio", "voice", vol_voice)
	cf.set_value("race", "car", car_id)
	cf.set_value("race", "rim", rim_id)
	cf.set_value("race", "livery", livery_id)
	cf.set_value("race", "driver", driver)
	cf.set_value("race", "driver_names", driver_names)
	cf.set_value("race", "city", city_id)
	cf.set_value("race", "env", env_override)
	cf.set_value("race", "laps", laps_override)
	cf.set_value("race", "reverse", reverse_lap)
	cf.set_value("meta", "first_run", first_run)
	cf.set_value("meta", "stats", stats)
	cf.set_value("meta", "seen_pws", seen_pws)
	cf.set_value("meta", "presentation_version", presentation_version)
	cf.set_value("meta", "version", VERSION)
	cf.save(path)
	changed.emit()


## Shared by persistence, live layout changes and the pause settings panel.
## A typed name made safe: printable characters only, spaces collapsed, at
## most NAME_MAX characters.
static func clean_name(text: String) -> String:
	var out := ""
	for ch in text.strip_edges():
		var code := ch.unicode_at(0)
		if code < 32 or code == 127:
			continue
		if ch == " " and out.ends_with(" "):
			continue
		out += ch
	return out.strip_edges().left(NAME_MAX).strip_edges()


## The name driver `index` races under: the player's, or the default.
func driver_name(index: int) -> String:
	var i := clampi(index, 0, Data.DRIVERS.size() - 1)
	return str(driver_names.get(str(i), Data.DRIVERS[i].name))


## Renames driver `index`; an empty name or the default restores the default.
func set_driver_name(index: int, text: String) -> void:
	if index < 0 or index >= Data.DRIVERS.size():
		return
	var name := clean_name(text)
	if name.is_empty() or name == str(Data.DRIVERS[index].name):
		driver_names.erase(str(index))
	else:
		driver_names[str(index)] = name


func input_config() -> Dictionary:
	var values := {}
	for key in ["tilt_sens", "tilt_invert", "touch_steer", "auto_accel", "left_handed", "touch_sens", "control_size", "control_opacity", "control_offset_x", "control_offset_y", "tilt_center"]:
		values[key] = get(key)
	return values


func load_input_config(values: Dictionary) -> void:
	for key in ["tilt_invert", "touch_steer", "auto_accel", "left_handed"]:
		set(key, bool(values.get(key, get(key))))
	for key in ["tilt_sens", "touch_sens", "control_size"]:
		set(key, clampi(int(values.get(key, get(key))), 0, 2))
	for key in ["control_opacity", "control_offset_x", "control_offset_y", "tilt_center"]:
		var value := float(values.get(key, get(key)))
		if not is_finite(value):
			value = float(get(key))
		var lower := 0.45 if key == "control_opacity" else (-PI * 0.5 if key == "tilt_center" else 0.0)
		var upper := PI * 0.5 if key == "tilt_center" else 1.0
		set(key, clampf(value, lower, upper))


func reset_control_layout() -> void:
	left_handed = false
	control_size = 1
	control_opacity = 0.9
	control_offset_x = 0.0
	control_offset_y = 0.0


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
