extends Node

func _ready() -> void:
	Quality.set_preset("low")
	var def: Dictionary = Data.CARS[0]
	var car := CarVisual.new()
	add_child(car)
	car.setup(def, Color.html(def.color), true)
	var track := RaceTrack.load_city("tirane")
	var state := CarState.new(0, def, "test", true, Color.WHITE)
	assert(car.finish_driver != null, "player driver exists")
	_assert_shadows(car, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	Quality.set_preset("medium")
	_assert_shadows(car, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	Quality.set_preset("low")
	_assert_shadows(car, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert(car.contact_shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "contact shadow never casts")
	state.invuln_t = 2.0
	car.apply_state(state, track, 0.10)
	assert(not car.model.visible and not car.finish_driver.visible, "driver disappears with car")
	car.apply_state(state, track, 0.08)
	assert(car.model.visible and car.finish_driver.visible, "driver returns with car")
	state.invuln_t = 0.0
	car.apply_state(state, track, 0.0)
	assert(car.model.visible and car.finish_driver.visible, "driver remains visible after flicker")
	car.show_finish_driver()
	assert(car.finish_driver.visible, "finish driver remains visible")
	car.queue_free()
	# Public builds without the privately staged model use the original GLB.
	CarVisual._sport_checked = true
	CarVisual._sport_scene = null
	var fallback := CarVisual.new()
	add_child(fallback)
	fallback.setup(def, Color.html(def.color), true)
	_assert_shadows(fallback, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	state.invuln_t = 2.0
	fallback.apply_state(state, track, 0.10)
	assert(not fallback.model.visible and not fallback.finish_driver.visible, "fallback driver disappears with car")
	fallback.queue_free()
	print("CAR VISUAL: flicker and quality shadows passed")
	get_tree().quit()


func _assert_shadows(car: CarVisual, expected: int) -> void:
	for root in [car.model, car.finish_driver]:
		for child in root.get_children():
			if child is GeometryInstance3D:
				assert(child.cast_shadow == expected, "car and driver shadow settings must match quality")
