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
	var boost := false
	var discard: Dictionary = {} # exact item reference; never discard a stale index

	## Steering travels as a signed byte; quantise local input the same way
	## so the local car and every peer simulate identical values.
	static func quantize(steer_in: float) -> float:
		return roundf(clampf(steer_in, -1.0, 1.0) * 127.0) / 127.0

	## One tick of input in 4 bytes: steer, button bits, select, discard slot.
	## `slots` is the car's inventory, to send the discarded item as an index.
	func pack(slots: Array) -> PackedByteArray:
		var bytes := PackedByteArray()
		bytes.resize(4)
		bytes.encode_s8(0, int(roundf(clampf(steer, -1.0, 1.0) * 127.0)))
		var bits := (1 if gas else 0) | (2 if brake else 0) | (4 if fire else 0) | (8 if back else 0) | (16 if cycle else 0) | (32 if boost else 0)
		bytes.encode_u8(1, bits)
		bytes.encode_u8(2, clampi(select, 0, 255))
		var slot := -1
		if not discard.is_empty():
			for i in slots.size():
				if is_same(slots[i], discard):
					slot = i
					break
		bytes.encode_s8(3, slot)
		return bytes

	## Inverse of pack(); the discard index is resolved against `slots`.
	## Button presses are OR-ed in: a press waits for the tick that uses it.
	func unpack(bytes: PackedByteArray, slots: Array) -> void:
		if bytes.size() < 4:
			return
		steer = bytes.decode_s8(0) / 127.0
		var bits := bytes.decode_u8(1)
		gas = bits & 1 != 0
		brake = bits & 2 != 0
		fire = fire or bits & 4 != 0
		back = back or bits & 8 != 0
		cycle = cycle or bits & 16 != 0
		boost = boost or bits & 32 != 0
		select = maxi(select, bytes.decode_u8(2))
		var slot := bytes.decode_s8(3)
		if slot >= 0 and slot < slots.size():
			discard = slots[slot]

var id := 0
var def: Dictionary          # entry from Data.CARS
var name := ""
var is_player := false
var autopilot := false
var color := Color.WHITE

var progress := 0.0          # total metres since the start (can exceed L)
var s := 0.0                 # progress mod L
var d := 0.0                 # lateral offset (+ driver's right)
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
var recovery_t := 0.0         # fixed anti-chain window; further hits cannot extend it
var chain_hits := 0
var nitro_duration := 2.6
var nitro_from_drift := false
var skill_charge := 0.0       # clean drift distance, banked up to one short boost
var skill_boosts := 0

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
var takedowns := 0           # rivals this car wrecked
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
