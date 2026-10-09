class_name ActivityResolver
extends RefCounted
## Resolves an activity for a specific creator (and room). Content-driven activities ("work") take
## their label, pose, bubble and props from the creator's chosen content type, then from the room's
## content_support entry, so the same content looks different in a bedroom than in the studio.


static func resolve(creator: CreatorState, activity_id: String, config: GameConfig, room: RoomState = null, content_id: String = "") -> Dictionary:
	var activity := config.activity(activity_id)
	if not is_content_driven(activity):
		return activity
	if content_id.is_empty():
		content_id = creator.content_focus
	var content := config.content(content_id)
	var resolved := activity.duplicate()
	var content_activity: Dictionary = content.get("activity", {})
	for key in content_activity:
		resolved[key] = content_activity[key]
	resolved["exclusive"] = bool(content.get("exclusive", true))
	resolved["content_id"] = content_id
	if room != null:
		var entry := RoomProduction.support(config, room.type_id, content_id)
		for key in entry:
			if key != "fit" and key != "min_level":
				resolved[key] = entry[key]
		resolved["room_type"] = room.type_id
	return resolved


static func is_content_driven(activity: Dictionary) -> bool:
	return bool(activity.get("content_driven", false))


## Room type for non-work activities (work rooms are chosen by RoomPlanner).
static func room_type(creator: CreatorState, activity_id: String, config: GameConfig) -> String:
	return str(resolve(creator, activity_id, config).get("room_type", ""))
