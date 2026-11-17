extends Node
## Plan 7.1's prerequisite: the simulation is a pure function of its seed and
## inputs. Two races with the same seed and the same packed inputs, stepped
## side by side in one process, agree on state_hash() at every check; one
## changed input makes them part from that tick on. The same for points
## rounds. Also the 4-byte input packing itself.

const DT := 1.0 / 60.0
const CHECK_EVERY := 30

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func _track() -> RaceTrack:
	var track := RaceTrack.new()
	track.build({"id": "tirane", "hw": 10.0, "pts": [[-700.0, 0.0, -700.0], [700.0, 0.0, -700.0], [700.0, 0.0, 700.0], [-700.0, 0.0, 700.0]]}, false)
	return track


## A scripted driver: weaving, braking, firing and cycling now and then,
## from its own seeded generator so every run gets the same inputs.
func script_inputs(ticks: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := []
	var c := CarState.Ctrl.new()
	for t in ticks:
		c.steer = sin(t * 0.021) * 0.8 + rng.randf_range(-0.15, 0.15)
		c.gas = rng.randf() > 0.05
		c.brake = rng.randf() < 0.04
		c.fire = rng.randf() < 0.02
		c.back = rng.randf() < 0.005
		c.cycle = rng.randf() < 0.005
		c.boost = rng.randf() < 0.01
		out.append(c.pack([]))
	return out


## Steps sims side by side, feeding each its inputs; returns per-sim hashes
## taken every CHECK_EVERY ticks.
func run_side_by_side(sims: Array, inputs: Array, ticks: int) -> Array:
	var hashes := []
	for s in sims:
		hashes.append([])
	for t in ticks:
		for i in sims.size():
			var sim = sims[i]
			sim.apply_packed(sim.cars.find(sim.player), inputs[i][t])
			sim.step(DT)
			sim.take_events()
			if t % CHECK_EVERY == 0:
				hashes[i].append(sim.state_hash())
	return hashes


func first_difference(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return i
	return -1


func _ready() -> void:
	# --- packing
	var c := CarState.Ctrl.new()
	c.steer = 0.333
	c.gas = true
	c.fire = true
	c.boost = true
	c.select = 2
	var slots := [{"type": "bolt", "ammo": 1}, {"type": "eagle", "ammo": 1}]
	c.discard = slots[1]
	var bytes := c.pack(slots)
	check(bytes.size() == 4, "one tick of input is 4 bytes")
	var d := CarState.Ctrl.new()
	d.unpack(bytes, slots)
	check(d.steer == CarState.Ctrl.quantize(0.333) and d.gas and not d.brake and d.fire and not d.back and d.boost and d.select == 2, "inputs survive packing")
	check(is_same(d.discard, slots[1]), "the discarded item is sent as its slot and found again")
	check(d.pack(slots) == bytes, "packing is stable")
	d.fire = false
	d.unpack(CarState.Ctrl.new().pack([]), slots)
	check(d.steer == 0.0 and not d.gas, "held controls follow the latest tick")
	var e := CarState.Ctrl.new()
	e.fire = true
	e.unpack(CarState.Ctrl.new().pack([]), [])
	check(e.fire, "a press not yet used is not lost to a later empty tick")
	check(absf(CarState.Ctrl.quantize(0.5) - 0.5) < 0.005 and CarState.Ctrl.quantize(2.0) == 1.0, "steering is quantised to 1/127")

	# --- races
	var track := _track()
	var ticks := 60 * 50
	var opts := {"seed": 41, "laps": 2, "diff": 1, "driver": 2}
	var inputs := script_inputs(ticks, 9)
	var changed := inputs.duplicate()
	var flip := 900
	var odd := CarState.Ctrl.new()
	odd.steer = -1.0
	odd.gas = false
	odd.brake = true
	changed[flip] = odd.pack([])
	var started := []
	for i in 3:
		var race := Race.new(track, opts)
		race.started = true
		started.append(race)
	var start_hashes := started.map(func(r: Race) -> int: return r.state_hash())
	check(start_hashes[0] == start_hashes[1] and start_hashes[1] == start_hashes[2], "the same seed builds the same grid")
	var hashes := run_side_by_side(started, [inputs, inputs, changed], ticks)
	check(hashes[0] == hashes[1], "same seed and inputs: equal hashes for 50 s (%d checks)" % hashes[0].size())
	var parted := first_difference(hashes[0], hashes[2])
	check(parted == flip / CHECK_EVERY, "one changed input parts the race on that tick (check %d)" % parted)
	check(started[0].player.progress > 1500.0, "the scripted driver actually raced")
	check(Race.new(track, {"seed": 42, "laps": 2, "diff": 1, "driver": 2}).state_hash() != start_hashes[0], "another seed is another race")

	# --- points rounds
	var arena_ticks := 60 * 30
	var a_inputs := script_inputs(arena_ticks, 5)
	var a_changed := a_inputs.duplicate()
	a_changed[600] = odd.pack([])
	var arenas := []
	for i in 3:
		var arena := Arena.new({"seed": 8, "time": 120.0, "driver": 0})
		arena.started = true
		arenas.append(arena)
	var ah := run_side_by_side(arenas, [a_inputs, a_inputs, a_changed], arena_ticks)
	check(ah[0] == ah[1], "points rounds replay exactly too")
	check(first_difference(ah[0], ah[2]) == 600 / CHECK_EVERY, "and part at a changed input")

	print("lockstep_replay: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
