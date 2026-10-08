extends TestCase


func _creator(looks: float = 50.0) -> CreatorState:
	var c := CreatorState.new()
	c.stats = {"looks": looks, "stamina": 50.0}
	c.energy = 100.0
	c.mood = 100.0
	c.followers = 1000.0
	c.subscribers = 0.0
	return c


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
	var activity := {"rates_per_hour": {"cash": 10.0, "audience_cash": 0.1}}
	# (10 + 0.1 * 1000^1.0) * appeal 1 * quality 2 * productivity 1 = 220
	var rates := Economy.activity_rates(_creator(), activity, 2.0, config)
	assert_almost(float(rates["cash"]), 220.0)


func test_better_room_earns_more() -> void:
	var config := load_config()
	var activity := config.activity("film_content")
	var low := Economy.activity_rates(_creator(), activity, 1.0, config)
	var high := Economy.activity_rates(_creator(), activity, 1.5, config)
	assert_gt(float(high["cash"]), float(low["cash"]))
	assert_gt(float(high["followers"]), float(low["followers"]))


func test_trend_multiplier_applies() -> void:
	var config := load_config()
	var activity := config.activity("film_content")
	var base := Economy.activity_rates(_creator(), activity, 1.0, config, 1.0)
	var trending := Economy.activity_rates(_creator(), activity, 1.0, config, 2.0)
	assert_almost(float(trending["cash"]), float(base["cash"]) * 2.0, 0.01)


func test_stamina_reduces_energy_drain() -> void:
	var config := load_config()
	var activity := config.activity("film_content")
	var weak := _creator()
	weak.stats["stamina"] = 20.0
	var strong := _creator()
	strong.stats["stamina"] = 90.0
	var weak_drain := float(Economy.activity_rates(weak, activity, 1.0, config)["energy"])
	var strong_drain := float(Economy.activity_rates(strong, activity, 1.0, config)["energy"])
	assert_lt(weak_drain, 0.0)
	assert_lt(weak_drain, strong_drain, "weak creator should drain faster")


func test_subscribers_converge_toward_target() -> void:
	var config := fixture_config()
	var activity := {"rates_per_hour": {"subscriber_conversion_rate": 0.5}}
	var c := _creator()
	c.subscribers = 0.0
	# target = 1000 * 0.1 = 100; gap 100 * 0.5 * quality 1 = 50/h
	assert_almost(float(Economy.activity_rates(c, activity, 1.0, config)["subscribers"]), 50.0)
	c.subscribers = 150.0
	assert_lt(float(Economy.activity_rates(c, activity, 1.0, config)["subscribers"]), 0.0, "over target churns down")


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


func test_house_cash_rate_positive_for_new_game() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	assert_gt(Economy.house_cash_per_hour(state, config), 0.0)
