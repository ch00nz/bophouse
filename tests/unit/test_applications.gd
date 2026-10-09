extends TestCase
## Creators applying to live in the house: applicants, expectations, bedrooms, living costs and
## revenue-share terms. Joining never costs money; running costs grow with every resident.


func _house_with_free_bedroom(config: GameConfig, cash: float) -> GameState:
	var state := GameState.new_game(config, 5)
	state.cash = 100_000.0
	var lot: RoomState = Housing.buildable_lots(state, config, "bedroom")[0]
	assert_true(bool(Housing.build(state, config, lot.id, "bedroom")["ok"]))
	state.cash = cash
	return state


func test_six_distinct_adult_applicants() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	var ids := Applications.applicant_ids(state, config)
	assert_true(ids.size() >= 6, "at least six applicants")
	var names := {}
	var archetypes := {}
	var looks := {}
	var estimates: Array[float] = []
	for template_id in ids:
		var template: Dictionary = config.creator_templates[template_id]
		var creator := CreatorSetup.create(template, config, state)
		assert_true(creator.age >= 21, template_id + " is 21+")
		names[creator.display_name] = true
		archetypes[creator.archetype] = true
		var look_key := "%s|%s|%s|%s" % [creator.look_value("hair_color"), creator.look_value("hair_style"), creator.look_value("outfit"), creator.appearance.get("skin", "")]
		assert_false(looks.has(look_key), template_id + " has a distinct look")
		looks[look_key] = true
		for field in ["bio", "strengths", "weaknesses"]:
			assert_false(str(template.get(field, "")).is_empty(), template_id + " has " + field)
		assert_false(creator.traits.is_empty(), template_id + " traits")
		assert_gt(creator.living_cost_per_day, 0.0, template_id + " has living costs")
		assert_gt(creator.creator_share(), 0.0, template_id + " keeps a share")
		estimates.append(float(Applications.estimate(template, state, config)["gross_per_day"]))
	assert_eq(names.size(), ids.size(), "unique names")
	assert_eq(archetypes.size(), ids.size(), "unique archetypes")
	assert_gt(estimates.max(), estimates.min() * 2.0, "earning potential differs a lot")


func test_applicants_have_different_strengths() -> void:
	var config := load_config()
	var best := {}
	for stat_id in ["looks", "charisma", "work_ethic", "stamina", "adaptability", "wildness"]:
		var top := ""
		var top_value := -1.0
		for template_id in config.creator_order:
			if not bool(config.creator_templates[template_id].get("applicant", false)):
				continue
			var value := float(config.creator_templates[template_id]["stats"][stat_id])
			if value > top_value:
				top_value = value
				top = template_id
		best[top] = true
	assert_true(best.size() >= 5, "different applicants lead different stats: %s" % str(best.keys()))


func test_moving_in_needs_a_free_bedroom() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	state.cash = 1_000_000.0
	state.creators[0].followers = 5000.0 # Mia has applied
	var check := Applications.check(state, config, "mia")
	assert_false(bool(check["ok"]))
	assert_true(str(check["reason"]).contains("bedroom"), "explains: " + str(check["reason"]))
	assert_false(bool(Applications.accept(state, config, "mia")["ok"]))
	assert_eq(state.creators.size(), 1, "nobody moved in")


func test_joining_is_free_and_she_moves_into_the_free_bedroom() -> void:
	var config := load_config()
	var state := _house_with_free_bedroom(config, 0.0)
	state.creators[0].followers = 5000.0
	var reserve := Applications.required_reserve(config.creator_templates["mia"], state, config)
	state.cash = reserve
	var free_room := Housing.free_bedrooms(state, config)[0]
	var result := Applications.accept(state, config, "mia")
	assert_true(bool(result["ok"]), str(result["reason"]))
	assert_almost(state.cash, reserve, 0.0001, "no money changes hands: the reserve stays in the bank")
	var mia := state.get_creator("mia")
	assert_eq(mia.home_room_id, free_room.id)
	assert_almost(mia.creator_share(), 0.6, 0.0001, "her own terms")
	assert_almost(mia.living_cost_per_day, 75.0, 0.0001)
	assert_false(Applications.applicant_ids(state, config).has("mia"), "no longer applying")
	assert_false(bool(Applications.accept(state, config, "mia")["ok"]), "can't move in twice")
	assert_false(state.relationships.is_empty(), "housemates get a relationship")


func test_some_creators_only_apply_once_the_house_meets_expectations() -> void:
	var config := load_config()
	var state := _house_with_free_bedroom(config, 0.0)
	var chloe: Dictionary = config.creator_templates["chloe"]
	assert_false(Applications.has_applied(chloe, state, config))
	var missing := Applications.unmet_expectations(chloe, state, config)
	assert_eq(missing.size(), 3, "studio level, audience and the bigger house: %s" % str(missing))
	assert_false(bool(Applications.accept(state, config, "chloe")["ok"]))
	state.cash = 100_000.0
	state.get_room("studio_1").level = 2
	state.creators[0].followers = 13000.0
	Upgrades.purchase(state, config, Upgrades.EXPANSION)
	assert_true(Applications.has_applied(chloe, state, config), "now she applies")
	assert_true(bool(Applications.accept(state, config, "chloe")["ok"]))
	# The first applicants only want a small audience: a progression unlock, not a wall.
	var fresh := GameState.new_game(config, 1)
	for template_id in ["mia", "lily"]:
		assert_false(Applications.has_applied(config.creator_templates[template_id], fresh, config), template_id + " waits for some audience")
	fresh.creators[0].followers = 1500.0
	for template_id in ["mia", "lily"]:
		assert_true(Applications.has_applied(config.creator_templates[template_id], fresh, config), template_id)


func test_moving_in_needs_a_cash_reserve_for_running_costs() -> void:
	var config := load_config()
	var state := _house_with_free_bedroom(config, 0.0)
	state.creators[0].followers = 5000.0
	var reserve := Applications.required_reserve(config.creator_templates["mia"], state, config)
	assert_gt(reserve, Expenses.total_per_day(state, config), "covers several days")
	state.cash = reserve - 1.0
	var result := Applications.accept(state, config, "mia")
	assert_false(bool(result["ok"]))
	assert_true(str(result["reason"]).contains("bank"), str(result["reason"]))


func test_living_costs_are_charged_continuously_and_add_up() -> void:
	var config := load_config()
	var state := house_with(config, ["mia", "lily"])
	assert_almost(state.living_cost_per_day(), 75.0 + 55.0, 0.001, "founder covered, each housemate adds her costs")
	var house_before := state.total_house_earnings()
	var totals := Simulation.advance(state, config, GameState.MINUTES_PER_DAY, 5.0)
	assert_almost(state.living_costs, 130.0, 0.01, "one day of living costs")
	assert_almost(float(totals["living_costs"]), 130.0, 0.01)
	assert_almost(state.get_creator("mia").living_costs_paid, 75.0, 0.01)
	var house_gain := state.total_house_earnings() - house_before
	assert_almost(state.cash, house_gain - float(totals["expenses"]), 0.01, "cash = house shares - running costs")
	assert_almost(float(totals["cash"]), state.cash, 0.01)


func test_living_costs_are_charged_in_full_while_away() -> void:
	var config := load_config()
	var state := house_with(config, ["mia"])
	state.last_seen_unix = 1000.0
	var summary := OfflineProgress.apply(state, config, 1000.0 + 3600.0)
	var minutes := float(summary["game_minutes"])
	assert_almost(float(summary["living_costs"]), 75.0 * minutes / GameState.MINUTES_PER_DAY, 0.01)


func test_house_growth_needs_more_investment() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	var first_bedroom := Housing.build_cost(state, config, "bedroom")
	state.creators[0].followers = 5000.0
	var investment := first_bedroom + Applications.required_reserve(config.creator_templates["mia"], state, config)
	assert_gt(investment, 4000.0, "a second housemate is a real investment")
	assert_lt(investment, 6000.0, "but reachable within the first couple of hours")
	state = house_with(config, ["lily"])
	assert_gt(Housing.build_cost(state, config, "bedroom"), first_bedroom, "each bedroom costs more")
	var costs_two := state.living_cost_per_day()
	state = house_with(config, ["lily", "mia"])
	assert_gt(state.living_cost_per_day(), costs_two, "running costs rise with every resident")


func test_house_expands_to_at_least_three_bedrooms() -> void:
	var config := load_config()
	var state := house_with(config, ["mia", "jade"])
	assert_eq(state.creators.size(), 3)
	var homes := {}
	for creator in state.creators:
		assert_false(creator.home_room_id.is_empty(), creator.id + " has a bedroom")
		assert_false(homes.has(creator.home_room_id), "nobody shares a bedroom")
		homes[creator.home_room_id] = true
	assert_true(Housing.capacity(state, config) >= 3)


func test_terms_never_override_boundaries() -> void:
	var config := load_config()
	var state := house_with(config, ["mia"])
	var mia := state.get_creator("mia")
	state.get_room("studio_1").level = 3
	ContentRules.refresh_unlocks(state, config)
	assert_eq(int(ContentRules.check(mia, "topless_premium", state, config)["status"]), ContentRules.Status.DECLINED)
	state.cash = 1_000_000.0
	assert_false(bool(Appearance.check_item(mia, state, config, "breast_augmentation")["ok"]), "her body, her call")


func test_revenue_split_is_exact() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	var creator := state.creators[0]
	creator.contract = Contracts.make(0.7, 1, "test")
	state.cash = 0.0
	var house := Contracts.credit(state, creator, 1000.0)
	assert_almost(house, 300.0, 0.0001)
	assert_almost(state.cash, 300.0, 0.0001, "only the house share is credited")
	assert_almost(creator.creator_earnings, 700.0, 0.0001)
	assert_almost(creator.lifetime_earnings, 1000.0, 0.0001, "gross tracked")


func test_simulated_income_is_split_per_creator_and_totals_add_up() -> void:
	var config := load_config()
	var state := house_with(config, ["mia", "roxy"])
	var house_before := state.total_house_earnings()
	var gross_before := state.total_gross_earnings()
	var totals := Simulation.advance(state, config, 24.0 * 60.0, 5.0)
	for creator in state.creators:
		assert_gt(creator.lifetime_earnings, 0.0, creator.id + " earned")
		assert_almost(creator.creator_earnings + creator.house_earnings, creator.lifetime_earnings, 0.01, creator.id + " ledger adds up")
	var house_gain := state.total_house_earnings() - house_before
	var gross_gain := state.total_gross_earnings() - gross_before
	assert_almost(state.cash, house_gain - float(totals["expenses"]), 0.01, "player cash = house shares - running costs")
	assert_almost(float(totals["gross"]), gross_gain, 0.01)
	assert_lt(house_gain, gross_gain, "creators keep their share")


func test_build_requires_cash_and_a_lot() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	state.cash = 10.0
	var lot: RoomState = Housing.buildable_lots(state, config, "bedroom")[0]
	assert_false(bool(Housing.build(state, config, lot.id, "bedroom")["ok"]))
	assert_eq(lot.type_id, "empty_lot")
	assert_false(bool(Housing.build(state, config, "studio_1", "bedroom")["ok"]), "can't build over a room")
	state.cash = 100_000.0
	var cost := Housing.build_cost(state, config, "bedroom")
	assert_true(bool(Housing.build(state, config, lot.id, "bedroom")["ok"]))
	assert_eq(lot.type_id, "bedroom")
	assert_almost(state.cash, 100_000.0 - cost, 0.001)
	assert_almost(state.build_costs, cost, 0.001)


func test_bedroom_swap_never_leaves_anyone_homeless() -> void:
	var config := load_config()
	var state := house_with(config, ["mia"])
	var ava := state.get_creator("ava")
	var mia := state.get_creator("mia")
	var ava_home := ava.home_room_id
	var mia_home := mia.home_room_id
	assert_true(bool(Housing.assign_bedroom(state, config, ava, mia_home)["ok"]))
	assert_eq(ava.home_room_id, mia_home)
	assert_eq(mia.home_room_id, ava_home, "swapped")
	assert_false(bool(Housing.assign_bedroom(state, config, ava, "living_1")["ok"]), "not a bedroom")
