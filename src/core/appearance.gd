class_name Appearance
extends RefCounted
## Creator looks: slots, derived appearance tags, makeover purchases, previews and recovery.
## Pure logic; rendering reads render_spec(). The creator always has the final say: items in
## her appearance_prefs.declines can't be bought for her.

const SINGLE_SLOTS: Array[String] = ["hair_color", "hair_style", "outfit", "makeup", "bust", "body", "lips"]
const LIST_SLOTS: Array[String] = ["piercings", "tattoos"]
const DEFAULT_LOOK := {
	"hair_color": "brunette", "hair_style": "long_waves", "outfit": "casual", "makeup": "natural",
	"bust": "natural", "body": "natural", "lips": "natural",
}
const BODY_CATEGORIES := ["procedures", "modifications"]


# ---------------------------------------------------------------------------
# Setup and tags
# ---------------------------------------------------------------------------

## Fills any missing look data from the creator's template (or defaults) and refreshes tags.
## Safe to call repeatedly; used for new games and when loading older saves.
static func ensure_look(creator: CreatorState, config: GameConfig) -> void:
	var template: Dictionary = config.creator_templates.get(creator.id, {})
	var template_look: Dictionary = template.get("look", {})
	for slot in SINGLE_SLOTS:
		if config.look_option(slot, creator.look_value(slot)).is_empty():
			creator.look[slot] = str(template_look.get(slot, DEFAULT_LOOK[slot]))
	for slot in LIST_SLOTS:
		if not creator.look.get(slot) is Array:
			creator.look[slot] = []
	if creator.owned_styles.is_empty():
		creator.owned_styles = template.get("owned_styles", []).duplicate()
	for slot in ["hair_color", "hair_style", "outfit", "makeup"]:
		var key := "%s:%s" % [slot, creator.look_value(slot)]
		if not creator.owned_styles.has(key):
			creator.owned_styles.append(key)
	if creator.base_tags.is_empty():
		for tag_id in template.get("base_tags", {}):
			creator.base_tags[str(tag_id)] = float(template["base_tags"][tag_id])
	if creator.appearance_prefs.is_empty():
		creator.appearance_prefs = template.get("appearance_prefs", {}).duplicate(true)
	refresh(creator, config)


static func refresh(creator: CreatorState, config: GameConfig) -> void:
	creator.appearance_tags = compute_tags(creator, config)


## Tags 0..1 = base tags + age tags + chosen options + applied procedures/modifications
## + body tags derived from measurements (petite, slim, curvy, voluptuous, athletic) and their bonuses.
static func compute_tags(creator: CreatorState, config: GameConfig) -> Dictionary:
	var tags := {}
	for tag_id in config.tag_order:
		tags[tag_id] = 0.0
	_add_tags(tags, creator.base_tags)
	var age_tags: Dictionary = config.appearance.get("age_tags", {})
	for tag_id in age_tags:
		var rule: Dictionary = age_tags[tag_id]
		var from_age := float(rule.get("from_age", 30))
		var full_age := float(rule.get("full_age", 40))
		tags[tag_id] = float(tags.get(tag_id, 0.0)) + clampf((creator.age - from_age) / maxf(full_age - from_age, 1.0), 0.0, 1.0)
	for slot in SINGLE_SLOTS:
		_add_tags(tags, config.look_option(slot, creator.look_value(slot)).get("tags", {}))
	for item_id in config.look_item_order:
		var item := config.look_item(item_id)
		if item.has("tags") and is_applied(creator, item):
			_add_tags(tags, item["tags"])
	if creator.measurements != null:
		var body_tags := BodyShape.tags(creator.measurements, config)
		_add_tags(tags, body_tags)
		_add_tags(tags, BodyShape.tag_bonus(body_tags, config))
	for tag_id in tags:
		tags[tag_id] = clampf(float(tags[tag_id]), 0.0, 1.0)
	return tags


## Tag ids strong enough to show as chips, strongest first.
static func visible_tags(creator: CreatorState, config: GameConfig) -> Array[String]:
	var threshold := float(config.appearance.get("show_tag_threshold", 0.35))
	var result: Array[String] = []
	for tag_id in config.tag_order:
		if creator.tag(tag_id) >= threshold:
			result.append(tag_id)
	result.sort_custom(func(a: String, b: String) -> bool: return creator.tag(a) > creator.tag(b))
	return result


# ---------------------------------------------------------------------------
# Catalogue and purchases
# ---------------------------------------------------------------------------

static func items_in_category(config: GameConfig, category: String) -> Array[String]:
	var ids: Array[String] = []
	for item_id in config.look_item_order:
		if str(config.look_item(item_id).get("category", "")) == category:
			ids.append(item_id)
	return ids


## Display name: the item's own label, or the option it selects (e.g. "Platinum blonde").
static func item_label(config: GameConfig, item: Dictionary) -> String:
	if item.has("label"):
		return str(item["label"])
	var option := config.look_option(str(item.get("slot", "")), str(item.get("value", "")))
	return str(option.get("label", item.get("id", "")))


static func is_applied(creator: CreatorState, item: Dictionary) -> bool:
	var slot := str(item.get("slot", ""))
	if item.has("add"):
		return creator.look_list(slot).has(str(item["add"]))
	return creator.look_value(slot) == str(item.get("value", ""))


static func is_body_change(item: Dictionary) -> bool:
	return BODY_CATEGORIES.has(str(item.get("category", "")))


## Styling she already owns can be switched back to for free.
static func price_for(creator: CreatorState, item: Dictionary) -> float:
	if str(item.get("category", "")) == "styling" and creator.owned_styles.has(str(item.get("id", ""))):
		return 0.0
	return float(item.get("price", 0))


## Returns {ok, reason, price, affordable}. `ok` means it can be bought right now.
static func check_item(creator: CreatorState, state: GameState, config: GameConfig, item_id: String) -> Dictionary:
	var item := config.look_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "Unknown item", "price": 0.0, "affordable": false}
	var price := price_for(creator, item)
	var result := {"ok": false, "reason": "", "price": price, "affordable": state.cash >= price}
	if is_applied(creator, item):
		result["reason"] = "Already part of her look"
		return result
	if creator.appearance_prefs.get("declines", []).has(item_id):
		result["reason"] = "%s doesn't want this. Her body, her call." % ContentRules.first_name(creator)
		return result
	if is_body_change(item) and creator.is_recovering():
		result["reason"] = "Still recovering from her last procedure"
		return result
	if state.cash < price:
		result["reason"] = "Need %s more" % Fmt.money(price - state.cash)
		return result
	result["ok"] = true
	return result


## Applies an item's look change (no money involved). Used by purchases and previews.
static func apply_item(creator: CreatorState, config: GameConfig, item: Dictionary, game_minutes: float = 0.0) -> void:
	var slot := str(item.get("slot", ""))
	if item.has("add"):
		var list := creator.look_list(slot).duplicate()
		if not list.has(str(item["add"])):
			list.append(str(item["add"]))
		creator.look[slot] = list
	else:
		creator.look[slot] = str(item.get("value", ""))
	# Procedures with measurement deltas permanently change her body (and so her rendered shape).
	if item.has("measurements") and creator.measurements != null:
		creator.measurements.apply_delta(item["measurements"])
	if str(item.get("category", "")) == "styling" and not creator.owned_styles.has(str(item["id"])):
		creator.owned_styles.append(str(item["id"]))
	if is_body_change(item):
		creator.procedure_history.append({"item_id": str(item["id"]), "day": int(game_minutes / GameState.MINUTES_PER_DAY) + 1})
		var recovery: Dictionary = item.get("recovery", {})
		var minutes := float(recovery.get("hours", 0.0)) * 60.0
		if minutes > 0.0:
			creator.recovery = {"item_id": str(item["id"]), "remaining_minutes": minutes, "total_minutes": minutes}
	refresh(creator, config)


## A changed copy for "after" previews. The real creator is never touched.
## By default the copy is shown fully healed (long-term effect); recovery is reported separately.
static func preview(creator: CreatorState, config: GameConfig, item_id: String, include_recovery: bool = false) -> CreatorState:
	var copy := creator.clone()
	var item := config.look_item(item_id)
	if not item.is_empty():
		apply_item(copy, config, item)
		if not include_recovery:
			copy.recovery = creator.recovery.duplicate()
	return copy


## Spends cash and applies the item. Returns check_item()'s result (plus "item" on success).
static func purchase(state: GameState, config: GameConfig, creator: CreatorState, item_id: String) -> Dictionary:
	var result := check_item(creator, state, config, item_id)
	if not bool(result["ok"]):
		return result
	var item := config.look_item(item_id)
	state.cash -= float(result["price"])
	state.spending["makeovers"] = float(state.spending.get("makeovers", 0.0)) + float(result["price"])
	apply_item(creator, config, item, state.game_minutes)
	var wished: bool = creator.appearance_prefs.get("wishes", []).has(item_id)
	var mood_bonus := config.tuning_f("appearance", "wish_mood_bonus", 15.0) if wished else config.tuning_f("appearance", "change_mood_bonus", 4.0)
	creator.mood = clampf(creator.mood + mood_bonus, 0.0, 100.0)
	result["wished"] = wished
	return result


# ---------------------------------------------------------------------------
# Recovery
# ---------------------------------------------------------------------------

## Counts recovery down. Returns true when recovery finished during this call.
static func advance_recovery(creator: CreatorState, config: GameConfig, minutes: float) -> bool:
	if creator.recovery.is_empty():
		return false
	var rules := recovery_rules(creator, config)
	creator.mood = clampf(creator.mood + float(rules.get("mood_per_hour", 0.0)) * minutes / 60.0, 0.0, 100.0)
	creator.recovery["remaining_minutes"] = float(creator.recovery.get("remaining_minutes", 0.0)) - minutes
	if float(creator.recovery["remaining_minutes"]) <= 0.0:
		creator.recovery = {}
		return true
	return false


static func recovery_rules(creator: CreatorState, config: GameConfig) -> Dictionary:
	if not creator.is_recovering():
		return {}
	return config.look_item(str(creator.recovery.get("item_id", ""))).get("recovery", {})


## Output multiplier on content while recovering (1.0 when healthy).
static func recovery_output(creator: CreatorState, config: GameConfig) -> float:
	return float(recovery_rules(creator, config).get("output", 1.0)) if creator.is_recovering() else 1.0


## Whether she can make this content while recovering (empty allow-list = anything).
static func recovery_allows(creator: CreatorState, config: GameConfig, content_id: String) -> bool:
	if not creator.is_recovering():
		return true
	var allowed: Array = recovery_rules(creator, config).get("allowed_content", [])
	return allowed.is_empty() or allowed.has(content_id)


# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

## Everything a renderer needs, resolved from data. Layers read this, never raw slots.
## Body regions come from her measurements (BodyShape), so numbers and visuals always agree.
static func render_spec(creator: CreatorState, config: GameConfig) -> Dictionary:
	var ap := creator.appearance
	var body := {
		"bust": float(config.look_option("bust", creator.look_value("bust", "natural")).get("size", 1.0)),
		"hips": float(config.look_option("body", creator.look_value("body", "natural")).get("hips", 1.0)),
		"glutes": float(config.look_option("body", creator.look_value("body", "natural")).get("glutes", 1.0)),
		"waist": 1.0, "shoulders": 1.0, "height_scale": 1.0, "limb_tone": 1.0,
	}
	if creator.measurements != null:
		body = BodyShape.render_params(creator.measurements, config)
	return {
		"skin": str(ap.get("skin", "#f1c6a5")),
		"eyes": str(ap.get("eyes", "#2f5d7c")),
		"hair_color": str(config.look_option("hair_color", creator.look_value("hair_color", "brunette")).get("color", ap.get("hair", "#6b3b2a"))),
		"hair_style": creator.look_value("hair_style", "long_waves"),
		"outfit": config.look_option("outfit", creator.look_value("outfit", "casual")),
		"makeup": config.look_option("makeup", creator.look_value("makeup", "natural")),
		"bust": float(body["bust"]),
		"hips": float(body["hips"]),
		"glutes": float(body["glutes"]),
		"waist": float(body["waist"]),
		"shoulders": float(body["shoulders"]),
		"height_scale": float(body["height_scale"]),
		"limb_tone": float(body["limb_tone"]),
		"freckles": bool(ap.get("freckles", false)),
		"lip_size": float(config.look_option("lips", creator.look_value("lips", "natural")).get("size", 1.0)),
		"piercings": creator.look_list("piercings").duplicate(),
		"tattoos": creator.look_list("tattoos").duplicate(),
		"recovering": creator.is_recovering(),
		"expression": signature_expression(creator, config),
		"creator_id": creator.id,
		"look": creator.look.duplicate(true),
		# Painted art: the creator's resolved art definition (empty without paintings), what the
		# paintings show of her current look, and the hair palette the recolour shader paints with.
		"illustrated": illustrated_definition(creator.id, config),
		"art_cover": illustrated_coverage(creator, config),
		"hair_palette": (config.look_option("hair_color", creator.look_value("hair_color", "brunette")).get("art_palette", []) as Array).duplicate(),
		# Per-creator animation phase, so housemates don't blink and sway in sync.
		"seed": float(absi(creator.id.hash()) % 1000) / 97.0,
		"sprite_frames": str(ap.get("sprite_frames", "")),
		"portrait": str(ap.get("portrait", "")),
	}


## Painted-art definition for a creator: the shared defaults (data/illustrated_art.json) with her
## overrides, the manifest/rig paths for her id, and what the paintings depict, taken from her own
## template (painted hair colour, base look, natural body). {} when no paintings exist for her, so
## any creator gets painted art by dropping a manifest into assets/characters/<id>/illustrated/.
static func illustrated_definition(creator_id: String, config: GameConfig) -> Dictionary:
	var defaults: Dictionary = config.illustrated.get("defaults", {})
	var overrides: Dictionary = config.illustrated.get("creators", {}).get(creator_id, {})
	var def := defaults.duplicate(true)
	for key in overrides:
		def[key] = overrides[key]
	for key in ["manifest", "rigs"]:
		def[key] = str(def.get(key, "")).replace("{id}", creator_id)
	if str(def["manifest"]).is_empty() or not FileAccess.file_exists(str(def["manifest"])):
		return {}
	var template: Dictionary = config.creator_templates.get(creator_id, {})
	var template_look: Dictionary = template.get("look", {})
	def["hair_source"] = str(template_look.get("hair_color", DEFAULT_LOOK["hair_color"]))
	if not def.has("base_look"):
		var base := {}
		for slot in def.get("base_slots", []):
			base[str(slot)] = str(template_look.get(str(slot), DEFAULT_LOOK.get(str(slot), "")))
		def["base_look"] = base
	if not def.has("body"):
		var natural := BodyMeasurements.from_dict(template.get("body", BodyShape.DEFAULT_BODY))
		var params := BodyShape.render_params(natural, config)
		def["body"] = {"bust": params["bust"], "waist": params["waist"], "hips": params["hips"], "glutes": params["glutes"]}
	return def


## What a creator's paintings show of her current look:
##   {ok, missing (labels of what isn't painted yet), adapted (labels the renderer applies to the
##    paintings, e.g. a recoloured hair colour), outfit (painted outfit id or ""), missing_outfit}.
## The paintings stay on screen either way; 'missing' tells the player what they don't show yet.
static func illustrated_coverage(creator: CreatorState, config: GameConfig) -> Dictionary:
	var def := illustrated_definition(creator.id, config)
	if def.is_empty():
		return {"ok": false, "missing": ["No illustrated art"], "adapted": [], "outfit": "", "missing_outfit": ""}
	var missing: Array[String] = []
	var adapted: Array[String] = []
	var adapts: Array = def.get("adapts", [])
	var hair := creator.look_value("hair_color")
	if hair != str(def["hair_source"]):
		if adapts.has("hair_color"):
			adapted.append(_look_label(config, "hair_color", hair) + " hair")
		else:
			missing.append(_look_label(config, "hair_color", hair))
	var base: Dictionary = def.get("base_look", {})
	for slot in base:
		var value := creator.look_value(str(slot))
		if value != str(base[slot]):
			missing.append(_look_label(config, str(slot), value))
	var makeup := creator.look_value("makeup")
	if not (def.get("allowed_makeup", []) as Array).has(makeup):
		missing.append(_look_label(config, "makeup", makeup))
	var outfit := creator.look_value("outfit")
	var painted := str(def.get("outfits", {}).get(outfit, ""))
	var missing_outfit := ""
	if painted.is_empty():
		missing_outfit = _look_label(config, "outfit", outfit)
		missing.append(missing_outfit)
	for tattoo in creator.look_list("tattoos"):
		missing.append(_list_label(config, "tattoos", str(tattoo)))
	for piercing in creator.look_list("piercings"):
		if str(piercing) != "nipple": # never drawn in any art (non-explicit presentation)
			missing.append(_list_label(config, "piercings", str(piercing)))
	if creator.measurements != null and missing.is_empty():
		var body: Dictionary = def.get("body", {})
		var params := BodyShape.render_params(creator.measurements, config)
		var tolerance := float(def.get("body_tolerance", 0.08))
		for key in ["bust", "waist", "hips", "glutes"]:
			if body.has(key) and absf(float(params[key]) - float(body[key])) > tolerance:
				missing.append("Body measurements")
				break
	return {"ok": missing.is_empty(), "missing": missing, "adapted": adapted, "outfit": painted, "missing_outfit": missing_outfit}


static func _look_label(config: GameConfig, slot: String, value: String) -> String:
	for item_id in config.look_item_order:
		var item := config.look_item(item_id)
		if str(item.get("slot", "")) == slot and str(item.get("value", "")) == value:
			return item_label(config, item)
	return str(config.look_option(slot, value).get("label", value))


static func _list_label(config: GameConfig, slot: String, value: String) -> String:
	for item_id in config.look_item_order:
		var item := config.look_item(item_id)
		if str(item.get("slot", "")) == slot and str(item.get("add", "")) == value:
			return item_label(config, item)
	return value


## Default portrait expression from her personality (first trait with one in appearance.json).
static func signature_expression(creator: CreatorState, config: GameConfig) -> String:
	var rules: Dictionary = config.appearance.get("portrait", {})
	var by_trait: Dictionary = rules.get("trait_expressions", {})
	for trait_name in creator.traits:
		if by_trait.has(str(trait_name)):
			return str(by_trait[str(trait_name)])
	return str(rules.get("default_expression", "smile"))


static func _add_tags(into: Dictionary, deltas: Dictionary) -> void:
	for tag_id in deltas:
		into[str(tag_id)] = float(into.get(str(tag_id), 0.0)) + float(deltas[tag_id])
