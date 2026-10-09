class_name Economy
extends RefCounted
## Pure economic formulas. All rates are per in-game hour. No side effects.
##
## Work income = (content sales + audience earnings) x multipliers, where
##   multipliers = content fit (stats the content favours) x room quality x productivity
##                 (energy & mood) x trends x experience (settling into the content).
## Subscriptions pay continuously, whatever the creator is doing.
## Follower growth = (base + viral x sqrt(followers)) x multipliers x saturation, which grows
## polynomially and flattens toward a soft cap; a daily unfollow rate gives every audience a natural
## ceiling. Subscribers churn daily and must be kept up by working. Repeating the same content wears
## out its freshness. Equipment upgrades add (diminishing) multipliers. No runaway exponential growth.


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
## Scaled by fan value: who her subscribers are and how much they like her current look.
static func subscription_cash_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return maxf(creator.subscribers, 0.0) * config.tuning_f("economy", "subscription_cash_per_sub_hour", 0.3) \
		* AudienceModel.fan_value(creator, config)


## Reputation (0..100) makes followers more willing to subscribe.
static func reputation_conversion_factor(creator: CreatorState, config: GameConfig) -> float:
	return lerpf(config.tuning_f("reputation", "min_conversion_factor", 0.6),
		config.tuning_f("reputation", "max_conversion_factor", 1.4), clampf(creator.reputation / 100.0, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Rates
# ---------------------------------------------------------------------------

## Full, explainable breakdown of a creator's hourly output while making `content_id`
## (defaults to her current focus) in `room` (defaults to the room she's actually using, or the
## best available one for estimates). Used by the simulation and the income UI alike.
static func work_breakdown(creator: CreatorState, state: GameState, config: GameConfig, content_id: String = "", room: RoomState = null) -> Dictionary:
	if content_id.is_empty():
		content_id = creator.content_focus
	var content := config.content(content_id)
	var rates: Dictionary = content.get("rates_per_hour", {})
	if room == null:
		room = _room_for_content(creator, state, config, content_id)
	# Production quality of the actual room for this content (equipment, lighting, decor, privacy).
	var quality := RoomProduction.multiplier(config, room, content_id) if room != null else config.tuning_f("rooms", "min_production", 0.6)
	var time_of_day := time_multiplier(content, state.hour_of_day())
	var fit := content_fit(creator, content, config)
	var prod := productivity(creator, config)
	var trend := TrendSystem.modifiers(state, config, creator, content_id)
	var experience := experience_multiplier(creator, content_id, config)
	var market := AudienceModel.market(creator.appearance_tags, content_id, config)
	var audience_fit := float(market["multiplier"])
	var recovery := Appearance.recovery_output(creator, config)
	var freshness := creator.freshness(content_id)
	var gear_income := Upgrades.content_income_multiplier(state, config, content_id)
	var gear_followers := Upgrades.content_follower_multiplier(state, config, content_id)

	var common := fit * quality * prod * experience * audience_fit * recovery * time_of_day * freshness
	var cash_multiplier := common * float(trend["income"]) * gear_income
	var follower_multiplier := common * float(trend["followers"]) * gear_followers
	var content_sales := float(rates.get("cash", 0.0)) * cash_multiplier
	var audience_earnings := float(rates.get("audience_cash", 0.0)) * audience_value(creator.followers, config) * cash_multiplier
	var custom_sales := float(rates.get("per_subscriber_cash", 0.0)) * maxf(creator.subscribers, 0.0) * cash_multiplier
	var fees := float(rates.get("fee_per_hour", 0.0))
	var followers := follower_growth(float(rates.get("followers", 0.0)), float(rates.get("viral", 0.0)),
		creator.followers, follower_multiplier, config)

	# Subscribers converge toward a target set by followers, content, reputation and audience fit.
	# Content without a conversion rate (e.g. customs) leaves the subscriber count alone.
	var target_subscribers := creator.subscribers
	var subscribers := 0.0
	if rates.has("subscriber_conversion"):
		target_subscribers = creator.followers * float(rates["subscriber_conversion"]) \
			* reputation_conversion_factor(creator, config) * audience_fit
		var gap := target_subscribers - creator.subscribers
		subscribers = gap * float(rates.get("conversion_speed", 0.0)) * quality
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
		"cash": content_sales + audience_earnings + custom_sales - fees,
		"content_sales": content_sales,
		"audience_earnings": audience_earnings,
		"custom_sales": custom_sales,
		"fees": fees,
		"subscriptions": subscription_cash_per_hour(creator, config),
		"fan_value": AudienceModel.fan_value(creator, config),
		"reputation": float(rates.get("reputation", 0.0)),
		"market": market,
		"recovering": creator.is_recovering(),
		"followers": followers,
		"subscribers": subscribers,
		"target_subscribers": target_subscribers,
		"energy": energy,
		"mood": mood,
		"loved": loved,
		"multipliers": {
			"fit": fit, "room": quality, "productivity": prod,
			"trend_income": float(trend["income"]), "trend_followers": float(trend["followers"]),
			"experience": experience, "audience_fit": audience_fit, "recovery": recovery,
			"time_of_day": time_of_day, "freshness": freshness, "gear_income": gear_income, "gear_followers": gear_followers,
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
		"reputation": 0.0,
	}


## What the creator is producing right now (zero while walking).
static func current_rates(creator: CreatorState, state: GameState, config: GameConfig) -> Dictionary:
	if creator.is_travelling():
		return {"cash": 0.0, "followers": 0.0, "subscribers": 0.0, "energy": 0.0, "mood": 0.0, "reputation": 0.0}
	var activity := config.activity(creator.activity_id)
	if ActivityResolver.is_content_driven(activity):
		return work_breakdown(creator, state, config)
	var rates := activity_rates(creator, activity, room_quality(config, state.get_room(creator.room_id)), config)
	rates["cash"] = float(rates["cash"]) + passive_sales_per_hour(creator, state, config, activity)
	return rates


## Overnight sales: while she sleeps, content she has already posted keeps selling at a share
## (activity passive_sales_fraction) of what her content focus earns now. Cash only.
static func passive_sales_per_hour(creator: CreatorState, state: GameState, config: GameConfig, activity: Dictionary) -> float:
	var fraction := float(activity.get("passive_sales_fraction", 0.0))
	if fraction <= 0.0 or creator.content_focus.is_empty():
		return 0.0
	return fraction * maxf(float(work_breakdown(creator, state, config)["cash"]), 0.0)


## Estimated current gross revenue per hour for one creator (before the contract split).
static func creator_cash_per_hour(creator: CreatorState, state: GameState, config: GameConfig) -> float:
	return subscription_cash_per_hour(creator, config) + float(current_rates(creator, state, config)["cash"])


## The house's share of one creator's current revenue per hour.
static func creator_house_cash_per_hour(creator: CreatorState, state: GameState, config: GameConfig) -> float:
	return creator_cash_per_hour(creator, state, config) * creator.house_share()


## What the player is earning per hour right now: the house share of every creator's revenue.
static func house_cash_per_hour(state: GameState, config: GameConfig) -> float:
	var total := 0.0
	for creator in state.creators:
		total += creator_house_cash_per_hour(creator, state, config)
	return total


## The house's running costs per hour (rent, utilities, maintenance, living costs).
static func expenses_per_hour(state: GameState, config: GameConfig) -> float:
	return Expenses.total_per_day(state, config) / 24.0


## The player's net income per hour right now: house shares minus running costs.
static func house_profit_per_hour(state: GameState, config: GameConfig) -> float:
	return house_cash_per_hour(state, config) - expenses_per_hour(state, config)


## Followers lost per hour to unfollows (gives audiences a natural ceiling).
static func follower_decay_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return maxf(creator.followers, 0.0) * config.tuning_f("economy", "follower_decay_per_day", 0.0) / 24.0


## Subscribers cancelling per hour regardless of what she does (normal churn).
static func subscriber_base_churn_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return maxf(creator.subscribers, 0.0) * config.tuning_f("economy", "subscriber_base_churn_per_day", 0.0) / 24.0


## Combined gross revenue per hour of every creator (before splits).
static func gross_cash_per_hour(state: GameState, config: GameConfig) -> float:
	var total := 0.0
	for creator in state.creators:
		total += creator_cash_per_hour(creator, state, config)
	return total


## Time-of-day multiplier: content can peak at certain hours (e.g. evening livestreams).
static func time_multiplier(content: Dictionary, hour: int) -> float:
	var peak: Array = content.get("peak_hours", [])
	if peak.size() < 2:
		return 1.0
	var start := int(peak[0])
	var end := int(peak[1])
	var in_peak := (hour >= start and hour < end) if start <= end else (hour >= start or hour < end)
	return float(content.get("peak_multiplier", 1.0)) if in_peak else 1.0


## The room this content is (or would be) made in: the room she's actually working in, the room
## she's walking to for work, else the best room available to her.
static func _room_for_content(creator: CreatorState, state: GameState, config: GameConfig, content_id: String) -> RoomState:
	var making_it := content_id == creator.content_focus
	if making_it and creator.is_travelling() and creator.target_activity_id == CreatorBrain.WORK:
		var target := state.get_room(creator.target_room_id)
		if RoomProduction.supports(config, target, content_id):
			return target
	if making_it and not creator.is_travelling() and creator.activity_id == CreatorBrain.WORK:
		var current := state.get_room(creator.room_id)
		if RoomProduction.supports(config, current, content_id):
			return current
	return RoomPlanner.best_room_for(creator, state, config, content_id)
