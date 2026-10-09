class_name RoomState
extends RefCounted
## Runtime state of one room slot in the house grid.
## Position is in grid units: `column` is the left edge, `storey` 0 is the ground floor.

var id: String = ""
var type_id: String = ""
var storey: int = 0
var column: int = 0
var width: int = 1
var level: int = 1
## Production attribute bonuses from owned equipment upgrades (derived by Upgrades.refresh, not saved).
var bonus: Dictionary = {}


static func create(room_id: String, room_type: String, room_storey: int, room_column: int, room_width: int, room_level: int = 1) -> RoomState:
	var room := RoomState.new()
	room.id = room_id
	room.type_id = room_type
	room.storey = room_storey
	room.column = room_column
	room.width = room_width
	room.level = room_level
	return room


## Logical standing position for a spot expressed as a 0..1 fraction of the room width.
func spot_position(spot: float) -> Vector2:
	return Vector2(column + width * clampf(spot, 0.0, 1.0), storey)


func center_column() -> float:
	return column + width * 0.5


func to_dict() -> Dictionary:
	return {
		"id": id, "type_id": type_id, "storey": storey,
		"column": column, "width": width, "level": level,
	}


static func from_dict(data: Dictionary) -> RoomState:
	return create(
		str(data.get("id", "")), str(data.get("type_id", "")),
		int(data.get("storey", 0)), int(data.get("column", 0)),
		int(data.get("width", 1)), int(data.get("level", 1)))
