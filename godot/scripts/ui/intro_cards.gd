class_name IntroCards
extends Control
## Driver name cards for the intro sweep: the starting grid, front row first,
## one card after another. They leave when the countdown begins.

const FIRST_DELAY := 0.2
const STAGGER := 0.26
const LEAVE_TIME := 0.3

var cards: Array[Control] = []
var leaving := false


## Front of the grid first.
static func grid_order(cars: Array[CarState]) -> Array[CarState]:
	var order := cars.duplicate()
	order.sort_custom(func(a: CarState, b: CarState) -> bool: return a.progress > b.progress)
	return order


func setup(race: Race) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Right of the standings, under the speedometer.
	position = Vector2(300, 136)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var heading := UiTheme.label(Data.t("intro.grid"), 20, UiTheme.CYAN)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	cards.append(heading)
	var place := 0
	for c in grid_order(race.cars):
		place += 1
		column.add_child(_card(place, c))
	_play.call_deferred()


func _card(place: int, c: CarState) -> Control:
	var panel := UiTheme.panel(10)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = 300
	var accent := c.color
	panel.add_theme_stylebox_override("panel", UiTheme.flat(Color(0.02, 0.04, 0.07, 0.72 if c.is_player else 0.5), Color(accent, 0.95 if c.is_player else 0.45), 10, 2 if c.is_player else 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var number := UiTheme.label(str(place), 26, UiTheme.TEXT)
	number.custom_minimum_size.x = 30
	row.add_child(number)
	var stripe := ColorRect.new()
	stripe.color = accent
	stripe.custom_minimum_size = Vector2(6, 30)
	stripe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stripe)
	var name_label := UiTheme.label(c.name, 26, Color.WHITE if c.is_player else UiTheme.TEXT, c.is_player)
	name_label.name = "DriverName"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(name_label)
	if c.is_player:
		row.add_child(UiTheme.label(Data.t("hud.you"), 20, UiTheme.CYAN))
	panel.set_meta("car", c)
	cards.append(panel)
	return panel


func _play() -> void:
	# After the column has laid its cards out, send each one in from the left.
	for card in cards:
		card.modulate.a = 0.0
	await get_tree().process_frame
	if leaving:
		return
	for i in cards.size():
		UiTheme.slide_in(cards[i], Vector2(-70.0, 0.0), UiTheme.SLIDE_TIME, FIRST_DELAY + maxi(0, i - 1) * STAGGER)


## Fade the cards out and remove them.
func leave() -> void:
	if leaving:
		return
	leaving = true
	var tween := UiTheme.fade(self, 0.0, LEAVE_TIME)
	if tween != null:
		tween.finished.connect(queue_free)
	else:
		queue_free()
