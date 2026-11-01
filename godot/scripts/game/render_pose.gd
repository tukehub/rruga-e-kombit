extends RefCounted
## Render between fixed simulation steps without modifying the simulation itself.

static func capture(c: CarState) -> Dictionary:
	return {"progress": c.progress, "s": c.s, "d": c.d, "yaw": c.yaw,
		"hop": c.hop, "wreck_t": c.wreck_t}


static func sample(previous: Dictionary, c: CarState, alpha: float, length: float) -> Dictionary:
	# Do not draw a path across the track when a car is reset or teleported.
	if previous.is_empty() or (float(previous.wreck_t) > 0.0 and c.wreck_t <= 0.0) \
			or absf(c.progress - float(previous.progress)) > 10.0 \
			or absf(c.d - float(previous.d)) > 10.0:
		return capture(c)
	var a := clampf(alpha, 0.0, 1.0)
	return {
		"s": fposmod(lerpf(float(previous.progress), c.progress, a), length),
		"d": lerpf(float(previous.d), c.d, a),
		"yaw": lerp_angle(float(previous.yaw), c.yaw, a),
		"hop": lerpf(float(previous.hop), c.hop, a),
	}
