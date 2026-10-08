class_name SaveSystem
extends RefCounted
## Versioned JSON persistence. On the web, user:// is backed by IndexedDB.

const SAVE_VERSION := 1


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
	var _version := from_version
	# Example for the future:
	# if _version == 1:
	#     migrated["state"]["trends"] = []
	#     _version = 2
	return migrated


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
