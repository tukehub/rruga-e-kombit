extends Node
## Central game data: cities, cars, power-ups, drivers, difficulty.
## Everything race-balance related lives here or in sim/race.gd so a new car
## or city is a data change only. Text the player reads is not here: it lives
## in strings_sq.gd under keys built from these ids ("pw.eagle.name",
## "city.tirane.name", "env.day") and is read through t().

const GAME_NAME := "Vortex"
const CAR_MODEL := GAME_NAME + " GT"
const Strings := preload("res://scripts/data/strings_sq.gd")

## The active language's table (plan 9.2 swaps it for another language).
var strings: Dictionary = Strings.T

# ---------------------------------------------------------------- environments
# Lighting/weather presets. sun_dir points *towards* the sun (Godot world space,
# x east, z south). Colours are sRGB hex. Fog in metres. Every city has a
# default env; the player can override weather/time in the race setup.
const ENV := {
	"night": {"icon": "☾", "sun_dir": Vector3(0.35, 0.55, -0.45), "sun_col": "#8ea6ff", "sun_i": 0.35,
		"sky_top": "#02030a", "sky_hor": "#1d1538", "ground": "#0a0810", "ambient": 0.35, "fog": "#120e22", "fog_density": 0.0028,
		"win": 1.0, "lamps": true, "stars": true, "moon": true, "exposure": 1.1, "bloom": 1.05, "wet": false, "rain": false, "snow": false},
	"dusk": {"icon": "◐", "sun_dir": Vector3(-0.75, 0.12, 0.4), "sun_col": "#ff9a6a", "sun_i": 1.2,
		"sky_top": "#121842", "sky_hor": "#e06c5a", "ground": "#2a1e22", "ambient": 0.45, "fog": "#4e3150", "fog_density": 0.0022,
		"win": 0.85, "lamps": true, "stars": true, "moon": false, "exposure": 1.05, "bloom": 0.9, "wet": false, "rain": false, "snow": false},
	"sunset": {"icon": "◒", "sun_dir": Vector3(0.8, 0.14, -0.3), "sun_col": "#ffb26e", "sun_i": 2.0,
		"sky_top": "#22336e", "sky_hor": "#ffaa62", "ground": "#3a2c26", "ambient": 0.5, "fog": "#c98a6a", "fog_density": 0.0016,
		"win": 0.5, "lamps": true, "stars": false, "moon": false, "exposure": 1.0, "bloom": 0.75, "wet": false, "rain": false, "snow": false},
	"day": {"icon": "☀", "sun_dir": Vector3(0.4, 0.85, 0.3), "sun_col": "#fff4dc", "sun_i": 2.6,
		"sky_top": "#3e7fd8", "sky_hor": "#c4e2f4", "ground": "#6c6a52", "ambient": 0.5, "fog": "#c6def0", "fog_density": 0.0010,
		"win": 0.0, "lamps": false, "stars": false, "moon": false, "exposure": 0.90, "bloom": 0.25, "wet": false, "rain": false, "snow": false},
	"golden": {"icon": "☀", "sun_dir": Vector3(-0.6, 0.33, 0.5), "sun_col": "#ffd6a0", "sun_i": 2.4,
		"sky_top": "#3a78c8", "sky_hor": "#f4d0a0", "ground": "#5c5240", "ambient": 0.55, "fog": "#dcc29a", "fog_density": 0.0012,
		"win": 0.1, "lamps": false, "stars": false, "moon": false, "exposure": 0.95, "bloom": 0.5, "wet": false, "rain": false, "snow": false},
	"rain": {"icon": "☂", "sun_dir": Vector3(0.3, 0.8, 0.2), "sun_col": "#9fb0c8", "sun_i": 0.3,
		"sky_top": "#07090f", "sky_hor": "#262e3c", "ground": "#101214", "ambient": 0.55, "fog": "#181d27", "fog_density": 0.0045,
		"win": 1.0, "lamps": true, "stars": false, "moon": false, "exposure": 1.15, "bloom": 1.05, "wet": true, "rain": true, "snow": false},
	"rainy": {"icon": "☂", "sun_dir": Vector3(0.3, 0.8, 0.2), "sun_col": "#cdd5df", "sun_i": 0.65,
		"sky_top": "#5a6472", "sky_hor": "#9aa3ad", "ground": "#3c4046", "ambient": 0.55, "fog": "#8e98a4", "fog_density": 0.0060,
		"win": 0.0, "lamps": false, "stars": false, "moon": false, "exposure": 0.85, "bloom": 0.15, "wet": true, "rain": true, "snow": false, "dark": false},
	"snow": {"icon": "❄", "sun_dir": Vector3(-0.5, 0.3, 0.6), "sun_col": "#ffd8b8", "sun_i": 0.9,
		"sky_top": "#161d33", "sky_hor": "#5e6584", "ground": "#4a4e5a", "ambient": 0.6, "fog": "#3e445c", "fog_density": 0.0040,
		"win": 0.95, "lamps": true, "stars": false, "moon": false, "exposure": 1.1, "bloom": 0.95, "wet": true, "rain": false, "snow": true},
}
const ENV_ORDER := ["night", "dusk", "sunset", "day", "golden", "rainy", "rain", "snow"]

# ---------------------------------------------------------------- cities
# Track geometry comes from assets/cities/<id>/ (built by tools/pipeline).
# horizon: "flat" | "mountains" | "sea" picks the HDRI family and far terrain treatment.
const CITIES := [
	{"id": "tirane", "env": "day", "laps": 2, "neon": "#ff2d6f", "horizon": "flat", "hdri": "day"},
	{"id": "vlore", "env": "sunset", "laps": 2, "neon": "#ffd23a", "horizon": "sea", "hdri": "sunset"},
	{"id": "berat", "env": "dusk", "laps": 2, "neon": "#ffb347", "horizon": "mountains", "hdri": "dusk"},
	{"id": "gjirokaster", "env": "rain", "laps": 2, "neon": "#3d9dff", "horizon": "mountains", "hdri": "rain"},
	{"id": "shkoder", "env": "golden", "laps": 2, "neon": "#4ee0ff", "horizon": "mountains", "hdri": "golden"},
	{"id": "tetove", "env": "day", "laps": 2, "neon": "#ff5fc8", "horizon": "mountains", "hdri": "day"},
]

# ---------------------------------------------------------------- cars
# One contemporary Vortex GT, six paint choices, identical performance.
# Legacy IDs remain stable for saved selections. Shared GLB nodes include
# body/glass/lights/wheel_fl/wheel_fr/wheel_rl/wheel_rr.
const CARS := [
	{"id": "benxi", "kind": "coupe", "vmax": 58.0, "acc": 8.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#e63138",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36},
	{"id": "uragani", "kind": "coupe", "vmax": 58.0, "acc": 8.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#246be8",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36},
	{"id": "kercyesi", "kind": "coupe", "vmax": 58.0, "acc": 8.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#e9eff5",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36},
	{"id": "shigjeta", "kind": "coupe", "vmax": 58.0, "acc": 8.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#536476",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36},
	{"id": "gelendvagen", "kind": "coupe", "vmax": 58.0, "acc": 8.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#f6c82a",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36},
	{"id": "sprinteri", "kind": "coupe", "vmax": 58.0, "acc": 8.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#26b69b",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36},
]
const PAINTS := ["#e41e20", "#26262c", "#f1eee8", "#f2c230", "#2a6fdb", "#3f6d3b", "#ff6a1a", "#8e44ad"]

# ---------------------------------------------------------------- power-ups
const PW := {
	"eagle": {"col": "#ff2b2b", "w": 15, "ammo": 1},
	"bolt": {"col": "#3aa8ff", "w": 16, "ammo": 3},
	"barge": {"col": "#b45cff", "w": 12, "ammo": 1},
	"mine": {"col": "#ff8c1a", "w": 14, "ammo": 1},
	"shock": {"col": "#ffe03a", "w": 7, "ammo": 1},
	"nitro": {"col": "#38ff6a", "w": 17, "ammo": 1},
	"shield": {"col": "#dfe9ff", "w": 10, "ammo": 1},
	"repair": {"col": "#ff5fc8", "w": 9, "ammo": 1},
}
# Points mode only: used on the car itself. Not in PW_KEYS, so no race offers it.
const ARENA_PW := {
	"ram": {"col": "#ff3d9a", "ammo": 1},
}
const PW_KEYS := ["eagle", "bolt", "barge", "mine", "shock", "nitro", "shield", "repair"]

# ---------------------------------------------------------------- drivers
# Six drivers: the player is one, the other five drive the bots. Their names
# are proper names, the same in every language; the tag lines are text
# ("driver.<index>.tag").
const DRIVERS := [
	{"name": "Artur", "col": "#ff2a3d"},
	{"name": "Ritvan", "col": "#1fb6ff"},
	{"name": "Desantin", "col": "#ffc21a"},
	{"name": "Eno", "col": "#2bff88"},
	{"name": "Erlin", "col": "#c46bff"},
	{"name": "Flori", "col": "#19e6c1"},
]

# Opponents have their own names so changing the AI lineup never changes the
# player's saved driver selection or the name displayed for that selection.
const RIVAL_NAMES := ["Arben", "Dritan", "Luan", "Bora", "Era", "Valon"]

# Rival difficulty. `speed`, `react` and `aim` set how good the bots are.
# The rest is the rubber band, applied to bots only, as fractions of top speed:
# `catch_up` is the most a bot behind the player gains and `lead_drag` the
# most a bot ahead of the player loses, both reached `band` metres away;
# `runaway_drag` is the most a leading bot loses once it is more than
# `runaway_gap` metres clear of second place (full at twice that gap).
const DIFFS := [
	{"id": 0, "speed": 0.87, "react": 1.3, "aim": 0.55,
		"catch_up": 0.06, "lead_drag": 0.05, "band": 60.0, "runaway_gap": 60.0, "runaway_drag": 0.04},
	{"id": 1, "speed": 0.935, "react": 0.9, "aim": 0.8,
		"catch_up": 0.045, "lead_drag": 0.03, "band": 80.0, "runaway_gap": 90.0, "runaway_drag": 0.03},
	{"id": 2, "speed": 1.035, "react": 0.55, "aim": 1.0,
		"catch_up": 0.03, "lead_drag": 0.015, "band": 100.0, "runaway_gap": 120.0, "runaway_drag": 0.02},
]

# Handling difficulty, separate from the rivals' difficulty above. Each value
# scales one driver aid in `Race`: `assist` the steering self-centring,
# `brake_assist` the automatic speed trim before bends (when that aid is on),
# `drift_grip` the extra grip a drift gives. Arcade is 1.0 throughout.
const HANDLING_DEFAULT := "arcade"
const HANDLING := {
	"arcade": {"assist": 1.0, "brake_assist": 1.0, "drift_grip": 1.0},
	"pro": {"assist": 0.7, "brake_assist": 0.5, "drift_grip": 0.5},
}

# Traffic and hazards: how many parked and slow-moving cars a race places, by
# quality preset (each one is a drawn car). They are part of the simulation,
# so every peer of an online race must use the same pair.
const TRAFFIC := {
	"low": {"parked": 3, "moving": 1},
	"medium": {"parked": 5, "moving": 2},
	"high": {"parked": 8, "moving": 3},
}
# Heavier and far slower than a race car; same body, so the same footprint.
const TRAFFIC_CAR := {"id": "traffic", "kind": "coupe", "vmax": 15.0, "acc": 3.0, "grip": 1.0, "hp": 115.0, "mass": 1.6, "color": "#8a8f96",
	"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36}
const TRAFFIC_COLORS := ["#8a8f96", "#c9c4b8", "#3d4750", "#6f7f8c", "#a8a39a", "#525a52"]


func traffic(preset: String) -> Dictionary:
	return TRAFFIC[preset] if TRAFFIC.has(preset) else TRAFFIC.medium


## Colour of any pickup, from a race or from the points mode.
func pw_col(type: String) -> Color:
	if PW.has(type):
		return Color.html(PW[type].col)
	if ARENA_PW.has(type):
		return Color.html(ARENA_PW[type].col)
	return Color.WHITE


func has_pw(type: String) -> bool:
	return PW.has(type) or ARENA_PW.has(type)


func handling_id(id: String) -> String:
	return id if HANDLING.has(id) else HANDLING_DEFAULT


func city(id: String) -> Dictionary:
	for c in CITIES:
		if c.id == id:
			return c
	return CITIES[0]


func car(id: String) -> Dictionary:
	for c in CARS:
		if c.id == id:
			return c
	return CARS[0]


func car_index(id: String) -> int:
	for i in CARS.size():
		if CARS[i].id == id:
			return i
	return 0


func has_text(key: String) -> bool:
	return strings.has(key)


## The text for a key; args fill its "%s" / "%d" placeholders. Pass the key
## as a literal first argument so tests/string_table can follow it.
func t(key: String, args: Variant = null) -> String:
	var text: Variant = strings.get(key)
	if not (text is String):
		push_error("No text for key: " + key)
		return key
	return text if args == null else text % args


## A list of texts (facts, ordinals, ...). Read-only: duplicate before changing.
func t_list(key: String) -> Array:
	var list: Variant = strings.get(key)
	if not (list is Array):
		push_error("No text list for key: " + key)
		return []
	return list


func env_label(id: String) -> String:
	return t("env.%s" % id)


func city_name(id: String) -> String:
	return t("city.%s.name" % id)


func car_name(id: String) -> String:
	return t("car.%s.name" % id)


func pw_name(type: String) -> String:
	return t("pw.%s.name" % type)


func pw_desc(type: String) -> String:
	return t("pw.%s.desc" % type)


## "I PARI", "I DYTI", ... for a finishing place counted from 1.
func ordinal(place: int) -> String:
	var names := t_list("results.ordinal")
	return names[clampi(place - 1, 0, names.size() - 1)]


func place_msg(place: int, n: int) -> String:
	var messages := t_list("results.place_msg")
	return messages[messages.size() - 1 if place >= n else clampi(place - 1, 0, messages.size() - 1)]


## Rivals of driver index pi (all when pi < 0), shuffled with the given RNG.
func rivals_of(pi: int, rng: RandomNumberGenerator) -> Array:
	var b := []
	for i in DRIVERS.size():
		if i != pi:
			var rival: Dictionary = DRIVERS[i].duplicate()
			rival.name = RIVAL_NAMES[i]
			b.append(rival)
	for i in range(b.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = b[i]
		b[i] = b[j]
		b[j] = t
	return b


static func col(hex: String) -> Color:
	return Color.html(hex)
