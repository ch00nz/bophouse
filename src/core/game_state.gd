class_name GameState
extends RefCounted
## The complete mutable world state. Serialisable, render-agnostic.

const MINUTES_PER_DAY := 1440.0

var cash: float = 0.0
var game_minutes: float = 0.0
var lifetime_earnings: float = 0.0
## High-water mark of real-world unix time this save has seen. Guards offline progress
## against clock manipulation: moving the clock backwards never earns anything twice.
var last_seen_unix: float = 0.0
var creators: Array[CreatorState] = []
var rooms: Array[RoomState] = []


static func new_game(config: GameConfig) -> GameState:
	var state := GameState.new()
	state.cash = config.tuning_f("economy", "starting_cash", 0.0)
	state.game_minutes = config.tuning_f("time", "start_minute_of_day", 480.0)
	for slot in config.house_layout:
		state.rooms.append(RoomState.create(
			str(slot.get("id", "")), str(slot.get("type", "")),
			int(slot.get("storey", 0)), int(slot.get("column", 0)), int(slot.get("width", 1))))
	var starting: Array = config.balance.get("starting_creators", [])
	for creator_id in starting:
		var template: Dictionary = config.creator_templates.get(str(creator_id), {})
		if template.is_empty():
			push_warning("GameState: unknown starting creator '%s'" % creator_id)
			continue
		var creator := CreatorState.from_template(template)
		var bedroom := state.first_room_of_type("bedroom")
		if bedroom != null:
			creator.room_id = bedroom.id
			creator.position = bedroom.spot_position(0.7)
		state.creators.append(creator)
	return state


func get_room(room_id: String) -> RoomState:
	for room in rooms:
		if room.id == room_id:
			return room
	return null


func first_room_of_type(type_id: String) -> RoomState:
	for room in rooms:
		if room.type_id == type_id:
			return room
	return null


func get_creator(creator_id: String) -> CreatorState:
	for creator in creators:
		if creator.id == creator_id:
			return creator
	return null


func occupants_of(room_id: String) -> Array[CreatorState]:
	var result: Array[CreatorState] = []
	for creator in creators:
		if creator.occupied_room_id() == room_id:
			result.append(creator)
	return result


func total_followers() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.followers
	return total


func total_subscribers() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.subscribers
	return total


func day() -> int:
	return int(game_minutes / MINUTES_PER_DAY) + 1


func hour_of_day() -> int:
	return int(fmod(game_minutes, MINUTES_PER_DAY) / 60.0)


func minute_of_hour() -> int:
	return int(fmod(game_minutes, 60.0))


func to_dict() -> Dictionary:
	var creator_data: Array = []
	for creator in creators:
		creator_data.append(creator.to_dict())
	var room_data: Array = []
	for room in rooms:
		room_data.append(room.to_dict())
	return {
		"cash": cash,
		"game_minutes": game_minutes,
		"lifetime_earnings": lifetime_earnings,
		"last_seen_unix": last_seen_unix,
		"creators": creator_data,
		"rooms": room_data,
	}


static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.cash = float(data.get("cash", 0))
	state.game_minutes = float(data.get("game_minutes", 0))
	state.lifetime_earnings = float(data.get("lifetime_earnings", 0))
	state.last_seen_unix = float(data.get("last_seen_unix", 0))
	for creator_data in data.get("creators", []):
		if typeof(creator_data) == TYPE_DICTIONARY:
			state.creators.append(CreatorState.from_dict(creator_data))
	for room_data in data.get("rooms", []):
		if typeof(room_data) == TYPE_DICTIONARY:
			state.rooms.append(RoomState.from_dict(room_data))
	return state
