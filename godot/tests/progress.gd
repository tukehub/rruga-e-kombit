extends Node
## Progress (fans, unlocked paints and cities, cup stars) survives saving,
## loading, upgrades from older files, damaged values, a damaged file and a
## file written by a newer build. Uses its own files, never the player's.

const ProgressScript = preload("res://scripts/game/progress.gd")
const FILE := "user://progress_test.cfg"

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func fresh() -> Node:
	var progress: Node = ProgressScript.new()
	progress.path = FILE
	progress.load_progress()
	return progress

func clean() -> void:
	for suffix in ["", ".tmp", ".damaged"]:
		if FileAccess.file_exists(FILE + suffix):
			DirAccess.remove_absolute(FILE + suffix)

func stored(section: String, key: String) -> Variant:
	var file := ConfigFile.new()
	file.load(FILE)
	return file.get_value(section, key) if file.has_section_key(section, key) else null

func _ready() -> void:
	check(Progress.path == ProgressScript.PATH and Progress.version == ProgressScript.VERSION, "the autoload reads the player's own file at the current version")
	clean()

	# A new player.
	var p := fresh()
	check(p.version == ProgressScript.VERSION and int(stored("meta", "version")) == ProgressScript.VERSION, "a first run is written at the current version")
	check(p.fans == 0 and p.total_stars() == 0, "a new player has no fans and no stars")
	for car: Dictionary in Data.CARS:
		check(p.has_paint(car.id), "every paint offered today is owned from the start: " + str(car.id))
	check(p.has_city(ProgressScript.HOME_CITY) and not p.has_city("vlore"), "only the home city is open at the start")

	# Earning, spending, unlocking.
	var events := [0]
	p.changed.connect(func() -> void: events[0] += 1)
	p.add_fans(250)
	p.add_fans(-40)
	check(p.fans == 250 and events[0] == 1, "fans are added, never taken by a negative amount")
	check(not p.spend_fans(300) and p.fans == 250, "a price the player cannot pay takes nothing")
	check(not p.spend_fans(-5) and p.fans == 250, "a negative price is refused")
	check(p.spend_fans(100) and p.fans == 150, "an affordable price is taken once")
	p.unlock_paint("gold")
	p.unlock_paint("gold")
	p.unlock_city("vlore")
	p.unlock_city("")
	check(p.paints.count("gold") == 1 and p.has_city("vlore") and not p.cities.has(""), "unlocks are recorded once and need an id")
	p.set_stars("tirana.sprint", 2)
	p.set_stars("tirana.sprint", 1)
	p.set_stars("tirana.rain", 9)
	p.set_stars("tirana.night", 0)
	check(p.stars("tirana.sprint") == 2 and p.stars("tirana.rain") == ProgressScript.MAX_STARS, "the best result is kept and stars stop at the maximum")
	check(p.stars("tirana.night") == 0 and not p.cup_stars.has("tirana.night") and p.total_stars() == 5, "an event without stars is not recorded")
	check(not FileAccess.file_exists(FILE + ".tmp"), "saving leaves no temporary file behind")
	p.free()

	# Everything above comes back from the file.
	p = fresh()
	check(p.fans == 150 and p.has_paint("gold") and p.has_city("vlore") and p.stars("tirana.sprint") == 2 and p.total_stars() == 5, "progress persists across a restart")
	p.free()

	# An older file: no version, some values present, some nonsense.
	var old := ConfigFile.new()
	old.set_value("progress", "fans", -75)
	old.set_value("progress", "paints", ["gold", 7, "", "gold", "benxi"])
	old.set_value("progress", "cities", "vlore")
	old.set_value("progress", "cup_stars", {"tirana.sprint": 12, "tirana.rain": "three", 4: 2, "tirana.night": -1, "tirana.dusk": NAN})
	old.save(FILE)
	p = fresh()
	check(p.version == ProgressScript.VERSION and int(stored("meta", "version")) == ProgressScript.VERSION, "a file without a version is upgraded and rewritten")
	check(p.fans == 0, "negative fans are repaired to zero")
	check(p.paints.count("gold") == 1 and p.paints.count("benxi") == 1 and p.paints.size() == Data.CARS.size() + 1, "paint lists lose repeats and non-ids but keep what was earned")
	check(p.cities == [ProgressScript.HOME_CITY], "a city list of the wrong type falls back to the home city")
	check(p.cup_stars == {"tirana.sprint": ProgressScript.MAX_STARS}, "only valid cup results survive, within the maximum")
	p.free()

	# A file from a newer build: nothing it holds may be lost here.
	var newer := ConfigFile.new()
	newer.set_value("meta", "version", ProgressScript.VERSION + 4)
	newer.set_value("progress", "fans", 900)
	newer.set_value("progress", "paints", ["chrome"])
	newer.set_value("progress", "garage_slots", 3)
	newer.set_value("shop", "rims", ["turbine"])
	newer.save(FILE)
	p = fresh()
	check(p.version == ProgressScript.VERSION + 4 and p.fans == 900 and p.has_paint("chrome"), "a newer file is read as far as this build understands it")
	p.add_fans(100)
	check(int(stored("meta", "version")) == ProgressScript.VERSION + 4, "saving never lowers a newer file's version")
	check(int(stored("progress", "garage_slots")) == 3 and stored("shop", "rims") == ["turbine"], "saving keeps keys this build does not know")
	check(int(stored("progress", "fans")) == 1000, "known values are still updated in a newer file")
	# The same object reading another file must not carry the old one's keys.
	clean()
	p.load_progress()
	check(p.fans == 0 and p.version == ProgressScript.VERSION and stored("shop", "rims") == null and stored("progress", "garage_slots") == null, "loading again starts from the file alone")
	p.free()

	# A damaged file is set aside, not overwritten.
	var damaged := FileAccess.open(FILE, FileAccess.WRITE)
	damaged.store_string("[progress\nfans=\"\"\"")
	damaged.close()
	p = fresh()
	check(p.fans == 0 and p.version == ProgressScript.VERSION, "a damaged file starts the player clean")
	check(FileAccess.file_exists(FILE + ".damaged") and FileAccess.get_file_as_string(FILE + ".damaged").begins_with("[progress\nfans"), "the damaged file is kept for recovery")
	check(int(stored("meta", "version")) == ProgressScript.VERSION, "a readable file replaces it")
	p.free()

	clean()
	print("PROGRESS: defaults, earning, unlocks, stars, restart, upgrade, repair, newer and damaged files; failures=", failures)
	get_tree().quit(1 if failures else 0)
