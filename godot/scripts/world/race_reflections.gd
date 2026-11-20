extends Node3D
## Spaced UPDATE_ONCE captures, never six scene passes every racing frame.
## Layer 20 contains only static scenery, excluding cars, pickups and effects.

const SCENERY_MASK := 1 << 19
const LANDMARK_IDS := ["national_museum", "pyramid", "polytechnic"]
var player_probe: ReflectionProbe
var landmarks: Array[ReflectionProbe] = []
var _dirty: Array[bool] = []
var _player_dirty := true
var _placed := false
var _clock := 0.0
var _landmark_clock := 0.0
var captures := 0

static func include_scenery(root: Node) -> void:
	if root == null:
		return
	if root is GeometryInstance3D:
		root.layers |= SCENERY_MASK
	for child in root.get_children():
		include_scenery(child)

static func make_probe() -> ReflectionProbe:
	var probe := ReflectionProbe.new()
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.cull_mask = SCENERY_MASK
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	probe.enable_shadows = false
	probe.mesh_lod_threshold = 4.0
	probe.max_distance = 120.0
	probe.size = Vector3(160, 64, 160)
	probe.blend_distance = 18.0
	probe.intensity = 1.0
	probe.visible = false
	return probe

func setup(track: RaceTrack, anchors: Array) -> void:
	player_probe = make_probe()
	player_probe.name = "PlayerReflection"
	add_child(player_probe)
	for id in LANDMARK_IDS:
		for anchor: Dictionary in anchors:
			if str(anchor.id) != id:
				continue
			# Capture from the street facing the landmark, never inside its mesh.
			var index := track.nearest(float(anchor.x), float(anchor.z), 180.0)
			if index < 0:
				continue
			var probe := make_probe()
			probe.name = id
			probe.position = Vector3(track.X[index], track.Y[index] + 3.0, track.Z[index])
			probe.size = Vector3(120, 64, 120)
			add_child(probe)
			landmarks.append(probe)
			_dirty.append(true)
			break
	Quality.budget_changed.connect(_apply_budget)
	_apply_budget()

func _apply_budget() -> void:
	player_probe.visible = bool(Quality.p.probe) and _placed
	for i in landmarks.size():
		landmarks[i].visible = i < int(Quality.p.landmark_probes)
	invalidate()

func invalidate() -> void:
	_player_dirty = true
	for i in _dirty.size():
		_dirty[i] = true

func reset() -> void:
	_placed = false
	_clock = 0.0
	_landmark_clock = 0.0
	player_probe.hide()
	invalidate()

func follow(position: Vector3, dt: float) -> void:
	if not bool(Quality.p.probe):
		return
	_clock += maxf(dt, 0.0)
	_landmark_clock += maxf(dt, 0.0)
	var target := position + Vector3(0, 2.0, 0)
	var distance := player_probe.global_position.distance_to(target)
	# Emergency repositioning handles teleports and keeps the player inside
	# the volume even after a long frame. Ordinary motion is rate limited.
	if not _placed or distance > 65.0 or (_clock >= float(Quality.p.probe_interval) and (_player_dirty or distance >= 18.0)):
		player_probe.global_position = target
		_refresh(player_probe)
		player_probe.show()
		_player_dirty = false
		_placed = true
		_clock = 0.0
	if _landmark_clock >= 0.75:
		for i in landmarks.size():
			if landmarks[i].visible and _dirty[i]:
				_refresh(landmarks[i])
				_dirty[i] = false
				_landmark_clock = 0.0
				break

func _refresh(probe: ReflectionProbe) -> void:
	# UPDATE_ONCE responds to transform changes, not sky/material changes.
	# Alternate a millimetre offset without drifting away from the anchor.
	var offset := -0.001 if probe.has_meta("nudged") and probe.get_meta("nudged") else 0.001
	probe.position.y += offset
	probe.set_meta("nudged", offset > 0.0)
	captures += 1
