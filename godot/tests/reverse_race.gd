extends Node

func _ready() -> void:
	var forward := RaceTrack.load_city("tirane")
	var reverse := RaceTrack.load_city("tirane", true)
	assert(forward != null and reverse != null)
	assert(forward.pos(0.0, 0.0).distance_to(reverse.pos(0.0, 0.0)) < 0.01, "reverse must keep the start/finish")
	assert(forward.tangent(0.0).dot(reverse.tangent(0.0)) < -0.99, "reverse must turn the starting grid around")
	assert(absf(forward.L - reverse.L) < 0.5, "reverse must keep the same circuit length")
	for fraction in [0.1, 0.25, 0.5, 0.75, 0.9]:
		var a := forward.pos(forward.L * fraction, 3.0)
		var b := reverse.pos(reverse.L * (1.0 - fraction), -3.0)
		assert(a.distance_to(b) < 1.0, "reverse must follow the same road")
	var race := Race.new(reverse, {"laps": 1, "seed": 42})
	race.started = true
	assert(race.pickups.size() > 0, "reverse needs pickup stations")
	for pickup in race.pickups:
		assert(absf(float(pickup.d)) < reverse.half_w, "reverse pickup must be on road")
	var player := race.player
	player.lap = 0
	player.progress = reverse.L - 0.1
	player.s = reverse.mod_s(player.progress)
	player.v = 20.0
	player.d = 0.0
	player.yaw = 0.0
	player.ctrl.gas = true
	race.step(1.0 / 60.0)
	assert(player.finished and player.lap == 1, "forward progress over start must finish a reverse lap")
	# Drive a complete lap in reverse, not only across the finish-line boundary.
	var solo := Race.new(reverse, {"laps": 1, "seed": 42, "no_player": true})
	solo.cars.resize(1)
	solo.started = true
	for tick in 18000:
		solo.step(1.0 / 60.0)
		solo.take_events()
		if solo.cars[0].finished:
			break
	assert(solo.cars[0].finished, "AI must complete a full reverse lap")
	print("REVERSE RACE: same circuit, opposite direction, pickups and finish passed")
	get_tree().quit()
