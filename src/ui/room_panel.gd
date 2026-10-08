class_name RoomPanel
extends VBoxContainer
## Sidebar panel for one room: level, effect, occupants and the upgrade button.

signal navigate(kind: String, id: String)

var room_id: String = ""

var _built_level: int = -1
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

	_occupants = UiTheme.label("", 14, UiTheme.TEXT, true)
	add_child(UiTheme.label("In here now", 14, UiTheme.MUTED))
	add_child(_occupants)

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
	if room.level != _built_level:
		_build()
		return
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


func _on_upgrade_pressed() -> void:
	if Game.upgrade_room(room_id):
		_build()
