class_name Overlay
extends Control
## Full-screen modal: dims the house, centres a large panel sized to the window (fits 1280x720)
## and blocks clicks from reaching the house. Subclasses fill `body` in _build().
## Closes with the X button or Escape.

signal closed

const MAX_SIZE := Vector2(1240, 690)

var body: VBoxContainer
var header_row: HBoxContainer
var _panel: PanelContainer
var _title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A CenterContainer sizes the panel to its minimum size (set from the window in _fit), so content
	# can never stretch it off screen; long content scrolls inside instead.
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL.darkened(0.15), 16, 12, UiTheme.ACCENT, 2))
	center.add_child(_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_panel.add_child(outer)
	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	outer.add_child(header_row)
	_title = UiTheme.label("", 22, UiTheme.ACCENT)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(_title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(spacer)
	var close := Button.new()
	close.text = "Close  X"
	close.custom_minimum_size = Vector2(92, 34)
	close.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 6))
	close.pressed.connect(close_overlay)
	header_row.add_child(close)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	outer.add_child(body)
	get_viewport().size_changed.connect(_fit)
	_build()
	_fit()


## Override to build the content into `body`.
func _build() -> void:
	pass


func set_title(text: String) -> void:
	_title.text = text


func close_overlay() -> void:
	closed.emit()
	queue_free()


func _fit() -> void:
	var viewport := get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(minf(MAX_SIZE.x, viewport.x - 24.0), minf(MAX_SIZE.y, viewport.y - 24.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_overlay()


## A scroll area that fills the remaining space; returns the inner VBox.
static func scroll_column(parent: Control, separation: int = 8) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", separation)
	scroll.add_child(column)
	return column
