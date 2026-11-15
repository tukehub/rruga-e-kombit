extends Node

const Rules = preload("res://scripts/sim/combat_rules.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func fixture(adaptive := false, reverse := false) -> Race:
	var track := RaceTrack.new()
	track.build({"id": "tirane", "hw": 10.0, "pts": [[-1000, 0, -1000], [1000, 0, -1000], [1000, 0, 1000], [-1000, 0, 1000]]}, reverse)
	var race := Race.new(track, {"seed": 83, "laps": 2, "adaptive_pickups": adaptive})
	race.started = true
	race.time = 20.0
	move(race, race.player, 1000)
	race.player.v = 30.0
	for c: CarState in race.cars:
		if c != race.player:
			move(race, c, 2000.0 + c.id * 80.0)
	race.compute_order()
	return race

func move(race: Race, c: CarState, progress: float, d := 0.0) -> void:
	c.progress = progress
	c.s = race.track.mod_s(progress)
	c.d = d

func equip(c: CarState, kind: String) -> void:
	c.slots = [{"type": kind, "ammo": int(Data.PW[kind].ammo)}]

func _ready() -> void:
	targets_and_denials()
	incoming_warnings()
	chain_recovery()
	inventory_policy()
	drift_rewards()
	await get_tree().process_frame
	print("COMBAT RECOVERY: targeting/denials, incoming threats, bounded disabling chains, inventory/adaptation and earned boost; failures=", failures)
	get_tree().quit(1 if failures else 0)

func targets_and_denials() -> void:
	var race := fixture()
	var c := race.player
	var other := race.cars[0]
	equip(c, "eagle")
	race.use_item(c, false)
	check(c.slots.size() == 1 and race.projs.is_empty() and race.events[-1].why == "no_target", "homing ammunition survives a denied target")
	move(race, other, c.progress + 60)
	other.v = 20.0
	check(race.item_status(c).ready and race.item_status(c).target == other, "HUD query selects the actual forward target")
	race.use_item(c, false)
	check(c.slots.is_empty() and race.projs[-1].target == other, "homing fire uses the queried target")
	equip(c, "eagle")
	other.invuln_t = 1.0
	check(not race.item_status(c).ready, "respawn-protected cars are not advertised as homing targets")
	other.invuln_t = 0.0
	other.wreck_t = 1.0
	check(not race.item_status(c).ready, "wrecks are not valid targets")
	other.wreck_t = 0.0
	move(race, other, c.progress - 50)
	check(race.item_status(c, true).target == other and not race.item_status(c).ready, "forward/reverse availability is independent")
	other.v = -9.0
	move(race, other, c.progress - 140)
	check(not race.item_status(c, true).ready, "homing availability respects flight lifetime and closing speed")
	equip(c, "bolt")
	move(race, other, c.progress + 900)
	race.use_item(c, false)
	check(int(c.slots[0].ammo) == 2 and race.projs[-1].kind == "bolt", "straight shots keep deliberate free fire")
	equip(c, "barge")
	race.use_item(c, false)
	check(c.slots.size() == 1 and race.events[-1].why == "too_far", "close-range attack cannot be wasted outside its radius")
	move(race, other, c.progress + 8)
	check(race.item_status(c).target == other, "close-range target is within the real footprint")
	race.use_item(c, false)
	check(c.slots.is_empty() and other.recovery_t > 0, "valid barge applies a hit")
	equip(c, "repair")
	race.use_item(c, false)
	check(c.slots.size() == 1 and race.events[-1].why == "full", "full health has a precise nonconsuming denial")
	c.health *= 0.4
	race.use_item(c, false)
	check(c.health == c.max_hp and c.slots.is_empty(), "repair is useful after damage")
	equip(c, "shield")
	race.use_item(c, false)
	equip(c, "shield")
	race.use_item(c, false)
	check(c.slots.size() == 1 and race.events[-1].why == "shield_active", "active shield is not silently overwritten")
	equip(c, "nitro")
	race.use_item(c, false)
	equip(c, "nitro")
	race.use_item(c, false)
	check(c.slots.size() == 1 and race.events[-1].why == "nitro_active", "active turbo has an explicit denial")
	race.use_item(c, true)
	check(c.slots.is_empty() and c.nitro_t == 0.0 and c.hbrake_t > 0.0, "reverse Nitro consumes a deliberate brake and stops active turbo")
	var lead := race.leader()
	equip(c, "shock")
	lead.recovery_t = 1.0
	race.use_item(c, false)
	check(c.slots.size() == 1 and race.events[-1].why == "target_recovery", "storm waits for a recovering leader")
	lead.recovery_t = 0.0
	race.use_item(c, false)
	check(race.domes.size() == 3 and c.slots.is_empty(), "valid storm creates the expected three warnings")
	equip(c, "shock")
	race.use_item(c, false)
	check(race.domes.size() == 3 and c.slots.size() == 1 and race.events[-1].why == "storm_active", "carried storms cannot pile up across active domes")
	var rng_state := race.rng.state
	for i in 100:
		race.item_status(c)
		race.item_status(c, true)
		race.incoming_threat(c)
	check(race.rng.state == rng_state, "presentation queries never alter combat randomness")

func incoming_warnings() -> void:
	for reverse in [false, true]:
		var race := fixture(false, reverse)
		var c := race.player
		var shooter := race.cars[0]
		move(race, shooter, c.progress - 100)
		equip(shooter, "eagle")
		race.use_item(shooter, false)
		var threat := race.incoming_threat(c)
		check(not threat.is_empty() and str(threat.direction).begins_with("PRAPA") and not threat.urgent, "real incoming homing shot warns early on either track direction")
		if threat.is_empty():
			continue
		c.shield_t = 8.0
		check(race.incoming_threat(c).shielded, "warning recognizes a shield lasting through estimated arrival")
		c.shield_t = 0.0
		race.projs[0].d = c.d + 4.0
		check(str(race.incoming_threat(c).direction).ends_with("DJATHTAS"), "incoming side uses the driver's right track frame")
		race.projs[0].d = c.d - 4.0
		check(str(race.incoming_threat(c).direction).ends_with("MAJTAS"), "incoming side reverses consistently with the track frame")
		race.projs[0].s = race.track.mod_s(c.s - 25)
		check(race.incoming_threat(c).urgent, "near impact escalates urgency")
		race.projs[0].life = 0.01
		check(race.incoming_threat(c).is_empty(), "projectiles expiring before arrival do not make false warnings")
		race.projs[0].life = 7.0
		race.projs[0].kind = "bolt"
		check(race.incoming_threat(c).is_empty(), "straight projectiles are not falsely reported as locked homing")
		race.projs.clear()
		move(race, c, 2.0)
		move(race, shooter, race.L - 80)
		equip(shooter, "eagle")
		race.use_item(shooter, false)
		check(not race.incoming_threat(c).is_empty(), "threat detection works across the lap seam")
		race.projs.clear()
		move(race, shooter, c.progress + 65)
		equip(shooter, "eagle")
		race.use_item(shooter, true)
		check(str(race.incoming_threat(c).get("direction", "")).begins_with("PARA"), "reverse-fired homing approach is reported from ahead")
		c.finished = true
		check(race.incoming_threat(c).is_empty(), "finished racers have no incoming alarms")

func chain_recovery() -> void:
	var race := fixture()
	var c := race.player
	var by := race.cars[0]
	c.max_hp = 1000.0
	c.health = c.max_hp
	c.v = 40.0
	race.hit(c, by, "eagle", 34.0, {"spin": true})
	check(c.spin_t == 1.15 and is_equal_approx(c.v, 14.0), "first disabling hit retains normal force")
	var recovery := c.recovery_t
	var hop := c.hop_v
	var hp := c.health
	race.hit(c, by, "shock", 20.0, {"spin": true, "slow": 0.1, "stun": 20.0, "push": 50.0, "hop": 40.0})
	check(c.recovery_t == recovery and c.spin_t == 1.15 and c.stun_t == 0.0 and c.lat_v == 0.0 and c.hop_v == hop and is_equal_approx(c.v, 14.0), "follow-up effects cannot extend control loss or multiply slowing")
	check(is_equal_approx(hp - c.health, 20 * Rules.RECOVERY_DAMAGE_SCALE) and c.chain_hits == 1, "recovery reduces damage without creating invulnerability")
	for i in 180:
		race.physics(c, 1.0 / 60.0)
		if i % 30 == 0:
			race.hit(c, by, "mine", 1, {"stun": 2.2, "slow": 0.5})
	check(c.spin_t <= 0.0 and c.stun_t <= 0.0 and c.recovery_t < 0.6, "repeated attacks cannot refresh the fixed window")
	for i in 32:
		race.physics(c, 1.0 / 60.0)
	check(c.recovery_t == 0.0, "recovery expires in finite simulation time")
	race.hit(c, by, "shock", 20, {"stun": 2.2})
	check(c.stun_t == 2.2 and c.recovery_t == Rules.RECOVERY_DURATION, "new attacks work normally after the grace period")
	var bot := race.cars[1]
	bot.v = 40.0
	race.hit(bot, c, "eagle", 5, {"spin": true})
	race.hit(bot, c, "shock", 5, {"stun": 2.2})
	check(bot.recovery_t == Rules.RECOVERY_DURATION and bot.stun_t == 0.0, "bots get the same anti-chain rules")
	c.health = 1.0
	race.hit(c, by, "bolt", 11, {"slow": 0.86})
	check(c.wreck_t > 0 and c.recovery_t == 0.0, "recovery still permits a wreck and resets on it")
	for i in 145:
		race.physics(c, 1.0 / 60.0)
	var respawn_hp := c.health
	race.hit(c, by, "eagle", 34, {"spin": true})
	check(c.invuln_t > 0.0 and c.health == respawn_hp and c.spin_t <= 0.0, "respawn protection remains independent and complete")
	# Dense offense must leave real recovery/driving intervals, not just a
	# countdown that refreshes whenever another attacker connects.
	race = fixture()
	c = race.player
	c.max_hp = 100000.0
	c.health = c.max_hp
	c.ctrl.gas = true
	c.v = 40.0
	var start := c.progress
	var longest := 0.0
	var run := 0.0
	var clear_time := 0.0
	for i in 600:
		if i % 12 == 0:
			race.hit(c, race.cars[0], "shock", 20, {"spin": true, "stun": 2.2, "slow": 0.5})
		race.physics(c, 1.0 / 60.0)
		if c.spin_t > 0.0 or c.stun_t > 0.0:
			run += 1.0 / 60.0
			longest = maxf(longest, run)
		else:
			run = 0.0
			clear_time += 1.0 / 60.0
	check(longest <= 2.25 and clear_time > 2.5 and c.progress - start > 50.0, "a ten-second five-hit-per-second stream cannot keep the car disabled or stationary indefinitely")

func inventory_policy() -> void:
	var race := fixture(true)
	var c := race.player
	c.slots = [{"type": "bolt", "ammo": 2}, {"type": "repair", "ammo": 1}, {"type": "shield", "ammo": 1}]
	var selected: Dictionary = c.slots[0]
	check(race.has_pickup_room(c) and race.pickup_slot(c, "nitro") == 1, "full inventory exposes a blocked reserve as replacement room")
	check(race.pickup_slot(c, "shield") < 0, "replacement cannot add a duplicate")
	var p := {"id": 999, "s": c.s, "d": c.d, "type": "nitro", "alive": true, "t": 0.0}
	race.pickups = [p]
	race.update_pickups(0.0)
	check(c.slots.size() == 3 and is_same(selected, c.slots[0]) and c.slots[1].type == "nitro" and not p.alive, "real collection replaces the blocked reserve without changing selected ammo")
	check(race.events[-1].slot == 1 and race.events[-1].replaced == "repair", "replacement event identifies the actual slot and removed item")
	c.slots = [{"type": "repair", "ammo": 1}, {"type": "bolt", "ammo": 2}, {"type": "shield", "ammo": 1}]
	check(not race.has_pickup_room(c), "selected reserve is never automatically replaced")
	c.slots = [{"type": "bolt", "ammo": 2}, {"type": "repair", "ammo": 1}, {"type": "shield", "ammo": 1}]
	c.health *= 0.5
	check(not race.has_pickup_room(c), "useful repair is not discarded by collection")
	c.health = c.max_hp
	var token: Dictionary = c.slots[1]
	var impostor: Dictionary = token.duplicate()
	check(not race.discard_item(c, impostor) and c.slots.size() == 3, "an equal-value dictionary cannot discard a different item")
	c.slots.push_front(c.slots.pop_back())
	c.ctrl.discard = token
	c.ctrl.fire = true
	race.step(1.0 / 60.0)
	check(c.slots.size() == 2 and c.slots[0].type == "shield" and c.slots[1].type == "bolt" and not c.ctrl.fire and c.ctrl.discard.is_empty(), "discard follows exact item across reordering and suppresses simultaneous accidental fire")
	check(not race.discard_item(c, token), "a consumed discard token cannot remove the next slot")
	# Leadership can change during physics before the cached standings sort.
	c.slots = [{"type": "bolt", "ammo": 3}, {"type": "shock", "ammo": 1}, {"type": "shield", "ammo": 1}]
	move(race, c, 4000.0)
	check(race.pickup_slot(c, "nitro") == 1, "leading Shock reserve can be replaced using live progress")
	move(race, race.cars[0], 4010.0)
	check(race.pickup_slot(c, "nitro") < 0 and race.item_status(c, false, "shock").ready, "an unsorted overtake immediately protects a now-useful Shock reserve")
	# Adaptive offers use the same capacity/utility policy, with a fixed node pool.
	race = fixture(true)
	c = race.player
	c.v = 45.0
	c.slots = [{"type": "bolt", "ammo": 3}, {"type": "repair", "ammo": 1}, {"type": "shield", "ammo": 1}]
	var count := race.pickups.size()
	var weights: Dictionary = race.pickup_director.weights(race, c, c.s + 200)
	check(weights.nitro > 0.0 and weights.bolt == 0.0, "full-inventory planning offers useful replacement, not duplicates")
	for i in 12:
		race.time += 0.25
		race.pickup_director.advance(race, 0.25)
	check(race.pickup_director.counts.help_offers > 0 and race.pickups.size() == count, "blocked reserve capacity can receive a bounded shared adaptive opportunity")
	var lead := race.leader()
	lead.recovery_t = 3.0
	check(race.pickup_director.weights(race, c, c.s + 200).shock == 0.0, "adaptive storms do not pressure a recovering leader")

func drift_rewards() -> void:
	var race := fixture(true)
	var c := race.player
	c.v = 30.0
	c.ctrl.brake = true
	c.ctrl.steer = 0.7
	c.steer = 0.7
	c.drift = 1.0
	c.drift_t = 0.49
	race.physics(c, 1.0 / 60.0)
	check(c.skill_charge > 0.0 and c.fans >= 5.0, "real clean drift physics earns stored utility alongside fans")
	c.skill_charge = 0.0
	for i in 300:
		Rules.advance_drift(race, c, 1.0 / 60.0, 30.0 / 60.0)
	check(c.skill_charge == 1.0, "clean forward drift charge is banked and capped at one boost")
	var ready_events := 0
	for event: Dictionary in race.events:
		if event.t == "drift_ready": ready_events += 1
	check(ready_events == 1, "holding a full charge does not repeat reward notifications")
	c.nitro_t = 2.0
	check(not race.use_skill_boost(c) and c.skill_charge == 1.0, "stored reward is preserved while another turbo is active")
	c.nitro_t = 0.0
	var inventory := JSON.stringify(c.slots)
	check(race.use_skill_boost(c) and c.skill_boosts == 1 and c.nitro_t == Rules.DRIFT_BOOST_DURATION and c.skill_charge == 0.0, "earned boost gives a useful short turbo without a pickup")
	check(JSON.stringify(c.slots) == inventory and not race.use_skill_boost(c), "earned turbo neither consumes inventory nor repeats without earning another")
	check(race.pickup_director.history[c.id].nitro_t == race.time and not race.pickup_director.counts.used.has("nitro"), "earned boost ends drought without pretending a road item was used")
	c.nitro_t = 0.0
	for reason in ["scrape", "recovery_t", "stun_t", "spin_t", "hop", "invuln_t"]:
		c.skill_charge = 0.0
		c.set(reason, 1.0)
		Rules.advance_drift(race, c, 1.0, 1000.0)
		check(c.skill_charge == 0.0, "drift reward rejects wall/disable/air/protected farming " + reason)
		c.set(reason, 0.0)
	Rules.advance_drift(race, c, 1.0, -30.0)
	check(c.skill_charge == 0.0, "reversing cannot charge the reward")
	c.v = 0.0
	Rules.advance_drift(race, c, 1.0, 1000.0)
	check(c.skill_charge == 0.0, "stationary steering cannot charge the reward")
	c.v = 30.0
	Rules.advance_drift(race, c, 0.1, 1000.0)
	check(is_equal_approx(c.skill_charge, 0.03), "charge distance is bounded by real forward speed")
	c.finished = true
	var saved := c.skill_charge
	Rules.advance_drift(race, c, 5.0, 1000.0)
	check(c.skill_charge == saved and not race.use_skill_boost(c), "finish cannot earn or spend a reward")
	c.finished = false
	var samples: Array[float] = []
	for hz in [30, 60, 120]:
		c.skill_charge = 0.0
		for i in hz * 2:
			Rules.advance_drift(race, c, 1.0 / hz, 30.0 / hz)
		samples.append(c.skill_charge)
	check(absf(samples[0] - 0.6) < 0.00001 and absf(samples[1] - samples[0]) < 0.00001 and absf(samples[2] - samples[0]) < 0.00001, "clean drift distance earns the same charge across frame rates")
