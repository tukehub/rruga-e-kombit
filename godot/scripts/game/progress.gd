extends Node
## What the player has earned (user://progress.cfg): fans, the paints, rims
## and liveries they own, unlocked cities, cup stars. Settings holds preferences; this holds property, so it
## is written through a temporary file and a damaged file is set aside
## instead of being overwritten.
##
## The file carries a version. Loading upgrades older files step by step
## (_upgrade) and repairs values that make no sense. A file from a newer
## build keeps its version and every key this build does not know.

signal changed

const PATH := "user://progress.cfg"
const VERSION := 2
const MAX_STARS := 3
## Never locked: the city the game opens on.
const HOME_CITY := "tirane"

var path := PATH
var version := VERSION
var fans := 0
var paints: Array[String] = []
var rims: Array[String] = []
var liveries: Array[String] = []
var cities: Array[String] = []
## Cup event id -> best stars earned there (1..MAX_STARS).
var cup_stars := {}
## The file as loaded, so keys written by a newer build survive a save here.
var _file := ConfigFile.new()


func _ready() -> void:
	load_progress()


## Paints every player owns: the six the game has always offered.
func starting_paints() -> Array[String]:
	return Data.shop_free("paint")


func load_progress() -> void:
	_file = ConfigFile.new()
	var stored := 0
	if FileAccess.file_exists(path):
		if _file.load(path) == OK:
			stored = maxi(0, int(_number(_file.get_value("meta", "version", 0))))
		else:
			# Unreadable: keep it for recovery and start clean.
			_file = ConfigFile.new()
			DirAccess.rename_absolute(path, path + ".damaged")
			push_warning("Progress file was unreadable; kept as " + path + ".damaged")
	fans = maxi(0, int(_number(_file.get_value("progress", "fans", 0))))
	paints = _ids(_file.get_value("progress", "paints", []), starting_paints())
	rims = _ids(_file.get_value("progress", "rims", []), Data.shop_free("rim"))
	liveries = _ids(_file.get_value("progress", "liveries", []), Data.shop_free("livery"))
	cities = _ids(_file.get_value("progress", "cities", []), [HOME_CITY])
	cup_stars = {}
	var saved_stars: Variant = _file.get_value("progress", "cup_stars", {})
	if saved_stars is Dictionary:
		for event: Variant in saved_stars:
			var earned := clampi(int(_number(saved_stars[event])), 0, MAX_STARS)
			if event is String and not str(event).is_empty() and earned > 0:
				cup_stars[event] = earned
	version = stored
	while version < VERSION:
		_upgrade(version)
		version += 1
	if stored < VERSION:
		save()


## One step, from `from` to `from + 1`. Later versions add their case here.
func _upgrade(from: int) -> void:
	match from:
		0:
			# Nothing was stored before version 1: a new player, or an install
			# that predates progress. Both start from the defaults load applied.
			pass
		1:
			# Version 2 adds rims and liveries; a version 1 player owns the
			# free ones, which load already applied.
			pass


func save() -> void:
	_file.set_value("meta", "version", version)
	_file.set_value("progress", "fans", fans)
	_file.set_value("progress", "paints", paints)
	_file.set_value("progress", "rims", rims)
	_file.set_value("progress", "liveries", liveries)
	_file.set_value("progress", "cities", cities)
	_file.set_value("progress", "cup_stars", cup_stars)
	# A crash while writing must not cost the player what they earned.
	var temporary := path + ".tmp"
	if _file.save(temporary) == OK and DirAccess.rename_absolute(temporary, path) == OK:
		changed.emit()
	else:
		push_warning("Progress could not be saved to " + path)


func add_fans(amount: int) -> void:
	if amount > 0:
		fans += amount
		save()


## Takes the price only if the player can pay it.
func spend_fans(price: int) -> bool:
	if price < 0 or price > fans:
		return false
	fans -= price
	save()
	return true


func has_paint(id: String) -> bool:
	return paints.has(id)


func unlock_paint(id: String) -> void:
	if not id.is_empty() and not paints.has(id):
		paints.append(id)
		save()


## Shop ownership, by kind ("paint", "rim", "livery").
func owns(kind: String, id: String) -> bool:
	return _owned(kind).has(id)


## Buys an item the player does not own yet, if they have the fans.
func buy(kind: String, id: String) -> bool:
	var item := Data.shop_item(kind, id)
	if item.is_empty() or owns(kind, id):
		return false
	var price := int(item.get("price", 0))
	if price > fans:
		return false
	fans -= price
	_owned(kind).append(id)
	save()
	return true


func _owned(kind: String) -> Array[String]:
	match kind:
		"paint":
			return paints
		"rim":
			return rims
		"livery":
			return liveries
	var none: Array[String] = []
	return none


func has_city(id: String) -> bool:
	return cities.has(id)


func unlock_city(id: String) -> void:
	if not id.is_empty() and not cities.has(id):
		cities.append(id)
		save()


func stars(event: String) -> int:
	return int(cup_stars.get(event, 0))


## Records a cup result; an earlier, better result is kept.
func set_stars(event: String, earned: int) -> void:
	earned = clampi(earned, 0, MAX_STARS)
	if not event.is_empty() and earned > stars(event):
		cup_stars[event] = earned
		save()


func total_stars() -> int:
	var total := 0
	for event: String in cup_stars:
		total += int(cup_stars[event])
	return total


## Saved ids plus the ones every player owns, without repeats or non-text.
## Ids this build does not know stay: they may belong to a newer build.
func _ids(saved: Variant, always: Array) -> Array[String]:
	var ids: Array[String] = []
	for id: Variant in always + (saved if saved is Array else []):
		if id is String and not str(id).is_empty() and not ids.has(id):
			ids.append(id)
	return ids


func _number(value: Variant) -> float:
	return float(value) if (value is int or value is float) and is_finite(float(value)) else 0.0
