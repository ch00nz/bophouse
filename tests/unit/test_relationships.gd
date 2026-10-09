extends TestCase
## Housemate relationships and autonomous social interactions.


func _pair_in_lounge(config: GameConfig, ids: Array, seed: int = 21) -> GameState:
	var state := house_with(config, ids, seed)
	var lounge := state.get_room("living_1")
	for creator in state.creators:
		creator.travel_path = []
		creator.room_id = lounge.id
		creator.activity_id = "socialise"
		creator.position = lounge.spot_position(0.4)
	return state


func test_every_pair_has_a_relationship() -> void:
	var config := load_config()
	var state := house_with(config, ["mia", "jade"])
	assert_eq(state.relationships.size(), 3, "three pairs for three residents")
	var rel := Relationships.get_pair(state, config, state.get_creator("mia"), state.get_creator("jade"))
	for value_id in Relationships.VALUES:
		assert_true(rel.has(value_id))


func test_relaxing_together_produces_interactions_and_changes_relationships() -> void:
	var config := load_config()
	var state := _pair_in_lounge(config, ["mia"])
	var ava := state.get_creator("ava")
	var mia := state.get_creator("mia")
	var before := (Relationships.get_pair(state, config, ava, mia)).duplicate()
	var interval := float(config.social["interval_minutes"])
	var events: Array = []
	for i in 6:
		events.append_array(Relationships.step(state, config, interval))
	assert_eq(events.size(), 6, "one interaction per interval")
	var after := Relationships.get_pair(state, config, ava, mia)
	assert_true(after["friendship"] != before["friendship"] or after["rivalry"] != before["rivalry"], "relationship moved")
	assert_true(ava.has_reaction(state.game_minutes) or not ava.reaction.is_empty(), "reaction bubble set")
	assert_eq(str(ava.reaction["with"]), "mia")
	assert_eq(state.social_log.size(), 6)


func test_no_interactions_when_apart_or_in_private_rooms() -> void:
	var config := load_config()
	var state := _pair_in_lounge(config, ["mia"])
	var mia := state.get_creator("mia")
	mia.room_id = mia.home_room_id
	assert_true(Relationships.step(state, config, 500.0).is_empty(), "different rooms")
	var ava := state.get_creator("ava")
	ava.room_id = mia.home_room_id
	assert_true(Relationships.step(state, config, 500.0).is_empty(), "bedrooms are private")


func test_drama_makes_disagreements_likelier() -> void:
	var config := load_config()
	var calm := _pair_in_lounge(config, ["mia"])
	var dramatic := _pair_in_lounge(config, ["roxy"])
	var calm_share := _negative_share(Relationships.weights(calm, config, calm.get_creator("ava"), calm.get_creator("mia")))
	var drama_share := _negative_share(Relationships.weights(dramatic, config, dramatic.get_creator("ava"), dramatic.get_creator("roxy")))
	assert_gt(drama_share, calm_share * 2.0, "Roxy stirs things up")


func test_social_rolls_are_deterministic_and_saved() -> void:
	var config := load_config()
	var a := _pair_in_lounge(config, ["roxy"], 77)
	var b := SaveSystem.from_save_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_save_dict(a, 1.0))))
	var interval := float(config.social["interval_minutes"])
	var ids_a: Array = []
	var ids_b: Array = []
	for i in 10:
		for e: Dictionary in Relationships.step(a, config, interval):
			ids_a.append(e["id"])
		for e: Dictionary in Relationships.step(b, config, interval):
			ids_b.append(e["id"])
	assert_eq(ids_a, ids_b, "same seed and state, same interactions after a save round trip")


func test_log_is_capped() -> void:
	var config := load_config()
	var state := _pair_in_lounge(config, ["mia"])
	var interval := float(config.social["interval_minutes"])
	for i in 100:
		Relationships.step(state, config, interval)
	assert_eq(state.social_log.size(), int(config.social["log_size"]))


func _negative_share(options: Array) -> float:
	var total := 0.0
	var negative := 0.0
	for option: Dictionary in options:
		total += float(option["weight"])
		if str(option["interaction"].get("kind", "")) == "negative":
			negative += float(option["weight"])
	return negative / total if total > 0.0 else 0.0
