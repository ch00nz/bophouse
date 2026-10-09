class_name CreatorRenderer
extends RefCounted
## Western-cartoon creator rendering (milestone 5A art pipeline). Orchestrates modular layers in
## src/art/character/:
##   FigureModel     body geometry from measurements (cached per body)
##   FigurePoses     animation poses as joint targets (idle, walk, film, selfie, stream, ...)
##   BodyPainter     skin, limbs (IK), hands, shading, tattoos, piercings, sleep blanket
##   OutfitPainter   garments cut from the body contours, legwear, shoes
##   HairPainter     hairstyle back/front layers
##   FacePainter     head, face, makeup and expressions
##   AccessoryPainter earrings, choker, pendant, sunglasses, bracelet
##   InkPen          screen-space drawing (crisp at any size) and layer recording
##
## Draw order: back hair > far arm > far leg (+legwear, shoe) > torso/neck/near leg silhouette >
## tattoos/piercings > near legwear/shoe > garments > accessories > near arm (+phone) > head, face,
## earrings > front hair. A near hand raised in front of the face is drawn after the head.
##
## Pose-independent layers (face for an expression, hair, garments, torso shading) are recorded once
## per look and replayed, so many creators in the house stay cheap. Everything is clothed and
## non-explicit; all characters are adult women.
##
## Coordinates: facing +x, feet at (0, 0), head top ~ -121. Height scales the figure uniformly.

## Pixel scales at which detail tiers switch (see InkPen.lod): sprite / medium / portrait.
const TIER_PX := [1.4, 1.9]
const TIER_RECORD_PX := [1.0, 1.6, 3.0]
## Gameplay sprites get a slightly larger head so faces stay readable at ~120 px.
const SPRITE_HEAD_SCALE := 1.14
## Hip-sway steps baked into cached torso layers (model units).
const SWAY_STEP := 0.2

static var _layers: Dictionary = {}


## Draws a creator with feet at `origin`. Poses: idle, walk, film, socialise, selfie, stream, sleep,
## recline, chat, celebrate, argue, showcase. Her height scales the whole figure uniformly.
static func draw(ci: CanvasItem, spec: Dictionary, anim: String, t: float, origin: Vector2, facing: float = 1.0, scale: float = 1.0, sleep_lift: float = 0.0) -> void:
	scale *= float(spec.get("height_scale", 1.0))
	var seed := float(spec.get("seed", 0.0))
	var pose := FigurePoses.pose(anim, t + seed)
	var base: Transform2D
	if anim == "sleep":
		base = Transform2D(-PI / 2.0, Vector2(scale, scale), 0.0, origin + Vector2(56.0, -sleep_lift - 13.0) * scale)
	elif anim == "recline":
		var sway := sin(t * 1.4) * 0.03
		base = Transform2D(-PI / 2.0 + 0.2 + sway, Vector2(scale, scale), 0.0, origin + Vector2(56.0, -sleep_lift + 1.0) * scale)
	else:
		base = Transform2D(0.0, Vector2(facing * scale, scale), 0.0, origin + Vector2(0.0, float(pose["bob"])) * scale)
	var pen := InkPen.new(ci, base)
	_draw_figure(pen, spec, pose, t + seed)


## Draws the creator plus activity props (in local units, scaled like the figure):
##  - "guest_creator": a consenting adult guest creator posing alongside her (girl/girl collabs);
##  - "guest_silhouette": an anonymous, clothed dark silhouette (implied boy/girl collabs);
##  - "privacy_screen": closed-set content is implied by a folding screen and a CLOSED SET tag.
static func draw_with_props(ci: CanvasItem, spec: Dictionary, anim: String, t: float, origin: Vector2, facing: float, scale: float, lift: float, props: Array, guest_outfit: Dictionary = {}) -> void:
	draw_guests(ci, spec, anim, t, origin, facing, scale, lift, props, guest_outfit)
	draw(ci, spec, anim, t, origin, facing, scale, lift)
	draw_screen(ci, anim, origin, scale, lift, props)


## The other people in a collab shot (behind/beside the creator). Painted creators draw these too.
static func draw_guests(ci: CanvasItem, spec: Dictionary, anim: String, t: float, origin: Vector2, facing: float, scale: float, lift: float, props: Array, guest_outfit: Dictionary = {}) -> void:
	var lying := anim == "sleep" or anim == "recline"
	if not (props.has("guest_creator") or props.has("guest_silhouette")):
		return
	var offset := Vector2(0, -6) if lying else Vector2(-32.0 * facing, 0.0)
	if props.has("guest_creator"):
		var guest := spec.duplicate()
		guest.erase("look_hash")
		guest["hair_color"] = "#1f1a2e"
		guest["hair_style"] = "bob"
		guest["skin"] = "#c68863"
		guest["eyes"] = "#4a2c1d"
		guest["freckles"] = false
		guest["seed"] = float(spec.get("seed", 0.0)) + 1.3
		if not guest_outfit.is_empty():
			guest["outfit"] = guest_outfit
		guest["tattoos"] = []
		guest["piercings"] = []
		draw(ci, guest, "recline" if lying else "film", t, origin + offset * scale, -facing, scale * 0.98, lift + (4.0 if lying else 0.0))
	else:
		_draw_silhouette(ci, origin + offset * scale, -facing, scale, lying, lift)


## The closed-set privacy screen (drawn in front of the creator).
static func draw_screen(ci: CanvasItem, anim: String, origin: Vector2, scale: float, lift: float, props: Array) -> void:
	if not props.has("privacy_screen"):
		return
	ci.draw_set_transform(origin, 0.0, Vector2(scale, scale))
	_draw_privacy_screen(ci, anim == "sleep" or anim == "recline", lift)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Records a standing figure (feet at the origin, facing +x) into draw commands instead of drawing:
## [op, canvas points, colour, ...] (see InkPen.Op). Used by tests to check geometry headlessly.
static func record(spec: Dictionary, anim: String, t: float, scale: float = 3.0) -> Array:
	var pen := InkPen.new(null, Transform2D(0.0, Vector2(scale, scale) * float(spec.get("height_scale", 1.0)), 0.0, Vector2.ZERO))
	var rec := pen.recorder()
	rec.xf = pen.xf
	rec.px = scale
	_draw_figure(rec, spec, FigurePoses.pose(anim, t), t)
	return rec.commands()


# ---------------------------------------------------------------------------
# Figure
# ---------------------------------------------------------------------------

static func _draw_figure(pen: InkPen, spec: Dictionary, pose: Dictionary, t: float) -> void:
	var model := FigureModel.for_spec(spec)
	var tier := _tier(pen.px)
	var c := BodyPainter.palette(spec)
	var outfit: Dictionary = spec.get("outfit", {})
	var rig := BodyPainter.rig(model, pose)
	var sway := float(rig["sway"])
	var legs: Array = rig["legs"]
	var arms: Array = rig["arms"]
	var hands: Array = pose["hands"]
	var expr_name := str(pose.get("expression", ""))
	if expr_name.is_empty():
		expr_name = str(spec.get("expression", "smile"))
	var expr := FacePainter.expression(expr_name, t, float(spec.get("seed", 0.0)))

	var head_scale := SPRITE_HEAD_SCALE if tier == 0 else 1.0
	var tilt := float(pose["head_tilt"])
	var head_xf := Transform2D(tilt, Vector2(head_scale, head_scale), 0.0, FigureModel.NECK_TOP) * Transform2D(0.0, FigureModel.HEAD_OFFSET)
	var swing := float(pose.get("hair_swing", 0.0)) * 0.035 - tilt * 0.4
	var near_wrist: Vector2 = (arms[1] as Dictionary)["wrist"]
	var arm_after_head := near_wrist.y < -97.0 and near_wrist.x > 6.0

	# Back hair (swings with the pose).
	pen.push(head_xf * Transform2D(Vector2(1, 0), Vector2(swing, 1), Vector2.ZERO))
	pen.replay(_layer("hair_back", spec, tier, pen, func(rec: InkPen) -> void: HairPainter.draw_back(rec, spec)))
	pen.pop()

	BodyPainter.draw_arm(pen, arms[0], str(hands[0]), c, true, spec)
	var blanket := bool(pose.get("blanket", false))
	BodyPainter.draw_leg(pen, legs[0], c, true)
	if not blanket:
		OutfitPainter.draw_legwear(pen, legs[0], outfit.get("legwear", {}), c["skin"], true)
		OutfitPainter.draw_shoe(pen, legs[0], outfit.get("shoes", {}), c["skin"], true)

	# Hip sway is baked into the torso layers in small steps (no per-point work while drawing).
	sway = snappedf(sway, SWAY_STEP)
	var torso_detail := _layer("torso|%s" % model.key, spec, tier, pen, func(rec: InkPen) -> void: BodyPainter.bake_torso_detail(rec, model, c, spec), sway)
	BodyPainter.draw_body(pen, model, legs[1], c, sway, torso_detail)
	# Body art goes under legwear: stockings hide a thigh tattoo, fishnets show it through the mesh.
	BodyPainter.draw_skin_art(pen, spec, model, legs[1], sway)
	if not blanket:
		OutfitPainter.draw_legwear(pen, legs[1], outfit.get("legwear", {}), c["skin"], false)
		OutfitPainter.draw_shoe(pen, legs[1], outfit.get("shoes", {}), c["skin"], false)
	pen.replay(_layer("outfit|%s" % model.key, spec, tier, pen, func(rec: InkPen) -> void:
		OutfitPainter.draw_torso_garments(rec, model, outfit, c["skin"])
		AccessoryPainter.draw_neck(rec, spec, model), sway))
	if blanket:
		BodyPainter.draw_blanket(pen, model, sway)

	if not arm_after_head:
		_draw_near_arm(pen, arms[1], str(hands[1]), c, spec, bool(pose["phone"]))
	pen.push(head_xf)
	pen.replay(_layer("face|%s" % expr["key"], spec, tier, pen, func(rec: InkPen) -> void:
		FacePainter.draw_ear(rec, c["skin"])
		AccessoryPainter.draw_ears(rec, spec)
		FacePainter.draw(rec, spec, expr)))
	pen.replay(_layer("hair_front", spec, tier, pen, func(rec: InkPen) -> void:
		HairPainter.draw_front(rec, spec)
		AccessoryPainter.draw_head_top(rec, spec)))
	pen.pop()
	if arm_after_head:
		_draw_near_arm(pen, arms[1], str(hands[1]), c, spec, bool(pose["phone"]))


static func _draw_near_arm(pen: InkPen, arm: Dictionary, hand: String, c: Dictionary, spec: Dictionary, phone: bool) -> void:
	BodyPainter.draw_arm(pen, arm, hand, c, false, spec)
	if phone:
		var wrist: Vector2 = arm["wrist"]
		BodyPainter.draw_phone(pen, wrist, (wrist - (arm["elbow"] as Vector2)).normalized(), c["skin"])


static func _tier(px: float) -> int:
	if px < float(TIER_PX[0]):
		return 0
	return 1 if px < float(TIER_PX[1]) else 2


## Recorded commands for a pose-independent layer, cached by everything that changes its look.
static func _layer(kind: String, spec: Dictionary, tier: int, pen: InkPen, paint: Callable, sway: float = 0.0) -> Array:
	var key := "%s|%d|%d|%.2f" % [kind, tier, _look_hash(spec), sway]
	if _layers.has(key):
		return _layers[key]
	if _layers.size() > 600:
		_layers.clear()
	var base_key := "%s|%d|%d|0.00" % [kind, tier, _look_hash(spec)]
	if not _layers.has(base_key):
		var rec := pen.recorder()
		rec.px = float(TIER_RECORD_PX[tier])
		paint.call(rec)
		_layers[base_key] = rec.commands()
	_layers[key] = InkPen.sheared(_layers[base_key], sway)
	return _layers[key]


## Hash of the look-defining parts of a spec (not pose or recovery state).
static func _look_hash(spec: Dictionary) -> int:
	if spec.has("look_hash"):
		return int(spec["look_hash"])
	var value := [spec.get("skin"), spec.get("eyes"), spec.get("hair_color"), spec.get("hair_style"), spec.get("outfit"),
		spec.get("makeup"), spec.get("lip_size"), spec.get("freckles"), spec.get("piercings"), spec.get("tattoos")].hash()
	spec["look_hash"] = value # memoised on the spec (render_spec builds a fresh one per look change)
	return value


static func clear_cache() -> void:
	_layers.clear()


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------

static func _draw_privacy_screen(ci: CanvasItem, lying: bool, lift: float) -> void:
	var base_y := -lift + 2.0 if lying else 0.0
	var height := 34.0 if lying else 96.0
	var width := 104.0 if lying else 48.0
	var left := -width * 0.5 + (4.0 if lying else 0.0)
	var panels := 4 if lying else 3
	var panel_w := width / panels
	for i in panels:
		var x := left + i * panel_w
		var colour := Color("c77dff") if i % 2 == 0 else Color("b5179e")
		ci.draw_rect(Rect2(x, base_y - height, panel_w - 1.0, height), colour)
		ci.draw_rect(Rect2(x, base_y - height, panel_w - 1.0, height), colour.darkened(0.35), false, 1.2)
		PlaceholderArt.draw_heart(ci, Vector2(x + panel_w * 0.5, base_y - height * 0.55), 9.0, Color(1, 1, 1, 0.35))
	PlaceholderArt.draw_rounded_rect(ci, Rect2(left + width * 0.5 - 30, base_y - height - 14, 60, 12), Color(0.08, 0.03, 0.1, 0.85), 5)
	PlaceholderArt.draw_text(ci, Vector2(left + width * 0.5 - 30, base_y - height - 5), "CLOSED SET", 9, Color.WHITE, 60, HORIZONTAL_ALIGNMENT_CENTER)


## Anonymous, fully clothed guest: a soft dark silhouette with no features.
static func _draw_silhouette(ci: CanvasItem, origin: Vector2, facing: float, scale: float, lying: bool, lift: float) -> void:
	var dark := Color(0.16, 0.1, 0.22, 0.92)
	var base := Transform2D(0.0, Vector2(facing * scale, scale), 0.0, origin)
	if lying:
		base = Transform2D(-PI / 2.0 + 0.15, Vector2(scale, scale), 0.0, origin + Vector2(58.0, -lift - 6.0) * scale)
	var pen := InkPen.new(ci, base)
	var parts: Array = [
		[InkPen.smooth_closed(PackedVector2Array([Vector2(-10, -96), Vector2(11, -96), Vector2(9, -60), Vector2(8, -48), Vector2(-8, -48), Vector2(-9, -60)]), 3), dark],
		[InkPen.smooth_closed(PackedVector2Array([Vector2(-8, -50), Vector2(-1, -50), Vector2(-2, -1), Vector2(-7, -1)]), 2), dark],
		[InkPen.smooth_closed(PackedVector2Array([Vector2(1, -50), Vector2(8, -50), Vector2(7, -1), Vector2(2, -1)]), 2), dark],
		[InkPen.ellipse(Vector2(1, -107), Vector2(9, 10.5), 18), dark],
		[InkPen.ellipse(Vector2(0, -97), Vector2(3.5, 4), 10), dark],
	]
	pen.group(parts, 0.7, Color(0.08, 0.04, 0.12))
