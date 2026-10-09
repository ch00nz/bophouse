class_name OverviewPanel
extends VBoxContainer
## Default sidebar content: house profit and finances, trends, residents and rooms at a glance.

signal navigate(kind: String, id: String)

var _income: Label
var _gross: Label
var _audience: Label
var _ledger: Label
var _trends: Label
var _residents: VBoxContainer
var _capacity: Label
var _creator_buttons: Dictionary = {} # creator_id -> Button
var _room_buttons: Dictionary = {}    # room_id -> Button
var _rooms: VBoxContainer
var _layout_signature: String = ""


func _init() -> void:
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	add_child(UiTheme.label("Your House", 22))
	_income = UiTheme.label("", 16, UiTheme.GOOD)
	add_child(UiTheme.tip(_income, "The house's share of every creator's current income, minus running costs."))
	_gross = UiTheme.label("", 12, UiTheme.MUTED, true)
	add_child(_gross)
	_audience = UiTheme.label("", 13, UiTheme.MUTED, true)
	add_child(_audience)
	_ledger = UiTheme.label("", 12, UiTheme.TEXT, true)
	add_child(UiTheme.tip(_ledger, "Yesterday's real figures. Open Finances for every line item."))

	add_child(HSeparator.new())
	add_child(UiTheme.label("Trending now", 16))
	_trends = UiTheme.label("", 13, UiTheme.GOLD, true)
	add_child(_trends)
	var trends_button := _list_button()
	trends_button.text = "View trends & strategy"
	trends_button.pressed.connect(func() -> void: navigate.emit("trends", ""))
	add_child(trends_button)

	add_child(HSeparator.new())
	var head := HBoxContainer.new()
	var residents_title := UiTheme.label("Residents", 16)
	residents_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(residents_title)
	_capacity = UiTheme.label("", 12, UiTheme.MUTED)
	head.add_child(_capacity)
	add_child(head)
	_residents = VBoxContainer.new()
	_residents.add_theme_constant_override("separation", 6)
	add_child(_residents)
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 4)
	for entry: Array in [["Finances", "open_finances"], ["Upgrades", "open_upgrades"]]:
		var b := _list_button()
		b.text = str(entry[0])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var method := str(entry[1])
		b.pressed.connect(func() -> void:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null:
				hud.call(method))
		money.add_child(b)
	add_child(money)
	var recruit := Button.new()
	recruit.text = "Applications to join the house"
	recruit.custom_minimum_size = Vector2(0, 36)
	recruit.pressed.connect(func() -> void:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("open_applications"))
	add_child(recruit)

	add_child(HSeparator.new())
	add_child(UiTheme.label("Rooms", 16))
	_rooms = VBoxContainer.new()
	_rooms.add_theme_constant_override("separation", 6)
	add_child(_rooms)

	add_child(HSeparator.new())
	add_child(UiTheme.label(
		"Tip: click a creator or room in the house to inspect it. Build bedrooms on empty lots to house more creators. "
		+ "The house keeps earning while you're away (at reduced efficiency, capped).", 12, UiTheme.MUTED, true))
	refresh()


func refresh() -> void:
	if _income == null:
		return
	var state := Game.state
	var config := Game.config
	_rebuild_lists_if_needed()
	var profit := Economy.house_profit_per_hour(state, config)
	_income.text = "House profit %s / hour  (~%s/day)" % [Fmt.money(profit), Fmt.money(Forecast.steady_net_per_day(state, config))]
	_income.add_theme_color_override("font_color", UiTheme.GOOD if profit >= 0.0 else UiTheme.BAD)
	_gross.text = "Creators' gross %s/hr  |  House share %s/hr  |  Running costs %s/hr" % [Fmt.money(Economy.gross_cash_per_hour(state, config)),
		Fmt.money(Economy.house_cash_per_hour(state, config)), Fmt.money(Economy.expenses_per_hour(state, config))]
	_audience.text = "%s followers  |  %s paying subscribers" % [Fmt.compact(state.total_followers()), Fmt.compact(state.total_subscribers())]
	var house := state.total_house_earnings()
	var y := state.yesterday
	var y_costs := 0.0
	for key in Expenses.KEYS:
		y_costs += float(y.get(key, 0.0))
	_ledger.text = "Yesterday: %s gross  |  %s house share  |  %s costs  |  net %s" % [
		Fmt.money(float(y.get("gross", 0.0))), Fmt.money(float(y.get("house", 0.0))), Fmt.money(y_costs), Fmt.money(float(y.get("house", 0.0)) - y_costs)] \
		if not y.is_empty() else "Lifetime house share %s. Daily figures appear after the first full day." % Fmt.money(house)
	_capacity.text = "%d / %d beds" % [state.creators.size(), Housing.total_beds(state, config)]
	var trend_lines := PackedStringArray()
	for entry: Dictionary in state.active_trends:
		trend_lines.append("%s  (%s left)" % [config.trend(str(entry["id"])).get("name", entry["id"]), Fmt.game_duration(float(entry["remaining_minutes"]))])
	_trends.text = "\n".join(trend_lines)
	for creator_id in _creator_buttons:
		var creator := state.get_creator(creator_id)
		var button: Button = _creator_buttons[creator_id]
		button.text = "%s  -  %s/hr  -  %s" % [creator.first_name(), Fmt.money(Economy.creator_house_cash_per_hour(creator, state, config)), Game.describe_activity(creator)]
		button.tooltip_text = "Content focus: %s\nLifetime to the house: %s\nLiving costs: %s/day" % [config.content_label(creator.content_focus),
			Fmt.money(creator.house_earnings), Fmt.money(creator.living_cost_per_day)]
	for room_id in _room_buttons:
		var room := state.get_room(room_id)
		var button: Button = _room_buttons[room_id]
		var name := str(config.room_type(room.type_id).get("name", room.type_id))
		if not Housing.build_options(config, room).is_empty():
			var cost := Housing.build_cost(state, config, "bedroom")
			button.text = "Empty lot  -  build a bedroom %s%s" % [Fmt.money(cost), "  (ready!)" if state.cash >= cost else ""]
			continue
		var residents := Housing.residents_of(state, room_id)
		if not residents.is_empty():
			name = "%s's bedroom" % residents[0].first_name()
		var cost := RoomUpgrades.upgrade_cost(config, room)
		if cost < 0.0:
			button.text = "%s  (Lv %d, max)" % [name, room.level]
		elif state.cash >= cost:
			button.text = "%s  (Lv %d)  -  upgrade ready! %s" % [name, room.level, Fmt.money(cost)]
		else:
			button.text = "%s  (Lv %d)  -  next %s" % [name, room.level, Fmt.money(cost)]


func _rebuild_lists_if_needed() -> void:
	var state := Game.state
	var signature := ""
	for creator in state.creators:
		signature += creator.id + ","
	for room in state.rooms:
		signature += room.type_id + ","
	if signature == _layout_signature:
		return
	_layout_signature = signature
	for container: VBoxContainer in [_residents, _rooms]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	_creator_buttons.clear()
	_room_buttons.clear()
	for creator in state.creators:
		var button := _list_button()
		var id := creator.id
		button.pressed.connect(func() -> void: navigate.emit("creator", id))
		_residents.add_child(button)
		_creator_buttons[id] = button
	for room in state.rooms:
		var type_def := Game.config.room_type(room.type_id)
		if not bool(type_def.get("upgradable", false)) and Housing.build_options(Game.config, room).is_empty():
			continue
		var button := _list_button()
		var id := room.id
		button.pressed.connect(func() -> void: navigate.emit("room", id))
		_rooms.add_child(button)
		_room_buttons[id] = button


func _list_button() -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 8))
	button.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_LIGHT.lightened(0.15), 8, 8))
	return button
