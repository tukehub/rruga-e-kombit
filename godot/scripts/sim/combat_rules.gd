extends RefCounted
## Read-only targeting/utility queries are shared by firing, UI and pickup planning.
## No simulation RNG, presentation nodes or retained Race references.

const RECOVERY_DURATION := 3.5
const RECOVERY_DAMAGE_SCALE := 0.65
const SHIELD_DURATION := 8.0
const NITRO_DURATION := 2.6
const DRIFT_BOOST_DURATION := 1.25
const DRIFT_METRES := 100.0
const DIRECTIONAL := ["eagle", "bolt", "mine", "nitro"]


static func phase_reason(race, c: CarState) -> String:
	if not race.started:
		return "not_started"
	if c.finished:
		return "finished"
	if c.wreck_t > 0.0:
		return "wreck"
	if c.spin_t > 0.0:
		return "spin"
	return ""


static func leader(race) -> CarState:
	# Pickups/actions run before the standings sort at the end of a fixed tick.
	# Use live progress so an overtake cannot discard a now-useful reserve.
	var first: CarState = null
	for c: CarState in race.cars:
		if not c.finished and (first == null or c.progress > first.progress):
			first = c
	return first


static func target(race, c: CarState, kind: String, backward := false) -> CarState:
	var best: CarState = null
	var limit := 160.0 if backward else 420.0
	if kind == "bolt":
		limit = 150.0 if backward else 127.5
	elif kind == "barge":
		limit = 15.0
	elif kind == "mine":
		limit = 100.0
	for other: CarState in race.cars:
		if other == c or other.finished or other.wreck_t > 0.0 or other.invuln_t > 0.0:
			continue
		var distance: float
		if kind == "barge":
			distance = Vector2(race.track.wrap_s(other.s - c.s), other.d - c.d).length()
		else:
			distance = race.track.mod_s((other.s - c.s) * (-1.0 if backward else 1.0))
			if kind == "bolt" and absf(other.d - c.d) > 6.0:
				continue
			if kind == "eagle" and distance > eagle_reach(c, other, backward):
				continue
			if kind == "bolt":
				var closing := 75.0 + other.v if backward else maxf(c.v, 0.0) + 85.0 - other.v
				if distance > maxf(0.0, closing * 1.5 + 4.0):
					continue
		if (distance > 0.0 or kind == "barge") and distance < limit:
			limit = distance
			best = other
	return best


static func eagle_reach(owner: CarState, aim: CarState, backward: bool) -> float:
	if backward:
		return maxf(0.0, (32.0 + aim.v) * 3.2 + 5.0)
	var initial := maxf(owner.v + 25.0, 55.0)
	var terminal := maxf(45.0, aim.v + 45.0)
	var acceleration := 70.0 if terminal >= initial else -40.0
	var ramp := minf(7.0, absf(terminal - initial) / absf(acceleration))
	var travel := initial * ramp + acceleration * ramp * ramp * 0.5 + terminal * (7.0 - ramp)
	return maxf(0.0, travel - aim.v * 7.0 + 4.0)


static func item_status(race, c: CarState, backward := false, kind := "") -> Dictionary:
	var why := phase_reason(race, c)
	var aim: CarState = null
	if kind.is_empty():
		kind = c.slot_type()
	if why.is_empty():
		if kind.is_empty():
			why = "empty"
		elif not Data.PW.has(kind):
			why = "unknown"
		elif backward and kind not in DIRECTIONAL:
			why = "direction"
		else:
			match kind:
				"eagle", "bolt", "barge", "mine":
					aim = target(race, c, kind, backward)
					if aim == null and kind in ["eagle", "barge"]:
						why = "no_target" if kind == "eagle" else "too_far"
				"shock":
					aim = leader(race)
					if aim == null or aim == c:
						why = "first"
					elif aim.wreck_t > 0.0 or aim.invuln_t > 0.0 or aim.recovery_t > 0.0:
						why = "target_recovery"
					elif not race.domes.is_empty():
						why = "storm_active"
				"repair":
					if c.health >= c.max_hp * 0.97:
						why = "full"
				"shield":
					if c.shield_t > 0.1:
						why = "shield_active"
				"nitro":
					if not backward and c.nitro_t > 0.1:
						why = "nitro_active"
	return {"ready": why.is_empty(), "reason": why, "target": aim, "kind": kind, "back": backward}


static func boost_status(race, c: CarState) -> String:
	var why := phase_reason(race, c)
	if not why.is_empty():
		return why
	if c.skill_charge < 1.0:
		return "charge"
	if c.nitro_t > 0.1:
		return "nitro_active"
	return ""


static func replaceable_slot(race, c: CarState) -> int:
	# Keep the selected item: it may be a deliberate reserve for the next hit.
	for i in range(c.slots.size() - 1, 0, -1):
		var kind: String = c.slots[i].type
		if (kind == "repair" and c.health >= c.max_hp * 0.97) or (kind == "shock" and leader(race) == c):
			return i
	return -1


static func pickup_slot(race, c: CarState, kind: String) -> int:
	if c.slots.size() < 3:
		return c.slots.size()
	var replace := replaceable_slot(race, c)
	if replace < 0:
		return -1
	for item: Dictionary in c.slots:
		if item.type == kind:
			return -1
	# Never trade a reserve for another unusable pickup.
	if not bool(item_status(race, c, false, kind).ready):
		return -1
	return replace


static func incoming(race, c: CarState) -> Dictionary:
	var result := {}
	if not race.started or c.finished or c.wreck_t > 0.0 or c.invuln_t > 0.0:
		return result
	var soonest := 4.0
	var count := 0
	for p: Dictionary in race.projs:
		if p.kind != "eagle" or p.target != c or p.owner == c or float(p.life) <= 0.0:
			continue
		var signed_gap: float = race.track.wrap_s(c.s - float(p.s))
		var approach := signed_gap * float(p.dir)
		if approach < -3.2 or approach > 240.0:
			continue
		# A forward eagle accelerates toward target speed +45. Forecast part of
		# that acceleration so its early warning does not wait until impact.
		var closing := float(p.speed) - c.v * float(p.dir)
		if float(p.dir) > 0.0:
			closing = maxf(closing, 35.0)
		if closing <= 0.1:
			continue
		var eta := maxf(0.0, approach) / closing
		if eta > 4.0 or eta > float(p.life):
			continue
		count += 1
		if eta <= soonest:
			soonest = eta
			var side := "PRAPA" if signed_gap >= 0.0 else "PARA"
			if absf(float(p.d) - c.d) > 2.5:
				side += " · " + ("DJATHTAS" if float(p.d) > c.d else "MAJTAS")
			result = {"id": p.id, "eta": eta, "direction": side, "urgent": eta <= 1.25, "shielded": c.shield_t > eta}
	if not result.is_empty():
		result["count"] = count
	return result


static func advance_drift(race, c: CarState, dt: float, distance: float) -> void:
	if not race.started or c.finished or c.wreck_t > 0.0 or c.spin_t > 0.0 or c.stun_t > 0.0 or c.recovery_t > 0.0 or c.invuln_t > 0.0 or c.hop > 0.05 or c.nitro_t > 0.0:
		return
	if not c.ctrl.brake or absf(c.ctrl.steer) < 0.35 or c.drift < 0.6 or c.v < 18.0 or c.scrape > 0.05:
		return
	# Actual forward distance, bounded by road speed, excludes stationary wheel
	# turning, reversing, wall farming and curvature-amplified track progress.
	var metres := minf(maxf(distance, 0.0), maxf(c.v, 0.0) * dt)
	var was_ready := c.skill_charge >= 1.0
	c.skill_charge = minf(1.0, c.skill_charge + metres / DRIFT_METRES)
	if not was_ready and c.skill_charge >= 1.0:
		race.emit({"t": "drift_ready", "car": c})
