class_name Applications
extends RefCounted
## Creators applying to live and work in the house. Applicants are data (creators.json templates with
## "applicant": true). Joining costs nothing: she brings her own terms (revenue split), and every
## resident adds ongoing living costs. Some creators only apply once the house meets their
## expectations ("expects": room levels, combined house followers). Accepting needs a free bedroom.
## Her terms only set the revenue split; they never override her content boundaries or body choices.


static func applicant_ids(state: GameState, config: GameConfig) -> Array[String]:
	var ids: Array[String] = []
	for template_id in config.creator_order:
		if bool(config.creator_templates[template_id].get("applicant", false)) and state.get_creator(template_id) == null:
			ids.append(template_id)
	return ids


## What the house still lacks for her to apply: ["Studio Lv 2", "8,000 house followers"]. Empty = she's applied.
static func unmet_expectations(template: Dictionary, state: GameState, config: GameConfig) -> Array[String]:
	var missing: Array[String] = []
	var expects: Dictionary = template.get("expects", {})
	var levels: Dictionary = expects.get("room_levels", {})
	for type_id in levels:
		var needed := int(levels[type_id])
		var best := 0
		for room in state.rooms:
			if room.type_id == str(type_id):
				best = maxi(best, room.level)
		if best < needed:
			missing.append("%s Lv %d" % [config.room_type(str(type_id)).get("name", type_id), needed])
	var followers := float(expects.get("house_followers", 0.0))
	if state.total_followers() < followers:
		missing.append("%s house followers" % Fmt.compact(followers))
	for upgrade_id in expects.get("upgrades", []):
		if not Upgrades.owned(state, str(upgrade_id)):
			missing.append(str(config.upgrade(str(upgrade_id)).get("label", upgrade_id)))
	return missing


## Cash the house must hold before she moves in: reserve_days of running costs including hers.
static func required_reserve(template: Dictionary, state: GameState, config: GameConfig) -> float:
	var daily := Expenses.total_per_day(state, config) + maxf(float(template.get("living_cost_per_day", 0.0)), 0.0) \
		+ config.tuning_f("expenses", "utilities_per_resident", 4.0)
	return roundf(daily * config.tuning_f("applications", "reserve_days", 5.0) / 10.0) * 10.0


static func has_applied(template: Dictionary, state: GameState, config: GameConfig) -> bool:
	return unmet_expectations(template, state, config).is_empty()


## {ok, reason}: whether she can move in right now.
static func check(state: GameState, config: GameConfig, template_id: String) -> Dictionary:
	var template: Dictionary = config.creator_templates.get(template_id, {})
	if template.is_empty() or not bool(template.get("applicant", false)):
		return {"ok": false, "reason": "Unknown applicant"}
	if state.get_creator(template_id) != null:
		return {"ok": false, "reason": "Already lives in the house"}
	var missing := unmet_expectations(template, state, config)
	if not missing.is_empty():
		return {"ok": false, "reason": "She'll apply once the house has: " + ", ".join(missing)}
	var vacancy := Housing.vacancy_problem(state, config)
	if not vacancy.is_empty():
		return {"ok": false, "reason": vacancy}
	var reserve := required_reserve(template, state, config)
	if state.cash < reserve:
		return {"ok": false, "reason": "The house needs %s in the bank (%d days of running costs) before she moves in" % [
			Fmt.money(reserve), roundi(config.tuning_f("applications", "reserve_days", 5.0))]}
	return {"ok": true, "reason": ""}


## Accepts her application: she moves into a free bedroom on her own terms. No money changes hands;
## her living costs start immediately. Returns check()'s result plus "creator" on success.
static func accept(state: GameState, config: GameConfig, template_id: String) -> Dictionary:
	var result := check(state, config, template_id)
	if not bool(result["ok"]):
		return result
	result["creator"] = move_in(state, config, template_id)
	return result


## Moves her into the first free bedroom (callers check eligibility first). Returns the new resident.
static func move_in(state: GameState, config: GameConfig, template_id: String) -> CreatorState:
	var creator := CreatorSetup.create(config.creator_templates[template_id], config, state)
	var bedroom: RoomState = Housing.free_bedrooms(state, config)[0]
	creator.home_room_id = bedroom.id
	creator.room_id = bedroom.id
	creator.position = bedroom.spot_position(0.55)
	state.creators.append(creator)
	Relationships.ensure_all(state, config)
	return creator


## Rough earning potential: {focus, work_per_hour, subscriptions_per_hour, gross_per_day,
## house_per_day, living_per_day, net_per_day, rating (1..5), growth (0..1), creator}.
## Uses current trends and house rooms; she'd earn more as her audience grows.
static func estimate(template: Dictionary, state: GameState, config: GameConfig) -> Dictionary:
	var creator := CreatorSetup.create(template, config, state)
	creator.energy = 100.0
	creator.mood = 75.0
	var free := Housing.free_bedrooms(state, config)
	if not free.is_empty():
		creator.home_room_id = free[0].id
	# Potential: her best-paying content she'd make in this house today (within her boundaries).
	creator.content_focus = ContentRules.valid_focus(creator, state, config)
	var work := 0.0
	for content_id in ContentRules.assignable_ids(config):
		if not ContentRules.can_assign(creator, content_id, state, config):
			continue
		var cash := float(Economy.work_breakdown(creator, state, config, content_id)["cash"])
		if cash > work:
			work = cash
			creator.content_focus = content_id
	var subs := Economy.subscription_cash_per_hour(creator, config)
	var work_hours := lerpf(6.0, 10.0, clampf(creator.stat("work_ethic") / 100.0, 0.0, 1.0))
	var gross_day := work * work_hours + subs * 24.0
	var house_day := gross_day * creator.house_share()
	var added_costs := creator.living_cost_per_day + config.tuning_f("expenses", "utilities_per_resident", 4.0)
	var growth := clampf((creator.stat("adaptability") + creator.stat("charisma") + creator.stat("work_ethic")) / 300.0, 0.0, 1.0)
	var rating := 1
	for threshold: float in [400.0, 1000.0, 2000.0, 3500.0]:
		if gross_day >= threshold:
			rating += 1
	return {
		"focus": creator.content_focus,
		"work_per_hour": work,
		"subscriptions_per_hour": subs,
		"gross_per_day": gross_day,
		"house_per_day": house_day,
		"living_per_day": added_costs,
		"net_per_day": house_day - added_costs,
		"rating": rating,
		"growth": growth,
		"creator": creator,
	}
