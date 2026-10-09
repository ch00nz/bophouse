class_name UpgradesPanel
extends Overlay
## Upgrades & renovations: every way to invest in the house in one place. Each card shows the price,
## daily maintenance, what it does, prerequisites, and an estimate of how much more the house would
## net per day and how long it takes to pay back (Forecast, same formulas as the simulation).

var _summary: Label
var _list: VBoxContainer
var _message: Label
var _signature: String = ""


func _build() -> void:
	set_title("Upgrades & renovations")
	_summary = UiTheme.label("", 13, UiTheme.TEXT, true)
	body.add_child(_summary)
	_message = UiTheme.label("", 13, UiTheme.GOOD, true)
	body.add_child(_message)
	_list = Overlay.scroll_column(body, 8)
	Game.upgrade_purchased.connect(func(_id: String) -> void: _rebuild())
	Game.room_upgraded.connect(func(_id: String) -> void: _rebuild())
	_rebuild()


func _process(_delta: float) -> void:
	var signature := "%d" % int(Game.state.cash / 25.0)
	if signature != _signature:
		_signature = signature
		_refresh_summary()
		_refresh_buttons()


func _refresh_summary() -> void:
	var state := Game.state
	var config := Game.config
	var net := Forecast.steady_net_per_day(state, config)
	_summary.text = "Cash %s  |  Running costs %s/day  |  Estimated net profit %s/day. Estimates assume today's trends and content; maintenance is already counted." % [
		Fmt.money(state.cash), Fmt.money(Expenses.total_per_day(state, config)), Fmt.money(net)]


func _rebuild() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var config := Game.config
	var state := Game.state
	for category: Dictionary in config.upgrades_data.get("categories", []):
		var ids: Array[String] = []
		for upgrade_id in config.upgrade_order:
			if str(config.upgrade(upgrade_id).get("category", "")) == str(category["id"]):
				ids.append(upgrade_id)
		if ids.is_empty():
			continue
		_list.add_child(UiTheme.header(str(category.get("label", category["id"]))))
		var grid := _grid()
		for upgrade_id in ids:
			grid.add_child(_upgrade_card(upgrade_id))
		_list.add_child(grid)
	_list.add_child(UiTheme.header("Room renovations"))
	var rooms := _grid()
	for room in state.rooms:
		if bool(config.room_type(room.type_id).get("upgradable", false)):
			rooms.add_child(_renovation_card(room))
	_list.add_child(rooms)
	_refresh_summary()
	_refresh_buttons()


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


func _card_shell(title: String, price: float, maintenance: float, description: String, effects: String, owned: bool) -> Array:
	var card := UiTheme.card(UiTheme.PANEL_LIGHT, UiTheme.GOOD if owned else Color.TRANSPARENT)
	card.custom_minimum_size = Vector2(370, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c: VBoxContainer = card.get_child(0)
	var head := HBoxContainer.new()
	var name := UiTheme.label(title, 15, UiTheme.GOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiTheme.label("OWNED" if owned else Fmt.money(price), 15, UiTheme.GOOD if owned else UiTheme.TEXT))
	c.add_child(head)
	c.add_child(UiTheme.label(description, 11, UiTheme.MUTED, true))
	if not effects.is_empty():
		c.add_child(UiTheme.label(effects, 12, UiTheme.TEXT, true))
	if maintenance > 0.0:
		c.add_child(UiTheme.label("Maintenance %s/day" % Fmt.money(maintenance), 11, UiTheme.BAD))
	return [card, c]


func _upgrade_card(upgrade_id: String) -> Control:
	var config := Game.config
	var state := Game.state
	var upgrade := config.upgrade(upgrade_id)
	var owned := Upgrades.owned(state, upgrade_id)
	var shell := _card_shell(str(upgrade.get("label", upgrade_id)), float(upgrade.get("price", 0.0)), float(upgrade.get("maintenance_per_day", 0.0)),
		str(upgrade.get("description", "")), Upgrades.effect_text(config, upgrade), owned)
	var c: VBoxContainer = shell[1]
	if not owned:
		if upgrade_id == Upgrades.EXPANSION:
			c.add_child(UiTheme.label("Extra rent %s/day. Room for two more bedrooms (new housemates)." % Fmt.money(config.tuning_f("expenses", "rent_expansion", 0.0)), 12, UiTheme.TEXT, true))
		else:
			c.add_child(_estimate_label(Forecast.upgrade_value(state, config, upgrade_id)))
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(0, 32)
		buy.set_meta("upgrade_id", upgrade_id)
		buy.pressed.connect(_on_buy_upgrade.bind(upgrade_id))
		c.add_child(buy)
		var reason := UiTheme.label("", 11, UiTheme.BAD, true)
		c.add_child(reason)
		buy.set_meta("reason_label", reason)
	return shell[0]


func _renovation_card(room: RoomState) -> Control:
	var config := Game.config
	var state := Game.state
	var type_def := config.room_type(room.type_id)
	var next := RoomUpgrades.next_level_def(config, room)
	var residents := Housing.residents_of(state, room.id)
	var name := str(type_def.get("name", room.type_id))
	if not residents.is_empty():
		name = "%s's bedroom" % residents[0].first_name()
	if next.is_empty():
		return _card_shell("%s (Lv %d)" % [name, room.level], 0.0, 0.0, "Fully renovated.", "", true)[0]
	var shell := _card_shell("%s: Lv %d -> %d" % [name, room.level, room.level + 1], float(next.get("cost", 0.0)), float(next.get("upkeep_per_day", 0.0)),
		str(next.get("title", "")), _production_gain(room, next), false)
	var c: VBoxContainer = shell[1]
	c.add_child(_estimate_label(Forecast.renovation_value(state, config, room.id)))
	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 32)
	buy.set_meta("room_id", room.id)
	buy.pressed.connect(_on_renovate.bind(room.id))
	c.add_child(buy)
	return shell[0]


func _production_gain(room: RoomState, next: Dictionary) -> String:
	var current: Dictionary = Game.config.room_level_def(room.type_id, room.level).get("production", {})
	var upcoming: Dictionary = next.get("production", {})
	var parts := PackedStringArray()
	for attr in RoomProduction.ATTRIBUTES:
		var delta := float(upcoming.get(attr, 0.0)) - float(current.get(attr, 0.0))
		if delta > 0.001:
			parts.append("%s +%d" % [attr.capitalize(), roundi(delta * 100.0)])
	return "Set quality: " + ", ".join(parts) if not parts.is_empty() else ""


func _estimate_label(value: Dictionary) -> Label:
	var gain := float(value["gain_per_day"])
	var payback := float(value["payback_days"])
	var text := "Estimated %s%s/day net" % ["+" if gain >= 0.0 else "", Fmt.money(gain)]
	if payback < 1000.0:
		text += "  |  pays back in ~%s" % Fmt.game_duration(payback * GameState.MINUTES_PER_DAY)
	else:
		text += "  |  little direct income (reach, unlocks or comfort)"
	var colour := UiTheme.GOOD if payback < 10.0 else (UiTheme.GOLD if payback < 30.0 else UiTheme.MUTED)
	return UiTheme.label(text, 12, colour, true)


func _refresh_buttons() -> void:
	for button: Button in _list.find_children("*", "Button", true, false):
		if button.has_meta("upgrade_id"):
			var check := Upgrades.check(Game.state, Game.config, str(button.get_meta("upgrade_id")))
			button.text = "Buy for %s" % Fmt.money(float(check["price"]))
			button.disabled = not bool(check["ok"])
			(button.get_meta("reason_label") as Label).text = str(check["reason"])
		elif button.has_meta("room_id"):
			var room := Game.state.get_room(str(button.get_meta("room_id")))
			var cost := RoomUpgrades.upgrade_cost(Game.config, room)
			button.text = "Renovate for %s" % Fmt.money(cost) if Game.state.cash >= cost else "Need %s more" % Fmt.money(cost - Game.state.cash)
			button.disabled = not RoomUpgrades.can_upgrade(Game.state, Game.config, room.id)


func _on_buy_upgrade(upgrade_id: String) -> void:
	var result := Game.purchase_upgrade(upgrade_id)
	_message.text = ("Bought: %s" % Game.config.upgrade(upgrade_id).get("label", upgrade_id)) if bool(result["ok"]) else str(result["reason"])
	_message.add_theme_color_override("font_color", UiTheme.GOOD if bool(result["ok"]) else UiTheme.BAD)


func _on_renovate(room_id: String) -> void:
	if Game.upgrade_room(room_id):
		_message.text = "Renovation done!"
		_message.add_theme_color_override("font_color", UiTheme.GOOD)
