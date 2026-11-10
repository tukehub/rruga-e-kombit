class_name Race
extends RefCounted
## Race simulation: physics on the (s, d) track frame, collisions, power-ups,
## bot AI, laps and standings. Pure logic, no nodes. Port of src/03_sim.js.
## Events are dictionaries with key "t" consumed by the presentation layer.

const FANS := {"eagle": 100, "bolt": 35, "barge": 50, "mine": 60, "shock": 70, "wreck": 150, "place": 15}
const BOT_ASSIST := 1.4

var track: RaceTrack
var L := 0.0
var hw := 10.0
var opt := {}
var laps := 2
var diff: Dictionary
var rng := RandomNumberGenerator.new()
var wet := false
var assist := 1.6
# Corner assist for the human driver: the car is slowed before tight bends to
# a speed its tyres can carry, because the brake pedal is out of reach while
# both thumbs hold gas and steering.
var brake_assist := false
# 1.0 is what the tyres hold on the centreline; the wide road lets a driver
# cut the bend, so a little more still clears the walls.
const CORNER_ASSIST_GRIP := 1.15
const CORNER_ASSIST_PLAN_DECEL := 9.0
const CORNER_ASSIST_DECEL := 10.0
const CORNER_ASSIST_MIN_SPEED := 10.0
var _assist_noted := false
var time := 0.0
var events: Array = []
var next_id := 1
var cars: Array[CarState] = []
var pickups: Array = []
var projs: Array = []
var mines: Array = []
var domes: Array = []
var order: Array[CarState] = []
var started := false
var player: CarState = null


## opt keys: laps, diff (0..2), seed, wet, assist (bool), driver (index),
## player_car (id), player_slot, no_player, bot_cars (optional Array of ids).
func _init(p_track: RaceTrack, p_opt: Dictionary) -> void:
	track = p_track
	L = track.L
	hw = track.half_w
	opt = p_opt
	laps = int(opt.get("laps", 2))
	diff = Data.DIFFS[clampi(int(opt.get("diff", 1)), 0, 2)]
	rng.seed = int(opt.get("seed", 1234))
	wet = bool(opt.get("wet", false))
	assist = 0.9 if opt.get("assist", true) == false else 1.6
	brake_assist = bool(opt.get("brake_assist", false))
	var no_player := bool(opt.get("no_player", false))
	var pi := -1 if no_player else int(opt.get("driver", 0))
	var rivals := Data.rivals_of(pi, rng)
	var n := rivals.size() if no_player else rivals.size() + 1
	var pslot := int(opt.get("player_slot", n - 2))
	var bot_cars: Array = opt.get("bot_cars", [])
	var bi := 0
	var player_def: Dictionary = Data.car(str(opt.get("player_car", Data.CARS[0].id)))
	for i in n:
		var row := i / 2
		var col := i % 2
		var c: CarState
		if i == pslot and not no_player:
			var drv: Dictionary = Data.DRIVERS[clampi(pi, 0, Data.DRIVERS.size() - 1)]
			c = CarState.new(i, player_def, drv.name, true, Color.html(drv.col))
			player = c
		else:
			var drv: Dictionary = rivals[bi]
			var cdef: Dictionary
			if bi < bot_cars.size():
				cdef = Data.car(bot_cars[bi])
			else:
				cdef = _pick_bot_car(player_def, bi)
			bi += 1
			c = CarState.new(i, cdef, drv.name, false, Color.html(drv.col))
		c.progress = -9.0 - row * 9.0 - col * 3.5
		c.s = track.mod_s(c.progress)
		c.d = 4.0 if col == 1 else -4.0
		c.ai.t = 1.0 + rng.randf()
		c.ai.plan_t = 0.0
		c.ai.v_t = 0.0
		c.ai.d_t = c.d
		c.ai.lane_bias = (rng.randf() - 0.5) * 4.0
		c.ai.line_amt = 0.6 + rng.randf() * 0.35
		c.ai.skill = 0.975 + rng.randf() * 0.05
		c.ai.react = 0.8 + rng.randf() * 0.5
		cars.append(c)
	# pick-up stations
	var n_st := clampi(roundi(L / 300.0), 5, 10)
	var wsum := 0.0
	for k in Data.PW_KEYS:
		wsum += Data.PW[k].w
	for k in n_st:
		var st := (k + 0.55) * L / n_st + (rng.randf() - 0.5) * 30.0
		for lane in [-6.5, 0.0, 6.5]:
			pickups.append({"id": _nid(), "s": track.mod_s(st), "d": lane, "type": _pick_type(wsum), "alive": true, "t": 0.0})
	compute_order()


## Bots drive every car except the player's, each at most twice.
func _pick_bot_car(player_def: Dictionary, bi: int) -> Dictionary:
	var pool: Array = []
	for c in Data.CARS:
		if c.id != player_def.id:
			pool.append(c)
	if pool.is_empty():
		return Data.CARS[0]
	return pool[(bi + int(rng.randi() % 2)) % pool.size()]


func _pick_type(wsum: float) -> String:
	var x := rng.randf() * wsum
	for k in Data.PW_KEYS:
		x -= Data.PW[k].w
		if x <= 0.0:
			return k
	return "nitro"


func _nid() -> int:
	next_id += 1
	return next_id - 1


func emit(e: Dictionary) -> void:
	events.append(e)


func take_events() -> Array:
	var ev := events
	events = []
	return ev


static func _order_cmp(a: CarState, b: CarState) -> bool:
	if a.finished and b.finished:
		return a.finish_time < b.finish_time
	if a.finished:
		return true
	if b.finished:
		return false
	return a.progress > b.progress


func compute_order() -> void:
	order = cars.duplicate()
	order.sort_custom(_order_cmp)
	for i in order.size():
		var c := order[i]
		var np := i + 1
		if started and c.place > 0 and np < c.place and not c.finished:
			c.fans += FANS.place * (c.place - np)
		c.place = np


func leader() -> CarState:
	for o in order:
		if not o.finished:
			return o
	return null


func all_finished() -> bool:
	for o in cars:
		if not o.finished:
			return false
	return true


func car_ahead(c: CarState, range_m: float) -> CarState:
	var best: CarState = null
	var bd := INF
	for o in cars:
		if o == c or o.finished:
			continue
		var g := o.progress - c.progress
		if g > 0.0 and g < range_m and g < bd:
			bd = g
			best = o
	return best


func car_behind(c: CarState, range_m: float) -> CarState:
	var best: CarState = null
	var bd := INF
	for o in cars:
		if o == c or o.finished:
			continue
		var g := c.progress - o.progress
		if g > 0.0 and g < range_m and g < bd:
			bd = g
			best = o
	return best


func step(dt: float) -> void:
	time += dt
	for c in cars:
		if not c.is_player or c.finished or c.autopilot:
			ai_drive(c, dt)
	for c in cars:
		physics(c, dt)
	collisions(dt)
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
				var it = c.slots[k]
				c.slots.remove_at(k)
				c.slots.push_front(it)
				emit({"t": "cycle", "car": c})
		if c.ctrl.fire:
			c.ctrl.fire = false
			use_item(c, false)
		if c.ctrl.back:
			c.ctrl.back = false
			use_item(c, true)
	update_pickups(dt)
	update_projs(dt)
	update_mines(dt)
	update_domes(dt)
	# laps
	for c in cars:
		var li := int(floor(c.progress / L))
		if li > c.lap:
			c.lap = li
			if li >= 1 and not c.finished:
				var lt := time - c.lap_start
				c.lap_times.append(lt)
				c.best_lap = minf(c.best_lap, lt)
				c.lap_start = time
				if li >= laps:
					c.finished = true
					c.finish_time = time
					c.fans += (9 - c.place) * 60
					emit({"t": "finish", "car": c})
				else:
					emit({"t": "lap", "car": c, "lap": li + 1})
	compute_order()
	# rubber band + difficulty (bots only)
	var has_ref := player != null and not player.finished
	var ref := player.progress if has_ref else 0.0
	for c in cars:
		if c.is_player:
			c.vmax_mul = 1.0
			continue
		var mul: float = diff.speed * c.ai.skill
		if has_ref:
			mul *= 1.0 + clampf(-(c.progress - ref) / 520.0, -0.05, 0.075)
		c.vmax_mul = mul


func physics(c: CarState, dt: float) -> void:
	var T := track
	var def := c.def
	var tirana_driver := c.is_player and not c.autopilot and T.id == "tirane"
	c.invuln_t = maxf(0.0, c.invuln_t - dt)
	c.shield_t = maxf(0.0, c.shield_t - dt)
	c.nitro_t = maxf(0.0, c.nitro_t - dt)
	c.stun_t = maxf(0.0, c.stun_t - dt)
	c.hbrake_t = maxf(0.0, c.hbrake_t - dt)
	c.scrape = maxf(0.0, c.scrape - dt * 3.0)
	if c.hop > 0.0 or c.hop_v > 0.0:
		c.hop_v -= 30.0 * dt
		c.hop += c.hop_v * dt
		if c.hop <= 0.0:
			c.hop = 0.0
			c.hop_v = 0.0
	if c.wreck_t > 0.0:
		c.wreck_t -= dt
		c.v *= exp(-3.0 * dt)
		c.progress += c.v * dt
		c.s = T.mod_s(c.progress)
		if c.wreck_t <= 0.0:
			c.health = c.max_hp
			c.yaw = 0.0
			c.lat_v = 0.0
			c.v = 10.0
			c.invuln_t = 2.5
			c.spin_t = 0.0
			c.stun_t = 0.0
			c.d = clampf(c.d, -5.0, 5.0)
			emit({"t": "respawn", "car": c})
		return
	var steer_in := c.ctrl.steer
	var gas := c.ctrl.gas
	var brake := c.ctrl.brake
	var v_before := c.v
	if not started:
		gas = false
		brake = true
		steer_in = 0.0
	if c.spin_t > 0.0:
		c.spin_t -= dt
		steer_in = 0.0
		gas = false
		brake = false
		c.v *= exp(-1.3 * dt)
	var vmax: float = def.vmax * c.vmax_mul
	if c.nitro_t > 0.0:
		vmax *= 1.3
	if c.stun_t > 0.0:
		vmax *= 0.55
	if c.health < c.max_hp * 0.25:
		vmax *= 0.95
	var acc: float = def.acc * (2.1 if c.nitro_t > 0.0 else 1.0)
	# Ramp pressure so braking takes effect progressively rather than as a jolt.
	c.brake_force = move_toward(c.brake_force, 1.0 if brake else 0.0, dt * 5.0)
	var drifting := brake and absf(c.steer) > 0.35 and c.v > 18.0
	c.drift = minf(1.0, c.drift + dt * 4.0) if drifting else maxf(0.0, c.drift - dt * 3.0)
	c.braking = brake and (not drifting or tirana_driver) and c.v > 1.0
	c.gas_on = gas and not (brake and tirana_driver)
	# On the Tirana pilot, braking takes priority even with both pedals held.
	if gas and not (brake and (tirana_driver or not drifting)):
		if c.v < vmax:
			var r := c.v / vmax
			c.v = minf(vmax, c.v + acc * (1.0 - 0.8 * r * r) * dt)
		else:
			c.v = maxf(vmax, c.v - 10.0 * dt)
	elif not brake:
		if c.v > 0.0:
			c.v = maxf(0.0, c.v - (1.5 + c.v * 0.025) * dt)
		else:
			c.v = minf(0.0, c.v + 3.0 * dt)
	if brake:
		if drifting:
			# Steering while braking should still slow the car decisively; retain
			# the pressure ramp so there is no one-frame braking jolt.
			if tirana_driver:
				c.v = maxf(0.0, c.v - 7.5 * c.brake_force * dt)
			else:
				c.v -= 4.5 * dt
		elif c.v > 0.5:
			c.v = maxf(0.0, c.v - 9.0 * c.brake_force * dt)
		elif started:
			c.v = maxf(-9.0, c.v - 10.0 * dt)
	if c.v > vmax * 1.02 and c.nitro_t <= 0.0:
		c.v -= (c.v - vmax) * 1.5 * dt
	if brake_assist and started and c.is_player and not c.autopilot and c.v > 8.0:
		var corner_grip: float = def.grip * (29.0 if tirana_driver else 22.0) * (0.93 if wet else 1.0) * CORNER_ASSIST_GRIP
		var v_corner := maxf(CORNER_ASSIST_MIN_SPEED, corner_speed(c.s, corner_grip, CORNER_ASSIST_PLAN_DECEL, c.v * c.v / (2.0 * CORNER_ASSIST_PLAN_DECEL) + 12.0))
		if c.v > v_corner:
			if c.v - v_corner > 0.5:
				# Brake lights and tyre noise show that the assist is working.
				c.braking = true
				if not _assist_noted:
					_assist_noted = true
					emit({"t": "assist_brake", "car": c})
			# Never gain speed above the limit, nitro included.
			c.v = maxf(v_corner, minf(c.v, v_before) - CORNER_ASSIST_DECEL * dt)
	# steering
	var rate := 12.0 if (c.is_player and not c.autopilot) else 8.0
	c.steer += clampf(steer_in - c.steer, -rate * dt, rate * dt)
	var v := c.v
	var av := maxf(absf(v), 1.0)
	# The dense Tirana street circuit has several very tight junctions. Give
	# the human driver a little more arcade cornering authority there while
	# keeping the existing speed and lateral-displacement bounds intact.
	var grip_accel := 29.0 if tirana_driver else 22.0
	var a_lat: float = def.grip * grip_accel * (1.0 + c.drift * 0.5) * (1.8 if c.hbrake_t > 0.0 else 1.0) * (0.93 if wet else 1.0)
	var c_max := minf(0.12, a_lat / (av * av))
	var cc := c.steer * c_max
	var k := T.curv(c.s)
	# Tight inside bends must not turn a small steering offset into a
	# near-threefold burst of track progress and camera speed.
	var dsdt := v * cos(c.yaw) / maxf(0.8, 1.0 - k * c.d)
	var asst: float
	if c.is_player and not c.autopilot:
		asst = assist * (1.5 if absf(c.steer) < 0.05 else 1.0)
	else:
		asst = BOT_ASSIST
	c.yaw += (cc * v - k * dsdt - asst * c.yaw * minf(1.0, av / 10.0)) * dt
	c.yaw = clampf(c.yaw, -1.25, 1.25)
	# Keep the car's direction and velocity aligned during ordinary turning.
	# A fixed 8 m/s lateral cap made the body point into a bend while its motion
	# was forced mostly straight ahead. Bound extreme headings instead, with a
	# speed-relative lateral limit; collisions may still add bounded tyre slip.
	var lateral_limit := maxf(1.0, absf(v) * 0.75)
	var max_motion_yaw := asin(minf(1.0, lateral_limit / maxf(absf(v), 0.001)))
	c.yaw = clampf(c.yaw, -max_motion_yaw, max_motion_yaw)
	var lateral_speed := clampf(v * sin(c.yaw) + c.lat_v, -lateral_limit, lateral_limit)
	var longitudinal_step := v * cos(c.yaw) * dt
	var s_step := longitudinal_step / maxf(0.8, 1.0 - k * c.d)
	var lateral_step := lateral_speed * dt
	# The stored curvature is smoothed, but the rendered offset road uses raw
	# sample normals. At a few sharp bends its local geometry can differ enough
	# to multiply world speed or even fold backwards at the road edge. Measure
	# the actual segment and constrain progress to the intended forward travel.
	var origin := T.pos(c.s, c.d)
	var tangent3 := T.tangent(c.s)
	var normal3 := T.normal(c.s)
	var tangent := Vector2(tangent3.x, tangent3.z).normalized()
	var normal := Vector2(normal3.x, normal3.z).normalized()
	var base_delta := Vector2.ZERO
	for i in 4:
		var next := T.pos(c.s + s_step, c.d)
		base_delta = Vector2(next.x - origin.x, next.z - origin.z)
		var forward := base_delta.dot(tangent)
		if forward * longitudinal_step <= 0.0:
			s_step = 0.0
			base_delta = Vector2.ZERO
			break
		if absf(absf(forward) - absf(longitudinal_step)) <= 0.0001:
			break
		# The inside lane is shorter than the centreline. Match actual road
		# displacement in both directions, so a bend cannot make a car crawl.
		# A finite bound also protects against malformed or very tight routes.
		var ratio := clampf(absf(longitudinal_step / forward), 0.25, 3.0)
		s_step = clampf(s_step * ratio, -absf(longitudinal_step) * 4.0, absf(longitudinal_step) * 4.0)
	if not is_zero_approx(s_step):
		var refined := T.pos(c.s + s_step, c.d)
		base_delta = Vector2(refined.x - origin.x, refined.z - origin.z)
		if base_delta.dot(tangent) * longitudinal_step <= 0.0:
			s_step = 0.0
			base_delta = Vector2.ZERO
	# Cancel sideways motion caused by normal interpolation itself, subject to
	# the same lateral bound as steering and impacts.
	lateral_step = clampf(lateral_step - base_delta.dot(normal), -lateral_limit * dt, lateral_limit * dt)
	var end := T.pos(c.s + s_step, c.d + lateral_step)
	var actual_distance := Vector2(end.x - origin.x, end.z - origin.z).length()
	var intended_distance := Vector2(longitudinal_step, lateral_speed * dt).length()
	if actual_distance > intended_distance + 0.00001:
		var scale := intended_distance / actual_distance
		s_step *= scale
		lateral_step *= scale
	c.d += lateral_step
	c.lat_v *= exp(-4.0 * dt)
	c.progress += s_step
	c.s = T.mod_s(c.progress)
	# walls
	var lim := hw - 1.1
	if c.d > lim or c.d < -lim:
		var sd := 1.0 if c.d > 0.0 else -1.0
		c.d = sd * lim
		var into := (v * sin(c.yaw) + c.lat_v) * sd
		if into > 0.0:
			# Slide along the barrier instead of reflecting the heading and
			# lateral velocity in a single fixed tick. Bound drag per second so
			# sustained contact cannot repeatedly apply a full collision impulse.
			c.v = move_toward(c.v, 0.0, minf(14.0, into * 1.2) * dt)
			if v * sin(c.yaw) * sd > 0.0:
				c.yaw = move_toward(c.yaw, 0.0, 2.0 * dt)
			if c.lat_v * sd > 0.0:
				c.lat_v = move_toward(c.lat_v, 0.0, 12.0 * dt)
			if into > 9.0 and c.scrape <= 0.05:
				damage(c, (into - 9.0) * 0.9, null, "wall")
			c.scrape = maxf(c.scrape, minf(1.0, into / 14.0 + 0.25))
			if into > 5.0:
				emit({"t": "wall", "car": c, "imp": into, "side": sd})
	# drift fans
	if c.drift > 0.6 and c.v > 25.0 and started:
		c.drift_t += dt
		if c.drift_t > 0.5:
			c.drift_t -= 0.5
			c.fans += 5


# Collision footprint follows the actual GLB body (about 4.39 x 1.96 m).
# Clipped corners approximate the tapered bumpers and avoid invisible box corners.
const CAR_HALF_LENGTH := 2.18
const CAR_HALF_WIDTH := 0.98
const CAR_CORNER := 0.30


## Highest speed from which a car at `s` can still slow, at `decel`, to what
## `a_lat` of lateral grip carries through every bend within `reach` metres.
func corner_speed(s: float, a_lat: float, decel: float, reach: float) -> float:
	var v_t := INF
	var x := 0.0
	while x <= reach:
		var k := absf(track.curv(s + x))
		if k >= 1e-4:
			var allow := sqrt(a_lat / k + 2.0 * decel * x)
			if allow < v_t:
				v_t = allow
		x += 6.0
	return v_t


func _footprint_radius(axis: Vector2, forward: Vector2, side: Vector2) -> float:
	var along := absf(axis.dot(forward))
	var across := absf(axis.dot(side))
	return CAR_HALF_LENGTH * along + CAR_HALF_WIDTH * across - CAR_CORNER * minf(along, across)


func collisions(dt: float = 1.0 / 60.0) -> void:
	var T := track
	for i in cars.size():
		var a := cars[i]
		if a.finished or a.wreck_t > 0.0:
			continue
		for j in range(i + 1, cars.size()):
			var b := cars[j]
			if b.finished or b.wreck_t > 0.0:
				continue
			# This is only a broad phase; the actual contact test below uses
			# rendered world positions and both cars' headings, even on bends.
			if absf(T.wrap_s(b.s - a.s)) > 8.0 or absf(b.d - a.d) > 8.0:
				continue
			var ap := T.pos(a.s, a.d)
			var bp := T.pos(b.s, b.d)
			var delta := Vector2(bp.x - ap.x, bp.z - ap.z)
			var at3 := T.tangent(a.s)
			var bt3 := T.tangent(b.s)
			var an3 := T.normal(a.s)
			var bn3 := T.normal(b.s)
			var at := Vector2(at3.x, at3.z).normalized()
			var bt := Vector2(bt3.x, bt3.z).normalized()
			var an := Vector2(an3.x, an3.z).normalized()
			var bn := Vector2(bn3.x, bn3.z).normalized()
			var af := at * cos(a.yaw) + an * sin(a.yaw)
			var bf := bt * cos(b.yaw) + bn * sin(b.yaw)
			var ar := an * cos(a.yaw) - at * sin(a.yaw)
			var br := bn * cos(b.yaw) - bt * sin(b.yaw)
			var contact_axis := Vector2.ZERO
			var penetration := INF
			# Eight axes cover the four edge directions of each clipped box.
			for axis in [af, ar, (af + ar).normalized(), (af - ar).normalized(), bf, br, (bf + br).normalized(), (bf - br).normalized()]:
				var overlap := _footprint_radius(axis, af, ar) + _footprint_radius(axis, bf, br) - absf(delta.dot(axis))
				if overlap <= 0.0:
					penetration = -1.0
					break
				if overlap < penetration:
					penetration = overlap
					contact_axis = axis if delta.dot(axis) >= 0.0 else -axis
			if penetration <= 0.0:
				continue
			var ma: float = a.def.mass
			var mb: float = b.def.mass
			var tot := ma + mb
			# Limit correction in metres/second, so overlap cannot teleport cars.
			var separation_limit := (2.0 + minf(1.0, maxf(absf(a.v), absf(b.v)) * 0.1)) * dt
			var correction := contact_axis * minf(penetration, separation_limit)
			a.d -= correction.dot(an) * (mb / tot)
			b.d += correction.dot(bn) * (ma / tot)
			a.progress -= correction.dot(at) * (mb / tot) / maxf(0.8, 1.0 - T.curv(a.s) * a.d)
			b.progress += correction.dot(bt) * (ma / tot) / maxf(0.8, 1.0 - T.curv(b.s) * b.d)
			a.s = T.mod_s(a.progress)
			b.s = T.mod_s(b.progress)
			var side_contact := absf(contact_axis.dot(an)) > absf(contact_axis.dot(at))
			if side_contact:
				var sg := 1.0 if contact_axis.dot(an) >= 0.0 else -1.0
				var closing := (a.v * sin(a.yaw) + a.lat_v - b.v * sin(b.yaw) - b.lat_v) * sg
				var impulse := clampf(closing * 0.5, 0.0, 4.0)
				a.lat_v -= sg * impulse * (mb / tot)
				b.lat_v += sg * impulse * (ma / tot)
				if closing > 0.0:
					# Stop sustained steering into another body from producing
					# repeated sliding impulses; let the player steer away.
					if a.yaw * sg > 0.0:
						a.yaw = move_toward(a.yaw, 0.0, 2.0 * dt)
					if b.yaw * sg < 0.0:
						b.yaw = move_toward(b.yaw, 0.0, 2.0 * dt)
				emit({"t": "bump", "a": a, "b": b, "side": true})
			else:
				var front := b if contact_axis.dot(at) > 0.0 else a
				var rear := a if front == b else b
				var dv := rear.v - front.v
				if dv > 0.0:
					rear.v -= dv * (0.55 * front.def.mass / tot + 0.2)
					front.v += dv * 0.45 * rear.def.mass / tot
					if dv > 14.0:
						damage(rear, (dv - 14.0) * 0.6, front, "bump")
						damage(front, (dv - 14.0) * 0.4, rear, "bump")
					if dv > 3.0:
						emit({"t": "bump", "a": rear, "b": front, "dv": dv, "side": false})


func damage(c: CarState, dmg: float, by: CarState, kind: String) -> void:
	if c.wreck_t > 0.0 or c.finished or c.invuln_t > 0.0:
		return
	c.health -= dmg
	if c.health <= 0.0:
		wreck(c, by, kind)


func wreck(c: CarState, by: CarState, kind: String) -> void:
	c.health = 0.0
	c.wreck_t = 2.4
	c.spin_t = 0.0
	c.wrecks += 1
	c.nitro_t = 0.0
	c.shield_t = 0.0
	if by != null and by != c:
		by.fans += FANS.wreck
	emit({"t": "wreck", "car": c, "by": by, "kind": kind})


func hit(o: CarState, by: CarState, kind: String, dmg: float, fx: Dictionary) -> bool:
	if o.finished or o.wreck_t > 0.0:
		return false
	if o.shield_t > 0.0 or o.invuln_t > 0.0:
		emit({"t": "blocked", "car": o, "by": by, "kind": kind})
		return false
	o.health -= dmg
	if fx.get("spin", false):
		o.spin_t = 1.15
		o.spin_dir = -1 if rng.randf() < 0.5 else 1
		o.v *= 0.35
		o.hop_v = maxf(o.hop_v, 7.0)
	if fx.has("slow"):
		o.v *= fx.slow
	if fx.has("stun"):
		o.stun_t = maxf(o.stun_t, fx.stun)
	if fx.has("hop"):
		o.hop_v = maxf(o.hop_v, fx.hop)
	if fx.has("push"):
		o.lat_v += fx.push
	if by != null and by != o:
		by.fans += FANS.get(kind, 0)
		by.hits += 1
	emit({"t": "hit", "car": o, "by": by, "kind": kind, "dmg": dmg})
	if o.health <= 0.0:
		wreck(o, by, kind)
	return true


func use_item(c: CarState, back: bool) -> void:
	if c.slots.is_empty() or c.wreck_t > 0.0 or c.spin_t > 0.0 or not started:
		return
	var it: Dictionary = c.slots[0]
	var T := track
	var type: String = it.type
	var used := true
	match type:
		"eagle":
			var tgt := car_behind(c, 160.0) if back else car_ahead(c, 420.0)
			projs.append({"id": _nid(), "kind": "eagle", "owner": c, "s": T.mod_s(c.s + (-5.0 if back else 4.0)), "d": c.d,
				"dir": -1.0 if back else 1.0, "speed": 32.0 if back else maxf(c.v + 25.0, 55.0), "target": tgt, "life": 3.2 if back else 7.0, "born": time})
		"bolt":
			projs.append({"id": _nid(), "kind": "bolt", "owner": c, "s": T.mod_s(c.s + (-4.0 if back else 4.0)), "d": c.d,
				"dir": -1.0 if back else 1.0, "speed": 75.0 if back else maxf(c.v, 0.0) + 85.0, "target": null, "life": 1.5, "born": time})
			it.ammo -= 1
			used = it.ammo <= 0
		"barge":
			for o in cars:
				if o == c or o.finished or o.wreck_t > 0.0:
					continue
				var ds := T.wrap_s(o.s - c.s)
				var dd := o.d - c.d
				var dist := sqrt(ds * ds + dd * dd)
				if dist < 15.0:
					var f := 1.0 - dist / 15.0
					hit(o, c, "barge", 12.0 + 12.0 * f, {"slow": 0.85 - 0.2 * f, "push": (1.0 if dd >= 0.0 else -1.0) * (9.0 + 9.0 * f)})
			emit({"t": "barge", "car": c})
		"mine":
			if back:
				mines.append({"id": _nid(), "owner": c, "s": T.mod_s(c.s - 6.0), "d": c.d, "fly": 0.0, "fly0": 0.0, "vs": 0.0, "life": 45.0, "arm": 0.4, "born": time})
			else:
				mines.append({"id": _nid(), "owner": c, "s": T.mod_s(c.s + 4.0), "d": c.d, "fly": 0.7, "fly0": 0.7, "vs": maxf(c.v, 10.0) + 40.0, "life": 45.0, "arm": 0.4, "born": time})
		"shock":
			var lead := leader()
			if lead == null or lead == c:
				used = false
				emit({"t": "denied", "car": c, "why": "first"})
			else:
				var lanes := [-7.0, 0.0, 7.0]
				for i in range(2, 0, -1):
					var j := rng.randi_range(0, i)
					var tmp = lanes[i]
					lanes[i] = lanes[j]
					lanes[j] = tmp
				for k in 3:
					domes.append({"id": _nid(), "owner": c, "s": T.mod_s(lead.s + 110.0 + k * 45.0), "d": lanes[k] + (rng.randf() - 0.5) * 2.0,
						"r": 4.8, "warn": 1.0, "life": 9.0, "hit_set": {}})
				emit({"t": "shock", "car": c, "target": lead})
		"nitro":
			if back:
				c.v *= 0.5
				c.hbrake_t = 0.8
			else:
				c.nitro_t = 2.6
			emit({"t": "nitro", "car": c, "back": back})
		"shield":
			c.shield_t = 8.0
			emit({"t": "shield", "car": c})
		"repair":
			if c.health >= c.max_hp * 0.97:
				used = false
				emit({"t": "denied", "car": c, "why": "full"})
			else:
				c.health = c.max_hp
				emit({"t": "repair", "car": c})
	if used or type == "bolt":
		emit({"t": "fire", "car": c, "type": type, "back": back})
	if used:
		c.slots.pop_front()


func update_pickups(dt: float) -> void:
	var T := track
	for p in pickups:
		if not p.alive:
			p.t -= dt
			if p.t <= 0.0:
				p.alive = true
				emit({"t": "pickup_back", "p": p})
			continue
		for c in cars:
			if c.slots.size() >= 3 or c.wreck_t > 0.0 or c.finished:
				continue
			if absf(T.wrap_s(c.s - p.s)) < 3.2 and absf(c.d - p.d) < 2.6:
				p.alive = false
				p.t = 2.0
				c.slots.append({"type": p.type, "ammo": int(Data.PW[p.type].ammo)})
				emit({"t": "pickup", "car": c, "type": p.type, "p": p})
				break


func update_projs(dt: float) -> void:
	var T := track
	var i := projs.size() - 1
	while i >= 0:
		if i >= projs.size():
			i = projs.size() - 1
			continue
		var p: Dictionary = projs[i]
		var dead := false
		p.life -= dt
		var tgt: CarState = p.target
		if tgt != null and (tgt.finished or tgt.wreck_t > 0.0):
			tgt = null
		if p.kind == "eagle":
			if p.dir > 0.0:
				var want: float = tgt.v + 45.0 if tgt != null else p.speed
				p.speed += clampf(want - p.speed, -40.0 * dt, 70.0 * dt)
				p.speed = maxf(p.speed, 45.0)
			p.s = T.mod_s(p.s + p.dir * p.speed * dt)
			if tgt != null:
				var ds := T.wrap_s(tgt.s - p.s)
				var rate := 24.0 if absf(ds) < 70.0 else 7.0
				p.d += clampf(tgt.d - p.d, -rate * dt, rate * dt)
		else:
			p.s = T.mod_s(p.s + p.dir * p.speed * dt)
			var best: CarState = null
			var bd := 45.0
			for o in cars:
				if o == p.owner or o.finished or o.wreck_t > 0.0:
					continue
				var ds: float = T.wrap_s(o.s - p.s) * float(p.dir)
				if ds > 0.0 and ds < bd and absf(o.d - p.d) < 6.0:
					bd = ds
					best = o
			if best != null:
				p.d += clampf(best.d - p.d, -5.0 * dt, 5.0 * dt)
		p.d = clampf(p.d, -hw + 1.0, hw - 1.0)
		for o in cars:
			if o == p.owner or o.finished or o.wreck_t > 0.0:
				continue
			if absf(T.wrap_s(o.s - p.s)) < 3.2 and absf(o.d - p.d) < 2.3:
				if p.kind == "eagle":
					hit(o, p.owner, "eagle", 34.0, {"spin": true})
				else:
					hit(o, p.owner, "bolt", 11.0, {"slow": 0.86, "push": (1.0 if o.d - p.d >= 0.0 else -1.0) * 3.0})
				emit({"t": "boom", "kind": p.kind, "s": p.s, "d": p.d, "hit_car": o})
				dead = true
				break
		if not dead:
			for j in range(mines.size() - 1, -1, -1):
				var m: Dictionary = mines[j]
				if m.fly > 0.0:
					continue
				if absf(T.wrap_s(m.s - p.s)) < 2.6 and absf(m.d - p.d) < 2.6:
					mines.remove_at(j)
					emit({"t": "boom", "kind": "mine", "s": m.s, "d": m.d})
					emit({"t": "boom", "kind": p.kind, "s": p.s, "d": p.d})
					dead = true
					break
		if not dead:
			for j in range(projs.size() - 1, -1, -1):
				var q: Dictionary = projs[j]
				if q == p or q.dir == p.dir:
					continue
				if absf(T.wrap_s(q.s - p.s)) < 3.5 and absf(q.d - p.d) < 2.6:
					emit({"t": "boom", "kind": q.kind, "s": q.s, "d": q.d})
					emit({"t": "boom", "kind": p.kind, "s": p.s, "d": p.d})
					projs.remove_at(j)
					if j < i:
						i -= 1
					dead = true
					break
		if not dead and p.life <= 0.0:
			dead = true
			emit({"t": "fizzle", "kind": p.kind, "s": p.s, "d": p.d})
		if dead:
			var k := projs.find(p)
			if k >= 0:
				projs.remove_at(k)
		i -= 1


func update_mines(dt: float) -> void:
	var T := track
	for i in range(mines.size() - 1, -1, -1):
		var m: Dictionary = mines[i]
		if m.fly > 0.0:
			m.fly -= dt
			m.s = T.mod_s(m.s + m.vs * dt)
			continue
		m.life -= dt
		m.arm -= dt
		if m.life <= 0.0:
			mines.remove_at(i)
			continue
		if m.arm > 0.0:
			continue
		for o in cars:
			if (o == m.owner and time - m.born < 2.5) or o.finished or o.wreck_t > 0.0:
				continue
			if absf(T.wrap_s(o.s - m.s)) < 2.5 and absf(o.d - m.d) < 2.1:
				hit(o, m.owner, "mine", 26.0, {"hop": 7.5, "slow": 0.5, "stun": 1.0})
				emit({"t": "boom", "kind": "mine", "s": m.s, "d": m.d, "hit_car": o})
				mines.remove_at(i)
				break
	if mines.size() > 24:
		mines.pop_front()


func update_domes(dt: float) -> void:
	var T := track
	for i in range(domes.size() - 1, -1, -1):
		var dm: Dictionary = domes[i]
		if dm.warn > 0.0:
			dm.warn -= dt
			continue
		dm.life -= dt
		if dm.life <= 0.0:
			domes.remove_at(i)
			continue
		for o in cars:
			if dm.hit_set.has(o.id) or o.finished or o.wreck_t > 0.0:
				continue
			var ds: float = T.wrap_s(o.s - dm.s)
			var dd: float = o.d - dm.d
			if ds * ds + dd * dd < dm.r * dm.r:
				dm.hit_set[o.id] = true
				hit(o, dm.owner, "shock", 20.0, {"stun": 2.2, "slow": 0.6})
				emit({"t": "zap", "dome": dm, "car": o})


# ---------------------------------------------------------------- AI
func ai_drive(c: CarState, dt: float) -> void:
	var ai := c.ai
	var T := track
	ai.plan_t -= dt
	ai.t -= dt
	if ai.plan_t <= 0.0:
		ai.plan_t = 0.1
		var a_lat: float = c.def.grip * 22.0 * 0.93 * (0.93 if wet else 1.0)
		var v_t: float = c.def.vmax * c.vmax_mul * (1.3 if c.nitro_t > 0.0 else 1.0) * (0.55 if c.stun_t > 0.0 else 1.0)
		var x := 0.0
		while x <= 240.0:
			var k := absf(T.curv(c.s + x))
			if k >= 1e-4:
				var vc := sqrt(a_lat / k)
				var allow := sqrt(vc * vc + 2.0 * 19.0 * x)
				if allow < v_t:
					v_t = allow
			x += 6.0
		ai.v_t = v_t
		var ka := 0.0
		for xx in [15.0, 25.0, 35.0, 45.0, 55.0]:
			ka += T.curv(c.s + xx)
		ka /= 5.0
		var d_t := clampf(ka * 900.0, -1.0, 1.0) * (hw - 3.5) * ai.line_amt + ai.lane_bias
		if c.slots.size() < 3:
			var bp = null
			var bd := 80.0
			for p in pickups:
				if not p.alive:
					continue
				var ds := T.wrap_s(p.s - c.s)
				if ds > 8.0 and ds < bd:
					bd = ds
					bp = p
			if bp != null:
				d_t = bp.d
		for m in mines:
			if m.fly <= 0.0:
				d_t = _avoid(c, d_t, m.s, m.d, 3.0)
		for dm in domes:
			d_t = _avoid(c, d_t, dm.s, dm.d, dm.r + 0.5)
		for o in cars:
			if o == c or o.wreck_t > 0.0:
				continue
			var ds := T.wrap_s(o.s - c.s)
			if ds > 0.0 and ds < 24.0 and absf(o.d - c.d) < 2.6 and c.v > o.v + 0.5:
				d_t = o.d + (-3.6 if o.d > 0.0 else 3.6)
		ai.d_t = clampf(d_t, -hw + 1.7, hw - 1.7)
	c.ctrl.gas = c.v < ai.v_t - 0.5
	c.ctrl.brake = c.v > ai.v_t + 3.0
	var v := maxf(c.v, 3.0)
	var k := T.curv(c.s)
	var lk := maxf(10.0, v * 0.6)
	var yaw_des := atan2(ai.d_t - c.d, lk)
	var dsdt := c.v * cos(c.yaw) / maxf(0.8, 1.0 - k * c.d)
	var c_max := minf(0.12, c.def.grip * 22.0 * (0.93 if wet else 1.0) / (v * v))
	var c_need := ((yaw_des - c.yaw) / 0.3 + k * dsdt + BOT_ASSIST * c.yaw * minf(1.0, v / 10.0)) / v
	c.ctrl.steer = clampf(c_need / c_max, -1.0, 1.0)
	if ai.t <= 0.0:
		ai.t = (0.35 + rng.randf() * 0.6) * diff.react * ai.react
		if not c.finished:
			ai_weapons(c)


func _avoid(c: CarState, d_t: float, hs: float, hd: float, rad: float) -> float:
	var ds := track.wrap_s(hs - c.s)
	if ds > 0.0 and ds < 70.0 and absf(hd - d_t) < rad:
		return hd + (-rad - 1.0 if hd > 0.0 else rad + 1.0)
	return d_t


func ai_weapons(c: CarState) -> void:
	if c.slots.is_empty() or not started:
		return
	var it: Dictionary = c.slots[0]
	var T := track
	var r := rng.randf()
	var aim: float = diff.aim
	var ahead := car_ahead(c, 260.0)
	var behind := car_behind(c, 80.0)
	var fire := false
	var back := false
	match it.type:
		"eagle":
			if ahead != null and r < 0.75 * aim:
				fire = true
			elif behind != null and c.progress - behind.progress < 45.0 and r < 0.3:
				fire = true
				back = true
		"bolt":
			if ahead != null and ahead.progress - c.progress < 60.0 and absf(ahead.d - c.d) < 3.2 and r < 0.9 * aim:
				fire = true
			elif behind != null and c.progress - behind.progress < 35.0 and absf(behind.d - c.d) < 3.0 and r < 0.4:
				fire = true
				back = true
		"barge":
			var n := 0
			for o in cars:
				if o == c or o.finished:
					continue
				if Vector2(T.wrap_s(o.s - c.s), o.d - c.d).length() < 11.0:
					n += 1
			if n > 0 and r < 0.9:
				fire = true
		"mine":
			if behind != null and c.progress - behind.progress < 45.0 and r < 0.7:
				fire = true
				back = true
			elif r < 0.06:
				fire = true
				back = true
		"shock":
			var lead := leader()
			if lead != null and lead != c and lead.progress - c.progress > 40.0 and r < 0.6:
				fire = true
		"nitro":
			var straight := true
			var x := 0.0
			while x <= 140.0:
				if absf(T.curv(c.s + x)) > 1.0 / 160.0:
					straight = false
					break
				x += 10.0
			if straight and c.v > c.def.vmax * 0.55 and r < 0.8:
				fire = true
		"shield":
			var threat := false
			for p in projs:
				if p.target == c or (p.owner != c and absf(T.wrap_s(p.s - c.s)) < 30.0):
					threat = true
			if threat or (c.health < c.max_hp * 0.5 and r < 0.25) or r < 0.04:
				fire = true
		"repair":
			if c.health < c.max_hp * 0.45:
				fire = true
	if fire:
		use_item(c, back)
	elif c.slots.size() >= 2 and r > 0.9:
		c.slots.push_back(c.slots.pop_front())


## Estimated finishing times for cars still racing when results are shown.
func estimate() -> void:
	for c in cars:
		if c.finished:
			c.est = c.finish_time
			continue
		var remain := laps * L - c.progress
		var avg := maxf(18.0, c.progress / maxf(1.0, time))
		c.est = time + remain / avg
