class_name CreatorBrain
extends RefCounted
## Simple need-driven state machine that picks a creator's next activity.
## Uses hysteresis (start/stop thresholds) so creators don't flicker between activities.
## Later milestones extend this with schedules, preferences, boundaries and relationships.


## Returns {"activity_id", "room_id"} for a change of activity, or {} to keep going.
static func decide(creator: CreatorState, state: GameState, config: GameConfig) -> Dictionary:
	if creator.is_travelling():
		return {}
	var desired := desired_activity(creator, state, config)
	if desired == creator.activity_id:
		return {}
	var room := find_room_for(desired, creator, state, config)
	if room == null and not str(config.activity(desired).get("room_type", "")).is_empty():
		return {}
	return {"activity_id": desired, "room_id": room.id if room != null else creator.room_id}


static func desired_activity(creator: CreatorState, state: GameState, config: GameConfig) -> String:
	var energy := creator.energy
	var mood := creator.mood
	var current := creator.activity_id
	var current_def := config.activity(current)
	var minutes := creator.activity_minutes
	var stop_energy := work_stop_energy(creator, config)

	# Keep doing restorative activities until recovered.
	if current == "sleep" and energy < config.tuning_f("brain", "sleep_until_energy", 95.0):
		return "sleep"
	if current == "socialise" and energy > stop_energy:
		var min_minutes := float(current_def.get("min_minutes", 0))
		var max_minutes := float(current_def.get("max_minutes", 0))
		var still_low := mood < config.tuning_f("brain", "relax_until_mood", 75.0)
		var under_max := max_minutes <= 0.0 or minutes < max_minutes
		if under_max and (still_low or minutes < min_minutes):
			return "socialise"

	# Urgent needs.
	if energy <= stop_energy:
		return "sleep"
	if _is_night(state.hour_of_day(), config) and energy < config.tuning_f("brain", "night_sleep_below_energy", 70.0):
		return "sleep"
	if mood <= config.tuning_f("brain", "relax_when_mood_below", 30.0):
		return "socialise"

	# Long work sessions end with a break.
	if current == "film_content":
		var max_work := float(current_def.get("max_minutes", 0))
		if max_work > 0.0 and minutes >= max_work:
			return "socialise"
	return "film_content"


## Energy level at which a creator stops working. Higher work ethic pushes on longer.
static func work_stop_energy(creator: CreatorState, config: GameConfig) -> float:
	var lazy := config.tuning_f("brain", "work_stop_energy_low_ethic", 35.0)
	var diligent := config.tuning_f("brain", "work_stop_energy_high_ethic", 15.0)
	return lerpf(lazy, diligent, clampf(creator.stat("work_ethic") / 100.0, 0.0, 1.0))


## Nearest room of the activity's type with free capacity (the creator's current room always counts).
static func find_room_for(activity_id: String, creator: CreatorState, state: GameState, config: GameConfig) -> RoomState:
	var room_type := str(config.activity(activity_id).get("room_type", ""))
	if room_type.is_empty():
		return null
	var best: RoomState = null
	var best_distance := INF
	for room in state.rooms:
		if room.type_id != room_type:
			continue
		var capacity := int(config.room_type(room.type_id).get("capacity", 1))
		var others := 0
		for occupant in state.occupants_of(room.id):
			if occupant != creator:
				others += 1
		if others >= capacity:
			continue
		var distance := absf(room.center_column() - creator.position.x) + absf(room.storey - creator.position.y) * 3.0
		if distance < best_distance:
			best_distance = distance
			best = room
	return best


static func _is_night(hour: int, config: GameConfig) -> bool:
	var start := int(config.tuning("brain", "night_start_hour", 23))
	var end := int(config.tuning("brain", "night_end_hour", 7))
	if start > end:
		return hour >= start or hour < end
	return hour >= start and hour < end
