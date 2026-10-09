class_name ApplicationsPanel
extends Overlay
## Applications: creators who want to live and work in the house. Browse applicants (portrait,
## measurements, terms, living costs, earning potential), read a full profile with a big preview,
## and invite her to move in, or compare everyone side by side. Joining costs nothing; each
## resident adds living costs. Some creators only apply once the house meets their expectations,
## and everyone needs a free bedroom, which can be built right here.

var _list: VBoxContainer
var _housing: Label
var _build_button: Button
var _detail_holder: VBoxContainer
var _selected: String = ""
var _compare: bool = false
var _compare_button: Button
var _message: String = ""
var _estimates: Dictionary = {} # template id -> estimate (cached while open; trends barely move meanwhile)
var _invite_button: Button
var _invite_reason: Label
var _state_signature: String = ""
var _detail_scroll: ScrollContainer


func _build() -> void:
	set_title("Applications to join the house")
	_compare_button = Button.new()
	_compare_button.text = "Compare all"
	_compare_button.toggle_mode = true
	_compare_button.custom_minimum_size = Vector2(120, 34)
	_compare_button.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 8, 6))
	_compare_button.toggled.connect(func(on: bool) -> void:
		_compare = on
		_show_detail())
	header_row.add_child(_compare_button)
	header_row.move_child(_compare_button, header_row.get_child_count() - 2)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	body.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 6)
	columns.add_child(left)
	var housing_card := UiTheme.card()
	var h: VBoxContainer = housing_card.get_child(0)
	_housing = UiTheme.label("", 12, UiTheme.TEXT, true)
	h.add_child(_housing)
	_build_button = Button.new()
	_build_button.custom_minimum_size = Vector2(0, 32)
	_build_button.pressed.connect(_on_build)
	h.add_child(_build_button)
	left.add_child(housing_card)
	_list = Overlay.scroll_column(left, 6)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_detail_holder = VBoxContainer.new()
	_detail_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_detail_holder)

	Game.creator_joined.connect(func(_id: String) -> void: _refresh_all())
	Game.room_built.connect(func(_id: String) -> void: _refresh_all())
	_refresh_all()


func _process(_delta: float) -> void:
	# Cash, followers and rooms change while this is open: keep housing and eligibility current.
	var state := Game.state
	var signature := "%d|%d|%d" % [int(state.cash / 50.0), state.creators.size(), int(state.total_followers() / 100.0)]
	if signature != _state_signature:
		_state_signature = signature
		_refresh_housing()
		_update_invite_button()


func _refresh_all() -> void:
	_estimates.clear()
	var ids := Applications.applicant_ids(Game.state, Game.config)
	if not ids.has(_selected):
		_selected = ids[0] if not ids.is_empty() else ""
	_build_list()
	_refresh_housing()
	_show_detail()


func _estimate(template_id: String) -> Dictionary:
	if not _estimates.has(template_id):
		_estimates[template_id] = Applications.estimate(Game.config.creator_templates[template_id], Game.state, Game.config)
	return _estimates[template_id]


func _refresh_housing() -> void:
	var state := Game.state
	var config := Game.config
	var problem := Housing.vacancy_problem(state, config)
	var free := Housing.free_bedrooms(state, config).size()
	_housing.text = "Residents %d / %d beds  |  Running costs %s/day\n%s" % [state.creators.size(), Housing.total_beds(state, config),
		Fmt.money(Expenses.total_per_day(state, config)),
		problem if not problem.is_empty() else "%d free bedroom%s ready for a new housemate." % [free, "" if free == 1 else "s"]]
	_housing.add_theme_color_override("font_color", UiTheme.BAD if not problem.is_empty() else UiTheme.GOOD)
	var lots := Housing.buildable_lots(state, config, "bedroom")
	_build_button.visible = not lots.is_empty()
	if not lots.is_empty():
		var check := Housing.check_build(state, config, lots[0].id, "bedroom")
		_build_button.text = "Build a bedroom  (%s)" % Fmt.money(float(check["cost"]))
		_build_button.disabled = not bool(check["ok"])
		_build_button.tooltip_text = "Turns an empty lot into a new bedroom. " + str(check["reason"])


func _on_build() -> void:
	var lots := Housing.buildable_lots(Game.state, Game.config, "bedroom")
	if lots.is_empty():
		return
	var result := Game.build_room(lots[0].id, "bedroom")
	if not bool(result["ok"]):
		_message = str(result["reason"])


# ---------------------------------------------------------------------------
# Applicant list
# ---------------------------------------------------------------------------

func _build_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := Applications.applicant_ids(Game.state, Game.config)
	if ids.is_empty():
		_list.add_child(UiTheme.label("Everyone who applied has moved in! More creators will apply in later milestones.", 13, UiTheme.TEXT, true))
	for template_id in ids:
		_list.add_child(_applicant_card(template_id))


func _applicant_card(template_id: String) -> Control:
	var config := Game.config
	var template: Dictionary = config.creator_templates[template_id]
	var estimate := _estimate(template_id)
	var creator: CreatorState = estimate["creator"]
	var applied := Applications.has_applied(template, Game.state, config)
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 86)
	card.clip_contents = true
	var selected := template_id == _selected
	var bg := UiTheme.PANEL_LIGHT if applied else UiTheme.PANEL_LIGHT.darkened(0.3)
	card.add_theme_stylebox_override("normal", UiTheme.box(bg, 10, 4, UiTheme.GOLD if selected else Color.TRANSPARENT, 2 if selected else 0))
	card.add_theme_stylebox_override("hover", UiTheme.box(bg.lightened(0.12), 10, 4, UiTheme.GOLD, 1))
	card.add_theme_stylebox_override("pressed", UiTheme.box(bg.lightened(0.12), 10, 4, UiTheme.GOLD, 2))
	card.pressed.connect(func() -> void:
		_selected = template_id
		_message = ""
		_compare = false
		_compare_button.set_pressed_no_signal(false)
		_build_list()
		_show_detail())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 4
	row.offset_right = -6
	row.offset_bottom = -4
	var portrait := CreatorPreview.new("portrait", Vector2(64, 0))
	portrait.pose = "idle"
	portrait.show_look(Appearance.render_spec(creator, config))
	row.add_child(portrait)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)
	info.add_child(UiTheme.label("%s, %d" % [creator.display_name, creator.age], 14))
	info.add_child(UiTheme.label(creator.archetype + ("" if applied else "  (interested)"), 12, UiTheme.ACCENT if applied else UiTheme.MUTED))
	info.add_child(UiTheme.label(creator.measurements.summary(Game.imperial_units()), 11, UiTheme.MUTED))
	info.add_child(UiTheme.label("%s  |  %s split  |  %s/day" % [_stars(int(estimate["rating"])), Contracts.split_text(creator.creator_share()),
		Fmt.money(creator.living_cost_per_day)], 12, UiTheme.GOLD))
	return card


static func _stars(rating: int) -> String:
	return "*".repeat(rating) + "-".repeat(maxi(5 - rating, 0))


# ---------------------------------------------------------------------------
# Profile / comparison
# ---------------------------------------------------------------------------

func _show_detail() -> void:
	# Keep the reader's place when the profile is rebuilt for the same applicant.
	var keep_scroll := 0
	if _detail_scroll != null and is_instance_valid(_detail_scroll) and str(_detail_scroll.get_meta("applicant", "")) == _selected:
		keep_scroll = _detail_scroll.scroll_vertical
	_detail_scroll = null
	for child in _detail_holder.get_children():
		_detail_holder.remove_child(child)
		child.queue_free()
	_invite_button = null
	if _compare:
		_show_compare()
		return
	if _selected.is_empty():
		return
	var config := Game.config
	var template: Dictionary = config.creator_templates[_selected]
	var estimate := _estimate(_selected)
	var creator: CreatorState = estimate["creator"]

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	_detail_holder.add_child(columns)
	var preview := CreatorPreview.new("full", Vector2(250, 0))
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.pose = "film"
	preview.show_look(Appearance.render_spec(creator, config))
	columns.add_child(preview)
	var column := Overlay.scroll_column(columns, 6)
	_detail_scroll = column.get_parent() as ScrollContainer
	_detail_scroll.set_meta("applicant", _selected)
	if keep_scroll > 0:
		_restore_scroll(_detail_scroll, keep_scroll)

	var title := HBoxContainer.new()
	var name_label := UiTheme.label(creator.display_name, 22)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	title.add_child(UiTheme.label("Age %d" % creator.age, 15, UiTheme.MUTED))
	column.add_child(title)
	column.add_child(UiTheme.label(creator.archetype + "  -  " + creator.bio, 13, UiTheme.TEXT, true))
	column.add_child(UiTheme.label("Strengths: " + str(template.get("strengths", "")), 12, UiTheme.GOOD, true))
	column.add_child(UiTheme.label("Weaknesses: " + str(template.get("weaknesses", "")), 12, UiTheme.BAD, true))

	var traits := HFlowContainer.new()
	traits.add_theme_constant_override("h_separation", 4)
	traits.add_theme_constant_override("v_separation", 4)
	for trait_name in creator.traits:
		traits.add_child(UiTheme.chip(str(trait_name), UiTheme.GOLD, str(config.trait_defs.get(trait_name, {}).get("description", ""))))
	for tag_id in Appearance.visible_tags(creator, config):
		var colour := PlaceholderArt.color(config.tag_defs.get(tag_id, {}).get("color"), UiTheme.TEXT)
		traits.add_child(UiTheme.chip(config.tag_label(tag_id), colour, "Appearance tag (%d%%)" % roundi(creator.tag(tag_id) * 100.0)))
	column.add_child(traits)

	# Moving in: her terms, living costs, expectations and the invite.
	var terms := UiTheme.card(UiTheme.PANEL_LIGHT, UiTheme.GOLD)
	var k: VBoxContainer = terms.get_child(0)
	k.add_child(UiTheme.header("Moving in"))
	k.add_child(UiTheme.label("Her terms: she keeps %d%% of what she earns; the house keeps %d%%. No fee to join." % [
		roundi(creator.creator_share() * 100.0), roundi(creator.house_share() * 100.0)], 13, UiTheme.GOLD, true))
	k.add_child(UiTheme.label("Living costs: %s per day (rent share, utilities, food and lifestyle), paid by the house while she lives here." % Fmt.money(creator.living_cost_per_day), 12, UiTheme.TEXT, true))
	k.add_child(UiTheme.tip(UiTheme.label("Estimate now (current trends and rooms): %s/hr while working + %s/hr subscriptions.\n~%s gross per day, ~%s/day to the house, ~%s/day after her living costs.  Growth potential: %d%%." % [
		Fmt.money(float(estimate["work_per_hour"])), Fmt.money(float(estimate["subscriptions_per_hour"])),
		Fmt.money(float(estimate["gross_per_day"])), Fmt.money(float(estimate["house_per_day"])),
		Fmt.money(float(estimate["net_per_day"])), roundi(float(estimate["growth"]) * 100.0)], 12, UiTheme.TEXT, true),
		"Rough estimate. Her audience grows as she works, so earnings usually rise after she settles in."))
	k.add_child(UiTheme.label("Before she moves in the house needs %s in the bank (a few days of running costs including hers). It stays yours." % Fmt.money(Applications.required_reserve(template, Game.state, config)), 12, UiTheme.MUTED, true))
	_invite_button = Button.new()
	_invite_button.custom_minimum_size = Vector2(0, 42)
	_invite_button.pressed.connect(_on_invite)
	k.add_child(_invite_button)
	_invite_reason = UiTheme.label(_message, 12, UiTheme.BAD, true)
	k.add_child(_invite_reason)
	column.add_child(terms)

	var body_card := UiTheme.card()
	var b: VBoxContainer = body_card.get_child(0)
	b.add_child(UiTheme.header("Measurements & look"))
	b.add_child(UiTheme.label(creator.measurements.summary(Game.imperial_units()), 16, UiTheme.GOLD))
	var look_parts := PackedStringArray()
	for slot in ["hair_color", "hair_style", "outfit", "makeup"]:
		look_parts.append(str(config.look_option(slot, creator.look_value(slot)).get("label", "")))
	var mods := PackedStringArray()
	for item_id in config.look_item_order:
		var item := config.look_item(item_id)
		if str(item.get("category", "")) != "styling" and Appearance.is_applied(creator, item):
			mods.append(Appearance.item_label(config, item))
	b.add_child(UiTheme.label("Style: " + ", ".join(look_parts) + ("\nProcedures & mods: " + ", ".join(mods) if not mods.is_empty() else "\nAll natural, no procedures or mods"), 12, UiTheme.TEXT, true))
	column.add_child(body_card)

	var stats_card := UiTheme.card()
	var s: VBoxContainer = stats_card.get_child(0)
	s.add_child(UiTheme.header("Stats"))
	s.add_child(CreatorProfileSection.stat_grid(creator))
	column.add_child(stats_card)

	var content_card := UiTheme.card()
	var c: VBoxContainer = content_card.get_child(0)
	c.add_child(UiTheme.header("Content & audience"))
	c.add_child(UiTheme.label("Preferred specialisation: %s" % config.content_label(str(template.get("content", {}).get("default_focus", ""))), 13, UiTheme.ACCENT, true))
	c.add_child(UiTheme.label("Loves: " + _content_list(creator.content_accepts), 12, UiTheme.GOOD, true))
	c.add_child(UiTheme.label("Won't do (her boundaries, never overridden): " + _content_list(creator.content_declines), 12, UiTheme.BAD, true))
	var declines := PackedStringArray()
	for item_id in creator.appearance_prefs.get("declines", []):
		declines.append(Appearance.item_label(config, config.look_item(str(item_id))))
	if not declines.is_empty():
		c.add_child(UiTheme.label("Not interested in: " + ", ".join(declines), 12, UiTheme.MUTED, true))
	c.add_child(UiTheme.label("Audience: %s followers, %s paying subscribers  |  Reputation %d" % [Fmt.compact(creator.followers), Fmt.compact(creator.subscribers), roundi(creator.reputation)], 12, UiTheme.TEXT, true))
	column.add_child(content_card)
	_update_invite_button()


## Restores a scroll offset once the rebuilt content has been laid out.
func _restore_scroll(scroll: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = value


func _update_invite_button() -> void:
	if _invite_button == null or not is_instance_valid(_invite_button) or _selected.is_empty():
		return
	var check := Applications.check(Game.state, Game.config, _selected)
	var first := str(Game.config.creator_templates[_selected].get("name", "")).get_slice(" ", 0)
	_invite_button.text = "Invite %s to move in" % first
	_invite_button.disabled = not bool(check["ok"])
	if not bool(check["ok"]):
		_invite_reason.text = str(check["reason"])
		_invite_reason.add_theme_color_override("font_color", UiTheme.BAD)
	elif _message.is_empty():
		_invite_reason.text = "She'll move into a free bedroom straight away."
		_invite_reason.add_theme_color_override("font_color", UiTheme.GOOD)


func _on_invite() -> void:
	var name := str(Game.config.creator_templates[_selected].get("name", ""))
	var result := Game.accept_application(_selected)
	if bool(result["ok"]):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("show_toast", "%s has moved in. Welcome home!" % name, UiTheme.GOOD)
		_message = ""
	else:
		_message = str(result["reason"])
		_show_detail()


func _show_compare() -> void:
	var config := Game.config
	var ids := Applications.applicant_ids(Game.state, config)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_holder.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = ids.size() + 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	grid.add_child(Control.new())
	for template_id in ids:
		var creator: CreatorState = _estimate(template_id)["creator"]
		var portrait := CreatorPreview.new("full", Vector2(96, 150))
		portrait.pose = "idle"
		portrait.show_look(Appearance.render_spec(creator, config))
		grid.add_child(portrait)
	var rows: Array = [
		["Name", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return "%s, %d" % [c.first_name(), c.age]],
		["Archetype", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return c.archetype],
		["Height", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return c.measurements.height_text(Game.imperial_units())],
		["B / W / H", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return c.measurements.bwh_text(Game.imperial_units()).replace(" cm", "").replace(" in", "")],
		["Body type", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return _top_body_tag(c)],
		["Looks", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("looks")))],
		["Charisma", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("charisma")))],
		["Work ethic", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("work_ethic")))],
		["Stamina", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("stamina")))],
		["Adaptability", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("adaptability")))],
		["Wildness", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("wildness")))],
		["Drama", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return str(int(c.stat("drama")))],
		["Followers", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return Fmt.compact(c.followers)],
		["Subscribers", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return Fmt.compact(c.subscribers)],
		["Focus", func(_c: CreatorState, e: Dictionary, _t: Dictionary) -> String: return str(config.content(str(e["focus"])).get("short", e["focus"]))],
		["Split (her/house)", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return Contracts.split_text(c.creator_share())],
		["Living costs / day", func(c: CreatorState, _e: Dictionary, _t: Dictionary) -> String: return Fmt.money(c.living_cost_per_day)],
		["Gross / day (est.)", func(_c: CreatorState, e: Dictionary, _t: Dictionary) -> String: return Fmt.money(float(e["gross_per_day"]))],
		["House net / day (est.)", func(_c: CreatorState, e: Dictionary, _t: Dictionary) -> String: return Fmt.money(float(e["net_per_day"]))],
		["Potential", func(_c: CreatorState, e: Dictionary, _t: Dictionary) -> String: return _stars(int(e["rating"]))],
		["Applied?", func(_c: CreatorState, _e: Dictionary, t: Dictionary) -> String: return "Yes" if Applications.has_applied(t, Game.state, config) else "Not yet"],
	]
	for row: Array in rows:
		grid.add_child(UiTheme.label(str(row[0]), 12, UiTheme.MUTED))
		var getter: Callable = row[1]
		for template_id in ids:
			var estimate := _estimate(template_id)
			var cell := UiTheme.label(str(getter.call(estimate["creator"], estimate, config.creator_templates[template_id])), 12, UiTheme.TEXT)
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(cell)


static func _top_body_tag(creator: CreatorState) -> String:
	var best := ""
	var best_value := 0.15
	for tag_id in Game.config.appearance.get("body_tags", []):
		if creator.tag(str(tag_id)) > best_value:
			best_value = creator.tag(str(tag_id))
			best = Game.config.tag_label(str(tag_id))
	return best if not best.is_empty() else "Balanced"


static func _content_list(ids: Array) -> String:
	var names := PackedStringArray()
	for content_id in ids:
		names.append(Game.config.content_label(str(content_id)))
	return ", ".join(names) if not names.is_empty() else "none"
