class_name RoomInteriorView
extends CreatorStage
## Detailed Room View: one room of the house shown large and in detail, with the creators who are
## physically in it living their actual simulated lives (activities, walking in and out, reactions).
## Presentation only. It reads Game.state every frame and never runs its own simulation; the game
## keeps running while it's open. Room types opt in through data/room_interiors.json (see
## RoomStaging.supports), so bedrooms, studios and outdoor areas only need data plus any new
## furniture drawings in InteriorPainter.
##
## Layers inside the scaled world (room-local coordinates, same scale as the house cutaway):
##   cutaway frame > room (walls, floor, doorways) > furniture > creators (CreatorView, shared with
##   the house) > ceiling light and lighting > floating text.

signal creator_clicked(creator_id: String)
signal back_requested

const TOP_RESERVED := 150.0
const BOTTOM_MARGIN := 26.0
const SIDE_MARGIN := 30.0
const MAX_SCALE := 3.2

var room: RoomState
var reserved_left: float = 0.0
var reserved_right: float = 0.0

var _world: Node2D
var _room_layer: Node2D
var _furniture_layer: Node2D
var _creators_layer: Node2D
var _light_layer: Node2D
var _fx_layer: Node2D
var _frame_layer: Node2D
var _views: Dictionary = {} # creator_id -> CreatorView
var _plan: Dictionary = {}
var _plan_frame: int = -1
var _t: float = 0.0
var _redraw_timer: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	set_process_unhandled_input(false)
	_world = Node2D.new()
	add_child(_world)
	_frame_layer = _layer(_draw_frame)
	_room_layer = _layer(_draw_room)
	_furniture_layer = _layer(_draw_furniture)
	_creators_layer = Node2D.new()
	_world.add_child(_creators_layer)
	_light_layer = _layer(_draw_lighting)
	_fx_layer = Node2D.new()
	_world.add_child(_fx_layer)
	get_viewport().size_changed.connect(_layout)
	Game.room_upgraded.connect(func(room_id: String) -> void:
		if room != null and room_id == room.id:
			_redraw_room())
	Game.creator_joined.connect(func(_id: String) -> void:
		if room != null:
			_sync_views())


func _layer(drawer: Callable) -> Node2D:
	var node := Node2D.new()
	node.draw.connect(drawer)
	_world.add_child(node)
	return node


## Whether a room has a detailed view.
static func supports(game_config: GameConfig, target: RoomState) -> bool:
	return RoomStaging.supports(game_config, target)


func is_open() -> bool:
	return room != null


func open(room_id: String) -> void:
	config = Game.config
	state = Game.state
	room = state.get_room(room_id)
	if room == null:
		return
	_plan_frame = -1
	_sync_views()
	visible = true
	set_process(true)
	set_process_unhandled_input(true)
	_layout()
	_redraw_room()


func close() -> void:
	room = null
	visible = false
	set_process(false)
	set_process_unhandled_input(false)
	for view: CreatorView in _views.values():
		view.queue_free()
	_views.clear()
	for child in _fx_layer.get_children():
		child.queue_free()


func set_selection(kind: String, id: String) -> void:
	for creator_id: String in _views:
		(_views[creator_id] as CreatorView).selected = kind == "creator" and creator_id == id


func set_reserved(left: float, right: float) -> void:
	reserved_left = left
	reserved_right = right
	_layout()


## Room title and status for the HUD bar.
func title() -> String:
	if room == null:
		return ""
	return str(config.room_type(room.type_id).get("name", room.type_id))


func subtitle() -> String:
	if room == null:
		return ""
	var level_title := str(config.room_level_def(room.type_id, room.level).get("title", ""))
	var count := RoomStaging.present(state, room).size()
	return "Lv %d  %s  |  %s here" % [room.level, level_title, "nobody" if count == 0 else str(count)]


# ---------------------------------------------------------------------------
# CreatorStage
# ---------------------------------------------------------------------------

func room_size() -> Vector2:
	return Vector2(room.width * CELL_W, STOREY_H) if room != null else Vector2(CELL_W, STOREY_H)


func logical_to_pixel(logical: Vector2) -> Vector2:
	if room == null:
		return Vector2.ZERO
	return Vector2((logical.x - room.column) * CELL_W, InteriorPainter.interior_h(room_size()) - (logical.y - room.storey) * STOREY_H)


func stage(creator: CreatorState) -> Dictionary:
	if room == null or not RoomStaging.is_inside(creator, room):
		return {"pos": Vector2.ZERO, "visible": false}
	if _plan_frame != Engine.get_process_frames():
		_plan_frame = Engine.get_process_frames()
		var can_sit := {}
		for creator_id: String in _views:
			can_sit[creator_id] = (_views[creator_id] as CreatorView).can_sit()
		_plan = RoomStaging.plan(state, config, room, can_sit)
	var entry: Dictionary = _plan.get(creator.id, {})
	var ih := InteriorPainter.interior_h(room_size())
	return {
		"pos": Vector2(float(entry.get("x", 0.5)) * room_size().x, ih),
		"anim": str(entry.get("anim", "")),
		"lift": float(entry.get("seat_h", 0.0)) * ih,
		"face": float(entry.get("face", 0.0)),
		"ease": true,
	}


func spawn_floating_text(at: Vector2, text: String, text_color: Color) -> void:
	var popup := FloatingText.new()
	popup.text = text
	popup.color = text_color
	popup.position = at
	_fx_layer.add_child(popup)


# ---------------------------------------------------------------------------
# Frame
# ---------------------------------------------------------------------------

func _sync_views() -> void:
	for creator in state.creators:
		if _views.has(creator.id):
			continue
		var view := CreatorView.new()
		view.name = "Creator_" + creator.id
		_creators_layer.add_child(view)
		_views[creator.id] = view
		view.setup(creator, self)


func _layout() -> void:
	if room == null:
		return
	var viewport := get_viewport_rect().size
	var area := Rect2(reserved_left + SIDE_MARGIN, TOP_RESERVED, viewport.x - reserved_left - reserved_right - SIDE_MARGIN * 2.0,
		viewport.y - TOP_RESERVED - BOTTOM_MARGIN)
	var size := room_size() + Vector2(24, 30) # room plus the cut-away wall section around it
	var fit := minf(MAX_SCALE, minf(area.size.x / size.x, area.size.y / size.y))
	_world.scale = Vector2(fit, fit)
	_world.position = area.position + (area.size - room_size() * fit) * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_redraw_timer += delta
	queue_redraw()
	# The room animates gently (TV, neon, clouds, day and night) at a modest rate.
	if _redraw_timer >= 0.1:
		_redraw_timer = 0.0
		_redraw_room()


func _redraw_room() -> void:
	_room_layer.queue_redraw()
	_furniture_layer.queue_redraw()
	_light_layer.queue_redraw()
	_frame_layer.queue_redraw()


func _daylight() -> float:
	var hour := fmod(state.game_minutes, GameState.MINUTES_PER_DAY) / 60.0
	if hour < 5.0 or hour >= 21.0:
		return 0.0
	if hour < 7.0:
		return smoothstep(5.0, 7.0, hour)
	if hour >= 19.0:
		return 1.0 - smoothstep(19.0, 21.0, hour)
	return 1.0


## Sides (-1 left, +1 right) where a stairwell on the same storey opens into the room.
func _doors() -> Array:
	var result: Array = []
	for other in state.rooms:
		if other.storey != room.storey or not bool(config.room_type(other.type_id).get("connector", false)):
			continue
		if other.column == room.column + room.width:
			result.append(1)
		elif other.column + other.width == room.column:
			result.append(-1)
	return result


func _draw() -> void:
	if room == null:
		return
	# A soft stage behind the dollhouse room, darker at night.
	var viewport := get_viewport_rect().size
	var night := 1.0 - _daylight()
	var top := Color("3d1350").lerp(Color("140c26"), night * 0.6)
	var bottom := Color("7a2a5e").lerp(Color("24133a"), night * 0.6)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(viewport.x, 0), viewport, Vector2(0, viewport.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	var shadow_rect := Rect2(_world.position + Vector2(10, room_size().y * _world.scale.y), Vector2(room_size().x * _world.scale.x, 18))
	PlaceholderArt.draw_ellipse(self, shadow_rect.get_center(), shadow_rect.size * Vector2(0.55, 0.6), Color(0, 0, 0, 0.3))


func _draw_room() -> void:
	if room == null:
		return
	InteriorPainter.draw_room(_room_layer, config.room_level_def(room.type_id, room.level), room_size(), _daylight(), _t, _doors())


func _draw_furniture() -> void:
	if room == null:
		return
	var items: Array = config.room_level_def(room.type_id, room.level).get("furniture", [])
	InteriorPainter.draw_furniture(_furniture_layer, items, room_size(), _daylight(), _t, not RoomStaging.present(state, room).is_empty())


func _draw_lighting() -> void:
	if room == null:
		return
	var size := room_size()
	var spots: Array = [[Vector2(_pendant_x(), 60.0), 90.0, Color(1, 0.85, 0.55)]]
	for item: Dictionary in config.room_level_def(room.type_id, room.level).get("furniture", []):
		if str(item.get("kind", "")) in ["tv", "neon_sign", "lamp"]:
			var x := (float(item.get("x", 0.0)) + float(item.get("w", 0.1)) * 0.5) * size.x
			spots.append([Vector2(x, InteriorPainter.interior_h(size) * 0.6), 60.0, PlaceholderArt.color(item.get("color", null), Color(0.7, 0.8, 1.0)).lightened(0.4)])
	InteriorPainter.draw_ceiling_light(_light_layer, Vector2(_pendant_x(), 10), _daylight())
	InteriorPainter.draw_lighting(_light_layer, size, _daylight(), spots)


## Where the ceiling lamp hangs: the most central spot clear of wall decor (windows, posters, signs).
func _pendant_x() -> float:
	var size := room_size()
	for fraction: float in [0.48, 0.66, 0.32, 0.82, 0.18]:
		var clear := true
		for item: Dictionary in config.room_level_def(room.type_id, room.level).get("furniture", []):
			var x0 := float(item.get("x", 0.0))
			if bool(item.get("wall", false)) and fraction > x0 - 0.04 and fraction < x0 + float(item.get("w", 0.1)) + 0.04:
				clear = false
				break
		if clear:
			return fraction * size.x
	return size.x * 0.48


func _draw_frame() -> void:
	if room == null:
		return
	InteriorPainter.draw_frame(_frame_layer, room_size(), Color("f4d9c6").lerp(Color("8a7a8f"), 1.0 - _daylight()))


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if room == null:
		return
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event is InputEventMouseMotion:
		var hovered := _pick((event as InputEventMouse).position)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not hovered.is_empty() else Input.CURSOR_ARROW)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var creator_id := _pick((event as InputEventMouse).position)
		if not creator_id.is_empty():
			creator_clicked.emit(creator_id)
			get_viewport().set_input_as_handled()


func _pick(screen_point: Vector2) -> String:
	var point := _world.get_global_transform_with_canvas().affine_inverse() * screen_point
	var ids := _views.keys()
	ids.reverse()
	for creator_id: String in ids:
		var view: CreatorView = _views[creator_id]
		if view.visible and view.hit_rect().has_point(point - view.position):
			return creator_id
	return ""
