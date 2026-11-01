class_name ChaseCam
extends Camera3D
## Third-person chase camera, port of chaseCam() in src/10_main.js plus the
## 2.8 s intro sweep. Speed-dependent FOV, nitro FOV kick, impact shake.

var track: RaceTrack
var look := Vector3.ZERO
var fov_target := 64.0
var shake := 0.0
var intro_t := 0.0
var intro := false
var _snap := true
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


func follow(c: CarState, dt: float) -> void:
	if intro:
		_intro_cam(c, dt)
		return
	var sp := absf(c.v)
	# real-scale cars (~4.5 m) need more distance than the original 3.5 m
	var back := 6.4 + sp * 0.022
	var h := 2.15 + sp * 0.006
	var target := track.pos(c.s - back, c.d * 0.82)
	target.y += h + c.hop * 0.5
	var car := track.pos(c.s, c.d)
	car.y += c.hop
	var psi := track.heading(c.s) + c.yaw * 0.5
	var tg := track.tangent(c.s)
	var look_t := Vector3(car.x - sin(psi) * 12.0, car.y + 1.0 + tg.y * 12.0, car.z + cos(psi) * 12.0)
	var snap := _snap or global_position.distance_squared_to(target) > 900.0
	_snap = false
	var k := 1.0 if snap else 1.0 - exp(-dt * 8.0)
	var kl := 1.0 if snap else 1.0 - exp(-dt * 12.0)
	var p := global_position.lerp(target, k)
	look = look.lerp(look_t, kl)
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 2.5)
		var s := shake * 0.5
		p.x += (_rng.randf() - 0.5) * s
		p.y += (_rng.randf() - 0.5) * s
	global_position = p
	if not p.is_equal_approx(look):
		look_at(look, Vector3.UP)
	var want := 64.0 + clampf(sp / 60.0, 0.0, 1.3) * 12.0 + (10.0 if c.nitro_t > 0.0 else 0.0)
	fov_target += (want - fov_target) * (1.0 - exp(-dt * 4.0))
	fov = fov_target


func _intro_cam(c: CarState, dt: float) -> void:
	intro_t += dt
	var t := clampf(intro_t / 2.8, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var p := track.pos(c.s + lerpf(30.0, -9.5, e), c.d * lerpf(0.2, 0.82, e))
	p.y += lerpf(2.2, 3.0, e) + sin(e * PI) * 7.0
	global_position = p
	var car := track.pos(c.s, c.d)
	var psi := track.heading(c.s)
	look = Vector3(car.x - sin(psi) * 7.0 * e, car.y + 1.0, car.z + cos(psi) * 7.0 * e)
	look_at(look, Vector3.UP)
	fov = 64.0
	fov_target = 64.0
	if t >= 1.0:
		intro = false
		_snap = true
