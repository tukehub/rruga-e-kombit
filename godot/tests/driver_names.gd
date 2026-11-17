extends Node
## Player-named drivers: cleaning what is typed, saving per driver with the
## version-4 migration, the garage's name field and both race modes using it.

const MenuScript = preload("res://scripts/ui/menu.gd")
const SettingsScript = preload("res://scripts/game/settings.gd")
const TEST_PATH := "user://driver_names_test.cfg"

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func _track() -> RaceTrack:
	var track := RaceTrack.new()
	track.build({"id": "tirane", "hw": 10.0, "pts": [[-600.0, 0.0, -600.0], [600.0, 0.0, -600.0], [600.0, 0.0, 600.0], [-600.0, 0.0, 600.0]]}, false)
	return track


func _ready() -> void:
	var sound := Sfx.enabled
	Sfx.enabled = false
	var saved_names: Dictionary = Settings.driver_names.duplicate()
	var saved_driver: int = int(Game.race_opts.driver)

	# --- cleaning
	check(SettingsScript.clean_name("  Ana   Maria ") == "Ana Maria", "spaces are trimmed and collapsed")
	check(SettingsScript.clean_name("Bo\nb\t!") == "Bob!", "control characters are dropped")
	check(SettingsScript.clean_name("Shpejtësia e Tiranës") == "Shpejtësia e T", "names stop at NAME_MAX letters, Albanian letters kept")
	check(SettingsScript.clean_name("Abcdefghijklm nop").length() <= Settings.NAME_MAX and not SettingsScript.clean_name("Abcdefghijklm nop").ends_with(" "), "a cut name never ends in a space")

	# --- per driver, with defaults
	var s := SettingsScript.new()
	check(s.driver_name(0) == Data.DRIVERS[0].name, "untouched drivers keep their names")
	s.set_driver_name(2, "  Zana ")
	check(s.driver_name(2) == "Zana" and s.driver_name(1) == Data.DRIVERS[1].name, "renaming one driver leaves the others")
	s.set_driver_name(2, "   ")
	check(s.driver_name(2) == Data.DRIVERS[2].name and s.driver_names.is_empty(), "an empty name restores the default")
	s.set_driver_name(3, str(Data.DRIVERS[3].name))
	check(s.driver_names.is_empty(), "typing the default stores nothing")
	s.set_driver_name(99, "Nobody")
	s.set_driver_name(-1, "Nobody")
	check(s.driver_names.is_empty() and s.driver_name(99) == Data.DRIVERS[Data.DRIVERS.size() - 1].name, "drivers that do not exist cannot be renamed")

	# --- saving and migration
	s.set_driver_name(0, "Kapiten")
	s.set_driver_name(4, "Era e Re")
	s.save(TEST_PATH)
	var loaded := SettingsScript.new()
	loaded.load_settings(TEST_PATH)
	check(loaded.driver_name(0) == "Kapiten" and loaded.driver_name(4) == "Era e Re" and loaded.driver_name(1) == Data.DRIVERS[1].name, "names persist")
	var old := ConfigFile.new()
	old.set_value("meta", "version", 3)
	old.set_value("race", "driver_names", {"0": "Ghost"})
	old.save(TEST_PATH)
	var migrated := SettingsScript.new()
	migrated.load_settings(TEST_PATH)
	check(migrated.driver_names.is_empty(), "files before version 4 keep the default names")
	var bad := ConfigFile.new()
	bad.set_value("meta", "version", 4)
	bad.set_value("race", "driver_names", {"1": "   Valon\n   Krasniqi Junior  ", "9": "x", "2": ""})
	bad.save(TEST_PATH)
	var repaired := SettingsScript.new()
	repaired.load_settings(TEST_PATH)
	check(repaired.driver_names.size() == 1 and repaired.driver_name(1) == SettingsScript.clean_name("Valon Krasniqi Junior"), "a hand-edited file is cleaned on load")
	for o in [s, loaded, migrated, repaired]:
		o.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	# --- the races use it
	var track := _track()
	var race := Race.new(track, {"seed": 3, "driver": 1, "player_name": "Kapiten"})
	check(race.player.name == "Kapiten", "the race calls the player by the chosen name")
	var plain := Race.new(track, {"seed": 3, "driver": 1})
	check(plain.player.name == Data.DRIVERS[1].name, "without one, the default")
	var same := true
	for i in race.cars.size():
		same = same and (race.cars[i] == race.player or race.cars[i].name == plain.cars[i].name)
	check(same, "renaming yourself does not reshuffle the rivals")
	var arena := Arena.new({"seed": 3, "driver": 1, "player_name": "Kapiten"})
	check(arena.player.name == "Kapiten", "points rounds use the name too")

	# --- the garage
	Settings.driver_names = {}
	Game.race_opts.driver = 2
	var menu = MenuScript.new()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("car")
	menu._show_garage_tab("driver")
	check(menu._drv_name.text == Data.DRIVERS[2].name, "the name field shows the chosen driver")
	menu._drv_name.text_changed.emit("Dragoi")
	check((menu._drv_btns[2] as Button).text == "Dragoi" and Settings.driver_name(2) == "Dragoi", "typing renames the driver and its button")
	menu._drv_name.text_submitted.emit("  Dragoi   i Kuq ")
	check(menu._drv_name.text == "Dragoi i Kuq", "submitting shows the cleaned name")
	var on_disk := SettingsScript.new()
	on_disk.load_settings()
	check(on_disk.driver_name(2) == "Dragoi i Kuq", "and saves it")
	on_disk.free()
	(menu._drv_btns[0] as Button).pressed.emit()
	check(menu._drv_name.text == Data.DRIVERS[0].name and (menu._drv_btns[2] as Button).text == "Dragoi i Kuq", "choosing another driver shows that one's name")
	menu.queue_free()

	Settings.driver_names = saved_names
	Game.race_opts.driver = saved_driver
	Settings.save()
	await get_tree().create_timer(0.3).timeout
	Sfx.enabled = sound
	print("driver_names: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
