class_name NetRace
extends RefCounted
## Steps a Race in lockstep with the other phones (plan 7.2/7.3). The scene
## calls step(local_ctrl) once per 60 Hz tick it wants to simulate; it returns
## false while waiting for someone's input, and the scene simply tries again
## next frame. The local car's input goes through the same 4-byte packing as
## everyone else's, so every phone simulates identical numbers.

const DT := 1.0 / 60.0

var race: Race
var lockstep: Lockstep


## The Race every peer builds from the host's START config.
static func race_options(config: Dictionary) -> Dictionary:
	var o := {}
	for k in ["seed", "laps", "diff", "wet", "assist", "brake_assist", "handling", "bots", "humans", "adaptive_pickups"]:
		if config.has(k):
			o[k] = config[k]
	return o


func _init(p_race: Race, p_lockstep: Lockstep) -> void:
	race = p_race
	lockstep = p_lockstep


## This phone's car.
func local_car() -> CarState:
	return race.humans[lockstep.local]


## Simulates one tick if everyone's input for it is here. `local_ctrl` is
## this phone's Ctrl.pack() for the tick DELAY ahead.
func step(local_ctrl: PackedByteArray) -> bool:
	lockstep.submit(local_ctrl)
	if not lockstep.can_step():
		lockstep.stalls += 1
		return false
	var t := lockstep.tick
	var row := lockstep.take()
	for s in row.size():
		var car: CarState = race.humans[s]
		if lockstep.is_bot(s, t):
			car.is_player = false
			continue
		var index := race.cars.find(car)
		race.apply_packed(index, row[s])
	race.step(DT)
	if lockstep.wants_hash():
		lockstep.after_step(race.state_hash())
	return true
