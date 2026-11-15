extends Node
## The string table (scripts/data/strings_sq.gd) is the only home of text the
## player reads. This reads the scripts' source and fails on:
##  - a Data.t()/t_list()/has_text() key that the table does not have,
##  - a table key that no script uses,
##  - a call whose arguments disagree with the text's "%s"/"%d" placeholders,
##  - a script that carries its own text instead of a key.
## Keys are followed by their literal first argument, so write
## Data.t("a") if x else Data.t("b"), never Data.t("a" if x else "b").
## A key may be built with "%s"/"%d" ("pw.%s.name" % type): it then stands for
## every table key of that shape.

const SCRIPT_ROOT := "res://scripts"
const TABLE := "res://scripts/data/strings_sq.gd"
## Written, but no screen shows it yet: the city selector returns with plan 8,
## and the old tips have no place since the loading facts replaced them.
const RESERVED: Array[String] = ["tips", "garage.car_desc", "city.%s.region", "city.%s.blurb", "city.%s.landmarks"]
## Developer diagnostics are not UI text.
const DIAGNOSTICS: Array[String] = ["push_error(", "push_warning(", "print(", "printerr(", "assert("]

var failures := 0
var _key_shape := RegEx.create_from_string("^[a-z0-9_]+(\\.[a-z0-9_]+)*$")
var _reference := RegEx.create_from_string("(?:\\bData\\.|(?<![\\w.]))(t|t_list|has_text)\\(\\s*\"([^\"]+)\"\\s*(.?)")
var _placeholder := RegEx.create_from_string("%[-+ 0]?\\d*(?:\\.\\d+)?[sdfc]")
var _two_words := RegEx.create_from_string("[A-Za-z]{2,}\\s+[A-Za-z]{2,}")
var _shouting := RegEx.create_from_string("(?<![A-Za-z])[A-Z]{3,}(?![A-Za-z])")
var _word := RegEx.create_from_string("[A-Za-z]{2,}")
var _identifier := RegEx.create_from_string("^[a-z0-9_]*$")
## Calls and properties that put their string on screen.
var _sink := RegEx.create_from_string("\\b(label|button|headline|feed|center|pop|finish_place|_mk_button|_eyebrow|_button|_choice|_slider|_set_row|_set_slider|_bottombar|add_item)\\(|\\.(text|tooltip_text)\\s*\\+?=")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func _ready() -> void:
	var table: Dictionary = Data.strings
	table_checks(table)
	var patterns: Array[RegEx] = []
	var references := 0
	var files := scripts(SCRIPT_ROOT)
	check(files.size() > 40 and TABLE in files, "the scripts and the table are readable from source")
	for path in files:
		if path == TABLE:
			continue
		var number := 0
		for raw in FileAccess.get_file_as_string(path).split("\n"):
			number += 1
			var parsed := parse_line(raw)
			var code: String = parsed.code
			var where := "%s:%d" % [path.trim_prefix("res://"), number]
			var keys := {}
			for found in _reference.search_all(code):
				references += 1
				var key := found.get_string(2)
				keys[key] = true
				patterns.append(reference_checks(table, found.get_string(1), key, found.get_string(3), where))
			if DIAGNOSTICS.any(func(call: String) -> bool: return code.contains(call)):
				continue
			for text: String in parsed.literals:
				if not keys.has(text):
					check(not reads_as_text(text, _sink.search(code) != null), "%s holds its own text %s; give it a key in strings_sq.gd" % [where, JSON.stringify(text)])
	for name in RESERVED:
		patterns.append(pattern_of(name))
	for key: String in table:
		check(patterns.any(func(p: RegEx) -> bool: return p.search(key) != null), "no script uses the table key " + key)
	data_checks()
	check(Data.t("hud.lap", [1, 2]) == "XHIRO 1/2" and Data.t("input.drift", 40) == "DRIFT 40%", "placeholders take a list or one value")
	check(Data.has_text("common.yes") and not Data.has_text("common.maybe"), "has_text answers without an error")
	check(Data.ordinal(1) == Data.t_list("results.ordinal")[0] and Data.ordinal(99) == Data.t_list("results.ordinal").back(), "ordinals clamp to the list")
	check(Data.place_msg(6, 6) == Data.t_list("results.place_msg").back() and Data.place_msg(1, 6) == Data.t_list("results.place_msg")[0], "last place always gets the last message")
	print("STRING TABLE: %d keys, %d references in %d scripts; failures=%d" % [table.size(), references, files.size(), failures])
	get_tree().quit(1 if failures else 0)

func table_checks(table: Dictionary) -> void:
	check(table.size() > 200, "the table is loaded")
	for key: String in table:
		check(_key_shape.search(key) != null, "key is lowercase words joined by dots: " + key)
		var value: Variant = table[key]
		var texts: Array = value if value is Array else [value]
		check(not texts.is_empty(), "key has text: " + key)
		var seen := {}
		for text: Variant in texts:
			check(text is String and not str(text).strip_edges().is_empty(), "text is a non-empty string: " + key)
			check(not seen.has(text), "list has no repeated entry: %s (%s)" % [key, text])
			seen[text] = true
			# One source for the name: the table takes it as "%s".
			check(not str(text).to_lower().contains(Data.GAME_NAME.to_lower()), "the game's name is passed in, not written: " + key)
	check(str(ProjectSettings.get_setting("application/config/name")) == Data.GAME_NAME, "the project carries the same name")

## Every data id has its text, whichever screens exist today.
func data_checks() -> void:
	for id: String in Data.ENV:
		check(Data.has_text("env.%s" % id), "weather has a label: " + id)
	for city: Dictionary in Data.CITIES:
		check(Data.has_text("city.%s.name" % city.id), "city has a name: " + str(city.id))
	for car: Dictionary in Data.CARS:
		check(Data.has_text("car.%s.name" % car.id), "paint has a name: " + str(car.id))
	for type: String in Data.PW_KEYS:
		check(Data.has_text("pw.%s.name" % type) and Data.has_text("pw.%s.desc" % type), "power-up has a name and a description: " + type)
		check(Data.has_text("input.fire.%s" % type), "power-up has a fire button caption: " + type)
	for index in Data.DRIVERS.size():
		check(Data.has_text("driver.%d.tag" % index), "driver has a tag line: %d" % index)
	for index in Data.DIFFS.size():
		check(Data.has_text("diff.%d" % index), "difficulty has a name: %d" % index)
	for preset: String in Quality.PRESETS:
		check(Data.has_text("quality.%s" % preset), "quality preset has a name: " + preset)
	check(Data.t_list("results.ordinal").size() >= Data.DRIVERS.size() and Data.t_list("results.place_msg").size() == Data.DRIVERS.size(), "every finishing place has an ordinal and a message")
	check(Data.t_list("loading.facts").size() > 1, "the loading screen can alternate facts")

func reference_checks(table: Dictionary, function: String, key: String, next: String, where: String) -> RegEx:
	var pattern := pattern_of(key)
	check(next in [")", ",", "%"], "%s: the key is the whole first argument, so it can be followed: %s" % [where, key])
	if key.contains("%"):
		check(next == "%", "%s: a key with a placeholder is filled in place: %s" % [where, key])
		check(table.keys().any(func(k: String) -> bool: return pattern.search(k) != null), "%s: no table key has the shape %s" % [where, key])
		return pattern
	if not table.has(key):
		check(false, "%s: the table has no key %s" % [where, key])
		return pattern
	if function == "t_list":
		check(table[key] is Array, "%s: %s is one text, not a list" % [where, key])
	elif function == "t":
		check(table[key] is String, "%s: %s is a list; read it with t_list" % [where, key])
		var wanted := _placeholder.search_all(str(table[key]).replace("%%", "")).size()
		check(next != ")" or wanted == 0, "%s: %s needs %d argument(s)" % [where, key, wanted])
		check(next != "," or wanted > 0, "%s: %s takes no arguments" % [where, key])
	return pattern

## "pw.%s.name" -> every key of that shape; a plain key -> itself.
func pattern_of(key: String) -> RegEx:
	var source := key.replace(".", "\\.").replace("%s", "[a-z0-9_]+").replace("%d", "[0-9]+")
	return RegEx.create_from_string("^" + source + "$")

func reads_as_text(literal: String, on_screen: bool) -> bool:
	if literal.begins_with("res://") or literal.begins_with("user://"):
		return false
	var text := _placeholder.sub(literal.replace("%%", ""), "", true)
	for i in text.length():
		var character := text[i]
		if text.unicode_at(i) > 127 and character.to_upper() != character.to_lower():
			return true  # a letter beyond ASCII: Albanian (or any other) prose
	if _two_words.search(text) != null or _shouting.search(text) != null:
		return true
	return on_screen and _word.search(text) != null and _identifier.search(text) == null

## Splits one source line into its code (comment removed) and string literals.
func parse_line(line: String) -> Dictionary:
	var literals: Array[String] = []
	var quote := ""
	var start := 0
	var i := 0
	while i < line.length():
		var character := line[i]
		if quote.is_empty():
			if character == "#":
				return {"code": line.substr(0, i), "literals": literals}
			if character == "\"" or character == "'":
				quote = character
				start = i + 1
		elif character == "\\":
			i += 1
		elif character == quote:
			literals.append(line.substr(start, i - start))
			quote = ""
		i += 1
	return {"code": line, "literals": literals}

func scripts(directory: String) -> Array[String]:
	var found: Array[String] = []
	for name in DirAccess.get_directories_at(directory):
		found.append_array(scripts(directory.path_join(name)))
	for name in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			found.append(directory.path_join(name))
	return found
