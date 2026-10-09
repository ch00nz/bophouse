class_name TrendsPanel
extends VBoxContainer
## Sidebar panel listing active trends, the forecast, and what they mean for each creator.

signal navigate(kind: String, id: String)

var _countdowns: Dictionary = {}   # trend_id -> Label
var _advice: Dictionary = {}       # creator_id -> Label
var _shown_ids: Array[String] = []


func _init() -> void:
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	_build()
	Game.trends_changed.connect(_on_trends_changed)


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_countdowns.clear()
	_advice.clear()
	var state := Game.state
	_shown_ids = TrendSystem.active_ids(state)

	var back := Button.new()
	back.text = "< House overview"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: navigate.emit("overview", ""))
	add_child(back)
	add_child(UiTheme.label("Social Media Trends", 22))
	add_child(UiTheme.label("Trends rotate every day or two. Content that matches a trend earns more, and creators with the favoured stats and high adaptability ride it hardest.", 12, UiTheme.MUTED, true))

	add_child(UiTheme.header("Trending now"))
	for entry: Dictionary in state.active_trends:
		add_child(_trend_card(str(entry["id"]), true))

	add_child(UiTheme.header("Coming next"))
	add_child(_trend_card(state.next_trend_id, false))

	add_child(HSeparator.new())
	add_child(UiTheme.header("Strategy"))
	for creator in state.creators:
		var advice := UiTheme.label("", 13, UiTheme.TEXT, true)
		add_child(advice)
		_advice[creator.id] = advice
		var go := Button.new()
		go.text = "Change %s's content" % ContentRules.first_name(creator)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var creator_id := creator.id
		go.pressed.connect(func() -> void: navigate.emit("creator_content", creator_id))
		add_child(go)
	refresh()


func refresh() -> void:
	var state := Game.state
	for entry: Dictionary in state.active_trends:
		var trend_id := str(entry["id"])
		if _countdowns.has(trend_id):
			(_countdowns[trend_id] as Label).text = "ends in " + Fmt.game_duration(float(entry["remaining_minutes"]))
	for creator_id: String in _advice:
		var creator := state.get_creator(creator_id)
		if creator != null:
			(_advice[creator_id] as Label).text = _advice_text(creator)


func _trend_card(trend_id: String, active: bool) -> Control:
	var config := Game.config
	var trend := config.trend(trend_id)
	var card := UiTheme.card(UiTheme.PANEL_LIGHT if active else UiTheme.PANEL_LIGHT.darkened(0.3),
		UiTheme.GOLD.darkened(0.2) if active else Color.TRANSPARENT)
	var body: VBoxContainer = card.get_child(0)
	var title_row := HBoxContainer.new()
	var title := UiTheme.label(str(trend.get("name", trend_id)), 16, UiTheme.GOLD if active else UiTheme.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	if active:
		var countdown := UiTheme.label("", 12, UiTheme.MUTED)
		countdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiTheme.tip(countdown, "In-game time. At 1x speed a game day is about 12 real minutes.")
		title_row.add_child(countdown)
		_countdowns[trend_id] = countdown
	body.add_child(title_row)
	body.add_child(UiTheme.label(str(trend.get("description", "")), 12, UiTheme.TEXT, true))

	var boosts := PackedStringArray()
	var content: Dictionary = trend.get("content", {})
	for content_id in content:
		var strength := float(content[content_id])
		boosts.append("%s%s" % [config.content_label(str(content_id)), "" if strength >= 0.99 else " (partly)"])
	body.add_child(UiTheme.label("Boosts: " + ", ".join(boosts), 12, UiTheme.GOOD, true))
	var stat_names := PackedStringArray()
	for stat_id in trend.get("stats", []):
		stat_names.append(config.stat_label(str(stat_id)))
	body.add_child(UiTheme.label("Favours: " + ", ".join(stat_names), 12, UiTheme.MUTED, true))
	body.add_child(UiTheme.label("Up to %s income, %s followers" % [
		Fmt.percent_change(float(trend.get("income", 1.0))), Fmt.percent_change(float(trend.get("followers", 1.0)))], 12, UiTheme.MUTED))
	return card


func _advice_text(creator: CreatorState) -> String:
	var config := Game.config
	var state := Game.state
	var best_cash_id := ""
	var best_cash := -1.0
	var best_growth_id := ""
	var best_growth := -1.0
	for content_id in ContentRules.assignable_ids(config):
		if not ContentRules.can_assign(creator, content_id, state, config):
			continue
		var b := Economy.work_breakdown(creator, state, config, content_id)
		if float(b["cash"]) > best_cash:
			best_cash = float(b["cash"])
			best_cash_id = content_id
		if float(b["followers"]) > best_growth:
			best_growth = float(b["followers"])
			best_growth_id = content_id
	var first_name := ContentRules.first_name(creator)
	var current := Economy.work_breakdown(creator, state, config)
	var lines := PackedStringArray()
	lines.append("%s is making %s: ~%s/hr." % [first_name, config.content_label(creator.content_focus), Fmt.money(float(current["cash"]))])
	if not best_cash_id.is_empty() and best_cash_id != creator.content_focus:
		lines.append("Best earner right now: %s (~%s/hr)." % [config.content_label(best_cash_id), Fmt.money(best_cash)])
	if not best_growth_id.is_empty() and best_growth_id != creator.content_focus:
		lines.append("Fastest growth: %s (+%s followers/hr)." % [config.content_label(best_growth_id), Fmt.compact(best_growth)])
	if lines.size() == 1:
		lines.append("That's already her best option on both earnings and growth.")
	lines.append("(Switching costs some experience at first.)")
	return "\n".join(lines)


func _on_trends_changed(_started: Array) -> void:
	if TrendSystem.active_ids(Game.state) != _shown_ids:
		_build()
