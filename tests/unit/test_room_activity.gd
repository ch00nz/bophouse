extends TestCase
## Multi-room automated content production: room support, production quality, room selection,
## capacity/exclusivity, stability, sleep priority and the optional photoshoot.


func _setup(seed: int = 41) -> Array:
	var config := load_config()
	var state := GameState.new_game(config, seed)
	state.active_trends = []
	var ava := state.creators[0]
	for content_id in ContentRules.assignable_ids(config):
		ava.content_experience[content_id] = 1.0
	return [config, state, ava]


## Adds a second resident with her own bedroom (built on the empty lot).
func _add_housemate(config: GameConfig, state: GameState) -> CreatorState:
	for i in state.rooms.size():
		if state.rooms[i].id == "lot_1":
			state.rooms[i] = RoomState.create("bedroom_2", "bedroom", 1, 3, 2)
	var bella := state.creators[0].clone()
	bella.id = "bella"
	bella.display_name = "Bella Rose"
	bella.home_room_id = ""
	bella.last_work_room_id = ""
	bella.room_id = "living_1"
	bella.position = state.get_room("living_1").spot_position(0.5)
	bella.activity_id = "idle"
	state.creators.append(bella)
	state.creators[0].home_room_id = ""
	RoomPlanner.assign_home_rooms(state, config)
	return bella


func _run_until_working(state: GameState, config: GameConfig, creator: CreatorState, max_minutes: float = 600.0) -> void:
	var elapsed := 0.0
	while elapsed < max_minutes and not (creator.activity_id == CreatorBrain.WORK and not creator.is_travelling()):
		Simulation.advance(state, config, 5.0)
		elapsed += 5.0


func test_new_creator_gets_a_home_bedroom() -> void:
	var s := _setup()
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	assert_eq(ava.home_room_id, "bedroom_1")


func test_ava_produces_premium_content_in_her_bedroom() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_focus = "solo_premium"
	state.get_room("bedroom_1").level = 3 # a boudoir suite beats a basic studio
	ava.energy = 90.0
	ava.mood = 90.0
	var cash_before := state.cash
	_run_until_working(state, config, ava)
	assert_eq(ava.room_id, "bedroom_1", "chose her own bedroom")
	assert_eq(ActivityResolver.resolve(ava, ava.activity_id, config, state.get_room(ava.room_id)).get("anim"), "recline")
	Simulation.advance(state, config, 60.0)
	assert_gt(state.cash, cash_before, "and earns from it automatically")
	assert_eq(str(Economy.work_breakdown(ava, state, config)["room_id"]), "bedroom_1", "income reflects the bedroom")


func test_studio_is_not_required_for_premium_content() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	for i in range(state.rooms.size() - 1, -1, -1):
		if state.rooms[i].type_id == "studio":
			state.rooms.remove_at(i)
	ava.content_focus = "solo_premium"
	ava.energy = 90.0
	_run_until_working(state, config, ava)
	assert_eq(ava.activity_id, CreatorBrain.WORK)
	assert_eq(state.get_room(ava.room_id).type_id, "bedroom")


func test_she_still_uses_the_studio_when_it_is_better() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	state.get_room("studio_1").level = 3
	ava.content_focus = "glamour"
	ava.energy = 90.0
	_run_until_working(state, config, ava)
	assert_eq(ava.room_id, "studio_1")


func test_livestreaming_unlocks_from_a_bedroom_upgrade() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	assert_eq(int(ContentRules.check(ava, "livestream", state, config)["status"]), ContentRules.Status.LOCKED)
	state.get_room("bedroom_1").level = 2
	assert_true(ContentRules.refresh_unlocks(state, config).has("livestream"))
	assert_true(RoomProduction.supports(config, state.get_room("bedroom_1"), "livestream"))
	assert_false(RoomProduction.supports(config, state.get_room("studio_1"), "livestream"), "studio still level 1")


func test_room_upgrades_raise_production_and_income() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var bedroom := state.get_room("bedroom_1")
	var levels: Array[float] = []
	var incomes: Array[float] = []
	for level in [1, 2, 3]:
		bedroom.level = level
		levels.append(RoomProduction.multiplier(config, bedroom, "solo_premium"))
		incomes.append(float(Economy.work_breakdown(ava, state, config, "solo_premium", bedroom)["cash"]))
	assert_gt(levels[1], levels[0])
	assert_gt(levels[2], levels[1])
	assert_gt(incomes[2], incomes[0])


func test_room_attributes_matter_per_content() -> void:
	# Livestreams want equipment, premium sets want privacy: the studio and bedroom trade places.
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var bedroom := state.get_room("bedroom_1")
	var studio := state.get_room("studio_1")
	bedroom.level = 2
	studio.level = 2
	var bedroom_stream := RoomProduction.score(config, bedroom, "livestream")
	var studio_stream := RoomProduction.score(config, studio, "livestream")
	var bedroom_topless := RoomProduction.score(config, bedroom, "topless_premium")
	var studio_topless := RoomProduction.score(config, studio, "topless_premium")
	assert_gt(studio_stream, bedroom_stream)
	assert_gt(bedroom_topless, studio_topless)


func test_sleep_takes_priority_over_filming() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_focus = "solo_premium"
	state.get_room("bedroom_1").level = 3
	_run_until_working(state, config, ava)
	assert_eq(ava.room_id, "bedroom_1")
	ava.energy = 5.0
	Simulation.advance(state, config, 5.0)
	assert_eq(ava.activity_id, "sleep", "exhausted: sleeps in the same room she films in")
	assert_eq(ava.room_id, "bedroom_1")
	# At night she goes to bed rather than starting a new shoot.
	ava.energy = 60.0
	state.game_minutes = floor(state.game_minutes / 1440.0) * 1440.0 + 23.5 * 60.0
	Simulation.advance(state, config, 30.0)
	assert_eq(ava.activity_id, "sleep")


func test_room_selection_responds_to_availability() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var bella := _add_housemate(config, state)
	state.get_room("studio_1").level = 3
	ava.content_focus = "solo_premium"
	assert_eq(RoomPlanner.choose_work_room(ava, state, config).id, "studio_1", "studio is best while free")
	# Bella takes the studio for an exclusive premium shoot.
	bella.content_focus = "solo_premium"
	Simulation.start_activity(state, config, bella, CreatorBrain.WORK, "studio_1")
	assert_false(RoomPlanner.can_use(state, config, ava, state.get_room("studio_1"), CreatorBrain.WORK))
	assert_eq(RoomPlanner.choose_work_room(ava, state, config).id, ava.home_room_id, "falls back to her own bedroom")


func test_bedrooms_are_private_sets() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var bella := _add_housemate(config, state)
	assert_true(ava.home_room_id != bella.home_room_id, "each has her own bedroom")
	bella.content_focus = "solo_premium"
	assert_false(RoomPlanner.can_use(state, config, bella, state.get_room(ava.home_room_id), CreatorBrain.WORK))
	assert_true(RoomPlanner.can_use(state, config, bella, state.get_room(bella.home_room_id), CreatorBrain.WORK))


func test_no_filming_where_someone_sleeps() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var bella := _add_housemate(config, state)
	# Share one bedroom for this test.
	bella.home_room_id = ava.home_room_id
	ava.energy = 20.0 # properly tired, so she stays asleep
	Simulation.start_activity(state, config, ava, "sleep", ava.home_room_id)
	Simulation.advance(state, config, 60.0)
	bella.content_focus = "social_media" # even non-exclusive content
	assert_false(RoomPlanner.can_use(state, config, bella, state.get_room(ava.home_room_id), CreatorBrain.WORK))
	assert_true(RoomPlanner.can_use(state, config, bella, state.get_room(ava.home_room_id), "sleep"), "but she can sleep there")


func test_two_creators_never_conflict_over_three_days() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	var bella := _add_housemate(config, state)
	ava.content_focus = "solo_premium"
	bella.content_focus = "glamour"
	state.get_room("studio_1").level = 2
	var rooms_used := {}
	for i in range(3 * 24 * 12):
		Simulation.advance(state, config, 5.0)
		for room in state.rooms:
			var present: Array[CreatorState] = []
			for creator in state.creators:
				if not creator.is_travelling() and creator.room_id == room.id:
					present.append(creator)
			assert_true(present.size() <= int(config.room_type(room.type_id).get("capacity", 1)), "capacity in " + room.id)
			if present.size() > 1:
				for creator in present:
					var act := ActivityResolver.resolve(creator, creator.activity_id, config, room)
					assert_false(bool(act.get("exclusive", false)), "exclusive work never shared: " + room.id)
					if ActivityResolver.is_content_driven(config.activity(creator.activity_id)):
						for other in present:
							if other != creator:
								assert_false(bool(config.activity(other.activity_id).get("quiet", false)), "no filming next to a sleeper")
		for creator in state.creators:
			if creator.activity_id == CreatorBrain.WORK and not creator.is_travelling():
				rooms_used[creator.id + ":" + creator.room_id] = true
	assert_gt(float(rooms_used.size()), 1.0, "both produced content")
	assert_gt(ava.lifetime_earnings, 0.0)
	assert_gt(bella.lifetime_earnings, 0.0)


func test_room_choice_is_stable_against_small_differences() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_focus = "solo_premium"
	var bedroom := state.get_room("bedroom_1")
	var studio := state.get_room("studio_1")
	ava.last_work_room_id = bedroom.id
	var bedroom_score := RoomPlanner.work_score(ava, state, config, bedroom)
	var studio_score := RoomPlanner.work_score(ava, state, config, studio)
	var threshold := config.tuning_f("rooms", "switch_threshold", 0.15)
	if studio_score <= bedroom_score * (1.0 + threshold):
		assert_eq(RoomPlanner.choose_work_room(ava, state, config).id, bedroom.id, "small gain: keeps her familiar room")
	studio.level = 3
	assert_gt(RoomPlanner.work_score(ava, state, config, studio), bedroom_score * (1.0 + threshold))
	assert_eq(RoomPlanner.choose_work_room(ava, state, config).id, studio.id, "big gain: switches")


func test_room_changes_happen_only_between_sessions() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.content_focus = "solo_premium"
	var switches := 0
	var sessions := 0
	var last_room := ""
	var was_working := false
	for i in range(2 * 24 * 12):
		Simulation.advance(state, config, 5.0)
		var working := ava.activity_id == CreatorBrain.WORK and not ava.is_travelling()
		if working and not was_working:
			sessions += 1
			if not last_room.is_empty() and last_room != ava.room_id:
				switches += 1
			last_room = ava.room_id
		if working and was_working:
			assert_eq(ava.room_id, last_room, "never changes room mid-session")
		was_working = working
	assert_gt(float(sessions), 2.0)
	assert_true(switches <= 1, "settles on a room (switches: %d)" % switches)


func test_recovery_and_boundaries_still_apply_in_any_room() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	state.get_room("bedroom_1").level = 3
	ContentRules.refresh_unlocks(state, config)
	assert_eq(int(ContentRules.check(ava, "topless_premium", state, config)["status"]), ContentRules.Status.DECLINED)
	ava.content_focus = "solo_premium"
	ava.recovery = {"item_id": "bbl", "remaining_minutes": 3000.0, "total_minutes": 3000.0}
	ava.energy = 90.0
	ava.mood = 90.0
	Simulation.advance(state, config, 60.0)
	assert_eq(ava.activity_id, CreatorBrain.RECOVER, "rests instead of shooting premium in bed")


func test_time_of_day_bonus() -> void:
	var config := load_config()
	var stream := config.content("livestream")
	assert_gt(Economy.time_multiplier(stream, 21), 1.0, "evening peak")
	assert_almost(Economy.time_multiplier(stream, 10), 1.0)
	assert_almost(Economy.time_multiplier(config.content("solo_premium"), 21), 1.0)


func test_photoshoot_is_an_optional_bonus_with_cooldown() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	var ava: CreatorState = s[2]
	ava.energy = 80.0
	assert_true(bool(Photoshoot.check(ava, state, config)["ok"]))
	var poor := Photoshoot.reward(ava, state, config, 0.0)
	var great := Photoshoot.reward(ava, state, config, 1.0)
	assert_gt(float(great["cash"]), float(poor["cash"]), "better shots, bigger reward")
	var cash := state.cash
	var result := Photoshoot.complete(ava, state, config, 0.8)
	assert_true(bool(result["ok"]))
	assert_almost(state.cash, cash + float(result["cash"]), 0.01)
	assert_lt(ava.energy, 80.0, "costs energy")
	assert_false(bool(Photoshoot.check(ava, state, config)["ok"]), "cooldown")
	Simulation.advance(state, config, config.tuning_f("photoshoot", "cooldown_hours", 12.0) * 60.0 + 1.0, 10.0)
	ava.energy = 80.0
	ava.activity_id = "idle"
	assert_true(bool(Photoshoot.check(ava, state, config)["ok"]), "available again")
	assert_almost(Photoshoot.shot_quality(0.5, 0.5), 1.0)
	assert_almost(Photoshoot.shot_quality(0.0, 0.5, 0.25), 0.0)


func test_idle_progress_does_not_need_photoshoots() -> void:
	var s := _setup()
	var config: GameConfig = s[0]
	var state: GameState = s[1]
	state.cash = 0.0
	Simulation.advance(state, config, 3.0 * 24.0 * 60.0, 5.0)
	assert_gt(state.cash, 150.0, "automated production earns on its own, after running costs")
