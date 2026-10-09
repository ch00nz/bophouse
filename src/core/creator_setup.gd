class_name CreatorSetup
extends RefCounted
## Builds a ready-to-play creator from a template: look, measurements consistent with that look,
## tags, fan mix and contract. Used for the starting creator and for every recruit, so there is
## a single code path (no per-character logic).


static func create(template: Dictionary, config: GameConfig, state: GameState = null) -> CreatorState:
	var creator := CreatorState.from_template(template)
	Appearance.ensure_look(creator, config)
	creator.measurements = BodyShape.derive(creator, config)
	# Procedures she had before joining are part of her history (for future events).
	for item_id in Appearance.items_in_category(config, "procedures"):
		if Appearance.is_applied(creator, config.look_item(item_id)):
			creator.procedure_history.append({"item_id": item_id, "day": 0, "before_joining": true})
	Appearance.refresh(creator, config)
	AudienceModel.ensure_mix(creator, config)
	var terms := Contracts.template_terms(template)
	var day := state.day() if state != null else 1
	creator.contract = Contracts.make(float(terms["creator_share"]), day, str(terms["label"]))
	creator.joined_day = day
	return creator


## Fills anything a loaded creator is missing (saves from before measurements and contracts).
static func repair(creator: CreatorState, config: GameConfig) -> void:
	var template: Dictionary = config.creator_templates.get(creator.id, {})
	Appearance.ensure_look(creator, config)
	if creator.measurements == null:
		creator.measurements = BodyShape.derive(creator, config)
	if creator.contract.is_empty():
		var terms := Contracts.template_terms(template)
		creator.contract = Contracts.make(float(terms["creator_share"]), creator.joined_day, str(terms["label"]))
		creator.living_cost_per_day = maxf(float(template.get("living_cost_per_day", 0.0)), 0.0)
		creator.sleep_shift_hours = float(template.get("schedule", {}).get("sleep_shift_hours", creator.sleep_shift_hours))
		if creator.archetype.is_empty():
			creator.archetype = str(template.get("archetype", ""))
	if creator.living_cost_per_day <= 0.0:
		creator.living_cost_per_day = maxf(float(template.get("living_cost_per_day", 0.0)), 0.0)
	creator.age = maxi(CreatorState.MIN_AGE, creator.age)
	Appearance.refresh(creator, config)
	AudienceModel.ensure_mix(creator, config)
