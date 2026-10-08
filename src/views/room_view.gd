class_name RoomView
extends Node2D
## Draws one room of the cutaway house. Local origin is the room's top-left corner.
## Uses the level's `background_texture` when present, otherwise placeholder drawing from data.

const FRAME := 3.0

var room: RoomState
var config: GameConfig
var size: Vector2 = Vector2.ZERO
var floor_height: float = 14.0
var has_stairs_up: bool = false

var selected: bool = false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()
var hovered: bool = false:
	set(value):
		if hovered != value:
			hovered = value
			queue_redraw()
var upgrade_ready: bool = false:
	set(value):
		if upgrade_ready != value:
			upgrade_ready = value
			queue_redraw()

var _flash: float = 0.0


func setup(room_data: RoomState, game_config: GameConfig, room_size: Vector2, floor_h: float, stairs_up: bool) -> void:
	room = room_data
	config = game_config
	size = room_size
	floor_height = floor_h
	has_stairs_up = stairs_up
	queue_redraw()


func is_interactive() -> bool:
	return str(config.room_type(room.type_id).get("style", "room")) != "stairs"


func play_upgrade_fx() -> void:
	_flash = 1.0
	set_process(true)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 1.2)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)


func interior_height() -> float:
	return size.y - floor_height


func _draw() -> void:
	var type_def := config.room_type(room.type_id)
	var level_def := config.room_level_def(room.type_id, room.level)
	var wall := PlaceholderArt.color(level_def.get("wall", null), Color("cccccc"))
	var floor_color := PlaceholderArt.color(level_def.get("floor", null), Color("8b6b55"))
	var interior := Rect2(Vector2.ZERO, Vector2(size.x, interior_height()))

	var background := ArtLibrary.texture(str(level_def.get("background_texture", "")))
	if background != null:
		draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(interior, wall)
		PlaceholderArt.draw_wall_pattern(self, interior, str(level_def.get("pattern", "none")), wall)
		draw_rect(Rect2(0, 0, size.x, 8), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(0, interior.size.y - 6, size.x, 6), wall.darkened(0.25))
		PlaceholderArt.draw_floor(self, Rect2(0, interior.size.y, size.x, floor_height), floor_color)
		match str(type_def.get("style", "room")):
			"stairs":
				_draw_stairs(wall)
			"lot":
				_draw_lot()
			_:
				_draw_furniture(level_def.get("furniture", []))

	if hovered and is_interactive():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.07))
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0.85, _flash * 0.6))
		for i in 6:
			var sparkle := Vector2(size.x * (0.1 + 0.16 * i), size.y * (0.7 - _flash * 0.5) - (i % 2) * 20.0)
			PlaceholderArt.draw_star(self, sparkle, 7.0 * _flash + 3.0, Color(1, 0.85, 0.2, _flash))

	draw_rect(Rect2(Vector2.ZERO, size).grow(-FRAME * 0.5), Color("3b2433"), false, FRAME)
	if selected:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-3.0), Color("ffd166"), false, 4.0)
	if is_interactive() and bool(type_def.get("upgradable", false)):
		_draw_plaque(type_def)


func _draw_furniture(items: Array) -> void:
	var interior_h := interior_height()
	for item: Dictionary in items:
		var w := float(item.get("w", 0.1)) * size.x
		var h := float(item.get("h", 0.1)) * interior_h
		var x := float(item.get("x", 0.0)) * size.x
		var y := float(item.get("y", 0.0)) * interior_h if bool(item.get("wall", false)) else interior_h - h
		PlaceholderArt.draw_furniture(self, item, Rect2(x, y, w, h))


func _draw_stairs(wall: Color) -> void:
	if not has_stairs_up:
		return
	var half := HouseNavigator.FLIGHT_HALF_WIDTH * (size.x / float(room.width))
	var centre := size.x * 0.5
	var going_right := room.storey % 2 == 0
	var bottom_x := centre - half if going_right else centre + half
	var top_x := centre + half if going_right else centre - half
	var floor_y := interior_height()
	var steps := 9
	var step_w := (top_x - bottom_x) / steps
	var step_h := (floor_y + floor_height) / steps
	var stair_color := wall.darkened(0.35)
	for i in steps:
		var x := bottom_x + step_w * i
		var y := floor_y - step_h * (i + 1)
		var rect := Rect2(minf(x, x + step_w), y, absf(step_w), floor_y - y)
		draw_rect(rect, stair_color.lightened(0.05 * (i % 2)))
	draw_line(Vector2(bottom_x, floor_y - 30), Vector2(top_x, -floor_height - 30), Color("5d4037"), 3.0)


func _draw_lot() -> void:
	var interior_h := interior_height()
	var hatch := Color(0.45, 0.35, 0.25, 0.18)
	var x := -interior_h
	while x < size.x:
		# Diagonal hatch from (x, bottom) to (x + h, top), clipped to the room width.
		var t0 := clampf(-x / interior_h, 0.0, 1.0)
		var t1 := clampf((size.x - x) / interior_h, 0.0, 1.0)
		if t1 > t0:
			draw_line(Vector2(x + t0 * interior_h, interior_h * (1.0 - t0)),
				Vector2(x + t1 * interior_h, interior_h * (1.0 - t1)), hatch, 2.0)
		x += 22.0
	var box := Rect2(10, 10, size.x - 20, interior_h - 20)
	var dash := 12.0
	var cursor := 0.0
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[i + 1]
		var length := a.distance_to(b)
		cursor = 0.0
		while cursor < length:
			draw_line(a.lerp(b, cursor / length), a.lerp(b, minf(cursor + dash * 0.6, length) / length), Color("8a6d4b"), 2.0)
			cursor += dash
	var cone := Vector2(size.x * 0.5, interior_h * 0.62)
	draw_colored_polygon(PackedVector2Array([cone + Vector2(-12, 16), cone + Vector2(12, 16), cone + Vector2(0, -18)]), Color("ff8c42"))
	draw_rect(Rect2(cone + Vector2(-16, 14), Vector2(32, 5)), Color("ff8c42"))
	draw_line(cone + Vector2(-7, 2), cone + Vector2(7, 2), Color.WHITE, 3.0)
	PlaceholderArt.draw_text(self, Vector2(0, interior_h * 0.32), "ROOM TO GROW", 16, Color("8a6d4b"), size.x, HORIZONTAL_ALIGNMENT_CENTER)
	PlaceholderArt.draw_text(self, Vector2(0, interior_h * 0.32 + 18), "New rooms coming soon", 12, Color("8a6d4b"), size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_plaque(type_def: Dictionary) -> void:
	var title := str(type_def.get("name", room.type_id))
	var plaque := Rect2(8, 8, 150, 22)
	PlaceholderArt.draw_rounded_rect(self, plaque, Color(0.12, 0.07, 0.15, 0.78), 8)
	PlaceholderArt.draw_text(self, Vector2(16, 24), title, 13, Color.WHITE)
	var max_level := config.max_room_level(room.type_id)
	for i in max_level:
		var star_color := Color("ffd166") if i < room.level else Color(1, 1, 1, 0.25)
		PlaceholderArt.draw_star(self, Vector2(plaque.end.x - 12 - (max_level - 1 - i) * 14, plaque.position.y + 11), 5.5, star_color)
	if upgrade_ready:
		var badge := Vector2(size.x - 20, 20)
		draw_circle(badge, 11.0, Color("2ecc71"))
		draw_colored_polygon(PackedVector2Array([badge + Vector2(0, -7), badge + Vector2(6, 0), badge + Vector2(2, 0),
			badge + Vector2(2, 6), badge + Vector2(-2, 6), badge + Vector2(-2, 0), badge + Vector2(-6, 0)]), Color.WHITE)
