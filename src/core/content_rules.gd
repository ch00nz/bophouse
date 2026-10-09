class_name ContentRules
extends RefCounted
## Who may make which content. A creator's declines are hard boundaries the player can
## never override; everything else is gated by house equipment (unlocks) and stat requirements.

enum Status { AVAILABLE, LOCKED, NEEDS_STATS, DECLINED, UNAVAILABLE }


static func assignable_ids(config: GameConfig) -> Array[String]:
	var ids: Array[String] = []
	for content_id in config.content_order:
		if bool(config.content(content_id).get("assignable", false)):
			ids.append(content_id)
	return ids


## Returns {ok: bool, status: Status, reason: String}.
static func check(creator: CreatorState, content_id: String, state: GameState, config: GameConfig) -> Dictionary:
	var content := config.content(content_id)
	if content.is_empty() or not bool(content.get("assignable", false)):
		return _result(Status.UNAVAILABLE, "Not available yet")
	if creator.content_declines.has(content_id):
		return _result(Status.DECLINED, "Outside %s's boundaries. It's her call." % first_name(creator))
	if not is_unlocked(state, content_id, config):
		return _result(Status.LOCKED, "Locked: " + room_requirement_text(content, config))
	var missing := PackedStringArray()
	var stat_reqs: Dictionary = content.get("requirements", {}).get("stats", {})
	for stat_id in stat_reqs:
		var needed := float(stat_reqs[stat_id])
		if creator.stat(str(stat_id)) < needed:
			missing.append("%s %d (has %d)" % [config.stat_label(str(stat_id)), int(needed), int(creator.stat(str(stat_id)))])
	if not missing.is_empty():
		return _result(Status.NEEDS_STATS, "Needs " + ", ".join(missing))
	return _result(Status.AVAILABLE, "")


static func can_assign(creator: CreatorState, content_id: String, state: GameState, config: GameConfig) -> bool:
	return bool(check(creator, content_id, state, config)["ok"])


static func loves(creator: CreatorState, content_id: String) -> bool:
	return creator.content_accepts.has(content_id)


## Room-gated content stays unlocked once the house has had the required room level.
static func is_unlocked(state: GameState, content_id: String, config: GameConfig) -> bool:
	var room_req: Dictionary = config.content(content_id).get("requirements", {}).get("room", {})
	return room_req.is_empty() or state.unlocked_content.has(content_id)


static func room_requirement_met(state: GameState, room_req: Dictionary) -> bool:
	if room_req.is_empty():
		return true
	for room in state.rooms:
		if room.type_id == str(room_req.get("type", "")) and room.level >= int(room_req.get("level", 1)):
			return true
	return false


static func room_requirement_text(content: Dictionary, config: GameConfig) -> String:
	var room_req: Dictionary = content.get("requirements", {}).get("room", {})
	if room_req.is_empty():
		return ""
	var room_name := str(config.room_type(str(room_req.get("type", ""))).get("name", room_req.get("type", "")))
	return "needs %s level %d" % [room_name, int(room_req.get("level", 1))]


## Unlocks content whose room requirement is now met. Returns the newly unlocked ids.
static func refresh_unlocks(state: GameState, config: GameConfig) -> Array[String]:
	var unlocked: Array[String] = []
	for content_id in assignable_ids(config):
		var room_req: Dictionary = config.content(content_id).get("requirements", {}).get("room", {})
		if room_req.is_empty() or state.unlocked_content.has(content_id):
			continue
		if room_requirement_met(state, room_req):
			state.unlocked_content.append(content_id)
			unlocked.append(content_id)
	return unlocked


## Keeps the current focus if still valid, otherwise picks a loved, then any, allowed category.
static func valid_focus(creator: CreatorState, state: GameState, config: GameConfig) -> String:
	if can_assign(creator, creator.content_focus, state, config):
		return creator.content_focus
	for content_id in creator.content_accepts:
		if can_assign(creator, str(content_id), state, config):
			return str(content_id)
	for content_id in assignable_ids(config):
		if can_assign(creator, content_id, state, config):
			return content_id
	return ""


static func first_name(creator: CreatorState) -> String:
	return creator.display_name.get_slice(" ", 0)


static func _result(status: Status, reason: String) -> Dictionary:
	return {"ok": status == Status.AVAILABLE, "status": status, "reason": reason}
