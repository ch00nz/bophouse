class_name CreatorProfileSection
extends VBoxContainer
## Profile tab: needs, audience, all core stats (with tooltips) and bio.

const STAT_ORDER := ["looks", "wildness", "adaptability", "charisma", "work_ethic", "stamina", "confidence", "drama"]

var creator_id: String = ""

var _energy: ProgressBar
var _energy_value: Label
var _mood: ProgressBar
var _mood_value: Label
var _productivity: Label
var _followers: Label
var _subscribers: Label
var _rate: Label
var _lifetime: Label


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
	var config := Game.config

	add_child(UiTheme.header("Wellbeing"))
	_energy_value = UiTheme.value_label()
	_energy = UiTheme.bar(0, Color("4cc9f0"))
	add_child(UiTheme.tip(_need_row("Energy", _energy, _energy_value),
		"Energy drains while working and recovers while sleeping. Low energy lowers productivity, and she stops to rest."))
	_mood_value = UiTheme.value_label()
	_mood = UiTheme.bar(0, Color("f72585"))
	add_child(UiTheme.tip(_need_row("Mood", _mood, _mood_value),
		"Mood dips while working and lifts while socialising. Content she loves is less draining."))
	_productivity = UiTheme.label("", 13, UiTheme.MUTED)
	add_child(UiTheme.tip(_productivity, "Combined effect of energy and mood on everything she produces."))

	add_child(HSeparator.new())
	add_child(UiTheme.header("Audience"))
	_followers = UiTheme.value_label()
	_subscribers = UiTheme.value_label()
	_rate = UiTheme.value_label("", UiTheme.GOOD)
	_lifetime = UiTheme.value_label()
	add_child(UiTheme.tip(UiTheme.row("Followers", _followers), "Public reach. Drives audience earnings and the subscriber pool."))
	add_child(UiTheme.tip(UiTheme.row("Paying subscribers", _subscribers), "Paying fans. Their subscriptions pay out around the clock."))
	add_child(UiTheme.tip(UiTheme.row("Earning now", _rate), "Current hourly income including subscriptions. See the Income tab for details."))
	add_child(UiTheme.row("Lifetime earnings", _lifetime))

	add_child(HSeparator.new())
	add_child(UiTheme.header("Stats"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	for stat_id: String in STAT_ORDER:
		var description := str(config.stat_defs.get(stat_id, {}).get("description", ""))
		var caption := UiTheme.label(config.stat_label(stat_id), 13, UiTheme.MUTED)
		caption.custom_minimum_size = Vector2(96, 0)
		grid.add_child(UiTheme.tip(caption, description))
		grid.add_child(UiTheme.tip(UiTheme.bar(creator.stat(stat_id), _stat_color(creator.stat(stat_id)), 10), description))
		var value := UiTheme.value_label(str(int(creator.stat(stat_id))), UiTheme.TEXT, 13)
		value.custom_minimum_size = Vector2(26, 0)
		grid.add_child(value)
	add_child(grid)

	if not creator.bio.is_empty():
		add_child(HSeparator.new())
		add_child(UiTheme.label(creator.bio, 13, UiTheme.TEXT, true))
	refresh()


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null or _energy == null:
		return
	_energy.value = creator.energy
	_energy_value.text = "%d" % roundi(creator.energy)
	_mood.value = creator.mood
	_mood_value.text = "%d" % roundi(creator.mood)
	_productivity.text = "Productivity: %d%%" % roundi(Economy.productivity(creator, Game.config) * 100.0)
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
	h.add_child(value)
	return h


func _stat_color(value: float) -> Color:
	if value >= 65.0:
		return UiTheme.GOOD.darkened(0.1)
	if value >= 45.0:
		return UiTheme.ACCENT
	return UiTheme.GOLD.darkened(0.15)
