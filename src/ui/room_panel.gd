class_name RoomPanel
extends VBoxContainer
## Sidebar panel for one room: level, effect, occupants and the upgrade button.

signal navigate(kind: String, id: String)

var room_id: String = ""

var _built_level: int = -1
var _built_type: String = ""
var _build_buttons: Dictionary = {} # type_id -> [Button, Label]
var _occupants: Label
var _upgrade_button: Button
var _upgrade_status: Label


func _init(id: String) -> void:
	room_id = id
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	_build()


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var room := Game.state.get_room(room_id)
	if room == null:
		return
	var config := Game.config
	var type_def := config.room_type(room.type_id)
	var level_def := config.room_level_def(room.type_id, room.level)
	_built_level = room.level
	_built_type = room.type_id
	_build_buttons.clear()

	var back := Button.new()
	back.text = "< House overview"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: navigate.emit("overview", ""))
	add_child(back)

	add_child(UiTheme.label(str(type_def.get("name", room.type_id)), 22))
	var upgradable := bool(type_def.get("upgradable", false))
	if upgradable:
		add_child(UiTheme.label("Level %d of %d  -  %s" % [room.level, config.max_room_level(room.type_id), level_def.get("title", "")], 14, UiTheme.GOLD, true))
	add_child(UiTheme.label(str(type_def.get("description", "")), 14, UiTheme.MUTED, true))

	var effect := str(type_def.get("effect_label", ""))
	if not effect.is_empty():
		var quality := float(level_def.get("quality", 1.0))
		add_child(UiTheme.row(effect, UiTheme.label("x%.2f" % quality, 15, UiTheme.GOOD)))

	if Housing.beds(config, room) > 0:
		var residents := Housing.residents_of(Game.state, room.id)
		var who := "Resident: %s" % residents[0].display_name if not residents.is_empty() else "Free bedroom: ready for a new recruit."
		add_child(UiTheme.label(who, 14, UiTheme.GOLD if not residents.is_empty() else UiTheme.GOOD, true))
	var options := Housing.build_options(config, room)
	if not options.is_empty():
		add_child(HSeparator.new())
		add_child(UiTheme.label("Build here", 16))
		for type_id in options:
			var type_name := str(config.room_type(str(type_id)).get("name", type_id))
			add_child(UiTheme.label(str(config.room_type(str(type_id)).get("description", "")), 12, UiTheme.MUTED, true))
			var button := Button.new()
			button.custom_minimum_size = Vector2(0, 40)
			var build_type := str(type_id)
			button.pressed.connect(func() -> void:
				if bool(Game.build_room(room_id, build_type)["ok"]):
					_build())
			add_child(button)
			var status := UiTheme.label("", 13, UiTheme.MUTED, true)
			add_child(status)
			_build_buttons[build_type] = [button, status, type_name]
		add_child(UiTheme.label("Each new room costs more than the last and adds %s/day rent. A new bedroom lets another creator move in." % Fmt.money(config.tuning_f("expenses", "rent_per_built_room", 0.0)), 12, UiTheme.MUTED, true))
	_occupants = UiTheme.label("", 14, UiTheme.TEXT, true)
	add_child(UiTheme.label("In here now", 14, UiTheme.MUTED))
	add_child(_occupants)

	if not type_def.get("content_support", {}).is_empty():
		_add_production_section(room, type_def)

	if not upgradable:
		refresh()
		return

	add_child(HSeparator.new())
	var next := RoomUpgrades.next_level_def(config, room)
	if next.is_empty():
		add_child(UiTheme.label("Fully upgraded!", 16, UiTheme.GOLD))
		refresh()
		return
	add_child(UiTheme.label("Next upgrade", 16))
	add_child(UiTheme.label(str(next.get("title", "")), 15, UiTheme.GOLD, true))
	var current_q := float(level_def.get("quality", 1.0))
	var next_q := float(next.get("quality", 1.0))
	add_child(UiTheme.label("%s x%.2f -> x%.2f (+%d%%)" % [effect, current_q, next_q, roundi((next_q / current_q - 1.0) * 100.0)], 14, UiTheme.GOOD, true))
	var unlocks := PackedStringArray()
	var support: Dictionary = type_def.get("content_support", {})
	for content_id in support:
		if int(support[content_id].get("min_level", 1)) == room.level + 1:
			unlocks.append(config.content_label(str(content_id)))
	if not unlocks.is_empty():
		add_child(UiTheme.label("Can host here: " + ", ".join(unlocks), 14, UiTheme.GOLD, true))
	var next_production: Dictionary = next.get("production", {})
	var current_production: Dictionary = level_def.get("production", {})
	var gains := PackedStringArray()
	for attr in RoomProduction.ATTRIBUTES:
		var delta := float(next_production.get(attr, 0.0)) - float(current_production.get(attr, 0.0))
		if delta > 0.001:
			gains.append("%s +%d" % [attr.capitalize(), roundi(delta * 100.0)])
	if not gains.is_empty():
		add_child(UiTheme.label("Set quality: " + ", ".join(gains), 13, UiTheme.GOOD, true))
	var upkeep := float(next.get("upkeep_per_day", 0.0))
	if upkeep > 0.0:
		add_child(UiTheme.label("Upkeep %s/day once renovated." % Fmt.money(upkeep), 12, UiTheme.BAD, true))
	var value := Forecast.renovation_value(Game.state, config, room_id)
	add_child(UiTheme.label("Estimated %s%s/day net%s" % ["+" if float(value["gain_per_day"]) >= 0.0 else "", Fmt.money(float(value["gain_per_day"])),
		"" if float(value["payback_days"]) > 1000.0 else ", pays back in ~%s" % Fmt.game_duration(float(value["payback_days"]) * GameState.MINUTES_PER_DAY)], 12, UiTheme.GOLD, true))
	_upgrade_button = Button.new()
	_upgrade_button.custom_minimum_size = Vector2(0, 40)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)
	add_child(_upgrade_button)
	_upgrade_status = UiTheme.label("", 13, UiTheme.MUTED, true)
	add_child(_upgrade_status)
	refresh()


func refresh() -> void:
	var room := Game.state.get_room(room_id)
	if room == null:
		return
	if room.level != _built_level or room.type_id != _built_type:
		_build()
		return
	for type_id: String in _build_buttons:
		var entry: Array = _build_buttons[type_id]
		var check := Housing.check_build(Game.state, Game.config, room_id, type_id)
		(entry[0] as Button).text = "Build %s for %s" % [str(entry[2]).to_lower(), Fmt.money(float(check["cost"]))]
		(entry[0] as Button).disabled = not bool(check["ok"])
		(entry[1] as Label).text = str(check["reason"])
	if _occupants != null:
		var names := PackedStringArray()
		for creator in Game.state.occupants_of(room_id):
			names.append("%s (%s)" % [creator.display_name.get_slice(" ", 0), Game.describe_activity(creator)])
		_occupants.text = "\n".join(names) if not names.is_empty() else "Nobody"
	if _upgrade_button != null:
		var cost := RoomUpgrades.upgrade_cost(Game.config, room)
		_upgrade_button.text = "Upgrade for %s" % Fmt.money(cost)
		var affordable := Game.state.cash >= cost
		_upgrade_button.disabled = not affordable
		_upgrade_status.text = "" if affordable else "Need %s more" % Fmt.money(cost - Game.state.cash)


## Content set: owner (for private rooms), production attributes and what can be made here.
func _add_production_section(room: RoomState, type_def: Dictionary) -> void:
	var config := Game.config
	add_child(HSeparator.new())
	add_child(UiTheme.header("Content set"))
	if bool(type_def.get("private", false)):
		var owners := PackedStringArray()
		for creator in Game.state.creators:
			if creator.home_room_id == room.id:
				owners.append(creator.display_name.get_slice(" ", 0))
		add_child(UiTheme.label("Private: only %s films here." % (" & ".join(owners) if not owners.is_empty() else "its owner"), 12, UiTheme.MUTED, true))
	var attrs := RoomProduction.attributes(config, room)
	var tips := {
		"equipment": "Cameras, ring lights, laptops. Livestreams and glamour love gear.",
		"lighting": "Flattering light for photos and video.",
		"decor": "A set that looks good on camera.",
		"privacy": "A closed, intimate space. Premium and custom content need it.",
	}
	for attr in RoomProduction.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var caption := UiTheme.label(attr.capitalize(), 13, UiTheme.MUTED)
		caption.custom_minimum_size = Vector2(80, 0)
		row.add_child(caption)
		row.add_child(UiTheme.bar(float(attrs.get(attr, 0.0)) * 100.0, Color("4cc9f0"), 10))
		add_child(UiTheme.tip(row, str(tips.get(attr, ""))))
	var support: Dictionary = type_def.get("content_support", {})
	for content_id in ContentRules.assignable_ids(config):
		if not support.has(content_id):
			continue
		var entry: Dictionary = support[content_id]
		var min_level := int(entry.get("min_level", 1))
		var value: Label
		if room.level >= min_level:
			var mult := RoomProduction.multiplier(config, room, content_id)
			value = UiTheme.value_label("x%.2f" % mult, UiTheme.GOOD if mult >= 1.0 else UiTheme.TEXT, 13)
		else:
			value = UiTheme.value_label("from Lv %d" % min_level, UiTheme.MUTED, 13)
		add_child(UiTheme.tip(UiTheme.row(config.content_label(content_id), value),
			"Production multiplier for this content here: room fit x set quality (equipment, lighting, decor, privacy)."))


func _on_upgrade_pressed() -> void:
	if Game.upgrade_room(room_id):
		_build()
