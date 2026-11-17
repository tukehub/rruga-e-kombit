extends Node
## The announcer (plan 4.3): every line has a recording, the queue's
## priorities, gap, stale-line drop, cooldowns and cut-ins, the finish and
## points-round lines, the settings switch and level with their migration.

const SettingsScript = preload("res://scripts/game/settings.gd")
const STEP := 1.0 / 60.0
const TEST_PATH := "user://announcer_settings_test.cfg"

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func run(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		Announcer.advance(STEP)


func keys_said() -> Array:
	return Announcer.said.map(func(s: Array) -> String: return s[0])


func fresh() -> void:
	Announcer.clear()
	run(5.0)
	Announcer.said.clear()
	Announcer._said_at.clear()


func _ready() -> void:
	Announcer.set_process(false)
	Announcer.output = false
	var saved_on := Settings.announcer
	Settings.announcer = true

	# --- recordings
	for key in Announcer.LINES:
		var s := Announcer.stream(key)
		check(s != null and s.get_length() > 0.2 and s.get_length() < 2.0, "line %s is recorded and short" % key)
	var files := Array(DirAccess.get_files_at(Announcer.DIR + Announcer.LANG)).filter(func(f: String) -> bool: return f.ends_with(".ogg"))
	check(files.size() == Announcer.LINES.size(), "no recording without a line")
	check(Announcer._player.bus == Announcer.BUS and AudioServer.get_bus_index(Announcer.BUS) > 0, "the announcer talks on the Voice bus")

	# --- the queue
	fresh()
	check(Announcer.say("3") and Announcer.current() == "3", "a line on a quiet channel starts at once")
	check(Announcer.say("target_destroyed"), "a lower line waits")
	check(not Announcer.say("target_destroyed"), "the same line is not queued twice")
	check(Announcer.current() == "3", "waiting does not interrupt")
	run(Announcer.stream("3").get_length() + Announcer.GAP + 0.05)
	check(Announcer.current() == "target_destroyed", "the waiting line follows after the gap")
	var said: Array = Announcer.said
	check(said[1][1] - said[0][1] >= Announcer.stream("3").get_length() + Announcer.GAP - STEP, "lines never overlap")

	fresh()
	Announcer.say("final_lap")
	Announcer.say("look_out")
	run(3.0)
	check(keys_said() == ["final_lap"], "a warning that comes too late is dropped, not said late")

	fresh()
	Announcer.say("final_lap")
	run(0.2)
	check(Announcer.say("go") and Announcer.current() == "go", "countdown lines cut in")
	check(keys_said() == ["final_lap", "go"], "the cut-in replaced the lower line")

	fresh()
	Announcer.say("go")
	Announcer.say("new_record")
	Announcer.say("target_destroyed")
	run(Announcer.stream("go").get_length() + Announcer.GAP + 0.05)
	check(Announcer.current() == "target_destroyed", "the most important waiting line goes first")
	run(2.5)
	check(keys_said() == ["go", "target_destroyed", "new_record"], "then the next")

	fresh()
	Announcer.say("go")
	Announcer.say("new_record")
	Announcer.say("hurry_up")
	Announcer.say("look_out")
	Announcer.say("target_destroyed")
	check(Announcer._queue.size() == Announcer.QUEUE_MAX and not Announcer._queue.any(func(q: Dictionary) -> bool: return q.key == "hurry_up"), "a full queue sheds its least important line")

	fresh()
	check(Announcer.say("look_out"), "a warning is said")
	run(2.0)
	check(not Announcer.say("look_out"), "and not again within its cooldown")
	run(Announcer.LINES.look_out.cooldown)
	check(Announcer.say("look_out"), "after the cooldown it is said again")
	check(not Announcer.LINES.has("power_up"), "power-ups are not announced")

	fresh()
	check(not Announcer.say("no_such_line"), "unknown lines are silence")
	Settings.announcer = false
	check(not Announcer.say("go") and Announcer.current() == "", "switched off, it says nothing")
	Settings.announcer = true
	Announcer.say("final_lap")
	Announcer.say("target_destroyed")
	Announcer.clear()
	run(0.1)
	check(Announcer.current() == "" and Announcer._queue.is_empty(), "clear() silences and forgets")

	# --- which line
	check(Announcer.finish_line(1, 6) == "you_win", "first wins")
	check(Announcer.finish_line(3, 6) == "congratulations", "podium is congratulated")
	check(Announcer.finish_line(4, 6) == "you_lose", "off the podium loses")
	check(Announcer.finish_line(2, 2) == "you_lose", "second of two is last")
	var me := {"score": 500}
	var a := {"score": 700}
	var b := {"score": 500}
	check(Announcer.arena_line(me, [me, {"score": 300}]) == "you_win", "top score wins the round")
	check(Announcer.arena_line(me, [b, me]) == "tie", "a shared top score is a tie")
	check(Announcer.arena_line(me, [a, me, {"score": 1}]) == "congratulations", "second in points is congratulated")
	check(Announcer.arena_line(me, [a, {"score": 600}, {"score": 550}, me]) == "you_lose", "fourth in points loses")

	# --- settings
	var old := ConfigFile.new()
	old.set_value("meta", "version", 2)
	old.set_value("game", "announcer", false)
	old.set_value("audio", "voice", 0.1)
	old.save(TEST_PATH)
	var loaded := SettingsScript.new()
	loaded.load_settings(TEST_PATH)
	check(loaded.announcer and is_equal_approx(loaded.vol_voice, 1.0), "files before version 3 start with the announcer on, full")
	loaded.announcer = false
	loaded.vol_voice = 0.4
	loaded.save(TEST_PATH)
	var again := SettingsScript.new()
	again.load_settings(TEST_PATH)
	check(not again.announcer and is_equal_approx(again.vol_voice, 0.4), "the switch and level persist")
	loaded.free()
	again.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var saved_voice := Settings.vol_voice
	Settings.vol_voice = 0.5
	Sfx.apply_volumes()
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Voice")), linear_to_db(0.5)), "the voice level sets the Voice bus")
	Settings.vol_voice = saved_voice
	Sfx.apply_volumes()

	Settings.announcer = saved_on
	Announcer.clear()
	Announcer.set_process(true)
	Announcer.output = true
	print("announcer: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
