class_name HouseView
extends Node2D
## Side-on cutaway of the house: sky, building shell, rooms and creators.
## Presentation only. Converts logical grid positions to pixels and reports clicks upward.
## The building lives in a scaled "world" node that fits the free screen area (between the roster
## on the left, the sidebar on the right and the top bar), so taller houses still fit at 1280x720.

signal creator_clicked(creator_id: String)
signal room_clicked(room_id: String)
signal background_clicked

const CELL_W := 170.0
const STOREY_H := 200.0
const FLOOR_H := 14.0
const ROOF_H := 92.0

## Screen width covered by UI (sidebar on the right, roster on the left); the house centres in what's left.
var reserved_right: float = 340.0
var reserved_left: float = 0.0
const GROUND_H := 52.0
const TOP_RESERVED := 104.0
const SIDE_MARGIN := 40.0

var config: GameConfig
var state: GameState

var _world: Node2D                 # scaled container: shell, rooms, creators, effects
var _shell: Node2D
var _ground_y: float = 0.0         # screen y of the ground line
var _columns: int = 1
var _storeys: int = 1
var _room_views: Dictionary = {}    # room_id -> RoomView
var _creator_views: Dictionary = {} # creator_id -> CreatorView
var _rooms_layer: Node2D
var _creators_layer: Node2D
var _fx_layer: Node2D
var _status_timer: float = 0.0


func _ready() -> void:
	_world = Node2D.new()
	_shell = Node2D.new()
	_shell.draw.connect(_draw_shell)
	_rooms_layer = Node2D.new()
	_creators_layer = Node2D.new()
	_fx_layer = Node2D.new()
	add_child(_world)
	_world.add_child(_shell)
	_world.add_child(_rooms_layer)
	_world.add_child(_creators_layer)
	_world.add_child(_fx_layer)
	get_viewport().size_changed.connect(_layout)
	Game.room_upgraded.connect(_on_room_upgraded)
	Game.room_built.connect(func(_room_id: String) -> void: build())
	Game.upgrade_purchased.connect(func(upgrade_id: String) -> void:
		if upgrade_id == Upgrades.EXPANSION:
			build()) # the house grows a storey
	Game.creator_joined.connect(_on_creator_joined)
	Game.bedroom_changed.connect(func(_id: String) -> void: _refresh_rooms())


func build() -> void:
	config = Game.config
	state = Game.state
	for child in _rooms_layer.get_children():
		child.queue_free()
	for child in _creators_layer.get_children():
		child.queue_free()
	for child in _fx_layer.get_children():
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
	var house_width := _columns * CELL_W + SIDE_MARGIN * 2.0
	var house_height := _storeys * STOREY_H + ROOF_H + 8.0
	var area := Vector2(maxf(viewport.x - reserved_right - reserved_left, 200.0), maxf(viewport.y - GROUND_H - TOP_RESERVED, 200.0))
	var fit := minf(1.0, minf(area.x / house_width, area.y / house_height))
	_ground_y = floor(viewport.y - GROUND_H)
	_world.scale = Vector2(fit, fit)
	_world.position = Vector2(floor(reserved_left + (area.x - _columns * CELL_W * fit) * 0.5), _ground_y)
	for room_id in _room_views:
		var view: RoomView = _room_views[room_id]
		view.position = room_rect(view.room).position
	queue_redraw()
	_shell.queue_redraw()


func set_reserved_right(width: float) -> void:
	reserved_right = width
	_layout()


func set_reserved_left(width: float) -> void:
	reserved_left = width
	_layout()


## Converts a logical (column, storey) position to the world point where feet touch the floor.
## World space has column 0 / ground level at the origin and is scaled to fit the screen.
func logical_to_pixel(logical: Vector2) -> Vector2:
	return Vector2(logical.x * CELL_W, -logical.y * STOREY_H - FLOOR_H)


func room_rect(room: RoomState) -> Rect2:
	return Rect2(room.column * CELL_W, -(room.storey + 1) * STOREY_H, room.width * CELL_W, STOREY_H)


## Screen position of a world point (for UI that follows the house).
func world_to_screen(point: Vector2) -> Vector2:
	return _world.transform * point


func _refresh_rooms() -> void:
	for room_id in _room_views:
		(_room_views[room_id] as RoomView).queue_redraw()


func _on_creator_joined(creator_id: String) -> void:
	var creator := state.get_creator(creator_id)
	if creator == null or _creator_views.has(creator_id):
		return
	var view := CreatorView.new()
	view.name = "Creator_" + creator.id
	_creators_layer.add_child(view)
	_creator_views[creator.id] = view
	view.setup(creator, self)
	spawn_floating_text(logical_to_pixel(creator.position) + Vector2(0, -150), "Welcome, %s!" % creator.first_name(), Color("ffd166"))
	_refresh_rooms()


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
			var view: RoomView = _room_views[room_id]
			view.upgrade_ready = RoomUpgrades.can_upgrade(state, config, room_id)
			var residents := Housing.residents_of(state, room_id)
			view.owner_name = residents[0].first_name() if not residents.is_empty() else ""
			if not Housing.build_options(config, view.room).is_empty():
				view.build_hint = "Build a bedroom: %s" % Fmt.money(Housing.build_cost(state, config, "bedroom"))


func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventMouseMotion:
		var target := _pick(_world.get_local_mouse_position())
		for room_id in _room_views:
			(_room_views[room_id] as RoomView).hovered = target.get("kind", "") == "room" and target.get("id", "") == room_id
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not target.is_empty() else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _pick(_world.get_local_mouse_position())
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
	PlaceholderArt.draw_ellipse(self, Vector2(viewport.x * 0.15, _ground_y + 20), Vector2(380, 120), hills.darkened(0.08))
	PlaceholderArt.draw_ellipse(self, Vector2(viewport.x * 0.75, _ground_y + 30), Vector2(460, 140), hills)

	var grass := Color("6cc551").lerp(Color("2d5a2a"), 1.0 - daylight)
	draw_rect(Rect2(0, _ground_y, viewport.x, viewport.y - _ground_y), Color("8d6e4f").lerp(Color("3e2f24"), 1.0 - daylight))
	draw_rect(Rect2(0, _ground_y, viewport.x, 12), grass)
	_shell.queue_redraw()


## Building shell, roof and bushes, drawn in world space on the _shell node.
func _draw_shell() -> void:
	if state == null:
		return
	var ci := _shell
	var daylight := _daylight()
	var width := _columns * CELL_W
	var top := -_storeys * STOREY_H
	var wall := Color("f4d9c6").lerp(Color("8a7a8f"), 1.0 - daylight)
	var trim := Color("b0476f")
	ci.draw_rect(Rect2(-12, top - 10, width + 24, _storeys * STOREY_H + 10), wall)
	ci.draw_rect(Rect2(-18, -6, width + 36, 14), Color("7a6a5e"))
	# Roof
	var eave := 30.0
	var roof := PackedVector2Array([
		Vector2(-eave, top - 6), Vector2(width + eave, top - 6),
		Vector2(width * 0.5 + 40, top - ROOF_H), Vector2(width * 0.5 - 40, top - ROOF_H)])
	ci.draw_colored_polygon(roof, trim)
	ci.draw_rect(Rect2(-eave, top - 12, width + eave * 2, 10), trim.darkened(0.25))
	ci.draw_rect(Rect2(width * 0.78, top - ROOF_H + 4, 26, 52), Color("8c5a4a"))
	var sign_rect := Rect2(width * 0.5 - 110, top - ROOF_H + 26, 220, 38)
	PlaceholderArt.draw_rounded_rect(ci, sign_rect, Color("2b1d3f"), 10, Color("ffd166"), 3)
	PlaceholderArt.draw_text(ci, Vector2(sign_rect.position.x, sign_rect.position.y + 27), "BOP HOUSE", 22,
		Color("ff7ab8"), sign_rect.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3, Color(1, 0.4, 0.7, 0.35))
	# Bushes
	for i in 3:
		PlaceholderArt.draw_ellipse(ci, Vector2(-40 + i * 14, -8), Vector2(24, 18), Color("3fa34d").darkened(i * 0.06))
		PlaceholderArt.draw_ellipse(ci, Vector2(width + 30 + i * 14, -8), Vector2(24, 18), Color("3fa34d").darkened(i * 0.06))


func _draw_sun_and_moon(viewport: Vector2, daylight: float) -> void:
	var day_fraction := fmod(state.game_minutes, GameState.MINUTES_PER_DAY) / GameState.MINUTES_PER_DAY
	var sun_angle := (day_fraction - 0.5) * TAU # noon at the top, 06:00 on the left horizon
	var arc_centre := Vector2((viewport.x - reserved_right) * 0.5, _ground_y)
	var radius := Vector2(viewport.x * 0.45, _ground_y - 90)
	var sun := arc_centre + Vector2(sin(sun_angle) * radius.x, -cos(sun_angle) * radius.y)
	var moon := arc_centre + Vector2(-sin(sun_angle) * radius.x, cos(sun_angle) * radius.y)
	if sun.y < _ground_y:
		draw_circle(sun, 46, Color(1, 0.9, 0.5, 0.25))
		draw_circle(sun, 28, Color("ffd166"))
	if moon.y < _ground_y and daylight < 0.6:
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
