class_name CreatorContentSection
extends VBoxContainer
## Content tab: one card per content category with live projections and an assign button.
## Declined categories are shown (so the player understands why) but can never be selected.

var creator_id: String = ""

var _cards: Dictionary = {}       # content_id -> {projection: Label, trend: Label, experience: Label}
var _message: Label


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
	var first_name := ContentRules.first_name(creator)
	add_child(UiTheme.label("Choose %s's content focus. She only makes content within her own boundaries." % first_name, 13, UiTheme.MUTED, true))
	_message = UiTheme.label("", 13, UiTheme.BAD, true)
	_message.visible = false
	add_child(_message)
	for content_id in ContentRules.assignable_ids(Game.config):
		add_child(_build_card(creator, content_id))
	refresh()


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null:
		return
	for content_id: String in _cards:
		var refs: Dictionary = _cards[content_id]
		if not refs.has("projection"):
			continue
		var b := Economy.work_breakdown(creator, Game.state, Game.config, content_id)
		var fit := float(b["multipliers"]["audience_fit"])
		var room := Game.state.get_room(str(b["room_id"]))
		var room_text := "in %s" % Game.config.room_type(room.type_id).get("name", "") if room != null else "no room free"
		(refs["projection"] as Label).text = "~%s/hr   +%s fans/hr   look fit %s\n%s (set x%.2f)" % [
			Fmt.money(float(b["cash"])), Fmt.compact(float(b["followers"])), Fmt.percent_change(fit),
			room_text, float(b["multipliers"]["room"])]
		var trend_mult := float(b["multipliers"]["trend_income"])
		var trend_label: Label = refs["trend"]
		trend_label.visible = trend_mult > 1.005
		trend_label.text = "Trending: %s income" % Fmt.percent_change(trend_mult)
		var exp_value := creator.experience(content_id)
		(refs["experience"] as Label).text = "Experience %d%%" % roundi(exp_value * 100.0) if exp_value < 0.995 else "Experienced"


func _build_card(creator: CreatorState, content_id: String) -> Control:
	var config := Game.config
	var content := config.content(content_id)
	var check := ContentRules.check(creator, content_id, Game.state, config)
	var ok := bool(check["ok"])
	var is_focus := creator.content_focus == content_id
	var status := int(check["status"])

	var border := UiTheme.GOLD if is_focus else Color.TRANSPARENT
	var bg := UiTheme.PANEL_LIGHT if ok else UiTheme.PANEL_LIGHT.darkened(0.35)
	var card := UiTheme.card(bg, border)
	var body: VBoxContainer = card.get_child(0)

	var title_row := HBoxContainer.new()
	var title := UiTheme.label(str(content.get("label", content_id)), 15, UiTheme.TEXT if ok else UiTheme.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	var role := str(content.get("role", ""))
	if not role.is_empty():
		var role_colour := UiTheme.ACCENT if role == "Earner" else (Color("4cc9f0") if role == "Funnel" else UiTheme.MUTED)
		var role_chip := UiTheme.chip(role.to_upper(), role_colour,
			"Funnel: grows followers and reputation. Earner: subscribers and direct income. Balanced/Hybrid: a bit of both.")
		role_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(role_chip)
	title_row.add_child(_status_chip(creator, content_id, status, is_focus))
	body.add_child(title_row)

	body.add_child(UiTheme.label(str(content.get("description", "")), 12, UiTheme.MUTED, true))

	var refs := {}
	if status == ContentRules.Status.DECLINED:
		body.add_child(UiTheme.label(str(check["reason"]), 12, UiTheme.BAD, true))
	else:
		if not ok:
			body.add_child(UiTheme.label(str(check["reason"]), 12, UiTheme.GOLD, true))
		var projection := UiTheme.label("", 13, UiTheme.GOOD if ok else UiTheme.MUTED, true)
		UiTheme.tip(projection, "Estimated hourly output while making this content right now (before subscriptions).")
		body.add_child(projection)
		var details := HBoxContainer.new()
		var experience := UiTheme.label("", 12, UiTheme.MUTED)
		UiTheme.tip(experience, "New content starts less productive. Experience builds while working; adaptability speeds it up.")
		experience.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(experience)
		var trend := UiTheme.label("", 12, UiTheme.GOLD)
		details.add_child(trend)
		body.add_child(details)
		refs = {"projection": projection, "trend": trend, "experience": experience}
		body.add_child(UiTheme.label(_requirements_text(content), 11, UiTheme.MUTED, true))
		if ok and not is_focus:
			var assign := Button.new()
			assign.text = "Focus on this"
			assign.custom_minimum_size = Vector2(0, 32)
			assign.pressed.connect(_on_assign.bind(content_id))
			body.add_child(assign)
	_cards[content_id] = refs
	return card


func _status_chip(creator: CreatorState, content_id: String, status: int, is_focus: bool) -> Control:
	var text := ""
	var color := UiTheme.MUTED
	if is_focus:
		text = "CURRENT"
		color = UiTheme.GOLD
	else:
		match status:
			ContentRules.Status.DECLINED:
				text = "WON'T DO"
				color = UiTheme.BAD
			ContentRules.Status.LOCKED:
				text = "LOCKED"
			ContentRules.Status.NEEDS_STATS, ContentRules.Status.NEEDS_SUBSCRIBERS:
				text = "NOT YET"
			_:
				text = "LOVES IT" if ContentRules.loves(creator, content_id) else "WILLING"
				color = UiTheme.GOOD if ContentRules.loves(creator, content_id) else UiTheme.TEXT
	var chip := UiTheme.label(text, 11, color)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not is_focus and status == ContentRules.Status.AVAILABLE:
		UiTheme.tip(chip, "She loves this: a little less draining on her mood." if text == "LOVES IT" else "Within her boundaries.")
	return chip


func _requirements_text(content: Dictionary) -> String:
	var parts := PackedStringArray()
	var rates: Dictionary = content.get("rates_per_hour", {})
	parts.append("Energy %d/hr" % roundi(float(rates.get("energy", 0))))
	var weights: Dictionary = content.get("stat_weights", {})
	var stat_names := PackedStringArray()
	for stat_id in weights:
		stat_names.append(Game.config.stat_label(str(stat_id)))
	if not stat_names.is_empty():
		parts.append("Uses " + ", ".join(stat_names))
	var rooms := PackedStringArray()
	for entry: Dictionary in RoomProduction.supporting_types(Game.config, str(content.get("id", ""))):
		var name := str(Game.config.room_type(str(entry["type_id"])).get("name", entry["type_id"]))
		rooms.append(name if int(entry["min_level"]) <= 1 else "%s Lv%d" % [name, int(entry["min_level"])])
	if not rooms.is_empty():
		parts.append("Rooms: " + ", ".join(rooms))
	return "  |  ".join(parts)


func _on_assign(content_id: String) -> void:
	var result := Game.set_content_focus(creator_id, content_id)
	if not bool(result["ok"]):
		_message.text = str(result["reason"])
		_message.visible = true
