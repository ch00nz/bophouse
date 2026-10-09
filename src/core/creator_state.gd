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
## Content she loves making (small mood bonus). Not a whitelist: anything not declined is allowed.
var content_accepts: Array = []
## Her hard boundaries. The player can never assign these.
var content_declines: Array = []
## The player's chosen content specialisation (must be within her boundaries).
var content_focus: String = ""
## content_id -> 0..1 experience. Rises while making that content, faster with adaptability.
## New content starts at 0, so switching strategy has a short settling-in cost.
var content_experience: Dictionary = {}

## Appearance slots (see data/appearance.json): hair_color, hair_style, outfit, makeup,
## bust, body, lips (single values) and piercings, tattoos (arrays).
var look: Dictionary = {}
## Styling items she owns ("slot:value"); owned styles can be switched back to for free.
var owned_styles: Array = []
## [{item_id, day}] in purchase order. Kept for future events (e.g. complications, regrets).
var procedure_history: Array = []
## {item_id, remaining_minutes, total_minutes} while recovering, else empty.
var recovery: Dictionary = {}
## Tags she has regardless of styling (personality / natural look).
var base_tags: Dictionary = {}
## Cached, derived from base_tags + look (Appearance.refresh). Saved for future event eligibility.
var appearance_tags: Dictionary = {}
## Her own say over her appearance: {declines: [item ids], wishes: [item ids]}.
var appearance_prefs: Dictionary = {}
## Subscriber composition by audience segment (fractions summing to 1).
var fan_mix: Dictionary = {}
## 0..100 mainstream reputation. Socials raise it; it boosts subscriber conversion.
var reputation: float = 40.0

## Her own bedroom (sleeps there; private rooms can only be filmed in by their owner).
var home_room_id: String = ""
## Where her last work session happened; used for room-selection stability.
var last_work_room_id: String = ""
## room type -> comfort multiplier when choosing where to work.
var room_preferences: Dictionary = {}
## Game minute when the optional bonus photoshoot is available again.
var photoshoot_ready_at: float = 0.0

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
	c.content_focus = str(content.get("default_focus", ""))
	if not c.content_focus.is_empty():
		c.content_experience[c.content_focus] = 1.0
	var start: Dictionary = template.get("starting", {})
	c.followers = float(start.get("followers", 0))
	c.subscribers = float(start.get("subscribers", 0))
	c.energy = float(start.get("energy", 100))
	c.mood = float(start.get("mood", 70))
	c.look = template.get("look", {}).duplicate(true)
	c.owned_styles = template.get("owned_styles", []).duplicate()
	c.base_tags = template.get("base_tags", {}).duplicate()
	c.appearance_prefs = template.get("appearance_prefs", {}).duplicate(true)
	c.reputation = float(template.get("reputation", 40))
	c.room_preferences = _float_dict(template.get("room_preferences", {}))
	return c


## Deep, independent copy (used for makeover previews so nothing is applied for real).
func clone() -> CreatorState:
	return CreatorState.from_dict(JSON.parse_string(JSON.stringify(to_dict())))


func is_recovering() -> bool:
	return not recovery.is_empty() and float(recovery.get("remaining_minutes", 0.0)) > 0.0


func look_value(slot: String, default: String = "") -> String:
	return str(look.get(slot, default))


func look_list(slot: String) -> Array:
	var value: Variant = look.get(slot, [])
	return value if value is Array else []


func tag(tag_id: String) -> float:
	return float(appearance_tags.get(tag_id, 0.0))


func stat(stat_name: String) -> float:
	return float(stats.get(stat_name, 50))


func experience(content_id: String) -> float:
	return float(content_experience.get(content_id, 0.0))


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
		"content_focus": content_focus, "content_experience": content_experience,
		"look": look, "owned_styles": owned_styles, "procedure_history": procedure_history,
		"recovery": recovery, "base_tags": base_tags, "appearance_tags": appearance_tags,
		"appearance_prefs": appearance_prefs, "fan_mix": fan_mix, "reputation": reputation,
		"home_room_id": home_room_id, "last_work_room_id": last_work_room_id,
		"room_preferences": room_preferences, "photoshoot_ready_at": photoshoot_ready_at,
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
	c.content_focus = str(data.get("content_focus", ""))
	var experience: Dictionary = data.get("content_experience", {})
	for content_id in experience:
		c.content_experience[str(content_id)] = clampf(float(experience[content_id]), 0.0, 1.0)
	c.look = _dict(data.get("look", {}))
	c.owned_styles = _arr(data.get("owned_styles", []))
	c.procedure_history = _arr(data.get("procedure_history", []))
	c.recovery = _dict(data.get("recovery", {}))
	c.base_tags = _float_dict(data.get("base_tags", {}))
	c.appearance_tags = _float_dict(data.get("appearance_tags", {}))
	c.appearance_prefs = _dict(data.get("appearance_prefs", {}))
	c.fan_mix = _float_dict(data.get("fan_mix", {}))
	c.reputation = clampf(float(data.get("reputation", 40.0)), 0.0, 100.0)
	c.home_room_id = str(data.get("home_room_id", ""))
	c.last_work_room_id = str(data.get("last_work_room_id", ""))
	c.room_preferences = _float_dict(data.get("room_preferences", {}))
	c.photoshoot_ready_at = float(data.get("photoshoot_ready_at", 0.0))
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


static func _dict(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _arr(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


static func _float_dict(value: Variant) -> Dictionary:
	var result := {}
	if value is Dictionary:
		for key in value:
			result[str(key)] = float(value[key])
	return result


static func _vec(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.ZERO
