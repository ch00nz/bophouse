class_name ContentRules
extends RefCounted
## Who may make which content. A creator's declines are hard boundaries the player can
## never override; everything else is gated by house equipment (unlocks) and stat requirements.

enum Status { AVAILABLE, LOCKED, NEEDS_STATS, DECLINED, UNAVAILABLE, NEEDS_SUBSCRIBERS }


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
		return _result(Status.LOCKED, "Locked: " + RoomProduction.requirement_text(config, content_id))
	var missing := PackedStringArray()
	var stat_reqs: Dictionary = content.get("requirements", {}).get("stats", {})
	for stat_id in stat_reqs:
		var needed := float(stat_reqs[stat_id])
		if creator.stat(str(stat_id)) < needed:
			missing.append("%s %d (has %d)" % [config.stat_label(str(stat_id)), int(needed), int(creator.stat(str(stat_id)))])
	if not missing.is_empty():
		return _result(Status.NEEDS_STATS, "Needs " + ", ".join(missing))
	var min_subs := float(content.get("requirements", {}).get("min_subscribers", 0))
	if creator.subscribers < min_subs:
		return _result(Status.NEEDS_SUBSCRIBERS, "Needs %d paying subscribers (has %d)" % [int(min_subs), int(creator.subscribers)])
	return _result(Status.AVAILABLE, "")


static func can_assign(creator: CreatorState, content_id: String, state: GameState, config: GameConfig) -> bool:
	return bool(check(creator, content_id, state, config)["ok"])


static func loves(creator: CreatorState, content_id: String) -> bool:
	return creator.content_accepts.has(content_id)


## Content that needs an upgraded room (any room able to host it, see rooms.json content_support)
## stays unlocked once the house has had such a room.
static func is_unlocked(state: GameState, content_id: String, config: GameConfig) -> bool:
	if not RoomProduction.is_room_gated(config, content_id):
		return true
	return state.unlocked_content.has(content_id)


## Unlocks room-gated content once some room can host it. Returns the newly unlocked ids.
static func refresh_unlocks(state: GameState, config: GameConfig) -> Array[String]:
	var unlocked: Array[String] = []
	for content_id in assignable_ids(config):
		if not RoomProduction.is_room_gated(config, content_id) or state.unlocked_content.has(content_id):
			continue
		if RoomProduction.house_supports(state, config, content_id):
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
