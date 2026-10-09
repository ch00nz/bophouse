class_name RosterPanel
extends PanelContainer
## Left-hand roster: one compact card per resident (portrait, name, activity, energy/mood,
## followers, house income per hour, recovery) plus house capacity and the Applications button.
## Clicking a card selects the creator; "Manage" opens her management screen.

signal creator_selected(creator_id: String)
signal manage_requested(creator_id: String)
signal applications_requested
signal upgrades_requested
signal finances_requested

const WIDTH := 218.0
const CARD_H := 92.0

var selected_id: String = ""

var _list: VBoxContainer
var _capacity: Label
var _recruit: Button
var _cards: Dictionary = {} # creator_id -> {card, activity, energy, mood, stats, status, portrait}
var _signature: String = ""


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_bottom = 1.0
	offset_left = 8.0
	offset_right = 8.0 + WIDTH
	offset_top = 108.0
	offset_bottom = -8.0
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, 12, 8, UiTheme.ACCENT.darkened(0.2), 2))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var header := HBoxContainer.new()
	var title := UiTheme.label("ROSTER", 14, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_capacity = UiTheme.label("", 12, UiTheme.MUTED)
	header.add_child(UiTheme.tip(_capacity, "Residents / bedrooms. Each creator needs her own bedroom."))
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_recruit = Button.new()
	_recruit.text = "Applications"
	_recruit.custom_minimum_size = Vector2(0, 38)
	_recruit.tooltip_text = "Creators who'd like to live and work in the house."
	_recruit.pressed.connect(func() -> void: applications_requested.emit())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for entry: Array in [["Upgrades", "Equipment, renovations and the bigger house.", upgrades_requested], ["Finances", "Income, creators' shares and running costs.", finances_requested]]:
		var button := Button.new()
		button.text = str(entry[0])
		button.tooltip_text = str(entry[1])
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var requested: Signal = entry[2]
		button.pressed.connect(func() -> void: requested.emit())
		row.add_child(button)
	column.add_child(row)
	column.add_child(_recruit)
	_rebuild()


func select(creator_id: String) -> void:
	selected_id = creator_id
	for id: String in _cards:
		_style_card(id)


func refresh() -> void:
	var state := Game.state
	var signature := ""
	for creator in state.creators:
		signature += creator.id + JSON.stringify(creator.look) + creator.measurements.summary() + "|"
	if signature != _signature:
		_rebuild()
	_capacity.text = "%d / %d beds" % [state.creators.size(), Housing.total_beds(state, Game.config)]
	for creator in state.creators:
		var refs: Dictionary = _cards.get(creator.id, {})
		if refs.is_empty():
			continue
		(refs["activity"] as Label).text = Game.describe_activity(creator)
		(refs["energy"] as ProgressBar).value = creator.energy
		(refs["mood"] as ProgressBar).value = creator.mood
		(refs["portrait"] as CreatorPreview).set_mood(CreatorMood.expression(creator, state.game_minutes))
		(refs["stats"] as Label).text = "%s fans  |  %s/hr" % [Fmt.compact(creator.followers),
			Fmt.money(Economy.creator_house_cash_per_hour(creator, state, Game.config))]
		var status: Label = refs["status"]
		status.visible = creator.is_recovering()
		if creator.is_recovering():
			status.text = "Recovering %s" % Fmt.game_duration(float(creator.recovery.get("remaining_minutes", 0)))


func _rebuild() -> void:
	var state := Game.state
	_signature = ""
	for creator in state.creators:
		_signature += creator.id + JSON.stringify(creator.look) + creator.measurements.summary() + "|"
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_cards.clear()
	for creator in state.creators:
		_list.add_child(_build_card(creator))
	refresh()


func _build_card(creator: CreatorState) -> Control:
	var id := creator.id
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, CARD_H)
	card.clip_contents = true
	card.tooltip_text = "%s, %d  -  %s\nClick to select. Manage opens her full profile." % [creator.display_name, creator.age, creator.archetype]
	card.pressed.connect(func() -> void: creator_selected.emit(id))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 4
	row.offset_right = -4
	row.offset_bottom = -4
	var portrait := CreatorPreview.new("portrait", Vector2(52, 0))
	portrait.pose = "idle"
	portrait.show_look(Appearance.render_spec(creator, Game.config))
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := UiTheme.label(creator.first_name(), 14, UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	var manage := Button.new()
	manage.text = "Manage"
	manage.custom_minimum_size = Vector2(0, 20)
	manage.add_theme_font_size_override("font_size", 11)
	manage.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.ACCENT.darkened(0.25), 6, 2))
	manage.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.ACCENT, 6, 2))
	manage.pressed.connect(func() -> void: manage_requested.emit(id))
	name_row.add_child(manage)
	info.add_child(name_row)
	var activity := UiTheme.label("", 11, UiTheme.GOLD)
	activity.clip_text = true
	activity.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(activity)
	var energy := _mini_bar(Color("4cc9f0"))
	var mood := _mini_bar(Color("f72585"))
	info.add_child(UiTheme.tip(energy, "Energy"))
	info.add_child(UiTheme.tip(mood, "Mood"))
	var stats := UiTheme.label("", 11, UiTheme.MUTED)
	stats.clip_text = true
	info.add_child(UiTheme.tip(stats, "Followers and the house's share of her current hourly income."))
	var status := UiTheme.label("", 11, Color("2ec4b6"))
	status.visible = false
	info.add_child(status)
	_cards[id] = {"card": card, "activity": activity, "energy": energy, "mood": mood, "stats": stats, "status": status, "portrait": portrait}
	_style_card(id)
	return card


func _style_card(id: String) -> void:
	var refs: Dictionary = _cards.get(id, {})
	if refs.is_empty():
		return
	var card: Button = refs["card"]
	var selected := id == selected_id
	var border := UiTheme.GOLD if selected else Color.TRANSPARENT
	card.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 10, 4, border, 2 if selected else 0))
	card.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_LIGHT.lightened(0.12), 10, 4, UiTheme.GOLD, 1))
	card.add_theme_stylebox_override("pressed", UiTheme.box(UiTheme.PANEL_LIGHT.lightened(0.12), 10, 4, UiTheme.GOLD, 2))


func _mini_bar(colour: Color) -> ProgressBar:
	var bar := UiTheme.bar(0, colour, 5)
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	return bar
