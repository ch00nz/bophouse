class_name Simulation
extends RefCounted
## Advances the world. The same code path is used for live play (small steps every frame)
## and offline catch-up (large steps), so the two can never drift apart.


## Advances `state` by `minutes` of game time in steps no larger than `max_step`.
## `output_multiplier` scales gains (cash, followers, subscribers); offline uses < 1.
## Returns totals gained: {cash, followers, subscribers, minutes}.
static func advance(state: GameState, config: GameConfig, minutes: float, max_step: float = 1.0, output_multiplier: float = 1.0) -> Dictionary:
	var totals := {"cash": 0.0, "followers": 0.0, "subscribers": 0.0, "minutes": 0.0}
	var step_size := maxf(max_step, 0.001)
	var remaining := minutes
	while remaining > 0.000001:
		var dt := minf(remaining, step_size)
		_step(state, config, dt, output_multiplier, totals)
		remaining -= dt
	return totals


static func _step(state: GameState, config: GameConfig, dt: float, output_multiplier: float, totals: Dictionary) -> void:
	state.game_minutes += dt
	totals["minutes"] += dt
	var started := TrendSystem.advance(state, config, dt)
	if not started.is_empty():
		var all_started: Array = totals.get("trends_started", [])
		all_started.append_array(started)
		totals["trends_started"] = all_started
	for creator in state.creators:
		_step_creator(state, config, creator, dt, output_multiplier, totals)


static func _step_creator(state: GameState, config: GameConfig, creator: CreatorState, dt: float, output_multiplier: float, totals: Dictionary) -> void:
	var hours := dt / 60.0
	_earn(state, creator, Economy.subscription_cash_per_hour(creator, config) * hours * output_multiplier, totals)
	if Appearance.advance_recovery(creator, config, dt):
		var recovered: Array = totals.get("recovered", [])
		recovered.append(creator.id)
		totals["recovered"] = recovered
	# Reputation drifts back toward a baseline unless mainstream work keeps it up.
	var baseline := config.tuning_f("reputation", "baseline", 30.0)
	creator.reputation += (baseline - creator.reputation) * config.tuning_f("reputation", "decay_per_hour", 0.015) * hours

	if creator.is_travelling():
		creator.energy = clampf(creator.energy + config.tuning_f("movement", "energy_per_hour", -2.0) * hours, 0.0, 100.0)
		_advance_travel(creator, config, dt)
		return

	var rates := Economy.current_rates(creator, state, config)
	_earn(state, creator, float(rates["cash"]) * hours * output_multiplier, totals)

	var follower_gain := float(rates["followers"]) * hours * output_multiplier
	creator.followers = maxf(0.0, creator.followers + follower_gain)
	totals["followers"] += follower_gain

	var previous_subs := creator.subscribers
	creator.subscribers = clampf(creator.subscribers + float(rates["subscribers"]) * hours * output_multiplier, 0.0, creator.followers)
	totals["subscribers"] += creator.subscribers - previous_subs

	creator.energy = clampf(creator.energy + float(rates["energy"]) * hours, 0.0, 100.0)
	creator.mood = clampf(creator.mood + float(rates["mood"]) * hours, 0.0, 100.0)
	creator.reputation = clampf(creator.reputation + float(rates.get("reputation", 0.0)) * hours, 0.0, 100.0)
	creator.activity_minutes += dt
	if ActivityResolver.is_content_driven(config.activity(creator.activity_id)) and not creator.content_focus.is_empty():
		var gained := Economy.experience_rate_per_hour(creator, config) * hours
		creator.content_experience[creator.content_focus] = minf(1.0, creator.experience(creator.content_focus) + gained)
		AudienceModel.drift_mix(creator, config, creator.content_focus, hours)

	var decision := CreatorBrain.decide(creator, state, config)
	if not decision.is_empty():
		start_activity(state, config, creator, str(decision["activity_id"]), str(decision["room_id"]))


## Sends a creator to `room_id` to perform `activity_id`, walking there if needed.
static func start_activity(state: GameState, config: GameConfig, creator: CreatorState, activity_id: String, room_id: String) -> void:
	var room := state.get_room(room_id)
	var target := creator.position
	if room != null:
		target = room.spot_position(float(ActivityResolver.resolve(creator, activity_id, config, room).get("spot", 0.5)))
	creator.target_activity_id = activity_id
	creator.target_room_id = room_id
	var path := HouseNavigator.find_path(state.rooms, config, creator.position, target)
	if HouseNavigator.path_length(path) < 0.01:
		_arrive(creator)
		return
	creator.travel_path = path
	creator.travel_progress = 0.0
	creator.room_id = ""


static func _advance_travel(creator: CreatorState, config: GameConfig, dt: float) -> void:
	creator.travel_progress += config.tuning_f("movement", "walk_cells_per_minute", 0.3) * dt
	if creator.travel_progress >= HouseNavigator.path_length(creator.travel_path):
		creator.position = creator.travel_path[creator.travel_path.size() - 1]
		_arrive(creator)
	else:
		creator.position = HouseNavigator.point_along(creator.travel_path, creator.travel_progress)


static func _arrive(creator: CreatorState) -> void:
	creator.travel_path = []
	creator.travel_progress = 0.0
	creator.activity_id = creator.target_activity_id
	creator.room_id = creator.target_room_id
	if creator.activity_id == CreatorBrain.WORK:
		creator.last_work_room_id = creator.room_id
	creator.activity_minutes = 0.0
	creator.target_activity_id = ""
	creator.target_room_id = ""


static func _earn(state: GameState, creator: CreatorState, amount: float, totals: Dictionary) -> void:
	state.cash += amount
	state.lifetime_earnings += amount
	creator.lifetime_earnings += amount
	totals["cash"] += amount
