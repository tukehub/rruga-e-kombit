extends RefCounted
## Static corner plan from the same forward track frames the car follows.
## Positive heading curvature is a driver's RIGHT turn (N=(-tz,tx)).

const MIN_CURVATURE := 0.004
const MIN_ANGLE := 0.25
const JOIN_GAP := 12.0
var turns: Array[Dictionary] = []
var length := 0.0

func _init(track: RaceTrack) -> void:
	length = track.L
	var groups: Array[Dictionary] = []
	var i := 0
	while i < track.M:
		if absf(track.K[i]) < MIN_CURVATURE:
			i += 1
			continue
		var first := i
		var last := i
		var peak := i
		var side := signf(track.K[i])
		var angle := 0.0
		while i < track.M:
			var k := float(track.K[i])
			if absf(k) >= MIN_CURVATURE:
				if signf(k) != side:
					break
				last = i
				angle += absf(k) * track.ds_h
				if absf(k) > absf(track.K[peak]):
					peak = i
			elif (i - last) * track.ds > JOIN_GAP:
				break
			i += 1
		groups.append({"first": first, "last": last, "peak": peak, "side": side, "angle": angle, "curvature": absf(track.K[peak])})
	# One corner can straddle the start line. Merge without changing the anchor
	# or emitting two conflicting advance signs at the lap seam.
	if groups.size() > 1:
		var first: Dictionary = groups[0]
		var last: Dictionary = groups[-1]
		if first.side == last.side and (int(first.first) + track.M - int(last.last)) * track.ds <= JOIN_GAP:
			var joined := last.duplicate()
			joined.last = int(first.last) + track.M
			joined.angle = float(first.angle) + float(last.angle)
			if float(first.curvature) > float(last.curvature):
				joined.peak = first.peak
				joined.curvature = first.curvature
			groups.pop_back()
			groups.pop_front()
			groups.append(joined)
	for group: Dictionary in groups:
		if float(group.angle) < MIN_ANGLE:
			continue
		var severity := 1
		if float(group.angle) >= 0.8 and float(group.curvature) >= 0.008:
			severity = 2
		if float(group.angle) >= 2.2 and float(group.curvature) >= 0.025:
			severity = 3
		turns.append({"start": track.mod_s(int(group.first) * track.ds), "end": track.mod_s((int(group.last) + 1) * track.ds),
			"span": (int(group.last) + 1 - int(group.first)) * track.ds, "apex": int(group.peak) * track.ds,
			"side": int(group.side), "direction": "right" if float(group.side) > 0 else "left",
			"severity": severity, "angle": float(group.angle), "radius": 1.0 / maxf(0.00001, float(group.curvature))})
	turns.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.start) < float(b.start))

func next(s: float, lookahead := 200.0) -> Dictionary:
	var best := {}
	var distance := lookahead
	for turn: Dictionary in turns:
		var into := fposmod(s - float(turn.start), length)
		var gap := fposmod(float(turn.start) - s, length)
		if into <= float(turn.span):
			gap = 0.0
		if gap <= distance:
			distance = gap
			best = turn.duplicate()
			best["distance"] = gap
	return best
