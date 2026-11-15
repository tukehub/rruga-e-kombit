extends RefCounted
## Hysteretic frame-budget controller. Takes measurements, never touches physics,
## device clocks, settings, scene nodes or random state.

const WINDOW := 2.0
const WARMUP := 5.0
const COOLDOWN := 8.0
const RECOVER := 12.0
const MAX_STAGE := 3
var stage := 0
var frame_target := 60
var warmup := WARMUP
var mean_ms := 0.0
var overrun_ratio := 0.0
var changes := 0
var _time := 0.0
var _frames := 0
var _slow := 0
var _bad_windows := 0
var _good_time := 0.0
var _cooldown := 0.0
var _long_frames := 0

func reset(target := 60, keep_stage := false, grace := WARMUP) -> void:
	frame_target = 30 if target == 30 else 60
	if not keep_stage:
		stage = 0
	warmup = grace
	_clear_window()
	_bad_windows = 0
	_good_time = 0.0
	_cooldown = 0.0
	_long_frames = 0

func _clear_window() -> void:
	_time = 0.0
	_frames = 0
	_slow = 0

func observe(dt: float, active := true) -> bool:
	if not active:
		_clear_window()
		_bad_windows = 0
		_good_time = 0.0
		return false
	if not is_finite(dt) or dt <= 0.0:
		return false
	if dt > 0.25:
		_long_frames += 1
		# Ignore an isolated loading/camera-cut stall, but repeated long frames
		# are sustained overload and must eventually lower the budget.
		if _long_frames < 3:
			_clear_window()
			return false
		dt = 0.25
	else:
		_long_frames = 0
	_cooldown = maxf(0.0, _cooldown - dt)
	if warmup > 0.0:
		warmup = maxf(0.0, warmup - dt)
		return false
	_time += dt
	_frames += 1
	var budget := 1.0 / float(frame_target)
	if dt > budget * 1.12:
		_slow += 1
	if _time < WINDOW:
		return false
	var elapsed := _time
	var budget_ms := budget * 1000.0
	mean_ms = 1000.0 * _time / _frames
	overrun_ratio = float(_slow) / _frames
	_clear_window()
	if mean_ms > budget_ms * 1.18 and overrun_ratio >= 0.2:
		_bad_windows += 1
		_good_time = 0.0
	elif mean_ms < budget_ms * 1.07 and overrun_ratio < 0.1:
		_bad_windows = 0
		_good_time += elapsed
	else:
		_bad_windows = 0
		_good_time = 0.0
	if _cooldown > 0.0:
		return false
	var next := stage
	if _bad_windows >= 2:
		next = mini(MAX_STAGE, stage + 1)
	elif _good_time >= RECOVER:
		next = maxi(0, stage - 1)
	if next == stage:
		return false
	stage = next
	changes += 1
	_cooldown = COOLDOWN
	_bad_windows = 0
	_good_time = 0.0
	return true

func snapshot() -> Dictionary:
	return {"stage": stage, "target_fps": frame_target, "mean_ms": mean_ms,
		"overrun_ratio": overrun_ratio, "warmup_s": warmup, "changes": changes}
