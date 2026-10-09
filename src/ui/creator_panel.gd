class_name CreatorPanel
extends VBoxContainer
## Sidebar profile for one creator: a large portrait header with identity, appeal tags and status,
## then tabs: Profile, Content, Makeover and Income.

signal navigate(kind: String, id: String)

const TABS := ["Profile", "Content", "Makeover", "Income"]

static var last_tab: String = "Profile" # remembered across selections for convenience

var creator_id: String = ""

var _tab_buttons: Dictionary = {}
var _body: VBoxContainer
var _portrait: CreatorPreview
var _tags: HFlowContainer
var _status: Label
var _focus_label: Label
var _activity: Label
var _section: Control


func _init(id: String, initial_tab: String = "") -> void:
	creator_id = id
	if not initial_tab.is_empty():
		last_tab = initial_tab
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

	_portrait = CreatorPreview.new("portrait", Vector2(0, 176))
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

	# Fixed heights so live text changes never shift the buttons below under the cursor.
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

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	for tab_name: String in TABS:
		var button := UiTheme.tab_button(tab_name)
		button.pressed.connect(_show_tab.bind(tab_name))
		tabs.add_child(button)
		_tab_buttons[tab_name] = button
	add_child(tabs)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)

	Game.content_focus_changed.connect(_on_content_changed)
	Game.content_unlocked.connect(_on_content_unlocked)
	Game.appearance_changed.connect(_on_appearance_changed)
	Game.recovery_finished.connect(_on_recovery_finished)
	_refresh_look()
	_show_tab(last_tab)


func refresh() -> void:
	var creator := _creator()
	if creator == null or _activity == null:
		return
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
	if _section != null and _section.has_method("refresh"):
		_section.call("refresh")


func _refresh_look() -> void:
	var creator := _creator()
	_portrait.show_look(Appearance.render_spec(creator, Game.config))
	for child in _tags.get_children():
		_tags.remove_child(child)
		child.queue_free()
	for tag_id in Appearance.visible_tags(creator, Game.config):
		var colour := PlaceholderArt.color(Game.config.tag_defs.get(tag_id, {}).get("color"), UiTheme.TEXT)
		_tags.add_child(UiTheme.chip(Game.config.tag_label(tag_id), colour,
			"Appeal tag (%d%%). Tags decide which audiences love her look." % roundi(creator.tag(tag_id) * 100.0)))


func _show_tab(tab_name: String) -> void:
	last_tab = tab_name
	for key: String in _tab_buttons:
		(_tab_buttons[key] as Button).set_pressed_no_signal(key == tab_name)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match tab_name:
		"Content":
			_section = CreatorContentSection.new(creator_id)
		"Makeover":
			_section = CreatorMakeoverSection.new(creator_id)
		"Income":
			_section = CreatorIncomeSection.new(creator_id)
		_:
			_section = CreatorProfileSection.new(creator_id)
	_body.add_child(_section)
	refresh()


func _on_content_unlocked(_content_id: String) -> void:
	_show_tab(last_tab)


func _on_content_changed(changed_id: String, _content_id: String) -> void:
	if changed_id == creator_id:
		_show_tab(last_tab)


func _on_appearance_changed(changed_id: String, _item_id: String) -> void:
	if changed_id == creator_id:
		_refresh_look()


func _on_recovery_finished(changed_id: String) -> void:
	if changed_id == creator_id:
		_refresh_look()
		_show_tab(last_tab)


func _creator() -> CreatorState:
	return Game.state.get_creator(creator_id)
