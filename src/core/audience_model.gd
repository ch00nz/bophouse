class_name AudienceModel
extends RefCounted
## Subscriber preference segments (data/audiences.json).
##
## Segment appeal = 1 + sum(likes x tag) - sum(dislikes x tag), clamped.
## For a content type, each segment's weight = share x interest x spend; audience fit is the
## weight-averaged appeal (1.0 for a look nobody loves or hates). The income multiplier is
## fit^fit_exponent, so looks matter without dominating.
## Each creator also has a fan_mix (who her subscribers are) that drifts toward the segments her
## current content and look attract. Subscription value depends on how satisfied *those* fans are,
## so a makeover that delights new fans can still disappoint existing ones.


static func segment_appeal(segment: Dictionary, tags: Dictionary, config: GameConfig) -> float:
	var appeal := 1.0
	var likes: Dictionary = segment.get("likes", {})
	for tag_id in likes:
		appeal += float(likes[tag_id]) * float(tags.get(tag_id, 0.0))
	var dislikes: Dictionary = segment.get("dislikes", {})
	for tag_id in dislikes:
		appeal -= float(dislikes[tag_id]) * float(tags.get(tag_id, 0.0))
	return clampf(appeal, config.tuning_f("audience", "min_segment_appeal", 0.15), config.tuning_f("audience", "max_segment_appeal", 2.5))


static func content_interest(segment: Dictionary, content_id: String, config: GameConfig) -> float:
	return float(segment.get("content", {}).get(content_id, config.audience.get("default_content_interest", 0.1)))


## Returns {fit, multiplier, segments: [{id, name, appeal, buyer_share}]} sorted by buyer_share.
static func market(tags: Dictionary, content_id: String, config: GameConfig) -> Dictionary:
	var rows: Array = []
	var total_base := 0.0
	var total_weighted := 0.0
	for segment: Dictionary in config.segments:
		var base := float(segment.get("share", 0.0)) * content_interest(segment, content_id, config) * float(segment.get("spend", 1.0))
		var appeal := segment_appeal(segment, tags, config)
		total_base += base
		total_weighted += base * appeal
		rows.append({"id": str(segment["id"]), "name": str(segment.get("name", segment["id"])), "appeal": appeal, "weight": base * appeal})
	for row: Dictionary in rows:
		row["buyer_share"] = float(row["weight"]) / total_weighted if total_weighted > 0.0 else 0.0
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["buyer_share"]) > float(b["buyer_share"]))
	var fit := total_weighted / total_base if total_base > 0.0 else 1.0
	return {"fit": fit, "multiplier": pow(fit, config.tuning_f("audience", "fit_exponent", 0.6)), "segments": rows}


## Segment shares of the buyers a look + content would attract (sums to 1).
static func target_mix(tags: Dictionary, content_id: String, config: GameConfig) -> Dictionary:
	var mix := {}
	for row: Dictionary in market(tags, content_id, config)["segments"]:
		mix[row["id"]] = float(row["buyer_share"])
	return mix


## Subscription value multiplier: how much her existing fans spend and how happy they are.
static func fan_value(creator: CreatorState, config: GameConfig) -> float:
	if creator.fan_mix.is_empty():
		return 1.0
	var min_sat := config.tuning_f("audience", "min_fan_satisfaction", 0.5)
	var max_sat := config.tuning_f("audience", "max_fan_satisfaction", 1.5)
	var value := 0.0
	for segment: Dictionary in config.segments:
		var share := float(creator.fan_mix.get(str(segment["id"]), 0.0))
		if share <= 0.0:
			continue
		var satisfaction := clampf(segment_appeal(segment, creator.appearance_tags, config), min_sat, max_sat)
		value += share * float(segment.get("spend", 1.0)) * satisfaction
	return value


## 0..1: how much of her fanbase dislikes her current look (share-weighted shortfall below 1.0 appeal).
static func unhappiness(creator: CreatorState, config: GameConfig) -> float:
	var total := 0.0
	for segment: Dictionary in config.segments:
		var share := float(creator.fan_mix.get(str(segment["id"]), 0.0))
		if share > 0.0:
			total += share * maxf(0.0, 1.0 - segment_appeal(segment, creator.appearance_tags, config))
	return clampf(total, 0.0, 1.0)


## Subscribers per hour cancelling because they dislike her current look.
static func unhappy_churn_per_hour(creator: CreatorState, config: GameConfig) -> float:
	return maxf(creator.subscribers, 0.0) * config.tuning_f("loyalty", "unhappy_churn_per_hour", 0.004) * unhappiness(creator, config)


## Her fanbase for the UI, largest first: [{id, name, share, target, satisfaction, spend}] where
## target is the share her current look + content attracts (where the mix is drifting to).
static func fan_breakdown(creator: CreatorState, config: GameConfig) -> Array:
	var content_id := creator.content_focus if not creator.content_focus.is_empty() else "social_media"
	var target := target_mix(creator.appearance_tags, content_id, config)
	var rows: Array = []
	for segment: Dictionary in config.segments:
		var segment_id := str(segment["id"])
		rows.append({
			"id": segment_id, "name": str(segment.get("name", segment_id)),
			"share": float(creator.fan_mix.get(segment_id, 0.0)), "target": float(target.get(segment_id, 0.0)),
			"satisfaction": segment_appeal(segment, creator.appearance_tags, config), "spend": float(segment.get("spend", 1.0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["share"]) > float(b["share"]))
	return rows


## Moves her fan mix toward the audience her current content and look attract.
static func drift_mix(creator: CreatorState, config: GameConfig, content_id: String, hours: float) -> void:
	var target := target_mix(creator.appearance_tags, content_id, config)
	var rate := clampf(config.tuning_f("audience", "fan_mix_drift_per_hour", 0.03) * hours, 0.0, 1.0)
	var total := 0.0
	for segment_id in target:
		var current := float(creator.fan_mix.get(segment_id, 0.0))
		creator.fan_mix[segment_id] = lerpf(current, float(target[segment_id]), rate)
		total += float(creator.fan_mix[segment_id])
	if total > 0.0:
		for segment_id in creator.fan_mix:
			creator.fan_mix[segment_id] = float(creator.fan_mix[segment_id]) / total


static func ensure_mix(creator: CreatorState, config: GameConfig) -> void:
	if creator.fan_mix.is_empty():
		var content_id := creator.content_focus if not creator.content_focus.is_empty() else "social_media"
		creator.fan_mix = target_mix(creator.appearance_tags, content_id, config)


static func segment(config: GameConfig, segment_id: String) -> Dictionary:
	for s: Dictionary in config.segments:
		if str(s["id"]) == segment_id:
			return s
	return {}
