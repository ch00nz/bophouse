class_name Hud
extends CanvasLayer
## Screen-space UI: resource bar, speed controls, sidebar, hints and popups.

const REFRESH_INTERVAL := 0.2
const TOAST_SECONDS := 4.0

## Emitted when the screen area covered by the sidebar changes (collapse/expand).
signal reserved_width_changed(width: float)

var sidebar: Sidebar
var _trend_strip: Button
var _sidebar_toggle: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_time: float = 0.0

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
	add_to_group("hud")
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_top_bar()
	sidebar = Sidebar.new()
	_root.add_child(sidebar)
	sidebar.collapsed_changed.connect(_on_sidebar_collapsed)
	_build_trend_strip()
	_build_sidebar_toggle()
	_build_toast()
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
	Game.trends_changed.connect(_on_trends_changed)
	Game.content_unlocked.connect(_on_content_unlocked)
	Game.recovery_finished.connect(_on_recovery_finished)
	_on_speed_changed(Game.speed, Game.paused)
	_refresh()


func show_offline_summary(summary: Dictionary) -> void:
	_offline_popup.show_summary(summary)


## Opens the optional bonus photoshoot mini-game for a creator.
func open_photoshoot(creator_id: String) -> void:
	_root.add_child(PhotoshootPopup.new(creator_id))


func show_toast(text: String, color: Color = UiTheme.GOLD) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_time = TOAST_SECONDS


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh()
	if _saved_fade > 0.0:
		_saved_fade = maxf(0.0, _saved_fade - delta)
		_saved.modulate.a = minf(1.0, _saved_fade)
	if _toast_time > 0.0:
		_toast_time = maxf(0.0, _toast_time - delta)
		_toast.modulate.a = minf(1.0, _toast_time)
		_toast.visible = _toast_time > 0.0


func _refresh() -> void:
	var state := Game.state
	_cash.text = Fmt.money(state.cash)
	_rate.text = "+%s/hr" % Fmt.money(Economy.house_cash_per_hour(state, Game.config))
	_followers.text = Fmt.compact(state.total_followers())
	_subscribers.text = Fmt.compact(state.total_subscribers())
	_clock.text = Fmt.clock(state)
	var parts := PackedStringArray()
	for entry: Dictionary in state.active_trends:
		parts.append("%s (%s)" % [Game.config.trend(str(entry["id"])).get("name", entry["id"]), Fmt.game_duration(float(entry["remaining_minutes"]))])
	_trend_strip.text = "TRENDING:  " + "   |   ".join(parts)
	sidebar.refresh()


func _build_trend_strip() -> void:
	_trend_strip = Button.new()
	_trend_strip.offset_left = 8.0
	_trend_strip.offset_top = 72.0
	_trend_strip.offset_bottom = 100.0
	_trend_strip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_trend_strip.add_theme_font_size_override("font_size", 13)
	_trend_strip.add_theme_color_override("font_color", UiTheme.GOLD)
	_trend_strip.add_theme_color_override("font_hover_color", Color.WHITE)
	_trend_strip.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, 8, 6))
	_trend_strip.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 6))
	_trend_strip.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 6))
	_trend_strip.tooltip_text = "Social media trends. Click for details and content strategy."
	_trend_strip.pressed.connect(sidebar.show_trends)
	_root.add_child(_trend_strip)


func _build_sidebar_toggle() -> void:
	_sidebar_toggle = Button.new()
	_sidebar_toggle.anchor_left = 1.0
	_sidebar_toggle.anchor_right = 1.0
	_sidebar_toggle.offset_top = 80.0
	_sidebar_toggle.offset_bottom = 128.0
	_sidebar_toggle.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, 8, 4, UiTheme.ACCENT.darkened(0.2), 2))
	_sidebar_toggle.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 4, UiTheme.ACCENT, 2))
	_sidebar_toggle.pressed.connect(func() -> void: sidebar.set_collapsed(not sidebar.collapsed))
	_root.add_child(_sidebar_toggle)
	_place_sidebar_toggle()


func _place_sidebar_toggle() -> void:
	var right := -sidebar.reserved_width() + (Sidebar.MARGIN if not sidebar.collapsed else 0.0) - 8.0
	_sidebar_toggle.offset_right = right
	_sidebar_toggle.offset_left = right - 28.0
	_sidebar_toggle.text = ">" if not sidebar.collapsed else "<"
	_sidebar_toggle.tooltip_text = "Hide the side panel" if not sidebar.collapsed else "Show the side panel"


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = 108.0
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, 12, 12, UiTheme.GOLD, 2))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = UiTheme.label("", 16, UiTheme.GOLD)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.visible = false
	_root.add_child(_toast)


func _on_sidebar_collapsed(_collapsed: bool) -> void:
	_place_sidebar_toggle()
	reserved_width_changed.emit(sidebar.reserved_width())


func _on_trends_changed(started: Array) -> void:
	for trend_id in started:
		var trend := Game.config.trend(str(trend_id))
		show_toast("New trend: %s!  %s" % [trend.get("name", trend_id), _boost_summary(trend)])


func _on_content_unlocked(content_id: String) -> void:
	show_toast("%s unlocked! Assign it from a creator's Content tab." % Game.config.content_label(content_id), UiTheme.GOOD)


func _on_recovery_finished(creator_id: String) -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator != null:
		show_toast("%s has fully recovered and is back to work!" % ContentRules.first_name(creator), Color("2ec4b6"))


func _boost_summary(trend: Dictionary) -> String:
	var names := PackedStringArray()
	for content_id in trend.get("content", {}):
		names.append(Game.config.content(str(content_id)).get("short", content_id))
	return "Boosts " + ", ".join(names)


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
