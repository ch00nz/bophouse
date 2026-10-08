extends TestCase


func test_same_storey_path_is_direct() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var path := HouseNavigator.find_path(state.rooms, config, Vector2(0.5, 0), Vector2(4.0, 0))
	assert_eq(path.size(), 2)
	assert_almost(HouseNavigator.path_length(path), 3.5)


func test_cross_storey_path_uses_stairwell() -> void:
	var config := load_config()
	var state := GameState.new_game(config)
	var path := HouseNavigator.find_path(state.rooms, config, Vector2(1.0, 1), Vector2(4.0, 0))
	assert_eq(path.size(), 4)
	var top: Vector2 = path[1]
	var bottom: Vector2 = path[2]
	assert_eq(int(top.y), 1)
	assert_eq(int(bottom.y), 0)
	# Stairwell is column 2, width 1 => centre 2.5.
	assert_true(absf(top.x - 2.5) <= HouseNavigator.FLIGHT_HALF_WIDTH + 0.001)
	assert_true(absf(bottom.x - 2.5) <= HouseNavigator.FLIGHT_HALF_WIDTH + 0.001)


func test_point_along_interpolates() -> void:
	var path: Array = [Vector2(0, 0), Vector2(2, 0), Vector2(2, 1)]
	assert_eq(HouseNavigator.point_along(path, 1.0), Vector2(1, 0))
	assert_eq(HouseNavigator.point_along(path, 2.5), Vector2(2, 0.5))
	assert_eq(HouseNavigator.point_along(path, 99.0), Vector2(2, 1))


func test_spot_position_inside_room() -> void:
	var room := RoomState.create("r", "bedroom", 1, 3, 2)
	assert_eq(room.spot_position(0.5), Vector2(4, 1))
