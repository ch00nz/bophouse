class_name SaveSystem
extends RefCounted
## Versioned JSON persistence. On the web, user:// is backed by IndexedDB.

## v1: first prototype. v2: content specialisation, experience, unlocks, trends.
## v3: appearance (look, owned styles, procedures, recovery, tags), fan mix, reputation.
## v4: multi-room production (home room, last work room, room preferences), photoshoot cooldown.
const SAVE_VERSION := 4

## Content ids renamed in v2.
const V2_CONTENT_RENAMES := {"solo_subscription": "solo_premium", "premium": "topless_premium"}


static func to_save_dict(state: GameState, now_unix: float) -> Dictionary:
	var saved_at := maxf(state.last_seen_unix, now_unix)
	return {"version": SAVE_VERSION, "saved_at_unix": saved_at, "state": state.to_dict()}


## Returns null when the data is unreadable or from a newer, unknown version.
static func from_save_dict(data: Variant) -> GameState:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var version := int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		push_warning("SaveSystem: unsupported save version %d" % version)
		return null
	var migrated := _migrate(data, version)
	var state_data: Variant = migrated.get("state", null)
	if typeof(state_data) != TYPE_DICTIONARY:
		return null
	var state := GameState.from_dict(state_data)
	state.last_seen_unix = maxf(state.last_seen_unix, float(migrated.get("saved_at_unix", 0)))
	return state


## Upgrades older save formats step by step. Add a branch per version bump.
static func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var migrated := data.duplicate(true)
	var version := from_version
	if version == 1:
		_migrate_v1_to_v2(migrated)
		version = 2
	if version == 2:
		# v3 only adds fields. Creator defaults (look, tags, fan mix) need the creator templates,
		# so post_load() fills them in; nothing to rewrite here.
		version = 3
	if version == 3:
		# v4 only adds fields (home/work rooms, preferences, photoshoot cooldown); post_load fills them.
		version = 4
	migrated["version"] = version
	return migrated


static func _migrate_v1_to_v2(data: Dictionary) -> void:
	var state_data: Variant = data.get("state", null)
	if typeof(state_data) != TYPE_DICTIONARY:
		return
	for creator_data in state_data.get("creators", []):
		if typeof(creator_data) != TYPE_DICTIONARY:
			continue
		# The prototype's generic studio activity became content-driven work.
		for key in ["activity_id", "target_activity_id"]:
			if str(creator_data.get(key, "")) == "film_content":
				creator_data[key] = "work"
		for key in ["content_accepts", "content_declines"]:
			var renamed: Array = []
			for content_id in creator_data.get(key, []):
				renamed.append(V2_CONTENT_RENAMES.get(str(content_id), str(content_id)))
			creator_data[key] = renamed
		# v1 creators were effectively shooting glamour in the studio and were good at it.
		if not creator_data.has("content_focus"):
			creator_data["content_focus"] = "glamour"
			creator_data["content_experience"] = {"glamour": 1.0}
	# Trends and unlocks are created by post_load().


## Repairs a loaded state against current data: unlocks, trends, invalid choices.
## Call after loading (needs config, so it isn't part of from_save_dict).
static func post_load(state: GameState, config: GameConfig) -> void:
	RoomPlanner.assign_home_rooms(state, config)
	ContentRules.refresh_unlocks(state, config)
	TrendSystem.ensure_initialized(state, config)
	for creator in state.creators:
		if creator.room_preferences.is_empty():
			var template: Dictionary = config.creator_templates.get(creator.id, {})
			for type_id in template.get("room_preferences", {}):
				creator.room_preferences[str(type_id)] = float(template["room_preferences"][type_id])
		Appearance.ensure_look(creator, config)
		AudienceModel.ensure_mix(creator, config)
		creator.content_focus = ContentRules.valid_focus(creator, state, config)
		if config.activity(creator.activity_id).is_empty():
			creator.activity_id = "idle"
		if creator.is_travelling() and config.activity(creator.target_activity_id).is_empty():
			creator.target_activity_id = "idle"


static func write(path: String, state: GameState, now_unix: float) -> Error:
	var text := JSON.stringify(to_save_dict(state, now_unix), "\t")
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	# Write-then-rename so a crash mid-save can't corrupt the existing save.
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		file = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(text)
		file.close()
		DirAccess.remove_absolute(tmp_path)
	return OK


static func read(path: String) -> GameState:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("SaveSystem: save file %s is corrupt (%s)" % [path, json.get_error_message()])
		return null
	return from_save_dict(json.data)


static func delete(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## True if a loaded state still makes sense with the current data files.
static func is_compatible(state: GameState, config: GameConfig) -> bool:
	if state == null or state.creators.is_empty() or state.rooms.is_empty():
		return false
	for room in state.rooms:
		if config.room_type(room.type_id).is_empty():
			return false
	return true
