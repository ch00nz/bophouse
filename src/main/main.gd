extends Node
## Composition root: creates the house view and HUD and wires their signals together.

var _house: HouseView
var _hud: Hud


func _ready() -> void:
	_house = HouseView.new()
	_house.name = "HouseView"
	add_child(_house)
	_hud = Hud.new()
	_hud.name = "Hud"
	add_child(_hud)

	_house.creator_clicked.connect(_hud.sidebar.show_creator)
	_house.room_clicked.connect(_hud.sidebar.show_room)
	_house.background_clicked.connect(_hud.sidebar.show_overview)
	_hud.sidebar.selection_changed.connect(_house.set_selection)
	_hud.reserved_width_changed.connect(_house.set_reserved_right)
	_house.reserved_right = _hud.sidebar.reserved_width()
	Game.state_replaced.connect(_house.build)
	_house.build()

	if not Game.pending_offline_summary.is_empty():
		_hud.show_offline_summary(Game.pending_offline_summary)
		Game.pending_offline_summary = {}
