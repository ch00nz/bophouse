class_name RoomUpgrades
extends RefCounted
## Room upgrade rules: costs and level changes come from rooms.json.


## Definition of the next level, or {} when the room is maxed or not upgradable.
static func next_level_def(config: GameConfig, room: RoomState) -> Dictionary:
	if room == null or not bool(config.room_type(room.type_id).get("upgradable", false)):
		return {}
	return config.room_level_def(room.type_id, room.level + 1)


## Cost of the next level, or -1 when no upgrade is available.
static func upgrade_cost(config: GameConfig, room: RoomState) -> float:
	var next := next_level_def(config, room)
	return -1.0 if next.is_empty() else float(next.get("cost", 0))


static func can_upgrade(state: GameState, config: GameConfig, room_id: String) -> bool:
	var cost := upgrade_cost(config, state.get_room(room_id))
	return cost >= 0.0 and state.cash >= cost


## Spends cash and raises the room level. Returns false (and changes nothing) if not possible.
static func try_upgrade(state: GameState, config: GameConfig, room_id: String) -> bool:
	if not can_upgrade(state, config, room_id):
		return false
	var room := state.get_room(room_id)
	var cost := upgrade_cost(config, room)
	state.cash -= cost
	state.spending["renovations"] = float(state.spending.get("renovations", 0.0)) + cost
	room.level += 1
	Upgrades.refresh(state, config)
	return true
