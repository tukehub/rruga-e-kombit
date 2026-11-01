class_name UiTheme
extends RefCounted
## Shared look for menus and HUD: OFL fonts (Big Shoulders Display for
## headlines, Chakra Petch for body), neon palette, helper constructors.

const BG := Color("0d0a10")
const PANEL := Color(0.08, 0.07, 0.11, 0.78)
const CYAN := Color("2de2ff")
const VIOLET := Color("8a5cff")
const PINK := Color("ff2d6f")
const AMBER := Color("ffb547")
const GREEN := Color("2bff88")
const RED := Color("ff3b4e")
const TEXT := Color("f4f1f7")
const MUTED := Color("c4d0dd")

static var _display: FontFile
static var _body: FontFile
static var _body_bold: FontFile
static var _theme: Theme


static func display() -> FontFile:
	if _display == null:
		_display = load("res://assets/fonts/BigShouldersDisplay.ttf")
	return _display


static func body() -> FontFile:
	if _body == null:
		_body = load("res://assets/fonts/ChakraPetch-Regular.ttf")
	return _body


static func body_bold() -> FontFile:
	if _body_bold == null:
		_body_bold = load("res://assets/fonts/ChakraPetch-Bold.ttf")
	return _body_bold


## Theme applied to the scene roots: body font everywhere, flat buttons.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = 26
	t.set_font("font", "Button", body_bold())
	t.set_font_size("font_size", "Button", 26)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_stylebox("normal", "Button", flat(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.22), 12))
	t.set_stylebox("hover", "Button", flat(Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.35), 12))
	t.set_stylebox("pressed", "Button", flat(Color(CYAN, 0.35), CYAN, 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", flat(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1), 12))
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "PanelContainer", flat(PANEL, Color(1, 1, 1, 0.12), 16))
	t.set_stylebox("panel", "Panel", flat(PANEL, Color(1, 1, 1, 0.12), 16))
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("slider", "HSlider", flat(Color(1, 1, 1, 0.15), Color(0, 0, 0, 0), 4))
	t.set_stylebox("grabber_area", "HSlider", flat(CYAN, Color(0, 0, 0, 0), 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(CYAN.lightened(0.2), Color(0, 0, 0, 0), 4))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func flat(bg: Color, border: Color, radius: int, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw if border.a > 0.0 else 0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func label(text: String, size: int, col := TEXT, use_display := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display() if use_display else body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Bold headline with a dark outline for readability on a phone.
static func headline(text: String, size: int, col := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, col, false, align)
	l.add_theme_font_override("font", body_bold())
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", maxi(2, size / 32))
	return l


static func button(text: String, accent := Color(0, 0, 0, 0), min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.y = 50
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	if accent.a > 0.0:
		b.add_theme_stylebox_override("normal", flat(Color(accent, 0.75), accent.lightened(0.25), 12))
		b.add_theme_stylebox_override("hover", flat(Color(accent, 0.9), accent.lightened(0.4), 12))
		b.add_theme_stylebox_override("pressed", flat(accent.lightened(0.2), Color.WHITE, 12))
		b.add_theme_color_override("font_color", Color.WHITE)
	return b


static func panel(radius := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", flat(PANEL, Color(1, 1, 1, 0.12), radius))
	return p


static func spacer(h := 12.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Full-screen dim backdrop for menus drawn over the 3D garage / world.
static func shade(alpha := 0.55) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(BG, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
