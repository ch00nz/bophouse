class_name DevPanel
extends PanelContainer
## Developer-only economy panel (debug builds only, toggle with F9): advance game time through the real
## simulation, adjust cash, and inspect every number behind the economy (per-creator multipliers,
## audience growth and churn, freshness, running costs, forecast). Never available in release exports.

var _text: Label
var _timer: float = 0.0


static func enabled() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	visible = false
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -330.0
	offset_right = 330.0
	offset_top = 108.0
	offset_bottom = 640.0
	add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.05, 0.08, 0.95), 10, 10, Color("4cc9f0"), 2))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	column.add_child(UiTheme.label("DEV: economy inspector (F9)", 14, Color("4cc9f0")))
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 4)
	buttons.add_theme_constant_override("v_separation", 4)
	for entry: Array in [["+1 hour", 60.0], ["+6 hours", 360.0], ["+1 day", 1440.0], ["+7 days", 10080.0]]:
		var b := Button.new()
		b.text = str(entry[0])
		var minutes := float(entry[1])
		b.pressed.connect(func() -> void: Game.dev_advance(minutes))
		buttons.add_child(b)
	for amount: float in [1000.0, 10000.0, -1000.0]:
		var b := Button.new()
		b.text = "%s%s" % ["+" if amount > 0.0 else "", Fmt.money(amount)]
		b.pressed.connect(func() -> void: Game.dev_add_cash(amount))
		buttons.add_child(b)
	column.add_child(buttons)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_text = UiTheme.label("", 11, UiTheme.TEXT, true)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_text)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F9:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer >= 0.5:
		_timer = 0.0
		_text.text = inspect(Game.state, Game.config)


## Plain-text dump of the economy (also handy from scripts).
static func inspect(state: GameState, config: GameConfig) -> String:
	var lines := PackedStringArray()
	var costs := Expenses.per_day(state, config)
	lines.append("%s  cash %s  forecast net %s/day  in debt: %s" % [Fmt.clock(state), Fmt.money(state.cash), Fmt.money(Forecast.steady_net_per_day(state, config)), str(Expenses.in_debt(state))])
	lines.append("costs/day: rent %.0f  utilities %.0f  maintenance %.0f  living %.0f  = %.0f" % [costs["rent"], costs["utilities"], costs["maintenance"], costs["living"], costs["total"]])
	lines.append("yesterday: %s" % JSON.stringify(state.yesterday))
	lines.append("upgrades: %s" % ", ".join(PackedStringArray(state.upgrades)))
	for creator in state.creators:
		var b := Economy.work_breakdown(creator, state, config)
		var m: Dictionary = b["multipliers"]
		lines.append("\n%s  [%s in %s]  share %d%%  E%d M%d  %s" % [creator.first_name(), b["content_id"], b["room_id"], roundi(creator.creator_share() * 100.0),
			roundi(creator.energy), roundi(creator.mood), Game.describe_activity(creator)])
		lines.append("  work gross %.2f/hr (sales %.2f + audience %.2f + custom %.2f - fees %.2f)  subs %.2f/hr" % [b["cash"], b["content_sales"], b["audience_earnings"], b["custom_sales"], b["fees"], b["subscriptions"]])
		var parts := PackedStringArray()
		for key in m:
			parts.append("%s %.2f" % [key, float(m[key])])
		lines.append("  x " + ", ".join(parts))
		lines.append("  followers %.0f (+%.1f/hr working, -%.1f/hr unfollows)  subs %.1f (target %.1f, %+.2f/hr, churn -%.2f/hr, unhappy -%.2f/hr)" % [
			creator.followers, b["followers"], Economy.follower_decay_per_hour(creator, config), creator.subscribers, b["target_subscribers"], b["subscribers"],
			Economy.subscriber_base_churn_per_hour(creator, config), AudienceModel.unhappy_churn_per_hour(creator, config)])
		lines.append("  freshness %s  lifetime gross %s  to house %s" % [JSON.stringify(creator.content_freshness), Fmt.money(creator.lifetime_earnings), Fmt.money(creator.house_earnings)])
	return "\n".join(lines)
