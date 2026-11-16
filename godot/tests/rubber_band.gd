extends Node
## Rubber band (README 2.4): bots behind the player catch up a little, bots
## ahead of the player and a runaway leading bot are held back a little, all
## from the numbers in Data.DIFFS. Fixed-step races check the finish spread.

const STEP := 1.0 / 60.0
const KEYS := ["catch_up", "lead_drag", "band", "runaway_gap", "runaway_drag"]
# Finish spread (last minus first), as a share of the winner's time.
const SPREAD_LIMIT := 0.17
const MEAN_SPREAD_LIMIT := 0.10

var failures := 0
var track: RaceTrack

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func new_race(opt: Dictionary) -> Race:
	var options := {"seed": 5, "laps": 1}
	options.merge(opt, true)
	var race := Race.new(track, options)
	race.started = true
	return race

func without_band(race: Race) -> Race:
	race.diff = race.diff.duplicate()
	for key in ["catch_up", "lead_drag", "runaway_drag"]:
		race.diff[key] = 0.0
	return race

## Line the field up `gap` metres apart behind the first car, on the lap.
func line_up(race: Race, first: CarState, gap: float) -> void:
	var at := 600.0
	first.progress = at
	for c in race.cars:
		if c != first:
			at -= gap
			c.progress = at
	for c in race.cars:
		c.s = track.mod_s(c.progress)
	race.compute_order()

func bots(race: Race) -> Array:
	return race.cars.filter(func(c: CarState) -> bool: return not c.is_player)

## A whole race with the AI driving the player's car at `pace` of its top speed.
func spread(diff: int, seed_value: int, pace: float, band: bool) -> Dictionary:
	var race := new_race({"diff": diff, "seed": seed_value})
	if not band:
		without_band(race)
	race.player.autopilot = true
	var steps := 0
	while not race.all_finished() and steps < 60 * 400:
		race.step(STEP)
		race.player.vmax_mul = pace
		race.take_events()
		steps += 1
	var times := []
	for c in race.cars:
		times.append(c.finish_time)
	times.sort()
	return {"done": race.all_finished(), "first": float(times[0]), "spread": float(times[-1]) - float(times[0])}

func _ready() -> void:
	track = RaceTrack.load_city("tirane")

	# The numbers live in Data.DIFFS and stay mild; harder rivals get less help.
	for i in Data.DIFFS.size():
		var d: Dictionary = Data.DIFFS[i]
		for key in KEYS:
			check(d.has(key) and float(d[key]) > 0.0, "difficulty %d sets %s" % [i, key])
		check(float(d.catch_up) <= 0.08 and float(d.lead_drag) <= 0.06 and float(d.runaway_drag) <= 0.05, "difficulty %d keeps the band mild" % i)
		check(float(d.lead_drag) <= float(d.catch_up), "difficulty %d slows leaders no more than it helps chasers" % i)
		if i > 0:
			var easier: Dictionary = Data.DIFFS[i - 1]
			check(float(d.catch_up) < float(easier.catch_up) and float(d.lead_drag) < float(easier.lead_drag) and float(d.runaway_drag) < float(easier.runaway_drag), "difficulty %d bands less than the one below" % i)

	for diff in Data.DIFFS.size():
		var d: Dictionary = Data.DIFFS[diff]
		# Bots behind the player: nothing level, a share part-way, the cap beyond the band.
		var race := new_race({"diff": diff})
		var bot: CarState = bots(race)[0]
		for c in race.cars:
			c.progress = 600.0
		race.compute_order()
		check(is_equal_approx(race.rubber_band(bot), 1.0), "a bot level with the player gets no help (%d)" % diff)
		race.player.progress = 600.0 + float(d.band) * 0.5
		race.compute_order()
		check(is_equal_approx(race.rubber_band(bot), 1.0 + float(d.catch_up) * 0.5), "catch-up grows with the gap (%d)" % diff)
		race.player.progress = 600.0 + float(d.band) * 6.0
		race.compute_order()
		check(is_equal_approx(race.rubber_band(bot), 1.0 + float(d.catch_up)), "catch-up is capped (%d)" % diff)
		# Bots ahead of the player, bunched so nobody is a runaway.
		race.player.progress = 600.0 - float(d.band) * 6.0
		race.compute_order()
		check(is_equal_approx(race.rubber_band(bot), 1.0 - float(d.lead_drag)), "a bot ahead of the player is held back, capped (%d)" % diff)
		# The band reaches the car through vmax_mul; the player's car never changes.
		race.step(STEP)
		check(is_equal_approx(bot.vmax_mul, float(d.speed) * bot.ai.skill * race.rubber_band(bot)), "the band scales the bot's top speed (%d)" % diff)
		check(race.player.vmax_mul == 1.0 and race.rubber_band(race.player) == 1.0, "the player's car is never banded (%d)" % diff)

		# Runaway leader: only the leading bot, only beyond the gap. The player
		# has finished here, so nothing else is acting.
		race = new_race({"diff": diff})
		race.player.finished = true
		race.player.finish_time = 1.0
		var field := bots(race)
		var leader: CarState = field[0]
		line_up(race, leader, float(d.runaway_gap))
		check(is_equal_approx(race.rubber_band(leader), 1.0), "a lead inside the gap costs nothing (%d)" % diff)
		line_up(race, leader, float(d.runaway_gap) * 1.5)
		check(is_equal_approx(race.rubber_band(leader), 1.0 - float(d.runaway_drag) * 0.5), "runaway drag grows beyond the gap (%d)" % diff)
		line_up(race, leader, float(d.runaway_gap) * 5.0)
		check(is_equal_approx(race.rubber_band(leader), 1.0 - float(d.runaway_drag)), "runaway drag is capped (%d)" % diff)
		for c: CarState in field:
			check(c == leader or is_equal_approx(race.rubber_band(c), 1.0), "only the leader is dragged (%d)" % diff)
		leader.finished = true
		race.compute_order()
		check(race.rubber_band(leader) == 1.0, "a finished car is not banded (%d)" % diff)
		# A player far in front is not a bot: no drag for them, help for the rest.
		race = new_race({"diff": diff})
		line_up(race, race.player, 400.0)
		check(race.rubber_band(race.player) == 1.0 and bots(race).all(func(c: CarState) -> bool: return race.rubber_band(c) >= 1.0 + float(d.catch_up) - 0.0001), "a runaway player is chased, not slowed (%d)" % diff)

	# Whole races, fixed steps, a slow and a quick driver in the player's car.
	var banded := 0.0
	var loose := 0.0
	var runs := 0
	for diff in Data.DIFFS.size():
		for seed_value in [3, 11]:
			for pace in [0.9, 1.04]:
				var on := spread(diff, seed_value, pace, true)
				var off := spread(diff, seed_value, pace, false)
				check(on.done and off.done, "every car finishes (diff %d seed %d pace %.2f)" % [diff, seed_value, pace])
				var share: float = on.spread / on.first
				print("RUBBER BAND diff=%d seed=%d pace=%.2f spread %.1f s (%.1f%%), without %.1f s" % [diff, seed_value, pace, on.spread, share * 100.0, off.spread])
				check(share < SPREAD_LIMIT, "finish spread inside the window (diff %d seed %d pace %.2f)" % [diff, seed_value, pace])
				banded += share
				loose += off.spread / off.first
				runs += 1
	print("RUBBER BAND mean spread %.1f%% with the band, %.1f%% without" % [banded / runs * 100.0, loose / runs * 100.0])
	check(banded / runs < MEAN_SPREAD_LIMIT, "mean finish spread inside the target window")
	check(banded < loose, "the band brings the field closer than no band")
	var replay_a := spread(1, 3, 0.9, true)
	var replay_b := spread(1, 3, 0.9, true)
	check(replay_a.first == replay_b.first and replay_a.spread == replay_b.spread, "a banded race replays exactly")

	if failures == 0:
		print("RUBBER BAND: catch-up, lead drag, runaway drag and finish spread passed")
	get_tree().quit(1 if failures else 0)
