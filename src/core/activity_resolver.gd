class_name ActivityResolver
extends RefCounted
## Resolves an activity for a specific creator. Content-driven activities ("work") take their
## room, spot, facing, animation, bubble and label from the creator's chosen content type.


static func resolve(creator: CreatorState, activity_id: String, config: GameConfig) -> Dictionary:
	var activity := config.activity(activity_id)
	if not is_content_driven(activity):
		return activity
	var resolved := activity.duplicate()
	var content_activity: Dictionary = config.content(creator.content_focus).get("activity", {})
	for key in content_activity:
		resolved[key] = content_activity[key]
	resolved["content_id"] = creator.content_focus
	return resolved


static func is_content_driven(activity: Dictionary) -> bool:
	return bool(activity.get("content_driven", false))


static func room_type(creator: CreatorState, activity_id: String, config: GameConfig) -> String:
	return str(resolve(creator, activity_id, config).get("room_type", ""))
