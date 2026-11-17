class_name Arena
extends RefCounted
## Points mode: free driving in a walled square, no track. Ram the others for
## points; quick hits in a row build a multiplier; a wreck pays a bonus. The
## highest score when the clock runs out wins. Node-free and deterministic,
## fixed 60 Hz steps, like Race. Port of the legacy src/035_arena.js, without
## its projectile weapons: the pickups here are the ones a car uses on itself.

# The square is a rounded rectangle with a round island in the middle. It is
# half as large again in area as the legacy square (each side x1.225).
const HALF_X := 147.0
const HALF_Z := 103.0
const CORNER := 32.0
const ISLAND := 15.0
const PADS := [[-113, -69], [0, -78], [113, -69], [-113, 69], [0, 78], [113, 69], [-73, 0], [73, 0],
	[-118, 0], [118, 0], [-47, -44], [47, 44], [-47, 44], [47, -44], [0, -39], [0, 39],
	[-80, -40], [80, 40], [-80, 40], [80, -40], [0, -92], [0, 92]]
# Pickup weights. Ram, nitro, shield and repair act on the car itself; the
# rest are weapons. Eagle, bolt, mine and oil can also go backwards.
const PICKUPS := {"ram": 10, "nitro": 9, "shield": 7, "repair": 6, "eagle": 9, "bolt": 10,
	"cluster": 8, "barge": 8, "mine": 8, "oil": 8, "shock": 5}
const BACKWARDS := ["eagle", "bolt", "mine", "oil"]
const SPEED := 0.74              # top speeds are scaled down for the square
const HIT_SPEED := 4.0           # closing speed that counts as a hit
const HIT_POINTS := 1            # points per m/s of closing speed
const PAIR_COOLDOWN := 0.6       # the same two cars cannot score again at once
const COMBO_WINDOW := 4.0
const COMBO_STEP := 3            # hits per multiplier step
const COMBO_MAX := 3
const WRECK_POINTS := 50
# Points for landing a weapon, before the multiplier.
const WEAPON_POINTS := {"eagle": 30, "bolt": 10, "cluster": 6, "barge": 15, "mine": 20, "oil": 10, "shock": 15}
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
var projs: Array = []            # eagles, bolts, cluster darts in flight
var mines: Array = []            # mines and oil slicks on the ground
var domes: Array = []            # storm domes
var player: ArenaCar = null
const SKIP_HASH := ["events", "player", "cars", "order", "opt", "diff"]
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
		var car_name := str(roster[i].get("name", Data.PLAYER_FALLBACK_NAME))
		if is_player and not str(opt.get("player_name", "")).is_empty():
			car_name = str(opt.player_name)
		var c := ArenaCar.new(i, def, car_name, is_player, Color.html(str(roster[i].col)))
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


## Lockstep desync check (plan 7.1): a digest of everything the next tick
## depends on. Peers with the same inputs must agree on it every tick.
func state_hash() -> int:
	var buf := StreamPeerBuffer.new()
	StateHash.expand(buf, self, SKIP_HASH)
	for c in cars:
		StateHash.expand(buf, c, ["def"])
		StateHash.write(buf, str(c.def.get("id", "")))
	for c in order:
		buf.put_64(c.id)
	pass
	return StateHash.digest(buf)


## Applies one tick of input to car `index` from Ctrl.pack() bytes, as a
## lockstep peer would; local input goes through the same path so every peer
## sees the same quantised values.
func apply_packed(index: int, bytes: PackedByteArray) -> void:
	var c: CarState = cars[index]
	c.ctrl.unpack(bytes, c.slots)


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
		if c.ctrl.fire:
			c.ctrl.fire = false
			use_item(c, false)
		if c.ctrl.back:
			c.ctrl.back = false
			use_item(c, true)
		c.ctrl.boost = false
	update_pickups(dt)
	update_projs(dt)
	update_mines(dt)
	update_domes(dt)
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
	# +steer is the driver's right, as in a race. Seen from the chase camera a
	# higher heading turns the car to the right of the screen.
	c.h += (c.steer * turn * (-1.0 if vf < -0.3 else 1.0) + c.spin_rate) * dt
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
				c.slots.append({"type": p.type, "ammo": int(Data.PW[p.type].ammo) if Data.PW.has(p.type) else 1})
				emit({"t": "pickup", "car": c, "type": p.type, "p": p, "slot": c.slots.size() - 1})
				break


func has_pickup_room(c: CarState) -> bool:
	return c.slots.size() < 3


## Whether an item can be used backwards (the lower fire button).
func has_back(kind: String) -> bool:
	return kind in BACKWARDS


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
	elif backward and not has_back(kind):
		why = "direction"
	elif kind == "repair" and c.health >= c.max_hp * 0.97:
		why = "full"
	elif kind == "shield" and c.shield_t > 0.1:
		why = "shield_active"
	elif kind == "nitro" and c.nitro_t > 0.1:
		why = "nitro_active"
	elif kind == "ram" and (c as ArenaCar).ram_t > 0.1:
		why = "nitro_active"
	elif kind == "shock" and leader() == c:
		why = "first"
	return {"ready": why.is_empty(), "reason": why, "target": null, "kind": kind, "back": backward}


## The drift boost belongs to the races; there is none on the square.
func boost_status(_c: CarState) -> String:
	return "charge"


func use_item(c: ArenaCar, back := false) -> void:
	var status := item_status(c, back)
	if not bool(status.ready):
		if str(status.reason) != "empty":
			emit({"t": "denied", "car": c, "why": status.reason})
		return
	var item: Dictionary = c.slots[0]
	var kind: String = item.type
	var f := c.forward() * (-1.0 if back else 1.0)
	var used := true
	match kind:
		"ram":
			c.ram_t = RAM_TIME
		"nitro":
			c.nitro_t = NITRO_TIME
		"shield":
			c.shield_t = SHIELD_TIME
		"repair":
			c.health = c.max_hp
		"eagle":
			# Homes on the best victim that way, or anyone in front.
			var target := aim_at(c, 90.0 if back else 220.0, 0.1, back)
			if target == null and not back:
				target = aim_at(c, 400.0, -1.0)
			var speed := maxf(absf(c.v) + 22.0, 42.0)
			_shoot(c, "eagle", f * 3.5, f * speed, target, 6.0)
		"bolt":
			_shoot(c, "bolt", f * 3.0, f * (maxf(c.v * (-1.0 if back else 1.0), 0.0) + 80.0), null, 1.3)
			item.ammo = int(item.ammo) - 1
			used = int(item.ammo) <= 0
		"cluster":
			var speed := maxf(c.v, 0.0) + 72.0
			for i in range(-2, 3):
				var dir := Vector2(-sin(c.h + i * 0.13), cos(c.h + i * 0.13))
				_shoot(c, "cluster", dir * 3.0, dir * speed, null, 1.2)
		"barge":
			# A shockwave: everybody close is thrown away from you.
			for o in cars:
				if o == c or o.wreck_t > 0.0:
					continue
				var away := o.at() - c.at()
				var distance := maxf(away.length(), 0.001)
				if distance < 15.0:
					var force := 1.0 - distance / 15.0
					hit(o, c, "barge", 12.0 + 12.0 * force, {"slow": 0.9, "push": away / distance * (12.0 + 14.0 * force)})
			emit({"t": "barge", "car": c, "x": c.x, "z": c.z})
		"mine", "oil":
			var drop := {"id": _nid(), "kind": kind, "owner_id": c.id, "x": c.x, "z": c.z, "vx": 0.0, "vz": 0.0,
				"fly": 0.0, "life": 40.0 if kind == "mine" else 14.0, "arm": 0.4, "born": time, "hit": {}}
			if back:
				drop.x -= c.forward().x * 4.0
				drop.z -= c.forward().y * 4.0
			else:
				# Thrown ahead, landing a moment later.
				var throw := c.forward() * (maxf(c.v, 8.0) + 24.0)
				drop.x += c.forward().x * 3.0
				drop.z += c.forward().y * 3.0
				drop.vx = throw.x
				drop.vz = throw.y
				drop.fly = 0.65
			mines.append(drop)
			if mines.size() > 20:
				mines.pop_front()
		"shock":
			# Three electric domes where the leader is heading.
			var lead := leader()
			var aim := lead.at() + Vector2(lead.vx, lead.vz) * 1.1
			for n in 3:
				var angle := rng.randf() * TAU
				var spread := 0.0 if n == 0 else 6.0 + rng.randf() * 5.0
				var spot := aim + Vector2(cos(angle), sin(angle)) * spread
				var room := wall(spot)
				if float(room.d) < 5.0:
					spot -= (room.n as Vector2) * (5.0 - float(room.d))
				domes.append({"id": _nid(), "owner_id": c.id, "x": spot.x, "z": spot.y, "r": 4.8, "warn": 0.9, "life": 7.0, "hit": {}})
			emit({"t": "shock", "car": c, "target": lead})
	if used:
		c.slots.pop_front()
	emit({"t": "fire", "car": c, "type": kind, "back": back, "x": c.x, "z": c.z})


func _shoot(c: ArenaCar, kind: String, offset: Vector2, velocity: Vector2, target: ArenaCar, life: float) -> void:
	projs.append({"id": _nid(), "kind": kind, "owner_id": c.id, "x": c.x + offset.x, "z": c.z + offset.y,
		"vx": velocity.x, "vz": velocity.y, "target_id": target.id if target != null else -1, "life": life})


## A weapon landing on `o`. Shields and the respawn grace block it; points go
## to the car that used it.
func hit(o: ArenaCar, by: ArenaCar, kind: String, dmg: float, fx: Dictionary) -> bool:
	if o.wreck_t > 0.0:
		return false
	if o.shield_t > 0.0 or o.invuln_t > 0.0:
		emit({"t": "blocked", "car": o, "by": by, "kind": kind, "x": o.x, "z": o.z})
		return false
	if fx.get("spin", false):
		o.spin_t = 1.0
		o.spin_rate += (-7.0 if rng.randf() < 0.5 else 7.0)
		o.vx *= 0.35
		o.vz *= 0.35
		o.hop_v = maxf(o.hop_v, float(fx.get("hop", 0.0)))
	if fx.has("slow"):
		o.vx *= float(fx.slow)
		o.vz *= float(fx.slow)
	if fx.has("stun"):
		o.stun_t = maxf(o.stun_t, float(fx.stun))
	if fx.has("hop"):
		o.hop_v = maxf(o.hop_v, float(fx.hop))
	if fx.has("push"):
		o.vx += (fx.push as Vector2).x
		o.vz += (fx.push as Vector2).y
	var points := 0
	if by != null and by != o and not over:
		points = award(by, o, int(WEAPON_POINTS.get(kind, 10)))
	var from := (o.at() - by.at()).normalized() if by != null and by != o else Vector2.ZERO
	emit({"t": "hit", "car": o, "by": by, "kind": kind, "dmg": dmg, "pts": points, "combo": by.combo if by != null else 1, "x": o.x, "z": o.z, "dir": from})
	if dmg > 0.0:
		damage(o, dmg)
	return true


func update_projs(dt: float) -> void:
	for i in range(projs.size() - 1, -1, -1):
		var p: Dictionary = projs[i]
		p.life = float(p.life) - dt
		var owner := car_by_id(int(p.owner_id))
		var target := car_by_id(int(p.target_id))
		if target != null and target.wreck_t > 0.0:
			target = null
		if p.kind == "eagle":
			# Turns toward its target and keeps a little faster than it.
			var velocity := Vector2(p.vx, p.vz)
			var heading := velocity.angle()
			if target != null:
				var wanted := (target.at() - Vector2(p.x, p.z)).angle()
				heading += clampf(wrapf(wanted - heading, -PI, PI), -3.4 * dt, 3.4 * dt)
			var speed := minf(velocity.length() + 40.0 * dt, maxf(50.0, Vector2(target.vx, target.vz).length() + 18.0 if target != null else 50.0))
			velocity = Vector2.from_angle(heading) * speed
			p.vx = velocity.x
			p.vz = velocity.y
		p.x = float(p.x) + float(p.vx) * dt
		p.z = float(p.z) + float(p.vz) * dt
		var at := Vector2(p.x, p.z)
		var done := false
		for o in cars:
			if o == owner or o.wreck_t > 0.0 or o.at().distance_to(at) > 2.5:
				continue
			if p.kind == "eagle":
				hit(o, owner, "eagle", 34.0, {"spin": true, "hop": 7.0})
			else:
				var push := Vector2(p.vx, p.vz).normalized() * 4.0
				hit(o, owner, str(p.kind), 9.0 if p.kind == "cluster" else 11.0, {"slow": 0.86, "push": push})
			emit({"t": "boom", "kind": p.kind, "x": p.x, "z": p.z})
			done = true
			break
		if not done and (float(wall(at).d) < 0.4 or at.length() < ISLAND):
			emit({"t": "boom", "kind": p.kind, "x": p.x, "z": p.z})
			done = true
		if not done and float(p.life) <= 0.0:
			emit({"t": "fizzle", "kind": p.kind, "x": p.x, "z": p.z})
			done = true
		if done:
			projs.remove_at(i)


func update_mines(dt: float) -> void:
	for i in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[i]
		if float(m.fly) > 0.0:
			m.fly = float(m.fly) - dt
			m.x = float(m.x) + float(m.vx) * dt
			m.z = float(m.z) + float(m.vz) * dt
			var room := wall(Vector2(m.x, m.z))
			if float(room.d) < 1.5:
				m.x = float(m.x) - (room.n as Vector2).x * (1.5 - float(room.d))
				m.z = float(m.z) - (room.n as Vector2).y * (1.5 - float(room.d))
				m.fly = 0.0
			continue
		m.life = float(m.life) - dt
		m.arm = float(m.arm) - dt
		if float(m.life) <= 0.0:
			mines.remove_at(i)
			continue
		if float(m.arm) > 0.0:
			continue
		var owner := car_by_id(int(m.owner_id))
		for o in cars:
			if (o == owner and time - float(m.born) < 2.5) or o.wreck_t > 0.0 or m.hit.has(o.id):
				continue
			if o.at().distance_to(Vector2(m.x, m.z)) < (2.3 if m.kind == "mine" else 3.2):
				if m.kind == "mine":
					hit(o, owner, "mine", 26.0, {"hop": 7.5, "slow": 0.5, "stun": 1.0})
					emit({"t": "boom", "kind": "mine", "x": m.x, "z": m.z})
					mines.remove_at(i)
					break
				# Oil stays where it is and spins every car once.
				m.hit[o.id] = true
				hit(o, owner, "oil", 0.0, {"spin": true})
				emit({"t": "slip", "car": o, "x": m.x, "z": m.z})


func update_domes(dt: float) -> void:
	for i in range(domes.size() - 1, -1, -1):
		var dm: Dictionary = domes[i]
		if float(dm.warn) > 0.0:
			dm.warn = float(dm.warn) - dt
			continue
		dm.life = float(dm.life) - dt
		if float(dm.life) <= 0.0:
			domes.remove_at(i)
			continue
		for o in cars:
			if dm.hit.has(o.id) or o.wreck_t > 0.0:
				continue
			if o.at().distance_to(Vector2(dm.x, dm.z)) < float(dm.r):
				dm.hit[o.id] = true
				hit(o, car_by_id(int(dm.owner_id)), "shock", 20.0, {"stun": 2.2, "slow": 0.6})
				emit({"t": "zap", "car": o, "x": o.x, "z": o.z})


## The best victim in front (or behind): close and well lined up.
func aim_at(c: ArenaCar, reach: float, min_dot: float, back := false) -> ArenaCar:
	var best: ArenaCar = null
	var best_score := -INF
	var ahead := c.forward() * (-1.0 if back else 1.0)
	for o in cars:
		if o == c or o.wreck_t > 0.0:
			continue
		var to := o.at() - c.at()
		var distance := to.length()
		if distance > reach:
			continue
		var lined := to.dot(ahead) / maxf(distance, 0.001)
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
	# A higher heading is to the driver's right, so steer toward it directly.
	c.ctrl.steer = clampf(off * 2.4, -1.0, 1.0)
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
	var aim := float(diff.aim)
	var target := car_by_id(int(c.bot.target_id))
	var use := false
	var back := false
	match str(c.slots[0].type):
		"ram":
			use = target != null and target == aim_at(c, 45.0, 0.85) and roll < 0.9
		"nitro":
			use = target != null and target.at().distance_to(c.at()) > 22.0 and target == aim_at(c, 90.0, 0.9) and roll < 0.8
		"shield":
			var threat := false
			for p in projs:
				if int(p.target_id) == c.id or (int(p.owner_id) != c.id and Vector2(p.x, p.z).distance_to(c.at()) < 25.0):
					threat = true
			use = threat or (c.health < c.max_hp * 0.5 and roll < 0.25) or roll < 0.04
		"repair":
			use = c.health < c.max_hp * 0.45
		"eagle":
			if aim_at(c, 180.0, 0.3) != null and roll < 0.8 * aim:
				use = true
			elif aim_at(c, 40.0, 0.5, true) != null and roll < 0.3:
				use = true
				back = true
		"bolt":
			use = aim_at(c, 55.0, 0.93) != null and roll < 0.9 * aim
		"cluster":
			use = aim_at(c, 60.0, 0.75) != null and roll < 0.85 * aim
		"barge":
			for o in cars:
				if o != c and o.wreck_t <= 0.0 and o.at().distance_to(c.at()) < 10.0:
					use = true
		"mine":
			if aim_at(c, 30.0, 0.5, true) != null and roll < 0.7:
				use = true
				back = true
			elif aim_at(c, 35.0, 0.8) != null and roll < 0.4:
				use = true
		"oil":
			if aim_at(c, 35.0, 0.5, true) != null and roll < 0.6:
				use = true
				back = true
		"shock":
			use = c.place > 1 and roll < 0.5
	if use:
		use_item(c, back)
	elif c.slots.size() >= 2 and roll > 0.9:
		c.slots.push_back(c.slots.pop_front())
