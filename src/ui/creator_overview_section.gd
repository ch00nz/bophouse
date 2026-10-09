class_name CreatorOverviewSection
extends VBoxContainer
## Overview tab: what she's doing, wellbeing, audience, her bedroom (with reassignment), content
## focus, the optional photoshoot, and her bio with strengths and weaknesses.

signal open_tab(tab_name: String)

var creator_id: String = ""

var _activity: Label
var _status: Label
var _focus: Label
var _bedroom: OptionButton
var _bedroom_ids: Array[String] = []
var _bedroom_message: Label
var _photoshoot: Button
var _profile: CreatorProfileSection


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
	var now := UiTheme.card()
	var n: VBoxContainer = now.get_child(0)
	n.add_child(UiTheme.header("Right now"))
	_activity = UiTheme.label("", 15, UiTheme.GOLD, true)
	n.add_child(_activity)
	_status = UiTheme.label("", 12, UiTheme.MUTED, true)
	n.add_child(_status)
	var focus_row := HBoxContainer.new()
	_focus = UiTheme.label("", 13, UiTheme.ACCENT)
	_focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_row.add_child(_focus)
	var change := Button.new()
	change.text = "Change content"
	change.pressed.connect(func() -> void: open_tab.emit("Content"))
	focus_row.add_child(change)
	n.add_child(focus_row)
	_photoshoot = Button.new()
	_photoshoot.custom_minimum_size = Vector2(0, 32)
	_photoshoot.clip_text = true
	_photoshoot.tooltip_text = "Optional mini-game for bonus income and followers. She produces content automatically either way."
	_photoshoot.pressed.connect(func() -> void:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("open_photoshoot", creator_id))
	n.add_child(_photoshoot)
	add_child(now)

	var home := UiTheme.card()
	var h: VBoxContainer = home.get_child(0)
	h.add_child(UiTheme.header("Bedroom"))
	h.add_child(UiTheme.label("She sleeps, rests and films private content in her own bedroom. Choosing someone else's room swaps them.", 11, UiTheme.MUTED, true))
	_bedroom = OptionButton.new()
	_bedroom.item_selected.connect(_on_bedroom_selected)
	h.add_child(_bedroom)
	_bedroom_message = UiTheme.label("", 12, UiTheme.GOOD, true)
	h.add_child(_bedroom_message)
	add_child(home)
	_fill_bedrooms()

	_profile = CreatorProfileSection.new(creator_id, false)
	add_child(_profile)

	add_child(HSeparator.new())
	add_child(UiTheme.header("About her"))
	if not creator.bio.is_empty():
		add_child(UiTheme.label(creator.bio, 13, UiTheme.TEXT, true))
	var template: Dictionary = Game.config.creator_templates.get(creator_id, {})
	if template.has("strengths"):
		add_child(UiTheme.label("Strengths: " + str(template["strengths"]), 12, UiTheme.GOOD, true))
	if template.has("weaknesses"):
		add_child(UiTheme.label("Weaknesses: " + str(template["weaknesses"]), 12, UiTheme.BAD, true))
	var boundaries := PackedStringArray()
	for content_id in creator.content_declines:
		boundaries.append(Game.config.content_label(str(content_id)))
	add_child(UiTheme.label("Won't make: " + (", ".join(boundaries) if not boundaries.is_empty() else "no hard limits on current content"), 12, UiTheme.MUTED, true))
	refresh()


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null or _activity == null:
		return
	_activity.text = Game.describe_activity(creator)
	if creator.is_recovering():
		var item := Game.config.look_item(str(creator.recovery.get("item_id", "")))
		_status.text = "Recovering from %s: %s left. Output reduced; rests more." % [Appearance.item_label(Game.config, item).to_lower(),
			Fmt.game_duration(float(creator.recovery.get("remaining_minutes", 0)))]
		_status.add_theme_color_override("font_color", Color("2ec4b6"))
	else:
		var night := "night owl" if creator.sleep_shift_hours >= 1.0 else ("early bird" if creator.sleep_shift_hours <= -1.0 else "regular hours")
		_status.text = "Healthy  |  Reputation %d  |  Routine: %s" % [roundi(creator.reputation), night]
		_status.add_theme_color_override("font_color", UiTheme.MUTED)
	_focus.text = "Specialising in: " + Game.config.content_label(creator.content_focus) if not creator.content_focus.is_empty() else "No content specialisation"
	var shoot := Photoshoot.check(creator, Game.state, Game.config)
	_photoshoot.disabled = not bool(shoot["ok"])
	_photoshoot.text = "Direct a bonus photoshoot" if bool(shoot["ok"]) else "Photoshoot: " + str(shoot["reason"])
	_profile.refresh()


func _fill_bedrooms() -> void:
	var state := Game.state
	var creator := state.get_creator(creator_id)
	_bedroom.clear()
	_bedroom_ids.clear()
	for room in state.rooms:
		if Housing.beds(Game.config, room) <= 0:
			continue
		var residents := Housing.residents_of(state, room.id)
		var label := "%s (Lv %d)" % [_room_name(room), room.level]
		if not residents.is_empty() and residents[0] != creator:
			label += " - %s's, swap" % residents[0].first_name()
		elif residents.is_empty():
			label += " - free"
		_bedroom.add_item(label)
		_bedroom_ids.append(room.id)
		if room.id == creator.home_room_id:
			_bedroom.select(_bedroom_ids.size() - 1)


func _on_bedroom_selected(index: int) -> void:
	if index < 0 or index >= _bedroom_ids.size():
		return
	var result := Game.assign_bedroom(creator_id, _bedroom_ids[index])
	if bool(result["ok"]):
		var swapped := Game.state.get_creator(str(result.get("swapped_with", "")))
		_bedroom_message.text = "Moved in." + (" %s took her old room." % swapped.first_name() if swapped != null else "")
		_bedroom_message.add_theme_color_override("font_color", UiTheme.GOOD)
	elif str(result.get("reason", "")) != "Already her bedroom":
		_bedroom_message.text = str(result.get("reason", ""))
		_bedroom_message.add_theme_color_override("font_color", UiTheme.BAD)
	_fill_bedrooms()


func _room_name(room: RoomState) -> String:
	var floors := ["Ground floor", "First floor", "Top floor"]
	var floor_name: String = floors[room.storey] if room.storey < floors.size() else "Floor %d" % room.storey
	return "%s bedroom (%s)" % [floor_name, "left" if room.column < 2 else "right"]
