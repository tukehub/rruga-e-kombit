extends Node
## Handling difficulty (README 2.2): Arcade / Pro scales the steering assist,
## the corner brake assist and drift grip for the human driver only, apart
## from the rivals' difficulty; the choice is saved and offered in settings.

const SettingsScript = preload("res://scripts/game/settings.gd")
const MenuScript = preload("res://scripts/ui/menu.gd")
const STEP := 1.0 / 60.0
const TEST_PATH := "user://settings_handling_test.cfg"

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func flat_track() -> RaceTrack:
	var track := RaceTrack.load_city("tirane")
	track.K.fill(0.0)
	return track

func new_race(track: RaceTrack, opt: Dictionary) -> Race:
	var options := {"seed": 13}
	options.merge(opt, true)
	var race := Race.new(track, options)
	race.started = true
	return race

func only(key: String, value: float) -> Dictionary:
	var scales := {"assist": 1.0, "brake_assist": 1.0, "drift_grip": 1.0}
	scales[key] = value
	return scales

## Two thirds of a second of a held turn on a straight road, short of the
## wall; returns the car.
func turn(race: Race, c: CarState, drifting: bool) -> CarState:
	c.s = 400.0
	c.progress = 400.0
	c.d = 0.0
	c.yaw = 0.0
	c.lat_v = 0.0
	c.v = 45.0
	c.ctrl.steer = 1.0
	c.ctrl.gas = not drifting
	c.ctrl.brake = drifting
	for i in 40:
		race.physics(c, STEP)
	return c

## The slowest speed over one second approaching Tirana's tightest bend.
func bend_trim(race: Race) -> float:
	var track := race.track
	var worst_s := 0.0
	var worst_k := 0.0
	var probe := 0.0
	while probe < track.L:
		if absf(track.curv(probe)) > worst_k:
			worst_k = absf(track.curv(probe))
			worst_s = probe
		probe += 3.0
	var p := race.player
	p.progress = track.L + worst_s - 40.0
	p.s = track.mod_s(p.progress)
	p.v = 40.0
	p.ctrl.gas = true
	var slowest := INF
	for i in 60:
		p.d = 0.0
		p.yaw = 0.0
		p.lat_v = 0.0
		race.physics(p, STEP)
		slowest = minf(slowest, p.v)
	return slowest

func snapshot(race: Race) -> Array:
	var out := []
	for c in race.cars:
		out.append([c.progress, c.d, c.v, c.yaw, c.health])
	return out

func _ready() -> void:
	# The table: arcade is the baseline, pro eases every aid without removing it.
	var arcade: Dictionary = Data.HANDLING.arcade
	var pro: Dictionary = Data.HANDLING.pro
	check(Data.HANDLING.keys() == ["arcade", "pro"] and Data.HANDLING_DEFAULT == "arcade", "arcade and pro, arcade by default")
	for key in ["assist", "brake_assist", "drift_grip"]:
		check(is_equal_approx(float(arcade[key]), 1.0), "arcade leaves %s as it was" % key)
		check(float(pro[key]) > 0.0 and float(pro[key]) < 1.0, "pro reduces %s" % key)
	check(Data.handling_id("pro") == "pro" and Data.handling_id("drift-king") == "arcade", "unknown handling ids fall back to arcade")

	var track := flat_track()
	check(new_race(track, {}).handling == arcade, "a race without the option drives arcade")
	check(new_race(track, {"handling": "pro"}).handling == pro, "a race takes pro from its options")
	check(new_race(track, {"handling": "nonsense"}).handling == arcade, "a race repairs an unknown handling id")
	for diff in 3:
		var race := new_race(track, {"handling": "pro", "diff": diff})
		check(race.handling == pro and race.diff == Data.DIFFS[diff], "handling is independent of rival difficulty %d" % diff)

	# Arcade is today's car: a whole race step sequence matches the default.
	var plain := new_race(RaceTrack.load_city("tirane"), {"assist": true, "brake_assist": true})
	var named := new_race(RaceTrack.load_city("tirane"), {"assist": true, "brake_assist": true, "handling": "arcade"})
	var pro_race := new_race(RaceTrack.load_city("tirane"), {"assist": true, "brake_assist": true, "handling": "pro"})
	for race in [plain, named, pro_race]:
		race.player.autopilot = true
		for i in 600:
			race.step(STEP)
	check(snapshot(plain) == snapshot(named), "arcade reproduces the default race exactly")
	# Bots, and a player car the AI drives, never read the handling scales.
	check(snapshot(plain) == snapshot(pro_race), "pro changes nothing for AI-driven cars")

	# Steering assist: less self-centring lets the same input turn the car more.
	for assisted in [true, false]:
		var base := turn(new_race(track, {"assist": assisted}), new_race(track, {"assist": assisted}).player, false)
		var a_race := new_race(track, {"assist": assisted})
		var p_race := new_race(track, {"assist": assisted})
		p_race.handling = only("assist", float(pro.assist))
		var a_car := turn(a_race, a_race.player, false)
		var p_car := turn(p_race, p_race.player, false)
		check(is_finite(base.yaw) and p_car.yaw > a_car.yaw + 0.01, "pro steering assist turns in harder (assist %s)" % str(assisted))
		check(p_car.yaw < 1.25 and absf(p_car.d) <= p_race.hw, "pro steering stays inside the car's limits")
	# Without steering input the weaker assist straightens the car more slowly.
	var settle := []
	for scales in [arcade, only("assist", float(pro.assist))]:
		var race := new_race(track, {})
		race.handling = scales
		var c := race.player
		c.s = 400.0
		c.progress = 400.0
		c.v = 30.0
		c.yaw = 0.3
		for i in 30:
			race.physics(c, STEP)
		settle.append(c.yaw)
	check(settle[1] > settle[0] + 0.01 and settle[1] < 0.3, "pro straightens the car more slowly, but still does")

	# Drift grip: a drift bites less in pro, so the slide runs wider.
	var arcade_drift := new_race(track, {})
	var pro_drift := new_race(track, {})
	pro_drift.handling = only("drift_grip", float(pro.drift_grip))
	var a_slide := turn(arcade_drift, arcade_drift.player, true)
	var p_slide := turn(pro_drift, pro_drift.player, true)
	check(a_slide.drift > 0.9 and p_slide.drift > 0.9, "both cars are drifting")
	check(p_slide.yaw < a_slide.yaw - 0.005 and p_slide.d < a_slide.d - 0.02, "pro drift grip turns the drifting car less")
	check(p_slide.yaw > 0.0 and p_slide.d > 0.0, "a pro drift still turns the car")
	# Out of a drift the grip scale has nothing to act on.
	var a_grip := new_race(track, {})
	var p_grip := new_race(track, {})
	p_grip.handling = only("drift_grip", float(pro.drift_grip))
	var a_plain := turn(a_grip, a_grip.player, false)
	var p_plain := turn(p_grip, p_grip.player, false)
	check(a_plain.drift < 0.01 and is_equal_approx(a_plain.yaw, p_plain.yaw) and is_equal_approx(a_plain.d, p_plain.d), "drift grip does not touch ordinary cornering")
	# A rival drifting beside a pro player keeps its own grip.
	var bot_arcade := new_race(track, {})
	var bot_pro := new_race(track, {"handling": "pro"})
	var bots := []
	for race in [bot_arcade, bot_pro]:
		var bot: CarState = race.cars.filter(func(o: CarState) -> bool: return not o.is_player)[0]
		bots.append(turn(race, bot, true))
	check(is_equal_approx(bots[0].yaw, bots[1].yaw) and is_equal_approx(bots[0].d, bots[1].d), "rivals keep the same grip under pro handling")

	# Corner brake assist: pro trims less than arcade and more than no assist.
	var trim_arcade := bend_trim(new_race(RaceTrack.load_city("tirane"), {"brake_assist": true}))
	var trim_pro := bend_trim(new_race(RaceTrack.load_city("tirane"), {"brake_assist": true, "handling": "pro"}))
	var trim_off := bend_trim(new_race(RaceTrack.load_city("tirane"), {"brake_assist": false, "handling": "pro"}))
	check(trim_arcade < 40.0 and trim_pro > trim_arcade + 0.3, "pro trims less speed before the bend")
	check(trim_pro < trim_off - 0.3, "pro still trims when the corner assist is on")
	var expected := 40.0 - Race.CORNER_ASSIST_DECEL * float(pro.brake_assist)
	check(absf(trim_pro - expected) < 0.2, "pro trim follows the brake_assist scale")
	var zero := new_race(RaceTrack.load_city("tirane"), {"brake_assist": true})
	zero.handling = only("brake_assist", 0.0)
	zero.take_events()
	check(absf(bend_trim(zero) - trim_off) < 0.001, "a zero scale switches the trim off")
	check(zero.take_events().all(func(e: Dictionary) -> bool: return e.t != "assist_brake"), "no assist notice when the trim is off")

	# The saved choice: round trip, repair, and files from before the setting.
	var saved := Settings.handling
	check(Data.HANDLING.has(Settings.handling), "the saved handling is a known id")
	var writer := SettingsScript.new()
	writer.handling = "pro"
	writer.save(TEST_PATH)
	var reader := SettingsScript.new()
	reader.load_settings(TEST_PATH)
	check(reader.handling == "pro", "pro handling survives a save and load")
	var file := ConfigFile.new()
	file.load(TEST_PATH)
	check(int(file.get_value("meta", "version", 0)) == SettingsScript.VERSION and SettingsScript.VERSION >= 1, "the settings file records its version")
	file.set_value("game", "handling", "drift-king")
	file.save(TEST_PATH)
	reader.free()
	reader = SettingsScript.new()
	reader.handling = "pro"
	reader.load_settings(TEST_PATH)
	check(reader.handling == "arcade", "an unknown saved handling is repaired to arcade")
	file.set_value("game", "handling", "pro")
	file.set_value("game", "assist", false)
	file.erase_section_key("meta", "version")
	file.save(TEST_PATH)
	reader.free()
	reader = SettingsScript.new()
	reader.load_settings(TEST_PATH)
	check(reader.handling == "arcade" and reader.assist == false, "a file from before the setting keeps arcade and its other choices")
	reader.save(TEST_PATH)
	file = ConfigFile.new()
	file.load(TEST_PATH)
	check(int(file.get_value("meta", "version", 0)) == SettingsScript.VERSION and str(file.get_value("game", "handling", "")) == "arcade", "saving upgrades the old file")
	writer.free()
	reader.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	# The settings page offers the switch and shows the saved choice.
	var menu: Menu = MenuScript.new()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("settings")
	var row: HBoxContainer = menu._set_rows.get("handling")
	check(row != null and row.get_child_count() == 2, "settings has an Arcade / Pro switch")
	if row != null:
		var arcade_button := row.get_child(0) as Button
		var pro_button := row.get_child(1) as Button
		check(arcade_button.text == Data.t("settings.handling.arcade") and pro_button.text == Data.t("settings.handling.pro"), "the switch is labelled from the string table")
		pro_button.pressed.emit()
		check(Settings.handling == "pro" and pro_button.button_pressed and not arcade_button.button_pressed, "choosing Pro sets and shows it")
		arcade_button.pressed.emit()
		check(Settings.handling == "arcade" and arcade_button.button_pressed and not pro_button.button_pressed, "choosing Arcade sets and shows it")
	menu.queue_free()
	Settings.handling = saved
	# The button clicks are still sounding; let them end before quitting.
	await get_tree().create_timer(0.6).timeout

	if failures == 0:
		print("HANDLING: arcade/pro scales steering assist, corner trim and drift grip; saved and selectable")
	get_tree().quit(1 if failures else 0)
