extends TestCase

const TEST_PATH := "user://test_savegame.json"


func after_each() -> void:
	SaveSystem.delete(TEST_PATH)


func _played_state(config: GameConfig) -> GameState:
	var state := GameState.new_game(config)
	Simulation.advance(state, config, 37.0) # mid-walk to the studio
	state.cash = 1234.5
	state.get_room("studio_1").level = 2
	return state


func test_round_trip_preserves_state() -> void:
	var config := load_config()
	var state := _played_state(config)
	var loaded := SaveSystem.from_save_dict(SaveSystem.to_save_dict(state, 1000.0))
	assert_true(loaded != null)
	assert_almost(loaded.cash, 1234.5)
	assert_almost(loaded.game_minutes, state.game_minutes)
	assert_eq(loaded.get_room("studio_1").level, 2)
	var a := state.creators[0]
	var b := loaded.creators[0]
	assert_eq(b.id, a.id)
	assert_eq(b.age, a.age)
	assert_almost(b.followers, a.followers)
	assert_almost(b.energy, a.energy)
	assert_eq(b.activity_id, a.activity_id)
	assert_eq(b.position, a.position)
	assert_eq(b.travel_path.size(), a.travel_path.size())
	assert_eq(b.target_room_id, a.target_room_id)
	assert_eq(b.stats, a.stats)


func test_round_trip_preserves_content_choices_and_trends() -> void:
	var config := load_config()
	var state := _played_state(config)
	var ava := state.creators[0]
	ava.content_focus = "social_media"
	ava.content_experience = {"glamour": 1.0, "social_media": 0.42}
	state.unlocked_content = ["livestream"]
	var loaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(state, 1.0))))
	var b := loaded.creators[0]
	assert_eq(b.content_focus, "social_media")
	assert_almost(b.experience("social_media"), 0.42)
	assert_eq(loaded.unlocked_content, ["livestream"])
	assert_eq(TrendSystem.active_ids(loaded), TrendSystem.active_ids(state))
	assert_eq(loaded.next_trend_id, state.next_trend_id)
	assert_eq(loaded.trend_rng_state, state.trend_rng_state, "64-bit RNG state survives JSON")
	assert_almost(float(loaded.active_trends[0]["remaining_minutes"]), float(state.active_trends[0]["remaining_minutes"]))


func test_v1_prototype_save_still_loads() -> void:
	var config := load_config()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v1.json"))
	assert_eq(int(data["version"]), 1, "fixture is a genuine v1 save")
	var state := SaveSystem.from_save_dict(data)
	assert_true(state != null, "v1 save loads")
	SaveSystem.post_load(state, config)
	assert_true(SaveSystem.is_compatible(state, config))
	var ava := state.creators[0]
	assert_eq(ava.look_value("hair_style"), "long_waves", "v1 creator gets a full v3 look")
	assert_eq(ava.activity_id, "work", "film_content migrated to work")
	assert_eq(ava.content_focus, "glamour")
	assert_almost(ava.experience("glamour"), 1.0)
	assert_true(ava.content_accepts.has("solo_premium"), "content ids renamed")
	assert_true(ava.content_declines.has("topless_premium"), "boundaries carried over")
	assert_false(ava.content_declines.has("premium"))
	assert_eq(state.active_trends.size(), 2, "trends initialised")
	assert_true(state.unlocked_content.has("livestream"), "studio was level 2 in the fixture")
	assert_almost(state.cash, float(data["state"]["cash"]), 0.001, "cash preserved")
	# And it keeps running happily.
	Simulation.advance(state, config, 24.0 * 60.0, 5.0)
	assert_gt(state.cash, float(data["state"]["cash"]))


func test_round_trip_preserves_appearance_and_audience() -> void:
	var config := load_config()
	var state := _played_state(config)
	state.cash = 100_000.0
	var ava := state.creators[0]
	Appearance.purchase(state, config, ava, "breast_augmentation")
	Appearance.purchase(state, config, ava, "outfit:lingerie")
	Appearance.purchase(state, config, ava, "makeup:glam")
	Simulation.advance(state, config, 300.0, 5.0)
	ava.reputation = 63.5
	var loaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(state, 1.0))))
	SaveSystem.post_load(loaded, config)
	var b := loaded.creators[0]
	assert_eq(b.look, ava.look, "look slots")
	assert_eq(b.owned_styles, ava.owned_styles, "purchased styles")
	assert_eq(b.procedure_history.size(), 1, "procedure history")
	assert_true(b.is_recovering(), "recovery status")
	assert_almost(float(b.recovery["remaining_minutes"]), float(ava.recovery["remaining_minutes"]), 0.001)
	for tag_id in ava.appearance_tags:
		assert_almost(b.tag(tag_id), ava.tag(tag_id), 0.0001, "tag " + tag_id)
	for segment_id in ava.fan_mix:
		assert_almost(float(b.fan_mix[segment_id]), float(ava.fan_mix[segment_id]), 0.0001, "fan mix " + segment_id)
	assert_almost(b.reputation, 63.5, 0.0001)
	assert_eq(b.appearance_prefs, ava.appearance_prefs)


func test_v2_save_still_loads() -> void:
	var config := load_config()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/save_v2.json"))
	assert_eq(int(data["version"]), 2, "fixture is a genuine v2 save")
	var state := SaveSystem.from_save_dict(data)
	assert_true(state != null, "v2 save loads")
	SaveSystem.post_load(state, config)
	assert_true(SaveSystem.is_compatible(state, config))
	var ava := state.creators[0]
	assert_eq(ava.content_focus, str(data["state"]["creators"][0]["content_focus"]), "content choice kept")
	assert_eq(ava.look_value("outfit"), "casual", "default look filled in")
	assert_gt(ava.tag("natural"), 0.0, "tags computed")
	assert_false(ava.fan_mix.is_empty(), "fan mix initialised")
	assert_almost(state.cash, float(data["state"]["cash"]), 0.001, "cash preserved")
	Simulation.advance(state, config, 24.0 * 60.0, 5.0)
	assert_gt(state.cash, float(data["state"]["cash"]))


func test_round_trip_through_file() -> void:
	var config := load_config()
	var state := _played_state(config)
	assert_eq(SaveSystem.write(TEST_PATH, state, 5000.0), OK)
	var loaded := SaveSystem.read(TEST_PATH)
	assert_true(loaded != null)
	assert_almost(loaded.cash, state.cash)
	assert_almost(loaded.last_seen_unix, 5000.0)
	assert_true(SaveSystem.is_compatible(loaded, config))


func test_loaded_state_keeps_simulating_identically() -> void:
	var config := load_config()
	var state := _played_state(config)
	var loaded := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(state, 1.0))))
	Simulation.advance(state, config, 300.0)
	Simulation.advance(loaded, config, 300.0)
	assert_almost(loaded.cash, state.cash, 0.01)
	assert_eq(loaded.creators[0].activity_id, state.creators[0].activity_id)


func test_rejects_corrupt_and_future_saves() -> void:
	assert_true(SaveSystem.from_save_dict("nonsense") == null)
	assert_true(SaveSystem.from_save_dict({"version": 999, "state": {}}) == null)
	assert_true(SaveSystem.from_save_dict({"state": {}}) == null)
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_true(SaveSystem.read(TEST_PATH) == null)


func test_missing_save_returns_null() -> void:
	assert_true(SaveSystem.read("user://does_not_exist.json") == null)


func test_creditable_seconds_clamps() -> void:
	assert_almost(OfflineProgress.creditable_seconds(1000.0, 1600.0, 3600.0), 600.0)
	assert_almost(OfflineProgress.creditable_seconds(1000.0, 999999.0, 3600.0), 3600.0)
	assert_almost(OfflineProgress.creditable_seconds(1000.0, 500.0, 3600.0), 0.0, 0.0001, "clock moved backwards")
	assert_almost(OfflineProgress.creditable_seconds(0.0, 500.0, 3600.0), 0.0, 0.0001, "never seen")


func test_offline_progress_earns_and_advances_clock() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	state.last_seen_unix = 10_000.0
	var cash_before := state.cash
	var minutes_before := state.game_minutes
	var summary := OfflineProgress.apply(state, config, 10_000.0 + 3600.0)
	assert_almost(float(summary["real_seconds"]), 3600.0)
	assert_gt(float(summary["cash"]), 0.0)
	assert_almost(state.cash, cash_before + float(summary["cash"]), 0.01)
	var expected_minutes := 3600.0 * config.tuning_f("time", "game_minutes_per_real_second", 2.0)
	assert_almost(state.game_minutes, minutes_before + expected_minutes, 0.01)
	assert_almost(state.last_seen_unix, 13_600.0)


func test_offline_is_capped() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	state.last_seen_unix = 1.0
	var summary := OfflineProgress.apply(state, config, 1.0 + 10_000_000.0)
	assert_true(bool(summary["capped"]))
	assert_almost(float(summary["real_seconds"]), config.tuning_f("offline", "max_seconds", 0.0))


func test_offline_efficiency_reduces_earnings() -> void:
	var config := load_config()
	var live := GameState.new_game(config)
	var away := GameState.new_game(config)
	away.last_seen_unix = 100.0
	var seconds := 1800.0
	OfflineProgress.apply(away, config, 100.0 + seconds)
	var minutes := seconds * config.tuning_f("time", "game_minutes_per_real_second", 2.0)
	Simulation.advance(live, config, minutes, config.tuning_f("time", "offline_step_minutes", 5.0))
	assert_lt(away.cash, live.cash)


func test_clock_rollback_grants_nothing_twice() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	state.last_seen_unix = 10_000.0
	OfflineProgress.apply(state, config, 13_600.0) # +1h credited
	var cash_after_first := state.cash
	var summary := OfflineProgress.apply(state, config, 12_000.0) # clock rolled back
	assert_almost(float(summary["real_seconds"]), 0.0)
	assert_almost(state.cash, cash_after_first)
	OfflineProgress.apply(state, config, 13_600.0) # forward again to same moment
	assert_almost(state.cash, cash_after_first, 0.0001, "same hour must not be paid twice")
