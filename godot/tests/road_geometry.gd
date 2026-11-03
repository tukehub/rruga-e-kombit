extends Node


func _ready() -> void:
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 1})
	race.started = true
	var car := race.player
	var edge := track.half_w - 1.2
	var worst_travel := INF
	var max_travel := 0.0
	# Sample every half metre, including across the finish seam. Both sides of
	# the driveable road must advance along the centreline rather than fold back.
	for i in track.M * 4:
		var s := track.ds * i / 4.0
		var tangent3 := track.tangent(s)
		var tangent := Vector2(tangent3.x, tangent3.z).normalized()
		for d in [-edge, edge]:
			var before := track.pos(s, d)
			var after := track.pos(s + track.ds * 0.25, d)
			var forward := Vector2(after.x - before.x, after.z - before.z).dot(tangent)
			assert(forward > 0.001, "the driveable road edge must not fold backward")
			car.progress = s
			car.s = s
			car.d = d
			car.v = 15.0
			car.yaw = 0.0
			car.lat_v = 0.0
			car.steer = 0.0
			race.physics(car, 1.0 / 60.0)
			var end := track.pos(car.s, car.d)
			var travel := Vector2(end.x - before.x, end.z - before.z).length()
			worst_travel = minf(worst_travel, travel)
			max_travel = maxf(max_travel, travel)
	assert(worst_travel > 0.15, "a 15 m/s car must not slow dramatically along either road edge")
	assert(max_travel < 0.26, "turning must not make the car travel faster than its speed")
	print("ROAD GEOMETRY: no folds, travel %.3f–%.3f m per tick" % [worst_travel, max_travel])
	get_tree().quit()
