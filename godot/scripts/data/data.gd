extends Node
## Central game data: cities, cars, power-ups, drivers, difficulty, copy.
## Everything race-balance related lives here or in sim/race.gd so a new car
## or city is a data change only.

const GAME_NAME := "Vortex"

# ---------------------------------------------------------------- environments
# Lighting/weather presets. sun_dir points *towards* the sun (Godot world space,
# x east, z south). Colours are sRGB hex. Fog in metres. Every city has a
# default env; the player can override weather/time in the race setup.
const ENV := {
	"night": {"label": "Natë", "icon": "☾", "sun_dir": Vector3(0.35, 0.55, -0.45), "sun_col": "#8ea6ff", "sun_i": 0.35,
		"sky_top": "#02030a", "sky_hor": "#1d1538", "ground": "#0a0810", "ambient": 0.35, "fog": "#120e22", "fog_density": 0.0028,
		"win": 1.0, "lamps": true, "stars": true, "moon": true, "exposure": 1.1, "bloom": 1.05, "wet": false, "rain": false, "snow": false},
	"dusk": {"label": "Muzg", "icon": "◐", "sun_dir": Vector3(-0.75, 0.12, 0.4), "sun_col": "#ff9a6a", "sun_i": 1.2,
		"sky_top": "#121842", "sky_hor": "#e06c5a", "ground": "#2a1e22", "ambient": 0.45, "fog": "#4e3150", "fog_density": 0.0022,
		"win": 0.85, "lamps": true, "stars": true, "moon": false, "exposure": 1.05, "bloom": 0.9, "wet": false, "rain": false, "snow": false},
	"sunset": {"label": "Perëndim", "icon": "◒", "sun_dir": Vector3(0.8, 0.14, -0.3), "sun_col": "#ffb26e", "sun_i": 2.0,
		"sky_top": "#22336e", "sky_hor": "#ffaa62", "ground": "#3a2c26", "ambient": 0.5, "fog": "#c98a6a", "fog_density": 0.0016,
		"win": 0.5, "lamps": true, "stars": false, "moon": false, "exposure": 1.0, "bloom": 0.75, "wet": false, "rain": false, "snow": false},
	"day": {"label": "Ditë", "icon": "☀", "sun_dir": Vector3(0.4, 0.85, 0.3), "sun_col": "#fff4dc", "sun_i": 2.6,
		"sky_top": "#3e7fd8", "sky_hor": "#c4e2f4", "ground": "#6c6a52", "ambient": 0.6, "fog": "#c6def0", "fog_density": 0.0010,
		"win": 0.0, "lamps": false, "stars": false, "moon": false, "exposure": 0.95, "bloom": 0.45, "wet": false, "rain": false, "snow": false},
	"golden": {"label": "Pasdite", "icon": "☀", "sun_dir": Vector3(-0.6, 0.33, 0.5), "sun_col": "#ffd6a0", "sun_i": 2.4,
		"sky_top": "#3a78c8", "sky_hor": "#f4d0a0", "ground": "#5c5240", "ambient": 0.55, "fog": "#dcc29a", "fog_density": 0.0012,
		"win": 0.1, "lamps": false, "stars": false, "moon": false, "exposure": 0.95, "bloom": 0.5, "wet": false, "rain": false, "snow": false},
	"rain": {"label": "Shi natën", "icon": "☂", "sun_dir": Vector3(0.3, 0.8, 0.2), "sun_col": "#9fb0c8", "sun_i": 0.3,
		"sky_top": "#07090f", "sky_hor": "#262e3c", "ground": "#101214", "ambient": 0.55, "fog": "#181d27", "fog_density": 0.0045,
		"win": 1.0, "lamps": true, "stars": false, "moon": false, "exposure": 1.15, "bloom": 1.05, "wet": true, "rain": true, "snow": false},
	"snow": {"label": "Borë", "icon": "❄", "sun_dir": Vector3(-0.5, 0.3, 0.6), "sun_col": "#ffd8b8", "sun_i": 0.9,
		"sky_top": "#161d33", "sky_hor": "#5e6584", "ground": "#4a4e5a", "ambient": 0.6, "fog": "#3e445c", "fog_density": 0.0040,
		"win": 0.95, "lamps": true, "stars": false, "moon": false, "exposure": 1.1, "bloom": 0.95, "wet": true, "rain": false, "snow": true},
}
const ENV_ORDER := ["night", "dusk", "sunset", "day", "golden", "rain", "snow"]

# ---------------------------------------------------------------- cities
# Track geometry comes from assets/cities/<id>/ (built by tools/pipeline).
# horizon: "flat" | "mountains" | "sea" picks the HDRI family and far terrain treatment.
const CITIES := [
	{"id": "tirane", "name": "Tiranë", "region": "Shqipëri", "env": "day", "laps": 2, "neon": "#ff2d6f", "horizon": "flat",
		"hdri": "day", "blurb": "Bulevardi në dritën e ditës: pallate me ngjyra dhe Piramida në krah.",
		"landmarks": ["Sheshi Skënderbej", "Piramida", "Blloku", "Sheshi Nënë Tereza"]},
	{"id": "vlore", "name": "Vlorë", "region": "Shqipëri", "env": "sunset", "laps": 2, "neon": "#ffd23a", "horizon": "sea",
		"hdri": "sunset", "blurb": "Këtu lindi shteti. Lungomare, det dhe perëndim.",
		"landmarks": ["Monumenti i Pavarësisë", "Lungomare"]},
	{"id": "berat", "name": "Berat", "region": "Shqipëri", "env": "dusk", "laps": 2, "neon": "#ffb347", "horizon": "mountains",
		"hdri": "dusk", "blurb": "Qyteti i një mbi një dritareve. Të gjitha të shohin kur humb.",
		"landmarks": ["Kalaja", "Mangalemi", "Gorica"]},
	{"id": "gjirokaster", "name": "Gjirokastër", "region": "Shqipëri", "env": "rain", "laps": 2, "neon": "#3d9dff", "horizon": "mountains",
		"hdri": "rain", "blurb": "Gurë, shi dhe kthesa. Qyteti i gurtë nuk fal.",
		"landmarks": ["Kalaja", "Çatitë e gurta"]},
	{"id": "shkoder", "name": "Shkodër", "region": "Shqipëri", "env": "golden", "laps": 2, "neon": "#4ee0ff", "horizon": "mountains",
		"hdri": "golden", "blurb": "Liqeni, Rozafa dhe një mijë biçikleta që s’të lënë rrugë.",
		"landmarks": ["Kalaja e Rozafës", "Liqeni i Shkodrës"]},
	{"id": "tetove", "name": "Tetovë", "region": "Maqedoni e Veriut", "env": "day", "laps": 2, "neon": "#ff5fc8", "horizon": "mountains",
		"hdri": "day", "blurb": "Xhamia e Larme, Sharri me borë dhe kthesa që s’mbarojnë.",
		"landmarks": ["Xhamia e Larme", "Mali Sharr"]},
]

# ---------------------------------------------------------------- cars
# One contemporary Vortex GT, six paint choices, identical performance.
# Legacy IDs remain stable for saved selections. Shared GLB nodes include
# body/glass/lights/wheel_fl/wheel_fr/wheel_rl/wheel_rr.
const CARS := [
	{"id": "benxi", "name": "E kuqe", "kind": "coupe", "vmax": 58.0, "acc": 17.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#e63138",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36,
		"desc": "I njëjti Vortex GT. Zgjidh ngjyrën tënde."},
	{"id": "uragani", "name": "Blu", "kind": "coupe", "vmax": 58.0, "acc": 17.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#246be8",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36,
		"desc": "I njëjti Vortex GT. Zgjidh ngjyrën tënde."},
	{"id": "kercyesi", "name": "E bardhë", "kind": "coupe", "vmax": 58.0, "acc": 17.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#e9eff5",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36,
		"desc": "I njëjti Vortex GT. Zgjidh ngjyrën tënde."},
	{"id": "shigjeta", "name": "Grafit", "kind": "coupe", "vmax": 58.0, "acc": 17.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#536476",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36,
		"desc": "I njëjti Vortex GT. Zgjidh ngjyrën tënde."},
	{"id": "gelendvagen", "name": "E verdhë", "kind": "coupe", "vmax": 58.0, "acc": 17.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#f6c82a",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36,
		"desc": "I njëjti Vortex GT. Zgjidh ngjyrën tënde."},
	{"id": "sprinteri", "name": "Jeshile", "kind": "coupe", "vmax": 58.0, "acc": 17.0, "grip": 1.05, "hp": 115.0, "mass": 1.1, "color": "#26b69b",
		"model": "res://assets/cars/vortex_gt.glb", "size": Vector3(1.94, 1.38, 4.62), "wheel_r": 0.36,
		"desc": "I njëjti Vortex GT. Zgjidh ngjyrën tënde."},
]
const PAINTS := ["#e41e20", "#26262c", "#f1eee8", "#f2c230", "#2a6fdb", "#3f6d3b", "#ff6a1a", "#8e44ad"]

# ---------------------------------------------------------------- power-ups
const PW := {
	"eagle": {"name": "Shqiponja", "col": "#ff2b2b", "w": 15, "ammo": 1, "desc": "Lëshon një shqiponjë që ndjek makinën para teje. Prapa: atë pas teje."},
	"bolt": {"name": "Rrufeja", "col": "#3aa8ff", "w": 16, "ammo": 3, "desc": "Tre rrufe të shpejta. Pak dëm, shumë inat."},
	"barge": {"name": "Tërmeti", "col": "#b45cff", "w": 12, "ammo": 1, "desc": "Shtyn me forcë këdo që të rri afër."},
	"mine": {"name": "Gropa", "col": "#ff8c1a", "w": 14, "ammo": 1, "desc": "Lë një gropë pas vetes, si bashkia. Përpara: e hedh."},
	"shock": {"name": "Stuhia", "col": "#ffe03a", "w": 7, "ammo": 1, "desc": "Tre kupola elektrike para atij që është i pari."},
	"nitro": {"name": "Nitro", "col": "#38ff6a", "w": 17, "ammo": 1, "desc": "Shpejtësi e çmendur. Prapa: frenim i menjëhershëm."},
	"shield": {"name": "Mburoja", "col": "#dfe9ff", "w": 10, "ammo": 1, "desc": "Të mbron nga çdo sulm për 8 sekonda."},
	"repair": {"name": "Usta", "col": "#ff5fc8", "w": 9, "ammo": 1, "desc": "Usta Ramizi ta rregullon makinën. Pa faturë."},
}
const PW_KEYS := ["eagle", "bolt", "barge", "mine", "shock", "nitro", "shield", "repair"]

# ---------------------------------------------------------------- drivers
# Six drivers: the player is one, the other five drive the bots.
const DRIVERS := [
	{"name": "Artur", "col": "#ff2a3d", "tag": "Gjithmonë me gaz"},
	{"name": "Ritvan", "col": "#1fb6ff", "tag": "Ftohtë si Valbona"},
	{"name": "Desantin", "col": "#ffc21a", "tag": "Fren? Ç’është ajo?"},
	{"name": "Eno", "col": "#2bff88", "tag": "Drift në çdo kthesë"},
	{"name": "Erlin", "col": "#c46bff", "tag": "Godet i pari, pyet më vonë"},
	{"name": "Flori", "col": "#19e6c1", "tag": "Vëllai i vogël i shpejtësisë"},
]

const DIFFS := [
	{"id": 0, "name": "E lehtë", "speed": 0.87, "react": 1.3, "aim": 0.55},
	{"id": 1, "name": "Normale", "speed": 0.935, "react": 0.9, "aim": 0.8},
	{"id": 2, "name": "E vështirë", "speed": 1.035, "react": 0.55, "aim": 1.0},
]

const TIPS := [
	"Në Tiranë, drita e verdhë do të thotë: shtype më fort.",
	"Gropat janë falas. Amortizatorët jo.",
	"Furgoni ndalon kudo. Edhe aty ku nuk ka vend.",
	"Bori është mjeti kombëtar i komunikimit.",
	"Nëse dikush të ndez dritat, ose është polic, ose kushëriri.",
	"Kafeja zgjat tre orë. Gara zgjat tre minuta. Zgjidh me kujdes.",
	"Në Shkodër biçikleta ka gjithmonë përparësi. Edhe kur nuk ka.",
	"Shqipëria ka mbi 170 mijë bunkerë. Asnjë s’të mbron nga Shqiponja.",
	"Rrethrrotullimi është vendi ku ligjet e fizikës dalin me pushime.",
	"Usta Ramizi pranon vetëm kesh. Dhe raki.",
	"Mburoja zgjat 8 sekonda. Si premtimet para zgjedhjeve.",
	"Një gropë e vendosur mirë është art. Bashkia e di.",
	"Diaspora vjen në gusht. Ti erdhe i fundit.",
	"Mbaje frenën për të rrëshqitur në kthesë. Tifozët e duan dramën.",
	"Stuhia godet gjithmonë të parin. Mos u bëj i pari shumë herët.",
	"Rrufeja ka tre të shtëna. Gjuaji kur makina është drejt para teje.",
	"Anoje telefonin, jo kokën. Kthesat vijnë vetë.",
]
const PLACE_MSG := [
	"Kampion! Shqiponja dykrenore ngriti të dyja kokat për ty.",
	"I dyti. Si gjithmonë: afër, por jo aq afër.",
	"Podium! Mjafton për një foto profili.",
	"I katërti. Vendi më i dhimbshëm në sport.",
	"I parafundit. Të paktën dikush ishte më keq.",
	"I fundit. Edhe furgoni i linjës të kaloi, dhe ndaloi dy herë për pasagjerë.",
]
const ORD := ["I PARI", "I DYTI", "I TRETI", "I KATËRTI", "I PESTI", "I GJASHTI", "I SHTATI", "I TETI"]


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


func place_msg(place: int, n: int) -> String:
	if place >= n:
		return PLACE_MSG[PLACE_MSG.size() - 1]
	return PLACE_MSG[clampi(place - 1, 0, PLACE_MSG.size() - 1)]


## Rivals of driver index pi (all when pi < 0), shuffled with the given RNG.
func rivals_of(pi: int, rng: RandomNumberGenerator) -> Array:
	var b := []
	for i in DRIVERS.size():
		if i != pi:
			b.append(DRIVERS[i])
	for i in range(b.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = b[i]
		b[i] = b[j]
		b[j] = t
	return b


static func col(hex: String) -> Color:
	return Color.html(hex)
