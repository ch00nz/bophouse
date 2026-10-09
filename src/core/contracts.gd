class_name Contracts
extends RefCounted
## Revenue sharing between a creator and the house. Every dollar a creator earns is gross revenue:
## her contract's creator_share goes to her, the rest is credited to the house (the player's cash).
## Creators apply to live and work in the house and set their own split; there is no fee to join.
## Contracts are purely financial: they never change content boundaries or appearance decisions.


## Splits a gross amount: {gross, creator, house}.
static func split(creator: CreatorState, gross: float) -> Dictionary:
	var to_creator := gross * creator.creator_share()
	return {"gross": gross, "creator": to_creator, "house": gross - to_creator}


## Records gross revenue for a creator and credits the house share to the player. Returns the house share.
static func credit(state: GameState, creator: CreatorState, gross: float) -> float:
	var parts := split(creator, gross)
	var house := float(parts["house"])
	creator.lifetime_earnings += gross
	creator.creator_earnings += float(parts["creator"])
	creator.house_earnings += house
	state.record("gross", gross)
	state.record("creators", float(parts["creator"]))
	state.record("house", house)
	state.cash += house
	state.lifetime_earnings += house
	return house


## The terms a creator asks for: {creator_share, label}.
static func template_terms(template: Dictionary) -> Dictionary:
	var terms: Dictionary = template.get("contract", {})
	return {
		"creator_share": clampf(float(terms.get("creator_share", 0.6)), 0.0, 1.0),
		"label": str(terms.get("label", "Revenue share")),
	}


## The agreement stored on the creator when she moves in.
static func make(creator_share: float, day: int, label: String) -> Dictionary:
	return {"creator_share": clampf(creator_share, 0.0, 1.0), "joined_day": day, "label": label}


## "70 / 30" (creator / house) for display.
static func split_text(creator_share: float) -> String:
	return "%d / %d" % [roundi(creator_share * 100.0), roundi((1.0 - creator_share) * 100.0)]
