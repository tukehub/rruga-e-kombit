class_name PickupVisual
extends Node3D
## Legacy-style floating badges: readable eagle/lightning/etc silhouettes, a
## slim colored pad, and no solid crates hiding the lane. The badge faces the
## camera so its symbol remains legible while approaching or overtaking it.

static var _ring: TorusMesh
static var _mats: Dictionary = {}

var race: Race
var track: RaceTrack
var items: Array[Node3D] = []
var _bindings: Array[Dictionary] = []
var _by_id: Dictionary = {}
var _t := 0.0


static func _ring_shared() -> TorusMesh:
	if _ring == null:
		_ring = TorusMesh.new()
		_ring.inner_radius = 0.82
		_ring.outer_radius = 0.95
		_ring.rings = 24
		_ring.ring_segments = 6
	return _ring


static func _mat(type: String) -> StandardMaterial3D:
	if _mats.has(type):
		return _mats[type]
	var col := Color.html(Data.PW[type].col)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[type] = m
	return m


func setup(p_race: Race, p_track: RaceTrack) -> void:
	race = p_race
	track = p_track
	_sync_items()
	_process(0.0)


func _sync_items() -> void:
	var live := {}
	items.clear()
	_bindings.clear()
	for p in race.pickups:
		live[p.id] = true
		if not _by_id.has(p.id):
			_by_id[p.id] = _make_item(int(p.id))
		var binding: Dictionary = _by_id[p.id]
		items.append(binding.root)
		_bindings.append(binding)
	for id in _by_id.keys():
		if not live.has(id):
			(_by_id[id].root as Node3D).queue_free()
			_by_id.erase(id)


func _make_item(id: int) -> Dictionary:
	var station := Node3D.new()
	station.name = "Pickup%d" % id
	station.visible = false
	add_child(station)
	var badge := Sprite3D.new()
	badge.name = "Symbol"
	badge.pixel_size = 0.0086 # 2.2 m wide; the road remains visible around it.
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.shaded = false
	badge.double_sided = true
	badge.position.y = 1.85
	badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	badge.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	badge.visibility_range_end = 155.0
	station.add_child(badge)
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = _ring_shared()
	pad.position.y = 0.10
	pad.scale.y = 0.35
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	pad.visibility_range_end = 110.0
	station.add_child(pad)
	return {"id": id, "root": station, "badge": badge, "pad": pad,
		"kind": "", "s": INF, "d": INF}


func _process(dt: float) -> void:
	if race == null:
		return
	if items.size() != race.pickups.size():
		_sync_items()
	else:
		for i in _bindings.size():
			if int(_bindings[i].id) != int(race.pickups[i].id):
				_sync_items()
				break
	_t += dt
	for i in items.size():
		var p: Dictionary = race.pickups[i]
		var binding: Dictionary = _bindings[i]
		var station: Node3D = binding.root
		station.visible = bool(p.alive) and bool(p.get("active", true))
		if not station.visible:
			continue
		var badge: Sprite3D = binding.badge
		if binding.kind != p.type:
			badge.texture = PowerupIcons.texture(p.type)
			(binding.pad as MeshInstance3D).material_override = _mat(p.type)
			binding.kind = p.type
		if float(binding.s) != float(p.s) or float(binding.d) != float(p.d):
			station.position = track.pos(float(p.s), float(p.d))
			binding.s = p.s
			binding.d = p.d
		badge.position.y = 1.85 + sin(_t * 2.0 + i) * 0.12
