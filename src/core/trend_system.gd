class_name TrendSystem
extends RefCounted
## Rotating social-media trends. A fixed number are active at once, each with its own countdown;
## when one expires the forecast trend replaces it and a new forecast is rolled.
## Rolls use a seeded RNG whose state is saved, so rotations are reproducible and survive reloads.


static func ensure_initialized(state: GameState, config: GameConfig) -> void:
	if config.trends.is_empty():
		return
	if state.trend_rng_seed == 0:
		state.trend_rng_seed = randi() + 1
	# Drop trends that no longer exist in data (e.g. renamed between versions).
	var kept: Array = []
	for entry: Dictionary in state.active_trends:
		if config.trends.has(str(entry.get("id", ""))):
			kept.append(entry)
	state.active_trends = kept
	# Older saves rolled much shorter trends: stretch them to the current minimum (time already
	# elapsed is kept, so a trend that was nearly over still ends first).
	for entry: Dictionary in state.active_trends:
		var duration := float(entry.get("duration_minutes", 0.0))
		var clamped := clamp_duration(duration, config)
		if not is_equal_approx(clamped, duration):
			entry["remaining_minutes"] = clampf(float(entry.get("remaining_minutes", 0.0)) + clamped - duration, 1.0, clamped)
			entry["duration_minutes"] = clamped

	var rng := _rng(state)
	var count := mini(int(config.tuning("trends", "active_count", 2)), config.trends.size())
	while state.active_trends.size() < count:
		var entry := _new_entry(rng, config, _pick(rng, config, active_ids(state)))
		# Stagger start times so trends don't all change at once.
		if not state.active_trends.is_empty():
			entry["remaining_minutes"] = float(entry["duration_minutes"]) * 0.5
		state.active_trends.append(entry)
	if not config.trends.has(state.next_trend_id) or active_ids(state).has(state.next_trend_id):
		state.next_trend_id = _pick(rng, config, active_ids(state))
	state.trend_rng_state = rng.state


## Counts down active trends and rotates expired ones. Returns ids of trends that just started.
static func advance(state: GameState, config: GameConfig, minutes: float) -> Array[String]:
	var started: Array[String] = []
	if state.active_trends.is_empty():
		return started
	var rng: RandomNumberGenerator = null
	for i in state.active_trends.size():
		var entry: Dictionary = state.active_trends[i]
		entry["remaining_minutes"] = float(entry["remaining_minutes"]) - minutes
		if float(entry["remaining_minutes"]) > 0.0:
			continue
		if rng == null:
			rng = _rng(state)
		var others := active_ids(state)
		others.erase(str(entry["id"]))
		var next_id := state.next_trend_id
		if not config.trends.has(next_id) or others.has(next_id):
			next_id = _pick(rng, config, others)
		var replacement := _new_entry(rng, config, next_id)
		# Carry overshoot so long offline steps don't stretch trends.
		replacement["remaining_minutes"] = float(replacement["remaining_minutes"]) + float(entry["remaining_minutes"])
		state.active_trends[i] = replacement
		started.append(next_id)
		var excluded := active_ids(state)
		excluded.append(str(entry["id"])) # don't immediately bring back the trend that just ended
		state.next_trend_id = _pick(rng, config, excluded)
	if rng != null:
		state.trend_rng_state = rng.state
	return started


static func active_ids(state: GameState) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in state.active_trends:
		ids.append(str(entry.get("id", "")))
	return ids


## How active trends affect `creator` making `content_id`.
## Returns {income, followers, effects: [{id, name, strength, income, followers}]}.
## Strength = content match x creator stat fit x adaptability factor.
static func modifiers(state: GameState, config: GameConfig, creator: CreatorState, content_id: String) -> Dictionary:
	var income := 1.0
	var followers := 1.0
	var effects: Array = []
	var adapt := adaptability_factor(creator, config)
	var stat_floor := config.tuning_f("trends", "stat_fit_floor", 0.5)
	for entry: Dictionary in state.active_trends:
		var trend := config.trend(str(entry.get("id", "")))
		var match_strength := float(trend.get("content", {}).get(content_id, 0.0))
		if match_strength <= 0.0:
			continue
		var stat_fit := lerpf(stat_floor, 1.0, favoured_stat_score(creator, trend))
		var strength := match_strength * stat_fit * adapt
		var trend_income := 1.0 + (float(trend.get("income", 1.0)) - 1.0) * strength
		var trend_followers := 1.0 + (float(trend.get("followers", 1.0)) - 1.0) * strength
		income *= trend_income
		followers *= trend_followers
		effects.append({
			"id": str(entry["id"]), "name": str(trend.get("name", entry["id"])),
			"strength": strength, "income": trend_income, "followers": trend_followers,
		})
	return {"income": income, "followers": followers, "effects": effects}


## 0..1 fit with the trend's favoured stats and (if any) favoured appearance tags, averaged.
static func favoured_stat_score(creator: CreatorState, trend: Dictionary) -> float:
	var stats: Array = trend.get("stats", [])
	var stat_score := 1.0
	if not stats.is_empty():
		var total := 0.0
		for stat_id in stats:
			total += creator.stat(str(stat_id))
		stat_score = clampf(total / stats.size() / 100.0, 0.0, 1.0)
	var tags: Array = trend.get("tags", [])
	if tags.is_empty():
		return stat_score
	var tag_total := 0.0
	for tag_id in tags:
		tag_total += creator.tag(str(tag_id))
	return (stat_score + clampf(tag_total / tags.size(), 0.0, 1.0)) * 0.5


## High adaptability lets a creator ride trends harder (0.6x .. 1.4x by default).
static func adaptability_factor(creator: CreatorState, config: GameConfig) -> float:
	return lerpf(config.tuning_f("trends", "min_adaptability_factor", 0.6),
		config.tuning_f("trends", "max_adaptability_factor", 1.4),
		clampf(creator.stat("adaptability") / 100.0, 0.0, 1.0))


static func _new_entry(rng: RandomNumberGenerator, config: GameConfig, trend_id: String) -> Dictionary:
	var hours: Array = config.trend(trend_id).get("duration_hours", [168, 168])
	var duration := clamp_duration(rng.randf_range(float(hours[0]), float(hours[hours.size() - 1])) * 60.0, config)
	return {"id": trend_id, "remaining_minutes": duration, "duration_minutes": duration}


## Trend length in game minutes, kept within one week .. one month (balance.json trends).
static func clamp_duration(minutes: float, config: GameConfig) -> float:
	return clampf(minutes, config.tuning_f("trends", "min_duration_hours", 168.0) * 60.0,
		config.tuning_f("trends", "max_duration_hours", 720.0) * 60.0)


static func _pick(rng: RandomNumberGenerator, config: GameConfig, excluded: Array[String]) -> String:
	var candidates: Array[String] = []
	for trend_id in config.trend_order:
		if not excluded.has(trend_id):
			candidates.append(trend_id)
	if candidates.is_empty():
		candidates = config.trend_order.duplicate()
	return candidates[rng.randi_range(0, candidates.size() - 1)]


static func _rng(state: GameState) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = state.trend_rng_seed
	if state.trend_rng_state != 0:
		rng.state = state.trend_rng_state
	return rng
