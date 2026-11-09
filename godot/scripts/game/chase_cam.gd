class_name ChaseCam
extends Camera3D
## Third-person chase camera, port of chaseCam() in src/10_main.js plus the
## 2.8 s intro sweep. Speed-dependent FOV, nitro FOV kick, impact shake.

# real-scale cars (~4.5 m) need more distance than the original 3.5 m
const CHASE_BACK := 7.0
const CHASE_HEIGHT := 2.3

var track: RaceTrack
var look := Vector3.ZERO
var fov_target := 64.0
var shake := 0.0
var intro_t := 0.0
var intro := false
var cabin := false
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
var _rng := RandomNumberGenerator.new()


func setup(p_track: RaceTrack) -> void:
	track = p_track
	near = 0.3
	far = 6000.0
	fov = 64.0
	_snap = true


func start_intro() -> void:
	intro = true
	intro_t = 0.0


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 1.5)


func follow(c: CarState, dt: float, pose: Dictionary = {}) -> void:
	if intro:
		_intro_cam(c, dt)
		return
	var s := float(pose.get("s", c.s))
	var d := float(pose.get("d", c.d))
	var hop := float(pose.get("hop", c.hop))
	var yaw := float(pose.get("yaw", c.yaw))
	if cabin:
		_follow_cabin(c, s, d, yaw, hop, dt)
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
	_cam_d = lerpf(_cam_d, d * 0.82, k)
	_cam_hop = lerpf(_cam_hop, hop, k)
	_cam_psi = lerp_angle(_cam_psi, psi, kl)
	_cam_slope = lerpf(_cam_slope, tg.y, kl)
	var p := track.pos(s - CHASE_BACK, _cam_d)
	p.y += CHASE_HEIGHT + _cam_hop * 0.5
	look = Vector3(car.x - sin(_cam_psi) * 12.0, car.y + 1.0 + _cam_slope * 12.0, car.z + cos(_cam_psi) * 12.0)
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 2.5)
		var shake_size := shake * 0.5
		p.x += (_rng.randf() - 0.5) * shake_size
		p.y += (_rng.randf() - 0.5) * shake_size
	global_position = p
	if not p.is_equal_approx(look):
		look_at(look, Vector3.UP)
	var want := 64.0 + clampf(sp / 60.0, 0.0, 1.3) * 12.0 + (10.0 if c.nitro_t > 0.0 else 0.0)
	fov_target += (want - fov_target) * (1.0 - exp(-dt * 4.0))
	fov = fov_target


func _follow_cabin(c: CarState, s: float, d: float, yaw: float, hop: float, dt: float) -> void:
	var p := track.pos(s, d)
	p.y += 1.23 + hop
	var psi := track.heading(s) + yaw
	var tg := track.tangent(s)
	var forward := Vector3(-sin(psi), tg.y, cos(psi)).normalized()
	global_position = p
	look = p + forward * 30.0
	look_at(look, Vector3.UP)
	var want := 74.0 + clampf(absf(c.v) / 60.0, 0.0, 1.0) * 5.0
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
