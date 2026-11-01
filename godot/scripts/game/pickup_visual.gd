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
	for p in race.pickups:
		var station := Node3D.new()
		station.position = track.pos(float(p.s), float(p.d))
		add_child(station)
		var badge := Sprite3D.new()
		badge.name = "Symbol"
		badge.texture = PowerupIcons.texture(p.type)
		badge.pixel_size = 0.0086  # 2.2 m wide; compact enough to see the road around it.
		badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		badge.shaded = false
		badge.double_sided = true
		badge.position.y = 1.85
		badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		badge.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		badge.visibility_range_end = 155.0
		station.add_child(badge)
		var pad := MeshInstance3D.new()
		pad.mesh = _ring_shared()
		pad.material_override = _mat(p.type)
		pad.position.y = 0.10
		pad.scale.y = 0.35
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		pad.visibility_range_end = 110.0
		station.add_child(pad)
		items.append(station)


func _process(dt: float) -> void:
	if race == null:
		return
	_t += dt
	for i in items.size():
		var p: Dictionary = race.pickups[i]
		var station := items[i]
		station.visible = bool(p.alive)
		if not station.visible:
			continue
		var badge := station.get_node("Symbol") as Sprite3D
		badge.position.y = 1.85 + sin(_t * 2.0 + i) * 0.12
