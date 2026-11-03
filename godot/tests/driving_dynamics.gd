extends Node

func _ready() -> void:
	var track := RaceTrack.load_city("tirane")
	track.K.fill(0.0)
	var race := Race.new(track, {"seed": 1})
	race.started = true
	var car := race.player
	car.d = 0.0
	car.yaw = 0.0
	car.v = 0.0
	car.ctrl.gas = true
	var acceleration_time := 0.0
	while car.v < 100.0 / 3.6 and acceleration_time < 10.0:
		race.physics(car, 1.0 / 60.0)
		acceleration_time += 1.0 / 60.0
	assert(acceleration_time > 3.0 and acceleration_time < 5.5, "0–100 km/h should take a plausible sports-car interval")
	car.ctrl.gas = false
	car.ctrl.brake = true
	var start := car.progress
	var stop_time := 0.0
	while car.v > 0.5 and stop_time < 8.0:
		race.physics(car, 1.0 / 60.0)
		stop_time += 1.0 / 60.0
	var stopping_distance := car.progress - start
	assert(stop_time > 2.8 and stop_time < 4.5, "braking should take a plausible interval")
	assert(stopping_distance > 35.0 and stopping_distance < 60.0, "braking distance should be plausible")
	# Parallel contact must not invent sideways speed; an actual closing
	# collision should impart separation rather than a fixed kick.
	var a := race.player
	var b := race.cars[0]
	race.cars.clear()
	race.cars.append(a)
	race.cars.append(b)
	a.progress = 200.0
	b.progress = 200.0
	a.s = track.mod_s(200.0)
	b.s = a.s
	a.d = 0.0
	b.d = 1.9
	a.v = 20.0
	b.v = 20.0
	a.yaw = 0.0
	b.yaw = 0.0
	a.lat_v = 0.0
	b.lat_v = 0.0
	race.collisions()
	assert(absf(a.lat_v) < 0.001 and absf(b.lat_v) < 0.001, "parallel cars must not get an artificial sideways kick")
	b.d = 1.9
	a.d = 0.0
	a.lat_v = 3.0
	race.collisions()
	assert(a.lat_v < 3.0 and b.lat_v > 0.0, "closing cars must share impact velocity")
	# A large heading/impact velocity must not turn into a high-speed
	# sideways teleport during the next 60 Hz simulation step.
	a.d = 0.0
	a.v = 30.0
	a.yaw = 1.0
	a.lat_v = 8.0
	a.ctrl.steer = 0.0
	a.ctrl.brake = false
	race.physics(a, 1.0 / 60.0)
	assert(absf(a.d) <= 8.0 / 60.0 + 0.001, "lateral motion must remain bounded")
	# Deep overlaps are separated gradually, without a one-frame jump.
	a.d = 0.0
	b.d = 0.2
	a.s = 200.0
	b.s = 200.0
	a.lat_v = 0.0
	b.lat_v = 0.0
	race.collisions()
	assert(absf(a.d) <= 0.081 and absf(b.d - 0.2) <= 0.081, "collision separation must be gradual")
	a.d = 0.0
	b.d = 0.0
	a.progress = 200.0
	b.progress = 200.1
	a.s = 200.0
	b.s = 200.1
	race.collisions()
	assert(absf(a.progress - 200.0) <= 0.081 and absf(b.progress - 200.1) <= 0.081, "longitudinal overlap must not teleport cars")
	# Deep stationary overlaps must unwind smoothly, not jump sideways at
	# several metres per second, and must not remain permanently interlocked.
	a.v = 0.0
	b.v = 0.0
	a.yaw = 0.0
	b.yaw = 0.0
	a.lat_v = 0.0
	b.lat_v = 0.0
	a.progress = 200.0
	b.progress = 200.0
	a.s = track.mod_s(200.0)
	b.s = a.s
	a.d = 0.0
	b.d = 0.2
	race.collisions(1.0 / 60.0)
	assert(absf(a.d) <= 0.017 and absf(b.d - 0.2) <= 0.017, "stationary overlap must unwind gently")
	for i in 90:
		race.collisions(1.0 / 60.0)
	assert(absf(b.d - a.d) >= 2.049, "stationary overlap must resolve without sticking")
	a.d = 0.0
	b.d = 0.2
	for i in 30:
		race.collisions(1.0 / 60.0)
	var gap_60 := b.d - a.d
	a.d = 0.0
	b.d = 0.2
	for i in 15:
		race.collisions(1.0 / 30.0)
	assert(absf(b.d - a.d - gap_60) < 0.001, "separation must depend on elapsed time, not tick count")
	print("DRIVING: 0-100 km/h %.2fs; 100-0 %.2fs, %.1fm" % [acceleration_time, stop_time, stopping_distance])
	get_tree().quit()
