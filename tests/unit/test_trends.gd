extends TestCase


func _state_with_trend(config: GameConfig, trend_id: String) -> GameState:
	var state := GameState.new_game(config, 9)
	state.active_trends = [{"id": trend_id, "remaining_minutes": 600.0, "duration_minutes": 600.0}]
	return state


func test_new_game_has_distinct_active_trends_and_forecast() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ids := TrendSystem.active_ids(state)
	assert_eq(ids.size(), int(config.tuning("trends", "active_count", 2)))
	assert_true(ids[0] != ids[1], "active trends are distinct")
	assert_true(config.trends.has(state.next_trend_id))
	assert_false(ids.has(state.next_trend_id), "forecast isn't already active")


func test_at_least_five_trends_defined_with_required_fields() -> void:
	var config := load_config()
	assert_true(config.trends.size() >= 5)
	for trend_id in config.trend_order:
		var t := config.trend(trend_id)
		for key in ["name", "description", "duration_hours", "content", "stats", "tags", "income", "followers"]:
			assert_true(t.has(key), "%s has %s" % [trend_id, key])


func test_favoured_content_gets_trend_bonus() -> void:
	var config := load_config()
	var state := _state_with_trend(config, "poolside_glamour")
	var ava := state.creators[0]
	ava.content_experience = {"glamour": 1.0, "solo_premium": 1.0}
	var favoured := TrendSystem.modifiers(state, config, ava, "glamour")
	var other := TrendSystem.modifiers(state, config, ava, "solo_premium")
	assert_gt(float(favoured["income"]), 1.0)
	assert_gt(float(favoured["followers"]), 1.0)
	assert_almost(float(other["income"]), 1.0, 0.0001, "unrelated content unaffected")
	assert_eq((favoured["effects"] as Array).size(), 1)


func test_trend_modifier_flows_into_income() -> void:
	var config := load_config()
	var state := _state_with_trend(config, "poolside_glamour")
	var ava := state.creators[0]
	var with_trend := Economy.work_breakdown(ava, state, config, "glamour")
	state.active_trends = []
	var without := Economy.work_breakdown(ava, state, config, "glamour")
	var ratio := float(with_trend["cash"]) / float(without["cash"])
	assert_almost(ratio, float(with_trend["multipliers"]["trend_income"]), 0.0001)
	assert_gt(ratio, 1.0)


func test_adaptability_improves_trend_response() -> void:
	var config := load_config()
	var state := _state_with_trend(config, "poolside_glamour")
	var ava := state.creators[0]
	ava.stats["adaptability"] = 10.0
	var rigid := float(TrendSystem.modifiers(state, config, ava, "glamour")["income"])
	ava.stats["adaptability"] = 95.0
	var adaptable := float(TrendSystem.modifiers(state, config, ava, "glamour")["income"])
	assert_gt(adaptable, rigid)


func test_favoured_stats_improve_trend_response() -> void:
	var config := load_config()
	var state := _state_with_trend(config, "poolside_glamour") # favours looks + confidence
	var ava := state.creators[0]
	ava.stats["looks"] = 30.0
	ava.stats["confidence"] = 30.0
	var weak := float(TrendSystem.modifiers(state, config, ava, "glamour")["income"])
	ava.stats["looks"] = 95.0
	ava.stats["confidence"] = 95.0
	assert_gt(float(TrendSystem.modifiers(state, config, ava, "glamour")["income"]), weak)


func test_trends_rotate_to_forecast_when_expired() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 2)
	var forecast := state.next_trend_id
	var soonest: Dictionary = state.active_trends[0]
	for entry: Dictionary in state.active_trends:
		if float(entry["remaining_minutes"]) < float(soonest["remaining_minutes"]):
			soonest = entry
	var expiring_id := str(soonest["id"])
	var remaining := float(soonest["remaining_minutes"])
	var started := TrendSystem.advance(state, config, remaining + 1.0)
	assert_true(started.has(forecast), "forecast trend started")
	assert_false(TrendSystem.active_ids(state).has(expiring_id), "expired trend gone")
	assert_true(state.next_trend_id != expiring_id, "ended trend doesn't come straight back")
	assert_false(TrendSystem.active_ids(state).has(state.next_trend_id), "new forecast not already active")


func test_trends_keep_rotating_over_many_days() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 4)
	var seen := {}
	# Trends last 1-4 weeks, so it takes a couple of in-game years to see every one.
	for i in range(730):
		TrendSystem.advance(state, config, 24.0 * 60.0)
		for trend_id in TrendSystem.active_ids(state):
			seen[trend_id] = true
		assert_eq(state.active_trends.size(), 2)
	assert_eq(seen.size(), config.trends.size(), "every trend appears over two years")


func test_trends_last_between_a_week_and_a_month() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 9)
	var week := 7.0 * 24.0 * 60.0
	var month := 30.0 * 24.0 * 60.0
	var rolled := 0
	for i in range(400):
		TrendSystem.advance(state, config, 24.0 * 60.0)
		for entry: Dictionary in state.active_trends:
			var duration := float(entry["duration_minutes"])
			assert_true(duration >= week - 0.01 and duration <= month + 0.01, "%s lasts %.1f days" % [entry["id"], duration / 1440.0])
			rolled += 1
	assert_gt(rolled, 0)
	for trend_id in config.trend_order:
		var hours: Array = config.trend(trend_id)["duration_hours"]
		assert_true(float(hours[0]) >= 168.0 and float(hours[1]) <= 720.0, "%s data is within a week..month" % trend_id)


func test_short_trends_from_old_saves_are_stretched() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	state.active_trends = [{"id": "poolside_glamour", "remaining_minutes": 600.0, "duration_minutes": 2400.0}]
	TrendSystem.ensure_initialized(state, config)
	var entry: Dictionary = state.active_trends[0]
	assert_almost(float(entry["duration_minutes"]), 168.0 * 60.0)
	assert_almost(float(entry["remaining_minutes"]), 168.0 * 60.0 - 1800.0, 0.01, "elapsed time is kept")


func test_trend_rolls_are_deterministic_for_a_seed() -> void:
	var config := load_config()
	var a := GameState.new_game(config, 1234)
	var b := GameState.new_game(config, 1234)
	Simulation.advance(a, config, 10.0 * 24.0 * 60.0, 30.0)
	Simulation.advance(b, config, 10.0 * 24.0 * 60.0, 30.0)
	assert_eq(TrendSystem.active_ids(a), TrendSystem.active_ids(b))
	assert_eq(a.next_trend_id, b.next_trend_id)
