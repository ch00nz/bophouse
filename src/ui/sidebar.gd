class_name Sidebar
extends PanelContainer
## Right-hand context panel: overview, creator profile, room or trends. Collapsible.

signal selection_changed(kind: String, id: String)
signal collapsed_changed(collapsed: bool)

const WIDTH := 324.0
const MARGIN := 8.0

var current_kind: String = ""
var current_id: String = ""
var collapsed: bool = false

var _scroll: ScrollContainer
var _panel: Control


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -WIDTH - MARGIN
	offset_right = -MARGIN
	offset_top = 72.0
	offset_bottom = -MARGIN
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	show_overview()


## Screen width the sidebar currently covers (0 when collapsed).
func reserved_width() -> float:
	return 0.0 if collapsed else WIDTH + MARGIN * 2.0


func set_collapsed(value: bool) -> void:
	if collapsed == value:
		return
	collapsed = value
	visible = not value
	collapsed_changed.emit(collapsed)


func show_overview() -> void:
	_set_panel(OverviewPanel.new(), "overview", "", false)


func show_creator(creator_id: String, tab: String = "") -> void:
	_set_panel(CreatorPanel.new(creator_id, tab), "creator", creator_id)


func show_room(room_id: String) -> void:
	_set_panel(RoomPanel.new(room_id), "room", room_id)


func show_trends() -> void:
	_set_panel(TrendsPanel.new(), "trends", "")


func refresh() -> void:
	if collapsed:
		return
	if _panel != null and _panel.has_method("refresh"):
		_panel.call("refresh")


## `expand` reopens a collapsed sidebar when the player explicitly selects something.
func _set_panel(panel: Control, kind: String, id: String, expand: bool = true) -> void:
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
	if expand:
		set_collapsed(false)
	selection_changed.emit(kind, id)


func _on_navigate(kind: String, id: String) -> void:
	match kind:
		"creator":
			show_creator(id)
		"creator_content":
			show_creator(id, "Content")
		"room":
			show_room(id)
		"trends":
			show_trends()
		_:
			show_overview()
