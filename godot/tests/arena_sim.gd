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
	# The chase camera looks along +z here, so the screen's right is world -x.
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 3, -10), Vector3(0, 0, 0), Vector3.UP)
	var screen_right := Vector2(camera.global_transform.basis.x.x, camera.global_transform.basis.x.z)
	camera.free()
	check(screen_right.is_equal_approx(Vector2(-1.0, 0.0)), "facing +z, the screen's right is world -x")
	check(Vector2(p.vx, p.vz).dot(screen_right) > 1.0 and p.forward().dot(screen_right) > 0.2, "steering right turns the car to the right of the screen")
	var straight := ArenaCar.new(0, Data.CARS[0], "", false, Color.WHITE)
	check(straight.right().is_equal_approx(screen_right), "right() is the screen's right")
	place(p, Vector2(0.0, -50.0), 0.0, 20.0)
	p.ctrl.steer = -1.0
	run(arena, 0.6)
	check(p.forward().dot(screen_right) < -0.2, "steering left turns the other way")
	# A bot heads for its target instead of circling away from it.
	var chaser := new_arena()
	var bot: ArenaCar = chaser.cars.filter(func(c: ArenaCar) -> bool: return not c.is_player)[0]
	park(chaser, [bot, chaser.player])
	bot.is_player = false
	chaser.player.is_player = true
	place(bot, Vector2(-60.0, -60.0), 0.0, 10.0)
	place(chaser.player, Vector2(60.0, -60.0), 0.0, 0.0)
	chaser.player.invuln_t = 0.0
	bot.slots = [{"type": "repair", "ammo": 1}, {"type": "repair", "ammo": 1}]  # no detour for pickups
	bot.bot.target_id = chaser.player.id
	bot.bot.retarget_t = 99.0
	var gap_before := bot.at().distance_to(chaser.player.at())
	for i in 180:
		chaser.ai_drive(bot, STEP)
		chaser.physics(bot, STEP)
	check(bot.at().distance_to(chaser.player.at()) < gap_before - 30.0, "a bot drives toward its target")
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
	check(gains.slice(0, 2) == [100, 100] and gains[2] == 200 and gains[5] == 300, "the multiplier rises every third hit")
	check(gains[8] == 300 and gains[15] == 300 and p.combo == Arena.COMBO_MAX and Arena.COMBO_MAX == 3, "the multiplier stops at x3")
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
	check(bool(arena.item_status(p).ready) and not bool(arena.item_status(p, true).ready), "the ram charge is used forward only")
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

	# Weapons.
	check(Arena.PICKUPS.size() >= 10 and Arena.PICKUPS.keys().all(func(k: String) -> bool: return Data.has_pw(k) and PowerupIcons.texture(k) != null and Data.has_text("pw.%s.name" % k)), "ten and more pickups, each with an icon and a name")
	check(Arena.BACKWARDS == ["eagle", "bolt", "mine", "oil"] and not Arena.BACKWARDS.has("nitro"), "only throwing weapons go backwards; nitro never does")
	var duel := func() -> Arena:
		var sim := new_arena()
		park(sim, [sim.player, sim.cars[1]])
		sim.cars[1].is_player = true
		place(sim.player, Vector2(0.0, -60.0), 0.0, 0.0)
		place(sim.cars[1], Vector2(0.0, -30.0), 0.0, 0.0)  # 30 m ahead
		sim.take_events()
		return sim
	for weapon in ["bolt", "eagle", "cluster"]:
		var sim: Arena = duel.call()
		sim.player.slots = [{"type": weapon, "ammo": 1}]
		sim.player.ctrl.fire = true
		var flight := run(sim, 2.0)
		var hits := of(flight, "hit")
		check(hits.size() >= 1 and hits[0].car == sim.cars[1] and hits[0].by == sim.player, "%s fired forward hits the car ahead" % weapon)
		check(int(hits[0].pts) == int(Arena.WEAPON_POINTS[weapon]) and sim.player.score >= int(Arena.WEAPON_POINTS[weapon]), "%s scores its few points" % weapon)
		check(of(flight, "boom").size() >= 1 and sim.projs.is_empty(), "%s bursts and is gone" % weapon)
	var back_shot: Arena = duel.call()
	place(back_shot.cars[1], Vector2(0.0, -90.0), 0.0, 0.0)  # now behind
	back_shot.player.slots = [{"type": "bolt", "ammo": 3}]
	back_shot.player.ctrl.back = true
	var back_hits := of(run(back_shot, 1.0), "hit")
	check(back_hits.size() == 1 and back_hits[0].car == back_shot.cars[1] and int(back_shot.player.slots[0].ammo) == 2, "a bolt fired backwards hits the car behind, one shot of three")
	var refused: Arena = duel.call()
	refused.player.slots = [{"type": "nitro", "ammo": 1}]
	refused.player.ctrl.back = true
	run(refused, 0.1)
	check(refused.player.slots.size() == 1 and refused.player.nitro_t == 0.0, "nitro cannot be used backwards")
	var mined: Arena = duel.call()
	mined.player.slots = [{"type": "mine", "ammo": 1}]
	mined.player.ctrl.back = true
	run(mined, 0.1)
	check(mined.mines.size() == 1 and Vector2(mined.mines[0].x, mined.mines[0].z).distance_to(Vector2(0.0, -64.0)) < 0.5, "a mine is dropped behind")
	mined.cars[1].x = mined.mines[0].x
	mined.cars[1].z = mined.mines[0].z
	var blast := run(mined, 0.6)
	check(of(blast, "hit").size() == 1 and mined.cars[1].stun_t > 0.0 and mined.mines.is_empty(), "a mine goes off under a car")
	var oiled: Arena = duel.call()
	oiled.player.slots = [{"type": "oil", "ammo": 1}]
	oiled.player.ctrl.back = true
	run(oiled, 0.1)
	oiled.cars[1].x = oiled.mines[0].x
	oiled.cars[1].z = oiled.mines[0].z
	var spun := run(oiled, 0.6)
	check(of(spun, "slip").size() == 1 and oiled.cars[1].health == oiled.cars[1].max_hp and oiled.mines.size() == 1, "oil spins a car without damage and stays put")
	var spun_again := run(oiled, 0.6)
	check(of(spun_again, "slip").is_empty(), "the same car slips on one slick only once")
	var waved: Arena = duel.call()
	place(waved.cars[1], Vector2(0.0, -52.0), 0.0, 0.0)
	waved.player.slots = [{"type": "barge", "ammo": 1}]
	waved.player.ctrl.fire = true
	run(waved, 0.05)
	check(Vector2(waved.cars[1].vx, waved.cars[1].vz).y > 10.0, "the shockwave throws close cars away")
	var stormy: Arena = duel.call()
	stormy.cars[1].score = 500
	stormy.compute_order()
	stormy.player.slots = [{"type": "shock", "ammo": 1}]
	stormy.player.ctrl.fire = true
	run(stormy, 0.05)
	check(stormy.domes.size() == 3, "the storm drops three domes by the leader")
	stormy.player.slots = [{"type": "shock", "ammo": 1}]
	stormy.player.score = 1000
	stormy.compute_order()
	check(stormy.item_status(stormy.player).reason == "first", "the leader cannot call a storm")
	var guarded: Arena = duel.call()
	guarded.cars[1].shield_t = 5.0
	guarded.player.slots = [{"type": "bolt", "ammo": 1}]
	guarded.player.ctrl.fire = true
	var stopped := run(guarded, 1.0)
	check(of(stopped, "blocked").size() == 1 and guarded.cars[1].health == guarded.cars[1].max_hp and guarded.player.score == 0, "a shield stops a weapon, for no points")

	# A whole round with bots at every wheel.
	var round := new_arena({"time": 120.0, "no_player": true})
	var total_events := run(round, 121.0)
	var scores := round.order.map(func(c: ArenaCar) -> int: return c.score)
	print("ARENA round: scores %s, %d hits, %d wrecks, %d pickups" % [scores, of(total_events, "score").size(), of(total_events, "wreck").size(), of(total_events, "pickup").size()])
	check(round.over and round.cars.all(func(c: ArenaCar) -> bool: return inside(c) or c.wreck_t > 0.0), "every car ends the round inside the square")
	check(round.cars.all(func(c: ArenaCar) -> bool: return c.score > 0), "every bot lands at least one hit")
	var weapon_hits := of(total_events, "hit").size()
	check(weapon_hits >= 10, "bots use the weapons (%d weapon hits)" % weapon_hits)
	check(scores[0] < 2000 and scores[0] > 50, "scores stay modest: the winner has %d" % scores[0])
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
