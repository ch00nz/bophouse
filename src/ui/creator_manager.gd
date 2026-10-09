class_name CreatorManager
extends Overlay
## Large creator management screen: a switcher across all residents, a hero full-body showcase
## (with close-up and house line-up views) that shows measurements, outfit, styling and procedures
## clearly, and tabs: Overview, Stats & Measurements,
## Content, Makeover, Finances, Relationships. Switching creators keeps the screen and tab open.

const TABS := ["Overview", "Stats & Measurements", "Content", "Makeover", "Finances", "Relationships"]

static var last_tab: String = "Overview"
## Hero view: "full", "closeup" or "lineup" (remembered between openings).
static var hero_view: String = "full"

var creator_id: String = ""

var _switcher: HBoxContainer
var _switch_buttons: Dictionary = {}
var _preview: CreatorPreview
var _view_buttons: Dictionary = {}
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
	left.custom_minimum_size = Vector2(372, 0)
	left.add_theme_constant_override("separation", 4)
	columns.add_child(left)
	_preview = CreatorPreview.new("full", Vector2(372, 470))
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.pose = "showcase"
	left.add_child(_preview)
	# View toggles float over the top of the showcase.
	var views := HBoxContainer.new()
	views.add_theme_constant_override("separation", 3)
	views.position = Vector2(8, 8)
	_preview.add_child(views)
	for entry: Array in [["full", "Full body"], ["closeup", "Close-up"], ["lineup", "Line-up"]]:
		var button := UiTheme.tab_button(str(entry[1]))
		button.add_theme_font_size_override("font_size", 11)
		button.clip_text = false
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.custom_minimum_size = Vector2(72, 24)
		button.tooltip_text = {"full": "Full-body showcase", "closeup": "Face, hair and makeup up close",
			"lineup": "Everyone in the house side by side, at their real heights"}[entry[0]]
		button.pressed.connect(_set_hero_view.bind(str(entry[0])))
		views.add_child(button)
		_view_buttons[str(entry[0])] = button
	views.reset_size()
	_identity = UiTheme.label("", 13, UiTheme.MUTED, true)
	_identity.custom_minimum_size = Vector2(372, 0)
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
	_show_hero(creator)
	_identity.text = ", ".join(PackedStringArray(creator.traits))
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
	_show_hero(Game.state.get_creator(creator_id))
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


func _set_hero_view(view: String) -> void:
	hero_view = view
	_show_hero(Game.state.get_creator(creator_id))


## Shows the selected creator in the hero view (full body, close-up, or the whole house line-up).
func _show_hero(creator: CreatorState) -> void:
	if creator == null:
		return
	for key: String in _view_buttons:
		(_view_buttons[key] as Button).set_pressed_no_signal(key == hero_view)
	_preview.set_caption(creator.display_name, "Age %d  |  %s" % [creator.age, creator.archetype])
	if hero_view == "lineup" and Game.state.creators.size() > 1:
		var specs: Array = []
		var names: Array = []
		for other in Game.state.creators:
			specs.append(Appearance.render_spec(other, Game.config))
			names.append(("> %s <" if other.id == creator.id else "%s") % other.first_name())
		_preview.set_framing("full")
		_preview.show_lineup(specs, names)
		return
	_preview.set_framing("closeup" if hero_view == "closeup" else "full")
	_preview.show_look(Appearance.render_spec(creator, Game.config))


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
