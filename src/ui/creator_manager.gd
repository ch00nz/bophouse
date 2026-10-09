class_name CreatorManager
extends Overlay
## Large creator management screen: a switcher across all residents, a big full-body preview that
## shows measurements, outfit and procedures clearly, and tabs: Overview, Stats & Measurements,
## Content, Makeover, Finances, Relationships. Switching creators keeps the screen and tab open.

const TABS := ["Overview", "Stats & Measurements", "Content", "Makeover", "Finances", "Relationships"]

static var last_tab: String = "Overview"

var creator_id: String = ""

var _switcher: HBoxContainer
var _switch_buttons: Dictionary = {}
var _preview: CreatorPreview
var _name: Label
var _identity: Label
var _measure: Label
var _tags: HFlowContainer
var _tab_buttons: Dictionary = {}
var _section_holder: VBoxContainer
var _section: Control
var _refresh_timer: float = 0.0


func _init(id: String, tab: String = "") -> void:
	creator_id = id
	if not tab.is_empty():
		last_tab = tab


func _build() -> void:
	set_title("Manage creators")
	_switcher = HBoxContainer.new()
	_switcher.add_theme_constant_override("separation", 4)
	header_row.add_child(_switcher)
	header_row.move_child(_switcher, 1)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	_preview = CreatorPreview.new("full", Vector2(320, 430))
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.pose = "film"
	left.add_child(_preview)
	_name = UiTheme.label("", 22, UiTheme.TEXT)
	left.add_child(_name)
	_identity = UiTheme.label("", 13, UiTheme.MUTED, true)
	_identity.custom_minimum_size = Vector2(320, 0)
	left.add_child(_identity)
	_measure = UiTheme.label("", 15, UiTheme.GOLD)
	left.add_child(UiTheme.tip(_measure, "Height, bust / waist / hips. Toggle units in Stats & Measurements."))
	_tags = HFlowContainer.new()
	_tags.add_theme_constant_override("h_separation", 4)
	_tags.add_theme_constant_override("v_separation", 4)
	left.add_child(_tags)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	columns.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	for tab_name: String in TABS:
		var button := UiTheme.tab_button(tab_name)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_show_tab.bind(tab_name))
		tabs.add_child(button)
		_tab_buttons[tab_name] = button
	right.add_child(tabs)
	_section_holder = Overlay.scroll_column(right)

	Game.appearance_changed.connect(_on_creator_changed)
	Game.recovery_finished.connect(func(id: String) -> void: _on_creator_changed(id, ""))
	Game.content_focus_changed.connect(func(id: String, _c: String) -> void:
		if id == creator_id and last_tab == "Content":
			_show_tab("Content"))
	Game.creator_joined.connect(func(_id: String) -> void: _build_switcher())
	Game.settings_changed.connect(_refresh_identity)
	_build_switcher()
	show_creator(creator_id)


func show_creator(id: String) -> void:
	if Game.state.get_creator(id) == null:
		return
	creator_id = id
	for key: String in _switch_buttons:
		(_switch_buttons[key] as Button).set_pressed_no_signal(key == id)
	_refresh_identity()
	_show_tab(last_tab)


func _build_switcher() -> void:
	for child in _switcher.get_children():
		_switcher.remove_child(child)
		child.queue_free()
	_switch_buttons.clear()
	for creator in Game.state.creators:
		var button := UiTheme.tab_button(creator.first_name())
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size = Vector2(84, 32)
		var id := creator.id
		button.pressed.connect(func() -> void: show_creator(id))
		_switcher.add_child(button)
		_switch_buttons[id] = button
		button.set_pressed_no_signal(id == creator_id)


func _refresh_identity() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null:
		return
	_preview.show_look(Appearance.render_spec(creator, Game.config))
	_name.text = creator.display_name
	_identity.text = "Age %d  |  %s  |  %s" % [creator.age, creator.archetype, ", ".join(PackedStringArray(creator.traits))]
	_measure.text = creator.measurements.summary(Game.imperial_units())
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
	for child in _section_holder.get_children():
		_section_holder.remove_child(child)
		child.queue_free()
	# The big preview is shared: the makeover tab shows before/after in it.
	_preview.show_look(Appearance.render_spec(Game.state.get_creator(creator_id), Game.config))
	match tab_name:
		"Stats & Measurements":
			_section = CreatorStatsSection.new(creator_id)
		"Content":
			_section = CreatorContentSection.new(creator_id)
		"Makeover":
			_section = CreatorMakeoverSection.new(creator_id, _preview)
		"Finances":
			_section = CreatorFinanceSection.new(creator_id)
		"Relationships":
			_section = CreatorRelationshipsSection.new(creator_id)
		_:
			var overview := CreatorOverviewSection.new(creator_id)
			overview.open_tab.connect(_show_tab)
			_section = overview
	_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_holder.add_child(_section)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < 0.25:
		return
	_refresh_timer = 0.0
	if _section != null and is_instance_valid(_section) and _section.has_method("refresh"):
		_section.call("refresh")


func _on_creator_changed(id: String, _item_id: String) -> void:
	if id != creator_id:
		return
	_refresh_identity()
	if last_tab != "Makeover":
		_show_tab(last_tab)
