extends TestCase
## Economy rebalance: starting conditions, running costs, upgrades with diminishing returns, audience
## saturation and churn, content freshness, speed/offline consistency, debt and simulator regressions.

const BalanceSim := preload("res://tests/balance/balance_sim.gd")


func test_humble_starting_conditions() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	assert_almost(state.cash, 250.0, 0.001)
	assert_almost(ava.followers, 350.0, 0.001)
	assert_almost(ava.subscribers, 8.0, 0.001)
	assert_eq(state.creators.size(), 1)
	assert_true(state.upgrades.is_empty(), "no equipment yet")
	var gross := float(Economy.work_breakdown(ava, state, config)["cash"])
	assert_gt(gross, 13.0, "about $18 per productive hour (got %.1f)" % gross)
	assert_lt(gross, 24.0, "about $18 per productive hour (got %.1f)" % gross)
	assert_gt(Expenses.total_per_day(state, config), 40.0, "real running costs from day one")


func test_expense_breakdown_adds_up_and_is_charged() -> void:
	var config := load_config()
	var state := house_with(config, ["mia"])
	state.cash = 10_000.0
	Upgrades.purchase(state, config, "ring_light")
	state.get_room("studio_1").level = 2
	var costs := Expenses.per_day(state, config)
	var sum := 0.0
	for key in Expenses.KEYS:
		assert_gt(float(costs[key]) + 0.001, 0.0, key)
		sum += float(costs[key])
	assert_almost(float(costs["total"]), sum, 0.001)
	assert_gt(float(costs["maintenance"]), 0.0, "upgrade + renovated room upkeep")
	var cash := state.cash
	var before := state.expense_totals.duplicate()
	Expenses.charge(state, config, GameState.MINUTES_PER_DAY)
	assert_almost(cash - state.cash, float(costs["total"]), 0.01, "one day of costs")
	for key in Expenses.KEYS:
		assert_almost(float(state.expense_totals[key]) - float(before.get(key, 0.0)), float(costs[key]), 0.01, key + " tracked")


func test_rent_grows_with_the_house() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var base := float(Expenses.per_day(state, config)["rent"])
	state.cash = 100_000.0
	Housing.build(state, config, "lot_1", "bedroom")
	var with_room := float(Expenses.per_day(state, config)["rent"])
	assert_gt(with_room, base)
	Upgrades.purchase(state, config, Upgrades.EXPANSION)
	assert_gt(float(Expenses.per_day(state, config)["rent"]), with_room, "bigger house, bigger rent")
	assert_true(state.get_room("lot_2") != null, "top floor added")


func test_upgrades_cost_money_need_prerequisites_and_help() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	state.active_trends = []
	var ava := state.creators[0]
	var before := float(Economy.work_breakdown(ava, state, config)["cash"])
	assert_false(bool(Upgrades.check(state, config, "softbox_kit")["ok"]), "needs the ring light first")
	var result := Upgrades.purchase(state, config, "ring_light")
	assert_true(bool(result["ok"]))
	assert_almost(state.cash, 100.0, 0.001, "$250 - $150")
	assert_gt(float(Economy.work_breakdown(ava, state, config)["cash"]), before * 1.08, "a tangible boost")
	assert_false(bool(Upgrades.purchase(state, config, "ring_light")["ok"]), "can't buy twice")
	assert_false(bool(Upgrades.purchase(state, config, "pro_camera")["ok"]), "can't afford / needs the phone")
	assert_almost(state.cash, 100.0, 0.001)


func test_upgrades_have_diminishing_returns_within_a_category() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	state.cash = 100_000.0
	var room := state.get_room("bedroom_1")
	var base := float(RoomProduction.attributes(config, room)["lighting"])
	Upgrades.purchase(state, config, "ring_light")
	var one := float(RoomProduction.attributes(config, room)["lighting"])
	Upgrades.purchase(state, config, "softbox_kit")
	var two := float(RoomProduction.attributes(config, room)["lighting"])
	var softbox := float(config.upgrade("softbox_kit")["effects"]["room_attributes"]["lighting"])
	assert_lt(two - one, softbox - 0.001, "second lighting upgrade counts less than its full value")
	assert_gt(two - one, 0.0, "but still helps")
	assert_true(two <= 1.0, "attributes are capped")
	assert_gt(one, base)
	# Income multipliers stack with diminishing returns too.
	Upgrades.purchase(state, config, "wardrobe_upgrade")
	Upgrades.purchase(state, config, "prop_collection")
	var all_in := Upgrades.content_income_multiplier(state, config, "glamour")
	assert_lt(all_in, 1.6, "no category dominates (x%.2f)" % all_in)


func test_revenue_share_is_applied_once() -> void:
	var config := load_config()
	var state := house_with(config, ["mia"])
	state.cash = 0.0
	var totals := Simulation.advance(state, config, GameState.MINUTES_PER_DAY, 5.0)
	var expected_house := 0.0
	for creator in state.creators:
		expected_house += float(totals["by_creator"].get(creator.id, {}).get("house", 0.0))
	assert_almost(float(totals["house"]), expected_house, 0.01)
	var mia_entry: Dictionary = totals["by_creator"]["mia"]
	assert_almost(float(mia_entry["house"]), float(mia_entry["gross"]) * 0.4, 0.01, "Mia's 60/40 split, once")
	assert_almost(state.cash, float(totals["house"]) - float(totals["expenses"]), 0.01)


func test_audience_growth_slows_and_levels_off() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	ava.content_focus = "social_media"
	var net_growth := func(followers: float) -> float:
		ava.followers = followers
		return float(Economy.work_breakdown(ava, state, config)["followers"]) - Economy.follower_decay_per_hour(ava, config) * 24.0 / 9.0
	var small: float = net_growth.call(2000.0)
	var big: float = net_growth.call(60000.0)
	assert_gt(small, big, "bigger audiences are harder to grow (%.1f vs %.1f)" % [small, big])
	assert_lt(big, 0.0, "a huge audience shrinks without more reach")


func test_subscribers_churn_without_work() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	ava.subscribers = 200.0
	ava.energy = 5.0 # sleeps all day
	Simulation.start_activity(state, config, ava, "sleep", ava.home_room_id)
	Simulation.advance(state, config, 12.0 * 60.0, 5.0)
	assert_lt(ava.subscribers, 200.0, "subscribers cancel over time")


func test_content_freshness_wears_out_and_recovers() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	ava.content_focus = "glamour"
	ava.activity_id = CreatorBrain.WORK
	ava.room_id = ava.home_room_id
	ava.energy = 100.0
	var fresh := float(Economy.work_breakdown(ava, state, config)["cash"])
	for i in 60:
		Simulation._update_freshness(ava, config, 1.0)
	var floor_value := config.tuning_f("freshness", "floor", 0.75)
	assert_almost(ava.freshness("glamour"), floor_value, 0.0001, "worn out to the floor")
	assert_lt(float(Economy.work_breakdown(ava, state, config)["cash"]), fresh * 0.8, "stale content earns less")
	ava.content_focus = "social_media"
	for i in 24:
		Simulation._update_freshness(ava, config, 1.0)
	assert_almost(ava.freshness("glamour"), 1.0, 0.0001, "recovers while she makes something else")
	assert_lt(ava.freshness("social_media"), 1.0, "the new content wears instead")


func test_same_results_at_every_game_speed() -> void:
	var config := load_config()
	var results: Array[float] = []
	for speed in [1, 3, 10]:
		var state := GameState.new_game(config, 7)
		var frames := int(3600.0 / speed)
		for i in frames:
			var minutes := TimeControl.frame_minutes(1.0 / 60.0, speed, false, config)
			Simulation.advance(state, config, minutes, config.tuning_f("time", "max_sim_step_minutes", 1.0))
		results.append(state.game_minutes)
		results.append(state.cash)
	assert_almost(results[2], results[0], 0.5, "3x covers the same game time in a third of the frames")
	assert_almost(results[4], results[0], 0.5, "10x too")
	assert_almost(results[3], results[1], 0.5, "same cash at 3x")
	assert_almost(results[5], results[1], 0.5, "same cash at 10x")


func test_offline_never_beats_playing() -> void:
	var config := load_config()
	var real_seconds := 4.0 * 3600.0
	var played := GameState.new_game(config, 3)
	Simulation.advance(played, config, real_seconds * config.tuning_f("time", "game_minutes_per_real_second", 2.0), 5.0)
	var away := GameState.new_game(config, 3)
	away.last_seen_unix = 1000.0
	OfflineProgress.apply(away, config, 1000.0 + real_seconds)
	var reopened := GameState.new_game(config, 3)
	reopened.last_seen_unix = 1000.0
	for i in 16: # reopening every 15 minutes
		OfflineProgress.apply(reopened, config, 1000.0 + (i + 1) * real_seconds / 16.0)
	assert_gt(played.cash, away.cash * 2.0, "playing earns far more than being away")
	assert_lt(reopened.cash, away.cash * 1.05, "reopening often is no better than one long break")
	assert_lt(reopened.cash, played.cash)


func test_debt_blocks_spending_and_stresses_residents() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.cash = -50.0
	assert_true(Expenses.in_debt(state))
	assert_false(bool(Upgrades.check(state, config, "ring_light")["ok"]))
	var ava := state.creators[0]
	ava.mood = 80.0
	ava.energy = 5.0
	Simulation.start_activity(state, config, ava, "sleep", ava.home_room_id)
	var mood_in_debt := ava.mood
	Simulation.advance(state, config, 60.0, 5.0)
	var debt_drop := mood_in_debt - ava.mood
	var calm := GameState.new_game(config, 3)
	var ava2 := calm.creators[0]
	ava2.mood = 80.0
	ava2.energy = 5.0
	Simulation.start_activity(calm, config, ava2, "sleep", ava2.home_room_id)
	Simulation.advance(calm, config, 60.0, 5.0)
	assert_gt(debt_drop, 80.0 - ava2.mood, "money worries hurt mood")


func test_upgrades_and_expenses_survive_saving() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.cash = 50_000.0
	Upgrades.purchase(state, config, "ring_light")
	Upgrades.purchase(state, config, Upgrades.EXPANSION)
	Simulation.advance(state, config, 600.0, 5.0)
	var loaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(state, 1.0))))
	SaveSystem.post_load(loaded, config)
	assert_eq(loaded.upgrades, state.upgrades)
	assert_true(loaded.get_room("lot_2") != null, "top floor kept")
	for key in Expenses.KEYS:
		assert_almost(float(loaded.expense_totals.get(key, 0.0)), float(state.expense_totals.get(key, 0.0)), 0.001, key)
	assert_almost(float(RoomProduction.attributes(config, loaded.get_room("bedroom_1"))["lighting"]),
		float(RoomProduction.attributes(config, state.get_room("bedroom_1"))["lighting"]), 0.0001, "bonuses rebuilt on load")


func test_v5_house_with_a_top_floor_keeps_it() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.rooms.append(RoomState.create("lot_2", "empty_lot", 2, 0, 2))
	var data := SaveSystem.to_save_dict(state, 1.0)
	data["version"] = 5
	data["state"].erase("upgrades")
	var loaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(data)))
	SaveSystem.post_load(loaded, config)
	assert_true(Upgrades.owned(loaded, Upgrades.EXPANSION), "counted as already expanded")
	assert_true(loaded.get_room("lot_3") != null, "rest of the top floor filled in")


func test_idle_player_never_goes_bankrupt() -> void:
	var sim = BalanceSim.new(load_config(), "idle", 99)
	var report: Dictionary = sim.run(12, 10.0)
	assert_gt(float(report["min_cash"]), 0.0, "an untouched house stays solvent")
	var daily: Array = report["daily"]
	assert_gt(float(daily[daily.size() - 1]["net"]), 0.0, "and profitable")
	assert_lt(float(report["final_cash"]), 5000.0, "but idling alone is slow (got %d)" % int(report["final_cash"]))


func test_engaged_player_gets_a_second_creator_in_the_first_couple_of_hours() -> void:
	var config := load_config()
	var sim = BalanceSim.new(config, "optimised", 1234)
	var report: Dictionary = sim.run(12, 10.0)
	var hours: Variant = report["milestones"].get("second_creator")
	assert_true(hours != null, "second creator within 12 game days")
	if hours != null:
		assert_gt(float(hours), 5.0 * 24.0, "not too early (day %.1f)" % (float(hours) / 24.0))
	assert_eq(int(report["hours_in_debt"]), 0, "growth doesn't bankrupt the house")
