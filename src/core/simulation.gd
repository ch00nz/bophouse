class_name Simulation
extends RefCounted
## Advances the world. The same code path is used for live play (small steps every frame)
## and offline catch-up (large steps), so the two can never drift apart.


## Advances `state` by `minutes` of game time in steps no larger than `max_step`.
## `output_multiplier` scales gains (cash, followers, subscribers); offline uses < 1.
## Returns totals: {cash (net: house shares credited minus running costs), gross (all creators'
## revenue), house (house shares), expenses (running costs), living_costs, followers, subscribers,
## minutes, by_creator: {id: {gross, house}}} plus optional trends_started, recovered, social.
static func advance(state: GameState, config: GameConfig, minutes: float, max_step: float = 1.0, output_multiplier: float = 1.0) -> Dictionary:
	var totals := {"cash": 0.0, "gross": 0.0, "house": 0.0, "expenses": 0.0, "living_costs": 0.0, "followers": 0.0, "subscribers": 0.0, "minutes": 0.0, "by_creator": {}}
	var step_size := maxf(max_step, 0.001)
	var remaining := minutes
	while remaining > 0.000001:
		var dt := minf(remaining, step_size)
		_step(state, config, dt, output_multiplier, totals)
		remaining -= dt
	return totals


static func _step(state: GameState, config: GameConfig, dt: float, output_multiplier: float, totals: Dictionary) -> void:
	var day_before := state.day()
	state.game_minutes += dt
	if state.day() != day_before:
		state.yesterday = state.today
		state.today = {}
	totals["minutes"] += dt
	var started := TrendSystem.advance(state, config, dt)
	if not started.is_empty():
		var all_started: Array = totals.get("trends_started", [])
		all_started.append_array(started)
		totals["trends_started"] = all_started
	# Running costs are real costs: charged in full, even while the player is away.
	var living_before := state.living_costs
	var expenses := Expenses.charge(state, config, dt)
	totals["expenses"] += expenses
	totals["living_costs"] += state.living_costs - living_before
	totals["cash"] -= expenses
	for creator in state.creators:
		_step_creator(state, config, creator, dt, output_multiplier, totals)
	var social := Relationships.step(state, config, dt)
	if not social.is_empty():
		var all_social: Array = totals.get("social", [])
		all_social.append_array(social)
		totals["social"] = all_social


static func _step_creator(state: GameState, config: GameConfig, creator: CreatorState, dt: float, output_multiplier: float, totals: Dictionary) -> void:
	var hours := dt / 60.0
	_earn(state, creator, Economy.subscription_cash_per_hour(creator, config) * hours * output_multiplier, totals)
	# Normal churn and unfollows: audiences must be kept up by working.
	var base_churn := Economy.subscriber_base_churn_per_hour(creator, config) * hours
	creator.subscribers = maxf(0.0, creator.subscribers - base_churn)
	totals["subscribers"] -= base_churn
	var unfollows := Economy.follower_decay_per_hour(creator, config) * hours
	creator.followers = maxf(0.0, creator.followers - unfollows)
	totals["followers"] -= unfollows
	_update_freshness(creator, config, hours)
	if Expenses.in_debt(state):
		creator.mood = clampf(creator.mood + config.tuning_f("expenses", "debt_mood_per_hour", -1.5) * hours, 0.0, 100.0)
	if Appearance.advance_recovery(creator, config, dt):
		var recovered: Array = totals.get("recovered", [])
		recovered.append(creator.id)
		totals["recovered"] = recovered
	# Reputation drifts back toward a baseline unless mainstream work keeps it up.
	var baseline := config.tuning_f("reputation", "baseline", 30.0)
	creator.reputation += (baseline - creator.reputation) * config.tuning_f("reputation", "decay_per_hour", 0.015) * hours
	# Subscribers who dislike her current look slowly cancel (audience loyalty).
	var churn := AudienceModel.unhappy_churn_per_hour(creator, config) * hours
	if churn > 0.0:
		creator.subscribers = maxf(0.0, creator.subscribers - churn)
		totals["subscribers"] -= churn

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
	elif not creator.content_focus.is_empty():
		# Off camera her fanbase still shifts, just more slowly.
		AudienceModel.drift_mix(creator, config, creator.content_focus, hours * config.tuning_f("loyalty", "idle_drift_factor", 0.25))

	var decision := CreatorBrain.decide(creator, state, config)
	if not decision.is_empty():
		start_activity(state, config, creator, str(decision["activity_id"]), str(decision["room_id"]))


## Sends a creator to `room_id` to perform `activity_id`, walking there if needed.
static func start_activity(state: GameState, config: GameConfig, creator: CreatorState, activity_id: String, room_id: String) -> void:
	var room := state.get_room(room_id)
	var target := creator.position
	if room != null:
		var spot := float(ActivityResolver.resolve(creator, activity_id, config, room).get("spot", 0.5))
		target = room.spot_position(free_spot(state, creator, room, spot))
	creator.target_activity_id = activity_id
	creator.target_room_id = room_id
	var path := HouseNavigator.find_path(state.rooms, config, creator.position, target)
	if HouseNavigator.path_length(path) < 0.01:
		_arrive(creator)
		return
	creator.travel_path = path
	creator.travel_progress = 0.0
	creator.room_id = ""


## Content she's making wears out; everything else recovers toward fully fresh.
static func _update_freshness(creator: CreatorState, config: GameConfig, hours: float) -> void:
	var making := ""
	if not creator.is_travelling() and ActivityResolver.is_content_driven(config.activity(creator.activity_id)):
		making = creator.content_focus
	var floor_value := config.tuning_f("freshness", "floor", 0.75)
	if not making.is_empty():
		creator.content_freshness[making] = maxf(floor_value, creator.freshness(making) - config.tuning_f("freshness", "decay_per_hour", 0.012) * hours)
	var recover := config.tuning_f("freshness", "recover_per_hour", 0.03) * hours
	for content_id in creator.content_freshness.keys():
		if content_id == making:
			continue
		var value := float(creator.content_freshness[content_id]) + recover
		if value >= 1.0:
			creator.content_freshness.erase(content_id)
		else:
			creator.content_freshness[content_id] = value


## A spot near `preferred` that isn't taken by someone already in (or heading to) the room, so
## housemates stand side by side instead of on top of each other.
static func free_spot(state: GameState, creator: CreatorState, room: RoomState, preferred: float) -> float:
	var taken: Array[float] = []
	for other in state.occupants_of(room.id):
		if other == creator:
			continue
		var at: Vector2 = other.position
		if other.is_travelling():
			at = other.travel_path[other.travel_path.size() - 1]
		taken.append((at.x - room.column) / maxf(room.width, 1.0))
	if taken.is_empty():
		return preferred
	var min_gap := 0.18
	for offset: float in [0.0, 0.2, -0.2, 0.36, -0.36, 0.5, -0.5]:
		var candidate := clampf(preferred + offset, 0.08, 0.92)
		var clear := true
		for x in taken:
			if absf(x - candidate) < min_gap:
				clear = false
				break
		if clear:
			return candidate
	return preferred


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


## Credits a creator's gross revenue: her contract share is hers, the rest goes to the house.
static func _earn(state: GameState, creator: CreatorState, amount: float, totals: Dictionary) -> void:
	var house := Contracts.credit(state, creator, amount)
	totals["cash"] += house
	totals["house"] += house
	totals["gross"] += amount
	var by_creator: Dictionary = totals["by_creator"]
	var entry: Dictionary = by_creator.get(creator.id, {"gross": 0.0, "house": 0.0})
	entry["gross"] = float(entry["gross"]) + amount
	entry["house"] = float(entry["house"]) + house
	by_creator[creator.id] = entry
