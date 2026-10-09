class_name FinancesPanel
extends Overlay
## House finances: where every dollar came from and went. Yesterday and today (so far) side by side:
## gross revenue, creators' shares, the house share, each running cost and net profit; today's cost
## rates with explanations; each creator's contribution; lifetime totals and investments.

var _days: GridContainer
var _costs: VBoxContainer
var _creators: GridContainer
var _lifetime: Label
var _warning: Label
var _timer: float = 0.0


func _build() -> void:
	set_title("House finances")
	_warning = UiTheme.label("", 14, UiTheme.BAD, true)
	body.add_child(_warning)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)

	var left := Overlay.scroll_column(columns, 8)
	left.add_child(UiTheme.header("Money in and out"))
	_days = GridContainer.new()
	_days.columns = 3
	_days.add_theme_constant_override("h_separation", 24)
	_days.add_theme_constant_override("v_separation", 4)
	left.add_child(_days)
	left.add_child(UiTheme.label("Creators keep their agreed share of what they earn; only the house share reaches your cash. Running costs are charged continuously, including while you're away.", 11, UiTheme.MUTED, true))
	left.add_child(HSeparator.new())
	left.add_child(UiTheme.header("Running costs per day (current)"))
	_costs = VBoxContainer.new()
	_costs.add_theme_constant_override("separation", 3)
	left.add_child(_costs)

	var right := Overlay.scroll_column(columns, 8)
	right.add_child(UiTheme.header("Each creator right now"))
	_creators = GridContainer.new()
	_creators.columns = 5
	_creators.add_theme_constant_override("h_separation", 16)
	_creators.add_theme_constant_override("v_separation", 4)
	right.add_child(_creators)
	right.add_child(HSeparator.new())
	right.add_child(UiTheme.header("Lifetime"))
	_lifetime = UiTheme.label("", 13, UiTheme.TEXT, true)
	right.add_child(_lifetime)
	_refresh()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= 0.5:
		_timer = 0.0
		_refresh()


func _refresh() -> void:
	var state := Game.state
	var config := Game.config
	_warning.visible = Expenses.in_debt(state)
	_warning.text = "Behind on bills! The house is %s in the red: purchases are on hold and residents are stressed until it's paid off." % Fmt.money(-state.cash)

	_clear(_days)
	for cell in ["", "Yesterday", "Today so far"]:
		_days.add_child(UiTheme.label(cell, 12, UiTheme.MUTED))
	var rows := [
		["Creators' gross revenue", "gross", 1.0, UiTheme.TEXT],
		["  Creators' shares", "creators", -1.0, UiTheme.MUTED],
		["House share", "house", 1.0, UiTheme.GOOD],
	]
	for key in Expenses.KEYS:
		rows.append(["  " + str(Expenses.LABELS[key]), key, -1.0, UiTheme.BAD])
	for row: Array in rows:
		_days.add_child(UiTheme.label(str(row[0]), 13, row[3]))
		for day: Dictionary in [state.yesterday, state.today]:
			var value := float(day.get(str(row[1]), 0.0)) * float(row[2])
			_days.add_child(UiTheme.value_label(Fmt.money(value), row[3], 13))
	_days.add_child(UiTheme.label("Net profit", 14, UiTheme.GOLD))
	for day: Dictionary in [state.yesterday, state.today]:
		var net := float(day.get("house", 0.0))
		for key in Expenses.KEYS:
			net -= float(day.get(key, 0.0))
		_days.add_child(UiTheme.value_label(Fmt.money(net), UiTheme.GOOD if net >= 0.0 else UiTheme.BAD, 14))

	_clear(_costs)
	var costs := Expenses.per_day(state, config)
	var explain := {
		"rent": "Base rent %s, +%s per bedroom built%s." % [Fmt.money(config.tuning_f("expenses", "rent_per_day", 0.0)), Fmt.money(config.tuning_f("expenses", "rent_per_built_room", 0.0)),
			", + bigger-house premium" if Upgrades.owned(state, Upgrades.EXPANSION) else ""],
		"utilities": "Internet, power and water: %s + %s per resident." % [Fmt.money(config.tuning_f("expenses", "utilities_per_day", 0.0)), Fmt.money(config.tuning_f("expenses", "utilities_per_resident", 0.0))],
		"maintenance": "Equipment %s + renovated rooms %s." % [Fmt.money(Upgrades.maintenance_per_day(state, config)), Fmt.money(Expenses.room_upkeep_per_day(state, config))],
		"living": "Each housemate's food and lifestyle (the founder's are covered).",
	}
	for key in Expenses.KEYS:
		_costs.add_child(UiTheme.tip(UiTheme.row(str(Expenses.LABELS[key]), UiTheme.value_label("%s/day" % Fmt.money(float(costs[key])), UiTheme.BAD, 13)), str(explain[key])))
		_costs.add_child(UiTheme.label(str(explain[key]), 11, UiTheme.MUTED, true))
	_costs.add_child(UiTheme.row("Total", UiTheme.value_label("%s/day" % Fmt.money(float(costs["total"])), UiTheme.GOLD, 14)))
	_costs.add_child(UiTheme.row("Estimated net profit", UiTheme.value_label("%s/day" % Fmt.money(Forecast.steady_net_per_day(state, config)), UiTheme.GOOD, 14)))

	_clear(_creators)
	for cell in ["", "Gross/hr", "House/hr", "Living/day", "Lifetime to house"]:
		_creators.add_child(UiTheme.label(cell, 12, UiTheme.MUTED))
	for creator in state.creators:
		var gross := Economy.creator_cash_per_hour(creator, state, config)
		_creators.add_child(UiTheme.label("%s (%s)" % [creator.first_name(), Contracts.split_text(creator.creator_share())], 13))
		_creators.add_child(UiTheme.value_label(Fmt.money(gross), UiTheme.TEXT, 13))
		_creators.add_child(UiTheme.value_label(Fmt.money(gross * creator.house_share()), UiTheme.GOOD, 13))
		_creators.add_child(UiTheme.value_label(Fmt.money(creator.living_cost_per_day), UiTheme.BAD, 13))
		_creators.add_child(UiTheme.value_label(Fmt.money(creator.house_earnings), UiTheme.TEXT, 13))

	var spent := 0.0
	var lines := PackedStringArray()
	lines.append("Creators' gross revenue: %s  (house share %s)" % [Fmt.money(state.total_gross_earnings()), Fmt.money(state.total_house_earnings())])
	for key in Expenses.KEYS:
		lines.append("%s: %s" % [Expenses.LABELS[key], Fmt.money(float(state.expense_totals.get(key, 0.0)))])
	var invest := {"upgrades": "Equipment & upgrades", "renovations": "Renovations", "makeovers": "Makeovers & procedures"}
	for key: String in invest:
		var amount := float(state.spending.get(key, 0.0))
		spent += amount
		lines.append("%s: %s" % [invest[key], Fmt.money(amount)])
	lines.append("Bedrooms built: %s" % Fmt.money(state.build_costs))
	spent += state.build_costs
	var costs_paid := 0.0
	for key in Expenses.KEYS:
		costs_paid += float(state.expense_totals.get(key, 0.0))
	lines.append("\nOperating profit (house share - running costs): %s" % Fmt.money(state.total_house_earnings() - costs_paid))
	lines.append("Invested in the house: %s" % Fmt.money(spent))
	_lifetime.text = "\n".join(lines)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
