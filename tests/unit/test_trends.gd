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


func test_five_trends_defined_with_required_fields() -> void:
	var config := load_config()
	assert_eq(config.trends.size(), 5)
	for trend_id in config.trend_order:
		var t := config.trend(trend_id)
		for key in ["name", "description", "duration_hours", "content", "stats", "income", "followers"]:
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
	for i in range(60):
		Simulation.advance(state, config, 24.0 * 60.0, 10.0)
		for trend_id in TrendSystem.active_ids(state):
			seen[trend_id] = true
		assert_eq(state.active_trends.size(), 2)
	assert_eq(seen.size(), 5, "every trend appears over 60 days")


func test_trend_rolls_are_deterministic_for_a_seed() -> void:
	var config := load_config()
	var a := GameState.new_game(config, 1234)
	var b := GameState.new_game(config, 1234)
	Simulation.advance(a, config, 10.0 * 24.0 * 60.0, 30.0)
	Simulation.advance(b, config, 10.0 * 24.0 * 60.0, 30.0)
	assert_eq(TrendSystem.active_ids(a), TrendSystem.active_ids(b))
	assert_eq(a.next_trend_id, b.next_trend_id)
