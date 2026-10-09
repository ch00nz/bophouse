class_name GameConfig
extends RefCounted
## Read-only game configuration loaded from JSON files in res://data.
## Every balancing number lives in data so tuning never needs a code change.

const DEFAULT_DIR := "res://data"

var balance: Dictionary = {}
var room_types: Dictionary = {}        # type_id -> definition
var activities: Dictionary = {}        # activity_id -> definition
var creator_templates: Dictionary = {} # creator_id -> template
var creator_order: Array[String] = []  # template ids in data-file order (applications list)
var content_types: Dictionary = {}     # content_type_id -> definition
var content_order: Array[String] = []  # content ids in data-file order (for UI lists)
var trends: Dictionary = {}            # trend_id -> definition
var trend_order: Array[String] = []    # trend ids in data-file order (deterministic rolls)
var stat_defs: Dictionary = {}         # stat_id -> {label, description}
var trait_defs: Dictionary = {}        # trait name -> {description}
var house_layout: Array = []           # starting room slots
var appearance: Dictionary = {}        # raw appearance.json (age_tags, thresholds...)
var tag_defs: Dictionary = {}          # tag_id -> {label, color}
var tag_order: Array[String] = []
var look_options: Dictionary = {}      # slot -> {option_id -> definition}
var look_items: Dictionary = {}        # item_id -> definition (makeover catalogue)
var look_item_order: Array[String] = []
var audience: Dictionary = {}          # raw audiences.json
var segments: Array = []               # audience segment definitions, in order
var body: Dictionary = {}              # raw body.json (measurement limits, render curves, body tags)
var social: Dictionary = {}            # raw social.json (housemate interactions)
var upgrades_data: Dictionary = {}     # raw upgrades.json (stack_falloff, categories)
var upgrades: Dictionary = {}          # upgrade_id -> definition
var upgrade_order: Array[String] = []  # catalogue order
var illustrated: Dictionary = {}       # raw illustrated_art.json (painted art per creator)
var interiors: Dictionary = {}         # raw room_interiors.json (Room View staging and seating)


static func load_from_dir(dir: String = DEFAULT_DIR) -> GameConfig:
	var config := GameConfig.new()
	config.balance = _read_json(dir.path_join("balance.json"))
	config.room_types = _index_by_id(_read_json(dir.path_join("rooms.json")).get("room_types", []))
	config.activities = _index_by_id(_read_json(dir.path_join("activities.json")).get("activities", []))
	var creator_list: Array = _read_json(dir.path_join("creators.json")).get("creators", [])
	config.creator_templates = _index_by_id(creator_list)
	for item in creator_list:
		config.creator_order.append(str(item.get("id", "")))
	var content_list: Array = _read_json(dir.path_join("content_types.json")).get("content_types", [])
	config.content_types = _index_by_id(content_list)
	for item in content_list:
		config.content_order.append(str(item.get("id", "")))
	var trend_list: Array = _read_json(dir.path_join("trends.json")).get("trends", [])
	config.trends = _index_by_id(trend_list)
	for item in trend_list:
		config.trend_order.append(str(item.get("id", "")))
	var stats_file := _read_json(dir.path_join("stats.json"))
	config.stat_defs = _index_by_id(stats_file.get("stats", []))
	config.trait_defs = _index_by_id(stats_file.get("traits", []))
	config.house_layout = _read_json(dir.path_join("house_layout.json")).get("rooms", [])
	config.appearance = _read_json(dir.path_join("appearance.json"))
	for tag_def in config.appearance.get("tags", []):
		config.tag_defs[str(tag_def["id"])] = tag_def
		config.tag_order.append(str(tag_def["id"]))
	var slots: Dictionary = config.appearance.get("slots", {})
	for slot in slots:
		config.look_options[str(slot)] = _index_by_id(slots[slot])
	for item in config.appearance.get("items", []):
		config.look_items[str(item["id"])] = item
		config.look_item_order.append(str(item["id"]))
	config.audience = _read_json(dir.path_join("audiences.json"))
	config.segments = config.audience.get("segments", [])
	config.body = _read_json(dir.path_join("body.json"))
	config.social = _read_json(dir.path_join("social.json"))
	config.illustrated = _read_json(dir.path_join("illustrated_art.json"))
	config.interiors = _read_json(dir.path_join("room_interiors.json"))
	config.upgrades_data = _read_json(dir.path_join("upgrades.json"))
	for item in config.upgrades_data.get("upgrades", []):
		config.upgrades[str(item["id"])] = item
		config.upgrade_order.append(str(item["id"]))
	return config


func look_option(slot: String, option_id: String) -> Dictionary:
	return look_options.get(slot, {}).get(option_id, {})


func look_item(item_id: String) -> Dictionary:
	return look_items.get(item_id, {})


func upgrade(upgrade_id: String) -> Dictionary:
	return upgrades.get(upgrade_id, {})


func tag_label(tag_id: String) -> String:
	return str(tag_defs.get(tag_id, {}).get("label", tag_id.capitalize()))


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


func content(content_id: String) -> Dictionary:
	return content_types.get(content_id, {})


func trend(trend_id: String) -> Dictionary:
	return trends.get(trend_id, {})


func stat_label(stat_id: String) -> String:
	return str(stat_defs.get(stat_id, {}).get("label", stat_id.capitalize()))


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
