class_name CreatorMakeoverSection
extends VBoxContainer
## Makeover tab: big animated preview, current look summary, catalogue by category, a
## before/after preview with estimated appeal effects, and confirmation before spending.
## She has the final say: items she declines can't be bought.

const CATEGORIES := [["procedures", "Procedures"], ["styling", "Styling"], ["modifications", "Mods"]]

static var last_category: String = "styling"

var creator_id: String = ""

var _preview: CreatorPreview
var _summary: Label
var _recovery: Label
var _category_buttons: Dictionary = {}
var _list: VBoxContainer
var _detail: VBoxContainer
var _selected: String = ""
var _confirm: ConfirmationDialog
var _before_purchase: Dictionary = {}
var _list_signature: String = ""


## `external_preview`: draw before/after in a preview owned by the caller (the management screen's
## big preview) instead of an embedded one.
func _init(id: String, external_preview: CreatorPreview = null) -> void:
	creator_id = id
	_preview = external_preview
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	if _preview == null:
		_preview = CreatorPreview.new("full", Vector2(0, 280))
		add_child(_preview)

	_summary = UiTheme.label("", 12, UiTheme.TEXT, true)
	var summary_card := UiTheme.card()
	(summary_card.get_child(0) as VBoxContainer).add_child(UiTheme.header("Current look"))
	(summary_card.get_child(0) as VBoxContainer).add_child(_summary)
	_recovery = UiTheme.label("", 12, Color("2ec4b6"), true)
	(summary_card.get_child(0) as VBoxContainer).add_child(_recovery)
	add_child(summary_card)

	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 4)
	add_child(_detail)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	for entry: Array in CATEGORIES:
		var button := UiTheme.tab_button(str(entry[1]))
		button.pressed.connect(_show_category.bind(str(entry[0])))
		tabs.add_child(button)
		_category_buttons[str(entry[0])] = button
	add_child(tabs)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	add_child(_list)

	add_child(UiTheme.label("Changes are her choice: you can offer to fund them, never force them. Gameplay abstraction only, not medical advice.", 11, UiTheme.MUTED, true))

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Confirm makeover"
	_confirm.ok_button_text = "Fund it"
	_confirm.confirmed.connect(_on_confirmed)
	add_child(_confirm)

	_show_category(last_category)
	_show_current()
	refresh()


func refresh() -> void:
	var creator := _creator()
	if creator == null or _summary == null:
		return
	_summary.text = _summary_text(creator)
	_recovery.visible = creator.is_recovering()
	if creator.is_recovering():
		var item := Game.config.look_item(str(creator.recovery.get("item_id", "")))
		var total := float(creator.recovery.get("total_minutes", 1.0))
		var left := float(creator.recovery.get("remaining_minutes", 0.0))
		_recovery.text = "Recovering from %s: %s left (%d%% healed). Output reduced; she rests more." % [
			Appearance.item_label(Game.config, item).to_lower(), Fmt.game_duration(left), roundi((1.0 - left / total) * 100.0)]
	# Affordability changes as cash grows; rebuild the list only when something actually changed.
	var signature := _list_state_signature(creator)
	if signature != _list_signature:
		_build_list()


# ---------------------------------------------------------------------------
# Catalogue
# ---------------------------------------------------------------------------

func _show_category(category: String) -> void:
	last_category = category
	for key: String in _category_buttons:
		(_category_buttons[key] as Button).set_pressed_no_signal(key == category)
	_build_list()


func _build_list() -> void:
	var creator := _creator()
	_list_signature = _list_state_signature(creator)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var config := Game.config
	var last_group := ""
	for item_id in Appearance.items_in_category(config, last_category):
		var item := config.look_item(item_id)
		var group := str(item.get("group", ""))
		if group != last_group:
			_list.add_child(UiTheme.header(group))
			last_group = group
		_list.add_child(_item_row(creator, item_id, item))


func _item_row(creator: CreatorState, item_id: String, item: Dictionary) -> Control:
	var config := Game.config
	var check := Appearance.check_item(creator, Game.state, config, item_id)
	var applied := Appearance.is_applied(creator, item)
	var declined: bool = creator.appearance_prefs.get("declines", []).has(item_id)
	var price := float(check["price"])

	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 38)
	button.clip_text = true
	var selected := item_id == _selected
	var bg := UiTheme.PANEL_LIGHT
	if not bool(check["ok"]) and not applied:
		bg = UiTheme.PANEL_LIGHT.darkened(0.35)
	button.add_theme_stylebox_override("normal", UiTheme.box(bg, 8, 8, UiTheme.GOLD if selected else Color.TRANSPARENT, 2 if selected else 0))
	button.add_theme_stylebox_override("hover", UiTheme.box(bg.lightened(0.12), 8, 8, UiTheme.GOLD, 1))
	button.add_theme_stylebox_override("pressed", UiTheme.box(bg.lightened(0.12), 8, 8, UiTheme.GOLD, 2))

	var price_text := ""
	if applied:
		price_text = "CURRENT"
	elif declined:
		price_text = "SHE DECLINES"
	elif price <= 0.0:
		price_text = "OWNED - FREE"
	else:
		price_text = Fmt.money(price)
	var wish := " (she wants this!)" if creator.appearance_prefs.get("wishes", []).has(item_id) and not applied else ""
	button.text = "%s%s" % [Appearance.item_label(config, item), wish]
	var price_label := UiTheme.label(price_text, 13, UiTheme.GOLD if bool(check["affordable"]) else UiTheme.BAD)
	if applied:
		price_label.add_theme_color_override("font_color", UiTheme.GOOD)
	elif declined:
		price_label.add_theme_color_override("font_color", UiTheme.MUTED)
	price_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	price_label.offset_left = -110
	price_label.offset_right = -10
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_child(price_label)
	if not bool(check["ok"]) and not applied:
		button.add_theme_color_override("font_color", UiTheme.MUTED)
	button.tooltip_text = str(item.get("description", "")) + ("\n" + str(check["reason"]) if not str(check["reason"]).is_empty() else "")
	button.pressed.connect(_select.bind(item_id))
	return button


## Cheap signature of what the list shows so refresh() only rebuilds on real changes.
func _list_state_signature(creator: CreatorState) -> String:
	var parts := PackedStringArray([last_category, _selected, str(creator.is_recovering()), JSON.stringify(creator.look)])
	for item_id in Appearance.items_in_category(Game.config, last_category):
		parts.append(str(Appearance.check_item(creator, Game.state, Game.config, item_id)["ok"]))
	return "|".join(parts)


# ---------------------------------------------------------------------------
# Preview and purchase
# ---------------------------------------------------------------------------

func _show_current() -> void:
	_selected = ""
	_preview.show_look(Appearance.render_spec(_creator(), Game.config))
	_clear_detail()
	_detail.add_child(UiTheme.label("Pick an item below to preview it on her before you buy.", 12, UiTheme.MUTED, true))


func _select(item_id: String) -> void:
	var creator := _creator()
	if _selected == item_id:
		_show_current()
		_build_list()
		return
	_selected = item_id
	var eval := MakeoverEvaluator.evaluate(creator, Game.state, Game.config, item_id)
	_preview.show_compare(Appearance.render_spec(creator, Game.config), Appearance.render_spec(eval["after"], Game.config))
	_show_detail(creator, item_id, eval)
	_build_list()
	_scroll_to_preview.call_deferred()


func _show_detail(creator: CreatorState, item_id: String, eval: Dictionary) -> void:
	_clear_detail()
	var card := UiTheme.card(UiTheme.PANEL_LIGHT, UiTheme.GOLD)
	var body: VBoxContainer = card.get_child(0)
	var title_row := HBoxContainer.new()
	var title := UiTheme.label(str(eval["label"]), 16, UiTheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	title_row.add_child(UiTheme.label(Fmt.money(float(eval["price"])) if float(eval["price"]) > 0.0 else "Free", 16, UiTheme.TEXT))
	body.add_child(title_row)
	body.add_child(UiTheme.label(str(eval["item"].get("description", "")), 12, UiTheme.MUTED, true))

	# Appeal tags gained / lost.
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 4)
	tags.add_theme_constant_override("v_separation", 4)
	for change: Dictionary in eval["tag_changes"]:
		var delta := float(change["delta"])
		tags.add_child(UiTheme.chip("%s%s %d" % ["+" if delta > 0 else "-", change["label"], roundi(absf(delta) * 100.0)],
			UiTheme.GOOD if delta > 0 else UiTheme.BAD))
	if not (eval["tag_changes"] as Array).is_empty():
		body.add_child(tags)

	# Body measurement changes (procedures only; styling never changes measurements).
	var after_body: BodyMeasurements = (eval["after"] as CreatorState).measurements
	if after_body != null and after_body.summary() != creator.measurements.summary():
		var imperial := Game.imperial_units()
		body.add_child(UiTheme.row("Measurements", UiTheme.value_label("%s -> %s" % [
			creator.measurements.bwh_text(imperial), after_body.bwh_text(imperial)], UiTheme.GOLD, 12)))

	# Income effect (healed), current content first.
	body.add_child(UiTheme.header("Estimated income once healed"))
	for row: Dictionary in eval["content"]:
		if bool(row["current"]):
			body.add_child(_change_row("%s (current)" % row["label"], float(row["before"]), float(row["after"]), true))
	var best: Dictionary = eval["best"]
	var worst: Dictionary = eval["worst"]
	if not best.is_empty() and not bool(best["current"]) and float(best["change"]) > 1.005:
		body.add_child(_change_row("Best: " + str(best["short"]), float(best["before"]), float(best["after"]), true))
	if not worst.is_empty() and not bool(worst["current"]) and float(worst["change"]) < 0.995:
		body.add_child(_change_row("Worst: " + str(worst["short"]), float(worst["before"]), float(worst["after"]), true))
	body.add_child(_change_row("Subscriptions (her fans)", float(eval["subscriptions_before"]), float(eval["subscriptions_after"]), true))

	# Audiences.
	var segments: Array = eval["segments"]
	if not segments.is_empty():
		body.add_child(UiTheme.header("Audience appeal"))
		for i in mini(4, segments.size()):
			var seg: Dictionary = segments[i]
			body.add_child(_change_row(str(seg["name"]), float(seg["before"]), float(seg["after"]), false))

	var recovery: Dictionary = eval["recovery"]
	if not recovery.is_empty() and float(recovery.get("hours", 0)) > 0.0:
		var allowed: Array = recovery.get("allowed_content", [])
		var allowed_text := "can keep making any content" if allowed.is_empty() else "can only do " + ", ".join(PackedStringArray(allowed.map(func(c: Variant) -> String: return Game.config.content_label(str(c)))))
		body.add_child(UiTheme.label("Recovery: %s. Output x%.2f; she %s and rests more." % [
			Fmt.game_duration(float(recovery["hours"]) * 60.0), float(recovery.get("output", 1.0)), allowed_text], 12, Color("2ec4b6"), true))
	if bool(eval["wished"]):
		body.add_child(UiTheme.label("%s has wanted this! Big mood boost." % ContentRules.first_name(creator), 12, UiTheme.GOOD, true))

	var check: Dictionary = eval["check"]
	var buttons := HBoxContainer.new()
	var buy := Button.new()
	buy.text = "Fund for %s" % Fmt.money(float(check["price"])) if float(check["price"]) > 0.0 else "Switch to this"
	buy.custom_minimum_size = Vector2(0, 36)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.disabled = not bool(check["ok"])
	buy.pressed.connect(_ask_confirm.bind(item_id, eval))
	buttons.add_child(buy)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, 36)
	cancel.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL, 10, 6))
	cancel.pressed.connect(func() -> void:
		_show_current()
		_build_list())
	buttons.add_child(cancel)
	body.add_child(buttons)
	if not bool(check["ok"]):
		body.add_child(UiTheme.label(str(check["reason"]), 12, UiTheme.BAD, true))
	_detail.add_child(card)


func _change_row(caption: String, before: float, after: float, money: bool) -> HBoxContainer:
	var ratio := after / before if absf(before) > 0.01 else 1.0
	var colour := UiTheme.MUTED
	if ratio > 1.005:
		colour = UiTheme.GOOD
	elif ratio < 0.995:
		colour = UiTheme.BAD
	var text := ""
	if money:
		text = "%s -> %s (%s)" % [Fmt.money(before), Fmt.money(after), Fmt.percent_change(ratio)]
	else:
		text = "x%.1f -> x%.1f" % [before, after]
	return UiTheme.row(caption, UiTheme.value_label(text, colour, 12))


func _ask_confirm(item_id: String, eval: Dictionary) -> void:
	var creator := _creator()
	var recovery: Dictionary = eval["recovery"]
	var text := "Fund %s's %s for %s?" % [ContentRules.first_name(creator), str(eval["label"]).to_lower(), Fmt.money(float(eval["price"]))]
	if float(eval["price"]) <= 0.0:
		text = "Switch %s's look to %s?" % [ContentRules.first_name(creator), str(eval["label"]).to_lower()]
	if not recovery.is_empty() and float(recovery.get("hours", 0)) > 0.0:
		text += "\nShe'll need %s to recover." % Fmt.game_duration(float(recovery["hours"]) * 60.0)
	_confirm.dialog_text = text
	_confirm.set_meta("item_id", item_id)
	_confirm.popup_centered()


func _on_confirmed() -> void:
	var item_id := str(_confirm.get_meta("item_id", ""))
	var creator := _creator()
	_before_purchase = Appearance.render_spec(creator, Game.config)
	var result := Game.purchase_appearance(creator_id, item_id)
	_clear_detail()
	if not bool(result["ok"]):
		_detail.add_child(UiTheme.label(str(result["reason"]), 13, UiTheme.BAD, true))
		return
	_selected = ""
	# Before vs after of the real, now-applied change.
	_preview.show_compare(_before_purchase, Appearance.render_spec(creator, Game.config))
	var card := UiTheme.card(UiTheme.PANEL_LIGHT, UiTheme.GOOD)
	var body: VBoxContainer = card.get_child(0)
	var label := Appearance.item_label(Game.config, Game.config.look_item(item_id))
	body.add_child(UiTheme.label("Makeover done: %s" % label, 15, UiTheme.GOOD, true))
	if bool(result.get("wished", false)):
		body.add_child(UiTheme.label("%s is thrilled. Mood boosted." % ContentRules.first_name(creator), 12, UiTheme.GOOD, true))
	var tags := PackedStringArray()
	for tag_id in Appearance.visible_tags(creator, Game.config):
		tags.append(Game.config.tag_label(tag_id))
	body.add_child(UiTheme.label("Appeal tags now: " + ", ".join(tags), 12, UiTheme.TEXT, true))
	var back := Button.new()
	back.text = "Done"
	back.pressed.connect(func() -> void:
		_show_current()
		_build_list())
	body.add_child(back)
	_detail.add_child(card)
	_build_list()


## Brings the before/after preview into view after picking an item further down the list.
func _scroll_to_preview() -> void:
	var node := get_parent()
	while node != null and not node is ScrollContainer:
		node = node.get_parent()
	if node != null and (node as ScrollContainer).is_ancestor_of(_preview):
		(node as ScrollContainer).ensure_control_visible(_preview)


func _clear_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()


func _summary_text(creator: CreatorState) -> String:
	var config := Game.config
	var parts := PackedStringArray()
	parts.append("Hair: %s, %s" % [_opt("hair_color", creator), _opt("hair_style", creator).to_lower()])
	parts.append("Outfit: %s   |   Makeup: %s" % [_opt("outfit", creator), _opt("makeup", creator)])
	parts.append("Bust: %s   |   Body: %s   |   Lips: %s" % [_opt("bust", creator), _opt("body", creator), _opt("lips", creator)])
	parts.append("Measurements: " + creator.measurements.summary(Game.imperial_units()))
	var mods := PackedStringArray()
	for item_id in Appearance.items_in_category(config, "modifications"):
		if Appearance.is_applied(creator, config.look_item(item_id)):
			mods.append(Appearance.item_label(config, config.look_item(item_id)))
	parts.append("Mods: " + (", ".join(mods) if not mods.is_empty() else "none"))
	var history := PackedStringArray()
	for entry: Dictionary in creator.procedure_history:
		var item := config.look_item(str(entry.get("item_id", "")))
		if str(item.get("category", "")) == "procedures":
			history.append("%s (day %d)" % [Appearance.item_label(config, item), int(entry.get("day", 1))])
	parts.append("Procedures: " + (", ".join(history) if not history.is_empty() else "none"))
	return "\n".join(parts)


func _opt(slot: String, creator: CreatorState) -> String:
	return str(Game.config.look_option(slot, creator.look_value(slot)).get("label", creator.look_value(slot)))


func _creator() -> CreatorState:
	return Game.state.get_creator(creator_id)
