extends SceneTree
## Encrypt a locally supplied GLB. The key and input never enter source control.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("Expected input GLB, private key file and output payload")
		quit(2)
		return
	var data := FileAccess.get_file_as_bytes(args[0])
	var key := FileAccess.get_file_as_bytes(args[1])
	if data.is_empty() or key.size() != 32:
		printerr("Input is empty or key is not 32 bytes")
		quit(2)
		return
	var output := FileAccess.open_encrypted(args[2], FileAccess.WRITE, key)
	if output == null:
		printerr("Could not create encrypted vehicle payload")
		quit(1)
		return
	output.store_buffer(data)
	output.close()
	quit(0)
