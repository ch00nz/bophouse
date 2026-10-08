class_name CreatorState
extends RefCounted
## Runtime state of one creator. Plain data plus small helpers; no rendering.

var id: String = ""
var display_name: String = ""
var age: int = 18
var bio: String = ""
var stats: Dictionary = {}
var traits: Array = []
var appearance: Dictionary = {}
var content_accepts: Array = []
var content_declines: Array = []

var energy: float = 100.0
var mood: float = 70.0
var followers: float = 0.0
var subscribers: float = 0.0
var lifetime_earnings: float = 0.0

var activity_id: String = "idle"
var activity_minutes: float = 0.0
var room_id: String = ""
## Logical position: x = house column (fractional), y = storey.
var position: Vector2 = Vector2.ZERO

## Travel: while travel_path is non-empty the creator is walking.
var travel_path: Array = []
var travel_progress: float = 0.0
var target_activity_id: String = ""
var target_room_id: String = ""


static func from_template(template: Dictionary) -> CreatorState:
	var c := CreatorState.new()
	c.id = str(template.get("id", ""))
	c.display_name = str(template.get("name", c.id))
	c.age = maxi(18, int(template.get("age", 18))) # All characters are adults, enforced in code too.
	c.bio = str(template.get("bio", ""))
	c.stats = template.get("stats", {}).duplicate()
	c.traits = template.get("traits", []).duplicate()
	c.appearance = template.get("appearance", {}).duplicate()
	var content: Dictionary = template.get("content", {})
	c.content_accepts = content.get("accepts", []).duplicate()
	c.content_declines = content.get("declines", []).duplicate()
	var start: Dictionary = template.get("starting", {})
	c.followers = float(start.get("followers", 0))
	c.subscribers = float(start.get("subscribers", 0))
	c.energy = float(start.get("energy", 100))
	c.mood = float(start.get("mood", 70))
	return c


func stat(stat_name: String) -> float:
	return float(stats.get(stat_name, 50))


func is_travelling() -> bool:
	return not travel_path.is_empty()


## Room the creator is in, or heading to.
func occupied_room_id() -> String:
	return target_room_id if is_travelling() else room_id


func to_dict() -> Dictionary:
	var path_data: Array = []
	for point: Vector2 in travel_path:
		path_data.append([point.x, point.y])
	return {
		"id": id, "name": display_name, "age": age, "bio": bio,
		"stats": stats, "traits": traits, "appearance": appearance,
		"content_accepts": content_accepts, "content_declines": content_declines,
		"energy": energy, "mood": mood, "followers": followers, "subscribers": subscribers,
		"lifetime_earnings": lifetime_earnings,
		"activity_id": activity_id, "activity_minutes": activity_minutes, "room_id": room_id,
		"position": [position.x, position.y],
		"travel_path": path_data, "travel_progress": travel_progress,
		"target_activity_id": target_activity_id, "target_room_id": target_room_id,
	}


static func from_dict(data: Dictionary) -> CreatorState:
	var c := CreatorState.new()
	c.id = str(data.get("id", ""))
	c.display_name = str(data.get("name", c.id))
	c.age = maxi(18, int(data.get("age", 18)))
	c.bio = str(data.get("bio", ""))
	c.stats = data.get("stats", {})
	c.traits = data.get("traits", [])
	c.appearance = data.get("appearance", {})
	c.content_accepts = data.get("content_accepts", [])
	c.content_declines = data.get("content_declines", [])
	c.energy = float(data.get("energy", 100))
	c.mood = float(data.get("mood", 70))
	c.followers = float(data.get("followers", 0))
	c.subscribers = float(data.get("subscribers", 0))
	c.lifetime_earnings = float(data.get("lifetime_earnings", 0))
	c.activity_id = str(data.get("activity_id", "idle"))
	c.activity_minutes = float(data.get("activity_minutes", 0))
	c.room_id = str(data.get("room_id", ""))
	c.position = _vec(data.get("position", [0, 0]))
	for point in data.get("travel_path", []):
		c.travel_path.append(_vec(point))
	c.travel_progress = float(data.get("travel_progress", 0))
	c.target_activity_id = str(data.get("target_activity_id", ""))
	c.target_room_id = str(data.get("target_room_id", ""))
	return c


static func _vec(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
