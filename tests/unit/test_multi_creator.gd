extends TestCase
## Several autonomous creators sharing the house: independence, simultaneous work, bedrooms,
## capacity, schedules and per-creator appearance/recovery.


func _three(config: GameConfig) -> GameState:
	var state := house_with(config, ["mia", "roxy"], 11)
	state.get_room("studio_1").level = 2
	ContentRules.refresh_unlocks(state, config)
	return state


func test_three_creators_move_and_act_independently() -> void:
	var config := load_config()
	var state := _three(config)
	var activities := {}
	var rooms := {}
	var distinct_positions := 0
	for i in range(24 * 12):
		Simulation.advance(state, config, 5.0)
		var positions := {}
		for creator in state.creators:
			activities[creator.id + ":" + creator.activity_id] = true
			if not creator.is_travelling():
				rooms[creator.id + ":" + creator.room_id] = true
			positions["%.2f,%.2f" % [creator.position.x, creator.position.y]] = true
		if positions.size() == 3:
			distinct_positions += 1
	for creator in state.creators:
		var own := 0
		for key: String in activities:
			if key.begins_with(creator.id + ":"):
				own += 1
		assert_true(own >= 3, creator.id + " cycles through activities")
	assert_gt(float(distinct_positions), 24.0 * 12.0 * 0.8, "they're rarely in the exact same place")


func test_creators_produce_content_simultaneously_in_different_rooms() -> void:
	var config := load_config()
	var state := _three(config)
	var best_simultaneous := 0
	for i in range(2 * 24 * 12):
		Simulation.advance(state, config, 5.0)
		var working_rooms := {}
		for creator in state.creators:
			if creator.activity_id == CreatorBrain.WORK and not creator.is_travelling():
				working_rooms[creator.room_id] = true
		best_simultaneous = maxi(best_simultaneous, working_rooms.size())
	assert_true(best_simultaneous >= 2, "at least two filming at once in different rooms (%d)" % best_simultaneous)


func test_each_sleeps_in_her_own_bedroom() -> void:
	var config := load_config()
	var state := _three(config)
	var slept := {}
	for i in range(3 * 24 * 12):
		Simulation.advance(state, config, 5.0)
		for creator in state.creators:
			if creator.activity_id == "sleep" and not creator.is_travelling():
				assert_eq(creator.room_id, creator.home_room_id, creator.id + " sleeps at home")
				slept[creator.id] = true
	assert_eq(slept.size(), 3, "everyone slept")


func test_room_capacity_and_exclusivity_respected_with_three() -> void:
	var config := load_config()
	var state := _three(config)
	for i in range(3 * 24 * 12):
		Simulation.advance(state, config, 5.0)
		for room in state.rooms:
			var present: Array[CreatorState] = []
			for creator in state.creators:
				if creator.occupied_room_id() == room.id:
					present.append(creator)
			assert_true(present.size() <= int(config.room_type(room.type_id).get("capacity", 1)), "capacity in " + room.id)
			for creator in present:
				var activity_id := creator.target_activity_id if creator.is_travelling() else creator.activity_id
				var act := ActivityResolver.resolve(creator, activity_id, config, room)
				if present.size() > 1:
					assert_false(bool(act.get("exclusive", false)), "exclusive content never shared: " + room.id)
				if ActivityResolver.is_content_driven(config.activity(activity_id)) and bool(config.room_type(room.type_id).get("private", false)):
					assert_eq(creator.home_room_id, room.id, "only the owner films in a bedroom")


func test_routines_differ_by_personality() -> void:
	var config := load_config()
	var state := _three(config)
	var roxy := state.get_creator("roxy")
	var mia := state.get_creator("mia")
	assert_gt(roxy.sleep_shift_hours, mia.sleep_shift_hours, "party girl keeps late hours")
	state.game_minutes = 23.5 * 60.0 + GameState.MINUTES_PER_DAY
	assert_true(CreatorBrain.is_night_for(mia, state, config), "bedtime for Mia")
	assert_false(CreatorBrain.is_night_for(roxy, state, config), "Roxy's night hasn't started")
	var work_def := config.activity(CreatorBrain.WORK)
	assert_gt(CreatorBrain.work_session_minutes(mia, work_def, config), CreatorBrain.work_session_minutes(roxy, work_def, config),
		"higher work ethic, longer sessions")


func test_makeover_affects_only_the_selected_creator() -> void:
	var config := load_config()
	var state := _three(config)
	state.cash = 100_000.0
	var roxy := state.get_creator("roxy")
	var others := {}
	for creator in state.creators:
		if creator != roxy:
			others[creator.id] = [creator.measurements.summary(), creator.look.duplicate(true), creator.appearance_tags.duplicate()]
	assert_true(bool(Appearance.purchase(state, config, roxy, "breast_augmentation")["ok"]), "Roxy wants this")
	assert_almost(roxy.measurements.bust_cm, 110.0, 0.001)
	for creator in state.creators:
		if creator == roxy:
			continue
		var before: Array = others[creator.id]
		assert_eq(creator.measurements.summary(), before[0], creator.id + " measurements untouched")
		assert_eq(creator.look, before[1], creator.id + " look untouched")
		assert_false(creator.is_recovering(), creator.id + " not recovering")


func test_one_creators_recovery_does_not_affect_others() -> void:
	var config := load_config()
	var state := _three(config)
	var mia := state.get_creator("mia")
	var roxy := state.get_creator("roxy")
	roxy.recovery = {"item_id": "breast_augmentation", "remaining_minutes": 6000.0, "total_minutes": 6000.0}
	assert_almost(Appearance.recovery_output(mia, config), 1.0, 0.0001)
	assert_lt(Appearance.recovery_output(roxy, config), 1.0)
	var mia_worked := false
	for i in range(24 * 12):
		Simulation.advance(state, config, 5.0)
		if mia.activity_id == CreatorBrain.WORK:
			mia_worked = true
		assert_false(mia.is_recovering())
	assert_true(mia_worked, "Mia keeps working")
	assert_true(roxy.is_recovering())


func test_individual_and_total_income_rates_are_consistent() -> void:
	var config := load_config()
	var state := _three(config)
	Simulation.advance(state, config, 10.0 * 60.0, 5.0)
	var house := 0.0
	var gross := 0.0
	for creator in state.creators:
		var her_gross := Economy.creator_cash_per_hour(creator, state, config)
		var her_house := Economy.creator_house_cash_per_hour(creator, state, config)
		assert_almost(her_house, her_gross * creator.house_share(), 0.0001)
		house += her_house
		gross += her_gross
	assert_almost(Economy.house_cash_per_hour(state, config), house, 0.0001)
	assert_almost(Economy.gross_cash_per_hour(state, config), gross, 0.0001)


func test_housemates_stand_apart_when_relaxing_together() -> void:
	var config := load_config()
	var state := _three(config)
	var lounge := state.get_room("living_1")
	for creator in state.creators:
		creator.energy = 80.0
		creator.mood = 20.0
		Simulation.start_activity(state, config, creator, "socialise", lounge.id)
	var targets := {}
	for creator in state.creators:
		var at: Vector2 = creator.travel_path[creator.travel_path.size() - 1] if creator.is_travelling() else creator.position
		targets["%.2f" % at.x] = true
	assert_eq(targets.size(), 3, "three different spots")
