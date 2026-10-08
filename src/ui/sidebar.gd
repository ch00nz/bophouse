class_name Sidebar
extends PanelContainer
## Right-hand context panel. Shows the overview, a creator profile or a room panel.

signal selection_changed(kind: String, id: String)

const WIDTH := 324.0

var current_kind: String = ""
var current_id: String = ""

var _scroll: ScrollContainer
var _panel: Control


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -WIDTH - 8.0
	offset_right = -8.0
	offset_top = 72.0
	offset_bottom = -8.0
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	show_overview()


func show_overview() -> void:
	_set_panel(OverviewPanel.new(), "overview", "")


func show_creator(creator_id: String) -> void:
	_set_panel(CreatorPanel.new(creator_id), "creator", creator_id)


func show_room(room_id: String) -> void:
	_set_panel(RoomPanel.new(room_id), "room", room_id)


func refresh() -> void:
	if _panel != null and _panel.has_method("refresh"):
		_panel.call("refresh")


func _set_panel(panel: Control, kind: String, id: String) -> void:
	if _panel != null:
		_scroll.remove_child(_panel)
		_panel.queue_free()
	_panel = panel
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _panel.has_signal("navigate"):
		_panel.connect("navigate", _on_navigate)
	_scroll.add_child(_panel)
	_scroll.scroll_vertical = 0
	current_kind = kind
	current_id = id
	selection_changed.emit(kind, id)


func _on_navigate(kind: String, id: String) -> void:
	match kind:
		"creator":
			show_creator(id)
		"room":
			show_room(id)
		_:
			show_overview()
