extends Node
## Headless sim smoke test:
##   godot --headless --path godot res://tests/sim_test.tscn
## Loads the Tirana track, runs a bot-only race, prints order + timing.

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var track := RaceTrack.load_city("tirane")
	if track == null:
		push_error("track load failed")
		get_tree().quit(1)
		return
	print("track: ", track.stats())
	var race := Race.new(track, {"laps": 2, "diff": 1, "seed": 42, "no_player": true})
	race.started = true
	print("cars: ", race.cars.size(), "  pickups: ", race.pickups.size())
	var dt := 1.0 / 60.0
	var steps := 0
	var ev_count := {}
	while not race.all_finished() and steps < 60 * 600:
		race.step(dt)
		for e in race.take_events():
			var k: String = e.t
			ev_count[k] = int(ev_count.get(k, 0)) + 1
		steps += 1
	print("sim steps: ", steps, "  sim time: %.1f s" % race.time, "  all finished: ", race.all_finished())
	print("events: ", ev_count)
	for c in race.order:
		print("  P%d %-22s laps=%d fin=%s best=%s hp=%.0f wrecks=%d hits=%d v=%.1f" % [
			c.place, c.name, c.lap, Game.fmt_time(c.finish_time), Game.fmt_time(c.best_lap),
			c.health, c.wrecks, c.hits, c.v])
	var ms := Time.get_ticks_msec() - t0
	print("wall: %d ms  (%.3f ms/step)" % [ms, float(ms) / maxi(steps, 1)])
	# determinism check
	var r2 := Race.new(track, {"laps": 2, "diff": 1, "seed": 42, "no_player": true})
	r2.started = true
	for i in 600:
		r2.step(dt)
	var r3 := Race.new(track, {"laps": 2, "diff": 1, "seed": 42, "no_player": true})
	r3.started = true
	for i in 600:
		r3.step(dt)
	var same := true
	for i in r2.cars.size():
		if not is_equal_approx(r2.cars[i].s, r3.cars[i].s):
			same = false
	print("deterministic: ", same)
	get_tree().quit(0)
