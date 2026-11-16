class_name ChaseCam
extends Camera3D
## Third-person chase camera, port of chaseCam() in src/10_main.js plus the
## 2.8 s intro sweep. Speed-dependent FOV, nitro FOV kick and pull-back, roll
## into bends and drifts, and a kick in the direction a blow came from.
## Cabin and bumper are the two first-person views.

enum View { CHASE, CABIN, BUMPER }

# real-scale cars (~4.5 m) need more distance than the original 3.5 m
const CHASE_BACK := 7.0
const CHASE_HEIGHT := 2.3
const NITRO_PULL := 1.6          # extra metres behind the car while nitro burns
const ROLL_STEER := 0.045        # radians at full lock and full speed
const ROLL_DRIFT := 0.05         # added at full drift
const LAG_RATE := 8.0            # sideways follow rate, 1/s
const LAG_RATE_DRIFT := 20.0     # the same at full drift: the tail stays in frame
const BUMPER_AHEAD := 2.1        # metres from the car's centre to its nose
const BUMPER_HEIGHT := 0.62
const KICK_SPRING := 150.0       # the kick swings back like a damped spring
const KICK_DAMPING := 9.0
const KICK_SPEED := 9.0          # m/s of camera travel per unit of kick
const KICK_LIMIT := 1.5

var track: RaceTrack
var look := Vector3.ZERO
var fov_target := 64.0
var intro_t := 0.0
var intro := false
var view := View.CHASE
var roll := 0.0                  # radians, positive leans into a right-hand bend
var kick := Vector2.ZERO         # metres: x to the driver's right, y forward
var _finish_car_position := Vector3.ZERO
var _finish_tracking := false
var _finish_t := 0.0
var _finish_angle := 0.0
var _finish_radius := 8.0
var _finish_height := 2.0
var _snap := true
var _cam_d := 0.0
var _cam_hop := 0.0
var _cam_psi := 0.0
var _cam_slope := 0.0
var _cam_back := CHASE_BACK
var _kick_v := Vector2.ZERO


func setup(p_track: RaceTrack) -> void:
	track = p_track
	near = 0.3
	far = 6000.0
	fov = 64.0
	_snap = true


func start_intro() -> void:
	intro = true
	intro_t = 0.0


## Knock the camera the way the blow travelled: `dir` is (to the driver's
## right, forward) as the simulation reports it. Unknown directions throw the
## camera forward, as a sudden stop does.
func add_kick(dir: Vector2, amount: float) -> void:
	var along := dir.normalized() if dir.length_squared() > 0.0001 else Vector2(0.0, 1.0)
	_kick_v = (_kick_v + along * amount * KICK_SPEED).limit_length(KICK_LIMIT * KICK_SPEED)


func first_person() -> bool:
	return view != View.CHASE


func _advance_dynamics(c: CarState, dt: float) -> void:
	# Semi-implicit spring: stable at any frame time the game renders at.
	_kick_v += (-kick * KICK_SPRING - _kick_v * KICK_DAMPING) * dt
	kick += _kick_v * dt
	var speed := clampf(absf(c.v) / 30.0, 0.0, 1.0)
	var lean := (c.steer * ROLL_STEER + c.drift * signf(c.steer) * ROLL_DRIFT) * speed
	roll = lerpf(roll, lean, 1.0 - exp(-dt * 6.0))


func _apply_roll(scale: float) -> void:
	# Looking down -Z, a negative turn about +Z drops the right-hand side.
	var angle := (roll + kick.x * 0.05) * scale
	if absf(angle) > 0.00001:
		rotate_object_local(Vector3(0.0, 0.0, 1.0), -angle)


func follow(c: CarState, dt: float, pose: Dictionary = {}) -> void:
	if intro:
		_intro_cam(c, dt)
		return
	var s := float(pose.get("s", c.s))
	var d := float(pose.get("d", c.d))
	var hop := float(pose.get("hop", c.hop))
	var yaw := float(pose.get("yaw", c.yaw))
	_advance_dynamics(c, dt)
	if view != View.CHASE:
		_follow_first_person(c, s, d, yaw, hop, dt)
		return
	var sp := absf(c.v)
	# The camera sits a fixed distance behind the car along the road. Only the
	# sideways offset, hop, heading and slope are smoothed, so the car keeps a
	# constant size on screen instead of shrinking and pulsing with speed.
	var car := track.pos(s, d)
	car.y += hop
	var psi := track.heading(s) + yaw * 0.5
	var tg := track.tangent(s)
	var snap := _snap
	_snap = false
	var k := 1.0 if snap else 1.0 - exp(-dt * 8.0)
	var kl := 1.0 if snap else 1.0 - exp(-dt * 12.0)
	# A drift swings the car across the road; a tighter follow keeps it framed.
	var kd := 1.0 if snap else 1.0 - exp(-dt * lerpf(LAG_RATE, LAG_RATE_DRIFT, clampf(c.drift, 0.0, 1.0)))
	var back := CHASE_BACK + (NITRO_PULL if c.nitro_t > 0.0 else 0.0)
	_cam_back = back if snap else lerpf(_cam_back, back, 1.0 - exp(-dt * 3.5))
	_cam_d = lerpf(_cam_d, d * 0.82, kd)
	_cam_hop = lerpf(_cam_hop, hop, k)
	_cam_psi = lerp_angle(_cam_psi, psi, kl)
	_cam_slope = lerpf(_cam_slope, tg.y, kl)
	var p := track.pos(s - _cam_back + kick.y, _cam_d + kick.x)
	p.y += CHASE_HEIGHT + _cam_hop * 0.5
	look = Vector3(car.x - sin(_cam_psi) * 12.0, car.y + 1.0 + _cam_slope * 12.0, car.z + cos(_cam_psi) * 12.0)
	global_position = p
	if not p.is_equal_approx(look):
		look_at(look, Vector3.UP)
	_apply_roll(1.0)
	var want := 64.0 + clampf(sp / 60.0, 0.0, 1.3) * 12.0 + (10.0 if c.nitro_t > 0.0 else 0.0)
	fov_target += (want - fov_target) * (1.0 - exp(-dt * 4.0))
	fov = fov_target


func _follow_first_person(c: CarState, s: float, d: float, yaw: float, hop: float, dt: float) -> void:
	var bumper := view == View.BUMPER
	var psi := track.heading(s) + yaw
	var tg := track.tangent(s)
	var forward := Vector3(-sin(psi), tg.y, cos(psi)).normalized()
	# The driver is strapped in: a blow moves the head a little, not the seat.
	var p := track.pos(s, d + kick.x * 0.15)
	if bumper:
		p += forward * BUMPER_AHEAD
		p.y += BUMPER_HEIGHT + hop
	else:
		p.y += 1.23 + hop
	global_position = p
	look = p + forward * 30.0
	look_at(look, Vector3.UP)
	_apply_roll(0.6)
	# Low on the nose the road already rushes past; the bumper needs less FOV.
	var want := (68.0 if bumper else 74.0) + clampf(absf(c.v) / 60.0, 0.0, 1.0) * 5.0 + (4.0 if c.nitro_t > 0.0 else 0.0)
	fov_target += (want - fov_target) * (1.0 - exp(-dt * 6.0))
	fov = fov_target
	_snap = true


func follow_finish(c: CarState, dt: float, pose: Dictionary = {}) -> void:
	# Fly continuously from the existing view over the side to the front.
	var s := float(pose.get("s", c.s))
	var d := float(pose.get("d", c.d))
	var p := track.pos(s, d)
	p.y += float(pose.get("hop", c.hop))
	var psi := track.heading(s) + float(pose.get("yaw", c.yaw))
	var forward := Vector3(-sin(psi), 0.0, cos(psi))
	var right := Vector3(forward.z, 0.0, -forward.x)
	if not _finish_tracking:
		var offset := global_position - p
		_finish_angle = atan2(offset.dot(right), offset.dot(forward))
		_finish_radius = maxf(1.0, Vector2(offset.x, offset.z).length())
		_finish_height = offset.y
		_finish_tracking = true
	_finish_car_position = p
	_finish_t += dt
	var t := clampf(_finish_t / 3.8, 0.0, 1.0)
	var ease := t * t * (3.0 - 2.0 * t)
	var angle := lerp_angle(_finish_angle, 0.25, ease)
	var radius := lerpf(_finish_radius, 8.5, ease)
	var height := lerpf(_finish_height, 3.0, ease) + sin(PI * ease) * 4.0
	global_position = p + (forward * cos(angle) + right * sin(angle)) * radius + Vector3.UP * height
	look = look.lerp(p + Vector3.UP * 0.8, 1.0 - exp(-dt * 5.0))
	if not global_position.is_equal_approx(look):
		look_at(look, Vector3.UP)
	fov_target = lerpf(fov_target, 64.0, 1.0 - exp(-dt * 3.0))
	fov = fov_target


func _intro_cam(c: CarState, dt: float) -> void:
	intro_t += dt
	var t := clampf(intro_t / 2.8, 0.0, 1.0)
	# Follow a smooth world-space arc rather than sampling a winding road for
	# every frame, which made the opening shot sway abruptly on bends.
	var e := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	var start := track.pos(c.s + 18.0, c.d * 0.2) + Vector3.UP * 8.0
	var middle := track.pos(c.s - 8.0, c.d * 0.5) + Vector3.UP * 9.0
	var end := track.pos(c.s - CHASE_BACK, c.d * 0.82) + Vector3.UP * CHASE_HEIGHT
	var p := start.lerp(middle, e).lerp(middle.lerp(end, e), e)
	global_position = p
	var car := track.pos(c.s, c.d)
	var psi := track.heading(c.s)
	var tg := track.tangent(c.s)
	var grid := track.pos(c.s - 13.0, 0.0) + Vector3.UP
	var final_look := Vector3(car.x - sin(psi) * 12.0, car.y + 1.0 + tg.y * 12.0, car.z + cos(psi) * 12.0)
	look = grid.lerp(final_look, e)
	look_at(look, Vector3.UP)
	fov = 64.0
	fov_target = 64.0
	if t >= 1.0:
		intro = false
		_snap = true
