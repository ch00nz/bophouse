class_name Relationships
extends RefCounted
## Pairwise housemate relationships (friendship, trust, rivalry; 0..100) and lightweight autonomous
## interactions (data/social.json). Two creators relaxing in the same shared room roll an interaction
## every interval: chats and hangouts build friendship, gossip and disagreements build rivalry, with
## weights from personality (charisma, drama) and history. Rolls use a saved seeded RNG, so play is
## reproducible. No romance, jealousy or storylines yet (later milestones).

const VALUES: Array[String] = ["friendship", "trust", "rivalry"]


static func pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


## {friendship, trust, rivalry} for a pair (created with starting values if new).
static func get_pair(state: GameState, config: GameConfig, a: CreatorState, b: CreatorState) -> Dictionary:
	var key := pair_key(a.id, b.id)
	if not state.relationships.has(key):
		state.relationships[key] = _initial(config, a, b)
	return state.relationships[key]


## Makes sure every pair of residents has a relationship entry.
static func ensure_all(state: GameState, config: GameConfig) -> void:
	for i in state.creators.size():
		for j in range(i + 1, state.creators.size()):
			get_pair(state, config, state.creators[i], state.creators[j])
	if state.social_rng_seed == 0:
		state.social_rng_seed = randi() + 1


## Short summary for UI: "Close friends", "Rivals"...
static func describe(rel: Dictionary) -> String:
	var friendship := float(rel.get("friendship", 0.0))
	var rivalry := float(rel.get("rivalry", 0.0))
	if rivalry >= 50.0 and rivalry > friendship:
		return "Rivals"
	if rivalry >= 30.0 and friendship >= 50.0:
		return "Frenemies"
	if friendship >= 75.0:
		return "Best friends"
	if friendship >= 55.0:
		return "Good friends"
	if friendship >= 35.0:
		return "Friendly"
	return "Acquaintances"


## Advances social timers for every co-located relaxing pair; resolves interactions when due.
## Returns the interactions that happened: [{a, b, id, text}].
static func step(state: GameState, config: GameConfig, minutes: float) -> Array:
	var happened: Array = []
	if state.creators.size() < 2 or config.social.is_empty():
		return happened
	var interval := float(config.social.get("interval_minutes", 45.0))
	var rng: RandomNumberGenerator = null
	for i in state.creators.size():
		var a := state.creators[i]
		for j in range(i + 1, state.creators.size()):
			var b := state.creators[j]
			var key := pair_key(a.id, b.id)
			if not _together(state, config, a, b):
				state.social_timers.erase(key)
				continue
			var elapsed := float(state.social_timers.get(key, 0.0)) + minutes
			if elapsed < interval:
				state.social_timers[key] = elapsed
				continue
			state.social_timers[key] = elapsed - interval
			if rng == null:
				rng = _rng(state)
			var event := _interact(state, config, a, b, rng)
			if not event.is_empty():
				happened.append(event)
	if rng != null:
		state.social_rng_state = rng.state
	return happened


## Interaction weights for a pair right now: [{interaction, weight}].
static func weights(state: GameState, config: GameConfig, a: CreatorState, b: CreatorState) -> Array:
	var rel := get_pair(state, config, a, b)
	var friendship := float(rel["friendship"])
	var rivalry := float(rel["rivalry"])
	var charisma := (a.stat("charisma") + b.stat("charisma")) / 100.0
	var drama := (a.stat("drama") + b.stat("drama")) / 100.0
	var result: Array = []
	for interaction: Dictionary in config.social.get("interactions", []):
		if friendship < float(interaction.get("min_friendship", 0.0)):
			continue
		var min_mood := float(interaction.get("min_mood", 0.0))
		if a.mood < min_mood or b.mood < min_mood:
			continue
		var weight := float(interaction.get("weight", 1.0))
		if str(interaction.get("kind", "positive")) == "negative":
			weight *= drama * drama * (1.0 + rivalry / 40.0) / (1.0 + friendship / 100.0)
		else:
			weight *= charisma * (1.0 + friendship / 100.0) / (1.0 + rivalry / 60.0)
		if weight > 0.0:
			result.append({"interaction": interaction, "weight": weight})
	return result


static func _interact(state: GameState, config: GameConfig, a: CreatorState, b: CreatorState, rng: RandomNumberGenerator) -> Dictionary:
	var options := weights(state, config, a, b)
	var total := 0.0
	for option: Dictionary in options:
		total += float(option["weight"])
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	var chosen: Dictionary = (options[options.size() - 1] as Dictionary)["interaction"]
	for option: Dictionary in options:
		roll -= float(option["weight"])
		if roll <= 0.0:
			chosen = option["interaction"]
			break
	apply(state, config, a, b, chosen)
	var text := str(chosen.get("text", "%s and %s spent time together.")) % [a.first_name(), b.first_name()]
	var log_size := int(config.social.get("log_size", 30))
	state.social_log.append({"minute": state.game_minutes, "a": a.id, "b": b.id, "id": str(chosen.get("id", "")), "text": text})
	while state.social_log.size() > log_size:
		state.social_log.remove_at(0)
	return {"a": a.id, "b": b.id, "id": str(chosen.get("id", "")), "text": text}


## Applies an interaction's effects to a pair (relationship values, mood, reaction bubbles).
static func apply(state: GameState, config: GameConfig, a: CreatorState, b: CreatorState, interaction: Dictionary) -> void:
	var rel := get_pair(state, config, a, b)
	var effects: Dictionary = interaction.get("effects", {})
	var bonus := _trait_bonus(config, a, b)
	for value_id in VALUES:
		var delta := float(effects.get(value_id, 0.0))
		if delta > 0.0:
			delta *= 1.0 + float(bonus.get(value_id, 0.0))
		rel[value_id] = clampf(float(rel[value_id]) + delta, 0.0, 100.0)
	var mood := float(interaction.get("mood", 0.0))
	var until := state.game_minutes + float(config.social.get("bubble_minutes", 25.0))
	for pair: Array in [[a, b], [b, a]]:
		var me: CreatorState = pair[0]
		var other: CreatorState = pair[1]
		me.mood = clampf(me.mood + mood, 0.0, 100.0)
		me.reaction = {
			"kind": str(interaction.get("bubble", "chat")), "anim": str(interaction.get("anim", "chat")),
			"with": other.id, "until": until, "label": str(interaction.get("label", "")),
		}


## Both relaxing (not walking) in the same shared room.
static func _together(state: GameState, config: GameConfig, a: CreatorState, b: CreatorState) -> bool:
	if a.is_travelling() or b.is_travelling() or a.room_id.is_empty() or a.room_id != b.room_id:
		return false
	var room := state.get_room(a.room_id)
	if room == null or bool(config.room_type(room.type_id).get("private", false)):
		return false
	var relaxing: Array = config.social.get("relaxing_activities", ["socialise", "idle"])
	return relaxing.has(a.activity_id) and relaxing.has(b.activity_id)


static func _initial(config: GameConfig, a: CreatorState, b: CreatorState) -> Dictionary:
	var start: Dictionary = config.social.get("start", {})
	var rel := {
		"friendship": float(start.get("friendship", 30.0)),
		"trust": float(start.get("trust", 25.0)),
		"rivalry": float(start.get("rivalry", 5.0)),
	}
	# Two big personalities clash a little from the start.
	rel["rivalry"] = clampf(float(rel["rivalry"]) + maxf(a.stat("drama") + b.stat("drama") - 100.0, 0.0) * 0.15, 0.0, 100.0)
	return rel


static func _trait_bonus(config: GameConfig, a: CreatorState, b: CreatorState) -> Dictionary:
	var bonus := {}
	var rules: Dictionary = config.social.get("trait_bonus", {})
	for creator: CreatorState in [a, b]:
		for trait_name in creator.traits:
			var entry: Dictionary = rules.get(str(trait_name), {})
			for value_id in entry:
				bonus[str(value_id)] = float(bonus.get(str(value_id), 0.0)) + float(entry[value_id])
	return bonus


static func _rng(state: GameState) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if state.social_rng_seed == 0:
		state.social_rng_seed = randi() + 1
	rng.seed = state.social_rng_seed
	if state.social_rng_state != 0:
		rng.state = state.social_rng_state
	return rng
