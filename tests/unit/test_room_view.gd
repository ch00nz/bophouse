extends TestCase
## Room View (detailed room interiors): which rooms have one, who is shown, seats from furniture,
## seating and facing, and that staging never changes game state (it's presentation only).


func _state(config: GameConfig) -> GameState:
	var state := GameState.new_game(config, 3)
	state.cash = 1_000_000.0
	for id in ["mia", "roxy"]:
		if Housing.buildable_lots(state, config, "bedroom").is_empty():
			Upgrades.purchase(state, config, Upgrades.EXPANSION)
		Housing.build(state, config, Housing.buildable_lots(state, config, "bedroom")[0].id, "bedroom")
		Applications.move_in(state, config, id)
	return state


func _place(state: GameState, id: String, room_id: String, x: float, activity: String) -> CreatorState:
	var creator := state.get_creator(id)
	var room := state.get_room(room_id)
	creator.travel_path = []
	creator.target_room_id = ""
	creator.room_id = room_id
	creator.position = Vector2(room.column + x * room.width, room.storey)
	creator.activity_id = activity
	creator.reaction = {}
	return creator


func test_only_rooms_enabled_in_data_have_a_room_view() -> void:
	var config := load_config()
	var state := _state(config)
	assert_true(RoomStaging.supports(config, state.get_room("living_1")), "living room")
	assert_false(RoomStaging.supports(config, state.get_room("studio_1")), "studio not yet")
	assert_false(RoomStaging.supports(config, state.get_room("stairs_0")), "stairs never")


func test_present_includes_people_walking_through_and_nobody_else() -> void:
	var config := load_config()
	var state := _state(config)
	var living := state.get_room("living_1")
	_place(state, "mia", "living_1", 0.4, "socialise")
	_place(state, "roxy", "studio_1", 0.5, "idle")
	var ava := state.get_creator("ava")
	ava.room_id = "stairs_0"
	ava.travel_path = [Vector2(2.4, 0), Vector2(1.2, 0)]
	ava.position = Vector2(1.7, 0) # walking in from the stairwell
	var ids := RoomStaging.present(state, living).map(func(c: CreatorState) -> String: return c.id)
	assert_true(ids.has("mia"), "relaxing in the room")
	assert_true(ids.has("ava"), "walking through it")
	assert_false(ids.has("roxy"), "in the studio")
	ava.position = Vector2(2.4, 0)
	assert_false(RoomStaging.is_inside(ava, living), "still on the stairs")


func test_seats_follow_the_furniture_of_each_level() -> void:
	var config := load_config()
	var state := _state(config)
	var living := state.get_room("living_1")
	for level in [1, 2, 3]:
		living.level = level
		var seats := RoomStaging.seats(config, living)
		assert_gt(seats.size(), 1, "level %d has seats" % level)
		for seat: Dictionary in seats:
			assert_true(float(seat["x"]) > 0.0 and float(seat["x"]) < 1.0, "seat inside the room")
	living.level = 3
	var kinds := RoomStaging.seats(config, living).map(func(s: Dictionary) -> String: return str(s["kind"]))
	assert_true(kinds.has("beanbag"), "the Lv3 beanbag is a seat")


func test_relaxing_creators_sit_apart_and_face_their_conversation_partner() -> void:
	var config := load_config()
	var state := _state(config)
	var living := state.get_room("living_1")
	living.level = 2
	_place(state, "mia", "living_1", 0.4, "socialise")
	_place(state, "roxy", "living_1", 0.6, "socialise")
	state.get_creator("mia").reaction = {"kind": "chat", "anim": "chat", "with": "roxy", "until": state.game_minutes + 30.0}
	state.get_creator("roxy").reaction = {"kind": "chat", "anim": "chat", "with": "mia", "until": state.game_minutes + 30.0}
	var plan := RoomStaging.plan(state, config, living, {"mia": true, "roxy": true})
	assert_eq(str(plan["mia"]["anim"]), "sit_chat")
	assert_eq(str(plan["roxy"]["anim"]), "sit_chat")
	assert_gt(absi(int(plan["mia"]["seat"]) - int(plan["roxy"]["seat"])), 1, "a seat between them")
	assert_lt(float(plan["mia"]["x"]), float(plan["roxy"]["x"]), "left-to-right order kept")
	assert_eq(float(plan["mia"]["face"]), 1.0, "Mia turns to Roxy")
	assert_eq(float(plan["roxy"]["face"]), -1.0, "Roxy turns to Mia")
	assert_gt(float(plan["mia"]["seat_h"]), 0.0, "seated poses know the seat height")


func test_working_and_unseatable_creators_keep_their_real_activity() -> void:
	var config := load_config()
	var state := _state(config)
	var living := state.get_room("living_1")
	var ava := _place(state, "ava", "living_1", 0.86, "work")
	ava.content_focus = "social_media"
	_place(state, "mia", "living_1", 0.4, "socialise")
	var plan := RoomStaging.plan(state, config, living, {"ava": true, "mia": false})
	assert_eq(str(plan["ava"]["anim"]), "", "working: her simulated pose")
	assert_almost(float(plan["ava"]["x"]), 0.86, 0.001, "at her simulated spot")
	assert_eq(str(plan["mia"]["anim"]), "", "no sitting art: she stays standing")
	assert_almost(float(plan["mia"]["x"]), 0.4, 0.001)


func test_painted_creators_have_no_sitting_art_yet() -> void:
	var config := load_config()
	var spec := Appearance.render_spec(GameState.new_game(config, 1).creators[0], config)
	assert_true(IllustratedArt.sprite(spec, "sit").is_empty(), "no painted sitting pose, so she stands")
	assert_true(IllustratedArt.sprite(spec, "sit_phone").is_empty())


func test_staging_never_changes_game_state() -> void:
	var config := load_config()
	var state := _state(config)
	_place(state, "mia", "living_1", 0.4, "socialise")
	_place(state, "roxy", "living_1", 0.6, "idle")
	var before := JSON.stringify(SaveSystem.to_save_dict(state, 1.0))
	for i in 5:
		RoomStaging.plan(state, config, state.get_room("living_1"), {"mia": true, "roxy": true, "ava": false})
	assert_eq(JSON.stringify(SaveSystem.to_save_dict(state, 1.0)), before, "presentation only")


func test_sitting_poses_render() -> void:
	var config := load_config()
	var spec := Appearance.render_spec(CreatorSetup.create(config.creator_templates["mia"], config), config)
	for anim in ["sit", "sit_phone", "sit_chat"]:
		assert_gt(CreatorRenderer.record(spec, anim, 0.5).size(), 60, anim + " draws")
	var pose := FigurePoses.pose("sit", 0.0, 21.0)
	assert_gt(float(pose["bob"]), 20.0, "the body lowers onto the seat")
