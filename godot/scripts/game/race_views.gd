class_name RaceViews
extends Node
## Rear camera renders at a deliberately small size and capped rate. The mirror
## can be switched off during a race to recover performance on slower devices.

const PLAYER_LAYER := 2
# One secondary pass every three displayed frames gives even pacing and cuts
# its work relative to the old alternating two/three-frame 24 Hz schedule.
const MIRROR_FRAME_INTERVAL := 3

var race_camera: ChaseCam
var rear: Camera3D
var viewport: SubViewport
var mirror: TextureRect
var mirror_panel: Panel
var view_button: Button
var mirror_button: Button
var cabin_overlay: Control
var enabled := false
## The new camera's name, for a brief note on screen.
signal view_changed(label: String)
var _mirror_frames := MIRROR_FRAME_INTERVAL - 1
const CAMERA_ICON := preload("res://assets/ui/icons/camera.svg")
## The camera button: square, left of the pause button, above the map.
const VIEW_BUTTON_SIZE := 48.0


class CabinOverlay extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var rim := Color(0.035, 0.045, 0.06, 0.88)
		draw_colored_polygon(PackedVector2Array([Vector2(0, h - 46), Vector2(w * 0.28, h - 24), Vector2(w * 0.4, h), Vector2(0, h)]), rim)
		draw_colored_polygon(PackedVector2Array([Vector2(w, h - 46), Vector2(w * 0.72, h - 24), Vector2(w * 0.6, h), Vector2(w, h)]), rim)
		draw_arc(Vector2(w * 0.34, h + 36), 80, PI, TAU, 40, Color(0.035, 0.045, 0.06, 0.9), 15, true)


func setup(cam: ChaseCam, player_visual: CarVisual, layer: Node) -> void:
	race_camera = cam
	enabled = Settings.mirror
	_set_player_layer(player_visual)
	viewport = SubViewport.new()
	viewport.name = "RearViewViewport"
	viewport.size = Vector2i(256, 64)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.positional_shadow_atlas_size = 0
	add_child(viewport)
	viewport.world_3d = get_viewport().world_3d
	rear = Camera3D.new()
	rear.name = "RearViewCamera"
	rear.near = 0.4
	rear.far = 180.0
	rear.keep_aspect = Camera3D.KEEP_WIDTH
	rear.fov = 90.0
	rear.set_cull_mask_value(PLAYER_LAYER, false)
	viewport.add_child(rear)
	rear.current = true
	cabin_overlay = CabinOverlay.new()
	cabin_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cabin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabin_overlay.visible = false
	layer.add_child(cabin_overlay)
	mirror_panel = Panel.new()
	mirror_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	mirror_panel.offset_left = -164
	mirror_panel.offset_right = 164
	mirror_panel.offset_top = 8
	mirror_panel.offset_bottom = 88
	mirror_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark glass with rounded corners; the picture is clipped to them.
	mirror_panel.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.03, 0.04, 0.05, 0.85), Color(0.0, 0.0, 0.0, 0.7), 12, 2))
	mirror_panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mirror_panel.visible = enabled
	layer.add_child(mirror_panel)
	mirror = TextureRect.new()
	mirror.position = Vector2(3, 3)
	mirror.size = Vector2(322, 74)
	mirror.texture = viewport.get_texture()
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_SCALE
	mirror.flip_h = true
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror_panel.add_child(mirror)
	# A thin light rim drawn over the picture, like the edge of a glass.
	var rim := Panel.new()
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rim.add_theme_stylebox_override("panel", UiTheme.flat(Color.TRANSPARENT, Color(1, 1, 1, 0.18), 12, 1))
	mirror_panel.add_child(rim)
	view_button = _icon_button(layer)
	view_button.pressed.connect(_toggle_view)
	view_button.tooltip_text = Data.t("view.camera.chase")
	# The mirror switch lives in the pause menu, which adopts this button.
	mirror_button = UiTheme.button(Data.t("view.mirror.on") if enabled else Data.t("view.mirror.off"))
	mirror_button.name = "MirrorToggle"
	mirror_button.pressed.connect(_toggle_mirror)
	Quality.budget_changed.connect(_apply_budget)
	_apply_budget()


func _apply_budget() -> void:
	var width := int(Quality.p.mirror_width)
	viewport.size = Vector2i(width, width / 4)
	_mirror_frames = int(Quality.p.mirror_interval) - 1


func _icon_button(layer: Node) -> Button:
	var b := Button.new()
	b.name = "CameraButton"
	b.icon = CAMERA_ICON
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.focus_mode = Control.FOCUS_NONE
	var st := UiTheme.flat(Color(0.02, 0.04, 0.07, 0.8), Color(1, 1, 1, 0.65), 12)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		st.set_content_margin(side, 10)
	b.add_theme_stylebox_override("normal", st)
	var on := st.duplicate() as StyleBoxFlat
	on.border_color = UiTheme.CYAN
	b.add_theme_stylebox_override("hover", on)
	b.add_theme_stylebox_override("pressed", on)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# The pause button spans -76..-16 from the right, 12..64 from the top.
	b.offset_right = -88
	b.offset_left = b.offset_right - VIEW_BUTTON_SIZE
	b.offset_top = 14
	b.offset_bottom = 14 + VIEW_BUTTON_SIZE
	layer.add_child(b)
	return b


func _set_player_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = 1 << (PLAYER_LAYER - 1)
	for child in node.get_children():
		_set_player_layer(child)


## Chase shows the car; cabin and bumper hide it from the race camera, and only
## the cabin draws the dashboard.
func set_view(view: ChaseCam.View) -> void:
	race_camera.view = view
	race_camera.set_cull_mask_value(PLAYER_LAYER, not race_camera.first_person())
	cabin_overlay.visible = view == ChaseCam.View.CABIN
	match view:
		ChaseCam.View.CABIN:
			view_button.tooltip_text = Data.t("view.camera.cabin")
		ChaseCam.View.BUMPER:
			view_button.tooltip_text = Data.t("view.camera.bumper")
		_:
			view_button.tooltip_text = Data.t("view.camera.chase")
	view_changed.emit(view_button.tooltip_text)
	race_camera._snap = true


func _toggle_view() -> void:
	set_view(((race_camera.view + 1) % ChaseCam.View.size()) as ChaseCam.View)
	Sfx.ui_click()


func _toggle_mirror() -> void:
	enabled = not enabled
	Settings.mirror = enabled
	Settings.save()
	mirror_panel.visible = enabled
	mirror_button.text = Data.t("view.mirror.on") if enabled else Data.t("view.mirror.off")
	if not enabled:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		_mirror_frames = int(Quality.p.mirror_interval) - 1
	Sfx.ui_click()


func update_pose(c: CarState, pose: Dictionary, _dt: float) -> void:
	if not enabled:
		return
	var s := float(pose.get("s", c.s))
	var d := float(pose.get("d", c.d))
	var yaw := float(pose.get("yaw", c.yaw))
	var p := race_camera.track.pos(s, d)
	p.y += 1.6 + float(pose.get("hop", c.hop))
	var psi := race_camera.track.heading(s) + yaw
	var tangent := race_camera.track.tangent(s)
	var backwards := Vector3(sin(psi), -tangent.y, -cos(psi)).normalized()
	rear.global_position = p
	rear.look_at(p + backwards * 30.0, Vector3.UP)
	_mirror_frames += 1
	if _mirror_frames >= int(Quality.p.mirror_interval):
		_mirror_frames = 0
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
