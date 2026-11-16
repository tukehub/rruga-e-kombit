extends Node
## Points mode simulation: free driving in the walled square, points for
## ramming, the combo multiplier, wrecks, pickups, the clock and the bots.

const STEP := 1.0 / 60.0

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func new_arena(opt := {}) -> Arena:
	var options := {"seed": 17, "time": 120.0}
	options.merge(opt, true)
	var arena := Arena.new(options)
	arena.started = true
	return arena

## Everybody out of the way in a corner region, standing still.
func park(arena: Arena, except: Array = []) -> void:
	var slot := 0
	for c in arena.cars:
		if c in except:
			continue
		c.x = -100.0 + slot * 9.0
		c.z = 70.0
		c.vx = 0.0
		c.vz = 0.0
		c.autopilot = false
		c.is_player = true  # no AI: the car just sits there
		slot += 1

func place(c: ArenaCar, at: Vector2, heading: float, speed: float) -> void:
	c.x = at.x
	c.z = at.y
	c.h = heading
	var v := c.forward() * speed
	c.vx = v.x
	c.vz = v.y
	c.v = speed

func of(events: Array, kind: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e.t == kind)

func run(arena: Arena, seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / STEP):
		arena.step(STEP)
		events.append_array(arena.take_events())
	return events

func inside(c: ArenaCar) -> bool:
	for p: Vector2 in c.circles():
		if float(Arena.wall(p).d) < ArenaCar.BODY_RADIUS - 0.05 or p.length() < Arena.ISLAND + ArenaCar.BODY_RADIUS - 0.05:
			return false
	return true

func snapshot(arena: Arena) -> Array:
	var out := []
	for c in arena.cars:
		out.append([c.x, c.z, c.h, c.score, c.health, c.slots.size()])
	return out

func _ready() -> void:
	# The square: walls, corners and the island.
	check(is_equal_approx(float(Arena.wall(Vector2.ZERO).d), Arena.HALF_Z), "the centre is half a square from the nearest wall")
	check(is_equal_approx(float(Arena.wall(Vector2(Arena.HALF_X - 3.0, 0.0)).d), 3.0) and Arena.wall(Vector2(Arena.HALF_X - 3.0, 0.0)).n == Vector2(1.0, 0.0), "the side wall is where it should be, normal pointing out")
	check(float(Arena.wall(Vector2(Arena.HALF_X + 2.0, 0.0)).d) < 0.0, "outside the wall the distance is negative")
	var corner := Vector2(Arena.HALF_X - 1.0, Arena.HALF_Z - 1.0)
	check(float(Arena.wall(corner).d) < 0.0, "the corners are rounded off")
	for pad in Arena.PADS:
		var at := Vector2(float(pad[0]), float(pad[1]))
		check(float(Arena.wall(at).d) > 8.0 and at.length() > Arena.ISLAND + 8.0, "every pickup pad is on open ground")

	# The start: everybody on the square, facing the island, standings set.
	var arena := new_arena()
	check(arena.cars.size() == 6 and arena.player != null and arena.player.is_player, "six cars, one of them the player's")
	check(arena.pickups.size() == Arena.PADS.size() and arena.pickups.all(func(p: Dictionary) -> bool: return Arena.PICKUPS.has(p.type)), "one known pickup on every pad")
	for c in arena.cars:
		check(inside(c), "%s starts inside the square" % c.name)
		check(c.forward().dot(-c.at().normalized()) > 0.99, "%s starts facing the middle" % c.name)
	var places := arena.cars.map(func(c: ArenaCar) -> int: return c.place)
	places.sort()
	check(places == [1, 2, 3, 4, 5, 6], "everyone has a place from the start")

	# Before the start nothing moves, whatever the pedals say.
	arena = new_arena()
	arena.started = false
	for c in arena.cars:
		c.ctrl.gas = true
	var before := snapshot(arena)
	run(arena, 1.0)
	check(snapshot(arena) == before and arena.time > 0.9, "cars hold still until the start")

	# Driving: gas, steering sides, brake, reverse.
	arena = new_arena()
	var p := arena.player
	park(arena, [p])
	place(p, Vector2(0.0, -50.0), 0.0, 0.0)  # facing +z
	p.ctrl.gas = true
	run(arena, 2.0)
	check(p.v > 12.0 and p.z > -50.0 + 10.0 and absf(p.x) < 0.01, "gas drives the car straight ahead")
	p.ctrl.steer = 1.0
	run(arena, 0.6)
	check(Vector2(p.vx, p.vz).dot(Vector2(-1.0, 0.0)) < -1.0 and p.forward().x > 0.2, "steering right turns toward the driver's right")
	check(is_equal_approx(p.right().dot(Vector2(1.0, 0.0)), cos(p.h)) and Vector2(0.0, 1.0).cross(Vector2(1.0, 0.0)) < 0.0, "right is clockwise seen from above")
	place(p, Vector2(0.0, -50.0), 0.0, 20.0)
	p.ctrl.steer = -1.0
	run(arena, 0.6)
	check(p.forward().x < -0.2, "steering left turns the other way")
	p.ctrl.steer = 0.0
	p.ctrl.gas = false
	p.ctrl.brake = true
	run(arena, 1.5)
	check(p.v < 0.0 and p.v >= -13.01, "holding the brake stops, then reverses, up to a limit")
	var top: float = float(p.def.vmax) * Arena.SPEED
	place(p, Vector2(-80.0, -50.0), -PI * 0.5, 0.0)  # facing +x, a long run
	p.ctrl.brake = false
	p.ctrl.gas = true
	run(arena, 6.0)
	check(p.v > top * 0.85 and p.v <= top * 1.03, "top speed on the square is the scaled-down one (%.1f of %.1f)" % [p.v, top])

	# Walls and the island keep the cars in, without eating all the speed.
	arena = new_arena()
	p = arena.player
	park(arena, [p])
	place(p, Vector2(Arena.HALF_X - 12.0, 0.0), -PI * 0.5, 20.0)
	var events := run(arena, 1.5)
	check(inside(p) and of(events, "wall").size() >= 1, "the wall stops a car and reports the impact")
	check(of(events, "wall")[0].dir.x < -0.9, "the wall impact points back into the square")
	place(p, Vector2(0.0, -30.0), 0.0, 15.0)
	p.ctrl.gas = true
	run(arena, 2.0)
	check(inside(p) and p.at().length() >= Arena.ISLAND, "the island cannot be driven through")
	p.ctrl.gas = false
	arena = new_arena()
	p = arena.player
	park(arena, [p])
	p.health = 5.0
	place(p, Vector2(Arena.HALF_X - 8.0, 0.0), -PI * 0.5, 30.0)
	events = run(arena, 0.6)
	check(of(events, "wreck").size() == 1 and of(events, "wreck")[0].by == null and of(events, "wreck")[0].pts == 0, "a wall can wreck a weak car, to nobody's credit")

	# A ram: the car driving in scores, by closing speed.
	arena = new_arena()
	p = arena.player
	var victim: ArenaCar = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	park(arena, [p, victim])
	victim.is_player = true
	place(victim, Vector2(0.0, -40.0), -PI * 0.5, 0.0)   # side on
	place(p, Vector2(0.0, -52.0), 0.0, 20.0)
	events = run(arena, 0.5)
	var scored := of(events, "score")
	check(scored.size() == 1 and scored[0].car == p and scored[0].victim == victim, "the car that drives in is the one that scores")
	if scored.size() == 1:
		var closing: float = scored[0].imp
		check(closing > 12.0 and int(scored[0].pts) == roundi(closing * Arena.HIT_POINTS) and p.score == int(scored[0].pts), "points follow the closing speed (%.1f m/s, %d points)" % [closing, int(scored[0].pts)])
		check(scored[0].dir.y > 0.9 and not bool(scored[0].ram), "the hit reports its direction")
	check(victim.health < victim.max_hp and p.health < p.max_hp and (p.max_hp - p.health) < (victim.max_hp - victim.health), "a hard hit hurts the victim more than the rammer")
	check(victim.score == 0 and victim.last_hit_id == p.id and p.hits_n == 1, "being hit scores nothing")
	check(p.place == 1 and arena.leader() == p, "the scorer leads the standings")
	check(absf(p.z - victim.z) > 0.0 and p.at().distance_to(victim.at()) > ArenaCar.BODY_RADIUS, "the cars do not end up inside each other")
	# A nudge is not a hit.
	arena = new_arena()
	p = arena.player
	victim = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	park(arena, [p, victim])
	victim.is_player = true
	place(victim, Vector2(0.0, -40.0), -PI * 0.5, 0.0)
	place(p, Vector2(0.0, -46.0), 0.0, 2.5)
	events = run(arena, 1.0)
	check(of(events, "score").is_empty() and p.score == 0, "a slow nudge scores nothing")

	# Combo: every third hit inside the window raises the multiplier, to a cap.
	arena = new_arena()
	p = arena.player
	victim = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	var gains := []
	for i in 16:
		arena.time += 1.0
		gains.append(arena.award(p, victim, 100))
	check(gains.slice(0, 2) == [100, 100] and gains[2] == 200 and gains[5] == 300 and gains[8] == 400, "the multiplier rises every third hit")
	check(gains[11] == 500 and gains[15] == 500 and p.combo == Arena.COMBO_MAX, "the multiplier stops at its cap")
	arena.time += Arena.COMBO_WINDOW + 0.1
	check(arena.award(p, victim, 100) == 100 and p.combo == 1, "a pause longer than the window resets the combo")
	# The same pair cannot score again within the cooldown.
	arena = new_arena()
	p = arena.player
	victim = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	arena.score_hit(p, victim, 10.0, Vector2.ZERO)
	arena.score_hit(p, victim, 10.0, Vector2.ZERO)
	check(p.hits_n == 1, "one contact is one hit")
	arena.time += Arena.PAIR_COOLDOWN + 0.01
	arena.score_hit(p, victim, 10.0, Vector2.ZERO)
	check(p.hits_n == 2, "the pair can score again after the cooldown")

	# Wrecks: the last car to hit gets the bonus; the wreck returns, protected.
	arena = new_arena()
	p = arena.player
	victim = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	park(arena, [p, victim])
	victim.is_player = true
	victim.health = 4.0
	place(victim, Vector2(0.0, -40.0), -PI * 0.5, 0.0)
	place(p, Vector2(0.0, -52.0), 0.0, 22.0)
	events = run(arena, 0.5)
	var wrecks := of(events, "wreck")
	check(wrecks.size() == 1 and wrecks[0].car == victim and wrecks[0].by == p and int(wrecks[0].pts) == Arena.WRECK_POINTS, "a wreck pays its bonus to the car that caused it")
	check(p.kills == 1 and victim.wrecks == 1 and victim.wreck_t > 0.0, "the wreck is counted on both sides")
	events = run(arena, Arena.WRECK_TIME + 0.2)
	check(of(events, "respawn").size() == 1 and victim.wreck_t <= 0.0 and victim.health == victim.max_hp and victim.invuln_t > 1.0, "a wrecked car comes back whole and briefly protected")
	check(inside(victim) and victim.at().distance_to(p.at()) > 20.0, "it comes back on open ground, away from the others")
	var hp := victim.health
	arena.score_hit(p, victim, 30.0, victim.at())
	check(victim.health == hp, "a protected car takes no damage")

	# Pickups: collected by driving over, used on the car itself, back later.
	arena = new_arena()
	p = arena.player
	park(arena, [p])
	var pad: Dictionary = arena.pickups[6]
	pad.type = "ram"
	place(p, Vector2(float(pad.x), float(pad.z) - 6.0), 0.0, 10.0)
	events = run(arena, 0.8)
	check(of(events, "pickup").size() == 1 and p.slots.size() == 1 and p.slot_type() == "ram" and not bool(pad.alive), "driving over a pad collects its pickup")
	check(bool(arena.item_status(p).ready) and not bool(arena.item_status(p, true).ready), "a pickup is used forward only")
	events = run(arena, 2.2)
	check(bool(pad.alive) and of(events, "pickup_back").size() == 1, "the pad refills")
	p.ctrl.fire = true
	events = run(arena, 0.05)
	check(p.ram_t > 1.0 and p.slots.is_empty() and of(events, "fire").size() == 1, "the ram charge starts when fired")
	check(arena.item_status(p).reason == "empty", "an empty hand says so")
	p.slots = [{"type": "repair", "ammo": 1}, {"type": "shield", "ammo": 1}, {"type": "nitro", "ammo": 1}]
	check(arena.item_status(p).reason == "full" and not arena.has_pickup_room(p), "repair is refused at full health, three items is a full hand")
	p.ctrl.cycle = true
	run(arena, 0.05)
	check(p.slot_type() == "shield", "cycling brings the next item up")
	p.ctrl.fire = true
	run(arena, 0.05)
	check(p.shield_t > 7.0 and arena.item_status(p, false, "shield").reason == "shield_active", "the shield goes up once")
	p.ctrl.fire = true
	run(arena, 0.05)
	check(p.nitro_t > 2.0, "nitro fires")
	p.health = 10.0
	p.ctrl.fire = true
	run(arena, 0.05)
	check(p.health == p.max_hp and p.slots.is_empty(), "repair restores the car")
	check(arena.boost_status(p) != "", "there is no drift boost on the square")
	# Ram charge: double points, the victim thrown, the rammer unhurt.
	var plain := new_arena()
	var charged := new_arena()
	var results := []
	for sim: Arena in [plain, charged]:
		var a := sim.player
		var b: ArenaCar = sim.cars.filter(func(c: ArenaCar) -> bool: return c != a)[0]
		park(sim, [a, b])
		b.is_player = true  # no AI: it stands still
		place(b, Vector2(0.0, -40.0), -PI * 0.5, 0.0)
		place(a, Vector2(0.0, -52.0), 0.0, 20.0)
		if sim == charged:
			a.ram_t = 1.0
		var hit := of(run(sim, 0.6), "score")
		results.append({"pts": int(hit[0].pts) if hit.size() == 1 else -1, "imp": float(hit[0].imp) if hit.size() == 1 else 0.0, "a": a, "b": b, "ram": hit.size() == 1 and bool(hit[0].ram)})
	check(results[1].ram and results[1].pts == roundi(float(results[1].imp) * Arena.HIT_POINTS) * 2, "a ram charge doubles the points")
	check(results[1].a.health == results[1].a.max_hp and results[0].a.health < results[0].a.max_hp, "the charging car takes no damage from its own hit")
	check(results[1].b.health < results[0].b.health, "a charged hit does more damage")
	# A shield takes the blow: points still, no damage.
	arena = new_arena()
	p = arena.player
	victim = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	victim.shield_t = 5.0
	arena.score_hit(p, victim, 30.0, victim.at())
	check(victim.health == victim.max_hp and p.score > 0, "a shielded car is hit for points but not for damage")

	# The clock: time up ends the scoring and stops the cars.
	arena = new_arena({"time": 2.0})
	events = run(arena, 2.5)
	check(arena.over and of(events, "timeup").size() == 1 and arena.time_left() == 0.0, "the clock runs out once")
	p = arena.player
	victim = arena.cars.filter(func(c: ArenaCar) -> bool: return c != p)[0]
	var frozen := p.score
	arena.score_hit(p, victim, 30.0, victim.at())
	check(p.score == frozen, "nothing scores after time is up")
	run(arena, 3.0)
	check(arena.cars.all(func(c: ArenaCar) -> bool: return absf(c.v) < 0.5), "the cars come to rest after time is up")
	check(not bool(arena.item_status(p, false, "ram").ready), "items are refused after time is up")

	# A whole round with bots at every wheel.
	var round := new_arena({"time": 120.0, "no_player": true})
	var total_events := run(round, 121.0)
	var scores := round.order.map(func(c: ArenaCar) -> int: return c.score)
	print("ARENA round: scores %s, %d hits, %d wrecks, %d pickups" % [scores, of(total_events, "score").size(), of(total_events, "wreck").size(), of(total_events, "pickup").size()])
	check(round.over and round.cars.all(func(c: ArenaCar) -> bool: return inside(c) or c.wreck_t > 0.0), "every car ends the round inside the square")
	check(round.cars.all(func(c: ArenaCar) -> bool: return c.score > 0), "every bot lands at least one hit")
	check(of(total_events, "score").size() >= 40 and of(total_events, "wreck").size() >= 2 and of(total_events, "pickup").size() >= 10, "a round is busy: hits, wrecks and pickups")
	var sorted := scores.duplicate()
	sorted.sort()
	sorted.reverse()
	check(scores == sorted and round.order[0].place == 1, "the final order is by score")
	check(round.cars.all(func(c: ArenaCar) -> bool: return is_finite(c.x) and is_finite(c.h)), "the simulation stays finite")
	for difficulty in 3:
		var short := new_arena({"time": 30.0, "diff": difficulty, "seed": 40 + difficulty})
		run(short, 30.5)
		check(short.over and short.leader().score > 0, "a round plays out on difficulty %d" % difficulty)
	# Same seed, same round; another seed, another round.
	var replay_a := new_arena({"time": 20.0, "no_player": true})
	var replay_b := new_arena({"time": 20.0, "no_player": true})
	var other := new_arena({"time": 20.0, "no_player": true, "seed": 18})
	for sim: Arena in [replay_a, replay_b, other]:
		run(sim, 20.0)
	check(snapshot(replay_a) == snapshot(replay_b), "a round replays exactly from its seed")
	check(snapshot(replay_a) != snapshot(other), "another seed gives another round")

	if failures == 0:
		print("ARENA SIM: square, driving, rams, combo, wrecks, pickups, clock and bots passed")
	get_tree().quit(1 if failures else 0)
