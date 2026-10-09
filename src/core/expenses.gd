class_name Expenses
extends RefCounted
## The house's running costs, all per game day and charged continuously (also while away):
##  - rent: base + per room built on a lot + the bigger-house premium;
##  - utilities & internet: base + per resident;
##  - equipment maintenance: owned upgrades plus renovated room levels' upkeep;
##  - living costs: each resident's food and lifestyle (creators.json).
## Creator revenue shares are not expenses here: they are taken once, when revenue is credited
## (Contracts.credit), so gross, shares and net profit stay separate and never double count.

const KEYS: Array[String] = ["rent", "utilities", "maintenance", "living"]
const LABELS := {"rent": "Rent", "utilities": "Utilities & internet", "maintenance": "Equipment maintenance", "living": "Residents' living costs"}


## {rent, utilities, maintenance, living, total} per game day.
static func per_day(state: GameState, config: GameConfig) -> Dictionary:
	var rent := config.tuning_f("expenses", "rent_per_day", 30.0) + config.tuning_f("expenses", "rent_per_built_room", 20.0) * state.rooms_built
	if Upgrades.owned(state, Upgrades.EXPANSION):
		rent += config.tuning_f("expenses", "rent_expansion", 120.0)
	var utilities := config.tuning_f("expenses", "utilities_per_day", 8.0) + config.tuning_f("expenses", "utilities_per_resident", 4.0) * state.creators.size()
	var maintenance := Upgrades.maintenance_per_day(state, config) + room_upkeep_per_day(state, config)
	var living := state.living_cost_per_day()
	return {"rent": rent, "utilities": utilities, "maintenance": maintenance, "living": living,
		"total": rent + utilities + maintenance + living}


static func total_per_day(state: GameState, config: GameConfig) -> float:
	return float(per_day(state, config)["total"])


static func room_upkeep_per_day(state: GameState, config: GameConfig) -> float:
	var total := 0.0
	for room in state.rooms:
		total += float(config.room_level_def(room.type_id, room.level).get("upkeep_per_day", 0.0))
	return total


## Charges `minutes` of running costs. Returns the amount charged (per-key totals are kept on the state,
## residents' living costs also on each creator).
static func charge(state: GameState, config: GameConfig, minutes: float) -> float:
	var fraction := minutes / GameState.MINUTES_PER_DAY
	var costs := per_day(state, config)
	var charged := 0.0
	for key in KEYS:
		var amount := float(costs[key]) * fraction
		state.expense_totals[key] = float(state.expense_totals.get(key, 0.0)) + amount
		state.record(key, amount)
		charged += amount
	for creator in state.creators:
		var living := creator.living_cost_per_day * fraction
		creator.living_costs_paid += living
		state.living_costs += living
	state.cash -= charged
	return charged


## True while the house can't pay its bills (cash below zero).
static func in_debt(state: GameState) -> bool:
	return state.cash < 0.0
