class_name RoomProduction
extends RefCounted
## How well a room hosts a content type.
##
## Room types declare `content_support` (fit, min_level, visual overrides) and each level has
## production attributes (equipment, lighting, decor, privacy) in 0..1. Content types weight those
## attributes (`room_weights`). Production multiplier = fit x lerp(min, max, weighted score), so a
## cosy upgraded bedroom can rival a basic studio for premium sets, while livestreams want gear.

const ATTRIBUTES: Array[String] = ["equipment", "lighting", "decor", "privacy"]


static func support(config: GameConfig, room_type_id: String, content_id: String) -> Dictionary:
	return config.room_type(room_type_id).get("content_support", {}).get(content_id, {})


static func supports(config: GameConfig, room: RoomState, content_id: String) -> bool:
	if room == null:
		return false
	var entry := support(config, room.type_id, content_id)
	return not entry.is_empty() and room.level >= int(entry.get("min_level", 1))


static func attributes(config: GameConfig, room: RoomState) -> Dictionary:
	if room == null:
		return {}
	return config.room_level_def(room.type_id, room.level).get("production", {})


## Weighted 0..1 score of the room's attributes for this content.
static func score(config: GameConfig, room: RoomState, content_id: String) -> float:
	var attrs := attributes(config, room)
	var weights: Dictionary = config.content(content_id).get("room_weights", {})
	if weights.is_empty():
		for attr in ATTRIBUTES:
			weights[attr] = 1.0
	var total := 0.0
	var weight_sum := 0.0
	for attr in weights:
		total += float(weights[attr]) * float(attrs.get(attr, 0.0))
		weight_sum += float(weights[attr])
	return total / weight_sum if weight_sum > 0.0 else 0.0


## Production multiplier for making `content_id` in `room` (0 if the room can't host it).
static func multiplier(config: GameConfig, room: RoomState, content_id: String) -> float:
	if not supports(config, room, content_id):
		return 0.0
	var fit := float(support(config, room.type_id, content_id).get("fit", 1.0))
	return fit * lerpf(config.tuning_f("rooms", "min_production", 0.6), config.tuning_f("rooms", "max_production", 1.5),
		clampf(score(config, room, content_id), 0.0, 1.0))


## Everything the UI needs to explain a room's production value.
static func breakdown(config: GameConfig, room: RoomState, content_id: String) -> Dictionary:
	return {
		"supported": supports(config, room, content_id),
		"fit": float(support(config, room.type_id, content_id).get("fit", 0.0)) if room != null else 0.0,
		"score": score(config, room, content_id),
		"multiplier": multiplier(config, room, content_id),
		"attributes": attributes(config, room),
		"weights": config.content(content_id).get("room_weights", {}),
	}


## Room types able to host the content: [{type_id, min_level, fit}].
static func supporting_types(config: GameConfig, content_id: String) -> Array:
	var result: Array = []
	for type_id in config.room_types:
		var entry := support(config, str(type_id), content_id)
		if not entry.is_empty():
			result.append({"type_id": str(type_id), "min_level": int(entry.get("min_level", 1)), "fit": float(entry.get("fit", 1.0))})
	return result


## Content needing an upgraded room somewhere in the house (e.g. livestreaming needs gear).
static func is_room_gated(config: GameConfig, content_id: String) -> bool:
	for entry: Dictionary in supporting_types(config, content_id):
		if int(entry["min_level"]) <= 1:
			return false
	return true


## True if any room in the house can currently host the content.
static func house_supports(state: GameState, config: GameConfig, content_id: String) -> bool:
	for room in state.rooms:
		if supports(config, room, content_id):
			return true
	return false


static func requirement_text(config: GameConfig, content_id: String) -> String:
	var options := PackedStringArray()
	for entry: Dictionary in supporting_types(config, content_id):
		options.append("%s Lv %d" % [config.room_type(str(entry["type_id"])).get("name", entry["type_id"]), int(entry["min_level"])])
	return "needs " + " or ".join(options) if not options.is_empty() else "no room can host it yet"
