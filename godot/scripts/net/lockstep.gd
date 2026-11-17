class_name Lockstep
extends RefCounted
## Deterministic lockstep bookkeeping for one peer (plan 7.1/7.2). No sockets:
## the session feeds it received messages and sends what it puts in `outbox`.
##
## Every peer runs the whole simulation. Tick t may only be simulated once
## every human's input for t is known; local input is scheduled DELAY ticks
## ahead so it has time to reach the others (3 ticks = 50 ms at 60 Hz). If an
## input is late the race waits for it (a stall) instead of guessing. Every
## HASH_EVERY ticks each peer publishes its state hash; a mismatch is a desync.

const DELAY := 3
const HASH_EVERY := 30

var players := 1
var local := 0
## Next tick to simulate.
var tick := 0
## Messages to send, oldest first; the session drains it.
var outbox: Array[PackedByteArray] = []
## First tick whose hashes disagreed, -1 while in sync.
var desync_tick := -1
## Ticks a frame wanted to simulate but could not for want of input.
var stalls := 0
## Slots no longer playing -> first tick a bot drives their car (plan 7.4).
## The host picks that tick as the first one it has no input for, so every
## peer switches the car over on the same tick.
var gone: Dictionary = {}

var _inputs: Dictionary = {}   # tick -> Array (PackedByteArray or null) by slot
var _hashes: Dictionary = {}   # tick -> Dictionary slot -> hash
var _sent_until := -1          # last tick local input was scheduled for
var _last_input: Dictionary = {}  # slot -> last tick with its input


func _init(p_players: int, p_local: int) -> void:
	players = p_players
	local = p_local
	# The first DELAY ticks run on empty input for everyone.
	var empty := CarState.Ctrl.new().pack([])
	for t in DELAY:
		for p in players:
			_set_input(t, p, empty)
	_sent_until = DELAY - 1


## Schedules this peer's input for tick + DELAY (once per tick).
func submit(ctrl: PackedByteArray) -> void:
	var target := tick + DELAY
	if target <= _sent_until:
		return
	_sent_until = target
	_set_input(target, local, ctrl)
	outbox.append(NetProto.input(local, target, ctrl))


## A decoded INPUT or HASH from another peer.
func receive(msg: Dictionary) -> void:
	var slot := int(msg.get("slot", -1))
	if slot < 0 or slot >= players or slot == local:
		return
	match int(msg.get("type", 0)):
		NetProto.INPUT:
			if int(msg.tick) >= tick:
				_set_input(int(msg.tick), slot, msg.ctrl)
		NetProto.HASH:
			_note_hash(int(msg.tick), slot, int(msg.hash))


## True when tick `tick` has every playing slot's input.
func can_step() -> bool:
	var row: Array = _inputs.get(tick, [])
	if row.is_empty():
		return false
	for p in players:
		if row[p] == null and not is_bot(p, tick):
			return false
	return true


## True when slot `p`'s car is driven by a bot on tick `t`.
func is_bot(p: int, t: int) -> bool:
	return gone.has(p) and t >= int(gone[p])


## The first tick slot `p` has sent no input for.
func first_missing(p: int) -> int:
	return int(_last_input.get(p, DELAY - 1)) + 1


## The inputs for the current tick by slot (null for a slot that is gone),
## and moves on. Call only after can_step().
func take() -> Array:
	var row: Array = _inputs[tick]
	_inputs.erase(tick)
	tick += 1
	return row


## True when the tick just simulated must be hashed and published.
func wants_hash() -> bool:
	return (tick - 1) % HASH_EVERY == 0


## Call after simulating a tick that wants_hash(), with its state_hash().
func after_step(state_hash: int) -> void:
	var done := tick - 1
	outbox.append(NetProto.hash_msg(local, done, state_hash))
	_note_hash(done, local, state_hash)


## Slot `slot` dropped out; from tick `from_tick` a bot drives its car and
## its input is no longer waited for.
func drop(slot: int, from_tick: int) -> void:
	gone[slot] = from_tick


func _set_input(t: int, slot: int, ctrl: PackedByteArray) -> void:
	if not _inputs.has(t):
		var row := []
		row.resize(players)
		_inputs[t] = row
	_inputs[t][slot] = ctrl
	_last_input[slot] = maxi(int(_last_input.get(slot, -1)), t)


func _note_hash(t: int, slot: int, value: int) -> void:
	var row: Dictionary = _hashes.get(t, {})
	row[slot] = value
	_hashes[t] = row
	for other in row.values():
		if other != value and (desync_tick < 0 or t < desync_tick):
			desync_tick = t
	# Hashes everyone has reported are settled; forget them.
	if row.size() >= players - gone.size():
		_hashes.erase(t)
