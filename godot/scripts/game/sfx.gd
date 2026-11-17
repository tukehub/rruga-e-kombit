extends Node
## Sound effects and the mix. Bus graph (a bus may only send to one on its
## left, and sidechains read buses on their right, so the order matters):
##
##   Master    hard limiter
##   ├ World   reverb (near landmarks / walls), low-pass (stunned / wrecked),
##   │         compressor keyed by Voice
##   │ ├ Engine, Tyres, Impacts, Pickups, Ambience
##   ├ UI
##   ├ Music   compressor keyed by Voice (Music.duck() is the scripted duck)
##   └ Voice   announcer (4.3)
##
## Scenes call set_mix(danger, space) every frame; the mix eases toward it.
## One-shots get a small random pitch/level spread and pick among
## `<name>.wav`, `<name>_2.wav` ... `<name>_6.wav` so repeats do not sound
## copied. Haptics are named patterns with strength, not one buzz.

const DIR := "res://assets/sfx/"
const BUSES := ["World", "Engine", "Tyres", "Impacts", "Pickups", "Ambience", "UI", "Music", "Voice"]
## Buses that are the game world and so take its reverb and filter.
const WORLD_BUSES := ["Engine", "Tyres", "Impacts", "Pickups", "Ambience"]
const MAX_VARIANTS := 6
## Pitch spread (fraction) and level spread (dB) per bus.
const SPREAD := {"UI": [0.015, 0.5], "Voice": [0.0, 0.0]}
const SPREAD_DEFAULT := [0.05, 1.5]
## Low-pass cutoff with nothing wrong, and at full danger (wrecked).
const CUTOFF_OPEN := 20000.0
const CUTOFF_DANGER := 650.0
## Reverb wet level at full space.
const REVERB_WET := 0.3
## Seconds to move the whole range: in fast, out slower.
const MIX_ATTACK := 0.12
const MIX_RELEASE := 0.7
const LIMIT_CEILING_DB := -0.5
## Haptic patterns: steps of [ms, amplitude 0..1]; amplitude 0 is a pause.
## A pattern only cuts in on one of equal or higher priority.
const HAPTICS := {
	"tap": {"prio": 0, "steps": [[12, 0.35]]},
	"fire": {"prio": 1, "steps": [[22, 0.5]]},
	"wall": {"prio": 1, "steps": [[16, 0.45]]},
	"score": {"prio": 2, "steps": [[28, 0.65]]},
	"hit_soft": {"prio": 1, "steps": [[14, 0.4]]},
	"hit": {"prio": 3, "steps": [[45, 0.85], [40, 0.0], [25, 0.45]]},
	"hit_heavy": {"prio": 3, "steps": [[70, 1.0], [45, 0.0], [40, 0.6]]},
	"wreck": {"prio": 4, "steps": [[90, 1.0], [60, 0.0], [130, 0.75], [50, 0.0], [60, 0.4]]},
}

var _streams: Dictionary = {}
var _variants: Dictionary = {}   # name -> Array[AudioStream]
var _last_variant: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _loop_players: Dictionary = {}   # name -> AudioStreamPlayer
var _pool_i := 0
var _pool3d_i := 0
var listener_pos := Vector3.ZERO
var enabled := true
var rng := RandomNumberGenerator.new()

## Mix state: targets set by the scene, current values eased toward them.
var danger_target := 0.0
var space_target := 0.0
var danger := 0.0
var space := 0.0
var _reverb: AudioEffectReverb
var _lowpass: AudioEffectLowPassFilter

## Haptics: steps still to play, the running pattern's priority, time left in
## the current step. Every vibration is also passed to haptic_sink, which
## tests replace to record them.
var _haptic_steps: Array = []
var _haptic_prio := -1
var _haptic_wait := 0.0
var haptic_sink := Callable(self, "_vibrate")


func _ready() -> void:
	rng.randomize()
	_setup_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Impacts"
		add_child(p)
		_players.append(p)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Impacts"
		p.max_distance = 140.0
		p.unit_size = 12.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players3d.append(p)
	apply_volumes()
	Settings.changed.connect(apply_volumes)


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus(AudioServer.bus_count)
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	# Put the buses in BUSES order right after Master, whatever existed before.
	for i in BUSES.size():
		var at := AudioServer.get_bus_index(BUSES[i])
		if at != i + 1:
			AudioServer.move_bus(at, i + 1)
	for b in BUSES:
		var idx := AudioServer.get_bus_index(b)
		AudioServer.set_bus_send(idx, "World" if b in WORLD_BUSES else "Master")
		while AudioServer.get_bus_effect_count(idx) > 0:
			AudioServer.remove_bus_effect(idx, 0)
	var master := AudioServer.get_bus_index("Master")
	while AudioServer.get_bus_effect_count(master) > 0:
		AudioServer.remove_bus_effect(master, 0)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMIT_CEILING_DB
	AudioServer.add_bus_effect(master, limiter)

	var world := AudioServer.get_bus_index("World")
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.55
	_reverb.damping = 0.6
	_reverb.predelay_msec = 45.0
	_reverb.predelay_feedback = 0.3
	_reverb.hipass = 0.25
	_reverb.spread = 0.8
	_reverb.dry = 1.0
	_reverb.wet = 0.0
	AudioServer.add_bus_effect(world, _reverb)
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = CUTOFF_OPEN
	_lowpass.resonance = 0.6
	AudioServer.add_bus_effect(world, _lowpass)
	AudioServer.add_bus_effect(world, _voice_ducker(-26.0, 3.0))
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Music"), _voice_ducker(-30.0, 5.0))
	_apply_mix()


## A compressor that pulls its bus down while the announcer talks.
func _voice_ducker(threshold_db: float, ratio: float) -> AudioEffectCompressor:
	var c := AudioEffectCompressor.new()
	c.sidechain = &"Voice"
	c.threshold = threshold_db
	c.ratio = ratio
	c.attack_us = 8000.0
	c.release_ms = 350.0
	c.gain = 0.0
	return c


func apply_volumes() -> void:
	_set_vol("Master", Settings.vol_master)
	_set_vol("Engine", Settings.vol_engine)
	_set_vol("Tyres", Settings.vol_tyres)
	_set_vol("Impacts", Settings.vol_impacts)
	_set_vol("Pickups", Settings.vol_pickups)
	_set_vol("UI", Settings.vol_ui)
	_set_vol("Music", Settings.vol_music)
	_set_vol("Voice", Settings.vol_voice)


func _set_vol(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


# ---------------------------------------------------------------- mix

## What the scene wants this frame. danger 0..1: 0 clear, ~0.6 stunned,
## 1 wrecked (muffles the world). space 0..1: how enclosed the listener is
## (reverb). Values ease in over MIX_ATTACK and out over MIX_RELEASE.
func set_mix(new_danger: float, new_space: float) -> void:
	danger_target = clampf(new_danger, 0.0, 1.0)
	space_target = clampf(new_space, 0.0, 1.0)


## Back to a dry, open mix at once (leaving a race, results, menus).
func reset_mix() -> void:
	danger_target = 0.0
	space_target = 0.0
	danger = 0.0
	space = 0.0
	_apply_mix()


func mix_step(dt: float) -> void:
	danger = _ease(danger, danger_target, dt)
	space = _ease(space, space_target, dt)
	_apply_mix()


func _ease(value: float, target: float, dt: float) -> float:
	return move_toward(value, target, dt / (MIX_ATTACK if target > value else MIX_RELEASE))


static func cutoff_for(amount: float) -> float:
	# Even steps in pitch, not in Hz.
	return CUTOFF_OPEN * pow(CUTOFF_DANGER / CUTOFF_OPEN, clampf(amount, 0.0, 1.0))


func _apply_mix() -> void:
	var world := AudioServer.get_bus_index("World")
	if world < 0 or _lowpass == null:
		return
	_lowpass.cutoff_hz = cutoff_for(danger)
	_reverb.wet = REVERB_WET * space
	# Effects off when they would do nothing: phones pay for every one.
	AudioServer.set_bus_effect_enabled(world, 0, space > 0.01)
	AudioServer.set_bus_effect_enabled(world, 1, danger > 0.01)


## Danger for set_mix() from a car's state: wrecked muffles most, stunned some.
static func danger_of(car) -> float:
	if car == null:
		return 0.0
	if float(car.wreck_t) > 0.0:
		return 1.0
	return 0.6 if float(car.stun_t) > 0.0 else 0.0


## How much reverb the listener at `pos` gets from big buildings: full inside
## `radius` * 0.35 of a landmark, nothing beyond `radius`.
static func space_near(pos: Vector3, anchors: Array, radius := 75.0) -> float:
	var best := 0.0
	for a in anchors:
		var d := Vector2(float(a.x) - pos.x, float(a.z) - pos.z).length()
		best = maxf(best, clampf((radius - d) / (radius * 0.65), 0.0, 1.0))
	return best


func _process(dt: float) -> void:
	mix_step(dt)
	haptic_step(dt)


# ---------------------------------------------------------------- streams

func stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := DIR + name + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = s
	return s


## The stream and its recorded variants (`<name>_2` ... `<name>_6`).
func variants(name: String) -> Array:
	if _variants.has(name):
		return _variants[name]
	var list := []
	var first := stream(name)
	if first != null:
		list.append(first)
		for i in range(2, MAX_VARIANTS + 1):
			var v := stream("%s_%d" % [name, i])
			if v == null:
				break
			list.append(v)
	_variants[name] = list
	return list


## One variant, never the same one twice in a row when there is a choice.
func pick(name: String) -> AudioStream:
	var list := variants(name)
	if list.is_empty():
		return null
	var i := 0
	var last := int(_last_variant.get(name, -1))
	if list.size() > 1 and last < 0:
		i = rng.randi_range(0, list.size() - 1)
	elif list.size() > 1:
		i = rng.randi_range(0, list.size() - 2)
		if i >= last:
			i += 1
	_last_variant[name] = i
	return list[i]


## [pitch, level dB] with this bus's random spread applied.
func spread(bus: String, vol_db: float, pitch: float) -> Array:
	var sp: Array = SPREAD.get(bus, SPREAD_DEFAULT)
	return [pitch * (1.0 + rng.randf_range(-sp[0], sp[0])), vol_db + rng.randf_range(-sp[1], sp[1])]


## Non-positional one shot.
func play(name: String, bus := "Impacts", vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var s := pick(name)
	if s == null:
		return
	var p := _players[_pool_i]
	_pool_i = (_pool_i + 1) % _players.size()
	p.stop()
	p.stream = s
	p.bus = bus
	var sp := spread(bus, vol_db, pitch)
	p.volume_db = sp[1]
	p.pitch_scale = sp[0]
	p.play()


## Positional one shot (world position). Falls back to 2D when close to listener.
func play_at(name: String, pos: Vector3, bus := "Impacts", vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var s := pick(name)
	if s == null:
		return
	var p := _players3d[_pool3d_i]
	_pool3d_i = (_pool3d_i + 1) % _players3d.size()
	p.stop()
	p.stream = s
	p.bus = bus
	var sp := spread(bus, vol_db, pitch)
	p.volume_db = sp[1]
	p.pitch_scale = sp[0]
	p.global_position = pos
	p.play()


## Persistent loop (engine, tyres, wind, rain). Returns the player for live control.
func loop(name: String, bus: String) -> AudioStreamPlayer:
	if _loop_players.has(name):
		return _loop_players[name]
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	_loop_players[name] = p
	return p


func set_loop(name: String, bus: String, vol: float, pitch := 1.0) -> void:
	var p := loop(name, bus)
	if p.stream == null:
		return
	if vol <= 0.002:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(clampf(vol, 0.0, 1.5))
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	if not p.playing:
		p.play()


func stop_loops() -> void:
	for k in _loop_players:
		_loop_players[k].stop()
	reset_mix()


func ui_click() -> void:
	play("ui_click", "UI", -6.0)


func ui_back() -> void:
	play("ui_back", "UI", -6.0)


## Plays a named pattern from HAPTICS (no-op when haptics are off).
func haptic(pattern: String) -> void:
	if not Settings.haptics or not HAPTICS.has(pattern):
		return
	var h: Dictionary = HAPTICS[pattern]
	if int(h.prio) < _haptic_prio and not _haptic_steps.is_empty():
		return
	_haptic_prio = int(h.prio)
	_haptic_steps = (h.steps as Array).duplicate()
	_haptic_wait = 0.0
	haptic_step(0.0)


func haptic_step(dt: float) -> void:
	_haptic_wait -= dt
	while _haptic_wait <= 0.0 and not _haptic_steps.is_empty():
		var step: Array = _haptic_steps.pop_front()
		if float(step[1]) > 0.0:
			haptic_sink.call(int(step[0]), float(step[1]))
		_haptic_wait += float(step[0]) / 1000.0
	if _haptic_steps.is_empty() and _haptic_wait <= 0.0:
		_haptic_prio = -1


func _vibrate(ms: int, amplitude: float) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amplitude)


func stop_all() -> void:
	stop_loops()
	for p in _players:
		p.stop()
		p.stream = null
	for p in _players3d:
		p.stop()
		p.stream = null


func _exit_tree() -> void:
	stop_all()
	for p in _loop_players.values():
		p.stream = null
	_streams.clear()
