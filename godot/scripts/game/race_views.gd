class_name RaceViews
extends Node
## Rear camera renders at a deliberately small size and capped rate. The mirror
## can be switched off during a race to recover performance on slower devices.

const PLAYER_LAYER := 2
const MIRROR_INTERVAL := 1.0 / 24.0

var race_camera: ChaseCam
var rear: Camera3D
var viewport: SubViewport
var mirror: TextureRect
var mirror_panel: Panel
var view_button: Button
var mirror_button: Button
var cabin_overlay: Control
var enabled := true
var clock := 0.0


class CabinOverlay extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var rim := Color(0.035, 0.045, 0.06, 0.88)
		draw_colored_polygon(PackedVector2Array([Vector2(0, h - 46), Vector2(w * 0.28, h - 24), Vector2(w * 0.4, h), Vector2(0, h)]), rim)
		draw_colored_polygon(PackedVector2Array([Vector2(w, h - 46), Vector2(w * 0.72, h - 24), Vector2(w * 0.6, h), Vector2(w, h)]), rim)
		draw_arc(Vector2(w * 0.34, h + 36), 80, PI, TAU, 40, Color(0.035, 0.045, 0.06, 0.9), 15, true)


func setup(cam: ChaseCam, player_visual: CarVisual, layer: CanvasLayer) -> void:
	race_camera = cam
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
	mirror_panel.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.015, 0.02, 0.025, 0.94), Color(0.65, 0.73, 0.76, 0.9), 10, 2))
	layer.add_child(mirror_panel)
	mirror = TextureRect.new()
	mirror.position = Vector2(4, 4)
	mirror.size = Vector2(320, 72)
	mirror.texture = viewport.get_texture()
	mirror.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mirror.stretch_mode = TextureRect.STRETCH_SCALE
	mirror.flip_h = true
	mirror.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror_panel.add_child(mirror)
	view_button = _button(layer, "KAMERA: JASHTË", 218)
	view_button.pressed.connect(_toggle_view)
	mirror_button = _button(layer, "PASQYRA: PO", 268)
	mirror_button.pressed.connect(_toggle_mirror)


func _button(layer: CanvasLayer, label: String, top: float) -> Button:
	var b := UiTheme.button(label)
	b.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	b.offset_left = -180
	b.offset_right = -16
	b.offset_top = top
	b.offset_bottom = top + 42
	b.add_theme_font_size_override("font_size", 17)
	layer.add_child(b)
	return b


func _set_player_layer(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = 1 << (PLAYER_LAYER - 1)
	for child in node.get_children():
		_set_player_layer(child)


func _toggle_view() -> void:
	race_camera.cabin = not race_camera.cabin
	race_camera.set_cull_mask_value(PLAYER_LAYER, not race_camera.cabin)
	cabin_overlay.visible = race_camera.cabin
	view_button.text = "KAMERA: KABINË" if race_camera.cabin else "KAMERA: JASHTË"
	race_camera._snap = true
	Sfx.ui_click()


func _toggle_mirror() -> void:
	enabled = not enabled
	mirror_panel.visible = enabled
	mirror_button.text = "PASQYRA: PO" if enabled else "PASQYRA: JO"
	if not enabled:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	Sfx.ui_click()


func update_pose(c: CarState, pose: Dictionary, dt: float) -> void:
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
	clock += dt
	if clock >= MIRROR_INTERVAL:
		clock = fmod(clock, MIRROR_INTERVAL)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
