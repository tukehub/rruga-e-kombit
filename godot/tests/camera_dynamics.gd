extends Node
## Chase camera dynamics (README 2.1): roll from steer and drift, a tighter
## sideways follow while drifting, a kick along the direction the simulation
## reports for a blow, the nitro pull-back and the bumper view.

const STEP := 1.0 / 60.0

var failures := 0
var track: RaceTrack
var race: Race

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func camera() -> ChaseCam:
	var cam := ChaseCam.new()
	add_child(cam)
	cam.setup(track)
	return cam

func car() -> CarState:
	var c := race.player
	c.s = 300.0
	c.progress = 300.0
	c.d = 0.0
	c.v = 40.0
	c.yaw = 0.0
	c.hop = 0.0
	c.steer = 0.0
	c.drift = 0.0
	c.nitro_t = 0.0
	return c

func run(cam: ChaseCam, c: CarState, frames: int) -> void:
	for i in frames:
		cam.follow(c, STEP)

## Camera position in the car's road frame: x to the driver's right, y forward.
func offset(cam: ChaseCam, c: CarState) -> Vector2:
	var psi := track.heading(c.s)
	var forward := Vector3(-sin(psi), 0.0, cos(psi))
	var right := Vector3(-forward.z, 0.0, forward.x)
	var rel := cam.global_position - track.pos(c.s, c.d)
	return Vector2(rel.dot(right), rel.dot(forward))

func hit_events() -> Array:
	return race.take_events().filter(func(e: Dictionary) -> bool: return e.t == "hit")

func _ready() -> void:
	track = RaceTrack.load_city("tirane")
	race = Race.new(track, {"seed": 7})
	race.started = true
	var c := car()

	# The road frame used here matches the simulation's: +d is the driver's right.
	var probe := camera()
	c.d = 3.0
	probe.follow(c, 0.0)
	check(offset(probe, c).y < -6.0, "chase camera sits behind the car")
	var right_of_centre := (track.pos(c.s, 3.0) - track.pos(c.s, 0.0))
	var psi := track.heading(c.s)
	check(right_of_centre.dot(Vector3(-cos(psi), 0.0, -sin(psi))) > 2.5, "+d is the driver's right in world space")
	probe.free()
	c = car()

	# Roll: into the bend, more with drift, level again on the straight.
	var cam := camera()
	run(cam, c, 30)
	check(absf(cam.roll) < 0.0001 and absf(cam.global_transform.basis.x.y) < 0.0001, "straight driving keeps the horizon level")
	c.steer = 1.0
	run(cam, c, 90)
	var steer_roll := cam.roll
	check(steer_roll > 0.03 and steer_roll < 0.06, "steering right leans the camera right")
	check(cam.global_transform.basis.x.y < -0.02, "the lean reaches the camera transform: right side drops")
	c.drift = 1.0
	run(cam, c, 90)
	check(cam.roll > steer_roll + 0.03 and cam.roll < 0.12, "a drift adds lean, within a small bound")
	c.steer = -1.0
	run(cam, c, 120)
	check(cam.roll < -0.08 and cam.global_transform.basis.x.y > 0.02, "the lean follows the steering side")
	c.steer = 0.0
	c.drift = 0.0
	run(cam, c, 180)
	check(absf(cam.roll) < 0.001, "the camera levels out again")
	c.steer = 1.0
	c.v = 0.0
	run(cam, c, 90)
	check(absf(cam.roll) < 0.001, "a parked car does not lean the camera")
	cam.free()
	c = car()

	# Lateral lag: the camera catches a sideways move sooner during a drift.
	var loose := camera()
	var tight := camera()
	loose.follow(c, 0.0)
	tight.follow(c, 0.0)
	c.d = 4.0
	run(loose, c, 6)
	c.drift = 1.0
	run(tight, c, 6)
	check(loose._cam_d > 0.5 and tight._cam_d > loose._cam_d + 0.6, "sideways follow tightens while drifting")
	check(tight._cam_d <= 4.0 * 0.82 + 0.0001, "tight follow does not overshoot the car")
	loose.free()
	tight.free()
	c = car()

	# Hit kick: along the reported direction, repeatable, and it dies away.
	var still := camera()
	var a := camera()
	var b := camera()
	var left := camera()
	for one in [still, a, b, left]:
		one.follow(c, 0.0)
	a.add_kick(Vector2(1.0, 0.0), 1.0)
	b.add_kick(Vector2(1.0, 0.0), 1.0)
	left.add_kick(Vector2(-1.0, 0.0), 1.0)
	var peak := 0.0
	for i in 12:
		for one in [still, a, b, left]:
			one.follow(c, STEP)
		check(a.global_position == b.global_position, "equal blows move the camera identically (no random shake)")
		peak = maxf(peak, offset(a, c).x - offset(still, c).x)
	check(peak > 0.2 and peak < 1.0, "a blow from the left throws the camera to the right")
	check(absf(offset(a, c).y - offset(still, c).y) < 0.01, "a sideways blow does not move the camera along the road")
	check(absf((offset(a, c).x - offset(still, c).x) + (offset(left, c).x - offset(still, c).x)) < 0.001, "the opposite blow mirrors the kick")
	run(a, c, 240)
	run(still, c, 240)
	check(a.kick.length() < 0.002 and a.global_position.distance_to(still.global_position) < 0.005, "the kick settles back on the chase position")
	a.add_kick(Vector2(0.0, 1.0), 1.0)
	peak = 0.0
	for i in 12:
		a.follow(c, STEP)
		still.follow(c, STEP)
		peak = maxf(peak, offset(a, c).y - offset(still, c).y)
	check(peak > 0.2 and absf(a.kick.x) < 0.0001, "a blow from behind throws the camera forward only")
	for i in 20:
		a.add_kick(Vector2(1.0, 0.0), 1.6)
	peak = 0.0
	for i in 60:
		a.follow(c, STEP)
		peak = maxf(peak, a.kick.length())
	check(peak < 1.2, "stacked blows cannot throw the camera off the car")
	a.add_kick(Vector2.ZERO, 1.0)
	check(is_finite(a._kick_v.x) and a._kick_v.y > 0.0, "a blow without a direction still kicks")
	for one in [still, a, b, left]:
		one.free()
	c = car()

	# Nitro pulls the camera back and lets it return.
	cam = camera()
	cam.follow(c, 0.0)
	var base := -offset(cam, c).y
	check(absf(base - ChaseCam.CHASE_BACK) < 0.2, "chase distance at rest")
	c.nitro_t = 2.0
	cam.follow(c, STEP)
	check(-offset(cam, c).y < base + 0.3, "the pull-back eases in")
	run(cam, c, 120)
	check(-offset(cam, c).y > base + ChaseCam.NITRO_PULL * 0.9, "nitro pulls the camera back")
	c.nitro_t = 0.0
	run(cam, c, 180)
	check(absf(-offset(cam, c).y - base) < 0.05, "the camera closes up after nitro")

	# Bumper view: low on the nose, looking down the road; cabin sits higher.
	cam.view = ChaseCam.View.BUMPER
	cam.follow(c, STEP)
	var nose := offset(cam, c)
	var bumper_height := cam.global_position.y - track.pos(c.s, c.d).y
	check(cam.first_person() and nose.y > 1.5 and nose.y < 3.0 and absf(nose.x) < 0.01, "bumper view rides on the nose")
	check(bumper_height > 0.4 and bumper_height < 0.9, "bumper view is near the road")
	var ahead := track.tangent(c.s)
	check((-cam.global_transform.basis.z).dot(ahead) > 0.98, "bumper view looks along the road")
	cam.view = ChaseCam.View.CABIN
	cam.follow(c, STEP)
	check(cam.first_person() and cam.global_position.y - track.pos(c.s, c.d).y > bumper_height + 0.4 and absf(offset(cam, c).y) < 0.1, "cabin view stays at the driver's seat")
	cam.view = ChaseCam.View.CHASE
	cam.follow(c, STEP)
	check(not cam.first_person() and absf(-offset(cam, c).y - base) < 0.05, "returning to chase restores the chase position")
	cam.free()

	# The simulation reports where each blow came from.
	var victim := race.player
	var rival: CarState = race.cars.filter(func(o: CarState) -> bool: return o != victim)[0]
	for o in race.cars:
		o.s = fposmod(1000.0 + 40.0 * o.id, track.L)
		o.d = 0.0
	victim.s = 300.0
	victim.d = 0.0
	race.take_events()
	race.projs.clear()
	race.projs.append({"id": 9001, "kind": "bolt", "owner": rival, "s": 299.0, "d": -1.5, "dir": 1.0, "speed": 0.0, "life": 2.0, "target": null})
	race.update_projs(STEP)
	var hits := hit_events()
	check(hits.size() == 1 and hits[0].car == victim, "the shot strikes the car it reaches")
	if hits.size() == 1:
		var dir: Vector2 = hits[0].dir
		check(absf(dir.length() - 1.0) < 0.001 and dir.x > 0.1 and dir.y > 0.5, "a shot from behind-left reports a blow forward and to the right")
	victim.recovery_t = 0.0
	victim.health = victim.max_hp
	race.projs.clear()
	race.projs.append({"id": 9002, "kind": "bolt", "owner": rival, "s": 301.0, "d": 1.5, "dir": -1.0, "speed": 0.0, "life": 2.0, "target": null})
	race.update_projs(STEP)
	hits = hit_events()
	check(hits.size() == 1 and hits[0].dir.x < -0.1 and hits[0].dir.y < -0.5, "a shot fired backward reports a blow rearward and to the left")
	victim.recovery_t = 0.0
	victim.health = 1.0
	race.hit(victim, rival, "bolt", 5.0, {}, Vector2(1.0, 0.0))
	var wrecks := race.take_events().filter(func(e: Dictionary) -> bool: return e.t == "wreck")
	check(wrecks.size() == 1 and wrecks[0].dir == Vector2(1.0, 0.0), "a wreck carries the direction of the final blow")

	if failures == 0:
		print("CAMERA DYNAMICS: roll, drift follow, directed kick, nitro pull-back and bumper view passed")
	get_tree().quit(1 if failures else 0)
