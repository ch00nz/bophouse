class_name CreatorPanel
extends VBoxContainer
## Sidebar profile for one creator, split into tabs: Profile, Content and Income.

signal navigate(kind: String, id: String)

const TABS := ["Profile", "Content", "Income"]

static var last_tab: String = "Profile" # remembered across selections for convenience

var creator_id: String = ""

var _tab_buttons: Dictionary = {}
var _body: VBoxContainer
var _focus_label: Label
var _activity: Label
var _section: Control


func _init(id: String, initial_tab: String = "") -> void:
	creator_id = id
	if not initial_tab.is_empty():
		last_tab = initial_tab
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	var creator := _creator()
	if creator == null:
		return
	var back := Button.new()
	back.text = "< House overview"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: navigate.emit("overview", ""))
	add_child(back)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(CreatorPortrait.new(creator.appearance))
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UiTheme.label(creator.display_name, 20, UiTheme.TEXT, true))
	identity.add_child(UiTheme.label("Age %d" % creator.age, 14, UiTheme.MUTED))
	var traits := HFlowContainer.new()
	traits.add_theme_constant_override("h_separation", 4)
	traits.add_theme_constant_override("v_separation", 4)
	for trait_name in creator.traits:
		traits.add_child(_trait_chip(str(trait_name)))
	identity.add_child(traits)
	header.add_child(identity)
	add_child(header)

	# Fixed heights so live text changes never shift the buttons below under the cursor.
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
	tabs.add_theme_constant_override("separation", 4)
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
	_show_tab(last_tab)


func refresh() -> void:
	var creator := _creator()
	if creator == null or _activity == null:
		return
	_activity.text = Game.describe_activity(creator)
	_focus_label.text = "Specialising in: " + Game.config.content_label(creator.content_focus) \
		if not creator.content_focus.is_empty() else "No content specialisation"
	if _section != null and _section.has_method("refresh"):
		_section.call("refresh")


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


func _trait_chip(trait_name: String) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.GOLD.darkened(0.55), 6, 3))
	chip.add_child(UiTheme.label(trait_name, 12, UiTheme.GOLD))
	var description := str(Game.config.trait_defs.get(trait_name, {}).get("description", ""))
	if not description.is_empty():
		UiTheme.tip(chip, trait_name + ": " + description)
	return chip


func _creator() -> CreatorState:
	return Game.state.get_creator(creator_id)
