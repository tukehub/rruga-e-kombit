extends Node
## Race announcer on the "Voice" bus (plan 4.3); the bus ducks the world and
## the music while it talks (see Sfx). say(key) asks for a line; lines queue
## by priority with a short gap between them, a stale line is dropped rather
## than said late, and chatty lines have a cooldown. Countdown and results
## lines (priority CUT_IN and up) interrupt anything lower.
##
## Lines live in assets/voice/<lang>/<key>.ogg (tools/build_voice.py). English
## ships first; an Albanian folder with the same keys needs no code change.
## A missing file is silence, never an error.

const BUS := "Voice"
const DIR := "res://assets/voice/"
const LANG := "en"
## Silence between two lines, in seconds.
const GAP := 0.25
## Lines waiting at most; the lowest priority falls off.
const QUEUE_MAX := 3
const CUT_IN := 5
## prio: higher goes first. ttl: seconds a queued line may wait before it is
## no longer true. cooldown: seconds before the same line may be said again.
const LINES := {
	"3": {"prio": 6, "ttl": 0.4, "cooldown": 0.0},
	"2": {"prio": 6, "ttl": 0.4, "cooldown": 0.0},
	"1": {"prio": 6, "ttl": 0.4, "cooldown": 0.0},
	"go": {"prio": 6, "ttl": 0.4, "cooldown": 0.0},
	"you_win": {"prio": 5, "ttl": 3.0, "cooldown": 0.0},
	"you_lose": {"prio": 5, "ttl": 3.0, "cooldown": 0.0},
	"congratulations": {"prio": 5, "ttl": 3.0, "cooldown": 0.0},
	"time_over": {"prio": 5, "ttl": 2.0, "cooldown": 0.0},
	"tie": {"prio": 5, "ttl": 3.0, "cooldown": 0.0},
	"final_lap": {"prio": 4, "ttl": 2.5, "cooldown": 10.0},
	"look_out": {"prio": 3, "ttl": 0.8, "cooldown": 5.0},
	"target_destroyed": {"prio": 3, "ttl": 1.5, "cooldown": 3.0},
	"new_record": {"prio": 2, "ttl": 5.0, "cooldown": 0.0},
	"hurry_up": {"prio": 2, "ttl": 3.0, "cooldown": 20.0},
}

var _player: AudioStreamPlayer
var _streams: Dictionary = {}
var _queue: Array = []          # [{key, prio, at}] highest priority first
var _said_at: Dictionary = {}   # key -> clock when last started
var _clock := 0.0
var _busy_until := 0.0          # clock when the current line and its gap end
var _current := ""
var _current_prio := -1
## False: the queue runs but nothing is played (tests, like Sfx.enabled).
var output := true
## Every line started, for tests: [key, clock].
var said: Array = []


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)


## The line for finishing a race in `place` of `field`.
static func finish_line(place: int, field: int) -> String:
	if place == 1:
		return "you_win"
	return "congratulations" if place <= mini(3, field - 1) else "you_lose"


## The line for the end of a points round: a shared top score is a tie.
## `order` is best first; anything with `score` works.
static func arena_line(player, order: Array) -> String:
	if order.is_empty():
		return ""
	var top := int(order[0].score)
	if int(player.score) == top:
		var level := order.filter(func(c) -> bool: return int(c.score) == top).size()
		return "tie" if level > 1 else "you_win"
	var place := order.find(player) + 1
	return "congratulations" if place >= 1 and place <= 3 else "you_lose"


func enabled() -> bool:
	return Settings.announcer


func stream(key: String) -> AudioStream:
	if not _streams.has(key):
		var path := DIR + LANG + "/" + key + ".ogg"
		_streams[key] = load(path) if ResourceLoader.exists(path) else null
	return _streams[key]


## The line being said, "" when quiet.
func current() -> String:
	return _current if _clock < _busy_until - GAP else ""


## Asks for a line. Returns false when it will not be said: announcer off,
## unknown key, no recording, still cooling down or already waiting.
func say(key: String) -> bool:
	if not enabled() or not LINES.has(key) or stream(key) == null:
		return false
	var line: Dictionary = LINES[key]
	if _said_at.has(key) and _clock - float(_said_at[key]) < float(line.cooldown):
		return false
	if _queue.any(func(q: Dictionary) -> bool: return q.key == key):
		return false
	var prio := int(line.prio)
	if prio >= CUT_IN and _clock < _busy_until and _current_prio < prio:
		_start(key)
		return true
	var at := _queue.size()
	for i in _queue.size():
		if int(_queue[i].prio) < prio:
			at = i
			break
	_queue.insert(at, {"key": key, "prio": prio, "at": _clock})
	if _queue.size() > QUEUE_MAX:
		_queue.pop_back()
	advance(0.0)
	return _queue.any(func(q: Dictionary) -> bool: return q.key == key) or _current == key


## Silence now and forget everything waiting (scene changes).
func clear() -> void:
	_queue.clear()
	_player.stop()
	_busy_until = _clock
	_current = ""
	_current_prio = -1


func _process(dt: float) -> void:
	advance(dt)


## One step of the queue; _process calls it with the frame time.
func advance(dt: float) -> void:
	_clock += dt
	if _clock >= _busy_until - GAP:
		_current_prio = -1
	_queue = _queue.filter(func(q: Dictionary) -> bool: return _clock - float(q.at) <= float(LINES[q.key].ttl))
	if _clock < _busy_until or _queue.is_empty() or not enabled():
		return
	_start(str(_queue.pop_front().key))


func _start(key: String) -> void:
	var s := stream(key)
	_player.stop()
	if output:
		_player.stream = s
		_player.play()
	_current = key
	_current_prio = int(LINES[key].prio)
	_said_at[key] = _clock
	_busy_until = _clock + s.get_length() + GAP
	said.append([key, _clock])


func _exit_tree() -> void:
	clear()
	_player.stream = null
	_streams.clear()
