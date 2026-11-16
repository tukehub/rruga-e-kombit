extends Node
## Combat counterplay (README 2.5): a bolt fired at an eagle that hunts its
## owner shoots it down, bots use that defence, and the pickup director
## weights its offers by standing, most of all for the car in last place.

const STEP := 1.0 / 60.0

var failures := 0
var track: RaceTrack

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

## A race on a straight road with the player mid-lap and one attacker; the
## other cars are parked far away.
func duel(seed_value := 9) -> Race:
	var race := Race.new(track, {"seed": seed_value, "laps": 3, "diff": 2})
	race.started = true
	race.time = 20.0
	var spot := 2000.0
	for c in race.cars:
		spot += 200.0
		c.progress = spot
		c.s = track.mod_s(spot)
		c.d = 0.0
		c.v = 0.0
	var p := race.player
	p.progress = 600.0
	p.s = 600.0
	p.v = 40.0
	p.slots = [{"type": "bolt", "ammo": 3}]
	race.compute_order()
	race.take_events()
	return race

func attacker(race: Race) -> CarState:
	return race.cars.filter(func(c: CarState) -> bool: return not c.is_player)[0]

## An eagle hunting `target`, `gap` metres behind it (ahead and flying
## backward when `from_ahead`), `lane` metres to the side.
func eagle(race: Race, target: CarState, gap: float, lane: float, from_ahead := false) -> Dictionary:
	var e := {"id": 9000 + race.projs.size(), "kind": "eagle", "owner": attacker(race),
		"s": track.mod_s(target.s + (gap if from_ahead else -gap)), "d": target.d + lane,
		"dir": -1.0 if from_ahead else 1.0, "speed": 32.0 if from_ahead else 80.0, "target": target, "life": 6.0, "born": race.time}
	race.projs.append(e)
	return e

## Fly the shots until they are spent; the player holds its speed and lane.
func fly(race: Race, seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / STEP):
		var p := race.player
		p.progress += p.v * STEP
		p.s = track.mod_s(p.progress)
		race.update_projs(STEP)
		events.append_array(race.take_events())
	return events

func of(events: Array, kind: String) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return e.t == kind)

func weights_at(race: Race, c: CarState, place: int) -> Dictionary:
	c.place = place
	return race.pickup_director.weights(race, c, c.s + 120.0)

func _ready() -> void:
	track = RaceTrack.load_city("tirane")
	track.K.fill(0.0)

	# Undefended, the eagle arrives.
	var race := duel()
	var player := race.player
	eagle(race, player, 70.0, 3.0)
	check(not race.incoming_threat(player).is_empty() and bool(race.incoming_threat(player).behind), "the eagle is reported as incoming from behind")
	var events := fly(race, 4.0)
	check(of(events, "hit").size() == 1 and of(events, "intercept").is_empty() and player.health < player.max_hp, "an undefended eagle strikes")

	# A bolt fired backward shoots it down, from any lane it approaches in.
	for lane in [0.0, 3.0, -5.0]:
		race = duel()
		player = race.player
		var hunter := eagle(race, player, 70.0, lane)
		var fans := player.fans
		race.use_item(player, true)
		check(race.projs.size() == 2 and int(player.slots[0].ammo) == 2, "firing backward spends one bolt (lane %.0f)" % lane)
		events = fly(race, 4.0)
		var caught := of(events, "intercept")
		check(caught.size() == 1 and caught[0].car == player and caught[0].by == attacker(race), "the backward bolt shoots the eagle down (lane %.0f)" % lane)
		check(of(events, "hit").is_empty() and player.health == player.max_hp, "the defended car is not struck (lane %.0f)" % lane)
		check(race.projs.is_empty() and not race.projs.has(hunter), "both shots are spent (lane %.0f)" % lane)
		check(player.fans == fans + float(Race.FANS.intercept) and int(Race.FANS.intercept) > 0, "the save earns fans (lane %.0f)" % lane)
		check(of(events, "boom").size() == 2, "both shots burst where they met (lane %.0f)" % lane)
		check(race.incoming_threat(player).is_empty(), "the warning clears (lane %.0f)" % lane)

	# The same defence forward, against an eagle fired back from a car ahead.
	race = duel()
	player = race.player
	eagle(race, player, 60.0, 2.5, true)
	race.use_item(player, false)
	events = fly(race, 4.0)
	check(of(events, "intercept").size() == 1 and of(events, "hit").is_empty(), "a forward bolt stops an eagle coming from ahead")

	# Fired the wrong way, the bolt does nothing for the defence.
	race = duel()
	player = race.player
	eagle(race, player, 70.0, 3.0)
	race.use_item(player, false)
	events = fly(race, 4.0)
	check(of(events, "intercept").is_empty() and of(events, "hit").size() == 1, "a bolt fired away from the eagle does not stop it")

	# Three bolts, three eagles.
	race = duel()
	player = race.player
	var saves := 0
	var struck := 0
	for i in 3:
		eagle(race, player, 70.0, 2.0)
		race.use_item(player, true)
		events = fly(race, 3.0)
		saves += of(events, "intercept").size()
		struck += of(events, "hit").size()
	check(saves == 3 and struck == 0 and player.slots.is_empty(), "each bolt of the three can stop an eagle")

	# With no eagle to stop, a backward bolt flies as it always did.
	race = duel()
	player = race.player
	race.use_item(player, true)
	var bolt: Dictionary = race.projs[0]
	var bolt_d: float = bolt.d
	fly(race, 0.5)
	check(race.projs.has(bolt) and bolt.d == bolt_d and float(bolt.dir) < 0.0, "a backward bolt with nothing to stop flies straight")
	# An eagle hunting someone else is not this bolt's business.
	race = duel()
	player = race.player
	var other: CarState = race.cars.filter(func(c: CarState) -> bool: return not c.is_player)[1]
	var stray := eagle(race, player, 70.0, 5.0)
	stray.target = other
	race.use_item(player, true)
	bolt = race.projs[1]
	bolt_d = bolt.d
	race.update_projs(STEP)
	race.update_projs(STEP)
	check(bolt.d == bolt_d and race._eagle_to_intercept(bolt).is_empty(), "a bolt does not chase an eagle aimed at another car")
	# The owner's own eagle is never a target for their bolt.
	race = duel()
	player = race.player
	var own := eagle(race, attacker(race), 70.0, 0.0)
	own.owner = attacker(race)
	own.target = attacker(race)
	check(race._eagle_to_intercept({"kind": "bolt", "owner": attacker(race), "s": own.s + 30.0, "d": 0.0, "dir": -1.0}).is_empty(), "nobody intercepts their own eagle")

	# Bots defend themselves the same way.
	var defended := 0
	var runs := 12
	for seed_value in runs:
		race = duel(100 + seed_value)
		var bot := attacker(race)
		bot.progress = 900.0
		bot.s = 900.0
		bot.v = 40.0
		bot.slots = [{"type": "bolt", "ammo": 3}]
		race.compute_order()
		var hunter := {"id": 9500, "kind": "eagle", "owner": race.player, "s": 860.0, "d": 2.0, "dir": 1.0, "speed": 80.0, "target": bot, "life": 6.0, "born": race.time}
		race.projs.append(hunter)
		race.ai_weapons(bot)
		var back_bolts := race.projs.filter(func(q: Dictionary) -> bool: return q.kind == "bolt" and q.owner == bot and float(q.dir) < 0.0)
		if back_bolts.size() == 1:
			defended += 1
	check(defended >= runs * 0.6 and defended < runs, "a hard bot usually, not always, fires back at an incoming eagle (%d of %d)" % [defended, runs])
	race = duel(100)
	var calm := attacker(race)
	calm.progress = 900.0
	calm.s = 900.0
	calm.slots = [{"type": "bolt", "ammo": 3}]
	race.compute_order()
	for i in 20:
		race.ai_weapons(calm)
	check(race.projs.is_empty() and int(calm.slots[0].ammo) == 3, "a bot with nothing to shoot at keeps its bolts")

	# Pickup weighting by standing.
	var director = race.pickup_director
	var n := race.cars.size()
	for kind in director.RANK_WEIGHTS:
		check(Data.PW.has(kind) and director.RANK_WEIGHTS[kind].size() == 2, "rank weights name a real pickup: %s" % kind)
	for kind in ["nitro", "eagle", "shock"]:
		check(float(director.RANK_WEIGHTS[kind][1]) > 1.0 and float(director.RANK_WEIGHTS[kind][1]) > float(director.RANK_WEIGHTS[kind][0]), "last place is offered more %s" % kind)
	for kind in ["mine", "shield"]:
		check(float(director.RANK_WEIGHTS[kind][1]) < 1.0 and float(director.RANK_WEIGHTS[kind][0]) > 1.0, "the leader, not last place, is offered more %s" % kind)
	race = duel()
	director = race.pickup_director
	var car := race.player
	car.slots = []
	# Rivals within reach both ways, so the attack and defence weights are live.
	var front := attacker(race)
	front.progress = car.progress + 60.0
	front.s = track.mod_s(front.progress)
	var rear: CarState = race.cars.filter(func(c: CarState) -> bool: return not c.is_player)[1]
	rear.progress = car.progress - 60.0
	rear.s = track.mod_s(rear.progress)
	check(director.rank_share(race, car) >= 0.0 and is_equal_approx(weights_at(race, car, 1).nitro / weights_at(race, car, n).nitro, 0.7 / 1.6), "nitro weight follows the standing")
	var first := weights_at(race, car, 1)
	var middle := weights_at(race, car, (n + 1) / 2)
	var last := weights_at(race, car, n)
	check(is_equal_approx(director.rank_share(race, car), 1.0), "last place is the far end of the standing scale")
	for kind in ["nitro", "eagle", "bolt"]:
		check(float(last[kind]) > float(middle[kind]) and float(middle[kind]) > float(first[kind]) and float(first[kind]) > 0.0, "%s is offered more toward the back" % kind)
	for kind in ["mine", "shield"]:
		check(float(last[kind]) < float(middle[kind]) and float(middle[kind]) < float(first[kind]) and float(last[kind]) > 0.0, "%s is offered more toward the front" % kind)
	check(is_equal_approx(float(first.barge), float(last.barge)) and is_equal_approx(float(first.repair), float(last.repair)), "pickups outside the table ignore the standing")
	# Standing scales a weight; it never revives one the situation rules out.
	car.shield_t = 5.0
	car.nitro_t = 2.0
	last = weights_at(race, car, n)
	first = weights_at(race, car, 1)
	check(float(last.shield) == 0.0 and float(first.shield) == 0.0 and float(last.nitro) == 0.0, "a ruled-out pickup stays ruled out at any standing")
	car.shield_t = 0.0
	car.nitro_t = 0.0
	var total_last := 0.0
	var total_first := 0.0
	last = weights_at(race, car, n)
	first = weights_at(race, car, 1)
	for kind in ["nitro", "eagle", "shock", "bolt"]:
		total_last += float(last[kind])
		total_first += float(first[kind])
	var sum_last := 0.0
	var sum_first := 0.0
	for kind in last:
		sum_last += float(last[kind])
		sum_first += float(first[kind])
	check(total_last / sum_last > total_first / sum_first + 0.1, "last place draws comeback items noticeably more often")

	if failures == 0:
		print("COMBAT COUNTERPLAY: bolt intercept, bot defence and standing-weighted pickups passed")
	get_tree().quit(1 if failures else 0)
