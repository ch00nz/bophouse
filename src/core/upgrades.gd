class_name Upgrades
extends RefCounted
## House-wide equipment and business upgrades (data/upgrades.json): one-off price, daily maintenance,
## prerequisites and effects. Effects within a category stack with diminishing returns: the n-th
## strongest bonus counts stack_falloff^n, so no single category can dominate. Room attribute bonuses
## are cached on each filming room (RoomState.bonus) and capped at 1.0 by RoomProduction.

const EXPANSION := "house_expansion"


static func owned(state: GameState, upgrade_id: String) -> bool:
	return state.upgrades.has(upgrade_id)


## {ok, reason, price}
static func check(state: GameState, config: GameConfig, upgrade_id: String) -> Dictionary:
	var upgrade := config.upgrade(upgrade_id)
	var price := float(upgrade.get("price", 0.0))
	if upgrade.is_empty():
		return {"ok": false, "reason": "Unknown upgrade", "price": price}
	if owned(state, upgrade_id):
		return {"ok": false, "reason": "Already owned", "price": price}
	var missing := PackedStringArray()
	for required in upgrade.get("requires", []):
		if not owned(state, str(required)):
			missing.append(str(config.upgrade(str(required)).get("label", required)))
	if not missing.is_empty():
		return {"ok": false, "reason": "Needs " + ", ".join(missing) + " first", "price": price}
	if state.cash < price:
		return {"ok": false, "reason": "Need %s more" % Fmt.money(price - state.cash), "price": price}
	return {"ok": true, "reason": "", "price": price}


## Buys an upgrade and applies its effects. Returns check()'s result.
static func purchase(state: GameState, config: GameConfig, upgrade_id: String) -> Dictionary:
	var result := check(state, config, upgrade_id)
	if not bool(result["ok"]):
		return result
	state.cash -= float(result["price"])
	state.spending["upgrades"] = float(state.spending.get("upgrades", 0.0)) + float(result["price"])
	state.upgrades.append(upgrade_id)
	if bool(config.upgrade(upgrade_id).get("effects", {}).get("unlock_house_expansion", false)):
		state.ensure_layout_rooms(config)
	refresh(state, config)
	return result


## Recomputes cached room bonuses from owned upgrades (call after purchases, building and loading).
static func refresh(state: GameState, config: GameConfig) -> void:
	var totals := _stacked_room_attributes(state, config)
	for room in state.rooms:
		room.bonus = totals.duplicate() if not config.room_type(room.type_id).get("content_support", {}).is_empty() else {}


## Income multiplier from upgrades for a content type (1.0 = none).
static func content_income_multiplier(state: GameState, config: GameConfig, content_id: String) -> float:
	return _stacked_multiplier(state, config, "content_income", content_id)


static func content_follower_multiplier(state: GameState, config: GameConfig, content_id: String) -> float:
	return _stacked_multiplier(state, config, "content_followers", content_id)


static func maintenance_per_day(state: GameState, config: GameConfig) -> float:
	var total := 0.0
	for upgrade_id in state.upgrades:
		total += float(config.upgrade(str(upgrade_id)).get("maintenance_per_day", 0.0))
	return total


## Upgrades in catalogue order that aren't owned yet.
static func available_ids(state: GameState, config: GameConfig) -> Array[String]:
	var ids: Array[String] = []
	for upgrade_id in config.upgrade_order:
		if not owned(state, upgrade_id):
			ids.append(upgrade_id)
	return ids


## Plain-language summary of an upgrade's effects for the UI.
static func effect_text(config: GameConfig, upgrade: Dictionary) -> String:
	var parts := PackedStringArray()
	var effects: Dictionary = upgrade.get("effects", {})
	var attrs: Dictionary = effects.get("room_attributes", {})
	for attr in attrs:
		parts.append("%s +%d in every set" % [str(attr).capitalize(), roundi(float(attrs[attr]) * 100.0)])
	for key: String in ["content_income", "content_followers"]:
		var map: Dictionary = effects.get(key, {})
		for content_id in map:
			var what := "all content" if str(content_id) == "*" else str(config.content(str(content_id)).get("short", content_id))
			parts.append("%s %s %s" % [Fmt.percent_change(float(map[content_id])), "income" if key == "content_income" else "followers", what])
	if bool(effects.get("unlock_house_expansion", false)):
		parts.append("Adds a top floor with two building lots")
	return "; ".join(parts)


static func _effects_by_category(state: GameState, config: GameConfig) -> Dictionary:
	var by_category := {}
	for upgrade_id in state.upgrades:
		var upgrade := config.upgrade(str(upgrade_id))
		var category := str(upgrade.get("category", upgrade_id))
		if not by_category.has(category):
			by_category[category] = []
		(by_category[category] as Array).append(upgrade.get("effects", {}))
	return by_category


static func _stacked_room_attributes(state: GameState, config: GameConfig) -> Dictionary:
	var falloff := float(config.upgrades_data.get("stack_falloff", 0.55))
	var totals := {}
	var by_category := _effects_by_category(state, config)
	for category in by_category:
		var per_attr := {}
		for effects: Dictionary in by_category[category]:
			var attrs: Dictionary = effects.get("room_attributes", {})
			for attr in attrs:
				if not per_attr.has(attr):
					per_attr[attr] = []
				(per_attr[attr] as Array).append(float(attrs[attr]))
		for attr in per_attr:
			var values: Array = per_attr[attr]
			values.sort()
			values.reverse()
			for i in values.size():
				totals[attr] = float(totals.get(attr, 0.0)) + float(values[i]) * pow(falloff, i)
	return totals


static func _stacked_multiplier(state: GameState, config: GameConfig, key: String, content_id: String) -> float:
	var falloff := float(config.upgrades_data.get("stack_falloff", 0.55))
	var result := 1.0
	var by_category := _effects_by_category(state, config)
	for category in by_category:
		var bonuses: Array = []
		for effects: Dictionary in by_category[category]:
			var map: Dictionary = effects.get(key, {})
			if map.has(content_id):
				bonuses.append(float(map[content_id]) - 1.0)
			elif map.has("*"):
				bonuses.append(float(map["*"]) - 1.0)
		bonuses.sort()
		bonuses.reverse()
		for i in bonuses.size():
			result *= 1.0 + float(bonuses[i]) * pow(falloff, i)
	return result
