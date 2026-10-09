extends RefCounted
## Headless economy simulator for balancing. Plays the real simulation (same Simulation.advance as the
## game) with a scripted player strategy and records finances, audience and milestone times.
##
## Strategies:
##   idle         never buys anything or changes anything
##   casual       checks in every ~6 real minutes: once a day picks the best-paying content the Content
##                tab shows, plays the photoshoot when it's ready (mediocre shots), buys the cheapest thing
##                she can comfortably afford (2-day buffer), and invites housemates when she can
##   upgrades     upgrade-focused: buys the best-paying equipment/renovations first, recruits later
##   recruitment  recruitment-focused: saves for bedrooms and housemates, buys only what applicants expect
##   optimised    picks the best payback among everything every hour, manages content (freshness,
##                trends) and directs the bonus photoshoot whenever it's ready
##
## Time: at 1x speed one real minute is time.game_minutes_per_real_second x 60 game minutes.

const STRATEGIES := ["idle", "casual", "upgrades", "recruitment", "optimised"]
## Housemates' audiences grow after they move in; observed gains are ~2-3x the at-signing estimate.
const RECRUIT_GROWTH_FACTOR := 2.5

var config: GameConfig
var state: GameState
var strategy: String = "idle"
var hour: int = 0
var log: Array = []          # purchases and events: {hour, kind, id, price, payback_days}
var daily: Array = []        # per-day snapshots
var milestones: Dictionary = {}
var min_cash: float = INF
var hours_in_debt: int = 0
var photoshoots: int = 0

var _day_start := {}


func _init(game_config: GameConfig, strategy_name: String, seed: int = 1234) -> void:
	config = game_config
	strategy = strategy_name
	state = GameState.new_game(config, seed)


## Real minutes at 1x speed for a number of game hours.
func real_minutes(game_hours: float) -> float:
	return game_hours * 60.0 / (config.tuning_f("time", "game_minutes_per_real_second", 2.0) * 60.0)


func run(days: int, step_minutes: float = 5.0) -> Dictionary:
	_snapshot_start()
	for h in days * 24:
		hour = h
		_decide()
		Simulation.advance(state, config, 60.0, step_minutes)
		min_cash = minf(min_cash, state.cash)
		if state.cash < 0.0:
			hours_in_debt += 1
		_check_milestones()
		if (h + 1) % 24 == 0:
			_close_day()
	return report()


# ---------------------------------------------------------------------------
# Strategy
# ---------------------------------------------------------------------------

func _decide() -> void:
	match strategy:
		"idle":
			return
		"casual":
			if hour % 24 == 12:
				_manage_content(true)
			if hour % 12 == 0:
				_photoshoot(0.5)
				# Once someone has applied she saves for the bedroom, only buying small things meanwhile.
				var saving := _buy_best(40.0, 2.0, ["recruit"])
				_buy_cheapest(2.0, 0.25 if saving else 1.0)
		"upgrades":
			if hour % 4 == 0:
				if not _buy_best(60.0, 1.0, ["upgrade", "renovation"]):
					_buy_best(40.0, 1.0, ["recruit"])
		"recruitment":
			if hour % 4 == 0:
				if not _buy_best(60.0, 1.0, ["recruit", "expectation"]):
					_buy_best(3.0, 1.0, ["upgrade", "renovation"])
		"optimised":
			_manage_content()
			_photoshoot(0.8)
			_buy_best(45.0, 1.0, ["upgrade", "renovation", "recruit", "expectation"])


## Buys the option with the best payback (days) among `kinds`, if it pays back within max_payback days
## and leaves `buffer_days` of running costs in the bank. Returns true if something was bought.
func _buy_best(max_payback: float, buffer_days: float, kinds: Array) -> bool:
	var buffer := Expenses.total_per_day(state, config) * buffer_days
	var best: Dictionary = {}
	for option: Dictionary in options(kinds):
		if float(option["payback_days"]) > max_payback:
			continue
		if best.is_empty() or float(option["payback_days"]) < float(best["payback_days"]):
			best = option
	if best.is_empty():
		return false
	if state.cash - float(best["price"]) < buffer + float(best.get("reserve", 0.0)):
		return true # saving up for it
	return _apply(best)


## Casual player: the cheapest upgrade or renovation she can afford while keeping a buffer.
func _buy_cheapest(buffer_days: float, max_share_of_cash: float = 1.0) -> bool:
	var buffer := Expenses.total_per_day(state, config) * buffer_days
	var cheapest: Dictionary = {}
	for option: Dictionary in options(["upgrade", "renovation"]):
		if cheapest.is_empty() or float(option["price"]) < float(cheapest["price"]):
			cheapest = option
	if cheapest.is_empty() or state.cash - float(cheapest["price"]) < buffer:
		return false
	if float(cheapest["price"]) > (state.cash - buffer) * max_share_of_cash:
		return false
	return _apply(cheapest)


## Every purchase the player could make now: [{kind, id, price, gain_per_day, payback_days, reserve}].
func options(kinds: Array) -> Array:
	var result: Array = []
	var base := steady_net_per_day(state)
	if kinds.has("upgrade"):
		for upgrade_id in Upgrades.available_ids(state, config):
			if upgrade_id == Upgrades.EXPANSION:
				continue
			var upgrade := config.upgrade(upgrade_id)
			var missing := false
			for required in upgrade.get("requires", []):
				if not Upgrades.owned(state, str(required)):
					missing = true
			if missing:
				continue
			var trial := _clone()
			trial.upgrades.append(upgrade_id)
			Upgrades.refresh(trial, config)
			result.append(_option("upgrade", upgrade_id, float(upgrade["price"]), steady_net_per_day(trial) - base))
	if kinds.has("renovation"):
		for room in state.rooms:
			var cost := RoomUpgrades.upgrade_cost(config, room)
			if cost < 0.0:
				continue
			var trial := _clone()
			trial.get_room(room.id).level += 1
			Upgrades.refresh(trial, config)
			ContentRules.refresh_unlocks(trial, config)
			result.append(_option("renovation", room.id, cost, steady_net_per_day(trial) - base))
	if kinds.has("recruit") or kinds.has("expectation"):
		result.append_array(_recruit_options(kinds, base))
	return result


func _recruit_options(kinds: Array, base: float) -> Array:
	var result: Array = []
	var applied: Array[String] = []
	for template_id in Applications.applicant_ids(state, config):
		var template: Dictionary = config.creator_templates[template_id]
		if Applications.has_applied(template, state, config):
			applied.append(template_id)
		elif kinds.has("expectation"):
			# Buy what's missing for the best-earning applicant (upgrades only; followers come with time).
			for upgrade_id in template.get("expects", {}).get("upgrades", []):
				if not Upgrades.owned(state, str(upgrade_id)) and _requires_met(str(upgrade_id)):
					var gain := float(Applications.estimate(template, state, config)["net_per_day"]) * 0.5
					result.append(_option("upgrade", str(upgrade_id), float(config.upgrade(str(upgrade_id))["price"]), gain))
	if applied.is_empty() or not kinds.has("recruit") and not kinds.has("expectation"):
		return result
	var best_id := ""
	var best_net := -INF
	for template_id in applied:
		var net := float(Applications.estimate(config.creator_templates[template_id], state, config)["net_per_day"])
		if net > best_net:
			best_net = net
			best_id = template_id
	best_net *= RECRUIT_GROWTH_FACTOR
	var template: Dictionary = config.creator_templates[best_id]
	var reserve := Applications.required_reserve(template, state, config)
	if Housing.has_vacancy(state, config):
		var option := _option("recruit", best_id, 0.0, best_net)
		option["reserve"] = reserve
		option["payback_days"] = 0.0 if best_net > 0.0 else INF
		result.append(option)
	elif Housing.free_bedrooms(state, config).is_empty():
		var lots := Housing.buildable_lots(state, config, "bedroom")
		if not lots.is_empty():
			var option := _option("build", lots[0].id, Housing.build_cost(state, config, "bedroom"), best_net)
			option["reserve"] = reserve
			result.append(option)
		elif not Upgrades.owned(state, Upgrades.EXPANSION):
			# The bigger house is worth what the next two housemates would add, minus its rent.
			var nets: Array = []
			for template_id in applied:
				nets.append(float(Applications.estimate(config.creator_templates[template_id], state, config)["net_per_day"]) * RECRUIT_GROWTH_FACTOR)
			nets.sort()
			nets.reverse()
			var gain := float(nets[0]) + (float(nets[1]) if nets.size() > 1 else 0.0) - config.tuning_f("expenses", "rent_expansion", 120.0)
			var option := _option("upgrade", Upgrades.EXPANSION, float(config.upgrade(Upgrades.EXPANSION)["price"]), gain)
			option["reserve"] = reserve
			result.append(option)
	return result


func _requires_met(upgrade_id: String) -> bool:
	for required in config.upgrade(upgrade_id).get("requires", []):
		if not Upgrades.owned(state, str(required)):
			return false
	return true


func _option(kind: String, id: String, price: float, gain: float) -> Dictionary:
	return {"kind": kind, "id": id, "price": price, "gain_per_day": gain,
		"payback_days": price / gain if gain > 0.01 else INF}


func _apply(option: Dictionary) -> bool:
	var ok := false
	match str(option["kind"]):
		"upgrade":
			ok = bool(Upgrades.purchase(state, config, str(option["id"]))["ok"])
		"renovation":
			ok = RoomUpgrades.try_upgrade(state, config, str(option["id"]))
			ContentRules.refresh_unlocks(state, config)
		"build":
			ok = bool(Housing.build(state, config, str(option["id"]), "bedroom")["ok"])
		"recruit":
			ok = bool(Applications.accept(state, config, str(option["id"]))["ok"])
	if ok:
		log.append({"hour": hour, "kind": option["kind"], "id": option["id"], "price": option["price"],
			"payback_days": option["payback_days"], "gain_per_day": option["gain_per_day"]})
	return ok


## Optimised player: keep each creator on her best-paying allowed content (freshness and trends
## included), switching only for a clear gain so experience isn't wasted.
func _manage_content(force: bool = false) -> void:
	if hour % 6 != 0 and not force:
		return
	for creator in state.creators:
		var current := float(Economy.work_breakdown(creator, state, config)["cash"]) if not creator.content_focus.is_empty() else 0.0
		var best_id := creator.content_focus
		var best := current
		for content_id in ContentRules.assignable_ids(config):
			if not ContentRules.can_assign(creator, content_id, state, config):
				continue
			var value := float(Economy.work_breakdown(creator, state, config, content_id)["cash"])
			if value > best * 1.12:
				best = value
				best_id = content_id
		creator.content_focus = best_id


func _photoshoot(quality: float) -> void:
	for creator in state.creators:
		if bool(Photoshoot.check(creator, state, config)["ok"]):
			Photoshoot.complete(creator, state, config, quality)
			photoshoots += 1


# ---------------------------------------------------------------------------
# Estimates
# ---------------------------------------------------------------------------

## Steady-state net profit per day (the game's own Forecast, so the sim and the shop agree).
func steady_net_per_day(s: GameState) -> float:
	return Forecast.steady_net_per_day(s, config)


func _clone() -> GameState:
	var copy := GameState.from_dict(state.to_dict())
	Upgrades.refresh(copy, config)
	return copy


# ---------------------------------------------------------------------------
# Recording
# ---------------------------------------------------------------------------

func _snapshot_start() -> void:
	_day_start = {"gross": state.total_gross_earnings(), "house": state.total_house_earnings(), "expenses": _expenses_total(), "cash": state.cash}


func _expenses_total() -> float:
	var total := 0.0
	for key in state.expense_totals:
		total += float(state.expense_totals[key])
	return total


func _close_day() -> void:
	var gross := state.total_gross_earnings() - float(_day_start["gross"])
	var house := state.total_house_earnings() - float(_day_start["house"])
	var expenses := _expenses_total() - float(_day_start["expenses"])
	daily.append({
		"day": daily.size() + 1, "cash": state.cash, "gross": gross, "house": house, "expenses": expenses,
		"net": house - expenses, "followers": state.total_followers(), "subscribers": state.total_subscribers(),
		"residents": state.creators.size(), "upgrades": state.upgrades.size(),
	})
	_snapshot_start()


func _mark(key: String) -> void:
	if not milestones.has(key):
		milestones[key] = hour + 1


func _check_milestones() -> void:
	var bought := 0
	for entry: Dictionary in log:
		if str(entry["kind"]) in ["upgrade", "renovation"]:
			bought += 1
	if bought >= 1:
		_mark("first_upgrade")
	if bought >= 3:
		_mark("three_upgrades")
	if bought >= 5:
		_mark("five_upgrades")
	if state.creators.size() >= 2:
		_mark("second_creator")
	if Upgrades.owned(state, Upgrades.EXPANSION):
		_mark("house_expansion")
	if state.creators.size() >= 3:
		_mark("third_creator")
	if state.creators.size() >= 4:
		_mark("fourth_creator")
	if not daily.is_empty() and state.creators.size() >= 4 and float(daily[daily.size() - 1]["net"]) >= config.tuning_f("milestones", "established_net_per_day", 3000.0):
		_mark("established")
	for amount in [1000, 5000, 30000, 100000]:
		if state.cash >= amount:
			_mark("cash_%d" % amount)


func report() -> Dictionary:
	return {
		"strategy": strategy, "milestones": milestones, "daily": daily, "log": log,
		"min_cash": min_cash, "hours_in_debt": hours_in_debt, "photoshoots": photoshoots,
		"final_cash": state.cash, "residents": state.creators.size(), "upgrades": state.upgrades.duplicate(),
	}
