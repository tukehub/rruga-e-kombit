extends Node
## Music on its own "Music" bus (Sfx creates the buses; Settings.vol_music
## sets its level). Two players, so one track fades out while the next fades
## in, and duck() to pull the music down under a loud moment.
## No tracks ship yet: plan 4.1 adds them under DIR and calls play().

const BUS := "Music"
const DIR := "res://assets/music/"
const FADE := 1.5
## Seconds for a duck to bite and to let go, over the full range.
const DUCK_ATTACK := 0.1
const DUCK_RELEASE := 0.8

var _players: Array[AudioStreamPlayer] = []
## Fade position of each player, 0 (silent) to 1 (full); the gain follows a
## quarter sine so two crossing tracks keep a constant loudness.
var _level: Array[float] = [0.0, 0.0]
var _active := 0
var _track := ""
var _fade := FADE
var _duck := 1.0
var _duck_floor := 1.0
var _duck_hold := 0.0


func _ready() -> void:
	# Music keeps playing behind the pause menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)


## The track that is playing or fading in; "" when the music is off.
func current() -> String:
	return _track


## Fades to assets/music/<track>.ogg. "" fades to silence. A track that does
## not exist also fades to silence and returns false.
func play(track: String, fade := FADE) -> bool:
	if track.is_empty():
		stop(fade)
		return true
	var path := DIR + track + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("No music track: " + path)
		stop(fade)
		return false
	play_stream(load(path), track, fade)
	return true


## Fades to a stream under a name. Asking for the track that is already
## playing changes nothing, so scenes can call this freely.
func play_stream(stream: AudioStream, track: String, fade := FADE) -> void:
	if stream == null or track.is_empty():
		stop(fade)
		return
	if track == _track:
		return
	_track = track
	_fade = fade
	_active = 1 - _active
	_level[_active] = 0.0
	var player := _players[_active]
	player.stream = stream
	player.play()
	advance(0.0)


func stop(fade := FADE) -> void:
	_track = ""
	_fade = fade
	advance(0.0)


## Pulls the music down to `amount` of its level (0..1) for `seconds`, then
## lets it rise again. Overlapping calls keep the lower level and longer hold.
func duck(amount := 0.35, seconds := 1.2) -> void:
	var wanted := clampf(amount, 0.0, 1.0)
	_duck_floor = minf(_duck_floor, wanted) if _duck_hold > 0.0 else wanted
	_duck_hold = maxf(_duck_hold, seconds)


func _process(dt: float) -> void:
	advance(dt)


## One step of the fades; _process calls it with the frame time.
func advance(dt: float) -> void:
	if _duck_hold > 0.0:
		_duck_hold -= dt
		_duck = move_toward(_duck, _duck_floor, dt / DUCK_ATTACK)
	else:
		_duck = move_toward(_duck, 1.0, dt / DUCK_RELEASE)
	for i in _players.size():
		var player := _players[i]
		var wanted := 1.0 if i == _active and not _track.is_empty() else 0.0
		_level[i] = wanted if _fade <= 0.0 else move_toward(_level[i], wanted, dt / _fade)
		if wanted == 0.0 and _level[i] <= 0.0 and player.stream != null:
			player.stop()
			player.stream = null
		player.volume_db = linear_to_db(maxf(sin(_level[i] * PI * 0.5) * _duck, 0.0001))
