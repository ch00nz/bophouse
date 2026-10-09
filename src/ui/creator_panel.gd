class_name CreatorPanel
extends VBoxContainer
## Sidebar summary for the selected creator: portrait, identity, measurements, appeal tags, status,
## activity and key numbers, with shortcuts into the full management screen (where the Overview,
## Stats & Measurements, Content, Makeover, Finances and Relationships tabs live).

signal navigate(kind: String, id: String)

var creator_id: String = ""

var _portrait: CreatorPreview
var _tags: HFlowContainer
var _measure: Label
var _status: Label
var _focus_label: Label
var _activity: Label
var _energy: ProgressBar
var _mood: ProgressBar
var _numbers: Label
var _photoshoot: Button
var _look_signature: String = ""


func _init(id: String, _initial_tab: String = "") -> void:
	creator_id = id
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	var creator := _creator()
	if creator == null:
		return
	var back := Button.new()
	back.text = "< House overview"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: navigate.emit("overview", ""))
	add_child(back)

	_portrait = CreatorPreview.new("portrait", Vector2(0, 160))
	_portrait.pose = "idle"
	add_child(_portrait)

	var name_row := HBoxContainer.new()
	var name_label := UiTheme.label(creator.display_name, 22, UiTheme.TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_label)
	var age := UiTheme.label("Age %d" % creator.age, 15, UiTheme.MUTED)
	age.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(age)
	add_child(name_row)
	add_child(UiTheme.label(creator.archetype, 13, UiTheme.ACCENT))
	_measure = UiTheme.label("", 14, UiTheme.GOLD)
	add_child(UiTheme.tip(_measure, "Height and bust / waist / hips."))

	var traits := HFlowContainer.new()
	traits.add_theme_constant_override("h_separation", 4)
	traits.add_theme_constant_override("v_separation", 4)
	for trait_name in creator.traits:
		var description := str(Game.config.trait_defs.get(trait_name, {}).get("description", ""))
		traits.add_child(UiTheme.chip(str(trait_name), UiTheme.GOLD, description))
	add_child(traits)
	_tags = HFlowContainer.new()
	_tags.add_theme_constant_override("h_separation", 4)
	_tags.add_theme_constant_override("v_separation", 4)
	add_child(_tags)

	_status = UiTheme.label("", 13, UiTheme.MUTED)
	_status.clip_text = true
	add_child(_status)
	_focus_label = UiTheme.label("", 14, UiTheme.ACCENT)
	_focus_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_focus_label.clip_text = true
	add_child(_focus_label)
	_activity = UiTheme.label("", 14, UiTheme.GOLD, true)
	_activity.custom_minimum_size = Vector2(0, 40)
	_activity.max_lines_visible = 2
	_activity.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(_activity)
	_energy = UiTheme.bar(0, Color("4cc9f0"), 10)
	_mood = UiTheme.bar(0, Color("f72585"), 10)
	add_child(UiTheme.row("Energy", UiTheme.value_label()))
	get_child(get_child_count() - 1).add_child(_energy)
	add_child(UiTheme.row("Mood", UiTheme.value_label()))
	get_child(get_child_count() - 1).add_child(_mood)
	_numbers = UiTheme.label("", 13, UiTheme.TEXT, true)
	add_child(_numbers)

	var manage := Button.new()
	manage.text = "Open %s's management" % creator.first_name()
	manage.custom_minimum_size = Vector2(0, 40)
	manage.pressed.connect(_open_manager.bind(""))
	add_child(manage)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 4)
	for tab: String in ["Content", "Makeover", "Finances"]:
		var button := UiTheme.tab_button(tab)
		button.toggle_mode = false
		button.pressed.connect(_open_manager.bind(tab))
		shortcuts.add_child(button)
	add_child(shortcuts)

	_photoshoot = Button.new()
	_photoshoot.custom_minimum_size = Vector2(0, 32)
	_photoshoot.clip_text = true
	_photoshoot.tooltip_text = "Optional mini-game: direct a quick photoshoot for bonus income and followers. She produces content automatically either way."
	_photoshoot.pressed.connect(func() -> void:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("open_photoshoot", creator_id))
	add_child(_photoshoot)
	refresh()


func refresh() -> void:
	var creator := _creator()
	if creator == null or _activity == null:
		return
	var signature := JSON.stringify(creator.look) + creator.measurements.summary() + str(Game.imperial_units()) + str(creator.is_recovering())
	if signature != _look_signature:
		_look_signature = signature
		_refresh_look()
	_activity.text = Game.describe_activity(creator)
	_focus_label.text = "Specialising in: " + Game.config.content_label(creator.content_focus) \
		if not creator.content_focus.is_empty() else "No content specialisation"
	if creator.is_recovering():
		var item := Game.config.look_item(str(creator.recovery.get("item_id", "")))
		_status.text = "Recovering (%s): %s left" % [Appearance.item_label(Game.config, item).to_lower(),
			Fmt.game_duration(float(creator.recovery.get("remaining_minutes", 0)))]
		_status.add_theme_color_override("font_color", Color("2ec4b6"))
	else:
		_status.text = "Status: healthy  |  Reputation %d" % roundi(creator.reputation)
		_status.add_theme_color_override("font_color", UiTheme.MUTED)
	_energy.value = creator.energy
	_mood.value = creator.mood
	var gross := Economy.creator_cash_per_hour(creator, Game.state, Game.config)
	_numbers.text = "%s followers  |  %s subscribers\nEarning %s/hr gross, %s/hr to the house (%s split)\nLiving costs %s/day" % [
		Fmt.compact(creator.followers), Fmt.compact(creator.subscribers), Fmt.money(gross),
		Fmt.money(gross * creator.house_share()), Contracts.split_text(creator.creator_share()), Fmt.money(creator.living_cost_per_day)]
	var shoot := Photoshoot.check(creator, Game.state, Game.config)
	_photoshoot.disabled = not bool(shoot["ok"])
	_photoshoot.text = "Direct a bonus photoshoot" if bool(shoot["ok"]) else "Photoshoot: " + str(shoot["reason"])


func _refresh_look() -> void:
	var creator := _creator()
	_portrait.show_look(Appearance.render_spec(creator, Game.config))
	_measure.text = creator.measurements.summary(Game.imperial_units())
	for child in _tags.get_children():
		_tags.remove_child(child)
		child.queue_free()
	for tag_id in Appearance.visible_tags(creator, Game.config):
		var colour := PlaceholderArt.color(Game.config.tag_defs.get(tag_id, {}).get("color"), UiTheme.TEXT)
		_tags.add_child(UiTheme.chip(Game.config.tag_label(tag_id), colour,
			"Appeal tag (%d%%). Tags decide which audiences love her look." % roundi(creator.tag(tag_id) * 100.0)))


func _open_manager(tab: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("open_manager", creator_id, tab)


func _creator() -> CreatorState:
	return Game.state.get_creator(creator_id)
