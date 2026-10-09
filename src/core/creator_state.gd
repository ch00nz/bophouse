class_name CreatorState
extends RefCounted
## Runtime state of one creator. Plain data plus small helpers; no rendering.
## Everything is per creator (identified by a unique id), so any number of residents work the same way.

## Every character in adult content is an adult; enforced in code as well as data.
const MIN_AGE := 21

var id: String = ""
var display_name: String = ""
var age: int = MIN_AGE
var bio: String = ""
## Short descriptor shown in applications and the roster (e.g. "Bombshell").
var archetype: String = ""
var stats: Dictionary = {}
var traits: Array = []
var appearance: Dictionary = {}
## Content she loves making (small mood bonus). Not a whitelist: anything not declined is allowed.
var content_accepts: Array = []
## Her hard boundaries. The player can never assign these.
var content_declines: Array = []
## The player's chosen content specialisation (must be within her boundaries).
var content_focus: String = ""
## content_id -> freshness (floor..1). Making the same content wears it out for her audience;
## it recovers while she makes something else. Missing = fully fresh.
var content_freshness: Dictionary = {}
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

## Permanent body measurements (null only while loading a save that predates them).
var measurements: BodyMeasurements = null
## Her agreement with the house: {creator_share (0..1), joined_day, label}.
var contract: Dictionary = {}
## What she adds to the house's running costs per game day (rent share, utilities, food, lifestyle).
var living_cost_per_day: float = 0.0
## Living costs the house has paid for her so far.
var living_costs_paid: float = 0.0
## Lifetime split of her gross revenue (lifetime_earnings is the gross).
var creator_earnings: float = 0.0
var house_earnings: float = 0.0
## Audience when she joined, for growth tracking.
var joined_day: int = 1
var joined_followers: float = 0.0
var joined_subscribers: float = 0.0
## Personal routine: moves her night later (+) or earlier (-), in hours.
var sleep_shift_hours: float = 0.0
## Transient social reaction bubble: {kind, anim, with, until (game minute), label}.
var reaction: Dictionary = {}

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
	c.age = maxi(MIN_AGE, int(template.get("age", MIN_AGE))) # All characters are adults, enforced in code too.
	c.bio = str(template.get("bio", ""))
	c.archetype = str(template.get("archetype", ""))
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
	c.sleep_shift_hours = float(template.get("schedule", {}).get("sleep_shift_hours", 0.0))
	c.living_cost_per_day = maxf(float(template.get("living_cost_per_day", 0.0)), 0.0)
	c.joined_followers = c.followers
	c.joined_subscribers = c.subscribers
	return c


## Deep, independent copy (used for makeover previews so nothing is applied for real).
func clone() -> CreatorState:
	return CreatorState.from_dict(JSON.parse_string(JSON.stringify(to_dict())))


## Her cut of gross revenue (0..1). The house keeps the rest.
func creator_share() -> float:
	return clampf(float(contract.get("creator_share", 0.0)), 0.0, 1.0)


func house_share() -> float:
	return 1.0 - creator_share()


func first_name() -> String:
	return display_name.get_slice(" ", 0)


func has_reaction(game_minutes: float) -> bool:
	return not reaction.is_empty() and float(reaction.get("until", 0.0)) > game_minutes


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


func freshness(content_id: String) -> float:
	return float(content_freshness.get(content_id, 1.0))


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
		"id": id, "name": display_name, "age": age, "bio": bio, "archetype": archetype,
		"stats": stats, "traits": traits, "appearance": appearance,
		"content_accepts": content_accepts, "content_declines": content_declines,
		"content_focus": content_focus, "content_experience": content_experience, "content_freshness": content_freshness,
		"look": look, "owned_styles": owned_styles, "procedure_history": procedure_history,
		"recovery": recovery, "base_tags": base_tags, "appearance_tags": appearance_tags,
		"appearance_prefs": appearance_prefs, "fan_mix": fan_mix, "reputation": reputation,
		"home_room_id": home_room_id, "last_work_room_id": last_work_room_id,
		"room_preferences": room_preferences, "photoshoot_ready_at": photoshoot_ready_at,
		"measurements": measurements.to_dict() if measurements != null else {},
		"contract": contract, "creator_earnings": creator_earnings, "house_earnings": house_earnings,
		"living_cost_per_day": living_cost_per_day, "living_costs_paid": living_costs_paid,
		"joined_day": joined_day, "joined_followers": joined_followers, "joined_subscribers": joined_subscribers,
		"sleep_shift_hours": sleep_shift_hours, "reaction": reaction,
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
	c.age = maxi(MIN_AGE, int(data.get("age", MIN_AGE)))
	c.bio = str(data.get("bio", ""))
	c.archetype = str(data.get("archetype", ""))
	c.stats = data.get("stats", {})
	c.traits = data.get("traits", [])
	c.appearance = data.get("appearance", {})
	c.content_accepts = data.get("content_accepts", [])
	c.content_declines = data.get("content_declines", [])
	c.content_focus = str(data.get("content_focus", ""))
	var experience: Dictionary = data.get("content_experience", {})
	for content_id in experience:
		c.content_experience[str(content_id)] = clampf(float(experience[content_id]), 0.0, 1.0)
	c.content_freshness = _float_dict(data.get("content_freshness", {}))
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
	var body_data: Variant = data.get("measurements", {})
	if body_data is Dictionary and not (body_data as Dictionary).is_empty():
		c.measurements = BodyMeasurements.from_dict(body_data)
	c.contract = _dict(data.get("contract", {}))
	c.creator_earnings = float(data.get("creator_earnings", 0.0))
	c.living_cost_per_day = maxf(float(data.get("living_cost_per_day", 0.0)), 0.0)
	c.living_costs_paid = float(data.get("living_costs_paid", 0.0))
	# Saves before contracts credited everything to the house.
	c.house_earnings = float(data.get("house_earnings", data.get("lifetime_earnings", 0.0)))
	c.joined_day = int(data.get("joined_day", 1))
	c.joined_followers = float(data.get("joined_followers", data.get("followers", 0.0)))
	c.joined_subscribers = float(data.get("joined_subscribers", data.get("subscribers", 0.0)))
	c.sleep_shift_hours = float(data.get("sleep_shift_hours", 0.0))
	c.reaction = _dict(data.get("reaction", {}))
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
