class_name Economy
extends RefCounted
## Pure economic formulas. All rates are per in-game hour. No side effects.
##
## Activity output = (base + audience-scaled term) x appeal x room quality x productivity x trend.
## Followers (reach) and subscribers (paying fans) are tracked separately: subscribers
## converge toward followers x conversion rate while the creator produces content.


## Weighted stat appeal, normalised so an all-baseline creator scores 1.0.
static func appeal(creator: CreatorState, config: GameConfig) -> float:
	var weights: Dictionary = config.tuning("economy", "appeal_weights", {})
	var baseline := config.tuning_f("economy", "stat_baseline", 50.0)
	var total := 0.0
	var weight_sum := 0.0
	for stat_name in weights:
		var weight := float(weights[stat_name])
		total += creator.stat(str(stat_name)) * weight
		weight_sum += weight
	if weight_sum <= 0.0 or baseline <= 0.0:
		return 1.0
	return (total / weight_sum) / baseline


static func room_quality(config: GameConfig, room: RoomState) -> float:
	if room == null:
		return 1.0
	return float(config.room_level_def(room.type_id, room.level).get("quality", 1.0))


## Tired or unhappy creators produce less. Ranges from (min_energy x min_mood) to 1.0.
static func productivity(creator: CreatorState, config: GameConfig) -> float:
	var min_energy := config.tuning_f("economy", "min_energy_efficiency", 0.4)
	var min_mood := config.tuning_f("economy", "min_mood_efficiency", 0.6)
	var energy_eff := lerpf(min_energy, 1.0, clampf(creator.energy / 100.0, 0.0, 1.0))
	var mood_eff := lerpf(min_mood, 1.0, clampf(creator.mood / 100.0, 0.0, 1.0))
	return energy_eff * mood_eff


## Multiplier on energy drain; higher stamina drains slower.
static func stamina_drain_factor(creator: CreatorState, config: GameConfig) -> float:
	var base := config.tuning_f("economy", "stamina_drain_base", 1.5)
	return maxf(0.2, base - creator.stat("stamina") / 100.0)


## Diminishing-returns audience size used for audience-scaled income.
static func audience_value(followers: float, config: GameConfig) -> float:
	return pow(maxf(followers, 0.0), config.tuning_f("economy", "audience_exponent", 0.85))


## Hourly rates for a creator doing `activity` in a room of the given quality.
## Returns {cash, followers, subscribers, energy, mood}.
static func activity_rates(creator: CreatorState, activity: Dictionary, quality: float, config: GameConfig, trend_multiplier: float = 1.0) -> Dictionary:
	var rates: Dictionary = activity.get("rates_per_hour", {})
	var output := appeal(creator, config) * quality * productivity(creator, config) * trend_multiplier

	var cash := (float(rates.get("cash", 0.0))
		+ float(rates.get("audience_cash", 0.0)) * audience_value(creator.followers, config)) * output
	var followers := (float(rates.get("followers", 0.0))
		+ float(rates.get("viral_rate", 0.0)) * creator.followers) * output

	var target_subscribers := creator.followers * config.tuning_f("economy", "subscriber_conversion", 0.04)
	var subscribers := (target_subscribers - creator.subscribers) \
		* float(rates.get("subscriber_conversion_rate", 0.0)) * quality

	var energy := float(rates.get("energy", 0.0))
	energy *= stamina_drain_factor(creator, config) if energy < 0.0 else quality
	var mood := float(rates.get("mood", 0.0))
	if mood > 0.0:
		mood *= quality

	return {"cash": cash, "followers": followers, "subscribers": subscribers, "energy": energy, "mood": mood}


## Recurring subscription revenue; paid regardless of current activity (the idle backbone).
static func subscription_cash_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return maxf(creator.subscribers, 0.0) * config.tuning_f("economy", "subscription_cash_per_sub_hour", 0.4)


## Estimated current cash per hour for one creator (for UI display).
static func creator_cash_per_hour(creator: CreatorState, state: GameState, config: GameConfig) -> float:
	var total := subscription_cash_per_hour(creator, config)
	if not creator.is_travelling():
		var room := state.get_room(creator.room_id)
		var rates := activity_rates(creator, config.activity(creator.activity_id), room_quality(config, room), config)
		total += float(rates["cash"])
	return total


static func house_cash_per_hour(state: GameState, config: GameConfig) -> float:
	var total := 0.0
	for creator in state.creators:
		total += creator_cash_per_hour(creator, state, config)
	return total
