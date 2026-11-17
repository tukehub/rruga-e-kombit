extends Node
## The mix (plan 4.4): bus graph and effects, the danger low-pass and the
## landmark reverb easing in and out, the voice sidechain, one-shot spread
## and variants, and named haptic patterns.

const STEP := 1.0 / 60.0

var failures := 0
var buzz: Array = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func bus(name: String) -> int:
	return AudioServer.get_bus_index(name)


func effect_of(bus_name: String, type: String) -> AudioEffect:
	var idx := bus(bus_name)
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i).is_class(type):
			return AudioServer.get_bus_effect(idx, i)
	return null


func effect_on(bus_name: String, type: String) -> bool:
	var idx := bus(bus_name)
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i).is_class(type):
			return AudioServer.is_bus_effect_enabled(idx, i)
	return false


func run(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		Sfx.mix_step(STEP)


func _ready() -> void:
	Sfx.set_process(false)

	# --- bus graph
	for b in Sfx.BUSES:
		check(bus(b) > 0, "bus %s exists" % b)
	for b in Sfx.WORLD_BUSES:
		check(AudioServer.get_bus_send(bus(b)) == &"World", "%s goes through World" % b)
		check(bus(b) > bus("World"), "%s sits right of World so it can send there" % b)
	for b in ["World", "UI", "Music", "Voice"]:
		check(AudioServer.get_bus_send(bus(b)) == &"Master", "%s goes straight to Master" % b)
	check(bus("Voice") > bus("World") and bus("Voice") > bus("Music"), "Voice is mixed before the buses it ducks")
	var limiter := effect_of("Master", "AudioEffectHardLimiter") as AudioEffectHardLimiter
	check(limiter != null and limiter.ceiling_db < 0.0, "a limiter guards Master")
	for b in ["World", "Music"]:
		var comp := effect_of(b, "AudioEffectCompressor") as AudioEffectCompressor
		check(comp != null and comp.sidechain == &"Voice", "%s ducks under the announcer" % b)
	# Running setup twice (scene reloads, tests) must not stack effects.
	var count := AudioServer.get_bus_effect_count(bus("World"))
	Sfx._setup_buses()
	check(AudioServer.get_bus_effect_count(bus("World")) == count and AudioServer.get_bus_effect_count(bus("Master")) == 1, "setting up the buses again adds nothing")
	check(AudioServer.bus_count == Sfx.BUSES.size() + 1, "no stray buses")

	# --- danger low-pass and reverb
	Sfx.reset_mix()
	check(not effect_on("World", "AudioEffectLowPassFilter") and not effect_on("World", "AudioEffectReverb"), "a clear, open mix runs no filter or reverb")
	check(is_equal_approx(Sfx.cutoff_for(0.0), Sfx.CUTOFF_OPEN) and is_equal_approx(Sfx.cutoff_for(1.0), Sfx.CUTOFF_DANGER), "cutoff spans open to danger")
	check(Sfx.cutoff_for(0.6) < 3000.0 and Sfx.cutoff_for(0.6) > Sfx.CUTOFF_DANGER, "stunned is muffled, less than wrecked")
	Sfx.set_mix(1.0, 0.0)
	run(Sfx.MIX_ATTACK * 0.5)
	check(Sfx.danger > 0.3 and Sfx.danger < 1.0, "danger eases in, not a jump")
	run(Sfx.MIX_ATTACK)
	var lp := effect_of("World", "AudioEffectLowPassFilter") as AudioEffectLowPassFilter
	check(is_equal_approx(Sfx.danger, 1.0) and effect_on("World", "AudioEffectLowPassFilter") and lp.cutoff_hz < 1000.0, "a wreck muffles the world")
	Sfx.set_mix(0.0, 0.0)
	run(Sfx.MIX_ATTACK * 1.5)
	check(Sfx.danger > 0.0, "the muffle lifts slower than it falls")
	run(Sfx.MIX_RELEASE)
	check(Sfx.danger == 0.0 and not effect_on("World", "AudioEffectLowPassFilter"), "the filter switches off once clear")
	Sfx.set_mix(0.0, 1.0)
	run(Sfx.MIX_ATTACK * 2.0)
	var rv := effect_of("World", "AudioEffectReverb") as AudioEffectReverb
	check(effect_on("World", "AudioEffectReverb") and is_equal_approx(rv.wet, Sfx.REVERB_WET) and is_equal_approx(rv.dry, 1.0), "space adds reverb on top of the dry sound")
	Sfx.set_mix(0.5, 0.5)
	Sfx.stop_loops()
	check(Sfx.danger == 0.0 and Sfx.space == 0.0 and Sfx.danger_target == 0.0 and not effect_on("World", "AudioEffectReverb"), "leaving a race resets the mix at once")

	# Anything with wreck_t / stun_t: race CarState and arena ArenaCar alike.
	var car := {"wreck_t": 0.0, "stun_t": 0.0}
	check(Sfx.danger_of(car) == 0.0, "a healthy car is no danger")
	car.stun_t = 1.0
	check(is_equal_approx(Sfx.danger_of(car), 0.6), "stunned is part danger")
	car.wreck_t = 1.0
	check(Sfx.danger_of(car) == 1.0, "wrecked is full danger")
	check(Sfx.danger_of(null) == 0.0, "no car, no danger")

	var anchors := [{"x": 0.0, "z": 0.0}, {"x": 500.0, "z": 0.0}]
	check(Sfx.space_near(Vector3(10, 100, 0), anchors) == 1.0, "beside a landmark is full space")
	var mid := Sfx.space_near(Vector3(50, 100, 0), anchors)
	check(mid > 0.0 and mid < 1.0, "space falls off with distance")
	check(Sfx.space_near(Vector3(250, 100, 0), anchors) == 0.0, "open street has no reverb")
	check(Sfx.space_near(Vector3.ZERO, []) == 0.0, "no landmarks, no reverb")

	# --- one-shot spread and variants
	Sfx.rng.seed = 7
	var pitches := {}
	for i in 200:
		var sp := Sfx.spread("Impacts", -3.0, 1.0)
		check(absf(sp[0] - 1.0) <= 0.05 + 1e-6 and absf(sp[1] + 3.0) <= 1.5 + 1e-6, "impact spread stays small")
		pitches[snappedf(sp[0], 0.01)] = true
		var ui := Sfx.spread("UI", 0.0, 1.0)
		check(absf(ui[0] - 1.0) <= 0.015 + 1e-6, "UI clicks barely vary")
	check(pitches.size() > 5, "repeated impacts do not share one pitch")
	check(Sfx.spread("Voice", 0.0, 1.0) == [1.0, 0.0], "the announcer is never detuned")
	check(Sfx.variants("impact_hard").size() >= 1 and Sfx.pick("no_such_sound") == null, "variants load what exists, nothing else")
	var a := AudioStreamWAV.new()
	var b := AudioStreamWAV.new()
	var c := AudioStreamWAV.new()
	Sfx._variants["fake"] = [a, b, c]
	var last: AudioStream = null
	var seen := {}
	for i in 60:
		var s := Sfx.pick("fake")
		check(s != last, "a variant never repeats back to back")
		seen[s] = true
		last = s
	check(seen.size() == 3, "every variant gets played")
	Sfx._variants.erase("fake")
	Sfx._last_variant.erase("fake")

	# --- haptics
	var saved_haptics := Settings.haptics
	var sink := Sfx.haptic_sink
	Sfx.haptic_sink = func(ms: int, amp: float) -> void: buzz.append([ms, amp])
	Settings.haptics = true
	for name in Sfx.HAPTICS:
		for step in Sfx.HAPTICS[name].steps:
			check(int(step[0]) > 0 and float(step[1]) >= 0.0 and float(step[1]) <= 1.0, "%s steps are valid" % name)
	Sfx.haptic("wreck")
	check(buzz.size() == 1 and buzz[0] == [90, 1.0], "a pattern starts at once")
	Sfx.haptic("fire")
	check(buzz.size() == 1, "a weak buzz does not cut into a wreck")
	for i in 60:
		Sfx.haptic_step(STEP)
	check(buzz.size() == 3 and buzz[2] == [60, 0.4], "pauses are kept and every pulse plays")
	Sfx.haptic("fire")
	check(buzz.size() == 4 and buzz[3] == [22, 0.5], "once done, any pattern plays")
	Sfx.haptic("no_such_pattern")
	Settings.haptics = false
	Sfx.haptic("wreck")
	for i in 30:
		Sfx.haptic_step(STEP)
	check(buzz.size() == 4, "haptics off means silence, unknown patterns too")
	Settings.haptics = saved_haptics
	Sfx.haptic_sink = sink

	Sfx.reset_mix()
	Sfx.set_process(true)
	print("audio_mix: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
