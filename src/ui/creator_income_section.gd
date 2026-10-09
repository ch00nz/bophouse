class_name CreatorIncomeSection
extends VBoxContainer
## Income tab: explains where the money comes from and why it changes.

var creator_id: String = ""

var _now: Label
var _now_note: Label
var _content_title: Label
var _sales: Label
var _audience: Label
var _subs: Label
var _multipliers: VBoxContainer
var _followers: Label
var _subscribers: Label
var _entries: Array = []
var _value_labels: Array[Label] = []
var _row_signature: String = ""


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	add_child(UiTheme.header("Right now"))
	_now = UiTheme.label("", 20, UiTheme.GOOD)
	add_child(_now)
	_now_note = UiTheme.label("", 12, UiTheme.MUTED, true)
	add_child(_now_note)

	add_child(HSeparator.new())
	_content_title = UiTheme.header("")
	add_child(_content_title)
	_sales = UiTheme.value_label()
	_audience = UiTheme.value_label()
	_subs = UiTheme.value_label()
	add_child(UiTheme.tip(UiTheme.row("Content sales", _sales), "Base pay for the content, scaled by every multiplier below."))
	add_child(UiTheme.tip(UiTheme.row("Audience earnings", _audience), "Ads, tips and sales that grow with her follower count (with diminishing returns)."))
	add_child(UiTheme.tip(UiTheme.row("Subscriptions (always on)", _subs), "Paying subscribers pay around the clock, even while she sleeps."))

	add_child(HSeparator.new())
	add_child(UiTheme.header("What's affecting it"))
	_multipliers = VBoxContainer.new()
	_multipliers.add_theme_constant_override("separation", 3)
	add_child(_multipliers)

	add_child(HSeparator.new())
	add_child(UiTheme.header("Audience growth while working"))
	_followers = UiTheme.value_label()
	_subscribers = UiTheme.value_label()
	add_child(UiTheme.tip(UiTheme.row("Followers", _followers), "Growth slows as her audience gets bigger, so it never runs away."))
	add_child(UiTheme.tip(UiTheme.row("Subscribers", _subscribers), "Subscribers drift toward a target set by her followers and content type."))
	refresh()


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null or _now == null:
		return
	var config := Game.config
	var state := Game.state
	var b := Economy.work_breakdown(creator, state, config)
	var working := not creator.is_travelling() and creator.activity_id == CreatorBrain.WORK

	_now.text = "%s / hr" % Fmt.money(Economy.creator_cash_per_hour(creator, state, config))
	if working:
		_now_note.text = "Working, so content income plus subscriptions."
	elif creator.is_travelling():
		_now_note.text = "Walking: only subscriptions pay right now."
	else:
		_now_note.text = "%s. Subscriptions keep paying; content income resumes when she works." % Game.describe_activity(creator)

	_content_title.text = ("While making %s" % config.content_label(b["content_id"])).to_upper()
	_sales.text = "%s/hr" % Fmt.money(float(b["content_sales"]))
	_audience.text = "%s/hr" % Fmt.money(float(b["audience_earnings"]))
	_subs.text = "%s/hr" % Fmt.money(float(b["subscriptions"]))

	_entries.clear()
	var m: Dictionary = b["multipliers"]
	var content := config.content(str(b["content_id"]))
	var stat_names := PackedStringArray()
	for stat_id in content.get("stat_weights", {}):
		stat_names.append(config.stat_label(str(stat_id)))
	_add_multiplier("Content fit", float(m["fit"]),
		"How well her stats suit this content (%s). Average stats = no change." % ", ".join(stat_names))
	var room := state.get_room(str(b["room_id"]))
	var room_name := "%s Lv %d" % [config.room_type(room.type_id).get("name", ""), room.level] if room != null else "No room"
	_add_multiplier("Room: " + room_name, float(m["room"]), "Upgrading the room boosts everything made in it.")
	_add_multiplier("Energy & mood", float(m["productivity"]), "Tired or unhappy creators produce less. Rest and socialising fix it.")
	var effects: Array = b["trend_effects"]
	if effects.is_empty():
		_add_multiplier("Trends", 1.0, "No active trend favours this content right now. Check the Trends panel.")
	for effect: Dictionary in effects:
		_add_multiplier("Trend: " + str(effect["name"]), float(effect["income"]),
			"Trend strength %d%%, from content match, her favoured stats and her adaptability." % roundi(float(effect["strength"]) * 100.0))
	_add_multiplier("Experience", float(m["experience"]), "Settling into new content. Improves as she works; faster with high adaptability.")
	_sync_multiplier_rows()

	_followers.text = "+%s/hr" % Fmt.compact(float(b["followers"]))
	var sub_rate := float(b["subscribers"])
	_subscribers.text = "%s%.1f/hr  (target %s)" % ["+" if sub_rate >= 0.0 else "", sub_rate, Fmt.compact(float(b["target_subscribers"]))]


func _add_multiplier(caption: String, multiplier: float, tooltip: String) -> void:
	_entries.append({"caption": caption, "multiplier": multiplier, "tooltip": tooltip})


## Rebuilds rows only when their captions change (so hover tooltips stay stable), else updates values.
func _sync_multiplier_rows() -> void:
	var signature := ""
	for entry: Dictionary in _entries:
		signature += str(entry["caption"]) + "|"
	if signature != _row_signature:
		_row_signature = signature
		_value_labels.clear()
		for child in _multipliers.get_children():
			_multipliers.remove_child(child)
			child.queue_free()
		for entry: Dictionary in _entries:
			var value := UiTheme.value_label("", UiTheme.MUTED, 13)
			_value_labels.append(value)
			_multipliers.add_child(UiTheme.tip(UiTheme.row(str(entry["caption"]), value), str(entry["tooltip"])))
	for i in _entries.size():
		var multiplier := float(_entries[i]["multiplier"])
		var label: Label = _value_labels[i]
		label.text = "x%.2f  (%s)" % [multiplier, Fmt.percent_change(multiplier)]
		var color := UiTheme.MUTED
		if multiplier > 1.005:
			color = UiTheme.GOOD
		elif multiplier < 0.995:
			color = UiTheme.BAD
		label.add_theme_color_override("font_color", color)
		(_multipliers.get_child(i) as Control).tooltip_text = str(_entries[i]["tooltip"])
