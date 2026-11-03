extends Node

func _ready() -> void:
	var track := RaceTrack.load_city("tirane")
	track.K.fill(0.0)
	for side in [-1.0, 1.0]:
		var race := Race.new(track, {"seed": 42})
		race.started = true
		var c := race.player
		c.s = 100.0
		c.progress = 100.0
		c.d = side * (race.hw - 1.12)
		c.v = 30.0
		c.yaw = side * 0.5
		var before := c.yaw
		race.physics(c, 1.0 / 60.0)
		assert(absf(c.d) <= race.hw - 1.1 + 0.001, "contact must keep the car within the road")
		assert(c.yaw * side > 0.0 and absf(c.yaw - before) < 0.1, "impact must not flip direction instantly")
		assert(c.v > 29.0, "single contact must not remove excessive speed")
		for i in 60:
			c.ctrl.steer = side
			race.physics(c, 1.0 / 60.0)
			assert(absf(c.d) <= race.hw - 1.1 + 0.001, "sustained contact must remain contained")
		assert(is_finite(c.v) and is_finite(c.yaw), "contact must remain finite")
	print("WALL CONTACT: bounded steering and containment passed")
	get_tree().quit()
