class_name RaceTrack
extends RefCounted
## Centreline of a city loop: uniform arc-length samples with frames, curvature
## and elevation. Port of src/02_track.js minus the procedural terrain (the
## pipeline already baked elevation into track.json).

var id := ""
var name := ""
var half_w := 10.0
var sea_level := 0.0
var style := "asphalt"

var M := 0            # sample count
var L := 0.0          # true 3D length (m)
var ds := 2.0         # arc-length spacing (3D)
var ds_h := 2.0       # horizontal spacing used for curvature
var X := PackedFloat32Array()
var Y := PackedFloat32Array()
var Z := PackedFloat32Array()
var NX := PackedFloat32Array()   # left normal (x)
var NZ := PackedFloat32Array()   # left normal (z)
var HD := PackedFloat32Array()   # heading (rad), atan2(-tx, tz) like the original
var K := PackedFloat32Array()    # curvature (1/m), smoothed
var TX := PackedFloat32Array()
var TY := PackedFloat32Array()
var TZ := PackedFloat32Array()
var bbox := Rect2()
var centre := Vector2.ZERO

var _i0 := 0
var _i1 := 0
var _t := 0.0

const CELL := 30.0
var _grid := {}


static func load_city(city_id: String) -> RaceTrack:
	var path := "res://assets/cities/%s/track.json" % city_id
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("track.json missing for %s" % city_id)
		return null
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("track.json invalid for %s" % city_id)
		return null
	var t := RaceTrack.new()
	t.build(data)
	return t


func build(data: Dictionary) -> void:
	id = str(data.get("id", ""))
	name = str(data.get("name", id))
	half_w = float(data.get("hw", 10.0))
	sea_level = float(data.get("sea_level", 0.0))
	style = str(data.get("style", "asphalt"))
	var raw: Array = data["pts"]
	var pts: Array[Vector3] = []
	for p in raw:
		pts.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	_resample(pts)
	_frames()
	_grid_build()


# Closed Catmull-Rom through the control points, resampled to ~2 m arc length.
func _resample(pts: Array[Vector3]) -> void:
	var n := pts.size()
	var dense: Array[Vector3] = []
	var sub := 8
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for k in sub:
			var u := float(k) / sub
			dense.append(_catmull(p0, p1, p2, p3, u))
	# cumulative horizontal length
	var cum := PackedFloat32Array()
	cum.resize(dense.size() + 1)
	cum[0] = 0.0
	for i in dense.size():
		var a := dense[i]
		var b := dense[(i + 1) % dense.size()]
		cum[i + 1] = cum[i] + Vector2(b.x - a.x, b.z - a.z).length()
	var L0 := cum[dense.size()]
	M = int(round(L0 / 2.0))
	ds_h = L0 / M
	X.resize(M); Y.resize(M); Z.resize(M)
	var j := 0
	for i in M:
		var target := i * ds_h
		while j + 1 < cum.size() - 1 and cum[j + 1] <= target:
			j += 1
		var seg := cum[j + 1] - cum[j]
		var u := 0.0 if seg <= 1e-6 else (target - cum[j]) / seg
		var a := dense[j]
		var b := dense[(j + 1) % dense.size()]
		var p := a.lerp(b, u)
		X[i] = p.x; Y[i] = p.y; Z[i] = p.z


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func _frames() -> void:
	NX.resize(M); NZ.resize(M); HD.resize(M); K.resize(M)
	TX.resize(M); TY.resize(M); TZ.resize(M)
	var minx := INF; var maxx := -INF; var minz := INF; var maxz := -INF
	for i in M:
		var a := (i - 1 + M) % M
		var b := (i + 1) % M
		var tx := X[b] - X[a]
		var tz := Z[b] - Z[a]
		var l := sqrt(tx * tx + tz * tz)
		if l < 1e-9:
			l = 1.0
		tx /= l; tz /= l
		NX[i] = -tz; NZ[i] = tx
		HD[i] = atan2(-tx, tz)
		minx = minf(minx, X[i]); maxx = maxf(maxx, X[i]); minz = minf(minz, Z[i]); maxz = maxf(maxz, Z[i])
	bbox = Rect2(minx, minz, maxx - minx, maxz - minz)
	centre = Vector2((minx + maxx) * 0.5, (minz + maxz) * 0.5)
	var k0 := PackedFloat32Array()
	k0.resize(M)
	for i in M:
		var a := (i - 1 + M) % M
		var b := (i + 1) % M
		k0[i] = wrap_ang(HD[b] - HD[a]) / (2.0 * ds_h)
	for i in M:
		var s := 0.0
		for k in range(-3, 4):
			s += k0[(i + k + M) % M]
		K[i] = s / 7.0
	# 3D tangents and true length
	var len := 0.0
	for i in M:
		var b := (i + 1) % M
		var a := (i - 1 + M) % M
		len += Vector3(X[b] - X[i], Y[b] - Y[i], Z[b] - Z[i]).length()
		var t := Vector3(X[b] - X[a], Y[b] - Y[a], Z[b] - Z[a])
		var l := t.length()
		if l < 1e-9:
			l = 1.0
		TX[i] = t.x / l; TY[i] = t.y / l; TZ[i] = t.z / l
	L = len
	ds = L / M


func _grid_build() -> void:
	_grid.clear()
	for i in M:
		var key := _gkey(int(floor(X[i] / CELL)), int(floor(Z[i] / CELL)))
		if not _grid.has(key):
			_grid[key] = PackedInt32Array()
		var arr: PackedInt32Array = _grid[key]
		arr.append(i)
		_grid[key] = arr


static func _gkey(ix: int, iz: int) -> int:
	return (ix + 32768) * 65536 + (iz + 32768)


static func wrap_ang(a: float) -> float:
	return fposmod(a + PI, TAU) - PI


func mod_s(p: float) -> float:
	return fposmod(p, L)


func wrap_s(d: float) -> float:
	d = fmod(d, L)
	if d > L * 0.5:
		d -= L
	elif d < -L * 0.5:
		d += L
	return d


func locate(s: float) -> void:
	s = fposmod(s, L)
	var f := s / ds
	var fi := int(floor(f))
	_i0 = fi % M
	_i1 = (_i0 + 1) % M
	_t = f - fi


func pos(s: float, d: float) -> Vector3:
	locate(s)
	var nx := lerpf(NX[_i0], NX[_i1], _t)
	var nz := lerpf(NZ[_i0], NZ[_i1], _t)
	return Vector3(lerpf(X[_i0], X[_i1], _t) + nx * d, lerpf(Y[_i0], Y[_i1], _t), lerpf(Z[_i0], Z[_i1], _t) + nz * d)


func tangent(s: float) -> Vector3:
	locate(s)
	return Vector3(lerpf(TX[_i0], TX[_i1], _t), lerpf(TY[_i0], TY[_i1], _t), lerpf(TZ[_i0], TZ[_i1], _t)).normalized()


func normal(s: float) -> Vector3:
	locate(s)
	return Vector3(lerpf(NX[_i0], NX[_i1], _t), 0.0, lerpf(NZ[_i0], NZ[_i1], _t))


func curv(s: float) -> float:
	locate(s)
	return lerpf(K[_i0], K[_i1], _t)


func heading(s: float) -> float:
	locate(s)
	return HD[_i0] + wrap_ang(HD[_i1] - HD[_i0]) * _t


func height(s: float) -> float:
	locate(s)
	return lerpf(Y[_i0], Y[_i1], _t)


## Nearest sample index within max_r metres, or -1.
func nearest(x: float, z: float, max_r := 60.0) -> int:
	var R := int(ceil(max_r / CELL))
	var cx := int(floor(x / CELL))
	var cz := int(floor(z / CELL))
	var best := -1
	var bd := INF
	for ix in range(cx - R, cx + R + 1):
		for iz in range(cz - R, cz + R + 1):
			var key := _gkey(ix, iz)
			if not _grid.has(key):
				continue
			for i in _grid[key]:
				var dx := X[i] - x
				var dz := Z[i] - z
				var d2 := dx * dx + dz * dz
				if d2 < bd:
					bd = d2
					best = i
	return best


## Distance from (x,z) to the centreline (brute force fallback for far points).
func dist_to(x: float, z: float) -> float:
	var n := nearest(x, z, 90.0)
	if n >= 0:
		return Vector2(X[n] - x, Z[n] - z).length()
	var bd := INF
	for i in range(0, M, 2):
		var dx := X[i] - x
		var dz := Z[i] - z
		bd = minf(bd, dx * dx + dz * dz)
	return sqrt(bd)


## Project a world point to (s, d) track coordinates (approximate, uses nearest sample).
func locate_xz(x: float, z: float) -> Vector2:
	var i := nearest(x, z, 120.0)
	if i < 0:
		return Vector2(0.0, 0.0)
	var dx := x - X[i]
	var dz := z - Z[i]
	var tx := TX[i]
	var tz := TZ[i]
	var along := dx * tx + dz * tz
	var d := dx * NX[i] + dz * NZ[i]
	return Vector2(mod_s(i * ds + along), d)


func stats() -> Dictionary:
	var max_k := 0.0
	var miny := INF
	var maxy := -INF
	for i in M:
		max_k = maxf(max_k, absf(K[i]))
		miny = minf(miny, Y[i]); maxy = maxf(maxy, Y[i])
	return {"L": roundi(L), "M": M, "minR": roundi(1.0 / maxf(max_k, 1e-6)), "y": [miny, maxy]}
