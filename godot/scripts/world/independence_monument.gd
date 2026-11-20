class_name IndependenceMonument
extends Node3D
## Monumenti i Pavarësisë, Sheshi i Flamurit, Vlorë: an interpretation after
## photographs. A tall, tapering dark stone pylon carrying "1912" near its top;
## a bronze flag-bearer standing on it with a great furled flag; a group of
## bronze figures at its foot (frock-coated statesmen, a fighter with raised
## fist, a kneeling rifleman, men in plis caps) on a low stepped plinth.
## Local frame: the "1912" face and the group look toward -Z.
## Figures are built from tapered limbs, readable at racing distance; this is
## not a scan. Two materials: stone and bronze.

const STONE := Color(0.20, 0.205, 0.21)
const STONE_LIGHT := Color(0.50, 0.50, 0.49)
const BRONZE := Color(0.13, 0.12, 0.10)
const PLINTH_TOP := 1.3
const PYLON_TOP := 16.5


func _ready() -> void:
	_stone()
	_bronze()
	_inscription()


func _stone() -> void:
	var st := LandmarkKit.begin()
	# Two broad steps and the plinth the group stands on.
	LandmarkKit.box(st, Vector3(0, -1.5, -1.0), Vector3(17.0, 3.0, 13.0), STONE_LIGHT)
	LandmarkKit.box(st, Vector3(0, 0.25, -1.0), Vector3(15.0, 0.5, 11.0), STONE_LIGHT.darkened(0.08))
	LandmarkKit.box(st, Vector3(0, 0.9, -1.0), Vector3(13.4, 0.8, 9.4), STONE_LIGHT.darkened(0.15))
	# The pylon: a tapering block whose top is cut on a slant, high at the back.
	var b0 := Vector2(1.9, 1.35)   # half sizes at the foot (x, z)
	var b1 := Vector2(1.25, 0.95)  # at the top
	var cz := 1.2                  # set back behind the group
	var y0 := PLINTH_TOP
	var foot := [Vector3(-b0.x, y0, cz - b0.y), Vector3(b0.x, y0, cz - b0.y), Vector3(b0.x, y0, cz + b0.y), Vector3(-b0.x, y0, cz + b0.y)]
	var head := [Vector3(-b1.x, PYLON_TOP - 1.2, cz - b1.y), Vector3(b1.x, PYLON_TOP - 1.2, cz - b1.y), Vector3(b1.x, PYLON_TOP, cz + b1.y), Vector3(-b1.x, PYLON_TOP, cz + b1.y)]
	for k in 4:
		var n := (k + 1) % 4
		var out: Vector3 = (foot[n] + foot[k]) * 0.5 - Vector3(0, y0, cz)
		LandmarkKit.quad_facing(st, foot[n], foot[k], head[k], head[n], STONE, out)
	LandmarkKit.quad_facing(st, head[0], head[1], head[2], head[3], STONE.darkened(0.1), Vector3.UP)
	# A raised panel framing the date.
	LandmarkKit.box(st, Vector3(0, PYLON_TOP - 3.4, cz - 1.08), Vector3(2.2, 1.25, 0.12), STONE.lightened(0.06))
	# Dark, rough-dressed stone; the steps a paler grey.
	add_child(LandmarkKit.mesh_node(st, LandmarkKit.material(0.95), "MonumentStone", 2200.0))


func _inscription() -> void:
	var label := Label3D.new()
	label.name = "MonumentDate"
	label.text = Data.t("sign.independence_year")
	label.font = preload("res://assets/fonts/BigShouldersDisplay.ttf")
	label.font_size = 128
	label.pixel_size = 0.0075
	label.modulate = Color(0.80, 0.79, 0.74)
	label.outline_modulate = Color(0.12, 0.12, 0.12)
	label.outline_size = 10
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	# -Z is the front: a Label3D reads from +Z, so turn it round.
	label.rotation.y = PI
	label.position = Vector3(0, PYLON_TOP - 3.4, 1.2 - 1.16)
	label.visibility_range_end = 700.0
	add_child(label)


func _bronze() -> void:
	var st := LandmarkKit.begin()
	# The flag-bearer on the pylon: pole in the right hand, cloth billowing up
	# and back over his left shoulder.
	var top := Vector3(0, PYLON_TOP - 0.6, 1.2)
	var pole_foot := top + Vector3(0.7, 0.2, -0.5)
	var pole_head := top + Vector3(0.35, 8.0, 0.6)
	_figure(st, top, 5.0, {"coat": true, "lean": -0.05,
		"hand_r": pole_foot.lerp(pole_head, 0.38) - top, "hand_l": pole_foot.lerp(pole_head, 0.58) - top})
	LandmarkKit.tube(st, pole_foot, pole_head, 0.09, 0.07, BRONZE)
	_cloth(st, pole_head, pole_foot.lerp(pole_head, 0.45), Vector3(-1, 0.15, 0.55).normalized(), 3.6)
	# The group at the foot, front row then back row (x across, z depth).
	var p := PLINTH_TOP
	var h := 3.4
	# Frock-coated statesman with a document, centre front.
	_figure(st, Vector3(-0.9, p, -3.3), h, {"coat": true, "hand_r": Vector3(0.35, 1.9, -0.45), "hand_l": Vector3(-0.3, 1.5, -0.2)})
	LandmarkKit.box(st, Vector3(-0.55, p + 1.95, -3.75), Vector3(0.45, 0.6, 0.06), BRONZE)
	# Bearded elder beside him.
	_figure(st, Vector3(-2.6, p, -2.9), h * 0.97, {"coat": true, "cap": true, "hand_r": Vector3(0.2, 1.3, -0.25), "hand_l": Vector3(-0.25, 1.3, -0.1)})
	# Fighter with a raised fist, behind on the left.
	_figure(st, Vector3(-3.4, p + 0.2, -0.9), h * 1.03, {"cap": true, "hand_l": Vector3(-0.35, 3.75, 0.0), "hand_r": Vector3(0.3, 1.4, -0.2)})
	# Man in a long coat with a rifle at his side, far left.
	_figure(st, Vector3(-4.8, p, -2.4), h, {"coat": true, "cap": true, "hand_r": Vector3(0.38, 1.35, -0.1), "hand_l": Vector3(-0.3, 1.5, -0.25), "rifle": true})
	# Standing statesman in a frock coat, right of centre.
	_figure(st, Vector3(1.1, p, -3.0), h * 1.02, {"coat": true, "hand_r": Vector3(0.3, 1.45, -0.15), "hand_l": Vector3(-0.35, 1.45, -0.15)})
	# Kneeling rifleman, front right.
	_figure(st, Vector3(2.7, p, -3.5), h, {"kneel": true, "cap": true, "hand_r": Vector3(0.4, 1.3, -0.5), "hand_l": Vector3(-0.1, 1.55, -0.7), "rifle": true})
	# Two more behind on the right, one turned outward.
	_figure(st, Vector3(3.6, p + 0.2, -1.0), h * 0.98, {"cap": true, "hand_r": Vector3(0.35, 1.4, -0.1), "hand_l": Vector3(-0.3, 1.6, -0.3)})
	_figure(st, Vector3(1.9, p + 0.3, -0.9), h * 1.04, {"coat": true, "hand_r": Vector3(0.3, 2.5, -0.35), "hand_l": Vector3(-0.3, 1.5, -0.1)})
	# Old, dark bronze: matte enough not to mirror the sky.
	var mat := LandmarkKit.material(0.68, 0.35)
	add_child(LandmarkKit.mesh_node(st, mat, "MonumentBronze", 2200.0))


## One standing (or kneeling) figure, feet at `foot`, facing -Z.
## Hands are given relative to the feet, in metres.
func _figure(st: SurfaceTool, foot: Vector3, h: float, pose: Dictionary) -> void:
	var s := h / 3.4
	var kneel: bool = pose.get("kneel", false)
	var lean: float = pose.get("lean", 0.0)
	var drop := 0.9 * s if kneel else 0.0
	var hip := foot + Vector3(0, 1.8 * s - drop, 0)
	var shoulder := hip + Vector3(0, 1.0 * s, lean * s)
	var neck := shoulder + Vector3(0, 0.18 * s, 0)
	var head := neck + Vector3(0, 0.2 * s, -0.02 * s)
	# Legs
	for side in [-1.0, 1.0]:
		var h0 := hip + Vector3(side * 0.17 * s, 0, 0)
		var knee: Vector3
		var ankle: Vector3
		if kneel and side > 0:
			knee = h0 + Vector3(0, -0.85 * s, -0.75 * s)
			ankle = knee + Vector3(0, -0.85 * s, 0.1 * s)
		elif kneel:
			knee = foot + Vector3(side * 0.2 * s, 0.15 * s, 0.2 * s)
			ankle = knee + Vector3(0, -0.05 * s, 0.8 * s)
		else:
			ankle = foot + Vector3(side * 0.24 * s, 0.1 * s, (0.08 if side > 0 else -0.12) * s)
			knee = h0.lerp(ankle, 0.5) + Vector3(0, 0, -0.05 * s)
		LandmarkKit.tube(st, h0, knee, 0.15 * s, 0.11 * s, BRONZE)
		LandmarkKit.tube(st, knee, ankle, 0.11 * s, 0.08 * s, BRONZE)
		LandmarkKit.box(st, ankle + Vector3(0, -0.05 * s, -0.1 * s), Vector3(0.18, 0.14, 0.42) * s, BRONZE)
	# Torso and, for coats, a skirt to the knees.
	LandmarkKit.tube(st, hip, shoulder, 0.3 * s, 0.36 * s, BRONZE, 10)
	LandmarkKit.sphere(st, shoulder + Vector3(0, -0.05 * s, 0), Vector3(0.4, 0.2, 0.26) * s, BRONZE)
	if pose.get("coat", false) and not kneel:
		LandmarkKit.tube(st, hip + Vector3(0, 0.25 * s, 0), hip + Vector3(0, -1.05 * s, 0), 0.33 * s, 0.46 * s, BRONZE, 10)
	LandmarkKit.tube(st, shoulder, neck, 0.11 * s, 0.1 * s, BRONZE)
	LandmarkKit.sphere(st, head, Vector3(0.14, 0.17, 0.15) * s, BRONZE)
	if pose.get("cap", false):
		# A plis: a short white-felt dome, here in bronze.
		LandmarkKit.tube(st, head + Vector3(0, 0.07 * s, 0), head + Vector3(0, 0.24 * s, 0), 0.15 * s, 0.13 * s, BRONZE)
	# Arms: shoulder, elbow bent outward, hand.
	for side in [-1.0, 1.0]:
		var sh := shoulder + Vector3(side * 0.4 * s, -0.05 * s, 0)
		var key := "hand_r" if side > 0 else "hand_l"
		var hand: Vector3 = foot + (pose.get(key, Vector3(side * 0.35, 1.45, -0.1)) as Vector3) * s
		var elbow := sh.lerp(hand, 0.5) + Vector3(side * 0.16 * s, -0.08 * s, 0.08 * s)
		LandmarkKit.tube(st, sh, elbow, 0.11 * s, 0.09 * s, BRONZE)
		LandmarkKit.tube(st, elbow, hand, 0.09 * s, 0.07 * s, BRONZE)
		LandmarkKit.sphere(st, hand, Vector3(0.08, 0.1, 0.08) * s, BRONZE, 4, 6)
	if pose.get("rifle", false):
		var grip: Vector3 = foot + (pose.get("hand_r") as Vector3) * s
		LandmarkKit.tube(st, grip + Vector3(0, -0.9 * s, 0.05 * s), grip + Vector3(0, 1.0 * s, -0.12 * s), 0.05 * s, 0.035 * s, BRONZE, 6)


## A heavy, billowing flag: rows of panels off the pole, wavy and drooping.
func _cloth(st: SurfaceTool, top: Vector3, low: Vector3, out: Vector3, length: float) -> void:
	var cols := 6
	var rows := 5
	var grid := []
	for r in rows + 1:
		var on_pole := top.lerp(low, float(r) / rows)
		var row := []
		for c in cols + 1:
			var t := float(c) / cols
			var p := on_pole + out * (length * t)
			p += Vector3(0, -1.2 * t * t, 0) + Vector3(0.35, 0.0, -0.35) * sin(t * 5.0 + r * 0.9) * t
			row.append(p)
		grid.append(row)
	for r in rows:
		for c in cols:
			var a: Vector3 = grid[r][c]
			var b: Vector3 = grid[r][c + 1]
			var cc: Vector3 = grid[r + 1][c + 1]
			var d: Vector3 = grid[r + 1][c]
			# Both faces: the cloth is seen from all round.
			LandmarkKit.quad(st, a, b, cc, d, BRONZE)
			LandmarkKit.quad(st, b, a, d, cc, BRONZE)
