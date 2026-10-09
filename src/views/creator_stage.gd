class_name CreatorStage
extends Node2D
## Base for views that show creators: the house cutaway (HouseView) and room interiors
## (RoomInteriorView). CreatorView only talks to this interface, so every view reuses the same
## creator rendering, animation, painted art and speech bubbles. Presentation only: stages read
## Game.state and never change it.

const CELL_W := 170.0
const STOREY_H := 200.0
const FLOOR_H := 14.0

var config: GameConfig
var state: GameState


## Where a creator's feet touch the floor for a logical (column, storey) position.
func logical_to_pixel(logical: Vector2) -> Vector2:
	return Vector2(logical.x * CELL_W, -logical.y * STOREY_H - FLOOR_H)


## How to show a creator right now:
##   pos       where to draw her (required)
##   visible   false hides her (e.g. she's in another room)            default true
##   anim      animation override ("" = her simulated activity)        default ""
##   lift      seat or bed height for the override animation           default 0
##   face      +1 / -1 to face a direction (0 = from her activity)     default 0
##   ease      walk smoothly to `pos` instead of snapping (interiors)  default false
func stage(creator: CreatorState) -> Dictionary:
	return {"pos": logical_to_pixel(creator.position)}


## Height of the bed (or other sleep surface) in a room, for placing sleeping creators.
func sleep_surface_height(room_id: String) -> float:
	var room := state.get_room(room_id)
	if room == null:
		return 0.0
	for item: Dictionary in config.room_level_def(room.type_id, room.level).get("furniture", []):
		if bool(item.get("sleep_surface", false)):
			return float(item.get("h", 0.0)) * (STOREY_H - FLOOR_H)
	return 0.0


func spawn_floating_text(at: Vector2, text: String, text_color: Color) -> void:
	var popup := FloatingText.new()
	popup.text = text
	popup.color = text_color
	popup.position = at
	add_child(popup)
