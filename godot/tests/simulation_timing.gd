extends Node

func _ready() -> void:
	var dt := RaceScene.DT
	var debt := 0.0
	var steps := 0
	var dropped := 0.0
	# Ordinary render frames must advance at the simulation's usual 60 Hz.
	for i in 60:
		var plan := RaceScene._timing_plan(debt, dt)
		debt = float(plan.debt)
		steps += int(plan.steps)
		dropped += float(plan.dropped)
	assert(steps == 60 and absf(debt) < 0.00001 and dropped == 0.0, "normal frames must retain one fixed tick per frame")

	# A 5 FPS frame represents twelve fixed steps, not five: verify elapsed
	# time with the real race simulation as well as the timing arithmetic.
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 17})
	race.started = true
	# Pausing after an input was latched but before a tick must not fire an
	# unexpected powerup when the race resumes.
	var scene := RaceScene.new()
	scene.player = race.player
	race.player.ctrl.fire = true
	race.player.ctrl.back = true
	race.player.ctrl.cycle = true
	race.player.ctrl.select = 2
	scene._clear_pending_actions()
	assert(not race.player.ctrl.fire and not race.player.ctrl.back and not race.player.ctrl.cycle and race.player.ctrl.select == 0, "pause must clear pending one-shot controls")
	scene.free()
	debt = 0.0
	for i in 10:
		var plan := RaceScene._timing_plan(debt, 0.2)
		debt = float(plan.debt)
		assert(int(plan.steps) == 12 and float(plan.dropped) == 0.0, "200 ms must produce twelve fixed steps without dropping time")
		for tick in int(plan.steps):
			race.step(dt)
	assert(absf(race.time - 2.0) < 0.0001 and absf(debt) < 0.00001, "race clock must advance two seconds across ten 200 ms frames")

	# Longer stalls may need several render frames to catch up. Their remaining
	# debt must be preserved, with a bound that prevents runaway accumulation.
	var overloaded := RaceScene._timing_plan(0.02, 2.0)
	assert(int(overloaded.steps) == 12, "catch-up steps must stay bounded")
	assert(absf(float(overloaded.dropped) - 1.02) < 0.00001, "only elapsed time beyond the debt limit may be discarded")
	assert(absf(float(overloaded.debt) - 0.8) < 0.00001, "unprocessed bounded debt must remain for future frames")
	debt = float(overloaded.debt)
	for i in 10:
		var plan := RaceScene._timing_plan(debt, 0.1)
		debt = float(plan.debt)
	assert(debt < dt, "capacity remaining after each frame must drain preserved debt")
	print("SIMULATION TIMING: 60 Hz, 200 ms frames, bounded overload and recovery passed")
	get_tree().quit()
