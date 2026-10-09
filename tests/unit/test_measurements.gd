extends TestCase
## Body measurements: plausibility, consistency with looks, rendering, procedures and audiences.


func _creator(config: GameConfig, template_id: String) -> CreatorState:
	return CreatorSetup.create(config.creator_templates[template_id], config)


func _all(config: GameConfig) -> Array[CreatorState]:
	var result: Array[CreatorState] = []
	for template_id in config.creator_order:
		result.append(_creator(config, template_id))
	return result


func test_every_template_has_plausible_adult_measurements() -> void:
	var config := load_config()
	for creator in _all(config):
		assert_true(creator.measurements != null, creator.id + " has measurements")
		assert_true(creator.age >= 21, creator.id + " is 21+")
		var problems := BodyShape.validate(creator.measurements, config)
		assert_true(problems.is_empty(), "%s plausible: %s" % [creator.id, ", ".join(problems)])


func test_measurements_vary_meaningfully_between_creators() -> void:
	var config := load_config()
	var seen := {}
	var heights: Array[float] = []
	var busts: Array[float] = []
	var hips: Array[float] = []
	for creator in _all(config):
		var key := creator.measurements.summary()
		assert_false(seen.has(key), "unique measurements: " + key)
		seen[key] = true
		heights.append(creator.measurements.height_cm)
		busts.append(creator.measurements.bust_cm)
		hips.append(creator.measurements.hips_cm)
	assert_gt(heights.max() - heights.min(), 15.0, "height range")
	assert_gt(busts.max() - busts.min(), 18.0, "bust range")
	assert_gt(hips.max() - hips.min(), 15.0, "hip range")


func test_reference_body_renders_like_the_original_variants() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	assert_eq(ava.measurements.summary(), "168 cm  -  96 / 66 / 99 cm")
	var spec := Appearance.render_spec(ava, config)
	assert_almost(float(spec["bust"]), 1.0, 0.001)
	assert_almost(float(spec["hips"]), 1.0, 0.001)
	assert_almost(float(spec["glutes"]), 1.0, 0.001)
	assert_almost(float(spec["waist"]), 1.0, 0.001)
	assert_almost(float(spec["height_scale"]), 1.0, 0.001)
	ava.measurements.apply_delta(config.look_item("breast_augmentation")["measurements"])
	assert_almost(float(Appearance.render_spec(ava, config)["bust"]), 1.75, 0.001, "augmented = old enhanced variant")
	ava.measurements.apply_delta(config.look_item("bbl")["measurements"])
	var curvy := Appearance.render_spec(ava, config)
	assert_almost(float(curvy["hips"]), 1.25, 0.001, "BBL = old curvy hips")
	assert_almost(float(curvy["glutes"]), 1.8, 0.001, "BBL = old curvy glutes")


func test_template_measurements_match_their_visible_look() -> void:
	var config := load_config()
	var chloe := _creator(config, "chloe")
	var natural: Dictionary = config.creator_templates["chloe"]["body"]
	assert_eq(chloe.look_value("bust"), "enhanced")
	assert_almost(chloe.measurements.bust_cm, float(natural["bust_cm"]) + 10.0, 0.001, "enhanced look includes the augmentation")
	assert_gt(chloe.tag("enhanced"), 0.5)
	assert_eq(chloe.procedure_history.size(), 2, "augmentation and lip filler on record")


func test_measurements_produce_visibly_different_bodies() -> void:
	var config := load_config()
	var lily := Appearance.render_spec(_creator(config, "lily"), config)
	var chloe := Appearance.render_spec(_creator(config, "chloe"), config)
	var roxy := Appearance.render_spec(_creator(config, "roxy"), config)
	var sienna := Appearance.render_spec(_creator(config, "sienna"), config)
	assert_gt(float(chloe["bust"]) / float(lily["bust"]), 2.0, "bust size")
	assert_gt(float(roxy["hips"]) - float(lily["hips"]), 0.3, "hip width")
	assert_gt(float(roxy["waist"]) - float(chloe["waist"]), 0.08, "waist width")
	assert_gt(float(roxy["glutes"]) - float(lily["glutes"]), 0.3, "buttock proportions")
	assert_gt(float(sienna["height_scale"]) - float(lily["height_scale"]), 0.08, "height")
	assert_gt(float(sienna["shoulders"]), float(lily["shoulders"]), "athletic shoulders")


func test_body_tags_come_from_combinations_of_measurements() -> void:
	var config := load_config()
	var lily := _creator(config, "lily")
	var sienna := _creator(config, "sienna")
	var roxy := _creator(config, "roxy")
	var chloe := _creator(config, "chloe")
	assert_gt(lily.tag("petite"), 0.8, "short and small-framed")
	assert_gt(sienna.tag("athletic"), 0.8, "toned")
	assert_lt(sienna.tag("petite"), 0.01, "tall")
	assert_gt(roxy.tag("voluptuous"), 0.3, "full figure")
	assert_gt(chloe.tag("curvy"), 0.9, "hourglass")
	assert_lt(lily.tag("curvy"), 0.05)
	# Fitness tone feeds the styling tags too.
	assert_gt(sienna.tag("fitness"), 0.9)


func test_breast_augmentation_updates_bust_only_and_visibly() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.cash = 100_000.0
	var ava := state.creators[0]
	var before := ava.measurements.clone()
	var spec_before := Appearance.render_spec(ava, config)
	var tags_before := ava.appearance_tags.duplicate()
	assert_true(bool(Appearance.purchase(state, config, ava, "breast_augmentation")["ok"]))
	assert_almost(ava.measurements.bust_cm, before.bust_cm + 10.0, 0.001)
	assert_almost(ava.measurements.waist_cm, before.waist_cm, 0.001)
	assert_almost(ava.measurements.hips_cm, before.hips_cm, 0.001)
	assert_almost(ava.measurements.height_cm, before.height_cm, 0.001)
	assert_gt(float(Appearance.render_spec(ava, config)["bust"]), float(spec_before["bust"]) + 0.5, "bigger visible bust")
	assert_gt(ava.tag("enhanced"), float(tags_before["enhanced"]) + 0.5)
	assert_gt(ava.tag("voluptuous"), float(tags_before.get("voluptuous", 0.0)), "fuller figure tag")
	assert_true(ava.is_recovering(), "recovery preserved")


func test_bbl_updates_hips_and_buttock_variant() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.cash = 100_000.0
	var ava := state.creators[0]
	var before := ava.measurements.clone()
	var glutes_before := float(Appearance.render_spec(ava, config)["glutes"])
	assert_true(bool(Appearance.purchase(state, config, ava, "bbl")["ok"]))
	assert_almost(ava.measurements.hips_cm, before.hips_cm + 7.0, 0.001)
	assert_almost(ava.measurements.bust_cm, before.bust_cm, 0.001)
	assert_gt(float(Appearance.render_spec(ava, config)["glutes"]), glutes_before + 0.5)
	assert_gt(ava.tag("enhanced"), 0.5)
	assert_true(ava.is_recovering())


func test_styling_and_modifications_never_change_measurements() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	state.cash = 100_000.0
	var ava := state.creators[0]
	var before := ava.measurements.summary()
	for item_id in ["lip_filler", "hair_color:pink", "outfit:lingerie", "makeup:glam", "rose_tattoo", "belly_piercing", "nose_piercing", "arm_sleeve", "hair_style:bob"]:
		ava.recovery = {}
		assert_true(bool(Appearance.purchase(state, config, ava, item_id)["ok"]), "bought " + item_id)
		assert_eq(ava.measurements.summary(), before, item_id + " leaves measurements alone")


func test_preview_does_not_change_real_measurements() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 3)
	var ava := state.creators[0]
	var after := Appearance.preview(ava, config, "breast_augmentation")
	assert_almost(after.measurements.bust_cm, 106.0, 0.001)
	assert_almost(ava.measurements.bust_cm, 96.0, 0.001, "real creator untouched")


func test_imperial_conversion() -> void:
	var m := BodyMeasurements.create(168.0, 96.0, 66.0, 99.0)
	assert_eq(m.bwh_text(false), "96 / 66 / 99 cm")
	assert_eq(m.bwh_text(true), "37.8 / 26.0 / 39.0 in")
	assert_eq(m.height_text(true), "5'6\"")
	assert_almost(BodyMeasurements.cm_to_inches(2.54), 1.0, 0.0001)


func test_body_type_changes_audience_appeal_in_opposite_directions() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 9)
	state.active_trends = []
	var ava := state.creators[0]
	var petite := ava.clone()
	petite.measurements = BodyMeasurements.create(154.0, 80.0, 60.0, 85.0, 0.35)
	Appearance.refresh(petite, config)
	var curvy := ava.clone()
	curvy.measurements = BodyMeasurements.create(168.0, 106.0, 66.0, 108.0, 0.35)
	Appearance.refresh(curvy, config)
	var petite_fans := AudienceModel.segment(config, "petite_fans")
	var curves_fans := AudienceModel.segment(config, "curves_fans")
	assert_gt(AudienceModel.segment_appeal(petite_fans, petite.appearance_tags, config),
		AudienceModel.segment_appeal(petite_fans, curvy.appearance_tags, config), "petite fans prefer the petite body")
	assert_gt(AudienceModel.segment_appeal(curves_fans, curvy.appearance_tags, config),
		AudienceModel.segment_appeal(curves_fans, petite.appearance_tags, config), "curves fans prefer the curvy body")


func test_no_body_type_earns_more_for_every_content() -> void:
	var config := load_config()
	var state := GameState.new_game(config, 9)
	state.active_trends = []
	state.get_room("studio_1").level = 3
	var ava := state.creators[0]
	ava.content_experience = {}
	for content_id in ContentRules.assignable_ids(config):
		ava.content_experience[content_id] = 1.0
	var bodies := {
		"petite": BodyMeasurements.create(154.0, 80.0, 60.0, 85.0, 0.35),
		"athletic": BodyMeasurements.create(174.0, 88.0, 63.0, 94.0, 0.9),
		"voluptuous": BodyMeasurements.create(168.0, 108.0, 68.0, 110.0, 0.25),
	}
	var winners := {}
	for content_id in ContentRules.assignable_ids(config):
		var best := ""
		var best_cash := -INF
		for body_id: String in bodies:
			var copy := ava.clone()
			copy.measurements = (bodies[body_id] as BodyMeasurements).clone()
			Appearance.refresh(copy, config)
			var cash := float(Economy.work_breakdown(copy, state, config, content_id, state.get_room("studio_1"))["cash"])
			if cash > best_cash:
				best_cash = cash
				best = body_id
		winners[best] = true
	assert_gt(float(winners.size()), 1.0, "different content favours different bodies: %s" % str(winners.keys()))
