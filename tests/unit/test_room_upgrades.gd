extends TestCase


func test_cannot_upgrade_without_cash() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	state.cash = 0.0
	assert_false(RoomUpgrades.try_upgrade(state, config, "studio_1"))
	assert_eq(state.get_room("studio_1").level, 1)
	assert_almost(state.cash, 0.0)


func test_upgrade_spends_cash_and_raises_level() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var room := state.get_room("studio_1")
	var cost := RoomUpgrades.upgrade_cost(config, room)
	assert_gt(cost, 0.0)
	state.cash = cost + 10.0
	assert_true(RoomUpgrades.try_upgrade(state, config, "studio_1"))
	assert_eq(room.level, 2)
	assert_almost(state.cash, 10.0)


func test_upgrade_raises_room_quality() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var room := state.get_room("bedroom_1")
	var before := Economy.room_quality(config, room)
	state.cash = 1_000_000.0
	RoomUpgrades.try_upgrade(state, config, "bedroom_1")
	assert_gt(Economy.room_quality(config, room), before)


func test_max_level_blocks_upgrade() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	state.cash = 1_000_000.0
	var room := state.get_room("living_1")
	while RoomUpgrades.try_upgrade(state, config, "living_1"):
		pass
	assert_eq(room.level, config.max_room_level("living_room"))
	assert_almost(RoomUpgrades.upgrade_cost(config, room), -1.0)


func test_non_upgradable_rooms() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	state.cash = 1_000_000.0
	assert_false(RoomUpgrades.try_upgrade(state, config, "stairs_0"))
	assert_false(RoomUpgrades.try_upgrade(state, config, "lot_1"))
