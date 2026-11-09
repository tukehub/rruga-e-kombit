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

	# 30 and 20 FPS still run in real time: two and three ticks per frame.
	for frame: Array in [[1.0 / 30.0, 2], [1.0 / 20.0, 3]]:
		debt = 0.0
		for i in 20:
			var plan := RaceScene._timing_plan(debt, float(frame[0]))
			debt = float(plan.debt)
			assert(int(plan.steps) == int(frame[1]) and float(plan.dropped) < 0.00001, "slow steady frames must keep real time")

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

	# A 5 FPS frame runs three ticks and sheds the rest: the race slows down
	# instead of the car jumping twelve ticks in one rendered frame.
	debt = 0.0
	for i in 10:
		var plan := RaceScene._timing_plan(debt, 0.2)
		debt = float(plan.debt)
		assert(int(plan.steps) == 3 and absf(float(plan.dropped) - 0.15) < 0.00001, "200 ms must produce three fixed steps and shed the remainder")
		for tick in int(plan.steps):
			race.step(dt)
	assert(absf(race.time - 0.5) < 0.0001 and debt < dt, "race clock must advance half a second across ten 200 ms frames")

	# A long stall is bounded the same way and leaves no backlog to fast-forward.
	var overloaded := RaceScene._timing_plan(0.02, 2.0)
	assert(int(overloaded.steps) == 3, "catch-up steps must stay bounded")
	assert(absf(float(overloaded.dropped) - 118.0 * dt) < 0.00001, "whole ticks beyond the catch-up limit must be discarded")
	assert(float(overloaded.debt) < dt, "only the sub-tick remainder may survive a stall")
	var after := RaceScene._timing_plan(float(overloaded.debt), dt)
	assert(int(after.steps) == 1, "the frame after a stall must run at normal speed")
	print("SIMULATION TIMING: 60 Hz, real time down to 20 FPS, bounded stalls passed")
	get_tree().quit()
