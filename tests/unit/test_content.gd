extends TestCase


func _setup() -> Array:
	var config := load_config()
	var state := GameState.new_game(config, 5)
	state.active_trends = [] # isolate content effects from trends
	return [config, state, state.creators[0]]


func test_changing_content_changes_earnings() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_experience = {"social_media": 1.0, "glamour": 1.0, "solo_premium": 1.0}
	var socials := Economy.work_breakdown(ava, state, config, "social_media")
	var glamour := Economy.work_breakdown(ava, state, config, "glamour")
	var premium := Economy.work_breakdown(ava, state, config, "solo_premium")
	assert_gt(float(glamour["cash"]), float(socials["cash"]), "glamour pays more than socials")
	assert_gt(float(socials["followers"]), float(glamour["followers"]), "socials grow followers faster")
	assert_gt(float(premium["target_subscribers"]), float(glamour["target_subscribers"]), "premium converts more subscribers")
	assert_lt(float(premium["energy"]), float(socials["energy"]), "premium is more draining")


func test_content_rooms_come_from_room_data() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	assert_true(RoomProduction.supports(config, state.get_room("living_1"), "social_media"))
	assert_true(RoomProduction.supports(config, state.get_room("bedroom_1"), "solo_premium"), "bedrooms host premium content")
	assert_true(RoomProduction.supports(config, state.get_room("studio_1"), "glamour"))
	assert_false(RoomProduction.supports(config, state.get_room("living_1"), "solo_premium"), "no premium sets in the lounge")
	assert_false(RoomProduction.supports(config, state.get_room("stairs_0"), "social_media"))
	assert_eq(ActivityResolver.room_type(state.creators[0], "sleep", config), "bedroom")


func test_declined_content_cannot_be_assigned() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	state.get_room("studio_1").level = 3
	ContentRules.refresh_unlocks(state, config)
	var result := ContentRules.check(ava, "topless_premium", state, config)
	assert_false(bool(result["ok"]))
	assert_eq(int(result["status"]), ContentRules.Status.DECLINED)
	ava.stats["confidence"] = 100.0 # no amount of stats or upgrades overrides a boundary
	assert_false(ContentRules.can_assign(ava, "topless_premium", state, config))


func test_stat_requirements_gate_content() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	assert_true(ContentRules.can_assign(ava, "glamour", state, config))
	ava.stats["looks"] = 30.0
	var result := ContentRules.check(ava, "glamour", state, config)
	assert_eq(int(result["status"]), ContentRules.Status.NEEDS_STATS)


func test_livestream_unlocks_with_studio_upgrade_and_stays_unlocked() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	assert_eq(int(ContentRules.check(ava, "livestream", state, config)["status"]), ContentRules.Status.LOCKED)
	state.cash = 10_000.0
	RoomUpgrades.try_upgrade(state, config, "studio_1")
	var unlocked := ContentRules.refresh_unlocks(state, config)
	assert_true(unlocked.has("livestream"))
	assert_true(ContentRules.can_assign(ava, "livestream", state, config))
	assert_eq(ContentRules.refresh_unlocks(state, config).size(), 0, "unlock only reported once")


func test_new_content_starts_less_productive() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_experience = {"glamour": 0.0}
	var fresh := float(Economy.work_breakdown(ava, state, config, "glamour")["cash"])
	ava.content_experience = {"glamour": 1.0}
	var seasoned := float(Economy.work_breakdown(ava, state, config, "glamour")["cash"])
	assert_almost(fresh / seasoned, config.tuning_f("content", "ramp_floor", 0.7), 0.001)


func test_adaptability_speeds_up_settling_in() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var ava: CreatorState = s[2]
	ava.stats["adaptability"] = 10.0
	var slow := Economy.experience_rate_per_hour(ava, config)
	ava.stats["adaptability"] = 90.0
	assert_gt(Economy.experience_rate_per_hour(ava, config), slow)


func test_loved_content_is_less_draining_on_mood() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var loved := float(Economy.work_breakdown(ava, state, config, "glamour")["mood"])
	ava.content_accepts = []
	var neutral := float(Economy.work_breakdown(ava, state, config, "glamour")["mood"])
	assert_gt(loved, neutral)


func test_valid_focus_falls_back_when_invalid() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_focus = "topless_premium"
	var fixed := ContentRules.valid_focus(ava, state, config)
	assert_true(fixed != "topless_premium" and ContentRules.can_assign(ava, fixed, state, config))
