extends TestCase


func _setup() -> Array:
	var config := load_config()
	var state := GameState.new_game(config, 33)
	state.active_trends = []
	var ava := state.creators[0]
	ava.content_experience = {}
	for content_id in ContentRules.assignable_ids(config):
		ava.content_experience[content_id] = 1.0
	return [config, state, ava]


func _segment(config: GameConfig, segment_id: String) -> Dictionary:
	return AudienceModel.segment(config, segment_id)


func test_neutral_look_has_neutral_fit() -> void:
	var config := load_config()
	var market := AudienceModel.market({}, "glamour", config)
	assert_almost(float(market["fit"]), 1.0, 0.0001)
	assert_almost(float(market["multiplier"]), 1.0, 0.0001)


func test_segments_react_differently_to_the_same_change() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var ava: CreatorState = s[2]
	var after := Appearance.preview(ava, config, "breast_augmentation")
	var bombshell := _segment(config, "bombshell_fans")
	var natural := _segment(config, "natural_fans")
	assert_gt(AudienceModel.segment_appeal(bombshell, after.appearance_tags, config),
		AudienceModel.segment_appeal(bombshell, ava.appearance_tags, config), "bombshell fans love it")
	assert_lt(AudienceModel.segment_appeal(natural, after.appearance_tags, config),
		AudienceModel.segment_appeal(natural, ava.appearance_tags, config), "natural fans don't")


func test_augmentation_does_not_raise_income_universally() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var after := Appearance.preview(ava, config, "breast_augmentation")
	var socials_before := float(Economy.work_breakdown(ava, state, config, "social_media")["cash"])
	var socials_after := float(Economy.work_breakdown(after, state, config, "social_media")["cash"])
	var premium_before := float(Economy.work_breakdown(ava, state, config, "solo_premium")["cash"])
	var premium_after := float(Economy.work_breakdown(after, state, config, "solo_premium")["cash"])
	assert_lt(socials_after, socials_before, "worse fit with mainstream/natural audiences")
	assert_gt(premium_after, premium_before, "better fit with premium/bombshell audiences")


func test_tattoo_helps_alt_audiences_not_wholesome_ones() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var ava: CreatorState = s[2]
	var after := Appearance.preview(ava, config, "rose_tattoo")
	var alt := _segment(config, "alt_fans")
	var gnd := _segment(config, "gnd_fans")
	assert_gt(AudienceModel.segment_appeal(alt, after.appearance_tags, config), AudienceModel.segment_appeal(alt, ava.appearance_tags, config))
	assert_lt(AudienceModel.segment_appeal(gnd, after.appearance_tags, config), AudienceModel.segment_appeal(gnd, ava.appearance_tags, config))


func test_appearance_tags_influence_revenue() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var base := float(Economy.work_breakdown(ava, state, config, "glamour")["cash"])
	ava.base_tags["glamour"] = 1.0
	Appearance.refresh(ava, config)
	assert_gt(float(Economy.work_breakdown(ava, state, config, "glamour")["cash"]), base)


func test_different_preferences_change_earnings() -> void:
	# Same creator and content; only the audience's taste changes.
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var base := float(Economy.work_breakdown(ava, state, config, "social_media")["cash"])
	for segment: Dictionary in config.segments:
		if str(segment["id"]) == "natural_fans":
			segment["likes"] = {}
			segment["dislikes"] = {"natural": 1.0}
	assert_lt(float(Economy.work_breakdown(ava, state, config, "social_media")["cash"]), base)


func test_fan_mix_drifts_toward_new_audience_and_sums_to_one() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var ava: CreatorState = s[2]
	var before := float(ava.fan_mix.get("premium_fans", 0.0))
	AudienceModel.drift_mix(ava, config, "topless_premium", 24.0)
	assert_gt(float(ava.fan_mix["premium_fans"]), before)
	var total := 0.0
	for segment_id in ava.fan_mix:
		total += float(ava.fan_mix[segment_id])
	assert_almost(total, 1.0, 0.0001)


func test_unhappy_existing_fans_lower_subscription_value() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var ava: CreatorState = s[2]
	ava.fan_mix = {"natural_fans": 1.0}
	var happy := AudienceModel.fan_value(ava, config)
	var after := Appearance.preview(ava, config, "breast_augmentation")
	assert_lt(AudienceModel.fan_value(after, config), happy)


func test_reputation_boosts_subscriber_target() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.reputation = 10.0
	var low := float(Economy.work_breakdown(ava, state, config, "solo_premium")["target_subscribers"])
	ava.reputation = 90.0
	assert_gt(float(Economy.work_breakdown(ava, state, config, "solo_premium")["target_subscribers"]), low)


func test_socials_is_a_funnel_and_premium_is_the_earner() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var socials := Economy.work_breakdown(ava, state, config, "social_media")
	var premium := Economy.work_breakdown(ava, state, config, "solo_premium")
	assert_gt(float(socials["followers"]), float(premium["followers"]) * 2.0, "socials grow followers")
	assert_gt(float(socials["reputation"]), 0.0, "socials build reputation")
	assert_gt(float(premium["cash"]), float(socials["cash"]) * 2.0, "premium earns")
	assert_gt(float(premium["target_subscribers"]), float(socials["target_subscribers"]) * 3.0, "premium converts")


func test_custom_content_pays_per_subscriber_and_needs_subscribers() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.subscribers = 10.0
	assert_eq(int(ContentRules.check(ava, "custom_content", state, config)["status"]), ContentRules.Status.NEEDS_SUBSCRIBERS)
	ava.subscribers = 100.0
	assert_true(ContentRules.can_assign(ava, "custom_content", state, config))
	var few := float(Economy.work_breakdown(ava, state, config, "custom_content")["custom_sales"])
	ava.subscribers = 200.0
	assert_almost(float(Economy.work_breakdown(ava, state, config, "custom_content")["custom_sales"]), few * 2.0, 0.01)
	assert_almost(float(Economy.work_breakdown(ava, state, config, "custom_content")["subscribers"]), 0.0, 0.0001, "customs don't churn subs")


func test_collab_content_respects_boundaries_and_charges_fees() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	state.get_room("studio_1").level = 2
	ContentRules.refresh_unlocks(state, config)
	for content_id in ["collab_boy_girl", "collab_girl_girl", "topless_premium"]:
		assert_eq(int(ContentRules.check(ava, content_id, state, config)["status"]), ContentRules.Status.DECLINED, content_id)
	ava.content_declines = []
	assert_true(ContentRules.can_assign(ava, "collab_girl_girl", state, config), "allowed once she's open to it")
	assert_gt(float(Economy.work_breakdown(ava, state, config, "collab_girl_girl")["fees"]), 0.0)


func test_trend_tags_reward_matching_looks() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	state.active_trends = [{"id": "bombshell_craze", "remaining_minutes": 600.0, "duration_minutes": 600.0}]
	var natural_look := float(TrendSystem.modifiers(state, config, ava, "glamour")["income"])
	var bombshell := Appearance.preview(ava, config, "breast_augmentation")
	assert_gt(float(TrendSystem.modifiers(state, config, bombshell, "glamour")["income"]), natural_look)
