extends Node
## Traffic and hazards (README 2.3): parked cars and slow traffic on the road
## ribbon as non-firing, non-racing CarStates that share the racers' footprint
## collision, with counts taken from the quality preset.

const STEP := 1.0 / 60.0
const FULL := {"parked": 8, "moving": 3}

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func new_race(opt: Dictionary, track: RaceTrack = null) -> Race:
	var options := {"seed": 21, "laps": 1}
	options.merge(opt, true)
	var race := Race.new(track if track != null else RaceTrack.load_city("tirane"), options)
	race.started = true
	return race

func layout(race: Race) -> Array:
	var out := []
	for c in race.traffic:
		out.append([c.traffic, c.s, c.d, c.v, c.color])
	return out

func grid(race: Race) -> Array:
	var out := []
	for c in race.cars:
		out.append([c.name, c.progress, c.d, c.ai.lane_bias, c.ai.skill, c.def.id])
	for p in race.pickups:
		out.append([p.s, p.d, p.type])
	return out

func traffic_bumps(events: Array) -> int:
	var n := 0
	for e in events:
		if e.t == "bump" and (e.a.traffic != "" or e.b.traffic != ""):
			n += 1
	return n

## Drive a whole race with the AI at the wheel of every car.
func run_race(race: Race) -> Dictionary:
	race.player.autopilot = true
	var bumps := 0
	var wrecks := 0
	var steps := 0
	while steps < 60 * 400 and not race.cars.all(func(c: CarState) -> bool: return c.finished):
		race.step(STEP)
		steps += 1
		var events := race.take_events()
		bumps += traffic_bumps(events)
		for e in events:
			if e.t == "wreck" and str(e.kind) in ["bump", "wall"]:
				wrecks += 1
	var times := []
	for c in race.cars:
		times.append(c.finish_time if c.finished else INF)
	times.sort()
	return {"times": times, "bumps": bumps, "wrecks": wrecks}

func _ready() -> void:
	# The table follows the quality presets and grows with them.
	for preset in Quality.PRESETS:
		check(Data.TRAFFIC.has(preset), "traffic counts exist for the %s preset" % preset)
	var low: Dictionary = Data.traffic("low")
	var medium: Dictionary = Data.traffic("medium")
	var high: Dictionary = Data.traffic("high")
	check(low.parked <= medium.parked and medium.parked <= high.parked and low.moving <= medium.moving and medium.moving <= high.moving, "a higher preset never has less traffic")
	check(int(high.parked) + int(high.moving) <= 12 and int(low.parked) + int(low.moving) >= 1, "counts stay inside the drawing budget")
	check(Data.traffic("unknown") == medium, "an unknown preset gets the medium counts")

	# No option, no traffic, and the race is the one it always was.
	var plain := new_race({})
	var empty := new_race({"traffic": {"parked": 0, "moving": 0}})
	check(plain.traffic.is_empty() and empty.traffic.is_empty(), "no traffic unless a race asks for it")
	var busy := new_race({"traffic": FULL})
	check(grid(plain) == grid(busy), "traffic leaves the grid, the bots and the pickups unchanged")
	check(busy.cars.size() == plain.cars.size() and busy.cars.all(func(c: CarState) -> bool: return c.traffic == ""), "traffic is not a racer")
	busy.compute_order()
	var places := busy.cars.map(func(c: CarState) -> int: return c.place)
	places.sort()
	check(places == range(1, busy.cars.size() + 1), "standings count racers only")

	# Placement: the asked counts, where a hazard is fair.
	var track := busy.track
	var parked := busy.traffic.filter(func(c: CarState) -> bool: return c.traffic == "parked")
	var moving := busy.traffic.filter(func(c: CarState) -> bool: return c.traffic == "moving")
	check(parked.size() == 8 and moving.size() == 3, "Tirana has room for the high preset's traffic")
	for c: CarState in busy.traffic:
		check(c.autopilot and not c.is_player and c.slots.is_empty() and c.def == Data.TRAFFIC_CAR, "traffic is an unarmed autopilot car")
		check(absf(track.wrap_s(c.s)) >= Race.TRAFFIC_START_CLEAR - 0.01, "traffic keeps clear of the start and finish")
	for c: CarState in parked:
		check(is_equal_approx(absf(c.d), busy.hw - Race.TRAFFIC_PARKED_INSET) and c.v == 0.0, "a parked car stands at the kerb")
		check(absf(track.curv(c.s)) <= Race.TRAFFIC_MAX_CURVATURE, "nothing is parked in a bend")
		for o: CarState in parked:
			check(o == c or absf(track.wrap_s(o.s - c.s)) >= Race.TRAFFIC_SPACING, "parked cars are spaced out")
		for p in busy.pickups:
			check(absf(track.wrap_s(float(p.s) - c.s)) >= 14.0, "no parked car blocks a pickup station")
	for c: CarState in moving:
		check(absf(c.d) >= 2.6 and absf(c.d) <= 3.4 and c.lane == c.d, "slow traffic drives in a lane beside the centre")
		check(c.cruise >= 11.0 and c.cruise <= 14.0 and c.v == c.cruise and c.cruise < float(busy.player.def.vmax) * 0.3, "slow traffic is far slower than a race car")
	check(layout(busy) == layout(new_race({"traffic": FULL})), "the same seed places the same traffic")
	check(layout(busy) != layout(new_race({"traffic": FULL, "seed": 22})), "another seed places it elsewhere")
	check(new_race({"traffic": {"parked": 500, "moving": 0}}).traffic.size() < 500, "an impossible count ends instead of looping")

	# Left alone, a parked car stays and slow traffic keeps its lane and speed.
	var quiet := new_race({"traffic": FULL})
	for c in quiet.cars:
		c.finished = true  # nobody races, nothing touches the traffic
	var before := layout(quiet)
	for i in 600:
		quiet.update_traffic(STEP)
		quiet.collisions(STEP)
	for i in quiet.traffic.size():
		var c := quiet.traffic[i]
		if c.traffic == "parked":
			check(c.s == before[i][1] and c.d == before[i][2] and c.v == 0.0, "an untouched parked car does not move")
		else:
			check(absf(c.progress - (float(before[i][1]) + c.cruise * 10.0)) < c.cruise * 1.5, "slow traffic covers its cruise distance")
			check(absf(c.d - c.lane) < 0.05 and absf(c.d) < quiet.hw, "slow traffic holds its lane")
	check(traffic_bumps(quiet.take_events()) == 0, "traffic never collides with traffic")

	# Slow traffic queues behind slower traffic rather than passing through it.
	var queue := new_race({"traffic": {"parked": 0, "moving": 2}})
	var lead := queue.traffic[0]
	var tail := queue.traffic[1]
	lead.cruise = 6.0
	lead.v = 6.0
	tail.cruise = 14.0
	tail.v = 14.0
	tail.d = lead.d
	tail.lane = lead.lane
	tail.progress = lead.progress - 30.0
	tail.s = queue.track.mod_s(tail.progress)
	var closest := INF
	for i in 900:
		queue.update_traffic(STEP)
		closest = minf(closest, lead.progress - tail.progress)
	check(closest > 2.0 * Race.CAR_HALF_LENGTH + 0.5 and tail.v < 7.0, "slow traffic queues behind slower traffic")

	# Hitting a parked car: the existing footprint contact stops the racer.
	var flat := RaceTrack.load_city("tirane")
	flat.K.fill(0.0)
	var crash := new_race({"traffic": {"parked": 1, "moving": 0}}, flat)
	var wall := crash.traffic[0]
	var driver := crash.player
	for c in crash.cars:
		if c != driver:
			c.finished = true
	driver.progress = crash.L + wall.s - 12.0
	driver.s = flat.mod_s(driver.progress)
	driver.d = wall.d
	driver.v = 45.0
	driver.ctrl.gas = true
	var wall_start := wall.progress
	var slowest := INF
	var bumps := 0
	for i in 90:
		crash.physics(driver, STEP)
		crash.update_traffic(STEP)
		crash.collisions(STEP)
		bumps += traffic_bumps(crash.take_events())
		slowest = minf(slowest, driver.v)
		check(flat.wrap_s(wall.s - driver.s) > 2.0 * Race.CAR_HALF_LENGTH - 1.2 or absf(wall.d - driver.d) > 2.0 * Race.CAR_HALF_WIDTH - 0.6, "a racer cannot drive through a parked car")
	check(bumps > 0 and slowest < 30.0, "running into a parked car costs most of the speed")
	check(driver.health < driver.max_hp and driver.health > 0.0, "the crash damages the racer")
	check(wall.health == wall.max_hp and wall.wreck_t == 0.0, "traffic takes no damage and is never wrecked")
	check(wall.progress > wall_start + 0.5, "the parked car is shoved along")
	for c in crash.cars:
		c.finished = true
	for i in 300:
		crash.update_traffic(STEP)
	check(wall.v == 0.0 and absf(wall.d) <= crash.hw - 1.1 + 0.001, "the shoved car comes to rest on the road")

	# A crash into traffic that wrecks the racer is nobody's kill.
	var fatal := new_race({"traffic": {"parked": 1, "moving": 0}}, flat)
	var victim := fatal.player
	for c in fatal.cars:
		if c != victim:
			c.finished = true
	victim.progress = fatal.L + fatal.traffic[0].s - 8.0
	victim.s = flat.mod_s(victim.progress)
	victim.d = fatal.traffic[0].d
	victim.v = 55.0
	victim.health = 1.0
	var wreck_events := []
	for i in 60:
		fatal.physics(victim, STEP)
		fatal.update_traffic(STEP)
		fatal.collisions(STEP)
		wreck_events.append_array(fatal.take_events().filter(func(e: Dictionary) -> bool: return e.t == "wreck"))
	check(wreck_events.size() == 1 and wreck_events[0].car == victim and wreck_events[0].by == null, "a wreck on traffic credits no one")
	check(fatal.traffic[0].fans == 0.0 and fatal.traffic[0].hits == 0, "traffic scores nothing")

	# Weapons ignore traffic: it is scenery to the combat rules.
	var shots := new_race({"traffic": {"parked": 1, "moving": 0}}, flat)
	var target := shots.traffic[0]
	shots.projs.append({"id": 9001, "kind": "bolt", "owner": shots.player, "s": target.s, "d": target.d, "dir": 1.0, "speed": 0.0, "life": 2.0, "target": null})
	shots.update_projs(STEP)
	check(shots.take_events().all(func(e: Dictionary) -> bool: return e.t != "hit") and target.health == target.max_hp, "shots do not strike traffic")

	# Whole races: the bots steer around the traffic and still finish close
	# to their traffic-free times.
	var open_road := run_race(new_race({}))
	var crowded := run_race(new_race({"traffic": FULL}))
	check(open_road.times.all(func(t: float) -> bool: return t < INF), "the traffic-free race finishes")
	check(crowded.times.all(func(t: float) -> bool: return t < INF), "every bot finishes a race through traffic")
	check(open_road.bumps == 0, "no traffic contact without traffic")
	print("TRAFFIC race: winner %.2f s clear, %.2f s through traffic; %d traffic contacts, %d crash wrecks" % [open_road.times[0], crowded.times[0], crowded.bumps, crowded.wrecks])
	check(float(crowded.times[0]) < float(open_road.times[0]) * 1.06, "traffic costs the winner under 6% of the race")
	check(float(crowded.times[-1]) < float(open_road.times[-1]) * 1.12, "traffic does not strand the last car")
	check(crowded.wrecks <= open_road.wrecks + 1, "bots do not wreck themselves on traffic")
	var again := run_race(new_race({"traffic": FULL}))
	check(again.times == crowded.times and again.bumps == crowded.bumps, "a race through traffic replays exactly")

	if failures == 0:
		print("TRAFFIC: placement, lanes, footprint contact, bot avoidance and replay passed")
	get_tree().quit(1 if failures else 0)
