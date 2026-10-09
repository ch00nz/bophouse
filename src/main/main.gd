extends Node
## Composition root: creates the house view, the Room View and the HUD and wires their signals.
## Room View is presentation only: the simulation (Game autoload) runs the same whichever is shown.

var _house: HouseView
var _interior: RoomInteriorView
var _hud: Hud


func _ready() -> void:
	_house = HouseView.new()
	_house.name = "HouseView"
	add_child(_house)
	_interior = RoomInteriorView.new()
	_interior.name = "RoomView"
	add_child(_interior)
	_hud = Hud.new()
	_hud.name = "Hud"
	add_child(_hud)

	_house.creator_clicked.connect(func(id: String) -> void: _hud.sidebar.show_creator(id))
	_house.room_clicked.connect(_on_room_clicked)
	_house.background_clicked.connect(_hud.sidebar.show_overview)
	_hud.sidebar.selection_changed.connect(_house.set_selection)
	_hud.sidebar.selection_changed.connect(_interior.set_selection)
	_hud.reserved_width_changed.connect(func(width: float) -> void:
		_house.set_reserved_right(width)
		_interior.set_reserved(_hud.reserved_left(), width))
	_house.reserved_right = _hud.sidebar.reserved_width()
	_house.reserved_left = _hud.reserved_left()
	_interior.set_reserved(_hud.reserved_left(), _hud.sidebar.reserved_width())
	_interior.creator_clicked.connect(func(id: String) -> void: _hud.open_manager(id))
	_interior.back_requested.connect(close_room)
	_hud.back_to_house_requested.connect(close_room)
	Game.state_replaced.connect(close_room)
	Game.state_replaced.connect(_house.build)
	_house.build()

	if not Game.pending_offline_summary.is_empty():
		_hud.show_offline_summary(Game.pending_offline_summary)
		Game.pending_offline_summary = {}


func _process(_delta: float) -> void:
	if _interior.is_open():
		_hud.set_room_subtitle(_interior.subtitle())


func _on_room_clicked(room_id: String) -> void:
	_hud.sidebar.show_room(room_id)
	if RoomInteriorView.supports(Game.config, Game.state.get_room(room_id)):
		open_room(room_id)


## Shows a room's detailed view in place of the house overview.
func open_room(room_id: String) -> void:
	_interior.open(room_id)
	if not _interior.is_open():
		return
	_house.visible = false
	_house.set_process_unhandled_input(false)
	_hud.show_room_bar(_interior.title(), _interior.subtitle())


func close_room() -> void:
	if not _interior.is_open():
		return
	_interior.close()
	_house.visible = true
	_house.set_process_unhandled_input(true)
	_hud.hide_room_bar()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func is_room_open() -> bool:
	return _interior.is_open()
