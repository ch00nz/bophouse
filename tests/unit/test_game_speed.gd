extends TestCase
## Income must not depend on the speed setting: 1x, 3x and 10x should earn the same per game hour.


func _play(config: GameConfig, speed: int, game_minutes: float) -> GameState:
	var state := GameState.new_game(config, 77)
	var frame := 1.0 / 60.0
	var step := config.tuning_f("time", "max_sim_step_minutes", 1.0)
	var elapsed := 0.0
	while elapsed < game_minutes:
		var minutes := minf(TimeControl.frame_minutes(frame, speed, false, config), game_minutes - elapsed)
		Simulation.advance(state, config, minutes, step)
		elapsed += minutes
	return state


func test_frame_minutes_scale_with_speed() -> void:
	var config := load_config()
	var one := TimeControl.frame_minutes(0.1, 1, false, config)
	assert_almost(TimeControl.frame_minutes(0.1, 3, false, config), one * 3.0)
	assert_almost(TimeControl.frame_minutes(0.1, 10, false, config), one * 10.0)
	assert_almost(TimeControl.frame_minutes(0.1, 10, true, config), 0.0, 0.0001, "paused")


func test_long_frames_are_clamped() -> void:
	var config := load_config()
	var max_delta := config.tuning_f("time", "max_frame_delta_seconds", 0.25)
	assert_almost(TimeControl.frame_minutes(5.0, 1, false, config), TimeControl.frame_minutes(max_delta, 1, false, config))


func test_income_is_stable_across_speeds() -> void:
	var config := load_config()
	var minutes := 8.0 * 60.0
	var at_1x := _play(config, 1, minutes)
	var at_3x := _play(config, 3, minutes)
	var at_10x := _play(config, 10, minutes)
	assert_gt(at_1x.cash, 100.0, "earned something")
	assert_almost(at_3x.cash, at_1x.cash, at_1x.cash * 0.01, "3x matches 1x within 1%")
	assert_almost(at_10x.cash, at_1x.cash, at_1x.cash * 0.01, "10x matches 1x within 1%")
	assert_almost(at_10x.creators[0].followers, at_1x.creators[0].followers, at_1x.creators[0].followers * 0.01)
	assert_eq(at_10x.creators[0].activity_id, at_1x.creators[0].activity_id, "same behaviour at any speed")
