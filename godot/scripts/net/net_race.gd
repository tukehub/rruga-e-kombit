class_name NetRace
extends RefCounted
## Steps a Race in lockstep with the other phones (plan 7.2/7.3). The scene
## calls step(local_ctrl) once per 60 Hz tick it wants to simulate; it returns
## false while waiting for someone's input, and the scene simply tries again
## next frame. The local car's input goes through the same 4-byte packing as
## everyone else's, so every phone simulates identical numbers.

const DT := 1.0 / 60.0
## The countdown runs in ticks too, so the race starts on the same tick on
## every phone however long each one took to load.
const COUNTDOWN_TICKS := 192

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


## Seconds of countdown left (0 once racing).
func countdown_left() -> float:
	return maxf(0.0, float(COUNTDOWN_TICKS - lockstep.tick) * DT)


## Runs `apply` (which writes the touch/tilt state into a car's Ctrl, like
## RaceInput.apply) against a scratch Ctrl of the local car and returns it
## packed. The car's real Ctrl only ever receives input through the lockstep,
## on the tick everyone applies it.
func capture(apply: Callable) -> PackedByteArray:
	var car := local_car()
	var real := car.ctrl
	car.ctrl = CarState.Ctrl.new()
	apply.call(car)
	var bytes := car.ctrl.pack(car.slots)
	car.ctrl = real
	return bytes


## Simulates one tick if everyone's input for it is here. `local_ctrl` is
## this phone's Ctrl.pack() for the tick DELAY ahead.
func step(local_ctrl: PackedByteArray) -> bool:
	lockstep.submit(local_ctrl)
	if not lockstep.can_step():
		lockstep.stalls += 1
		return false
	var t := lockstep.tick
	var row := lockstep.take()
	if t < COUNTDOWN_TICKS:
		return true
	if t == COUNTDOWN_TICKS:
		race.started = true
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
