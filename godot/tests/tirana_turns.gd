extends Node

func _ready() -> void:
	# Corner assist: held on the centreline with the gas down, the assisted car
	# must reach the tightest bend at a speed its tyres can carry; without the
	# assist the same run arrives far too fast.
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
		p.progress = bend_track.L + worst_s - 260.0
		p.s = bend_track.mod_s(p.progress)
		p.v = 40.0
		p.ctrl.gas = true
		p.ctrl.steer = 0.0
		var peak := 0.0
		var slowest := INF
		for i in 600:
			p.d = 0.0
			p.yaw = 0.0
			p.lat_v = 0.0
			bend_race.physics(p, 1.0 / 60.0)
			peak = maxf(peak, p.v * p.v * absf(bend_track.curv(p.s)))
			slowest = minf(slowest, p.v)
		var grip_accel := float(p.def.grip) * 29.0
		if assisted:
			assert(peak <= grip_accel * Race.CORNER_ASSIST_GRIP * 1.15, "corner assist must slow the car to what its tyres can carry")
			assert(slowest >= Race.CORNER_ASSIST_MIN_SPEED - 0.01, "corner assist must never slow the car to a crawl")
		else:
			assert(peak > grip_accel * 1.5, "without the assist the same run must arrive too fast")
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
	# relaxed response is limited to human control in Tirana.
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
	assert(tirana_yaw > c.yaw * 1.2, "extra cornering authority must be confined to Tirana")
	print("TIRANA TURNS: steering response and simultaneous gas/brake passed")
	get_tree().quit()
