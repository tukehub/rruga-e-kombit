extends SceneTree
## Run inside the Godot project, or with --main-pack, to check the staged
## private payload without writing or publishing the decrypted model.

func _initialize() -> void:
	var payload := "res://assets/private_car/vortex_sport.bin"
	var key_path := "res://assets/private_car/car_key.gd"
	if not FileAccess.file_exists(payload) or not ResourceLoader.exists(key_path):
		printerr("PRIVATE CAR: encrypted payload or key is missing")
		quit(1)
		return
	var key_script = load(key_path)
	var file := FileAccess.open_encrypted(payload, FileAccess.READ, key_script.key())
	if file == null:
		printerr("PRIVATE CAR: decryption failed")
		quit(1)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var result := document.append_from_buffer(file.get_buffer(file.get_length()), "", state)
	if result != OK:
		printerr("PRIVATE CAR: cannot parse decrypted model")
		quit(1)
		return
	var model := document.generate_scene(state)
	if model == null:
		printerr("PRIVATE CAR: cannot create model scene")
		quit(1)
		return
	for child_name in ["body", "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		if not model.has_node(child_name):
			printerr("PRIVATE CAR: expected vehicle part is missing: ", child_name)
			model.free()
			quit(1)
			return
	model.free()
	print("PRIVATE CAR: encrypted model opens and all five vehicle parts exist")
	quit(0)
