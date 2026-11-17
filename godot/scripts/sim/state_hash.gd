class_name StateHash
extends RefCounted
## A 64-bit digest of simulation state for lockstep desync checks (plan 7.1).
## Peers running the same inputs must produce the same hash every tick; the
## first tick where they differ is where the simulations parted.
##
## Every script variable of an object is written in declaration order, so a
## field added later is covered without touching this file. Cars and other
## objects that carry an `id` are written as that id when they are only
## referenced (inside an event, a projectile's owner), never expanded twice.
## Dictionaries keep insertion order, which GDScript makes deterministic.


## Hash of `obj`'s script variables, leaving out the names in `skip`.
static func of_object(obj: Object, skip: Array = []) -> int:
	var buf := StreamPeerBuffer.new()
	expand(buf, obj, skip)
	return digest(buf)


static func digest(buf: StreamPeerBuffer) -> int:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf.data_array)
	return ctx.finish().decode_s64(0)


## Writes an object's own state: script variables, or a generator's state.
static func expand(buf: StreamPeerBuffer, obj: Object, skip: Array = []) -> void:
	if obj == null:
		buf.put_u8(0)
		return
	if obj is RandomNumberGenerator:
		buf.put_u64((obj as RandomNumberGenerator).seed)
		buf.put_u64((obj as RandomNumberGenerator).state)
		return
	for p in obj.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or str(p.name) in skip:
			continue
		var value = obj.get(p.name)
		if value is Object and not ("id" in value):
			expand(buf, value)
		else:
			write(buf, value)


## Writes a value; objects with an `id` are written as a reference.
static func write(buf: StreamPeerBuffer, value) -> void:
	match typeof(value):
		TYPE_NIL:
			buf.put_u8(0)
		TYPE_BOOL:
			buf.put_u8(2 if value else 1)
		TYPE_INT:
			buf.put_64(value)
		TYPE_FLOAT:
			buf.put_double(value)
		TYPE_STRING, TYPE_STRING_NAME:
			buf.put_utf8_string(str(value))
		TYPE_VECTOR2:
			buf.put_double(value.x)
			buf.put_double(value.y)
		TYPE_VECTOR3:
			buf.put_double(value.x)
			buf.put_double(value.y)
			buf.put_double(value.z)
		TYPE_COLOR:
			for ch in [value.r, value.g, value.b, value.a]:
				buf.put_double(ch)
		TYPE_DICTIONARY:
			buf.put_u32(value.size())
			for k in value:
				write(buf, k)
				write(buf, value[k])
		TYPE_OBJECT:
			if value == null:
				buf.put_u8(0)
			elif "id" in value:
				buf.put_64(int(value.id))
			else:
				expand(buf, value)
		_:
			if value is Array or typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
				buf.put_u32(value.size())
				for v in value:
					write(buf, v)
			else:
				buf.put_utf8_string(var_to_str(value))
