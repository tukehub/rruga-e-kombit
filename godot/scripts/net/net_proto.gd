class_name NetProto
extends RefCounted
## The wire format for online races (plan 7.2). Every message starts with a
## type byte. Inputs and hashes are fixed-size binary; lobby and start data
## are small dictionaries of plain values (var_to_bytes never decodes objects).

const HELLO := 1     # client -> host: name, game version
const WELCOME := 2   # host -> client: your slot
const LOBBY := 3     # host -> all: [names] by slot
const START := 4     # host -> all: race config (seed, laps, humans, ...)
const INPUT := 5     # anyone -> host -> others: slot, tick, 4 input bytes
const HASH := 6      # anyone -> host -> others: slot, tick, state hash
const LEAVE := 7     # host -> all: slot that dropped, first tick a bot drives it
const REFUSE := 8    # host -> client: why (full, started, version)

## Bump when the simulation or this format changes: peers must match.
const VERSION := 1


static func hello(name: String, car := "") -> PackedByteArray:
	return _dict(HELLO, {"name": name, "car": car, "version": VERSION})


static func welcome(slot: int) -> PackedByteArray:
	return PackedByteArray([WELCOME, slot])


static func lobby(names: Array, cars: Array = []) -> PackedByteArray:
	return _dict(LOBBY, {"names": names, "cars": cars})


static func start(config: Dictionary) -> PackedByteArray:
	return _dict(START, config)


static func leave(slot: int, from_tick: int) -> PackedByteArray:
	var b := PackedByteArray([LEAVE, slot, 0, 0, 0, 0])
	b.encode_u32(2, from_tick)
	return b


static func refuse(why: String) -> PackedByteArray:
	return _dict(REFUSE, {"why": why})


static func input(slot: int, tick: int, ctrl: PackedByteArray) -> PackedByteArray:
	var b := PackedByteArray([INPUT, slot, 0, 0, 0, 0])
	b.encode_u32(2, tick)
	b.append_array(ctrl)
	return b


static func hash_msg(slot: int, tick: int, value: int) -> PackedByteArray:
	var b := PackedByteArray([HASH, slot])
	b.resize(14)
	b.encode_u32(2, tick)
	b.encode_s64(6, value)
	return b


## {type, ...fields}; {} for anything malformed.
static func decode(b: PackedByteArray) -> Dictionary:
	if b.is_empty():
		return {}
	var type := b[0]
	match type:
		WELCOME:
			return {"type": type, "slot": b[1]} if b.size() == 2 else {}
		LEAVE:
			return {"type": type, "slot": b[1], "tick": b.decode_u32(2)} if b.size() == 6 else {}
		INPUT:
			if b.size() != 10:
				return {}
			return {"type": type, "slot": b[1], "tick": b.decode_u32(2), "ctrl": b.slice(6)}
		HASH:
			if b.size() != 14:
				return {}
			return {"type": type, "slot": b[1], "tick": b.decode_u32(2), "hash": b.decode_s64(6)}
		HELLO, LOBBY, START, REFUSE:
			var v = bytes_to_var(b.slice(1))
			if not (v is Dictionary):
				return {}
			var d: Dictionary = v
			d["type"] = type
			return d
	return {}


static func _dict(type: int, d: Dictionary) -> PackedByteArray:
	var b := PackedByteArray([type])
	b.append_array(var_to_bytes(d))
	return b
