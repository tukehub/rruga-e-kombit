extends Node

func _ready() -> void:
	_check_finish_assist()
	# Corner assist: held on the centreline with the gas down, the assisted car
	# gets a short, light speed trim close to the bend, not a long slowdown.
	# The driver remains responsible for stronger braking in a tight bend.
	var end_speed := {}
	for assisted in [true, false]:
		var bend_track := RaceTrack.load_city("tirane")
		var bend_race := Race.new(bend_track, {"seed": 13, "brake_assist": assisted})
		bend_race.started = true
		var worst_s := 0.0
		var worst_k := 0.0
		var probe := 0.0
		while probe < bend_track.L:
			var probe_k := absf(bend_track.curv(probe))
			if probe_k > worst_k:
				worst_k = probe_k
				worst_s = probe
			probe += 3.0
		assert(worst_k > 0.03, "Tirana must contain a tight bend for this check")
		var p := bend_race.player
		p.progress = bend_track.L + worst_s - 40.0
		p.s = bend_track.mod_s(p.progress)
		p.v = 40.0
		p.ctrl.gas = true
		p.ctrl.steer = 0.0
		var peak := 0.0
		var slowest := INF
		var first_trim := -1
		for i in 60:
			p.d = 0.0
			p.yaw = 0.0
			p.lat_v = 0.0
			var before_speed := p.v
			bend_race.physics(p, 1.0 / 60.0)
			assert(p.v >= before_speed - 2.1 / 60.0, "automatic corner braking must remain gentle per tick")
			if first_trim < 0 and p.braking:
				first_trim = i
			peak = maxf(peak, p.v * p.v * absf(bend_track.curv(p.s)))
			slowest = minf(slowest, p.v)
		var grip_accel := float(p.def.grip) * 29.0
		end_speed[assisted] = p.v
		if assisted:
			assert(slowest >= 37.9, "corner assist should take off only a few km/h")
			assert(first_trim >= 10, "corner assist must start close to the bend, not 40 m out (tick %d)" % first_trim)
			assert(slowest >= Race.CORNER_ASSIST_MIN_SPEED - 0.01, "corner assist must never slow the car to a crawl")
		else:
			assert(first_trim < 0 and peak > grip_accel * 1.5, "without the assist the same run must arrive too fast")
	assert(end_speed[true] < end_speed[false] - 2.0, "the assist still takes speed off before the bend")
	# With no bends ahead the assist must change nothing at all.
	var flat_track := RaceTrack.load_city("tirane")
	flat_track.K.fill(0.0)
	var flat_speeds: Array[float] = []
	for assisted in [true, false]:
		var flat_race := Race.new(flat_track, {"seed": 13, "brake_assist": assisted})
		flat_race.started = true
		var q := flat_race.player
		q.v = 30.0
		q.ctrl.gas = true
		for i in 120:
			flat_race.physics(q, 1.0 / 60.0)
		flat_speeds.append(q.v)
	assert(is_equal_approx(flat_speeds[0], flat_speeds[1]) and flat_speeds[0] > 35.0, "corner assist must not hold the car back on a straight")
	var track := RaceTrack.load_city("tirane")
	track.K.fill(0.0)
	var race := Race.new(track, {"seed": 13})
	race.started = true
	race.hw = 1000.0
	var c := race.player
	c.s = 0.0
	c.progress = 0.0
	c.d = 0.0
	c.yaw = 0.0
	c.steer = 0.7
	c.v = 30.0
	c.ctrl.steer = 0.7
	c.ctrl.gas = true
	c.ctrl.brake = true
	for i in 60:
		race.physics(c, 1.0 / 60.0)
	assert(c.v < 24.0 and c.v > 22.0, "Tirana driver must brake progressively while steering, even when gas is held")
	assert(c.braking and not c.gas_on, "visuals and sound must follow braking priority during a turn")
	# Compare the exact same isolated steering input at the same speed. The
	# relaxed response is the human player's in every city, never the bots'.
	c.ctrl.gas = false
	c.ctrl.brake = false
	c.ctrl.steer = 1.0
	c.steer = 1.0
	c.v = 25.0
	c.d = 0.0
	c.yaw = 0.0
	c.lat_v = 0.0
	race.physics(c, 1.0 / 60.0)
	var tirana_yaw := c.yaw
	c.v = 25.0
	c.d = 0.0
	c.yaw = 0.0
	c.lat_v = 0.0
	track.id = "vlore"
	race.physics(c, 1.0 / 60.0)
	# The second step inherits a little smoothed state from the first (~2%);
	# the old Tirana-only tune differed by more than 20%.
	assert(absf(tirana_yaw - c.yaw) <= 0.05 * tirana_yaw, "the player's cornering response must be the same in every city")
	c.v = 25.0
	c.d = 0.0
	c.yaw = 0.0
	c.lat_v = 0.0
	c.autopilot = true
	race.physics(c, 1.0 / 60.0)
	c.autopilot = false
	track.id = "tirane"
	assert(tirana_yaw > c.yaw * 1.2, "extra cornering authority must be confined to the human player")
	print("TIRANA TURNS: steering response and simultaneous gas/brake passed")
	get_tree().quit()


func _check_finish_assist() -> void:
	for reverse in [false, true]:
		var track := RaceTrack.load_city("tirane", reverse)
		# Force a bend even where the actual finishing straight is flat, so
		# the check proves the assistant is suppressed rather than unneeded.
		track.K.fill(0.04)
		for laps in [1, 2]:
			for distance in [151.0, 150.0, 50.0, 1.0, -1.0, track.L + 50.0, laps * track.L + 25.0]:
				var states: Array[CarState] = []
				for enabled in [false, true]:
					var race := Race.new(track, {"laps": laps, "seed": 13, "assist": enabled, "brake_assist": enabled})
					race.started = true
					race.hw = 1000.0
					var c := race.player
					c.progress = laps * track.L - distance
					c.s = track.mod_s(c.progress)
					c.d = 0.0
					c.yaw = 0.2
					c.v = 40.0
					c.steer = 0.25
					c.ctrl.steer = 0.25
					c.ctrl.gas = true
					race.physics(c, 1.0 / 60.0)
					states.append(c)
					assert(race.brake_assist == enabled, "finish override must preserve the selected preference")
					if distance <= 150.0:
						assert(race.take_events().is_empty(), "finish approach must not emit automatic braking feedback")
				if distance <= 150.0:
					assert(is_equal_approx(states[0].v, states[1].v) and states[1].v > 40.0, "finish approach must allow acceleration through a bend")
					assert(is_equal_approx(states[0].yaw, states[1].yaw), "finish approach must use the unassisted steering response")
					assert(not states[1].braking, "finish approach must release automatic brake lights")
				else:
					assert(states[1].v < states[0].v and states[1].braking, "assistance must remain active outside the final approach, including earlier laps and the start")
		# Manual brakes still work in the automatic-assistance exclusion zone.
		var race := Race.new(track, {"laps": 1, "brake_assist": true})
		race.started = true
		var c := race.player
		c.progress = track.L - 50.0
		c.s = track.mod_s(c.progress)
		c.v = 40.0
		c.brake_force = 1.0
		c.ctrl.gas = true
		c.ctrl.brake = true
		race.physics(c, 1.0 / 60.0)
		assert(c.v < 40.0 and c.braking, "manual braking must remain effective near the finish")
	print("FINISH ASSIST: final 150 m, boundary, earlier laps, starting grid, reverse and manual brakes passed")
