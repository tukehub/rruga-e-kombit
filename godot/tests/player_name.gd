extends Node
## The player's own name (no driver choice; everyone else is a bot): cleaning
## what is typed, saving with the version-5 migration from the old driver
## choice, the garage's name field, and both race modes using it.

const MenuScript = preload("res://scripts/ui/menu.gd")
const SettingsScript = preload("res://scripts/game/settings.gd")
const TEST_PATH := "user://player_name_test.cfg"

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func _track() -> RaceTrack:
	var track := RaceTrack.new()
	track.build({"id": "tirane", "hw": 10.0, "pts": [[-600.0, 0.0, -600.0], [600.0, 0.0, -600.0], [600.0, 0.0, 600.0], [-600.0, 0.0, 600.0]]}, false)
	return track


func load_file(values: Dictionary) -> Object:
	var cf := ConfigFile.new()
	for key in values:
		cf.set_value(key.get_slice("/", 0), key.get_slice("/", 1), values[key])
	cf.save(TEST_PATH)
	var s := SettingsScript.new()
	s.load_settings(TEST_PATH)
	return s


func _ready() -> void:
	var sound := Sfx.enabled
	Sfx.enabled = false
	var saved_name: String = Settings.player_name

	# --- cleaning
	check(SettingsScript.clean_name("  Ana   Maria ") == "Ana Maria", "spaces are trimmed and collapsed")
	check(SettingsScript.clean_name("Bo\nb\t!") == "Bob!", "control characters are dropped")
	check(SettingsScript.clean_name("Shpejtësia e Tiranës") == "Shpejtësia e T", "names stop at NAME_MAX letters, Albanian letters kept")
	check(not SettingsScript.clean_name("Abcdefghijklm nop").ends_with(" "), "a cut name never ends in a space")

	# --- default and saving
	var s := SettingsScript.new()
	check(s.player_name == "" and s.display_name() == Data.t("player.default_name"), "a new player is called the default")
	s.set_player_name("  Kapiten ")
	check(s.display_name() == "Kapiten", "a typed name is used")
	s.save(TEST_PATH)
	var loaded := SettingsScript.new()
	loaded.load_settings(TEST_PATH)
	check(loaded.display_name() == "Kapiten", "the name persists")
	s.set_player_name("   ")
	check(s.display_name() == Data.t("player.default_name"), "an empty name restores the default")

	# --- upgrading old files
	var v3 = load_file({"meta/version": 3, "race/driver": 2})
	check(v3.player_name == SettingsScript.LEGACY_DRIVERS[2], "an old file keeps the name its chosen driver raced under")
	var v4 = load_file({"meta/version": 4, "race/driver": 1, "race/driver_names": {"1": "Shqiponja", "0": "Other"}})
	check(v4.player_name == "Shqiponja", "a renamed driver's name carries over")
	var v4b = load_file({"meta/version": 4, "race/driver": 0, "race/driver_names": {"3": "Other"}})
	check(v4b.player_name == SettingsScript.LEGACY_DRIVERS[0], "only the chosen driver's name carries over")
	var fresh = load_file({"meta/version": 2})
	check(fresh.player_name == "", "a file that never chose a driver starts with the default")
	var bad = load_file({"meta/version": 5, "race/player_name": "  Valon\n  Krasniqi Junior "})
	check(bad.player_name == SettingsScript.clean_name("Valon Krasniqi Junior"), "a hand-edited name is cleaned on load")
	for o in [s, loaded, v3, v4, v4b, fresh, bad]:
		o.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

	# --- the races use it; the rest are bots
	var track := _track()
	var race := Race.new(track, {"seed": 3, "player_name": "Kapiten"})
	check(race.player.name == "Kapiten" and race.cars.filter(func(c: CarState) -> bool: return c.is_player).size() == 1, "the race calls the player by name; everyone else is a bot")
	var names := race.cars.map(func(c: CarState) -> String: return c.name)
	for rival in Data.RIVAL_NAMES.slice(1):
		check(rival in names, "rival %s is on the grid" % rival)
	check(Race.new(track, {"seed": 3}).player.name == Data.PLAYER_FALLBACK_NAME, "a race built without a name still has one")
	var arena := Arena.new({"seed": 3, "player_name": "Kapiten"})
	check(arena.player.name == "Kapiten", "points rounds use the name too")
	check(Arena.new({"seed": 3}).player.name == Data.PLAYER_FALLBACK_NAME, "and a fallback")

	# --- the garage
	Settings.player_name = ""
	var menu = MenuScript.new()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("car")
	menu._show_garage_tab("driver")
	check(menu._drv_name.text == "" and menu._drv_name.placeholder_text == Data.t("player.default_name"), "the name field is empty, hinting the default")
	check(not menu._garage_lists.driver.find_children("*", "Button", true, false).any(func(b: Button) -> bool: return b.toggle_mode), "there is no driver to pick")
	menu._drv_name.text_changed.emit("Dragoi")
	check(Settings.display_name() == "Dragoi", "typing renames the player")
	menu._drv_name.text_submitted.emit("  Dragoi   i Kuq ")
	check(menu._drv_name.text == "Dragoi i Kuq", "submitting shows the cleaned name")
	var on_disk := SettingsScript.new()
	on_disk.load_settings()
	check(on_disk.display_name() == "Dragoi i Kuq", "and saves it")
	on_disk.free()
	menu.queue_free()

	Settings.player_name = saved_name
	Settings.save()
	await get_tree().create_timer(0.3).timeout
	Sfx.enabled = sound
	print("player_name: %d failures" % failures)
	get_tree().quit(1 if failures else 0)
