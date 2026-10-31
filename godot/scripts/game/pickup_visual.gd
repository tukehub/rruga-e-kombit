class_name PickupVisual
extends Node3D
## Floating, spinning power-up crates along the track. One MeshInstance3D per
## pickup station lane; shared mesh + one emissive material per power-up type.

static var _mesh: Mesh
static var _mats: Dictionary = {}

var race: Race
var track: RaceTrack
var items: Array[MeshInstance3D] = []
var _t := 0.0


static func _mesh_shared() -> Mesh:
	if _mesh == null:
		var m := BoxMesh.new()
		m.size = Vector3(1.3, 1.3, 1.3)
		_mesh = m
	return _mesh


static func _mat(type: String) -> StandardMaterial3D:
	if _mats.has(type):
		return _mats[type]
	var col := Color.html(Data.PW[type].col)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 2.2
	m.metallic = 0.2
	m.roughness = 0.25
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[type] = m
	return m


func setup(p_race: Race, p_track: RaceTrack) -> void:
	race = p_race
	track = p_track
	for p in race.pickups:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh_shared()
		mi.material_override = _mat(p.type)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var pos := track.pos(float(p.s), float(p.d))
		pos.y += 1.3
		mi.position = pos
		add_child(mi)
		items.append(mi)


func _process(dt: float) -> void:
	if race == null:
		return
	_t += dt
	for i in items.size():
		var p: Dictionary = race.pickups[i]
		var mi := items[i]
		mi.visible = bool(p.alive)
		if not mi.visible:
			continue
		var pos := mi.position
		mi.position.y = track.height(float(p.s)) + 1.3 + sin(_t * 2.0 + i) * 0.15
		mi.rotation = Vector3(0.6, _t * 1.3 + i, 0.5)
		mi.position.x = pos.x
		mi.position.z = pos.z
