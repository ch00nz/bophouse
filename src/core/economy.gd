class_name Economy
extends RefCounted
## Pure economic formulas. All rates are per in-game hour. No side effects.
##
## Work income = (content sales + audience earnings) x multipliers, where
##   multipliers = content fit (stats the content favours) x room quality x productivity
##                 (energy & mood) x trends x experience (settling into the content).
## Subscriptions pay continuously, whatever the creator is doing.
## Follower growth = (base + viral x sqrt(followers)) x multipliers x saturation, which grows
## polynomially and flattens toward a soft cap, so there is no runaway exponential growth.


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

## Weighted stat score normalised so an all-baseline creator scores 1.0.
static func weighted_stats(creator: CreatorState, weights: Dictionary, config: GameConfig) -> float:
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


## General appeal (used by non-content activities such as socialising).
static func appeal(creator: CreatorState, config: GameConfig) -> float:
	return weighted_stats(creator, config.tuning("economy", "appeal_weights", {}), config)


## How well the creator's stats suit a content type.
static func content_fit(creator: CreatorState, content: Dictionary, config: GameConfig) -> float:
	var weights: Dictionary = content.get("stat_weights", {})
	if weights.is_empty():
		return appeal(creator, config)
	return weighted_stats(creator, weights, config)


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


## Growth slows as the audience approaches the platform's soft cap.
static func follower_saturation(followers: float, config: GameConfig) -> float:
	var soft_cap := config.tuning_f("economy", "follower_soft_cap", 250000.0)
	if soft_cap <= 0.0:
		return 1.0
	return 1.0 / (1.0 + maxf(followers, 0.0) / soft_cap)


static func follower_growth(base: float, viral: float, followers: float, multiplier: float, config: GameConfig) -> float:
	return (base + viral * sqrt(maxf(followers, 0.0))) * multiplier * follower_saturation(followers, config)


## Experience multiplier for a content type: a brand-new category runs at ramp_floor.
static func experience_multiplier(creator: CreatorState, content_id: String, config: GameConfig) -> float:
	return lerpf(config.tuning_f("content", "ramp_floor", 0.7), 1.0, creator.experience(content_id))


## Experience gained per working hour; adaptability speeds it up.
static func experience_rate_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return config.tuning_f("content", "ramp_base_per_hour", 0.08) \
		+ config.tuning_f("content", "ramp_adaptability_per_hour", 0.22) * clampf(creator.stat("adaptability") / 100.0, 0.0, 1.0)


## Recurring subscription revenue; paid regardless of current activity (the idle backbone).
static func subscription_cash_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return maxf(creator.subscribers, 0.0) * config.tuning_f("economy", "subscription_cash_per_sub_hour", 0.4)


# ---------------------------------------------------------------------------
# Rates
# ---------------------------------------------------------------------------

## Full, explainable breakdown of a creator's hourly output while making `content_id`
## (defaults to her current focus). Used by the simulation and the income UI alike.
static func work_breakdown(creator: CreatorState, state: GameState, config: GameConfig, content_id: String = "") -> Dictionary:
	if content_id.is_empty():
		content_id = creator.content_focus
	var content := config.content(content_id)
	var rates: Dictionary = content.get("rates_per_hour", {})
	var room := _room_for_content(creator, state, config, content)
	var quality := room_quality(config, room)
	var fit := content_fit(creator, content, config)
	var prod := productivity(creator, config)
	var trend := TrendSystem.modifiers(state, config, creator, content_id)
	var experience := experience_multiplier(creator, content_id, config)

	var cash_multiplier := fit * quality * prod * float(trend["income"]) * experience
	var follower_multiplier := fit * quality * prod * float(trend["followers"]) * experience
	var content_sales := float(rates.get("cash", 0.0)) * cash_multiplier
	var audience_earnings := float(rates.get("audience_cash", 0.0)) * audience_value(creator.followers, config) * cash_multiplier
	var followers := follower_growth(float(rates.get("followers", 0.0)), float(rates.get("viral", 0.0)),
		creator.followers, follower_multiplier, config)
	var target_subscribers := creator.followers * float(rates.get("subscriber_conversion", 0.0))
	var gap := target_subscribers - creator.subscribers
	var subscribers := gap * float(rates.get("conversion_speed", 0.0)) * quality
	if gap < 0.0:
		# Fans cancel more slowly than they sign up, so switching strategy isn't brutally punished.
		subscribers = gap * config.tuning_f("economy", "subscriber_churn_speed", 0.04)

	var energy := float(rates.get("energy", 0.0))
	energy *= stamina_drain_factor(creator, config) if energy < 0.0 else quality
	var mood := float(rates.get("mood", 0.0))
	var loved := ContentRules.loves(creator, content_id)
	if loved:
		mood += config.tuning_f("economy", "loved_content_mood_per_hour", 2.0)

	return {
		"content_id": content_id,
		"room_id": room.id if room != null else "",
		"cash": content_sales + audience_earnings,
		"content_sales": content_sales,
		"audience_earnings": audience_earnings,
		"subscriptions": subscription_cash_per_hour(creator, config),
		"followers": followers,
		"subscribers": subscribers,
		"target_subscribers": target_subscribers,
		"energy": energy,
		"mood": mood,
		"loved": loved,
		"multipliers": {
			"fit": fit, "room": quality, "productivity": prod,
			"trend_income": float(trend["income"]), "trend_followers": float(trend["followers"]),
			"experience": experience,
		},
		"trend_effects": trend["effects"],
	}


## Hourly rates for a non-content activity (rest, socialise...).
static func activity_rates(creator: CreatorState, activity: Dictionary, quality: float, config: GameConfig) -> Dictionary:
	var rates: Dictionary = activity.get("rates_per_hour", {})
	var output := appeal(creator, config) * quality * productivity(creator, config)
	var energy := float(rates.get("energy", 0.0))
	energy *= stamina_drain_factor(creator, config) if energy < 0.0 else quality
	var mood := float(rates.get("mood", 0.0))
	if mood > 0.0:
		mood *= quality
	return {
		"cash": float(rates.get("cash", 0.0)) * output,
		"followers": follower_growth(float(rates.get("followers", 0.0)), float(rates.get("viral", 0.0)), creator.followers, output, config),
		"subscribers": 0.0,
		"energy": energy,
		"mood": mood,
	}


## What the creator is producing right now (zero while walking).
static func current_rates(creator: CreatorState, state: GameState, config: GameConfig) -> Dictionary:
	if creator.is_travelling():
		return {"cash": 0.0, "followers": 0.0, "subscribers": 0.0, "energy": 0.0, "mood": 0.0}
	var activity := config.activity(creator.activity_id)
	if ActivityResolver.is_content_driven(activity):
		return work_breakdown(creator, state, config)
	return activity_rates(creator, activity, room_quality(config, state.get_room(creator.room_id)), config)


## Estimated current cash per hour for one creator (for UI display).
static func creator_cash_per_hour(creator: CreatorState, state: GameState, config: GameConfig) -> float:
	return subscription_cash_per_hour(creator, config) + float(current_rates(creator, state, config)["cash"])


static func house_cash_per_hour(state: GameState, config: GameConfig) -> float:
	var total := 0.0
	for creator in state.creators:
		total += creator_cash_per_hour(creator, state, config)
	return total


## The room a creator would use for this content: her current room if it fits, else the first match.
static func _room_for_content(creator: CreatorState, state: GameState, config: GameConfig, content: Dictionary) -> RoomState:
	var room_type := str(content.get("activity", {}).get("room_type", ""))
	var current := state.get_room(creator.room_id)
	if current != null and current.type_id == room_type:
		return current
	if not creator.target_room_id.is_empty():
		var target := state.get_room(creator.target_room_id)
		if target != null and target.type_id == room_type:
			return target
	return state.first_room_of_type(room_type)
