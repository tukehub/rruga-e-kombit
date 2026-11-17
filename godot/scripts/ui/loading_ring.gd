class_name LoadingRing
extends Control
## The game's badge inside a progress ring, for the corner of the loading
## screen. `target` is the real loading progress (0..1); the drawn arc eases
## toward it so it never jumps, and a short bright sweep keeps turning so the
## screen visibly lives even while a step takes a while.

const LOGO := preload("res://assets/icon.png")
const MASK := preload("res://shaders/circle_mask.gdshader")
const RING_WIDTH := 7.0
const EASE := 6.0
const SPIN := 2.4

var target := 0.0
var shown := 0.0
var _spin := 0.0
var _logo: TextureRect


func _init(size_px := 132.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = MASK
	_logo.material = mat
	add_child(_logo)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var inset := RING_WIDTH * 2.2
	_logo.position = Vector2(inset, inset)
	_logo.size = size - Vector2(inset, inset) * 2.0


## Moves the ring toward `value`; it never runs backwards.
func set_progress(value: float) -> void:
	target = maxf(target, clampf(value, 0.0, 1.0))


func _process(dt: float) -> void:
	advance(dt)


func advance(dt: float) -> void:
	shown = move_toward(shown, target, maxf(dt * EASE * (target - shown), dt * 0.25))
	_spin = fmod(_spin + dt * SPIN, TAU)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - RING_WIDTH * 0.5
	draw_circle(c, r + RING_WIDTH * 0.5, Color(0.0, 0.0, 0.0, 0.35))
	draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.12), RING_WIDTH, true)
	var start := -PI * 0.5
	if shown > 0.001:
		draw_arc(c, r, start, start + TAU * shown, maxi(8, int(96 * shown)), UiTheme.CYAN, RING_WIDTH, true)
	# A short bright sweep running round the track.
	draw_arc(c, r, _spin, _spin + 0.5, 12, Color(1, 1, 1, 0.55), RING_WIDTH * 0.45, true)
