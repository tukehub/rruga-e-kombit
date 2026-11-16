extends RefCounted
## Shared, advertised pickups planned before they enter the player's view.
## The director changes opportunities, never vehicle speeds or carried items.
## No Race reference is retained: Race owns this RefCounted object.

const SAMPLE_INTERVAL := 0.25
const PLAN_DISTANCE := 240.0
const VISIBLE_GUARD := 185.0 # 155 m badges + chase/intro camera and lane offsets.
const BOT_GUARD := 85.0 # Bots start planning a pickup at 80 m.
const HELP_MIN_DISTANCE := 100.0
const HELP_MAX_DISTANCE := 200.0
const HELP_POOL_SIZE := 2
const HELP_COOLDOWN := 12.0
const HELP_MIN_TRAVEL := 240.0
const SHOCK_COOLDOWN := 24.0
const NITRO_DROUGHT := 12.0
const HISTORY_LIMIT := 64

var seed: int
var rng := RandomNumberGenerator.new()
var rows: Array[Dictionary] = []
var history: Dictionary = {} # car id -> bounded recent state; no car references.
var decisions: Array[Dictionary] = []
var counts := {"normal_plans": 0, "help_offers": 0, "help_collected": 0,
	"player_help_collected": 0, "collected": {}, "used": {},
	"player_collected": {}, "player_used": {}}
var _sample_t := 0.0
# Pickup weight by standing: [first place, last place], interpolated between.
const RANK_WEIGHTS := {
	"nitro": [0.7, 1.6], "eagle": [0.7, 1.5], "shock": [1.0, 1.5], "bolt": [1.0, 1.2],
	"mine": [1.4, 0.5], "shield": [1.3, 0.8],
}
var _last_offer_time := -1000.0
var _last_offer_progress := -INF
var _shock_reserved_until := -1000.0


func _init(race_seed: int) -> void:
	seed = race_seed
	# Keep adaptive choices independent of driving, targeting and combat RNG.
	rng.seed = race_seed ^ 0x51A7B00


func setup(race) -> void:
	# Normal stations remain at their established locations and retain respawn.
	for i in range(0, race.pickups.size(), 3):
		var items: Array = []
		for j in range(i, mini(i + 3, race.pickups.size())):
			items.append(race.pickups[j])
		rows.append({"id": rows.size(), "items": items, "bonus": false, "cycle": -1000})
	# Preallocate one-shot rows so combat never adds pickup nodes mid-frame.
	for i in HELP_POOL_SIZE:
		var items: Array = []
		var lane := minf(6.5, maxf(0.0, float(race.hw) - 2.0))
		for d: float in [-lane, 0.0, lane]:
			var p := {"id": race._nid(), "s": 0.0, "d": d, "type": "nitro",
				"alive": false, "active": false, "respawn": false, "adaptive": true, "t": 0.0}
			race.pickups.append(p)
			items.append(p)
		rows.append({"id": rows.size(), "items": items, "bonus": true,
			"active": false, "progress": 0.0})


func advance(race, dt: float) -> void:
	if not race.started:
		return
	_sample_t += dt
	if _sample_t < SAMPLE_INTERVAL:
		return
	var elapsed := _sample_t
	_sample_t = 0.0
	_update_history(race, elapsed)
	_retire_help(race)
	for row: Dictionary in rows:
		if row.bonus:
			continue
		var s := float(row.items[0].s)
		var c := _approaching_car(race, s)
		if c == null or not _can_edit(race, s):
			continue
		var cycle := int(floor((c.progress + race.track.mod_s(s - c.s)) / float(race.L)))
		if cycle == int(row.cycle):
			continue
		# Do not resurrect a pickup or change a partially collected station.
		var complete := true
		for p: Dictionary in row.items:
			complete = complete and bool(p.alive)
		if not complete:
			continue
		_assign(race, row, c, s, "normal")
		row.cycle = cycle
		counts.normal_plans += 1
	_offer_help(race)


func _update_history(race, dt: float) -> void:
	var lead := _leader(race)
	for c: CarState in race.cars:
		var h := _state(c.id)
		var raw_gap := maxf(0.0, lead.progress - c.progress) / maxf(25.0, c.v) if lead != null else 0.0
		h.gap_s = lerpf(float(h.gap_s), raw_gap, 1.0 - exp(-dt / 3.0))
		if float(h.gap_s) > 3.5:
			h.behind = true
		elif float(h.gap_s) < 2.0:
			h.behind = false


func _state(car_id: int) -> Dictionary:
	if not history.has(car_id):
		history[car_id] = {"gap_s": 0.0, "behind": false, "pickup_t": 0.0,
			"nitro_t": 0.0, "hit_t": -1000.0, "recent": []}
	return history[car_id]


func _leader(race) -> CarState:
	var lead: CarState = null
	for c: CarState in race.cars:
		if not c.finished and (lead == null or c.progress > lead.progress):
			lead = c
	return lead


func _approaching_car(race, s: float) -> CarState:
	var best: CarState = null
	var nearest := PLAN_DISTANCE
	for c: CarState in race.cars:
		if c.finished or c.wreck_t > 0.0 or not race.has_pickup_room(c):
			continue
		var distance: float = race.track.mod_s(s - c.s)
		if distance > BOT_GUARD and distance <= nearest and c.progress + distance < race.laps * race.L:
			nearest = distance
			best = c
	return best


func _can_edit(race, s: float) -> bool:
	var pos: Vector3 = race.track.pos(s, 0.0)
	for c: CarState in race.cars:
		if c.is_player:
			# World distance also protects nearby parallel streets and hairpins.
			if race.track.pos(c.s, c.d).distance_squared_to(pos) <= VISIBLE_GUARD * VISIBLE_GUARD:
				return false
		elif not c.finished and absf(race.track.wrap_s(s - c.s)) <= BOT_GUARD:
			return false
	return true


func _straight(race, s: float) -> bool:
	for x in range(0, 141, 20):
		if absf(race.track.curv(s + x)) > 1.0 / 140.0:
			return false
	return true


## Public for diagnostics and statistical balance checks; does not consume RNG.
func weights(race, c: CarState, s: float, new_supply := true) -> Dictionary:
	var w := {}
	for kind in Data.PW_KEYS:
		w[kind] = float(Data.PW[kind].w)
	var held := {}
	for item: Dictionary in c.slots:
		held[item.type] = int(held.get(item.type, 0)) + 1
	var h := _state(c.id)
	var health := c.health / maxf(c.max_hp, 1.0)
	var ahead := _opponent(race, c, 420.0)
	var behind := _opponent(race, c, 100.0, true)
	var close := ahead != null and ahead.progress - c.progress < 100.0
	var recent_hit: bool = race.time - float(h.hit_t) < 5.0
	w.repair *= 0.0 if health >= 0.85 else lerpf(1.2, 6.0, clampf((0.85 - health) / 0.7, 0.0, 1.0))
	w.shield *= 0.0 if c.shield_t > 1.0 else (3.0 if recent_hit or behind != null else 0.7)
	w.nitro *= 1.0 if _straight(race, s) else 0.12
	if bool(h.behind):
		w.nitro *= 3.0
	if race.time - float(h.nitro_t) >= NITRO_DROUGHT:
		w.nitro *= 1.8
	if c.nitro_t > 0.1:
		w.nitro = 0.0
	w.bolt *= 2.0 if close or behind != null else 0.08
	w.eagle *= 1.8 if ahead != null or behind != null else 0.08
	w.barge *= 2.5 if (ahead != null and ahead.progress - c.progress < 22.0) or (behind != null and c.progress - behind.progress < 22.0) else 0.15
	w.mine *= 1.5 if behind != null else 0.5
	var lead := _leader(race)
	if lead == null or lead == c or lead.progress - c.progress < 80.0:
		w.shock = 0.0
	elif new_supply and (race.time < _shock_reserved_until or not race.domes.is_empty()):
		w.shock = 0.0
	elif lead.wreck_t > 0.0 or lead.spin_t > 0.0 or lead.stun_t > 0.0 or lead.recovery_t > 0.0 or lead.invuln_t > 0.0 or race.time - float(_state(lead.id).hit_t) < 5.0:
		w.shock = 0.0
	else:
		w.shock *= 4.0 if bool(h.behind) else 0.35
	# Standing: the car at the back is offered more to come back with, the
	# leader more to defend with. Mid-field sits in between.
	var rank := rank_share(race, c)
	for kind in RANK_WEIGHTS:
		w[kind] *= lerpf(float(RANK_WEIGHTS[kind][0]), float(RANK_WEIGHTS[kind][1]), rank)
	for kind in held:
		w[kind] *= 0.0 if kind in ["nitro", "repair", "shield", "shock"] else 0.12
	# Keep a drought from becoming a repetitive stream of the same other item.
	for kind in h.recent:
		w[kind] *= 0.65
	if c.slots.size() >= 3:
		for kind in w:
			if race.pickup_slot(c, kind) < 0:
				w[kind] = 0.0
	return w


## 0.0 for the car in first place, 1.0 for the one in last, among all racers.
func rank_share(race, c: CarState) -> float:
	if race.cars.size() < 2 or c.place <= 0:
		return 0.5
	return clampf(float(c.place - 1) / float(race.cars.size() - 1), 0.0, 1.0)


func _opponent(race, c: CarState, range_m: float, behind := false) -> CarState:
	var closest: CarState = null
	for other: CarState in race.cars:
		if other == c or other.finished or other.wreck_t > 0.0:
			continue
		var distance := (other.progress - c.progress) * (-1.0 if behind else 1.0)
		if distance > 0.0 and distance < range_m:
			range_m = distance
			closest = other
	return closest


func _reason(race, c: CarState) -> String:
	if not race.has_pickup_room(c) or c.finished or c.wreck_t > 0.0 or c.v < 12.0:
		return ""
	var h := _state(c.id)
	var held := {}
	for item: Dictionary in c.slots:
		held[item.type] = true
	if c.health < c.max_hp * 0.55 and not held.has("repair"):
		return "recovery"
	if race.time - float(h.hit_t) < 5.0 and not held.has("shield") and c.shield_t <= 0.1:
		return "defence"
	if bool(h.behind):
		var has_boost := held.has("nitro") or c.nitro_t > 0.1
		var has_attack := held.has("shock") or held.has("eagle")
		if not has_boost or not has_attack:
			return "comeback"
	var lead := _leader(race)
	if lead != null and lead.progress - c.progress > 25.0 and race.time - float(h.nitro_t) >= NITRO_DROUGHT and not held.has("nitro") and c.nitro_t <= 0.1:
		return "boost"
	if c.slots.is_empty() and race.time - float(h.pickup_t) >= 10.0:
		return "supply"
	return ""


func _help_weights(race, c: CarState, s: float, reason: String, existing := false) -> Dictionary:
	# A reservation limits new storm supply; it does not invalidate a storm
	# already advertised on the road, which racers can still collect and use.
	var all := weights(race, c, s, not existing)
	var wanted: Array = {"recovery": ["repair", "shield"], "defence": ["shield", "repair"],
		"comeback": ["nitro", "shock", "eagle"], "boost": ["nitro"], "supply": Data.PW_KEYS}.get(reason, [])
	var result := {}
	for kind in wanted:
		var carried := false
		for item: Dictionary in c.slots:
			carried = carried or item.type == kind
		if carried:
			continue
		if kind == "nitro" and not _straight(race, s):
			continue
		if kind == "eagle" and _opponent(race, c, 300.0) == null:
			continue
		if float(all[kind]) > 0.0:
			result[kind] = all[kind]
	return result


func _offer_help(race) -> void:
	var c: CarState = race.player
	if c == null or race.time < 6.0 or race.time - _last_offer_time < HELP_COOLDOWN or c.progress - _last_offer_progress < HELP_MIN_TRAVEL:
		return
	var reason := _reason(race, c)
	if reason.is_empty():
		return
	# A useful existing station already in reach needs no extra supply.
	for row: Dictionary in rows:
		if row.bonus and not bool(row.active):
			continue
		var s := float(row.items[0].s)
		var distance: float = race.track.mod_s(s - c.s)
		if distance < HELP_MIN_DISTANCE or distance > HELP_MAX_DISTANCE:
			continue
		var useful := _help_weights(race, c, s, reason, true)
		for p: Dictionary in row.items:
			if p.alive and useful.has(p.type):
				return
	var free: Dictionary = {}
	for row: Dictionary in rows:
		if row.bonus and not bool(row.active):
			free = row
			break
	if free.is_empty():
		return
	for distance: float in [200.0, 195.0, 190.0]:
		if c.progress + distance >= race.laps * race.L - 18.0:
			continue
		var s: float = race.track.mod_s(c.s + distance)
		if not _can_edit(race, s) or _help_weights(race, c, s, reason).is_empty():
			continue
		var clear := true
		for row: Dictionary in rows:
			if row.bonus and not bool(row.active):
				continue
			if absf(race.track.wrap_s(s - float(row.items[0].s))) < 35.0:
				clear = false
				break
		if not clear:
			continue
		_assign(race, free, c, s, reason)
		free.active = true
		free.progress = c.progress + distance
		_last_offer_time = race.time
		_last_offer_progress = c.progress
		counts.help_offers += 1
		return


func _assign(race, row: Dictionary, c: CarState, s: float, reason: String) -> void:
	var w := weights(race, c, s)
	var choices: Array[String] = []
	for i in row.items.size():
		# A help row offers one useful choice; collecting it is still up to racers.
		var kind := _pick(_help_weights(race, c, s, reason) if row.bonus and i == 0 else w)
		if kind.is_empty():
			kind = "shield"
		choices.append(kind)
		w[kind] = 0.0
	# Shuffle the useful choice among lanes so help never steers for the player.
	for i in range(choices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := choices[i]
		choices[i] = choices[j]
		choices[j] = tmp
	for i in row.items.size():
		var p: Dictionary = row.items[i]
		p.s = s
		p.type = choices[i]
		if row.bonus:
			p.active = true
			p.alive = true
			p.t = 0.0
	if choices.has("shock"):
		_shock_reserved_until = race.time + SHOCK_COOLDOWN
	_log({"event": "offer" if row.bonus else "plan", "t": race.time,
		"row": row.id, "car": c.id, "s": s, "progress": c.progress, "reason": reason, "types": choices})


func _pick(w: Dictionary) -> String:
	var total := 0.0
	for kind in Data.PW_KEYS:
		total += float(w.get(kind, 0.0))
	if total <= 0.0:
		return ""
	var value := rng.randf() * total
	for kind in Data.PW_KEYS:
		value -= float(w.get(kind, 0.0))
		if float(w.get(kind, 0.0)) > 0.0 and value <= 0.0:
			return kind
	return ""


func _retire_help(race) -> void:
	var c: CarState = race.player
	if c == null:
		return
	for row: Dictionary in rows:
		if not row.bonus or not bool(row.active):
			continue
		var any_alive := false
		for p: Dictionary in row.items:
			any_alive = any_alive or bool(p.alive)
		if any_alive and (c.progress < float(row.progress) + VISIBLE_GUARD + 20.0 or not _can_edit(race, float(row.items[0].s))):
			continue
		row.active = false
		for p: Dictionary in row.items:
			p.active = false
			p.alive = false


func note_pickup(c: CarState, kind: String, now: float, bonus: bool) -> void:
	var h := _state(c.id)
	h.pickup_t = now
	if kind == "nitro":
		h.nitro_t = now
	h.recent.append(kind)
	if h.recent.size() > 3:
		h.recent.pop_front()
	counts.collected[kind] = int(counts.collected.get(kind, 0)) + 1
	if c.is_player:
		counts.player_collected[kind] = int(counts.player_collected.get(kind, 0)) + 1
	if bonus:
		counts.help_collected += 1
		if c.is_player:
			counts.player_help_collected += 1


func note_use(c: CarState, kind: String, now: float) -> void:
	counts.used[kind] = int(counts.used.get(kind, 0)) + 1
	if c.is_player:
		counts.player_used[kind] = int(counts.player_used.get(kind, 0)) + 1
	if kind == "nitro":
		_state(c.id).nitro_t = now
	if kind == "shock":
		_shock_reserved_until = now + SHOCK_COOLDOWN


func note_hit(c: CarState, now: float) -> void:
	_state(c.id).hit_t = now


func note_mastery_boost(c: CarState, now: float) -> void:
	# Earned speed also ends a boost drought; it is not a consumed road item.
	_state(c.id).nitro_t = now


func _log(decision: Dictionary) -> void:
	decisions.append(decision)
	if decisions.size() > HISTORY_LIMIT:
		decisions.pop_front()


func snapshot() -> Dictionary:
	return {"seed": seed, "counts": counts.duplicate(true), "recent": decisions.duplicate(true)}
