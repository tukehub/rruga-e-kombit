extends Node
## Shop (README 6.3): paints, rims and liveries bought with fans, owned in
## Progress, worn through Settings and drawn by CarVisual.

const ProgressScript = preload("res://scripts/game/progress.gd")
const SettingsScript = preload("res://scripts/game/settings.gd")
const MenuScript = preload("res://scripts/ui/menu.gd")
const PROGRESS_FILE := "user://progress_shop_test.cfg"
const SETTINGS_FILE := "user://settings_shop_test.cfg"

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)

func clean() -> void:
	for path in [PROGRESS_FILE, SETTINGS_FILE]:
		for suffix in ["", ".tmp", ".damaged"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)

func shop_button(menu: Menu, kind: String, id: String) -> Button:
	return menu._shop_btns[kind + ":" + id]

func _ready() -> void:
	var sound := Sfx.enabled
	Sfx.enabled = false
	clean()
	var real_progress: String = Progress.path
	var saved_settings := [Settings.rim_id, Settings.livery_id]
	var saved_car: String = Game.race_opts.car

	# The catalogue.
	for kind in Data.SHOP_KINDS:
		var items: Array = Data.shop_items(kind)
		var free := Data.shop_free(kind)
		check(free.size() >= 1 and items.size() > free.size(), "%s: something free and something to buy" % kind)
		for item: Dictionary in items:
			check(Data.shop_item(kind, item.id) == item and Data.shop_price(kind, item.id) >= 0, "%s %s can be found and priced" % [kind, item.id])
			check(not Data.shop_name(kind, str(item.id)).is_empty(), "%s %s has a name" % [kind, item.id])
			if int(item.get("price", 0)) > 0:
				check(int(item.price) >= 200 and int(item.price) <= 1200, "%s %s costs a few races' fans" % [kind, item.id])
	check(Data.shop_free("paint").size() == 6, "the six original paints stay free")
	for item: Dictionary in Data.LIVERIES:
		check(int(item.tile) >= -1 and int(item.tile) < 4, "livery %s points into the atlas" % item.id)
	var atlas: Texture2D = load("res://assets/cars/livery_atlas.png")
	check(atlas != null and atlas.get_width() == atlas.get_height() * 2, "the livery atlas is four tiles by two rows")
	check(Data.shop_item("rim", "nope").is_empty() and Data.shop_price("rim", "nope") == 0, "unknown items find nothing")

	# Buying.
	var p: Node = ProgressScript.new()
	p.path = PROGRESS_FILE
	p.load_progress()
	check(p.owns("rim", "silver") and not p.owns("rim", "gold") and p.owns("livery", "none"), "a new player owns only the free items")
	check(not p.buy("rim", "gold") and p.fans == 0, "nothing is bought without the fans")
	p.add_fans(1000)
	check(p.buy("rim", "gold") and p.fans == 500 and p.owns("rim", "gold"), "a purchase takes the price and gives the item")
	check(not p.buy("rim", "gold") and p.fans == 500, "an owned item cannot be bought twice")
	check(not p.buy("livery", "checker") and p.fans == 500, "an item dearer than the fans left stays in the shop")
	check(p.buy("paint", "smerald") and p.fans == 0 and p.has_paint("smerald"), "paints are bought the same way")
	check(not p.buy("rim", "nope") and not p.buy("hat", "silver"), "unknown items cannot be bought")
	p.free()
	var reloaded: Node = ProgressScript.new()
	reloaded.path = PROGRESS_FILE
	reloaded.load_progress()
	check(reloaded.owns("rim", "gold") and reloaded.owns("paint", "smerald") and reloaded.fans == 0, "purchases are saved")
	reloaded.free()
	# A version 1 file: no rims or liveries stored; the player keeps the rest.
	var old := ConfigFile.new()
	old.set_value("meta", "version", 1)
	old.set_value("progress", "fans", 320)
	old.set_value("progress", "paints", ["benxi", "uragani"])
	old.save(PROGRESS_FILE)
	var upgraded: Node = ProgressScript.new()
	upgraded.path = PROGRESS_FILE
	upgraded.load_progress()
	check(upgraded.version == ProgressScript.VERSION and upgraded.fans == 320 and upgraded.rims == Data.shop_free("rim") and upgraded.liveries == Data.shop_free("livery"), "a version 1 file gains the free rim and livery")
	upgraded.free()

	# The worn rim and livery are saved, and only owned ones are worn.
	var settings: Node = SettingsScript.new()
	settings.rim_id = "gold"
	settings.livery_id = "stripes"
	settings.save(SETTINGS_FILE)
	var read_back: Node = SettingsScript.new()
	read_back.load_settings(SETTINGS_FILE)
	check(read_back.rim_id == "gold" and read_back.livery_id == "stripes", "the chosen rim and livery survive a save")
	var file := ConfigFile.new()
	file.load(SETTINGS_FILE)
	file.set_value("meta", "version", 1)
	file.save(SETTINGS_FILE)
	var older: Node = SettingsScript.new()
	older.load_settings(SETTINGS_FILE)
	check(older.rim_id == "silver" and older.livery_id == "none", "a settings file from before the shop starts with the free ones")
	settings.free()
	read_back.free()
	older.free()
	Progress.path = PROGRESS_FILE
	Progress.load_progress()
	Settings.rim_id = "gold"
	Settings.livery_id = "stripes"
	check(Game.cosmetics() == {"rim": "silver", "livery": "none"}, "an item the player does not own is not worn")
	Progress.add_fans(2000)
	Progress.buy("rim", "gold")
	Progress.buy("livery", "stripes")
	check(Game.cosmetics() == {"rim": "gold", "livery": "stripes"}, "owned items are worn")

	# CarVisual draws them.
	var def: Dictionary = Data.car("uragani")
	var plain := CarVisual.new()
	add_child(plain)
	plain.setup(def, Color.html(def.color), true)
	var dressed := CarVisual.new()
	add_child(dressed)
	dressed.setup(def, Color.html(def.color), true, {"rim": "gold", "livery": "checker"})
	check(plain.rim.id == "silver" and plain.livery.id == "none" and plain.livery_material == null, "without cosmetics the car is as it always was")
	var gold := Color.html(str(Data.shop_item("rim", "gold").color))
	var rim_colours := []
	for car: CarVisual in [plain, dressed]:
		for wheel: MeshInstance3D in car.wheels.values():
			for i in wheel.mesh.get_surface_count():
				var material := wheel.get_surface_override_material(i) as StandardMaterial3D
				if wheel.mesh.surface_get_material(i).resource_name == "rim":
					rim_colours.append([car == dressed, material.albedo_color])
	check(rim_colours.size() == 8 and rim_colours.all(func(r: Array) -> bool: return r[1].is_equal_approx(gold) == r[0]), "the chosen rim colours all four wheels, and only on that car")
	var livery := dressed.livery_material
	check(livery != null and dressed.mat_paint.next_pass == livery and plain.mat_paint.next_pass == null, "a livery is drawn over the paint")
	check(int(livery.get_shader_parameter("livery_tile")) == int(Data.shop_item("livery", "checker").tile) and livery.get_shader_parameter("livery_atlas") != null, "with its own tile of the atlas")
	var bounds: AABB = dressed.body.mesh.get_aabb()
	check((livery.get_shader_parameter("body_min") as Vector3).is_equal_approx(bounds.position) and (livery.get_shader_parameter("body_size") as Vector3).is_equal_approx(bounds.size), "projected over the body's own bounds")
	check(CarVisual.livery_color_for(Color.WHITE).get_luminance() < 0.2 and CarVisual.livery_color_for(Color("16171b")).get_luminance() > 0.8 and CarVisual.livery_color_for(Color.html(str(def.color))).get_luminance() > 0.8, "the livery colour stands out from the paint")
	plain.queue_free()
	dressed.queue_free()

	# The garage.
	Progress.fans = 700
	Progress.paints = Data.shop_free("paint")
	Progress.rims = Data.shop_free("rim")
	Progress.liveries = Data.shop_free("livery")
	Progress.save()
	Settings.rim_id = "silver"
	Settings.livery_id = "none"
	Game.race_opts.car = "benxi"
	var menu: Menu = MenuScript.new()
	add_child(menu)
	await get_tree().process_frame
	menu.show_page("car")
	check(menu._fans_label.text == "700 fansa" and menu._garage_tab == "paint" and menu._garage_lists.paint.visible and not menu._garage_lists.rim.visible, "the garage opens on the paints and shows the fans")
	check(not menu._buy_btn.visible, "nothing to buy until a shop item is picked")
	var free_paint := shop_button(menu, "paint", "uragani")
	var shop_paint := shop_button(menu, "paint", "ari")
	check(free_paint.text.is_empty() and free_paint.icon != null and shop_paint.text == "600 fansa", "owned paints show their colour; shop paints their price")
	free_paint.pressed.emit()
	check(Game.race_opts.car == "uragani" and not menu._buy_btn.visible and menu.garage_car.def.id == "uragani", "an owned paint is chosen at once")
	shop_paint.pressed.emit()
	check(Game.race_opts.car == "uragani" and menu.garage_car.def.id == "ari", "a shop paint is tried on the garage car, not chosen")
	check(menu._buy_btn.visible and not menu._buy_btn.disabled and menu._buy_btn.text == "Bli · 600 fansa" and menu._car_desc.text == "Provë: Ari", "with its price on the buy button")
	menu._buy_btn.pressed.emit()
	check(Progress.owns("paint", "ari") and Progress.fans == 100 and Game.race_opts.car == "ari" and not menu._buy_btn.visible, "buying pays, owns and chooses it")
	check(shop_paint.text.is_empty() and menu._fans_label.text == "100 fansa", "the button and the balance update")
	# Too dear: the button says how much is missing and does nothing.
	menu._show_garage_tab("livery")
	check(menu._garage_lists.livery.visible and not menu._garage_lists.paint.visible, "tabs switch the list")
	shop_button(menu, "livery", "checker").pressed.emit()
	check(menu._buy_btn.visible and menu._buy_btn.disabled and menu._buy_btn.text == "Të duhen edhe 700 fansa", "a dear item says how many fans are missing")
	check(menu.garage_car.livery.id == "checker" and menu.garage_car.def.id == "ari", "and is still tried on, over the chosen paint")
	menu._buy_preview()
	check(not Progress.owns("livery", "checker") and Progress.fans == 100, "and cannot be bought")
	# Rims: buy one and wear it.
	Progress.add_fans(400)
	menu._show_garage_tab("rim")
	shop_button(menu, "rim", "black").pressed.emit()
	check(menu.garage_car.rim.id == "black" and menu.garage_car.livery.id == "none", "trying a rim drops the livery being tried")
	menu._buy_btn.pressed.emit()
	check(Progress.owns("rim", "black") and Settings.rim_id == "black" and Progress.fans == 250 and Game.cosmetics().rim == "black", "a bought rim is worn")
	shop_button(menu, "rim", "silver").pressed.emit()
	check(Settings.rim_id == "silver" and menu.garage_car.rim.id == "silver", "an owned rim can be put back")
	# Leaving the garage drops the item being tried.
	menu._show_garage_tab("livery")
	shop_button(menu, "livery", "split").pressed.emit()
	check(menu.garage_car.livery.id == "split", "a livery is tried on")
	menu.show_page("title")
	check(menu._preview.is_empty() and menu.garage_car.livery.id == "none", "leaving the garage puts the owned look back")
	menu.queue_free()

	Settings.rim_id = saved_settings[0]
	Settings.livery_id = saved_settings[1]
	Settings.save()
	Game.race_opts.car = saved_car
	Progress.path = real_progress
	Progress.load_progress()
	clean()
	await get_tree().create_timer(0.3).timeout
	Sfx.enabled = sound
	if failures == 0:
		print("SHOP: catalogue, buying, saving, worn cosmetics, car drawing and garage passed")
	get_tree().quit(1 if failures else 0)
