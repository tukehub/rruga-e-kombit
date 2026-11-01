extends Node
## Sound effects mixer. Buses: Master > Engine / Tyres / Impacts / Pickups / UI.
## No music by design.

const DIR := "res://assets/sfx/"
const BUSES := ["Engine", "Tyres", "Impacts", "Pickups", "UI"]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _players3d: Array[AudioStreamPlayer3D] = []
var _loop_players: Dictionary = {}   # name -> AudioStreamPlayer
var _pool_i := 0
var _pool3d_i := 0
var listener_pos := Vector3.ZERO
var enabled := true


func _ready() -> void:
	_setup_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "Impacts"
		add_child(p)
		_players.append(p)
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Impacts"
		p.max_distance = 140.0
		p.unit_size = 12.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players3d.append(p)
	apply_volumes()
	Settings.changed.connect(apply_volumes)


func _setup_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_vol("Master", Settings.vol_master)
	_set_vol("Engine", Settings.vol_engine)
	_set_vol("Tyres", Settings.vol_tyres)
	_set_vol("Impacts", Settings.vol_impacts)
	_set_vol("Pickups", Settings.vol_pickups)
	_set_vol("UI", Settings.vol_ui)


func _set_vol(bus: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(idx, v <= 0.001)


func stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := DIR + name + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = s
	return s


## Non-positional one shot.
func play(name: String, bus := "Impacts", vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var s := stream(name)
	if s == null:
		return
	var p := _players[_pool_i]
	_pool_i = (_pool_i + 1) % _players.size()
	p.stop()
	p.stream = s
	p.bus = bus
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


## Positional one shot (world position). Falls back to 2D when close to listener.
func play_at(name: String, pos: Vector3, bus := "Impacts", vol_db := 0.0, pitch := 1.0) -> void:
	if not enabled:
		return
	var s := stream(name)
	if s == null:
		return
	var p := _players3d[_pool3d_i]
	_pool3d_i = (_pool3d_i + 1) % _players3d.size()
	p.stop()
	p.stream = s
	p.bus = bus
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.global_position = pos
	p.play()


## Persistent loop (engine, tyres, wind, rain). Returns the player for live control.
func loop(name: String, bus: String) -> AudioStreamPlayer:
	if _loop_players.has(name):
		return _loop_players[name]
	var p := AudioStreamPlayer.new()
	p.stream = stream(name)
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	_loop_players[name] = p
	return p


func set_loop(name: String, bus: String, vol: float, pitch := 1.0) -> void:
	var p := loop(name, bus)
	if p.stream == null:
		return
	if vol <= 0.002:
		if p.playing:
			p.stop()
		return
	p.volume_db = linear_to_db(clampf(vol, 0.0, 1.5))
	p.pitch_scale = clampf(pitch, 0.1, 4.0)
	if not p.playing:
		p.play()


func stop_loops() -> void:
	for k in _loop_players:
		_loop_players[k].stop()


func ui_click() -> void:
	play("ui_click", "UI", -6.0)


func ui_back() -> void:
	play("ui_back", "UI", -6.0)


func haptic(ms: int) -> void:
	if Settings.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func stop_all() -> void:
	stop_loops()
	for p in _players:
		p.stop()
		p.stream = null
	for p in _players3d:
		p.stop()
		p.stream = null


func _exit_tree() -> void:
	stop_all()
	for p in _loop_players.values():
		p.stream = null
	_streams.clear()
