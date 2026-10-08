class_name ArtLibrary
extends RefCounted
## Resolves optional artwork referenced from data files.
## Returns null when the art doesn't exist yet so callers fall back to placeholder drawing.
## Dropping a texture at the path named in data is all it takes to replace a placeholder.

static var _cache: Dictionary = {}


static func texture(path: String) -> Texture2D:
	return _load(path, "Texture2D") as Texture2D


static func sprite_frames(path: String) -> SpriteFrames:
	return _load(path, "SpriteFrames") as SpriteFrames


static func _load(path: String, type_hint: String) -> Resource:
	if path.is_empty():
		return null
	if _cache.has(path):
		return _cache[path]
	var resource: Resource = null
	if ResourceLoader.exists(path, type_hint):
		resource = ResourceLoader.load(path, type_hint)
	_cache[path] = resource
	return resource
