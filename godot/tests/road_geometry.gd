extends Node


func _ready() -> void:
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 1})
	# The grid sits immediately behind the relocated finish by Skanderbeg.
	# Check all six starting positions and the first actual racing step.
	var props: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cities/tirane/props.json"))
	var monument := Vector2.ZERO
	var monument_anchor := {}
	for item in props.landmarks:
		if item.id == "skanderbeg":
			monument = Vector2(item.x, item.z)
			monument_anchor = item
	var start := track.pos(0.0, 0.0)
	assert(Vector2(start.x, start.z).distance_to(monument) < 65.0, "finish must be near the monument")
	var landmark := Landmarks.new()
	add_child(landmark)
	landmark.load_anchors([monument_anchor])
	var sword := landmark.get_node_or_null("skanderbeg/SkanderbegSword") as Node3D
	assert(sword != null, "the square's monument must have a sword")
	var sword_axis := sword.global_basis.y
	var finish_direction := track.tangent(0.0)
	var sword_flat := Vector2(sword_axis.x, sword_axis.z).normalized()
	var finish_flat := Vector2(finish_direction.x, finish_direction.z).normalized()
	assert(absf(sword_flat.dot(finish_flat)) > 0.995, "sword must be perpendicular to the finish line")
	landmark.queue_free()
	for i in race.cars.size():
		var c := race.cars[i]
		var p := track.pos(c.s, c.d)
		assert(absf(c.d) < track.half_w - 1.0, "starting cars must be on the road")
		assert(Vector2(p.x, p.z).distance_to(monument) > 10.0, "grid must clear the monument")
		for category in [props.trees, props.lamps]:
			for item in category:
				assert(Vector2(p.x, p.z).distance_to(Vector2(item[0], item[2])) > 2.5,
					"starting cars must clear roadside props")
		for j in range(i):
			var other := race.cars[j]
			assert(p.distance_to(track.pos(other.s, other.d)) > 4.5, "starting cars must not overlap")
	race.started = true
	race.step(1.0 / 60.0)
	for c in race.cars:
		assert(not c.finished and c.lap < 1, "crossing the starting line must not finish a lap")
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
