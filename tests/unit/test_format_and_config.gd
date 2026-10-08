extends TestCase


func test_money_format() -> void:
	assert_eq(Fmt.money(0.0), "$0")
	assert_eq(Fmt.money(1234.9), "$1,234")
	assert_eq(Fmt.money(-50.0), "-$50")
	assert_eq(Fmt.money(2_500_000.0), "$2.50M")


func test_compact_format() -> void:
	assert_eq(Fmt.compact(950.0), "950")
	assert_eq(Fmt.compact(9999.0), "9,999")
	assert_eq(Fmt.compact(12_345.0), "12.3K")


func test_duration_format() -> void:
	assert_eq(Fmt.duration(45.0), "45s")
	assert_eq(Fmt.duration(125.0), "2m 5s")
	assert_eq(Fmt.duration(7980.0), "2h 13m")


func test_data_files_are_consistent() -> void:
	var config := load_config()
	assert_false(config.balance.is_empty(), "balance loaded")
	for slot in config.house_layout:
		assert_false(config.room_type(str(slot["type"])).is_empty(), "layout room type %s exists" % slot["type"])
	for activity_id in config.activities:
		var room_type := str(config.activity(activity_id).get("room_type", ""))
		if not room_type.is_empty():
			assert_false(config.room_type(room_type).is_empty(), "activity %s room type" % activity_id)
	for creator_id in config.creator_templates:
		assert_true(int(config.creator_templates[creator_id].get("age", 0)) >= 18, "%s is an adult" % creator_id)


func test_room_levels_are_ordered_and_priced() -> void:
	var config := load_config()
	for type_id in config.room_types:
		var levels: Array = config.room_type(type_id).get("levels", [])
		for i in levels.size():
			assert_eq(int(levels[i]["level"]), i + 1, "%s level numbering" % type_id)
			if i > 0:
				assert_gt(float(levels[i]["cost"]), float(levels[i - 1]["cost"]), "%s costs increase" % type_id)
				assert_gt(float(levels[i]["quality"]), float(levels[i - 1]["quality"]), "%s quality increases" % type_id)


func test_template_age_is_clamped_to_adult() -> void:
	var c := CreatorState.from_template({"id": "x", "age": 16})
	assert_eq(c.age, 18)
