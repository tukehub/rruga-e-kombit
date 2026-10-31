extends Node
## Central game data: cities, cars, power-ups, drivers, difficulty, copy.
## Everything race-balance related lives here or in sim/race.gd so a new car
## or city is a data change only.

const GAME_NAME := "Kafshim asfalti"

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
	{"id": "tirane", "name": "Tiranë", "region": "Shqipëri", "env": "night", "laps": 2, "neon": "#ff2d6f", "horizon": "flat",
		"hdri": "night", "blurb": "Bulevardi natën: pallate me ngjyra, neon dhe Piramida në krah.",
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
# All fictional. model: glb produced by tools/gen_cars.py with nodes
# body/glass/lights/wheel_fl/wheel_fr/wheel_rl/wheel_rr. Physics numbers are the
# original Vortex balance (vmax m/s, acc m/s², grip multiplier, hp, mass).
const CARS := [
	{"id": "benxi", "name": "Benxi GT", "kind": "coupe", "vmax": 58.0, "acc": 16.5, "grip": 1.0, "hp": 115.0, "mass": 1.1, "color": "#26262c",
		"model": "res://assets/cars/benxi.glb", "size": Vector3(2.0, 1.32, 4.75), "wheel_r": 0.36,
		"desc": "Kupeja e madhe e rrugëve tona. Rëndë, e qetë, dhe gjithmonë e parkuar para kafenesë."},
	{"id": "uragani", "name": "Uragani V10", "kind": "super", "vmax": 62.0, "acc": 16.0, "grip": 0.92, "hp": 100.0, "mass": 1.05, "color": "#1b4fd6",
		"model": "res://assets/cars/uragani.glb", "size": Vector3(2.02, 1.12, 4.6), "wheel_r": 0.35,
		"desc": "Dhjetë cilindra dhe zero durim. Kthesat i merr me bisht."},
	{"id": "kercyesi", "name": "Kërcyesi GTI", "kind": "hatch", "vmax": 55.0, "acc": 19.0, "grip": 1.16, "hp": 90.0, "mass": 0.85, "color": "#e41e20",
		"model": "res://assets/cars/kercyesi.glb", "size": Vector3(1.8, 1.45, 4.1), "wheel_r": 0.32,
		"desc": "I vogël, i shkathët, dhe gjithmonë me xhamat poshtë e muzikën lart."},
	{"id": "shigjeta", "name": "Shigjeta RS", "kind": "sedan", "vmax": 60.0, "acc": 18.0, "grip": 1.06, "hp": 95.0, "mass": 0.95, "color": "#f1eee8",
		"model": "res://assets/cars/shigjeta.glb", "size": Vector3(1.9, 1.4, 4.7), "wheel_r": 0.34,
		"desc": "Katër rrota që tërheqin. Shkon si në binarë, edhe mbi gropa."},
	{"id": "gelendvagen", "name": "Gelendvagen G", "kind": "offroad", "vmax": 54.0, "acc": 15.0, "grip": 0.96, "hp": 140.0, "mass": 1.35, "color": "#2a2a2e",
		"model": "res://assets/cars/gelendvagen.glb", "size": Vector3(2.0, 1.95, 4.65), "wheel_r": 0.42,
		"desc": "Kutia e zezë e çdo dasme. Gropat e tua s’i bëjnë gjë."},
	{"id": "sprinteri", "name": "Sprinteri i Linjës", "kind": "van", "vmax": 51.0, "acc": 13.5, "grip": 0.88, "hp": 175.0, "mass": 1.7, "color": "#f3f3ee",
		"model": "res://assets/cars/sprinteri.glb", "size": Vector3(2.05, 2.5, 5.9), "wheel_r": 0.38,
		"desc": "Tiranë–Durrës, 24/7. Ndalon ku të duash, edhe ku s’do."},
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
