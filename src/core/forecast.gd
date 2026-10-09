class_name Forecast
extends RefCounted
## Steady-state money estimates for decisions (upgrade shop, room panel, balancing tools). They answer
## "what would this house earn per day as set up now, and what would a purchase add?" using the same
## formulas as the simulation: each creator's work income over her usual working hours plus
## subscriptions, the house share of that, minus running costs. Never touches the real state.


## Net profit per day for this setup (house shares minus running costs).
static func steady_net_per_day(state: GameState, config: GameConfig) -> float:
	var house := 0.0
	for creator in state.creators:
		var work := 0.0
		if not creator.content_focus.is_empty():
			var saved_energy := creator.energy
			var saved_mood := creator.mood
			creator.energy = 85.0
			creator.mood = 75.0
			work = maxf(float(Economy.work_breakdown(creator, state, config)["cash"]), 0.0)
			creator.energy = saved_energy
			creator.mood = saved_mood
		house += (work * working_hours(creator) + Economy.subscription_cash_per_hour(creator, config) * 24.0) * creator.house_share()
	return house - Expenses.total_per_day(state, config)


## Typical productive hours per day (more for hard workers). Calibrated against the simulation, which
## also earns a little while socialising and grows the audience during the day.
static func working_hours(creator: CreatorState) -> float:
	return lerpf(8.0, 12.0, clampf(creator.stat("work_ethic") / 100.0, 0.0, 1.0))


## {gain_per_day, payback_days} for buying an upgrade (gain already net of its maintenance).
static func upgrade_value(state: GameState, config: GameConfig, upgrade_id: String) -> Dictionary:
	var trial := _copy(state, config)
	trial.upgrades.append(upgrade_id)
	Upgrades.refresh(trial, config)
	return _value(steady_net_per_day(trial, config) - steady_net_per_day(state, config), float(config.upgrade(upgrade_id).get("price", 0.0)))


## {gain_per_day, payback_days} for renovating a room to its next level.
static func renovation_value(state: GameState, config: GameConfig, room_id: String) -> Dictionary:
	var trial := _copy(state, config)
	var room := trial.get_room(room_id)
	var price := RoomUpgrades.upgrade_cost(config, room)
	room.level += 1
	Upgrades.refresh(trial, config)
	ContentRules.refresh_unlocks(trial, config)
	return _value(steady_net_per_day(trial, config) - steady_net_per_day(state, config), price)


static func _value(gain: float, price: float) -> Dictionary:
	return {"gain_per_day": gain, "payback_days": price / gain if gain > 0.01 else INF}


static func _copy(state: GameState, config: GameConfig) -> GameState:
	var copy := GameState.from_dict(state.to_dict())
	Upgrades.refresh(copy, config)
	return copy
