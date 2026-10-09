class_name RoomPlanner
extends RefCounted
## Decides who may use which room for what, and where a creator should work.
## Generic for any number of creators and rooms (no special cases per creator).
##
## Rules:
##  - room capacity is never exceeded (people already there or walking there count);
##  - private rooms (bedrooms) can only be filmed in by their owner, and only residents sleep there;
##  - exclusive activities (most adult content) need the room to themselves;
##  - nobody films where someone else is sleeping/recovering ("quiet"), and nobody sleeps where
##    someone else is filming.
## Stability: a work session keeps its room; a new session only moves to another room if it is
## clearly better than her last work room (balance rooms.switch_threshold).


## Whether `creator` may do `activity_id` in `room` right now. For work, `content_id` defaults to her focus.
static func can_use(state: GameState, config: GameConfig, creator: CreatorState, room: RoomState, activity_id: String, content_id: String = "") -> bool:
	if room == null:
		return false
	var room_type := config.room_type(room.type_id)
	var others := _others_in(state, room, creator)
	if others.size() >= int(room_type.get("capacity", 1)):
		return false
	var working := ActivityResolver.is_content_driven(config.activity(activity_id))
	if content_id.is_empty():
		content_id = creator.content_focus
	if working:
		if not RoomProduction.supports(config, room, content_id):
			return false
		if bool(room_type.get("private", false)) and creator.home_room_id != room.id:
			return false
	var mine := ActivityResolver.resolve(creator, activity_id, config, room, content_id)
	var exclusive := bool(mine.get("exclusive", false))
	var quiet := bool(mine.get("quiet", false))
	for other in others:
		var other_activity := other.target_activity_id if other.is_travelling() else other.activity_id
		var theirs := ActivityResolver.resolve(other, other_activity, config, room)
		var they_work := ActivityResolver.is_content_driven(config.activity(other_activity))
		if exclusive or bool(theirs.get("exclusive", false)):
			return false
		if working and bool(theirs.get("quiet", false)):
			return false
		if quiet and they_work:
			return false
	return true


## Value of working in a room: income plus audience growth, times her comfort there.
static func work_score(creator: CreatorState, state: GameState, config: GameConfig, room: RoomState, content_id: String = "") -> float:
	if content_id.is_empty():
		content_id = creator.content_focus
	var b := Economy.work_breakdown(creator, state, config, content_id, room)
	var value := float(b["cash"]) + float(b["followers"]) * 0.5 + maxf(float(b["subscribers"]), 0.0) * 2.0
	return maxf(value, 0.01) * float(creator.room_preferences.get(room.type_id, 1.0))


## Room for a new work session, or null if nowhere is available.
static func choose_work_room(creator: CreatorState, state: GameState, config: GameConfig) -> RoomState:
	var best: RoomState = null
	var best_score := -INF
	var last: RoomState = null
	var last_score := -INF
	for room in state.rooms:
		if not can_use(state, config, creator, room, CreatorBrain.WORK):
			continue
		var score := work_score(creator, state, config, room)
		if score > best_score:
			best_score = score
			best = room
		if room.id == creator.last_work_room_id:
			last = room
			last_score = score
	# Stick with the familiar room unless another is clearly better (no flip-flopping over pennies).
	if last != null and last_score >= best_score * (1.0 - config.tuning_f("rooms", "switch_threshold", 0.15)):
		return last
	return best


## Best room to make `content_id` in right now (no stability rule). Used for previews/estimates.
static func best_room_for(creator: CreatorState, state: GameState, config: GameConfig, content_id: String) -> RoomState:
	var best: RoomState = null
	var best_score := -INF
	for room in state.rooms:
		if not can_use(state, config, creator, room, CreatorBrain.WORK, content_id):
			continue
		var score := RoomProduction.multiplier(config, room, content_id) * float(creator.room_preferences.get(room.type_id, 1.0))
		if score > best_score:
			best_score = score
			best = room
	if best == null:
		# Everything busy: estimate with the best supporting room anyway.
		for room in state.rooms:
			if RoomProduction.supports(config, room, content_id) and (best == null
					or RoomProduction.multiplier(config, room, content_id) > RoomProduction.multiplier(config, best, content_id)):
				best = room
	return best


## Where to sleep or recover: her own bedroom if possible, else the nearest usable room of that type.
static func choose_rest_room(creator: CreatorState, state: GameState, config: GameConfig, activity_id: String) -> RoomState:
	var home := state.get_room(creator.home_room_id)
	if home != null and can_use(state, config, creator, home, activity_id):
		return home
	var room_type := ActivityResolver.room_type(creator, activity_id, config)
	var best: RoomState = null
	var best_distance := INF
	for room in state.rooms:
		if room.type_id != room_type or not can_use(state, config, creator, room, activity_id):
			continue
		# Never borrow someone else's bed.
		if bool(config.room_type(room.type_id).get("private", false)) and not Housing.residents_of(state, room.id).is_empty():
			continue
		var distance := absf(room.center_column() - creator.position.x) + absf(room.storey - creator.position.y) * 3.0
		if distance < best_distance:
			best_distance = distance
			best = room
	return best


## Gives every creator without a valid home a bedroom with a free bed (rooms.json "beds").
## Also fixes over-full bedrooms (e.g. old saves), keeping the first resident.
static func assign_home_rooms(state: GameState, config: GameConfig) -> void:
	var kept := {}
	for creator in state.creators:
		var home := state.get_room(creator.home_room_id)
		if home != null and Housing.beds(config, home) > int(kept.get(home.id, 0)):
			kept[home.id] = int(kept.get(home.id, 0)) + 1
			continue
		creator.home_room_id = ""
	for creator in state.creators:
		if not creator.home_room_id.is_empty():
			continue
		creator.home_room_id = ""
		var best: RoomState = null
		var best_residents := 1 << 30
		for room in state.rooms:
			if not bool(config.room_type(room.type_id).get("private", false)):
				continue
			var residents := 0
			for other in state.creators:
				if other.home_room_id == room.id:
					residents += 1
			if residents < Housing.beds(config, room) and residents < best_residents:
				best = room
				best_residents = residents
		if best != null:
			creator.home_room_id = best.id


static func _others_in(state: GameState, room: RoomState, creator: CreatorState) -> Array[CreatorState]:
	var others: Array[CreatorState] = []
	for occupant in state.occupants_of(room.id):
		if occupant != creator:
			others.append(occupant)
	return others
