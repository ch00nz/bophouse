class_name HouseView
extends Node2D
## Side-on cutaway of the house: sky, building shell, rooms and creators.
## Presentation only. Converts logical grid positions to pixels and reports clicks upward.

signal creator_clicked(creator_id: String)
signal room_clicked(room_id: String)
signal background_clicked

const CELL_W := 170.0
const STOREY_H := 200.0
const FLOOR_H := 14.0
const ROOF_H := 92.0
const SIDEBAR_W := 340.0
const GROUND_H := 64.0

var config: GameConfig
var state: GameState

var _base := Vector2.ZERO          # pixel position of column 0 at the bottom of storey 0
var _columns: int = 1
var _storeys: int = 1
var _room_views: Dictionary = {}    # room_id -> RoomView
var _creator_views: Dictionary = {} # creator_id -> CreatorView
var _rooms_layer: Node2D
var _creators_layer: Node2D
var _fx_layer: Node2D
var _status_timer: float = 0.0


func _ready() -> void:
	_rooms_layer = Node2D.new()
	_creators_layer = Node2D.new()
	_fx_layer = Node2D.new()
	add_child(_rooms_layer)
	add_child(_creators_layer)
	add_child(_fx_layer)
	get_viewport().size_changed.connect(_layout)
	Game.room_upgraded.connect(_on_room_upgraded)


func build() -> void:
	config = Game.config
	state = Game.state
	for child in _rooms_layer.get_children():
		child.queue_free()
	for child in _creators_layer.get_children():
		child.queue_free()
	_room_views.clear()
	_creator_views.clear()

	_columns = 1
	_storeys = 1
	for room in state.rooms:
		_columns = maxi(_columns, room.column + room.width)
		_storeys = maxi(_storeys, room.storey + 1)

	for room in state.rooms:
		var view := RoomView.new()
		view.name = "Room_" + room.id
		_rooms_layer.add_child(view)
		view.setup(room, config, Vector2(room.width * CELL_W, STOREY_H), FLOOR_H, _has_stairs_above(room))
		_room_views[room.id] = view
	for creator in state.creators:
		var view := CreatorView.new()
		view.name = "Creator_" + creator.id
		_creators_layer.add_child(view)
		_creator_views[creator.id] = view
	_layout()
	for creator in state.creators:
		(_creator_views[creator.id] as CreatorView).setup(creator, self)


func _layout() -> void:
	var viewport := get_viewport_rect().size
	var house_width := _columns * CELL_W
	var area_width := maxf(viewport.x - SIDEBAR_W, house_width + 40.0)
	_base = Vector2(floor((area_width - house_width) * 0.5), floor(viewport.y - GROUND_H))
	for room_id in _room_views:
		var view: RoomView = _room_views[room_id]
		view.position = room_rect(view.room).position
	queue_redraw()


## Converts a logical (column, storey) position to the pixel where feet touch the floor.
func logical_to_pixel(logical: Vector2) -> Vector2:
	return Vector2(_base.x + logical.x * CELL_W, _base.y - logical.y * STOREY_H - FLOOR_H)


func room_rect(room: RoomState) -> Rect2:
	return Rect2(_base.x + room.column * CELL_W, _base.y - (room.storey + 1) * STOREY_H, room.width * CELL_W, STOREY_H)


## Height of the bed (or other sleep surface) in a room, for placing sleeping creators.
func sleep_surface_height(room_id: String) -> float:
	var room := state.get_room(room_id)
	if room == null:
		return 0.0
	for item: Dictionary in config.room_level_def(room.type_id, room.level).get("furniture", []):
		if bool(item.get("sleep_surface", false)):
			return float(item.get("h", 0.0)) * (STOREY_H - FLOOR_H)
	return 0.0


func set_selection(kind: String, id: String) -> void:
	for room_id in _room_views:
		(_room_views[room_id] as RoomView).selected = kind == "room" and room_id == id
	for creator_id in _creator_views:
		(_creator_views[creator_id] as CreatorView).selected = kind == "creator" and creator_id == id


func spawn_floating_text(at: Vector2, text: String, text_color: Color) -> void:
	var popup := FloatingText.new()
	popup.text = text
	popup.color = text_color
	popup.position = at
	_fx_layer.add_child(popup)


func _process(delta: float) -> void:
	queue_redraw() # sky follows the clock
	_status_timer += delta
	if _status_timer >= 0.25 and state != null:
		_status_timer = 0.0
		for room_id in _room_views:
			(_room_views[room_id] as RoomView).upgrade_ready = RoomUpgrades.can_upgrade(state, config, room_id)


func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseMotion:
		var target := _pick(get_local_mouse_position())
		for room_id in _room_views:
			(_room_views[room_id] as RoomView).hovered = target.get("kind", "") == "room" and target.get("id", "") == room_id
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not target.is_empty() else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _pick(get_local_mouse_position())
		match str(target.get("kind", "")):
			"creator":
				creator_clicked.emit(str(target["id"]))
			"room":
				room_clicked.emit(str(target["id"]))
			_:
				background_clicked.emit()
		get_viewport().set_input_as_handled()


func _pick(point: Vector2) -> Dictionary:
	var creator_ids := _creator_views.keys()
	creator_ids.reverse()
	for creator_id in creator_ids:
		var view: CreatorView = _creator_views[creator_id]
		if view.hit_rect().has_point(point - view.position):
			return {"kind": "creator", "id": creator_id}
	for room_id in _room_views:
		var view: RoomView = _room_views[room_id]
		if view.is_interactive() and room_rect(view.room).has_point(point):
			return {"kind": "room", "id": room_id}
	return {}


func _has_stairs_above(room: RoomState) -> bool:
	if not bool(config.room_type(room.type_id).get("connector", false)):
		return false
	for other in state.rooms:
		if other.storey == room.storey + 1 and other.column == room.column \
				and bool(config.room_type(other.type_id).get("connector", false)):
			return true
	return false


func _on_room_upgraded(room_id: String) -> void:
	if not _room_views.has(room_id):
		return
	var view: RoomView = _room_views[room_id]
	view.queue_redraw()
	view.play_upgrade_fx()
	var rect := room_rect(view.room)
	spawn_floating_text(rect.get_center() + Vector2(0, -30), "Upgraded!", Color("ffd166"))
	for creator_id in _creator_views:
		(_creator_views[creator_id] as CreatorView).queue_redraw()


# ---------------------------------------------------------------------------
# Background, sky and building shell
# ---------------------------------------------------------------------------

func _draw() -> void:
	if state == null:
		return
	var viewport := get_viewport_rect().size
	var daylight := _daylight()
	var sky_top := Color("1b1f4a").lerp(Color("6ec6ff"), daylight)
	var sky_bottom := Color("4b3a78").lerp(Color("ffe0ef"), daylight)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(viewport.x, 0), viewport, Vector2(0, viewport.y)]),
		PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))

	_draw_sun_and_moon(viewport, daylight)
	_draw_clouds(viewport, daylight)

	var hills := Color("8fd694").lerp(Color("2f4a3a"), 1.0 - daylight)
	PlaceholderArt.draw_ellipse(self, Vector2(viewport.x * 0.15, _base.y + 20), Vector2(380, 120), hills.darkened(0.08))
	PlaceholderArt.draw_ellipse(self, Vector2(viewport.x * 0.75, _base.y + 30), Vector2(460, 140), hills)

	var grass := Color("6cc551").lerp(Color("2d5a2a"), 1.0 - daylight)
	draw_rect(Rect2(0, _base.y, viewport.x, viewport.y - _base.y), Color("8d6e4f").lerp(Color("3e2f24"), 1.0 - daylight))
	draw_rect(Rect2(0, _base.y, viewport.x, 12), grass)

	_draw_shell(daylight)


func _draw_shell(daylight: float) -> void:
	var width := _columns * CELL_W
	var top := _base.y - _storeys * STOREY_H
	var wall := Color("f4d9c6").lerp(Color("8a7a8f"), 1.0 - daylight)
	var trim := Color("b0476f")
	draw_rect(Rect2(_base.x - 12, top - 10, width + 24, _storeys * STOREY_H + 10), wall)
	draw_rect(Rect2(_base.x - 18, _base.y - 6, width + 36, 14), Color("7a6a5e"))
	# Roof
	var eave := 30.0
	var roof := PackedVector2Array([
		Vector2(_base.x - eave, top - 6), Vector2(_base.x + width + eave, top - 6),
		Vector2(_base.x + width * 0.5 + 40, top - ROOF_H), Vector2(_base.x + width * 0.5 - 40, top - ROOF_H)])
	draw_colored_polygon(roof, trim)
	draw_rect(Rect2(_base.x - eave, top - 12, width + eave * 2, 10), trim.darkened(0.25))
	draw_rect(Rect2(_base.x + width * 0.78, top - ROOF_H + 4, 26, 52), Color("8c5a4a"))
	var sign_rect := Rect2(_base.x + width * 0.5 - 110, top - ROOF_H + 26, 220, 38)
	PlaceholderArt.draw_rounded_rect(self, sign_rect, Color("2b1d3f"), 10, Color("ffd166"), 3)
	PlaceholderArt.draw_text(self, Vector2(sign_rect.position.x, sign_rect.position.y + 27), "BOP HOUSE", 22,
		Color("ff7ab8"), sign_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3, Color(1, 0.4, 0.7, 0.35))
	# Bushes
	for i in 3:
		PlaceholderArt.draw_ellipse(self, Vector2(_base.x - 40 + i * 14, _base.y - 8), Vector2(24, 18), Color("3fa34d").darkened(i * 0.06))
		PlaceholderArt.draw_ellipse(self, Vector2(_base.x + width + 30 + i * 14, _base.y - 8), Vector2(24, 18), Color("3fa34d").darkened(i * 0.06))


func _draw_sun_and_moon(viewport: Vector2, daylight: float) -> void:
	var day_fraction := fmod(state.game_minutes, GameState.MINUTES_PER_DAY) / GameState.MINUTES_PER_DAY
	var sun_angle := (day_fraction - 0.5) * TAU # noon at the top, 06:00 on the left horizon
	var arc_centre := Vector2((viewport.x - SIDEBAR_W) * 0.5, _base.y)
	var radius := Vector2(viewport.x * 0.45, _base.y - 90)
	var sun := arc_centre + Vector2(sin(sun_angle) * radius.x, -cos(sun_angle) * radius.y)
	var moon := arc_centre + Vector2(-sin(sun_angle) * radius.x, cos(sun_angle) * radius.y)
	if sun.y < _base.y:
		draw_circle(sun, 46, Color(1, 0.9, 0.5, 0.25))
		draw_circle(sun, 28, Color("ffd166"))
	if moon.y < _base.y and daylight < 0.6:
		draw_circle(moon, 20, Color(0.95, 0.95, 1.0, 1.0 - daylight))
		draw_circle(moon + Vector2(8, -5), 17, Color("1b1f4a").lerp(Color("6ec6ff"), daylight))


func _draw_clouds(viewport: Vector2, daylight: float) -> void:
	var cloud := Color(1, 1, 1, 0.85).lerp(Color(0.6, 0.6, 0.75, 0.5), 1.0 - daylight)
	var drift := fmod(state.game_minutes * 0.6, viewport.x + 300)
	for i in 4:
		var x := fmod(drift + i * (viewport.x + 300) / 4.0, viewport.x + 300) - 150
		var y := 110.0 + (i % 2) * 50.0
		PlaceholderArt.draw_ellipse(self, Vector2(x, y), Vector2(48, 16), cloud)
		PlaceholderArt.draw_ellipse(self, Vector2(x + 26, y - 10), Vector2(30, 16), cloud)
		PlaceholderArt.draw_ellipse(self, Vector2(x - 22, y - 6), Vector2(24, 12), cloud)


## 0 at midnight, 1 during the day, smooth transitions at dawn and dusk.
func _daylight() -> float:
	var hour := fmod(state.game_minutes, GameState.MINUTES_PER_DAY) / 60.0
	if hour < 5.0 or hour >= 21.0:
		return 0.0
	if hour < 7.0:
		return smoothstep(5.0, 7.0, hour)
	if hour >= 19.0:
		return 1.0 - smoothstep(19.0, 21.0, hour)
	return 1.0
