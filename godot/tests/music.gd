extends Node
## The Music autoload: its bus and saved volume, crossfades between the two
## players, interrupted fades, stopping and ducking. No track ships yet, so
## the streams here are built in memory.

const SettingsScript = preload("res://scripts/game/settings.gd")
const STEP := 1.0 / 60.0

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func tone() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(8000)
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = 8000
	return stream

func gain(index: int) -> float:
	return db_to_linear(Music._players[index].volume_db)

func run(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		Music.advance(STEP)

func _ready() -> void:
	# The fades are stepped by hand here, not by the frame clock.
	Music.set_process(false)
	var saved_volume := Settings.vol_music
	var bus := AudioServer.get_bus_index(Music.BUS)
	check(bus >= 0 and Music.BUS in Sfx.BUSES and AudioServer.get_bus_send(bus) == &"Master", "music has its own bus under Master")
	check(Music._players.size() == 2 and Music._players.all(func(p: AudioStreamPlayer) -> bool: return p.bus == Music.BUS), "two players share the music bus")
	check(Music.process_mode == Node.PROCESS_MODE_ALWAYS, "music keeps fading while the game is paused")
	Settings.vol_music = 0.5
	Settings.save()
	check(is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.5)) and not AudioServer.is_bus_mute(bus), "the saved music volume sets the bus level")
	var loaded := SettingsScript.new()
	loaded.load_settings()
	check(is_equal_approx(loaded.vol_music, 0.5), "the music volume persists")
	loaded.free()
	Settings.vol_music = 0.0
	Settings.save()
	check(AudioServer.is_bus_mute(bus), "zero volume mutes the music bus")
	var engine := AudioServer.get_bus_index("Engine")
	check(not AudioServer.is_bus_mute(engine), "muting music leaves the other buses alone")
	Settings.vol_music = saved_volume
	Settings.save()

	# Nothing ships yet: a missing track is silence, not a crash.
	check(not Music.play("no_such_track") and Music.current() == "", "a missing track plays nothing")
	check(Music.play("") and Music.current() == "", "an empty name means silence")

	# First track fades in from silence.
	var a := tone()
	var b := tone()
	var c := tone()
	Music.play_stream(a, "a", 1.0)
	var first := Music._active
	check(Music.current() == "a" and Music._players[first].playing and gain(first) < 0.001, "a new track starts silent")
	run(0.5)
	check(gain(first) > 0.6 and gain(first) < 0.8, "half way through the fade the track is partly up")
	run(0.6)
	check(is_equal_approx(gain(first), 1.0), "the fade ends at full level")
	Music.play_stream(a, "a", 1.0)
	check(Music._active == first and is_equal_approx(gain(first), 1.0), "asking for the playing track again changes nothing")

	# Crossfade: both audible, constant loudness, then the old one is released.
	Music.play_stream(b, "b", 1.0)
	var second := Music._active
	check(second != first and Music._players[first].playing and Music._players[second].playing, "the next track uses the other player while the old one still plays")
	var steady := true
	for i in 59:
		Music.advance(STEP)
		steady = steady and absf(gain(first) ** 2 + gain(second) ** 2 - 1.0) < 0.01
	check(steady and gain(first) < 0.1 and gain(second) > 0.9, "a crossfade keeps the combined loudness constant")
	run(0.1)
	check(not Music._players[first].playing and Music._players[first].stream == null and is_equal_approx(gain(second), 1.0), "the faded track is stopped and released")

	# A third track in the middle of a fade: the newest wins, nothing gets stuck.
	Music.play_stream(a, "a", 1.0)
	run(0.5)
	Music.play_stream(c, "c", 1.0)
	check(Music.current() == "c" and Music._players[Music._active].stream == c and gain(Music._active) < 0.001, "an interrupted fade starts the newest track from silence")
	run(1.1)
	check(is_equal_approx(gain(Music._active), 1.0) and Music._players[1 - Music._active].stream == null, "an interrupted fade still ends with one track")

	# Ducking: quick down, held, slow up, and it multiplies with a fade.
	var playing := Music._active
	Music.duck(0.3, 1.0)
	run(Music.DUCK_ATTACK + STEP)
	check(is_equal_approx(gain(playing), 0.3), "a duck pulls the music down quickly")
	Music.duck(0.6, 0.2)
	run(0.5)
	check(is_equal_approx(gain(playing), 0.3), "a weaker duck cannot lift one that is still held")
	run(0.6)
	check(gain(playing) > 0.3 and gain(playing) < 1.0, "the music rises gradually after the hold")
	run(Music.DUCK_RELEASE)
	check(is_equal_approx(gain(playing), 1.0), "the music returns to full level")
	Music.duck(0.0, 0.5)
	run(0.2)
	check(gain(playing) < 0.001 and Music._players[playing].playing, "a full duck silences without stopping the track")
	run(0.4 + Music.DUCK_RELEASE)
	Music.duck(0.5, 5.0)
	Music.play_stream(b, "b", 1.0)
	run(0.5)
	check(absf(gain(Music._active) - sin(PI * 0.25) * 0.5) < 0.02, "a duck applies on top of a fade")
	run(6.0)

	# Stop: fade out, release both players. An immediate stop is immediate.
	Music.stop(1.0)
	check(Music.current() == "" and Music._players[Music._active].playing, "stopping fades out instead of cutting")
	run(1.1)
	check(Music._players.all(func(p: AudioStreamPlayer) -> bool: return not p.playing and p.stream == null), "after the fade nothing plays and no stream is held")
	Music.play_stream(a, "a", 0.0)
	Music.advance(STEP)
	check(is_equal_approx(gain(Music._active), 1.0), "a zero fade starts at full level")
	Music.stop(0.0)
	check(Music._players.all(func(p: AudioStreamPlayer) -> bool: return p.stream == null), "a zero fade stops at once")
	print("MUSIC: bus, saved volume, crossfade, interrupted fade, duck and stop; failures=", failures)
	get_tree().quit(1 if failures else 0)
