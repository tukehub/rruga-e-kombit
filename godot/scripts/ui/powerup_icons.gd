class_name PowerupIcons
extends RefCounted
## The same symbols identify road pickups and the carried HUD inventory.
## Original vector silhouettes ported from the legacy Three.js iconCanvas.

static var _textures: Dictionary = {}

static func texture(type: String) -> Texture2D:
	if not _textures.has(type):
		_textures[type] = load("res://assets/powerups/%s.svg" % type)
	return _textures[type]
