class_name CreatorPanel
extends VBoxContainer
## Sidebar profile for one creator: identity, live activity, needs, audience and stats.

signal navigate(kind: String, id: String)

const STAT_ORDER := ["looks", "wildness", "adaptability", "charisma", "work_ethic", "stamina", "confidence", "drama"]

var creator_id: String = ""

var _activity: Label
var _energy: ProgressBar
var _energy_value: Label
var _mood: ProgressBar
var _mood_value: Label
var _followers: Label
var _subscribers: Label
var _rate: Label
var _lifetime: Label


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
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
	identity.add_child(UiTheme.label(", ".join(PackedStringArray(creator.traits)), 13, UiTheme.GOLD, true))
	header.add_child(identity)
	add_child(header)

	_activity = UiTheme.label("", 15, UiTheme.GOLD, true)
	add_child(_activity)

	_energy_value = UiTheme.label("", 13)
	_energy = UiTheme.bar(0, Color("4cc9f0"))
	add_child(_need_row("Energy", _energy, _energy_value))
	_mood_value = UiTheme.label("", 13)
	_mood = UiTheme.bar(0, Color("f72585"))
	add_child(_need_row("Mood", _mood, _mood_value))

	add_child(HSeparator.new())
	_followers = UiTheme.label("", 15)
	_subscribers = UiTheme.label("", 15)
	_rate = UiTheme.label("", 15, UiTheme.GOOD)
	_lifetime = UiTheme.label("", 15)
	add_child(UiTheme.row("Followers", _followers))
	add_child(UiTheme.row("Paying subscribers", _subscribers))
	add_child(UiTheme.row("Earning now", _rate))
	add_child(UiTheme.row("Lifetime earnings", _lifetime))

	add_child(HSeparator.new())
	add_child(UiTheme.label("Stats", 16, UiTheme.TEXT))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	for stat_name: String in STAT_ORDER:
		var caption := UiTheme.label(stat_name.capitalize(), 13, UiTheme.MUTED)
		caption.custom_minimum_size = Vector2(96, 0)
		grid.add_child(caption)
		grid.add_child(UiTheme.bar(creator.stat(stat_name), UiTheme.ACCENT, 10))
		var value := UiTheme.label(str(int(creator.stat(stat_name))), 13)
		value.custom_minimum_size = Vector2(26, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
	add_child(grid)

	add_child(HSeparator.new())
	add_child(UiTheme.label("Content she's happy to make", 14, UiTheme.MUTED))
	add_child(UiTheme.label(_content_list(creator.content_accepts), 14, UiTheme.GOOD, true))
	add_child(UiTheme.label("Not for her", 14, UiTheme.MUTED))
	add_child(UiTheme.label(_content_list(creator.content_declines), 14, UiTheme.BAD, true))
	add_child(UiTheme.label("Creators set their own boundaries; you can't override them.", 12, UiTheme.MUTED, true))

	if not creator.bio.is_empty():
		add_child(HSeparator.new())
		add_child(UiTheme.label(creator.bio, 13, UiTheme.TEXT, true))
	refresh()


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null or _activity == null:
		return
	_activity.text = Game.describe_activity(creator)
	_energy.value = creator.energy
	_energy_value.text = "%d" % roundi(creator.energy)
	_mood.value = creator.mood
	_mood_value.text = "%d" % roundi(creator.mood)
	_followers.text = Fmt.compact(creator.followers)
	_subscribers.text = Fmt.compact(creator.subscribers)
	_rate.text = "%s / hr" % Fmt.money(Economy.creator_cash_per_hour(creator, Game.state, Game.config))
	_lifetime.text = Fmt.money(creator.lifetime_earnings)


func _need_row(caption: String, bar: ProgressBar, value: Label) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var cap := UiTheme.label(caption, 14, UiTheme.MUTED)
	cap.custom_minimum_size = Vector2(56, 0)
	h.add_child(cap)
	h.add_child(bar)
	value.custom_minimum_size = Vector2(28, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(value)
	return h


func _content_list(ids: Array) -> String:
	if ids.is_empty():
		return "-"
	var labels := PackedStringArray()
	for content_id in ids:
		labels.append(Game.config.content_label(str(content_id)))
	return ", ".join(labels)
