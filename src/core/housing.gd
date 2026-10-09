class_name Housing
extends RefCounted
## House capacity, bedroom ownership and building on empty lots.
## Each creator lives in her own bedroom ("beds" in rooms.json); recruiting needs a free one.
## Capacity = min(balance housing.max_residents, total beds). Bedrooms can be built on empty lots;
## each new room costs more than the last (housing.build_cost_growth).


static func beds(config: GameConfig, room: RoomState) -> int:
	return int(config.room_type(room.type_id).get("beds", 0)) if room != null else 0


static func residents_of(state: GameState, room_id: String) -> Array[CreatorState]:
	var result: Array[CreatorState] = []
	for creator in state.creators:
		if creator.home_room_id == room_id:
			result.append(creator)
	return result


static func total_beds(state: GameState, config: GameConfig) -> int:
	var total := 0
	for room in state.rooms:
		total += beds(config, room)
	return total


static func capacity(state: GameState, config: GameConfig) -> int:
	return mini(int(config.tuning("housing", "max_residents", 6)), total_beds(state, config))


## Bedrooms with a free bed, in house order.
static func free_bedrooms(state: GameState, config: GameConfig) -> Array[RoomState]:
	var result: Array[RoomState] = []
	for room in state.rooms:
		var bed_count := beds(config, room)
		if bed_count > 0 and residents_of(state, room.id).size() < bed_count:
			result.append(room)
	return result


## Empty string when another creator can move in, else a player-facing explanation.
static func vacancy_problem(state: GameState, config: GameConfig) -> String:
	var max_residents := int(config.tuning("housing", "max_residents", 6))
	if state.creators.size() >= max_residents:
		return "The house is at its limit of %d residents." % max_residents
	if free_bedrooms(state, config).is_empty():
		if not buildable_lots(state, config, "bedroom").is_empty():
			return "No free bedroom. Build a bedroom on an empty lot first."
		return "No free bedroom and no space left to build one."
	return ""


static func has_vacancy(state: GameState, config: GameConfig) -> bool:
	return vacancy_problem(state, config).is_empty()


# ---------------------------------------------------------------------------
# Building
# ---------------------------------------------------------------------------

static func build_options(config: GameConfig, room: RoomState) -> Array:
	return config.room_type(room.type_id).get("build_options", []) if room != null else []


static func buildable_lots(state: GameState, config: GameConfig, type_id: String) -> Array[RoomState]:
	var result: Array[RoomState] = []
	for room in state.rooms:
		if build_options(config, room).has(type_id):
			result.append(room)
	return result


static func build_cost(state: GameState, config: GameConfig, type_id: String) -> float:
	var base := float(config.room_type(type_id).get("build_cost", 0.0))
	return roundf(base * (1.0 + config.tuning_f("housing", "build_cost_growth", 0.6) * state.rooms_built))


## {ok, reason, cost}
static func check_build(state: GameState, config: GameConfig, room_id: String, type_id: String) -> Dictionary:
	var room := state.get_room(room_id)
	var cost := build_cost(state, config, type_id)
	if room == null or not build_options(config, room).has(type_id):
		return {"ok": false, "reason": "Can't build that here", "cost": cost}
	if state.cash < cost:
		return {"ok": false, "reason": "Need %s more" % Fmt.money(cost - state.cash), "cost": cost}
	return {"ok": true, "reason": "", "cost": cost}


## Converts an empty lot into a level-1 room of `type_id`. Returns check_build()'s result.
static func build(state: GameState, config: GameConfig, room_id: String, type_id: String) -> Dictionary:
	var result := check_build(state, config, room_id, type_id)
	if not bool(result["ok"]):
		return result
	var room := state.get_room(room_id)
	state.cash -= float(result["cost"])
	state.build_costs += float(result["cost"])
	state.rooms_built += 1
	room.type_id = type_id
	room.level = 1
	Upgrades.refresh(state, config)
	return result


# ---------------------------------------------------------------------------
# Bedroom assignment
# ---------------------------------------------------------------------------

## Moves a creator into a bedroom. If it's someone else's, the two swap (nobody is left homeless).
## Returns {ok, reason, swapped_with}.
static func assign_bedroom(state: GameState, config: GameConfig, creator: CreatorState, room_id: String) -> Dictionary:
	var room := state.get_room(room_id)
	if room == null or beds(config, room) <= 0:
		return {"ok": false, "reason": "That's not a bedroom", "swapped_with": ""}
	if creator.home_room_id == room_id:
		return {"ok": false, "reason": "Already her bedroom", "swapped_with": ""}
	var residents := residents_of(state, room_id)
	var swapped := ""
	if residents.size() >= beds(config, room):
		var other: CreatorState = residents[0]
		other.home_room_id = creator.home_room_id
		swapped = other.id
	creator.home_room_id = room_id
	return {"ok": true, "reason": "", "swapped_with": swapped}
