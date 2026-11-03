class_name CarState
extends RefCounted
## Pure simulation state of one car (player or bot). Port of Car in src/03_sim.js.

class Ai:
	var t := 1.0
	var plan_t := 0.0
	var v_t := 0.0
	var d_t := 0.0
	var lane_bias := 0.0
	var line_amt := 0.8
	var skill := 1.0
	var react := 1.0

class Ctrl:
	var steer := 0.0
	var gas := false
	var brake := false
	var fire := false
	var back := false
	var cycle := false
	var select := 0

var id := 0
var def: Dictionary          # entry from Data.CARS
var name := ""
var is_player := false
var autopilot := false
var color := Color.WHITE

var progress := 0.0          # total metres since the start (can exceed L)
var s := 0.0                 # progress mod L
var d := 0.0                 # lateral offset (+ left)
var v := 0.0                 # speed m/s along the heading
var yaw := 0.0               # heading relative to the track tangent
var lat_v := 0.0
var steer := 0.0

var ctrl := Ctrl.new()
var ai := Ai.new()

var max_hp := 100.0
var health := 100.0
var slots: Array = []        # [{type, ammo}]

var wreck_t := 0.0
var spin_t := 0.0
var spin_dir := 1
var hop := 0.0
var hop_v := 0.0
var stun_t := 0.0
var nitro_t := 0.0
var shield_t := 0.0
var invuln_t := 0.0
var hbrake_t := 0.0

var finished := false
var finish_time := 0.0
var place := 0
var lap := -1
var lap_start := 0.0
var best_lap := INF
var lap_times: Array[float] = []

var fans := 0.0
var drift := 0.0
var drift_t := 0.0
var scrape := 0.0
var wrecks := 0
var hits := 0
var vmax_mul := 1.0
var brake_force := 0.0
var braking := false
var gas_on := false
var est := 0.0


func _init(p_id: int, p_def: Dictionary, p_name: String, p_is_player: bool, p_color: Color) -> void:
	id = p_id
	def = p_def
	name = p_name
	is_player = p_is_player
	color = p_color
	max_hp = float(def.hp)
	health = max_hp


func slot_type(i := 0) -> String:
	if i < slots.size():
		return slots[i].type
	return ""
