class_name OverviewPanel
extends VBoxContainer
## Default sidebar content: house totals, residents and rooms at a glance.

signal navigate(kind: String, id: String)

var _income: Label
var _audience: Label
var _creator_buttons: Dictionary = {} # creator_id -> Button
var _room_buttons: Dictionary = {}    # room_id -> Button


func _init() -> void:
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	add_child(UiTheme.label("Your House", 22))
	_income = UiTheme.label("", 16, UiTheme.GOOD)
	add_child(_income)
	_audience = UiTheme.label("", 14, UiTheme.MUTED, true)
	add_child(_audience)

	add_child(HSeparator.new())
	add_child(UiTheme.label("Residents", 16))
	for creator in Game.state.creators:
		var button := _list_button()
		var id := creator.id
		button.pressed.connect(func() -> void: navigate.emit("creator", id))
		add_child(button)
		_creator_buttons[id] = button
	add_child(UiTheme.label("More creators can be recruited in a later milestone.", 12, UiTheme.MUTED, true))

	add_child(HSeparator.new())
	add_child(UiTheme.label("Rooms", 16))
	for room in Game.state.rooms:
		if not bool(Game.config.room_type(room.type_id).get("upgradable", false)):
			continue
		var button := _list_button()
		var id := room.id
		button.pressed.connect(func() -> void: navigate.emit("room", id))
		add_child(button)
		_room_buttons[id] = button

	add_child(HSeparator.new())
	add_child(UiTheme.label(
		"Tip: click a creator or room in the house to inspect it. Upgrades make rooms more effective. "
		+ "The house keeps earning while you're away (at reduced efficiency, capped).", 12, UiTheme.MUTED, true))
	refresh()


func refresh() -> void:
	if _income == null:
		return
	var state := Game.state
	var config := Game.config
	_income.text = "Earning %s / hour" % Fmt.money(Economy.house_cash_per_hour(state, config))
	_audience.text = "%s followers  |  %s paying subscribers" % [Fmt.compact(state.total_followers()), Fmt.compact(state.total_subscribers())]
	for creator_id in _creator_buttons:
		var creator := state.get_creator(creator_id)
		(_creator_buttons[creator_id] as Button).text = "%s  -  %s" % [creator.display_name, Game.describe_activity(creator)]
	for room_id in _room_buttons:
		var room := state.get_room(room_id)
		var button: Button = _room_buttons[room_id]
		var name := str(config.room_type(room.type_id).get("name", room.type_id))
		var cost := RoomUpgrades.upgrade_cost(config, room)
		if cost < 0.0:
			button.text = "%s  (Lv %d, max)" % [name, room.level]
		elif state.cash >= cost:
			button.text = "%s  (Lv %d)  -  upgrade ready! %s" % [name, room.level, Fmt.money(cost)]
		else:
			button.text = "%s  (Lv %d)  -  next %s" % [name, room.level, Fmt.money(cost)]


func _list_button() -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size = Vector2(0, 34)
	button.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 8))
	button.add_theme_stylebox_override("hover", UiTheme.box(UiTheme.PANEL_LIGHT.lightened(0.15), 8, 8))
	return button
