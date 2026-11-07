extends Node

func _ready() -> void:
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
