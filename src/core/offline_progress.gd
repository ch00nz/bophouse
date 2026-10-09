class_name OfflineProgress
extends RefCounted
## Credits time spent away from the game (closed app, hidden browser tab, sleeping laptop).
## Bounded by a cap and an efficiency factor. Uses state.last_seen_unix as a high-water mark,
## so rolling the system clock back and forth can never grant the same time twice.
## Major story events (future milestone) must be queued for the player, not resolved here.


## Real seconds that should be credited, clamped to [0, max_seconds].
static func creditable_seconds(last_seen_unix: float, now_unix: float, max_seconds: float) -> float:
	if last_seen_unix <= 0.0:
		return 0.0
	return clampf(now_unix - last_seen_unix, 0.0, maxf(max_seconds, 0.0))


## Simulates the time since state.last_seen_unix and advances the high-water mark.
## Returns a summary for the "welcome back" popup.
static func apply(state: GameState, config: GameConfig, now_unix: float) -> Dictionary:
	var max_seconds := config.tuning_f("offline", "max_seconds", 28800.0)
	var raw_seconds := now_unix - state.last_seen_unix if state.last_seen_unix > 0.0 else 0.0
	var seconds := creditable_seconds(state.last_seen_unix, now_unix, max_seconds)
	# The house runs slower while you're away (offline.time_scale), so playing always beats reopening.
	var minutes := seconds * config.tuning_f("time", "game_minutes_per_real_second", 2.0) * config.tuning_f("offline", "time_scale", 1.0)
	var totals := {}
	if minutes > 0.0:
		totals = Simulation.advance(state, config, minutes,
			config.tuning_f("time", "offline_step_minutes", 5.0),
			config.tuning_f("offline", "efficiency", 0.75))
	state.last_seen_unix = maxf(state.last_seen_unix, now_unix)
	return {
		"real_seconds": seconds,
		"raw_seconds": raw_seconds,
		"capped": raw_seconds > max_seconds,
		"game_minutes": minutes,
		"cash": float(totals.get("cash", 0.0)),
		"gross": float(totals.get("gross", 0.0)),
		"living_costs": float(totals.get("living_costs", 0.0)),
		"house": float(totals.get("house", 0.0)),
		"expenses": float(totals.get("expenses", 0.0)),
		"by_creator": totals.get("by_creator", {}),
		"social": (totals.get("social", []) as Array).size(),
		"followers": float(totals.get("followers", 0.0)),
		"subscribers": float(totals.get("subscribers", 0.0)),
	}
