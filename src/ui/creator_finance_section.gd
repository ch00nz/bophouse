class_name CreatorFinanceSection
extends VBoxContainer
## Finances tab: her terms and revenue split, living costs, lifetime gross / her share / house share, audience
## growth since she joined, fanbase loyalty (who her subscribers are and whether they like her current
## look), then the detailed income breakdown.

var creator_id: String = ""

var _rate_gross: Label
var _rate_house: Label
var _gross: Label
var _hers: Label
var _house: Label
var _living: Label
var _growth_followers: Label
var _growth_subs: Label
var _churn: Label
var _fans: VBoxContainer
var _fan_rows: Array = []
var _income: CreatorIncomeSection


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 6)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
	var contract := creator.contract

	var card := UiTheme.card()
	var c: VBoxContainer = card.get_child(0)
	c.add_child(UiTheme.header("Her terms"))
	c.add_child(UiTheme.label("%s  -  %s split (her / house)" % [str(contract.get("label", "Revenue share")), Contracts.split_text(creator.creator_share())], 15, UiTheme.GOLD, true))
	var joined := "Living here since day %d" % int(contract.get("joined_day", creator.joined_day))
	c.add_child(UiTheme.label(joined + ". Only the house share reaches your cash. Her terms never override her boundaries.", 12, UiTheme.MUTED, true))
	c.add_child(UiTheme.tip(UiTheme.row("Living costs", UiTheme.value_label("%s/day" % Fmt.money(creator.living_cost_per_day), UiTheme.BAD if creator.living_cost_per_day > 0.0 else UiTheme.MUTED)),
		"Her share of rent, utilities, food and lifestyle, paid by the house."))
	_rate_gross = UiTheme.value_label()
	_rate_house = UiTheme.value_label("", UiTheme.GOOD)
	c.add_child(UiTheme.tip(UiTheme.row("Earning now (gross)", _rate_gross), "Everything she's making per hour before the split."))
	c.add_child(UiTheme.tip(UiTheme.row("House share now", _rate_house), "What you receive per hour from her right now."))
	add_child(card)

	var ledger := UiTheme.card()
	var l: VBoxContainer = ledger.get_child(0)
	l.add_child(UiTheme.header("Lifetime"))
	_gross = UiTheme.value_label()
	_hers = UiTheme.value_label()
	_house = UiTheme.value_label("", UiTheme.GOOD)
	l.add_child(UiTheme.row("Gross revenue", _gross))
	l.add_child(UiTheme.row("Her share", _hers))
	l.add_child(UiTheme.row("House share", _house))
	_living = UiTheme.value_label("", UiTheme.BAD)
	l.add_child(UiTheme.row("Living costs paid", _living))
	_growth_followers = UiTheme.value_label()
	_growth_subs = UiTheme.value_label()
	l.add_child(UiTheme.row("Follower growth since joining", _growth_followers))
	l.add_child(UiTheme.row("Subscriber growth since joining", _growth_subs))
	add_child(ledger)

	var loyalty := UiTheme.card()
	var f: VBoxContainer = loyalty.get_child(0)
	f.add_child(UiTheme.header("Her fanbase"))
	f.add_child(UiTheme.label("Who her paying subscribers are, how much they like her current look, and where the mix is drifting. Changes are gradual: new fans arrive while she works, unhappy ones slowly cancel.", 11, UiTheme.MUTED, true))
	_fans = VBoxContainer.new()
	_fans.add_theme_constant_override("separation", 2)
	f.add_child(_fans)
	for i in 5:
		var row := UiTheme.row("", UiTheme.value_label("", UiTheme.TEXT, 12))
		_fan_rows.append(row)
		_fans.add_child(UiTheme.tip(row, ""))
	_churn = UiTheme.label("", 12, UiTheme.MUTED, true)
	f.add_child(_churn)
	add_child(loyalty)

	add_child(HSeparator.new())
	_income = CreatorIncomeSection.new(creator_id)
	add_child(_income)
	refresh()


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null or _gross == null:
		return
	var state := Game.state
	var config := Game.config
	var gross_rate := Economy.creator_cash_per_hour(creator, state, config)
	_rate_gross.text = "%s/hr" % Fmt.money(gross_rate)
	_rate_house.text = "%s/hr (%d%%), %s/hr after living costs" % [Fmt.money(gross_rate * creator.house_share()), roundi(creator.house_share() * 100.0),
		Fmt.money(gross_rate * creator.house_share() - creator.living_cost_per_day / 24.0)]
	_gross.text = Fmt.money(creator.lifetime_earnings)
	_hers.text = Fmt.money(creator.creator_earnings)
	_house.text = Fmt.money(creator.house_earnings)
	_living.text = "-" + Fmt.money(creator.living_costs_paid)
	_growth_followers.text = "%s%s" % ["+" if creator.followers >= creator.joined_followers else "", Fmt.compact(creator.followers - creator.joined_followers)]
	_growth_subs.text = "%s%s" % ["+" if creator.subscribers >= creator.joined_subscribers else "", Fmt.compact(creator.subscribers - creator.joined_subscribers)]
	var rows := AudienceModel.fan_breakdown(creator, config)
	for i in _fan_rows.size():
		var row: HBoxContainer = _fan_rows[i]
		row.visible = i < rows.size() and float(rows[i]["share"]) >= 0.01
		if not row.visible:
			continue
		var data: Dictionary = rows[i]
		var satisfaction := float(data["satisfaction"])
		var trend := float(data["target"]) - float(data["share"])
		var arrow := "growing" if trend > 0.01 else ("shrinking" if trend < -0.01 else "steady")
		(row.get_child(0) as Label).text = str(data["name"])
		var value: Label = row.get_child(1)
		value.text = "%d%%  |  likes her x%.1f  |  %s" % [roundi(float(data["share"]) * 100.0), satisfaction, arrow]
		value.add_theme_color_override("font_color", UiTheme.GOOD if satisfaction > 1.05 else (UiTheme.BAD if satisfaction < 0.95 else UiTheme.TEXT))
		row.get_parent().tooltip_text = "Spend x%.1f per subscriber. Drifting toward %d%% of her fans for her current look and content." % [float(data["spend"]), roundi(float(data["target"]) * 100.0)]
	var churn := AudienceModel.unhappy_churn_per_hour(creator, config)
	var unhappiness := AudienceModel.unhappiness(creator, config)
	if churn >= 0.01:
		_churn.text = "%d%% of her fans dislike her current look: about %.1f subscribers cancel per hour." % [roundi(unhappiness * 100.0), churn]
		_churn.add_theme_color_override("font_color", UiTheme.BAD)
	else:
		_churn.text = "Her fans are happy with her look. Fan value x%.2f." % AudienceModel.fan_value(creator, config)
		_churn.add_theme_color_override("font_color", UiTheme.GOOD)
	_income.refresh()
