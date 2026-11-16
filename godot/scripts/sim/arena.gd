class_name Arena
extends RefCounted
## Points mode: free driving in a walled square, no track. Ram the others for
## points; quick hits in a row build a multiplier; a wreck pays a bonus. The
## highest score when the clock runs out wins. Node-free and deterministic,
## fixed 60 Hz steps, like Race. Port of the legacy src/035_arena.js, without
## its projectile weapons: the pickups here are the ones a car uses on itself.

# The square is a rounded rectangle with a round island in the middle.
const HALF_X := 120.0
const HALF_Z := 84.0
const CORNER := 26.0
const ISLAND := 12.5
const PADS := [[-92, -56], [0, -64], [92, -56], [-92, 56], [0, 64], [92, 56], [-60, 0], [60, 0],
	[-96, 0], [96, 0], [-38, -36], [38, 36], [-38, 36], [38, -36], [0, -32], [0, 32]]
const PICKUPS := {"ram": 14, "nitro": 12, "shield": 8, "repair": 8}
const SPEED := 0.74              # top speeds are scaled down for the square
const HIT_SPEED := 4.0           # closing speed that counts as a hit
const HIT_POINTS := 14           # points per m/s of closing speed
const PAIR_COOLDOWN := 0.6       # the same two cars cannot score again at once
const COMBO_WINDOW := 4.0
const COMBO_STEP := 3            # hits per multiplier step
const COMBO_MAX := 5
const WRECK_POINTS := 300
const RAM_TIME := 1.6
const NITRO_TIME := 2.6
const SHIELD_TIME := 8.0
const WRECK_TIME := 2.4

var arena := true
var opt := {}
var diff: Dictionary
var rng := RandomNumberGenerator.new()
var time := 0.0
var time_limit := 120.0
var over := false
var started := false
var events: Array = []
var cars: Array[ArenaCar] = []
var order: Array[ArenaCar] = []
var pickups: Array = []
var player: ArenaCar = null
var _pair_t := {}
var _next_id := 1
var _weight_sum := 0.0


## opt keys: time (seconds), diff (0..2), seed, driver (index), player_car
## (id), no_player.
func _init(p_opt: Dictionary) -> void:
	opt = p_opt
	diff = Data.DIFFS[clampi(int(opt.get("diff", 1)), 0, 2)]
	rng.seed = int(opt.get("seed", 1234))
	time_limit = float(opt.get("time", 120.0))
	var no_player := bool(opt.get("no_player", false))
	var driver := -1 if no_player else int(opt.get("driver", 0))
	var rivals := Data.rivals_of(driver, rng)
	var roster: Array = []
	if not no_player:
		roster.append(Data.DRIVERS[clampi(driver, 0, Data.DRIVERS.size() - 1)])
	roster.append_array(rivals)
	var player_def: Dictionary = Data.car(str(opt.get("player_car", Data.CARS[0].id)))
	for i in roster.size():
		var is_player := not no_player and i == 0
		var def: Dictionary = player_def if is_player else Data.CARS[rng.randi() % Data.CARS.size()]
		var c := ArenaCar.new(i, def, str(roster[i].name), is_player, Color.html(str(roster[i].col)))
		# Spread round the island, facing it: the first seconds are a charge.
		var angle := float(i) / roster.size() * TAU + 0.6
		c.x = sin(angle) * (HALF_X - 26.0)
		c.z = cos(angle) * (HALF_Z - 22.0)
		c.h = atan2(c.x, -c.z)
		c.bot = {"target_id": -1, "retarget_t": 0.0, "back_t": 0.0, "back_steer": 1.0, "stuck_t": 0.0, "item_t": 0.0,
			"skill": 0.95 + rng.randf() * 0.1, "react": 0.8 + rng.randf() * 0.5}
		if is_player:
			player = c
		cars.append(c)
	for kind in PICKUPS:
		_weight_sum += float(PICKUPS[kind])
	for pad in PADS:
		pickups.append({"id": _nid(), "x": float(pad[0]), "z": float(pad[1]), "type": _pick_type(), "alive": true, "t": 0.0})
	compute_order()


func _nid() -> int:
	_next_id += 1
	return _next_id - 1


func _pick_type() -> String:
	var roll := rng.randf() * _weight_sum
	for kind in PICKUPS:
		roll -= float(PICKUPS[kind])
		if roll <= 0.0:
			return kind
	return "ram"


func emit(e: Dictionary) -> void:
	events.append(e)


func take_events() -> Array:
	var out := events
	events = []
	return out


func compute_order() -> void:
	order = cars.duplicate()
	order.sort_custom(func(a: ArenaCar, b: ArenaCar) -> bool: return a.score > b.score if a.score != b.score else a.id < b.id)
	for i in order.size():
		order[i].place = i + 1


func car_by_id(id: int) -> ArenaCar:
	return cars[id] if id >= 0 and id < cars.size() else null


func leader() -> ArenaCar:
	return order[0] if not order.is_empty() else null


func time_left() -> float:
	return maxf(0.0, time_limit - time)


## Signed distance to the outer wall (positive inside) and the outward normal
## at the nearest wall point.
static func wall(p: Vector2) -> Dictionary:
	var inner := Vector2(HALF_X - CORNER, HALF_Z - CORNER)
	var nearest := Vector2(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y))
	var out := p - nearest
	var distance := out.length()
	if distance > 0.000001:
		return {"d": CORNER - distance, "n": out / distance}
	var to_x := HALF_X - absf(p.x)
	var to_z := HALF_Z - absf(p.y)
	if to_x < to_z:
		return {"d": to_x, "n": Vector2(1.0 if p.x >= 0.0 else -1.0, 0.0)}
	return {"d": to_z, "n": Vector2(0.0, 1.0 if p.y >= 0.0 else -1.0)}


func step(dt: float) -> void:
	time += dt
	if not over and started and time >= time_limit:
		over = true
		emit({"t": "timeup"})
	for c in cars:
		c.vmax_mul = 1.0 if c.is_player else float(diff.speed) * float(c.bot.skill)
	for c in cars:
		if not c.is_player or c.autopilot:
			ai_drive(c, dt)
	for c in cars:
		physics(c, dt)
	# Two passes settle a pile of cars without visible overlap.
	collide(true)
	collide(false)
	for c in cars:
		walls(c)
	for c in cars:
		if c.ctrl.cycle:
			c.ctrl.cycle = false
			if c.slots.size() > 1:
				c.slots.push_back(c.slots.pop_front())
				emit({"t": "cycle", "car": c})
		if c.ctrl.select > 0:
			var k := c.ctrl.select
			c.ctrl.select = 0
			if k < c.slots.size():
				var item = c.slots[k]
				c.slots.remove_at(k)
				c.slots.push_front(item)
				emit({"t": "cycle", "car": c})
		if not c.ctrl.discard.is_empty():
			var held := c.slots.find(c.ctrl.discard)
			c.ctrl.discard = {}
			if held >= 0:
				emit({"t": "discard", "car": c, "type": c.slots[held].type})
				c.slots.remove_at(held)
		if c.ctrl.fire or c.ctrl.back:
			c.ctrl.fire = false
			c.ctrl.back = false
			use_item(c)
		c.ctrl.boost = false
	update_pickups(dt)
	compute_order()


func physics(c: ArenaCar, dt: float) -> void:
	c.invuln_t = maxf(0.0, c.invuln_t - dt)
	c.scrape = maxf(0.0, c.scrape - dt * 3.0)
	c.shield_t = maxf(0.0, c.shield_t - dt)
	c.nitro_t = maxf(0.0, c.nitro_t - dt)
	c.ram_t = maxf(0.0, c.ram_t - dt)
	c.stun_t = maxf(0.0, c.stun_t - dt)
	if c.hop > 0.0 or c.hop_v > 0.0:
		c.hop_v -= 30.0 * dt
		c.hop += c.hop_v * dt
		if c.hop <= 0.0:
			c.hop = 0.0
			c.hop_v = 0.0
	if c.wreck_t > 0.0:
		c.wreck_t -= dt
		c.vx *= exp(-3.0 * dt)
		c.vz *= exp(-3.0 * dt)
		c.x += c.vx * dt
		c.z += c.vz * dt
		if c.wreck_t <= 0.0:
			respawn(c)
		return
	var def := c.def
	var f := c.forward()
	var r := c.right()
	var velocity := Vector2(c.vx, c.vz)
	var vf := velocity.dot(f)
	var vl := velocity.dot(r)
	var steer_in := c.ctrl.steer
	var gas := c.ctrl.gas
	var brake := c.ctrl.brake
	if not started or over:
		gas = false
		brake = true
		steer_in = 0.0
	if c.spin_t > 0.0:
		c.spin_t -= dt
		steer_in = 0.0
		gas = false
		brake = false
	var boost := 1.45 if c.ram_t > 0.0 else (1.35 if c.nitro_t > 0.0 else 1.0)
	var vmax: float = float(def.vmax) * SPEED * c.vmax_mul * boost * (0.55 if c.stun_t > 0.0 else 1.0)
	var acc: float = float(def.acc) * 1.15 * (2.6 if c.ram_t > 0.0 else (2.1 if c.nitro_t > 0.0 else 1.0))
	var drifting := brake and absf(c.steer) > 0.35 and vf > 12.0
	c.drift = minf(1.0, c.drift + dt * 4.0) if drifting else maxf(0.0, c.drift - dt * 3.0)
	if gas and not (brake and not drifting):
		if vf < vmax:
			var share := maxf(0.0, vf / vmax)
			vf = minf(vmax, vf + acc * (1.0 - 0.75 * share * share) * dt * (2.2 if vf < 0.0 else 1.0))
	elif brake:
		if drifting:
			vf -= 5.0 * dt
		elif vf > 0.5:
			vf = maxf(0.0, vf - 30.0 * dt)
		elif started and not over:
			vf = maxf(-13.0, vf - 14.0 * dt)  # hold to reverse
		else:
			vf = move_toward(vf, 0.0, 30.0 * dt)
	else:
		vf = move_toward(vf, 0.0, (2.2 + absf(vf) * 0.03) * dt)
	if vf > vmax * 1.02:
		vf -= (vf - vmax) * 2.0 * dt
	# Tight at parking speed, calmer flat out; reversing flips it like a real car.
	var rate := 6.0 if c.is_player and not c.autopilot else 9.0
	c.steer += clampf(steer_in - c.steer, -rate * dt, rate * dt)
	var speed := absf(vf)
	var turn: float = clampf(speed / 4.5, 0.0, 1.0) * (2.9 - 1.2 * clampf(speed / vmax, 0.0, 1.0)) * float(def.grip) * (1.0 + c.drift * 0.45)
	# +steer is the driver's right, as in a race; here that lowers the heading.
	c.h += (-c.steer * turn * (-1.0 if vf < -0.3 else 1.0) + c.spin_rate) * dt
	c.spin_rate *= exp(-3.2 * dt)
	# Grip eats sideways speed; less of it while drifting.
	vl *= exp(-(9.5 - 6.8 * c.drift) * float(def.grip) * dt)
	f = c.forward()
	r = c.right()
	velocity = f * vf + r * vl
	c.vx = velocity.x
	c.vz = velocity.y
	c.x += c.vx * dt
	c.z += c.vz * dt
	c.v = vf
	c.lat = vl
	c.braking = brake and not drifting and vf > 1.0
	c.gas_on = gas


func collide(impulses: bool) -> void:
	for i in cars.size():
		var a := cars[i]
		if a.wreck_t > 0.0:
			continue
		for j in range(i + 1, cars.size()):
			var b := cars[j]
			if b.wreck_t > 0.0 or absf(a.x - b.x) > 7.0 or absf(a.z - b.z) > 7.0:
				continue
			var best := 0.0
			var normal := Vector2.ZERO
			var point := Vector2.ZERO
			var reach := ArenaCar.BODY_RADIUS * 2.0
			for p: Vector2 in a.circles():
				for q: Vector2 in b.circles():
					var between := q - p
					var distance := between.length()
					if reach - distance > best:
						best = reach - distance
						normal = between / distance if distance > 0.00001 else Vector2(1.0, 0.0)
						point = p + normal * ArenaCar.BODY_RADIUS
			if best <= 0.0:
				continue
			var ma: float = a.def.mass
			var mb: float = b.def.mass
			var total := ma + mb
			a.x -= normal.x * best * (mb / total)
			a.z -= normal.y * best * (mb / total)
			b.x += normal.x * best * (ma / total)
			b.z += normal.y * best * (ma / total)
			if not impulses:
				continue
			var va := Vector2(a.vx, a.vz).dot(normal)
			var vb := Vector2(b.vx, b.vz).dot(normal)
			if vb - va >= 0.0:
				continue
			var closing := va - vb
			var impulse := 1.32 * closing / (1.0 / ma + 1.0 / mb)
			a.vx -= normal.x * impulse / ma
			a.vz -= normal.y * impulse / ma
			b.vx += normal.x * impulse / mb
			b.vz += normal.y * impulse / mb
			# Off-centre hits turn the car round.
			var arm_a := point - a.at()
			var arm_b := point - b.at()
			a.spin_rate += arm_a.cross(-normal) * impulse * 0.11 / ma
			b.spin_rate += arm_b.cross(normal) * impulse * 0.11 / mb
			if closing > 2.0:
				emit({"t": "bump", "a": a, "b": b, "x": point.x, "z": point.y, "imp": closing})
			# Who rammed whom: the car driving into the contact harder.
			var attacker := a if va >= -vb else b
			score_hit(attacker, b if attacker == a else a, closing, point)


## A hit is contact at real closing speed. The rammer scores, times its combo.
func score_hit(attacker: ArenaCar, victim: ArenaCar, closing: float, point: Vector2) -> void:
	if over or not started or closing < HIT_SPEED:
		return
	var key := mini(attacker.id, victim.id) * 100 + maxi(attacker.id, victim.id)
	if _pair_t.has(key) and time - float(_pair_t[key]) < PAIR_COOLDOWN:
		return
	_pair_t[key] = time
	# A ram charge doubles the points, hits far harder, throws the victim
	# away and costs the rammer nothing. A shield takes the blow instead.
	var ram := attacker.ram_t > 0.0
	var guarded := victim.shield_t > 0.0 or victim.invuln_t > 0.0
	var gain := award(attacker, victim, roundi(closing * HIT_POINTS) * (2 if ram else 1))
	var dir := (victim.at() - attacker.at()).normalized()
	emit({"t": "score", "car": attacker, "victim": victim, "pts": gain, "combo": attacker.combo, "imp": closing,
		"ram": ram, "x": point.x, "z": point.y, "dir": dir, "guarded": guarded})
	if guarded:
		return
	var dmg := maxf(0.0, closing - 8.0) * 1.9 * (2.5 if ram else 1.0) + (12.0 if ram else 0.0)
	if ram:
		victim.vx += dir.x * 16.0
		victim.vz += dir.y * 16.0
		victim.hop_v = maxf(victim.hop_v, 6.0)
		victim.spin_rate += (-4.0 if rng.randf() < 0.5 else 4.0)
	if dmg > 0.0:
		damage(victim, dmg)
		if not ram and attacker.shield_t <= 0.0:
			damage(attacker, dmg * 0.25)
	if closing > 16.0:
		victim.hop_v = maxf(victim.hop_v, minf(7.0, closing * 0.3))


## Points for a hit, times the attacker's multiplier: +1 for every COMBO_STEP
## hits landed within COMBO_WINDOW of each other, up to COMBO_MAX.
func award(attacker: ArenaCar, victim: ArenaCar, base: int) -> int:
	if time - attacker.combo_t > COMBO_WINDOW:
		attacker.combo_n = 0
	attacker.combo_n += 1
	attacker.combo_t = time
	attacker.combo = mini(COMBO_MAX, 1 + attacker.combo_n / COMBO_STEP)
	var gain := base * attacker.combo
	attacker.score += gain
	attacker.hits_n += 1
	attacker.hits += 1
	victim.last_hit_id = attacker.id
	victim.last_hit_t = time
	return gain


func damage(c: ArenaCar, dmg: float) -> void:
	if c.wreck_t > 0.0 or c.invuln_t > 0.0:
		return
	c.health -= dmg
	if c.health <= 0.0:
		wreck(c)


func wreck(c: ArenaCar) -> void:
	c.health = 0.0
	c.wreck_t = WRECK_TIME
	c.wrecks += 1
	c.combo_n = 0
	c.combo = 1
	c.drift = 0.0
	c.ram_t = 0.0
	c.nitro_t = 0.0
	c.shield_t = 0.0
	var by: ArenaCar = car_by_id(c.last_hit_id) if time - c.last_hit_t < 4.0 else null
	var points := 0
	if by != null and by != c and not over:
		points = WRECK_POINTS * by.combo
		by.score += points
		by.kills += 1
	emit({"t": "wreck", "car": c, "by": by, "pts": points, "x": c.x, "z": c.z})


## Back in play at the free spot furthest from everybody, facing the middle.
func respawn(c: ArenaCar) -> void:
	var best := Vector2(HALF_X - 30.0, 0.0)
	var best_room := -1.0
	for attempt in 14:
		var spot := Vector2((rng.randf() * 2.0 - 1.0) * (HALF_X - 14.0), (rng.randf() * 2.0 - 1.0) * (HALF_Z - 14.0))
		if spot.length() < ISLAND + 12.0 or float(wall(spot).d) < 8.0:
			continue
		var room := INF
		for o in cars:
			if o != c and o.wreck_t <= 0.0:
				room = minf(room, o.at().distance_to(spot))
		if room > best_room:
			best_room = room
			best = spot
	c.x = best.x
	c.z = best.y
	c.h = atan2(best.x, -best.y)
	c.vx = 0.0
	c.vz = 0.0
	c.spin_rate = 0.0
	c.v = 0.0
	c.steer = 0.0
	c.health = c.max_hp
	c.invuln_t = 2.5
	c.last_hit_id = -1
	emit({"t": "respawn", "car": c, "x": c.x, "z": c.z})


func walls(c: ArenaCar) -> void:
	if c.wreck_t > 0.0:
		return
	for p: Vector2 in c.circles():
		var outer := wall(p)
		if float(outer.d) < ArenaCar.BODY_RADIUS:
			bounce(c, outer.n, ArenaCar.BODY_RADIUS - float(outer.d))
		var from_centre := p.length()
		var limit := ISLAND + ArenaCar.BODY_RADIUS
		if from_centre < limit:
			bounce(c, -p / from_centre if from_centre > 0.00001 else Vector2(1.0, 0.0), limit - from_centre)


## Push out along -n (n points into the obstacle) and reflect the speed into it.
func bounce(c: ArenaCar, n: Vector2, depth: float) -> void:
	c.x -= n.x * depth
	c.z -= n.y * depth
	var into := Vector2(c.vx, c.vz).dot(n)
	if into <= 0.0:
		return
	c.vx = (c.vx - n.x * into * 1.3) * 0.94
	c.vz = (c.vz - n.y * into * 1.3) * 0.94
	c.scrape = maxf(c.scrape, minf(1.0, into / 14.0 + 0.25))
	if into > 13.0 and c.ram_t <= 0.0:
		damage(c, (into - 13.0) * 1.2)
	if into > 4.0:
		emit({"t": "wall", "car": c, "imp": into, "x": c.x + n.x * 1.4, "z": c.z + n.y * 1.4, "dir": -n})


func update_pickups(dt: float) -> void:
	for p in pickups:
		if not p.alive:
			p.t -= dt
			if p.t <= 0.0:
				p.alive = true
				p.type = _pick_type()
				emit({"t": "pickup_back", "p": p})
			continue
		for c in cars:
			if c.slots.size() >= 3 or c.wreck_t > 0.0:
				continue
			if c.at().distance_to(Vector2(p.x, p.z)) < 2.9:
				p.alive = false
				p.t = 2.0
				c.slots.append({"type": p.type, "ammo": 1})
				emit({"t": "pickup", "car": c, "type": p.type, "p": p, "slot": c.slots.size() - 1})
				break


func has_pickup_room(c: CarState) -> bool:
	return c.slots.size() < 3


## The same answer shape as Race.item_status, so the touch controls and the
## HUD can ask either mode.
func item_status(c: CarState, backward := false, kind := "") -> Dictionary:
	var why := ""
	if kind.is_empty():
		kind = c.slot_type()
	if not started:
		why = "not_started"
	elif over:
		why = "finished"
	elif c.wreck_t > 0.0:
		why = "wreck"
	elif c.spin_t > 0.0:
		why = "spin"
	elif kind.is_empty():
		why = "empty"
	elif backward:
		why = "direction"
	elif kind == "repair" and c.health >= c.max_hp * 0.97:
		why = "full"
	elif kind == "shield" and c.shield_t > 0.1:
		why = "shield_active"
	elif kind == "nitro" and c.nitro_t > 0.1:
		why = "nitro_active"
	elif kind == "ram" and (c as ArenaCar).ram_t > 0.1:
		why = "nitro_active"
	return {"ready": why.is_empty(), "reason": why, "target": null, "kind": kind, "back": backward}


## The drift boost belongs to the races; there is none on the square.
func boost_status(_c: CarState) -> String:
	return "charge"


func use_item(c: ArenaCar) -> void:
	var status := item_status(c)
	if not bool(status.ready):
		if str(status.reason) != "empty":
			emit({"t": "denied", "car": c, "why": status.reason})
		return
	var kind: String = c.slots[0].type
	match kind:
		"ram":
			c.ram_t = RAM_TIME
		"nitro":
			c.nitro_t = NITRO_TIME
		"shield":
			c.shield_t = SHIELD_TIME
		"repair":
			c.health = c.max_hp
	c.slots.pop_front()
	emit({"t": "fire", "car": c, "type": kind, "back": false, "x": c.x, "z": c.z})


## The best victim in front: close and well lined up.
func aim_at(c: ArenaCar, reach: float, min_dot: float) -> ArenaCar:
	var best: ArenaCar = null
	var best_score := -INF
	for o in cars:
		if o == c or o.wreck_t > 0.0:
			continue
		var to := o.at() - c.at()
		var distance := to.length()
		if distance > reach:
			continue
		var lined := to.dot(c.forward()) / maxf(distance, 0.001)
		if lined < min_dot:
			continue
		var value := lined * 2.0 - distance / reach
		if value > best_score:
			best_score = value
			best = o
	return best


# ---------------------------------------------------------------- AI
## Pick a victim, lead it, ram it, back off when stuck, repeat.
func ai_drive(c: ArenaCar, dt: float) -> void:
	if c.wreck_t > 0.0:
		return
	var bot := c.bot
	bot.retarget_t = float(bot.retarget_t) - dt
	var target := car_by_id(int(bot.target_id))
	if target == null or target.wreck_t > 0.0 or float(bot.retarget_t) <= 0.0:
		var best: ArenaCar = null
		var best_cost := INF
		for o in cars:
			if o == c or o.wreck_t > 0.0 or o.invuln_t > 0.5:
				continue
			var to := o.at() - c.at()
			var distance := to.length()
			var front := to.dot(c.forward()) / maxf(distance, 0.001)
			# Close and in front is best; the leader and the player are juicier.
			var cost := distance * (1.6 - front * 0.6) * (0.8 + rng.randf() * 0.5) * (0.85 if o == order[0] else 1.0) * (0.9 if o.is_player else 1.0)
			if cost < best_cost:
				best_cost = cost
				best = o
		target = best
		bot.target_id = best.id if best != null else -1
		bot.retarget_t = (2.2 + rng.randf() * 2.8) * float(diff.react) * float(bot.react)
	if float(bot.back_t) > 0.0:
		bot.back_t = float(bot.back_t) - dt
		c.ctrl.gas = false
		c.ctrl.brake = true
		c.ctrl.steer = float(bot.back_steer)
		return
	if started and absf(c.v) < 2.2:
		bot.stuck_t = float(bot.stuck_t) + dt
		if float(bot.stuck_t) > 0.7:
			bot.stuck_t = 0.0
			bot.back_t = 0.8 + rng.randf() * 0.4
			bot.back_steer = -1.0 if rng.randf() < 0.5 else 1.0
			return
	else:
		bot.stuck_t = 0.0
	# Aim where the target will be.
	var goal := Vector2.ZERO
	if target != null:
		var distance := target.at().distance_to(c.at())
		var lead := clampf(distance / maxf(10.0, absf(c.v) + 6.0), 0.0, 1.1)
		goal = target.at() + Vector2(target.vx, target.vz) * lead
	# Nothing much in hand and a pickup close by: take it on the way.
	if c.slots.size() < 2:
		var pad = null
		var pad_distance := 22.0 if not c.slots.is_empty() else 38.0
		for p in pickups:
			if not p.alive:
				continue
			var distance := c.at().distance_to(Vector2(p.x, p.z))
			if distance < pad_distance:
				pad_distance = distance
				pad = p
		if pad != null and (target == null or pad_distance < target.at().distance_to(c.at()) * 0.8):
			goal = Vector2(pad.x, pad.z)
	# Go round the island instead of into it.
	var path := goal - c.at()
	var along := clampf(-c.at().dot(path) / maxf(path.length_squared(), 1.0), 0.0, 1.0)
	var closest := c.at() + path * along
	if along > 0.02 and along < 0.98 and closest.length() < ISLAND + 5.0:
		goal = closest * ((ISLAND + 10.0) / maxf(closest.length(), 0.5)) if closest.length() > 0.5 else closest + Vector2(-path.y, path.x) * 0.3
	# About to meet the wall at speed: turn for the middle.
	var soon := wall(c.at() + Vector2(c.vx, c.vz) * 0.9)
	if float(soon.d) < 5.0 and absf(c.v) > 10.0:
		goal = c.at() - (soon.n as Vector2) * 30.0
	var to_goal := goal - c.at()
	var want := atan2(-to_goal.x, to_goal.y)
	var off := wrapf(want - c.h, -PI, PI)
	# A higher heading is to the driver's left, so steering is the negative.
	c.ctrl.steer = clampf(-off * 2.4, -1.0, 1.0)
	c.ctrl.gas = true
	c.ctrl.brake = absf(off) > 1.9 and c.v > 12.0  # hard about-turn: brake into a drift
	bot.item_t = float(bot.item_t) - dt
	if float(bot.item_t) <= 0.0:
		bot.item_t = (0.35 + rng.randf() * 0.6) * float(diff.react) * float(bot.react)
		ai_items(c)


func ai_items(c: ArenaCar) -> void:
	if c.slots.is_empty() or not started or over:
		return
	var roll := rng.randf()
	var target := car_by_id(int(c.bot.target_id))
	var use := false
	match str(c.slots[0].type):
		"ram":
			use = target != null and target == aim_at(c, 45.0, 0.85) and roll < 0.9
		"nitro":
			use = target != null and target.at().distance_to(c.at()) > 22.0 and target == aim_at(c, 90.0, 0.9) and roll < 0.8
		"shield":
			use = (c.health < c.max_hp * 0.5 and roll < 0.25) or roll < 0.04
		"repair":
			use = c.health < c.max_hp * 0.45
	if use:
		use_item(c)
	elif c.slots.size() >= 2 and roll > 0.9:
		c.slots.push_back(c.slots.pop_front())
