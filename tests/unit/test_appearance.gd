extends TestCase


func _setup(cash: float = 100_000.0) -> Array:
	var config := load_config()
	var state := GameState.new_game(config, 21)
	state.cash = cash
	state.active_trends = []
	return [config, state, state.creators[0]]


func test_new_creator_has_full_look_and_tags() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var ava: CreatorState = s[2]
	for slot in Appearance.SINGLE_SLOTS:
		assert_false(config.look_option(slot, ava.look_value(slot)).is_empty(), "slot %s valid" % slot)
	assert_gt(ava.tag("natural"), 0.5, "Ava starts natural")
	assert_almost(ava.tag("enhanced"), 0.0, 0.0001)
	assert_true(Appearance.visible_tags(ava, config).has("natural"))


func test_catalogue_has_required_minimum() -> void:
	var config := load_config()
	assert_true(config.look_options["hair_color"].size() >= 3, "3 hair colours")
	assert_true(config.look_options["hair_style"].size() >= 2, "2 hairstyles")
	for outfit in ["casual", "glamour", "lingerie", "fitness"]:
		assert_false(config.look_option("outfit", outfit).is_empty(), "outfit " + outfit)
	for item_id in ["breast_augmentation", "bbl", "lip_filler", "nipple_piercing", "belly_piercing", "rose_tattoo"]:
		assert_false(config.look_item(item_id).is_empty(), "item " + item_id)


func test_purchase_deducts_exact_price_and_applies() -> void:
	var s := _setup(10_000.0)
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var price := float(config.look_item("lip_filler")["price"])
	var result := Appearance.purchase(state, config, ava, "lip_filler")
	assert_true(bool(result["ok"]), str(result.get("reason", "")))
	assert_almost(state.cash, 10_000.0 - price)
	assert_eq(ava.look_value("lips"), "full")
	assert_eq(ava.procedure_history.size(), 1)
	assert_eq(str(ava.procedure_history[0]["item_id"]), "lip_filler")


func test_cannot_buy_when_unaffordable() -> void:
	var s := _setup(50.0)
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var result := Appearance.purchase(state, config, ava, "breast_augmentation")
	assert_false(bool(result["ok"]))
	assert_false(bool(result["affordable"]))
	assert_almost(state.cash, 50.0)
	assert_eq(ava.look_value("bust"), "natural")


func test_preview_does_not_change_the_creator() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var tags_before := ava.appearance_tags.duplicate()
	var cash_before := state.cash
	var after := Appearance.preview(ava, config, "breast_augmentation")
	assert_eq(after.look_value("bust"), "enhanced", "preview shows the change")
	assert_gt(after.tag("enhanced"), 0.5)
	assert_eq(ava.look_value("bust"), "natural", "real creator untouched")
	assert_eq(ava.appearance_tags, tags_before)
	assert_false(ava.is_recovering())
	assert_almost(state.cash, cash_before)


func test_purchased_change_is_visible_in_render_spec() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var before := Appearance.render_spec(ava, config)
	Appearance.purchase(state, config, ava, "breast_augmentation")
	Appearance.purchase(state, config, ava, "outfit:lingerie")
	var after := Appearance.render_spec(ava, config)
	assert_gt(float(after["bust"]), float(before["bust"]), "bigger bust in the renderer")
	assert_eq(str(after["outfit"]["id"]), "lingerie")
	ava.recovery = {}
	Appearance.purchase(state, config, ava, "rose_tattoo")
	assert_true((Appearance.render_spec(ava, config)["tattoos"] as Array).has("rose_thigh"))


func test_owned_styles_switch_back_for_free() -> void:
	var s := _setup(1000.0)
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	Appearance.purchase(state, config, ava, "outfit:fitness")
	var cash := state.cash
	var result := Appearance.purchase(state, config, ava, "outfit:casual")
	assert_true(bool(result["ok"]))
	assert_almost(float(result["price"]), 0.0, 0.0001, "already owned")
	assert_almost(state.cash, cash)


func test_creator_can_decline_a_change() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.appearance_prefs = {"declines": ["bbl"], "wishes": []}
	var result := Appearance.purchase(state, config, ava, "bbl")
	assert_false(bool(result["ok"]))
	assert_eq(ava.look_value("body"), "natural")
	assert_almost(state.cash, 100_000.0)


func test_procedure_starts_recovery_that_counts_down() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	Appearance.purchase(state, config, ava, "breast_augmentation")
	var hours := float(config.look_item("breast_augmentation")["recovery"]["hours"])
	assert_true(ava.is_recovering())
	assert_almost(float(ava.recovery["remaining_minutes"]), hours * 60.0)
	Simulation.advance(state, config, hours * 60.0 * 0.5, 5.0)
	assert_true(ava.is_recovering(), "halfway: still recovering")
	assert_almost(float(ava.recovery["remaining_minutes"]), hours * 60.0 * 0.5, 0.01)
	Simulation.advance(state, config, hours * 60.0 * 0.5 + 5.0, 5.0)
	assert_false(ava.is_recovering(), "recovered")


func test_recovery_reduces_output_and_restricts_content() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var healthy := float(Economy.work_breakdown(ava, state, config, "glamour")["cash"])
	ava.recovery = {"item_id": "breast_augmentation", "remaining_minutes": 600.0, "total_minutes": 600.0}
	var healing := Economy.work_breakdown(ava, state, config, "glamour")
	assert_lt(float(healing["cash"]), healthy)
	assert_false(Appearance.recovery_allows(ava, config, "glamour"))
	assert_true(Appearance.recovery_allows(ava, config, "social_media"))


func test_recovering_creator_rests_in_the_bedroom() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.energy = 90.0
	ava.mood = 80.0
	ava.content_focus = "glamour"
	ava.recovery = {"item_id": "bbl", "remaining_minutes": 6000.0, "total_minutes": 6000.0}
	Simulation.advance(state, config, 90.0)
	assert_eq(ava.activity_id, CreatorBrain.RECOVER)
	assert_eq(state.get_room(ava.room_id).type_id, "bedroom")


func test_body_changes_blocked_while_recovering() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	Appearance.purchase(state, config, ava, "lip_filler")
	var result := Appearance.check_item(ava, state, config, "bbl")
	assert_false(bool(result["ok"]))
	assert_true(bool(Appearance.check_item(ava, state, config, "outfit:glamour")["ok"]), "styling still fine")


func test_makeover_estimate_shows_mixed_effects_without_applying() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var look_before := ava.look.duplicate(true)
	var eval := MakeoverEvaluator.evaluate(ava, state, config, "breast_augmentation")
	assert_eq(ava.look, look_before, "estimate never applies the change")
	assert_almost(state.cash, 100_000.0)
	assert_gt(float(eval["best"]["change"]), 1.0, "some content gains")
	assert_lt(float(eval["worst"]["change"]), 1.0, "some content loses")
	var gained := false
	var lost := false
	for change: Dictionary in eval["tag_changes"]:
		gained = gained or float(change["delta"]) > 0.0
		lost = lost or float(change["delta"]) < 0.0
	assert_true(gained and lost, "tags both gained and lost")
	assert_gt(float(eval["recovery"].get("hours", 0)), 0.0, "recovery reported")


func test_wished_change_lifts_mood_more() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.mood = 50.0
	Appearance.purchase(state, config, ava, "outfit:glamour") # on her wish list
	var wished_gain := ava.mood - 50.0
	ava.mood = 50.0
	Appearance.purchase(state, config, ava, "outfit:fitness")
	assert_gt(wished_gain, ava.mood - 50.0)
