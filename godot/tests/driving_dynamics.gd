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
	assert(absf(a.d) <= 0.75 * 30.0 / 60.0 + 0.01, "lateral motion must remain bounded relative to speed")
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
	assert(absf(b.d - a.d) >= 1.959, "stationary overlap must resolve without sticking")
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
	# Use an exactly straight local track so measured separations match metres.
	var straight := RaceTrack.new()
	straight.M = 101
	straight.L = 202.0
	straight.ds = 2.0
	for i in straight.M:
		straight.X.append(0.0)
		straight.Y.append(0.0)
		straight.Z.append(i * 2.0)
		straight.TX.append(0.0)
		straight.TY.append(0.0)
		straight.TZ.append(1.0)
		straight.NX.append(1.0)
		straight.NZ.append(0.0)
		straight.K.append(0.0)
	race.track = straight
	a.progress = 40.0
	a.s = 40.0
	a.d = 0.0
	a.yaw = 0.0
	a.lat_v = 0.0
	a.v = 24.0
	b.progress = 44.42
	b.s = b.progress
	b.d = 0.0
	b.yaw = 0.0
	b.lat_v = 0.0
	b.v = 20.0
	race.collisions()
	assert(is_equal_approx(a.v, 24.0), "cars must not brake at the old invisible bumper")
	b.progress = 44.30
	b.s = b.progress
	race.collisions()
	assert(a.v < 24.0, "a real bumper overlap must respond")
	# The old rectangular bounds treated empty space near a bumper corner as contact.
	a.v = 24.0
	b.v = 20.0
	a.progress = 40.0
	a.s = a.progress
	a.d = 0.0
	b.progress = 44.30
	b.s = b.progress
	b.d = 1.85
	race.collisions()
	assert(is_equal_approx(a.v, 24.0), "empty space beside tapered bumper must not slow the car")
	# A yawed nose points away from this car, leaving a real visible gap.
	a.yaw = 0.35
	b.d = -1.8
	b.progress = 44.20
	b.s = b.progress
	race.collisions()
	assert(is_equal_approx(a.v, 24.0) and is_zero_approx(a.d), "yawed cars with a visible gap must not collide")
	b.d = 0.5
	race.collisions()
	assert(a.v < 24.0 or absf(a.d) > 0.0001, "turned body must collide at its actual footprint")
	# Sustained side contact must settle, then allow a steering movement away.
	a.progress = 40.0
	a.s = a.progress
	b.progress = 40.0
	b.s = b.progress
	a.d = 0.0
	b.d = 1.90
	a.yaw = 0.12
	b.yaw = 0.0
	a.lat_v = 0.0
	b.lat_v = 0.0
	a.v = 20.0
	b.v = 20.0
	a.ctrl.gas = false
	a.ctrl.brake = false
	b.ctrl.gas = false
	b.ctrl.brake = false
	for i in 30:
		race.physics(a, 1.0 / 60.0)
		race.physics(b, 1.0 / 60.0)
		race.collisions(1.0 / 60.0)
	assert(a.yaw < 0.12 and absf(a.lat_v) < 4.0, "side contact must settle without an accumulating slide")
	var gap_before_release := b.d - a.d
	a.yaw = -0.12
	a.lat_v = 0.0
	for i in 30:
		race.physics(a, 1.0 / 60.0)
		race.physics(b, 1.0 / 60.0)
		race.collisions(1.0 / 60.0)
	assert(b.d - a.d > gap_before_release + 0.2, "steering away must release side contact")

	# On a bend equal centreline gaps correspond to different actual gaps
	# on the inside and outside lanes. Use an analytic 30 m radius curve.
	for i in straight.M:
		var angle := i * straight.ds / 30.0
		straight.X[i] = 30.0 * cos(angle)
		straight.Z[i] = 30.0 * sin(angle)
		straight.TX[i] = -sin(angle)
		straight.TZ[i] = cos(angle)
		straight.NX[i] = -cos(angle)
		straight.NZ[i] = -sin(angle)
		straight.K[i] = 1.0 / 30.0
	a.progress = 40.0
	a.s = a.progress
	a.d = -8.0
	a.yaw = 0.0
	a.v = 24.0
	b.progress = 44.0
	b.s = b.progress
	b.d = -8.0
	b.yaw = 0.0
	b.v = 20.0
	race.collisions()
	assert(is_equal_approx(a.v, 24.0), "outside-lane cars with a real gap must not collide")
	a.d = 8.0
	b.d = 8.0
	b.progress = 44.8
	b.s = b.progress
	race.collisions()
	assert(a.v < 24.0, "inside-lane cars must collide when their world-space bodies touch")

	_test_real_turns()
	print("DRIVING: 0-100 km/h %.2fs; 100-0 %.2fs, %.1fm" % [acceleration_time, stop_time, stopping_distance])
	get_tree().quit()


func _test_real_turns() -> void:
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 1})
	race.started = true
	var car := race.player
	var dt := 1.0 / 60.0
	# Includes sharp corners and the finish-line seam on both sides of the road.
	for s in [0.0, 1000.0, 3515.9, track.L - 2.0]:
		for d in [-8.0, -4.0, 0.0, 4.0, 8.0]:
			for speed in [1.0, 30.0]:
				for yaw in [0.0, 0.3]:
					car.progress = s
					car.s = s
					car.d = d
					car.v = speed
					car.yaw = yaw
					car.lat_v = 0.0
					car.steer = 0.0
					car.ctrl.gas = false
					car.ctrl.brake = false
					car.ctrl.steer = 0.0
					var before := track.pos(s, d)
					race.physics(car, dt)
					var after := track.pos(car.s, car.d)
					var movement := Vector2(after.x - before.x, after.z - before.z)
					assert(car.v <= speed, "coasting through a turn must not accelerate")
					assert(movement.length() / dt <= speed + 0.3, "world travel must not exceed the car's speed on bends")
					var t := track.tangent(s)
					var n := track.normal(s)
					var direction := (Vector2(t.x, t.z) * cos(car.yaw) + Vector2(n.x, n.z) * sin(car.yaw)).normalized()
					# A folded road edge may stop forward progress until the driver
					# steers away; check heading where normal travel is possible.
					if movement.length() > maxf(0.02, speed * dt * 0.4):
						assert(movement.normalized().dot(direction) > 0.90, "body and travel direction should agree in a normal turn")
	# Sample the entire real circuit, not only the specific bends above. Without
	# a collision, tire grip should keep the actual travel close to body heading.
	for s in range(0, int(track.L), 40):
		for d in [-8.0, 0.0, 8.0]:
			for yaw in [-0.3, 0.0, 0.3]:
				car.progress = float(s)
				car.s = float(s)
				car.d = d
				car.v = 30.0
				car.yaw = yaw
				car.lat_v = 0.0
				car.steer = 0.0
				car.ctrl.gas = false
				car.ctrl.brake = false
				car.ctrl.steer = 0.0
				var before := track.pos(car.s, car.d)
				race.physics(car, dt)
				var after := track.pos(car.s, car.d)
				var travel := Vector2(after.x - before.x, after.z - before.z)
				var tangent := track.tangent(car.s)
				var normal := track.normal(car.s)
				var heading := (Vector2(tangent.x, tangent.z) * cos(car.yaw) + Vector2(normal.x, normal.z) * sin(car.yaw)).normalized()
				assert(travel.length() > 0.05 and travel.normalized().dot(heading) > cos(deg_to_rad(12.0)), "normal tire travel must track the body heading across Tirana")
	# The new direction limit must not repeatedly drain speed on a sustained turn.
	car.progress = 3500.0
	car.s = car.progress
	car.d = 0.0
	car.v = 30.0
	car.yaw = 0.0
	car.steer = 0.0
	car.ctrl.gas = true
	car.ctrl.steer = 0.3
	for i in 120:
		race.physics(car, dt)
	assert(car.v > 25.0, "sustained steering must not repeatedly destroy forward speed")
	print("TURNING: world speed and heading, coasting, sustained turn passed")
