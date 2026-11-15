extends Node
## Scenario checks use the real Race integration and shared pickup dictionaries.

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHECK FAILED: " + message)


func _ready() -> void:
	_check_utility()
	_check_gap_history()
	_check_offers_and_shared_collection()
	_check_visibility_and_existing_supply()
	_check_limits()
	_check_reverse_and_wrap()
	_check_determinism()
	_check_visual_sync()
	_check_distribution_and_history()
	_check_actual_tirana_race()
	await get_tree().process_frame
	print("ADAPTIVE PICKUPS: utility, recovery, shared offers, visibility, cooldowns, finish, reverse, RNG and visuals; failures=", failures)
	get_tree().quit(1 if failures else 0)


func _track(reverse := false, size := 1000.0) -> RaceTrack:
	var track := RaceTrack.new()
	track.build({"id": "tirane", "hw": 10.0, "pts": [
		[-size, 0.0, -size], [size, 0.0, -size], [size, 0.0, size], [-size, 0.0, size]]}, reverse)
	return track


func _move(race: Race, c: CarState, progress: float) -> void:
	c.progress = progress
	c.s = race.track.mod_s(progress)
	c.d = 0.0


func _fixture(seed_value := 13, reverse := false, adaptive := true) -> Race:
	var race := Race.new(_track(reverse), {"seed": seed_value, "laps": 2, "adaptive_pickups": adaptive})
	race.started = true
	race.time = 20.0
	_move(race, race.player, 1000.0)
	race.player.v = 45.0
	for c: CarState in race.cars:
		if c != race.player:
			_move(race, c, 1340.0 + c.id * 70.0)
			c.v = 45.0
	# Keep ordinary rows away from this isolated stretch unless a test places one.
	for i in race.pickups.size():
		var p: Dictionary = race.pickups[i]
		if not bool(p.get("adaptive", false)):
			p.s = race.track.mod_s(race.player.s + 600.0 + int(i / 3) * 30.0)
	race.compute_order()
	return race


func _advance(race: Race, seconds: float) -> void:
	for i in int(ceil(seconds / 0.25)):
		race.time += 0.25
		race.pickup_director.advance(race, 0.25)


func _bonus_rows(race: Race) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in race.pickup_director.rows:
		if row.bonus and bool(row.active):
			result.append(row)
	return result


func _check_utility() -> void:
	var race := _fixture()
	var director := race.pickup_director
	var c := race.player
	for rival: CarState in race.cars:
		if rival != c:
			_move(race, rival, c.progress - 200.0 - rival.id * 10.0)
	var w: Dictionary = director.weights(race, c, c.s + 200.0)
	check(w.repair == 0.0 and w.shock == 0.0, "healthy leader must not be offered repair or leader-targeting storm")
	c.health = c.max_hp * 0.25
	w = director.weights(race, c, c.s + 200.0)
	check(w.repair > float(Data.PW.repair.w) * 4.0, "low health strongly favors repair")
	var quiet_shield: float = w.shield
	director.note_hit(c, race.time)
	w = director.weights(race, c, c.s + 200.0)
	check(w.shield > quiet_shield * 3.0, "recent attacks increase defence supply")
	c.slots = [{"type": "repair", "ammo": 1}, {"type": "nitro", "ammo": 1}, {"type": "shield", "ammo": 1}]
	w = director.weights(race, c, c.s + 200.0)
	check(w.repair == 0.0 and w.nitro == 0.0 and w.shield == 0.0, "held recovery/boost items must not be duplicated")
	c.slots.clear()
	c.health = c.max_hp
	var straight_nitro: float = director.weights(race, c, c.s + 200.0).nitro
	race.track.K.fill(0.04)
	w = director.weights(race, c, c.s + 200.0)
	check(w.nitro < straight_nitro * 0.2, "tight upcoming bends suppress immediate nitro supply")
	check(Data.PW.nitro.w == 17 and Data.PW.repair.w == 9, "context weights must not mutate global balance data")
	# A nearby opponent makes bolts useful; an isolated racer gets comeback tools.
	race = _fixture()
	director = race.pickup_director
	c = race.player
	var rival := race.cars[0]
	_move(race, rival, c.progress + 50.0)
	var close_bolt: float = director.weights(race, c, c.s + 200.0).bolt
	_move(race, rival, c.progress + 500.0)
	_advance(race, 2.0)
	w = director.weights(race, c, c.s + 200.0)
	check(w.bolt < close_bolt * 0.1, "isolated racers must not receive a close-range weapon bias")
	# An actual storm use reserves supply across every racer, not only its owner.
	c.slots = [{"type": "shock", "ammo": 1}]
	race.use_item(c, false)
	check(not race.domes.is_empty(), "storm scenario must exercise actual weapon use")
	check(director.weights(race, c, c.s + 200.0).shock == 0.0, "active storm prevents further storm supply")
	race.domes.clear()
	check(director.weights(race, c, c.s + 200.0).shock == 0.0, "storm supply cooldown survives disappearance of its domes")


func _check_gap_history() -> void:
	var race := _fixture()
	var c := race.player
	_advance(race, 0.25)
	check(not bool(race.pickup_director.history[c.id].behind), "one gap sample must not trigger strong catch-up bias")
	_advance(race, 2.0)
	check(bool(race.pickup_director.history[c.id].behind), "a sustained large gap enables comeback bias")
	for rival: CarState in race.cars:
		if rival != c:
			_move(race, rival, c.progress + 20.0)
	_advance(race, 0.25)
	check(bool(race.pickup_director.history[c.id].behind), "a single close sample does not make catch-up oscillate")
	_advance(race, 10.0)
	check(not bool(race.pickup_director.history[c.id].behind), "comeback bias fades after the racer rejoins the pack")
	# Carrying a boost must not suppress a useful long-range attack opportunity.
	race = _fixture()
	c = race.player
	c.v = 0.0
	_advance(race, 3.0)
	c.v = 45.0
	c.slots = [{"type": "nitro", "ammo": 1}]
	_advance(race, 0.25)
	var offered_attack := false
	for row: Dictionary in _bonus_rows(race):
		for p: Dictionary in row.items:
			offered_attack = offered_attack or p.type == "shock" or p.type == "eagle"
	check(offered_attack, "a far-behind racer already carrying nitro can still receive useful attack supply")


func _check_offers_and_shared_collection() -> void:
	var race := _fixture()
	var initial_size := race.pickups.size()
	_advance(race, 2.0)
	var rows := _bonus_rows(race)
	check(rows.size() == 1, "a sustained isolated racer receives one extra opportunity")
	if rows.is_empty():
		return
	var row: Dictionary = rows[0]
	var distance := race.track.mod_s(float(row.items[0].s) - race.player.s)
	check(distance >= 190.0 and distance <= 200.1, "new useful station is within the next 100–200 m")
	check(race.pickups.size() == initial_size, "offers activate the preallocated pool rather than growing it")
	check(race.player.slots.is_empty(), "help must never grant inventory automatically")
	var choices := {}
	for p: Dictionary in row.items:
		choices[p.type] = true
	check(choices.size() == 3, "a station retains three distinct lane choices")
	check(choices.has("nitro") or choices.has("shock"), "far-behind opportunity includes a useful comeback tool")
	# A bot can take exactly the advertised shared item before the human arrives.
	var item: Dictionary = row.items[0]
	var kind: String = item.type
	var bot := race.cars[0]
	_move(race, bot, float(row.progress))
	bot.d = item.d
	race.update_pickups(0.0)
	check(bot.slots.size() == 1 and bot.slots[0].type == kind, "a bot collects the same advertised shared pickup")
	check(not item.alive and race.player.slots.is_empty(), "bot collection does not secretly reward the player")
	check(int(race.pickup_director.counts.help_collected) == 1, "actual assistance collection is measured")
	check(int(race.pickup_director.counts.player_help_collected) == 0, "bot collections must not be reported as player assistance")
	race.update_pickups(3.0)
	check(not item.alive, "one-shot assistance pickups must not respawn for farming")
	# Once safely passed, return unused offers to the bounded pool.
	_move(race, race.player, float(row.progress) + 400.0)
	for c: CarState in race.cars:
		if c != race.player:
			_move(race, c, race.player.progress + 450.0 + c.id * 50.0)
	race.player.slots = [{"type": "bolt", "ammo": 3}, {"type": "mine", "ammo": 1}, {"type": "shield", "ammo": 1}]
	_advance(race, 0.25)
	check(not bool(row.active), "safely passed assistance stations are recycled")


func _check_visibility_and_existing_supply() -> void:
	var race := _fixture()
	var first: Dictionary = race.pickup_director.rows[0]
	for p: Dictionary in first.items:
		p.s = race.track.mod_s(race.player.s + 150.0)
		p.type = "nitro"
	_advance(race, 2.0)
	check(_bonus_rows(race).is_empty(), "an existing useful station in the next 100–200 m needs no extra row")
	for p: Dictionary in first.items:
		check(p.type == "nitro", "visible pickup types must remain stable even when context changes")
	# Test an actual hidden normal station changing with the player's health.
	race = _fixture()
	first = race.pickup_director.rows[0]
	race.player.health = race.player.max_hp * 0.2
	for p: Dictionary in first.items:
		p.s = race.track.mod_s(race.player.s + 210.0)
		p.type = "shock"
	_advance(race, 0.25)
	check(int(race.pickup_director.counts.normal_plans) > 0, "unseen normal stations are replanned before entering view")
	var original: Array[String] = []
	for p: Dictionary in first.items:
		original.append(p.type)
	_move(race, race.player, race.player.progress + 90.0)
	race.player.health = race.player.max_hp
	_advance(race, 1.0)
	for i in first.items.size():
		check(first.items[i].type == original[i], "approaching a planned station must not reroll its icons")
	# Nearby parallel streets/hairpins must respect world distance as well as s.
	var tight_track := _track(false, 50.0)
	var tight := Race.new(tight_track, {"seed": 4, "laps": 5})
	tight.started = true
	tight.time = 20.0
	_move(tight, tight.player, 0.0)
	tight.player.v = 30.0
	check(not tight.pickup_director._can_edit(tight, 195.0), "a forward point on a nearby returning road is already in view")
	_advance(tight, 2.0)
	check(_bonus_rows(tight).is_empty(), "help must not pop into view on a tight looping track")
	# A cooldown on generating new storms must not dismiss an existing one.
	race = _fixture()
	race.player.v = 0.0
	_advance(race, 3.0)
	race.player.v = 45.0
	first = race.pickup_director.rows[0]
	for p2: Dictionary in first.items:
		p2.s = race.track.mod_s(race.player.s + 150.0)
		p2.type = "shock"
	race.pickup_director.note_use(race.cars[0], "shock", race.time)
	_advance(race, 0.25)
	check(_bonus_rows(race).is_empty(), "an already advertised useful storm still covers the comeback need during its supply reservation")


func _check_limits() -> void:
	var race := _fixture()
	var c := race.player
	c.slots = [{"type": "bolt", "ammo": 3}, {"type": "mine", "ammo": 1}, {"type": "shield", "ammo": 1}]
	var inventory := JSON.stringify(c.slots)
	_advance(race, 3.0)
	check(_bonus_rows(race).is_empty() and JSON.stringify(c.slots) == inventory, "a full inventory is neither overwritten nor supplied with an extra station")
	c.slots.clear()
	_advance(race, 0.25)
	check(int(race.pickup_director.counts.help_offers) == 1, "freeing capacity enables a needed offer")
	for row: Dictionary in _bonus_rows(race):
		for p: Dictionary in row.items:
			p.alive = false
	_move(race, c, c.progress + 300.0)
	_advance(race, 1.0)
	check(int(race.pickup_director.counts.help_offers) == 1, "rapidly clearing an offer must not bypass the cooldown")
	_advance(race, 12.0)
	check(int(race.pickup_director.counts.help_offers) <= 2, "help supply is rate limited")
	var offers: int = race.pickup_director.counts.help_offers
	for row: Dictionary in _bonus_rows(race):
		for p: Dictionary in row.items:
			p.alive = false
	_advance(race, 30.0)
	check(int(race.pickup_director.counts.help_offers) == offers, "waiting without forward travel cannot farm assistance")
	race = _fixture()
	_move(race, race.player, race.laps * race.L - 170.0)
	_advance(race, 3.0)
	check(_bonus_rows(race).is_empty(), "no assistance station may be placed beyond the actual race finish")
	race = _fixture()
	race.started = false
	_advance(race, 3.0)
	check(race.pickup_director.decisions.is_empty(), "intro and countdown do not trigger adaptive planning")
	race.started = true
	race.player.finished = true
	_advance(race, 3.0)
	check(_bonus_rows(race).is_empty(), "finished players receive no further help")
	race = _fixture()
	race.track.K.fill(0.04)
	for c2: CarState in race.cars:
		if c2 != race.player:
			_move(race, c2, race.player.progress + 60.0)
	_advance(race, 0.25)
	check(_bonus_rows(race).is_empty(), "a missing boost must not force an immediate-nitro offer into a tight bend")


func _check_reverse_and_wrap() -> void:
	for reverse in [false, true]:
		var race := _fixture(37, reverse)
		_move(race, race.player, race.L - 80.0)
		for c: CarState in race.cars:
			if c != race.player:
				_move(race, c, race.player.progress + 400.0 + c.id * 70.0)
		for p: Dictionary in race.pickups:
			if not bool(p.get("adaptive", false)):
				p.s = race.track.mod_s(race.player.s + 900.0)
		_advance(race, 2.0)
		var rows := _bonus_rows(race)
		check(rows.size() == 1, "assistance works across an earlier lap seam in either direction")
		if rows.is_empty():
			continue
		var distance := race.track.mod_s(float(rows[0].items[0].s) - race.player.s)
		check(distance >= 190.0 and distance <= 200.1, "wrapped assistance is ahead in the selected direction")


func _check_determinism() -> void:
	var a := _fixture(91)
	var b := _fixture(91)
	var original := _fixture(91, false, false)
	check(a.rng.state == original.rng.state, "initial adaptive pool must not consume driving/combat RNG")
	var state_before := a.rng.state
	_advance(a, 3.0)
	_advance(b, 3.0)
	check(a.rng.state == state_before, "adaptive planning must not consume driving/combat RNG")
	check(JSON.stringify(a.pickup_director.snapshot()) == JSON.stringify(b.pickup_director.snapshot()), "same seed and inputs produce replayable adaptive decisions")
	var snapshot: Dictionary = a.pickup_director.snapshot()
	snapshot.counts.help_offers = -10
	check(int(a.pickup_director.counts.help_offers) >= 0, "diagnostic snapshots cannot mutate the director")
	check(original.pickup_director == null and original.pickups.size() == a.pickups.size() - 6, "adaptive pickups can be disabled for baseline comparisons")


func _check_visual_sync() -> void:
	var race := _fixture()
	var visual := PickupVisual.new()
	add_child(visual)
	visual.setup(race, race.track)
	var count_before := visual.get_child_count()
	var extra_index := -1
	for i in race.pickups.size():
		if bool(race.pickups[i].get("adaptive", false)):
			extra_index = i
			break
	check(extra_index >= 0 and not visual.items[extra_index].visible, "pooled assistance is initially hidden")
	_advance(race, 2.0)
	visual._process(0.1)
	check(visual.get_child_count() == count_before, "activating a help row adds no visual nodes")
	for i in race.pickups.size():
		var p: Dictionary = race.pickups[i]
		var node: Node3D = visual.items[i]
		if not bool(p.get("adaptive", false)) or not bool(p.get("active", true)):
			continue
		var badge := node.get_node("Symbol") as Sprite3D
		var material := (node.get_node("Pad") as MeshInstance3D).material_override as StandardMaterial3D
		check(node.visible and node.position.distance_to(race.track.pos(p.s, p.d)) < 0.001, "help symbol appears at its actual collectible position")
		check(badge.texture == PowerupIcons.texture(p.type), "displayed help icon matches the real shared item")
		check(material.albedo_color.is_equal_approx(Color.html(Data.PW[p.type].col)), "help pad color matches its actual item")
	var p: Dictionary = race.pickups[0]
	p.type = "repair"
	p.s = race.track.mod_s(p.s + 30.0)
	visual._process(0.1)
	check((visual.items[0].get_node("Symbol") as Sprite3D).texture == PowerupIcons.texture("repair"), "normal replan refreshes the advertised icon")
	check(visual.items[0].position.distance_to(race.track.pos(p.s, p.d)) < 0.001, "reused station movement updates the displayed position")
	p.alive = false
	visual._process(0.1)
	check(not visual.items[0].visible, "collecting a shared item hides its exact visual")
	visual.free()


func _check_distribution_and_history() -> void:
	var race := _fixture(177)
	var c := race.player
	c.v = 0.0 # Collect history without extra offers or their storm reservation.
	_advance(race, 3.0)
	c.v = 45.0
	var director := race.pickup_director
	var w: Dictionary = director.weights(race, c, c.s + 200.0)
	var draws := {"nitro": 0, "shock": 0}
	for i in 2000:
		var kind: String = director._pick(w)
		if draws.has(kind):
			draws[kind] += 1
	check(int(draws.nitro) > 2000 * 0.35, "seeded isolated-racer distribution supplies substantially more nitro than the 17% baseline")
	check(int(draws.shock) > 2000 * 0.10, "seeded far-behind distribution favors storm more than its 7% baseline")
	# Real hits and real item use feed the director, including failed-use rules.
	race.hit(c, race.cars[0], "bolt", 11.0, {"slow": 0.86})
	check(is_equal_approx(float(director.history[c.id].hit_t), race.time), "combat integration records actual hits")
	c.slots = [{"type": "nitro", "ammo": 1}]
	race.use_item(c, false)
	check(c.nitro_t > 0.0 and director.weights(race, c, c.s + 200.0).nitro == 0.0, "using nitro suppresses redundant boost supply")
	c.health = c.max_hp
	c.slots = [{"type": "repair", "ammo": 1}]
	race.use_item(c, false)
	check(not director.counts.used.has("repair"), "denied use is not counted as a successful benefit")
	for i in 100:
		director.note_pickup(c, "bolt", race.time, false)
		director._log({"event": "sample", "t": float(i)})
	check(director.decisions.size() == 64 and director.history[c.id].recent.size() == 3, "long races keep diagnostic and recent-item history bounded")


func _check_actual_tirana_race() -> void:
	var track := RaceTrack.load_city("tirane")
	var race := Race.new(track, {"seed": 221, "laps": 1, "diff": 1})
	race.started = true
	race.player.autopilot = true
	# A disadvantaged start exercises catch-up on the real production circuit.
	_move(race, race.player, -400.0)
	var steps := 0
	while not race.player.finished and steps < 36000:
		race.step(1.0 / 60.0)
		race.take_events()
		steps += 1
	check(race.player.finished, "adaptive pickups retain a completable real Tirana race")
	check(int(race.pickup_director.counts.help_offers) > 0, "actual Tirana geometry admits useful catch-up opportunities")
	check(int(race.pickup_director.counts.player_help_collected) > 0, "real player actually collects adaptive supply on the production track")
	check(race.pickups.size() <= 36, "a full production lap retains the fixed pickup budget")
	print("ADAPTIVE TIRANA: ", JSON.stringify(race.pickup_director.counts))
