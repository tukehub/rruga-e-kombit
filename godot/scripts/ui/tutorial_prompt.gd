class_name TutorialPrompt
extends PanelContainer
## The tutorial's instruction line, top centre under the speedometer, with a
## button to leave the tutorial. RaceScene decides what it says and when.

signal skip_pressed

const WIDTH := 640.0

var label: Label
var skip: Button


func _ready() -> void:
	name = "TutorialPrompt"
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 136
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.78), Color(UiTheme.AMBER, 0.85), 12, 2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	label = UiTheme.label("", 21, UiTheme.TEXT)
	label.name = "PromptText"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A wrapping label has no width of its own; give the line a fixed one.
	label.custom_minimum_size.x = WIDTH - 160.0
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	skip = UiTheme.button(Data.t("tutorial.skip"))
	skip.name = "SkipTutorial"
	skip.custom_minimum_size = Vector2(110, 44)
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.add_theme_font_size_override("font_size", 19)
	skip.pressed.connect(func() -> void: skip_pressed.emit())
	row.add_child(skip)


func say(text: String) -> void:
	if label.text == text:
		return
	label.text = text
	modulate.a = 0.0
	UiTheme.fade(self, 1.0)
	# Shrink back to the text after a longer line; keep it centred.
	reset_size()
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
