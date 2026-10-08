class_name Hud
extends CanvasLayer
## Screen-space UI: resource bar, speed controls, sidebar, hints and popups.

const REFRESH_INTERVAL := 0.2

var sidebar: Sidebar

var _root: Control
var _cash: Label
var _rate: Label
var _followers: Label
var _subscribers: Label
var _clock: Label
var _saved: Label
var _speed_buttons: Dictionary = {} # speed (0 = pause) -> Button
var _offline_popup: OfflinePopup
var _reset_dialog: ConfirmationDialog
var _refresh_timer: float = 0.0
var _saved_fade: float = 0.0


func _ready() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_top_bar()
	sidebar = Sidebar.new()
	_root.add_child(sidebar)
	_build_footer()

	_reset_dialog = ConfirmationDialog.new()
	_reset_dialog.title = "Start over?"
	_reset_dialog.dialog_text = "This deletes your save and starts a brand new house."
	_reset_dialog.confirmed.connect(Game.reset_game)
	_root.add_child(_reset_dialog)

	_offline_popup = OfflinePopup.new()
	_root.add_child(_offline_popup)

	Game.saved.connect(_on_saved)
	Game.speed_changed.connect(_on_speed_changed)
	Game.offline_progress_applied.connect(show_offline_summary)
	Game.state_replaced.connect(sidebar.show_overview)
	_on_speed_changed(Game.speed, Game.paused)
	_refresh()


func show_offline_summary(summary: Dictionary) -> void:
	_offline_popup.show_summary(summary)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh()
	if _saved_fade > 0.0:
		_saved_fade = maxf(0.0, _saved_fade - delta)
		_saved.modulate.a = minf(1.0, _saved_fade)


func _refresh() -> void:
	var state := Game.state
	_cash.text = Fmt.money(state.cash)
	_rate.text = "+%s/hr" % Fmt.money(Economy.house_cash_per_hour(state, Game.config))
	_followers.text = Fmt.compact(state.total_followers())
	_subscribers.text = Fmt.compact(state.total_subscribers())
	_clock.text = Fmt.clock(state)
	sidebar.refresh()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.anchor_right = 1.0
	bar.offset_left = 8.0
	bar.offset_right = -8.0
	bar.offset_top = 8.0
	bar.offset_bottom = 64.0
	bar.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, 14, 8, UiTheme.ACCENT.darkened(0.2), 2))
	_root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	bar.add_child(row)

	var title := UiTheme.label("BOP HOUSE", 22, UiTheme.ACCENT)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)

	_cash = UiTheme.label("", 19, UiTheme.GOLD)
	_rate = UiTheme.label("", 12, UiTheme.GOOD)
	row.add_child(_stat_block("CASH", _cash, _rate))
	_followers = UiTheme.label("", 19)
	row.add_child(_stat_block("FOLLOWERS", _followers))
	_subscribers = UiTheme.label("", 19)
	row.add_child(_stat_block("SUBSCRIBERS", _subscribers))
	_clock = UiTheme.label("", 19)
	row.add_child(_stat_block("TIME", _clock))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 4)
	speeds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(speeds)
	var options: Array = Game.config.tuning("time", "speed_options", [1, 3, 10])
	var labels: Array = [0]
	labels.append_array(options)
	for speed_value in labels:
		var value := int(speed_value)
		var button := Button.new()
		button.text = "Pause" if value == 0 else "%dx" % value
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(58 if value == 0 else 44, 34)
		button.pressed.connect(_on_speed_pressed.bind(value))
		speeds.add_child(button)
		_speed_buttons[value] = button

	var reset := Button.new()
	reset.text = "New game"
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 6))
	reset.pressed.connect(func() -> void: _reset_dialog.popup_centered())
	row.add_child(reset)


func _stat_block(caption: String, value: Label, extra: Label = null) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -4)
	box.add_child(UiTheme.label(caption, 11, UiTheme.MUTED))
	if extra == null:
		box.add_child(value)
	else:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.add_child(value)
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(extra)
		box.add_child(line)
	return box


func _build_footer() -> void:
	var hint := UiTheme.label("Click a creator or a room to inspect it.", 13, Color(1, 1, 1, 0.85))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 14.0
	hint.offset_top = -28.0
	hint.offset_bottom = -8.0
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

	_saved = UiTheme.label("Saved", 13, UiTheme.GOOD)
	_saved.anchor_top = 1.0
	_saved.anchor_bottom = 1.0
	_saved.offset_left = 300.0
	_saved.offset_top = -28.0
	_saved.offset_bottom = -8.0
	_saved.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_saved.add_theme_constant_override("outline_size", 4)
	_saved.modulate.a = 0.0
	_saved.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_saved)


func _on_speed_pressed(value: int) -> void:
	if value == 0:
		Game.set_paused(not Game.paused)
	else:
		Game.set_speed(value)


func _on_speed_changed(speed: int, paused: bool) -> void:
	for value: int in _speed_buttons:
		var button: Button = _speed_buttons[value]
		button.set_pressed_no_signal(paused if value == 0 else (not paused and value == speed))


func _on_saved() -> void:
	_saved_fade = 1.5
