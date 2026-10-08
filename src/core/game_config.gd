class_name GameConfig
extends RefCounted
## Read-only game configuration loaded from JSON files in res://data.
## Every balancing number lives in data so tuning never needs a code change.

const DEFAULT_DIR := "res://data"

var balance: Dictionary = {}
var room_types: Dictionary = {}        # type_id -> definition
var activities: Dictionary = {}        # activity_id -> definition
var creator_templates: Dictionary = {} # creator_id -> template
var content_types: Dictionary = {}     # content_type_id -> definition
var house_layout: Array = []           # starting room slots


static func load_from_dir(dir: String = DEFAULT_DIR) -> GameConfig:
	var config := GameConfig.new()
	config.balance = _read_json(dir.path_join("balance.json"))
	config.room_types = _index_by_id(_read_json(dir.path_join("rooms.json")).get("room_types", []))
	config.activities = _index_by_id(_read_json(dir.path_join("activities.json")).get("activities", []))
	config.creator_templates = _index_by_id(_read_json(dir.path_join("creators.json")).get("creators", []))
	config.content_types = _index_by_id(_read_json(dir.path_join("content_types.json")).get("content_types", []))
	config.house_layout = _read_json(dir.path_join("house_layout.json")).get("rooms", [])
	return config


## Returns balance[section][key], or `default` when missing.
func tuning(section: String, key: String, default: Variant = null) -> Variant:
	var values: Dictionary = balance.get(section, {})
	return values.get(key, default)


func tuning_f(section: String, key: String, default: float = 0.0) -> float:
	return float(tuning(section, key, default))


func room_type(type_id: String) -> Dictionary:
	return room_types.get(type_id, {})


func room_level_def(type_id: String, level: int) -> Dictionary:
	var levels: Array = room_type(type_id).get("levels", [])
	for level_def in levels:
		if int(level_def.get("level", 0)) == level:
			return level_def
	return {}


func max_room_level(type_id: String) -> int:
	var levels: Array = room_type(type_id).get("levels", [])
	return levels.size()


func activity(activity_id: String) -> Dictionary:
	return activities.get(activity_id, {})


func content_label(content_id: String) -> String:
	return str(content_types.get(content_id, {}).get("label", content_id.capitalize()))


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameConfig: missing data file %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameConfig: %s is not a JSON object" % path)
		return {}
	return parsed


static func _index_by_id(items: Array) -> Dictionary:
	var result := {}
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			result[str(item["id"])] = item
	return result
