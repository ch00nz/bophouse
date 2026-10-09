class_name MakeoverEvaluator
extends RefCounted
## Estimates what a makeover item would change, using a preview copy (nothing is applied).
## Compares long-term (healed) income per content type, audience segment appeal, subscription
## value from her existing fans, and lists recovery impact separately.


static func evaluate(creator: CreatorState, state: GameState, config: GameConfig, item_id: String) -> Dictionary:
	var item := config.look_item(item_id)
	var after := Appearance.preview(creator, config, item_id)

	var tag_changes: Array = []
	for tag_id in config.tag_order:
		var delta := after.tag(tag_id) - creator.tag(tag_id)
		if absf(delta) >= 0.01:
			tag_changes.append({"id": tag_id, "label": config.tag_label(tag_id), "delta": delta})

	var content_rows: Array = []
	for content_id in ContentRules.assignable_ids(config):
		var status := int(ContentRules.check(creator, content_id, state, config)["status"])
		if status == ContentRules.Status.DECLINED or status == ContentRules.Status.UNAVAILABLE:
			continue
		var before_cash := float(Economy.work_breakdown(creator, state, config, content_id)["cash"])
		var after_cash := float(Economy.work_breakdown(after, state, config, content_id)["cash"])
		content_rows.append({
			"id": content_id, "label": config.content_label(content_id),
			"short": str(config.content(content_id).get("short", content_id)),
			"before": before_cash, "after": after_cash, "change": _ratio(after_cash, before_cash),
			"current": content_id == creator.content_focus,
		})

	var segment_rows: Array = []
	for segment: Dictionary in config.segments:
		var before_appeal := AudienceModel.segment_appeal(segment, creator.appearance_tags, config)
		var after_appeal := AudienceModel.segment_appeal(segment, after.appearance_tags, config)
		if absf(after_appeal - before_appeal) >= 0.02:
			segment_rows.append({"id": str(segment["id"]), "name": str(segment.get("name", "")), "before": before_appeal, "after": after_appeal})
	segment_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return absf(float(a["after"]) - float(a["before"])) > absf(float(b["after"]) - float(b["before"])))

	var best: Dictionary = {}
	var worst: Dictionary = {}
	for row: Dictionary in content_rows:
		if best.is_empty() or float(row["change"]) > float(best["change"]):
			best = row
		if worst.is_empty() or float(row["change"]) < float(worst["change"]):
			worst = row

	return {
		"item": item,
		"label": Appearance.item_label(config, item),
		"price": Appearance.price_for(creator, item),
		"check": Appearance.check_item(creator, state, config, item_id),
		"after": after,
		"tag_changes": tag_changes,
		"content": content_rows,
		"best": best,
		"worst": worst,
		"segments": segment_rows,
		"subscriptions_before": Economy.subscription_cash_per_hour(creator, config),
		"subscriptions_after": Economy.subscription_cash_per_hour(after, config),
		"recovery": item.get("recovery", {}) if Appearance.is_body_change(item) else {},
		"wished": creator.appearance_prefs.get("wishes", []).has(item_id),
	}


static func _ratio(after: float, before: float) -> float:
	if absf(before) < 0.01:
		return 1.0
	return after / before
