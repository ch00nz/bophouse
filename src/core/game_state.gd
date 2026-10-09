class_name GameState
extends RefCounted
## The complete mutable world state. Serialisable, render-agnostic.

const MINUTES_PER_DAY := 1440.0

var cash: float = 0.0
var game_minutes: float = 0.0
var lifetime_earnings: float = 0.0
## High-water mark of real-world unix time this save has seen. Guards offline progress
## against clock manipulation: moving the clock backwards never earns anything twice.
var last_seen_unix: float = 0.0
var creators: Array[CreatorState] = []
var rooms: Array[RoomState] = []
## Content categories the house has unlocked (e.g. livestreaming once the studio has the gear).
var unlocked_content: Array = []

## Trend state, managed by TrendSystem.
## active_trends: [{id, remaining_minutes, duration_minutes}]
var active_trends: Array = []
var next_trend_id: String = ""
var trend_rng_seed: int = 0
var trend_rng_state: int = 0

## House finances beyond creator revenue (which each creator's ledger tracks).
## living_costs: running costs paid for residents so far; build_costs: rooms built on empty lots.
var living_costs: float = 0.0
## Running costs paid so far by kind (Expenses.KEYS: rent, utilities, maintenance, living).
var expense_totals: Dictionary = {}
## One-off investments so far: {upgrades, renovations, makeovers} (bedroom builds are build_costs).
var spending: Dictionary = {}
## Owned equipment / business upgrade ids (data/upgrades.json).
var upgrades: Array = []
## Money moved today so far and during the last full day: {gross, house, creators, rent, utilities,
## maintenance, living}. Shown in the finances UI so every deduction is visible.
var today: Dictionary = {}
var yesterday: Dictionary = {}
var build_costs: float = 0.0
## Rooms built on empty lots so far (each new build costs more).
var rooms_built: int = 0

## Housemate relationships: pair key "a|b" (sorted ids) -> {friendship, trust, rivalry}.
var relationships: Dictionary = {}
## Minutes each co-located pair has spent together since their last interaction (pair key -> minutes).
var social_timers: Dictionary = {}
## Recent social interactions, oldest first: [{minute, a, b, id, text}].
var social_log: Array = []
var social_rng_seed: int = 0
var social_rng_state: int = 0

## Player preferences that belong with the save (e.g. {"imperial": false}).
var settings: Dictionary = {}


## `seed` makes trend rolls reproducible (tests); 0 picks a random seed.
static func new_game(config: GameConfig, seed: int = 0) -> GameState:
	var state := GameState.new()
	state.trend_rng_seed = seed if seed != 0 else randi() + 1
	state.social_rng_seed = state.trend_rng_seed + 7919
	state.cash = config.tuning_f("economy", "starting_cash", 0.0)
	state.game_minutes = config.tuning_f("time", "start_minute_of_day", 480.0)
	state.ensure_layout_rooms(config)
	var starting: Array = config.balance.get("starting_creators", [])
	for creator_id in starting:
		var template: Dictionary = config.creator_templates.get(str(creator_id), {})
		if template.is_empty():
			push_warning("GameState: unknown starting creator '%s'" % creator_id)
			continue
		var creator := CreatorSetup.create(template, config, state)
		var bedroom := state.first_room_of_type("bedroom")
		if bedroom != null:
			creator.room_id = bedroom.id
			creator.position = bedroom.spot_position(0.7)
		state.creators.append(creator)
	RoomPlanner.assign_home_rooms(state, config)
	Relationships.ensure_all(state, config)
	Upgrades.refresh(state, config)
	ContentRules.refresh_unlocks(state, config)
	TrendSystem.ensure_initialized(state, config)
	return state


## Adds any layout room missing from this state (matched by id). New games get the whole layout;
## older saves gain new lots without touching rooms they already have (or their upgrades).
func ensure_layout_rooms(config: GameConfig) -> void:
	for slot in config.house_layout:
		var slot_id := str(slot.get("id", ""))
		if slot_id.is_empty() or get_room(slot_id) != null:
			continue
		if bool(slot.get("requires_expansion", false)) and not upgrades.has(Upgrades.EXPANSION):
			continue
		var room := RoomState.create(slot_id, str(slot.get("type", "")),
			int(slot.get("storey", 0)), int(slot.get("column", 0)), int(slot.get("width", 1)))
		if not _overlaps(room):
			rooms.append(room)


func _overlaps(candidate: RoomState) -> bool:
	for room in rooms:
		if room.storey == candidate.storey and room.column < candidate.column + candidate.width 				and candidate.column < room.column + room.width:
			return true
	return false


func get_room(room_id: String) -> RoomState:
	for room in rooms:
		if room.id == room_id:
			return room
	return null


func first_room_of_type(type_id: String) -> RoomState:
	for room in rooms:
		if room.type_id == type_id:
			return room
	return null


func get_creator(creator_id: String) -> CreatorState:
	for creator in creators:
		if creator.id == creator_id:
			return creator
	return null


func occupants_of(room_id: String) -> Array[CreatorState]:
	var result: Array[CreatorState] = []
	for creator in creators:
		if creator.occupied_room_id() == room_id:
			result.append(creator)
	return result


func total_followers() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.followers
	return total


func total_subscribers() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.subscribers
	return total


## House share of all revenue ever earned (before living and build costs).
func total_house_earnings() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.house_earnings
	return total


func total_gross_earnings() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.lifetime_earnings
	return total


## Adds to today's money record.
func record(key: String, amount: float) -> void:
	today[key] = float(today.get(key, 0.0)) + amount


## Combined living costs of every resident, per game day.
func living_cost_per_day() -> float:
	var total := 0.0
	for creator in creators:
		total += creator.living_cost_per_day
	return total


func day() -> int:
	return int(game_minutes / MINUTES_PER_DAY) + 1


func hour_of_day() -> int:
	return int(fmod(game_minutes, MINUTES_PER_DAY) / 60.0)


func minute_of_hour() -> int:
	return int(fmod(game_minutes, 60.0))


func to_dict() -> Dictionary:
	var creator_data: Array = []
	for creator in creators:
		creator_data.append(creator.to_dict())
	var room_data: Array = []
	for room in rooms:
		room_data.append(room.to_dict())
	return {
		"cash": cash,
		"game_minutes": game_minutes,
		"lifetime_earnings": lifetime_earnings,
		"last_seen_unix": last_seen_unix,
		"creators": creator_data,
		"rooms": room_data,
		"unlocked_content": unlocked_content,
		"trends": {
			"active": active_trends,
			"next_id": next_trend_id,
			# 64-bit RNG values are stored as strings: JSON numbers are doubles and would lose precision.
			"rng_seed": str(trend_rng_seed),
			"rng_state": str(trend_rng_state),
		},
		"finance": {"living_costs": living_costs, "build_costs": build_costs, "rooms_built": rooms_built,
			"expenses": expense_totals, "spending": spending, "today": today, "yesterday": yesterday},
		"upgrades": upgrades,
		"social": {
			"relationships": relationships,
			"timers": social_timers,
			"log": social_log,
			"rng_seed": str(social_rng_seed),
			"rng_state": str(social_rng_state),
		},
		"settings": settings,
	}


static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	state.cash = float(data.get("cash", 0))
	state.game_minutes = float(data.get("game_minutes", 0))
	state.lifetime_earnings = float(data.get("lifetime_earnings", 0))
	state.last_seen_unix = float(data.get("last_seen_unix", 0))
	for creator_data in data.get("creators", []):
		if typeof(creator_data) == TYPE_DICTIONARY:
			var creator := CreatorState.from_dict(creator_data)
			# Unique ids: never load the same creator twice.
			if not creator.id.is_empty() and state.get_creator(creator.id) == null:
				state.creators.append(creator)
	for room_data in data.get("rooms", []):
		if typeof(room_data) == TYPE_DICTIONARY:
			state.rooms.append(RoomState.from_dict(room_data))
	state.unlocked_content = data.get("unlocked_content", []).duplicate()
	var trend_data: Dictionary = data.get("trends", {})
	for entry in trend_data.get("active", []):
		if typeof(entry) == TYPE_DICTIONARY:
			state.active_trends.append({
				"id": str(entry.get("id", "")),
				"remaining_minutes": float(entry.get("remaining_minutes", 0)),
				"duration_minutes": float(entry.get("duration_minutes", 0)),
			})
	state.next_trend_id = str(trend_data.get("next_id", ""))
	state.trend_rng_seed = str(trend_data.get("rng_seed", "0")).to_int()
	state.trend_rng_state = str(trend_data.get("rng_state", "0")).to_int()
	var finance: Dictionary = data.get("finance", {})
	state.living_costs = float(finance.get("living_costs", 0.0))
	state.build_costs = float(finance.get("build_costs", 0.0))
	state.rooms_built = int(finance.get("rooms_built", 0))
	for key in ["expenses", "spending", "today", "yesterday"]:
		var values: Variant = finance.get(key, {})
		if values is Dictionary:
			var target: Dictionary = {"expenses": state.expense_totals, "spending": state.spending, "today": state.today, "yesterday": state.yesterday}[key]
			for k in values:
				target[str(k)] = float(values[k])
	var owned: Variant = data.get("upgrades", [])
	if owned is Array:
		for upgrade_id in owned:
			if not state.upgrades.has(str(upgrade_id)):
				state.upgrades.append(str(upgrade_id))
	var social: Dictionary = data.get("social", {})
	var rels: Variant = social.get("relationships", {})
	if rels is Dictionary:
		for key in rels:
			var entry: Variant = rels[key]
			if entry is Dictionary:
				var rel := {}
				for value_id in Relationships.VALUES:
					rel[value_id] = clampf(float(entry.get(value_id, 0.0)), 0.0, 100.0)
				state.relationships[str(key)] = rel
	var timers: Variant = social.get("timers", {})
	if timers is Dictionary:
		for key in timers:
			state.social_timers[str(key)] = float(timers[key])
	var log_data: Variant = social.get("log", [])
	if log_data is Array:
		for entry in log_data:
			if entry is Dictionary:
				state.social_log.append(entry)
	state.social_rng_seed = str(social.get("rng_seed", "0")).to_int()
	state.social_rng_state = str(social.get("rng_state", "0")).to_int()
	var settings_data: Variant = data.get("settings", {})
	if settings_data is Dictionary:
		state.settings = (settings_data as Dictionary).duplicate(true)
	return state
