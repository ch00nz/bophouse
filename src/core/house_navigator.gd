class_name HouseNavigator
extends RefCounted
## Path finding on the house grid. Positions are logical: x = column, y = storey.
## Floors are connected by rooms whose type has `connector: true` (stairwells).
## Flights zig-zag: the flight leaving an even storey goes left->right, odd storeys right->left.

const FLIGHT_HALF_WIDTH := 0.3


static func find_path(rooms: Array[RoomState], config: GameConfig, from: Vector2, to: Vector2) -> Array:
	var from_storey := roundi(from.y)
	var to_storey := roundi(to.y)
	if from_storey == to_storey:
		return _dedupe([from, to])
	var stair_x := _best_connector_x(rooms, config, from_storey, to_storey, from.x, to.x)
	if is_nan(stair_x):
		push_warning("HouseNavigator: no stairwell connects storeys %d and %d" % [from_storey, to_storey])
		return _dedupe([from, to])
	var path: Array = [from]
	var step := 1 if to_storey > from_storey else -1
	var storey := from_storey
	while storey != to_storey:
		var lower := mini(storey, storey + step)
		var low_x := stair_x - FLIGHT_HALF_WIDTH if lower % 2 == 0 else stair_x + FLIGHT_HALF_WIDTH
		var high_x := stair_x + FLIGHT_HALF_WIDTH if lower % 2 == 0 else stair_x - FLIGHT_HALF_WIDTH
		if step > 0:
			path.append(Vector2(low_x, lower))
			path.append(Vector2(high_x, lower + 1))
		else:
			path.append(Vector2(high_x, lower + 1))
			path.append(Vector2(low_x, lower))
		storey += step
	path.append(to)
	return _dedupe(path)


static func path_length(path: Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	return total


## Point at `distance` along the polyline (clamped to its ends).
static func point_along(path: Array, distance: float) -> Vector2:
	if path.is_empty():
		return Vector2.ZERO
	var remaining := maxf(distance, 0.0)
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var segment := a.distance_to(b)
		if remaining <= segment:
			return a if segment <= 0.0 else a.lerp(b, remaining / segment)
		remaining -= segment
	return path[path.size() - 1]


## Centre column of the stairwell (present on every storey in range) closest to the route.
static func _best_connector_x(rooms: Array[RoomState], config: GameConfig, storey_a: int, storey_b: int, from_x: float, to_x: float) -> float:
	var low := mini(storey_a, storey_b)
	var high := maxi(storey_a, storey_b)
	var storeys_by_x := {}
	for room in rooms:
		if not bool(config.room_type(room.type_id).get("connector", false)):
			continue
		var x := room.center_column()
		if not storeys_by_x.has(x):
			storeys_by_x[x] = {}
		storeys_by_x[x][room.storey] = true
	var best := NAN
	var best_cost := INF
	for x: float in storeys_by_x:
		var covered := true
		for s in range(low, high + 1):
			if not storeys_by_x[x].has(s):
				covered = false
				break
		if not covered:
			continue
		var cost := absf(from_x - x) + absf(to_x - x)
		if cost < best_cost:
			best_cost = cost
			best = x
	return best


static func _dedupe(points: Array) -> Array:
	var result: Array = []
	for point: Vector2 in points:
		if result.is_empty() or not (result[result.size() - 1] as Vector2).is_equal_approx(point):
			result.append(point)
	return result
