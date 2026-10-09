extends TestCase


func _creator(looks: float = 50.0) -> CreatorState:
	var c := CreatorState.new()
	c.stats = {"looks": looks, "stamina": 50.0}
	c.energy = 100.0
	c.mood = 100.0
	c.followers = 1000.0
	c.subscribers = 0.0
	return c


## A state with no active trends so tests isolate the effect under test.
func _quiet_state(config: GameConfig) -> GameState:
	var state := GameState.new_game(config, 42)
	state.active_trends = []
	return state


func test_appeal_is_one_at_baseline() -> void:
	assert_almost(Economy.appeal(_creator(50.0), fixture_config()), 1.0)


func test_appeal_scales_with_stats() -> void:
	assert_almost(Economy.appeal(_creator(75.0), fixture_config()), 1.5)


func test_productivity_drops_when_tired() -> void:
	var config := fixture_config()
	var c := _creator()
	assert_almost(Economy.productivity(c, config), 1.0)
	c.energy = 0.0
	assert_almost(Economy.productivity(c, config), 0.5)


func test_activity_cash_formula_exact() -> void:
	var config := fixture_config()
	var activity := {"rates_per_hour": {"cash": 10.0}}
	# 10 * appeal 1 * quality 2 * productivity 1 = 20
	var rates := Economy.activity_rates(_creator(), activity, 2.0, config)
	assert_almost(float(rates["cash"]), 20.0)


func test_energy_and_mood_reduce_work_income() -> void:
	var config := load_config()
	var state := _quiet_state(config)
	var ava := state.creators[0]
	ava.energy = 100.0
	ava.mood = 100.0
	var fresh := float(Economy.work_breakdown(ava, state, config)["cash"])
	ava.energy = 20.0
	var tired := float(Economy.work_breakdown(ava, state, config)["cash"])
	ava.mood = 10.0
	var miserable := float(Economy.work_breakdown(ava, state, config)["cash"])
	assert_lt(tired, fresh, "low energy lowers income")
	assert_lt(miserable, tired, "low mood lowers it further")


func test_better_room_earns_more() -> void:
	var config := load_config()
	var state := _quiet_state(config)
	var ava := state.creators[0]
	var before := Economy.work_breakdown(ava, state, config, "glamour")
	state.get_room("studio_1").level = 3
	var after := Economy.work_breakdown(ava, state, config, "glamour")
	assert_gt(float(after["cash"]), float(before["cash"]))
	assert_gt(float(after["followers"]), float(before["followers"]))


func test_breakdown_components_add_up() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 7)
	var b := Economy.work_breakdown(state.creators[0], state, config)
	assert_almost(float(b["cash"]), float(b["content_sales"]) + float(b["audience_earnings"]), 0.0001)
	var m: Dictionary = b["multipliers"]
	var expected_sales := float(config.content("glamour")["rates_per_hour"]["cash"]) \
		* float(m["fit"]) * float(m["room"]) * float(m["productivity"]) * float(m["trend_income"]) * float(m["experience"]) \
		* float(m["audience_fit"]) * float(m["recovery"])
	assert_almost(float(b["content_sales"]), expected_sales, 0.0001, "sales = base x every multiplier shown in the UI")


func test_stamina_reduces_energy_drain() -> void:
	var config := load_config()
	var state := _quiet_state(config)
	var weak := state.creators[0]
	weak.stats["stamina"] = 20.0
	var weak_drain := float(Economy.work_breakdown(weak, state, config)["energy"])
	weak.stats["stamina"] = 90.0
	var strong_drain := float(Economy.work_breakdown(weak, state, config)["energy"])
	assert_lt(weak_drain, 0.0)
	assert_lt(weak_drain, strong_drain, "weak creator should drain faster")


func test_subscribers_converge_toward_target() -> void:
	var config := load_config()
	var state := _quiet_state(config)
	var ava := state.creators[0]
	ava.subscribers = 0.0
	assert_gt(float(Economy.work_breakdown(ava, state, config)["subscribers"]), 0.0)
	ava.subscribers = ava.followers
	assert_lt(float(Economy.work_breakdown(ava, state, config)["subscribers"]), 0.0, "over target churns down")


func test_subscription_income_linear() -> void:
	var config := fixture_config()
	var c := _creator()
	c.subscribers = 37.0
	assert_almost(Economy.subscription_cash_per_hour(c, config), 37.0)


func test_audience_value_has_diminishing_returns() -> void:
	var config := load_config()
	var small := Economy.audience_value(1000.0, config)
	var big := Economy.audience_value(10000.0, config)
	assert_lt(big, small * 10.0)
	assert_gt(big, small)


func test_follower_growth_is_not_exponential() -> void:
	var config := load_config()
	# Relative growth rate must fall as the audience grows (exponential growth keeps it constant).
	var small := Economy.follower_growth(16.0, 0.35, 1000.0, 1.0, config) / 1000.0
	var large := Economy.follower_growth(16.0, 0.35, 100000.0, 1.0, config) / 100000.0
	assert_lt(large, small * 0.2)


func test_long_run_growth_stays_bounded() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.cash = 0.0
	Simulation.advance(state, config, 60.0 * 24.0 * 30.0, 10.0) # 30 game days
	var ava := state.creators[0]
	assert_gt(ava.followers, 2000.0, "she should grow")
	assert_lt(ava.followers, 250000.0, "but not explode in a month")
	assert_true(is_finite(state.cash) and state.cash < 10_000_000.0, "cash stays sane")


func test_house_cash_rate_positive_for_new_game() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	assert_gt(Economy.house_cash_per_hour(state, config), 0.0)
