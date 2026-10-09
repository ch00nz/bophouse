extends TestCase


func test_new_game_has_one_adult_creator_in_bedroom() -> void:
	var state := GameState.new_game(load_config())
	assert_eq(state.creators.size(), 1)
	assert_true(state.creators[0].age >= 18, "creator must be an adult")
	assert_eq(state.get_room(state.creators[0].room_id).type_id, "bedroom")
	assert_eq(state.creators[0].content_focus, "glamour")


func test_rested_creator_walks_to_studio_and_works() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	c.energy = 90.0
	Simulation.advance(state, config, 1.0)
	assert_true(c.is_travelling(), "should start walking")
	assert_eq(c.target_activity_id, "work")
	Simulation.advance(state, config, 60.0)
	assert_false(c.is_travelling(), "should have arrived within an hour")
	assert_eq(c.activity_id, "work")
	assert_eq(state.get_room(c.room_id).type_id, "studio")


func test_working_earns_cash_and_followers() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	Simulation.start_activity(state, config, c, "work", "studio_1")
	Simulation.advance(state, config, 60.0)
	var cash_before := state.cash
	var followers_before := c.followers
	var energy_before := c.energy
	var totals := Simulation.advance(state, config, 30.0)
	assert_gt(state.cash, cash_before)
	assert_gt(c.followers, followers_before)
	assert_lt(c.energy, energy_before)
	assert_almost(float(totals["cash"]), state.cash - cash_before, 0.001)


func test_switching_to_content_the_room_cant_host_moves_her() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	c.content_focus = "social_media"
	Simulation.start_activity(state, config, c, "work", "living_1")
	Simulation.advance(state, config, 60.0)
	assert_eq(state.get_room(c.room_id).type_id, "living_room")
	c.content_focus = "solo_premium" # the lounge can't host premium sets
	Simulation.advance(state, config, 1.0)
	assert_true(c.is_travelling(), "should walk to a room that hosts the new content")
	Simulation.advance(state, config, 60.0)
	assert_eq(c.activity_id, "work")
	assert_true(RoomProduction.supports(config, state.get_room(c.room_id), "solo_premium"))


func test_switching_to_content_the_room_can_host_keeps_her_there() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	Simulation.start_activity(state, config, c, "work", "studio_1")
	Simulation.advance(state, config, 60.0)
	c.content_focus = "social_media" # the studio hosts socials too: no pointless walk mid-session
	Simulation.advance(state, config, 5.0)
	assert_false(c.is_travelling())
	assert_eq(c.room_id, "studio_1")


func test_new_content_gains_experience_while_working() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	c.content_focus = "solo_premium"
	assert_almost(c.experience("solo_premium"), 0.0)
	Simulation.start_activity(state, config, c, "work", "studio_1")
	Simulation.advance(state, config, 120.0)
	assert_gt(c.experience("solo_premium"), 0.1)
	assert_almost(c.experience("glamour"), 1.0, 0.0001, "other experience untouched")


func test_exhausted_creator_goes_to_sleep() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	Simulation.start_activity(state, config, c, "work", "studio_1")
	Simulation.advance(state, config, 60.0)
	c.energy = 5.0
	Simulation.advance(state, config, 1.0)
	assert_eq(c.target_activity_id, "sleep")
	Simulation.advance(state, config, 60.0)
	assert_eq(c.activity_id, "sleep")
	assert_eq(state.get_room(c.room_id).type_id, "bedroom")


func test_sleeps_at_night() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	Simulation.start_activity(state, config, c, "work", "studio_1")
	Simulation.advance(state, config, 60.0)
	state.game_minutes = 23.5 * 60.0 # 23:30
	c.energy = 60.0
	Simulation.advance(state, config, 60.0)
	assert_true(c.activity_id == "sleep" or c.target_activity_id == "sleep", "goes to bed at night when tired-ish")


func test_sleep_restores_energy() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var c := state.creators[0]
	c.energy = 10.0
	Simulation.start_activity(state, config, c, "sleep", "bedroom_1")
	Simulation.advance(state, config, 120.0)
	assert_gt(c.energy, 30.0)


func test_clock_advances() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var start := state.game_minutes
	Simulation.advance(state, config, 90.0)
	assert_almost(state.game_minutes, start + 90.0)
	assert_eq(state.day(), 1)
	assert_eq(state.hour_of_day(), 9)
	assert_eq(state.minute_of_hour(), 30)


func test_step_size_barely_changes_results() -> void:
	var config := load_config()
	var fine := GameState.new_game(config, 11)
	var coarse := GameState.new_game(config, 11)
	Simulation.advance(fine, config, 600.0, 0.5)
	Simulation.advance(coarse, config, 600.0, 5.0)
	assert_almost(coarse.cash, fine.cash, maxf(5.0, fine.cash * 0.1), "offline step size should not distort earnings")


func test_creator_cycles_through_rooms_over_a_day() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var seen := {}
	for i in range(24 * 12):
		Simulation.advance(state, config, 5.0)
		seen[state.creators[0].activity_id] = true
	assert_true(seen.has("work"), "worked")
	assert_true(seen.has("sleep"), "slept")
	assert_true(seen.has("socialise"), "socialised")
