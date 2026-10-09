class_name BodyShape
extends RefCounted
## Data-driven link between body measurements and everything that depends on them (data/body.json):
##  - render_params(): renderer body-region parameters (bust, waist, hips, glutes, shoulders, height),
##    so the numbers and the drawn body always agree;
##  - tags(): body appearance tags (petite, slim, curvy, voluptuous, athletic) from combinations of
##    measurements, which audiences like or dislike differently (no universal "bigger is better");
##  - derive(): measurements for a creator from her template's natural body plus applied procedures
##    (used for new creators and to migrate saves that predate measurements).

const DEFAULT_BODY := {"height_cm": 168.0, "bust_cm": 92.0, "waist_cm": 66.0, "hips_cm": 96.0, "tone": 0.35}


## Piecewise-linear interpolation through [[x, y], ...] points sorted by x (clamped at the ends).
static func curve(points: Array, x: float) -> float:
	if points.is_empty():
		return 1.0
	var first: Array = points[0]
	if x <= float(first[0]):
		return float(first[1])
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if x <= float(b[0]):
			var span := maxf(float(b[0]) - float(a[0]), 0.0001)
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / span)
	return float((points[points.size() - 1] as Array)[1])


## 0..1 ramp from `from` (0) to `to` (1); works in either direction.
static func ramp(x: float, from: float, to: float) -> float:
	if is_equal_approx(from, to):
		return 1.0 if x >= to else 0.0
	return clampf((x - from) / (to - from), 0.0, 1.0)


## Renderer parameters: {height_scale, bust, waist, hips, glutes, shoulders, limb_tone}.
static func render_params(m: BodyMeasurements, config: GameConfig) -> Dictionary:
	var rules: Dictionary = config.body.get("render", {})
	var metrics := m.metrics()
	var result := {}
	for key in ["height_scale", "bust", "waist", "hips", "glutes", "shoulders"]:
		var rule: Dictionary = rules.get(key, {})
		result[key] = curve(rule.get("points", []), float(metrics.get(str(rule.get("metric", "")), 0.0))) if not rule.is_empty() else 1.0
	# Toned bodies get a lifted, rounder seat and a little more limb definition.
	result["glutes"] = float(result["glutes"]) + float(rules.get("glute_tone", 0.0)) * maxf(m.tone - 0.35, 0.0)
	result["limb_tone"] = 1.0 + float(rules.get("limb_tone", 0.0)) * (m.tone - 0.35)
	return result


## Body tags (0..1) derived from measurements; every tag id in body.json is present.
static func tags(m: BodyMeasurements, config: GameConfig) -> Dictionary:
	var metrics := m.metrics()
	var result := {}
	var rules: Dictionary = config.body.get("tags", {})
	for tag_id in rules:
		var strength := 1.0
		for condition: Dictionary in rules[tag_id]:
			strength *= ramp(float(metrics.get(str(condition.get("metric", "")), 0.0)),
				float(condition.get("from", 0.0)), float(condition.get("to", 1.0)))
		result[str(tag_id)] = strength
	return result


## Styling-tag deltas implied by body tags (e.g. voluptuous adds a little bombshell).
static func tag_bonus(body_tags: Dictionary, config: GameConfig) -> Dictionary:
	var bonus := {}
	var rules: Dictionary = config.body.get("tag_bonus", {})
	for body_tag in rules:
		var strength := float(body_tags.get(str(body_tag), 0.0))
		if strength <= 0.0:
			continue
		var deltas: Dictionary = rules[body_tag]
		for tag_id in deltas:
			bonus[str(tag_id)] = float(bonus.get(str(tag_id), 0.0)) + float(deltas[tag_id]) * strength
	return bonus


## Measurements for a creator: her template's natural body plus the deltas of every procedure
## currently applied to her look. Keeps numbers consistent with what she visibly had done.
static func derive(creator: CreatorState, config: GameConfig) -> BodyMeasurements:
	var template: Dictionary = config.creator_templates.get(creator.id, {})
	var natural: Dictionary = template.get("body", DEFAULT_BODY)
	var m := BodyMeasurements.from_dict(natural)
	for item_id in config.look_item_order:
		var item := config.look_item(item_id)
		if item.has("measurements") and Appearance.is_applied(creator, item):
			m.apply_delta(item["measurements"])
	return m


## Problems with a set of measurements (empty = plausible adult measurements).
static func validate(m: BodyMeasurements, config: GameConfig) -> Array[String]:
	var problems: Array[String] = []
	var limits: Dictionary = config.body.get("limits", {})
	var fields: Array = BodyMeasurements.FIELDS.duplicate()
	fields.append("tone")
	for field: String in fields:
		var range_def: Array = limits.get(field, [])
		if range_def.size() == 2 and (m.value(field) < float(range_def[0]) or m.value(field) > float(range_def[1])):
			problems.append("%s %.1f outside %s..%s" % [field, m.value(field), range_def[0], range_def[1]])
	var rules: Dictionary = config.body.get("plausibility", {})
	var metrics := m.metrics()
	if float(metrics["bust_diff"]) < float(rules.get("min_bust_diff", 0.0)):
		problems.append("bust barely larger than waist")
	if float(metrics["hip_diff"]) < float(rules.get("min_hip_diff", 0.0)):
		problems.append("hips barely larger than waist")
	if float(metrics["frame"]) > float(rules.get("max_frame", 1.0)):
		problems.append("frame too large for height")
	return problems
