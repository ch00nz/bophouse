class_name Photoshoot
extends RefCounted
## Optional bonus photoshoot: a short timing mini-game the player can direct for extra income and
## followers. Purely a bonus. Automated production never depends on it, and it has a cooldown so
## idle players are never behind by much. Uses her current content within her boundaries.


## {ok, reason}: whether a photoshoot can start right now.
static func check(creator: CreatorState, state: GameState, config: GameConfig) -> Dictionary:
	if creator.content_focus.is_empty():
		return {"ok": false, "reason": "No content focus set"}
	if creator.activity_id == "sleep" and not creator.is_travelling():
		return {"ok": false, "reason": "%s is asleep" % ContentRules.first_name(creator)}
	if not Appearance.recovery_allows(creator, config, creator.content_focus):
		return {"ok": false, "reason": "Still recovering"}
	var min_energy := config.tuning_f("photoshoot", "min_energy", 30.0)
	if creator.energy < min_energy:
		return {"ok": false, "reason": "Too tired (needs %d energy)" % int(min_energy)}
	if state.game_minutes < creator.photoshoot_ready_at:
		return {"ok": false, "reason": "Next shoot in " + Fmt.game_duration(creator.photoshoot_ready_at - state.game_minutes)}
	return {"ok": true, "reason": ""}


## Quality of one shot: 1.0 when the marker is on target, falling to 0 at `tolerance` away.
static func shot_quality(marker: float, target: float, tolerance: float = 0.35) -> float:
	return clampf(1.0 - absf(marker - target) / maxf(tolerance, 0.001), 0.0, 1.0)


## Reward for a shoot of average quality `score` (0..1): a few hours of her content output.
static func reward(creator: CreatorState, state: GameState, config: GameConfig, score: float) -> Dictionary:
	var b := Economy.work_breakdown(creator, state, config)
	var factor := lerpf(config.tuning_f("photoshoot", "min_reward_factor", 0.5),
		config.tuning_f("photoshoot", "max_reward_factor", 2.0), clampf(score, 0.0, 1.0))
	var hours := config.tuning_f("photoshoot", "reward_hours", 3.0)
	return {
		"cash": maxf(float(b["cash"]), 0.0) * hours * factor,
		"followers": maxf(float(b["followers"]), 0.0) * hours * factor,
		"score": score,
	}


## Pays out the shoot and starts the cooldown. Returns the reward (or {ok:false, reason}).
static func complete(creator: CreatorState, state: GameState, config: GameConfig, score: float) -> Dictionary:
	var gate := check(creator, state, config)
	if not bool(gate["ok"]):
		return gate
	var result := reward(creator, state, config, score)
	var cash := float(result["cash"])
	state.cash += cash
	state.lifetime_earnings += cash
	creator.lifetime_earnings += cash
	creator.followers += float(result["followers"])
	creator.energy = clampf(creator.energy - config.tuning_f("photoshoot", "energy_cost", 12.0), 0.0, 100.0)
	creator.photoshoot_ready_at = state.game_minutes + config.tuning_f("photoshoot", "cooldown_hours", 12.0) * 60.0
	result["ok"] = true
	return result
