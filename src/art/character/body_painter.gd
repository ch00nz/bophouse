class_name BodyPainter
extends RefCounted
## Skin layers: limbs (posed with IK every frame), the torso/neck/near-leg silhouette drawn as one
## merged inked shape, soft shading and rim light, hands, tattoos, piercings and the sleep blanket.
## Tattoos and piercings anchor to limb samples and body contours, so they stay aligned in every
## pose and on every body; outfits hide them where they cover the skin.


static func palette(spec: Dictionary) -> Dictionary:
	var skin := PlaceholderArt.color(spec.get("skin"), Color("f1c6a5"))
	var back := InkPen.shadow_of(skin, 0.1)
	return {
		"skin": skin, "lit": InkPen.light_of(skin, 0.07), "mid": skin.lerp(InkPen.shadow_of(skin, 0.2), 0.3),
		"shadow": InkPen.shadow_of(skin, 0.22), "light": InkPen.light_of(skin, 0.3), "line": InkPen.line_of(skin, 0.42),
		"back": back, "back_mid": InkPen.shadow_of(skin, 0.18),
	}


# ---------------------------------------------------------------------------
# Rig: joints for this pose
# ---------------------------------------------------------------------------

## Limb joints for the pose: {legs: [far, near], arms: [far, near], sway}.
static func rig(model: FigureModel, pose: Dictionary) -> Dictionary:
	var sway := float(pose["sway"])
	var legs: Array = []
	var ankles: Array = pose["ankles"]
	var knees: Array = pose["knees"]
	var lying := bool(pose.get("lying", false))
	for i in 2:
		var hip: Vector2 = model.hip_joints[i] + Vector2(FigureModel.sway_at(FigureModel.HIP_JOINT_Y, sway), 0.0)
		var solved := FigureModel.solve_joint(hip, ankles[i], FigureModel.THIGH_LENGTH, FigureModel.SHIN_LENGTH, knees[i])
		var ankle: Vector2 = solved[1]
		var lift := FigurePoses.GROUND - ankle.y
		legs.append({
			"hip": hip, "knee": solved[0], "ankle": ankle, "side": -1.0 if i == 0 else 1.0,
			"thigh": pow(model.hips, 0.85) * lerpf(1.0, model.tone, 0.2), "calf": lerpf(1.0, model.tone, 0.6),
			"foot_angle": 0.35 if lying else clampf(lift * 0.22, 0.0, 0.7),
		})
	var arms: Array = []
	var wrists: Array = pose["wrists"]
	var elbows: Array = pose["elbows"]
	for i in 2:
		var shoulder: Vector2 = model.shoulder_joints[i]
		var solved := FigureModel.solve_joint(shoulder, wrists[i], FigureModel.UPPER_ARM, FigureModel.FOREARM, elbows[i])
		arms.append({"shoulder": shoulder, "elbow": solved[0], "wrist": solved[1], "tone": lerpf(1.0, model.tone, 0.7)})
	return {"legs": legs, "arms": arms, "sway": sway}


# ---------------------------------------------------------------------------
# Limbs
# ---------------------------------------------------------------------------

static func draw_leg(pen: InkPen, leg: Dictionary, c: Dictionary, is_far: bool) -> void:
	var poly := FigureModel.leg_polygon(leg, -0.08, 1.0)
	if is_far:
		pen.shape_lit(poly, c["back"], c["back_mid"])
		pen.shade(poly, Vector2(1.6, -0.2), InkPen.shadow_of(c["skin"], 0.3))
	else:
		pen.shape_lit(poly, c["lit"], c["mid"])
		_leg_shading(pen, leg, poly, c)


static func _leg_shading(pen: InkPen, leg: Dictionary, poly: PackedVector2Array, c: Dictionary) -> void:
	pen.shade(poly, Vector2(1.5, -0.2), c["shadow"])
	if pen.lod(1.4):
		for piece in InkPen.rim(poly, Vector2(-0.75, 0.2)):
			pen.fill_soft(piece, c["light"])
	if pen.lod(1.9):
		# Knee definition.
		var knee := FigureModel.leg_sample(leg, 0.5)
		var centre: Vector2 = knee[0]
		var normal: Vector2 = knee[3]
		pen.stroke(InkPen.quad(centre - normal * 0.9 + Vector2(0, -0.6), centre + Vector2(0.2, 0.4), centre + normal * 0.8 + Vector2(0, -0.4), 5), c["line"], 0.2, false, 0.6)


## Arm plus hand as one inked shape.
static func draw_arm(pen: InkPen, arm: Dictionary, hand_shape: String, c: Dictionary, is_far: bool, spec: Dictionary) -> void:
	var lit: Color = c["back"] if is_far else c["lit"]
	var mid: Color = c["back_mid"] if is_far else c["mid"]
	var arm_poly := FigureModel.arm_polygon(arm)
	var parts: Array = [[arm_poly, lit, mid]]
	var wrist: Vector2 = arm["wrist"]
	var dir: Vector2 = (wrist - (arm["elbow"] as Vector2)).normalized()
	for shape in hand_shapes(wrist, dir, hand_shape, pen.lod(1.9)):
		parts.append([shape, lit, mid])
	pen.group(parts, 0.75)
	pen.shade(arm_poly, Vector2(1.2, -0.6), InkPen.shadow_of(c["skin"], 0.3 if is_far else 0.22))
	if not is_far and pen.lod(1.4):
		for piece in InkPen.rim(arm_poly, Vector2(-0.6, 0.3)):
			pen.fill_soft(piece, c["light"])
	if not is_far:
		if (spec.get("tattoos", []) as Array).has("arm_sleeve"):
			_sleeve_tattoo(pen, arm, arm_poly)
		AccessoryPainter.draw_wrist(pen, spec, wrist, dir)
	if pen.lod(1.9) and hand_shape != "hidden" and hand_shape != "hip":
		var nails := PlaceholderArt.color((spec.get("makeup", {}) as Dictionary).get("lips"), Color("e05a7d"))
		var n := dir.orthogonal()
		var tips: Array[Vector2] = []
		match hand_shape:
			"open":
				for k in 4:
					var fan := dir.rotated((k - 1.5) * 0.28)
					tips.append(wrist + dir * 2.4 + fan * 2.7 + n * (k - 1.5) * 0.4)
			"point":
				tips.append(wrist + dir * 5.4)
			_:
				tips.append(wrist + dir * 4.6 + n * 0.3)
		for tip in tips:
			pen.dot(tip, 0.4, nails)


## Hand silhouettes for a wrist and forearm direction.
static func hand_shapes(wrist: Vector2, dir: Vector2, shape: String, detail: bool) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var angle := dir.angle()
	var n := dir.orthogonal()
	match shape:
		"hidden":
			return result
		"hip":
			result.append(InkPen.ellipse(wrist + dir * 1.6, Vector2(1.9, 1.25), 12, angle))
			result.append(InkPen.ellipse(wrist + dir * 3.2 - n * 0.3, Vector2(1.4, 0.95), 10, angle + 0.3))
		"open":
			result.append(InkPen.ellipse(wrist + dir * 1.6, Vector2(1.7, 1.4), 12, angle))
			if detail:
				for k in 4:
					var fan := dir.rotated((k - 1.5) * 0.28)
					var base := wrist + dir * 2.4 + n * (k - 1.5) * 0.45
					result.append(InkPen.taper(PackedVector2Array([base, base + fan * 1.5, base + fan * 2.9]), 0.75, 0.55))
			else:
				result.append(InkPen.ellipse(wrist + dir * 3.4, Vector2(1.6, 1.4), 10, angle))
			result.append(InkPen.ellipse(wrist + dir * 1.4 - n * 1.5, Vector2(1.1, 0.55), 10, angle - 0.7))
		"point":
			result.append(InkPen.ellipse(wrist + dir * 1.8, Vector2(1.8, 1.45), 12, angle))
			result.append(InkPen.taper(PackedVector2Array([wrist + dir * 3.0, wrist + dir * 4.4, wrist + dir * 5.6]), 0.7, 0.55))
		"phone":
			result.append(InkPen.ellipse(wrist + dir * 1.7, Vector2(1.8, 1.35), 12, angle))
			result.append(InkPen.ellipse(wrist + dir * 3.0 + n * 0.6, Vector2(1.3, 0.8), 10, angle + 0.5))
		_: # relaxed
			result.append(InkPen.ellipse(wrist + dir * 1.7, Vector2(1.8, 1.3), 12, angle))
			result.append(InkPen.ellipse(wrist + dir * 3.5 + n * 0.2, Vector2(1.45, 1.0), 10, angle + 0.15))
			result.append(InkPen.ellipse(wrist + dir * 1.8 - n * 1.25, Vector2(1.0, 0.5), 10, angle - 0.5))
	return result


static func draw_phone(pen: InkPen, wrist: Vector2, dir: Vector2, skin: Color) -> void:
	var centre := wrist + dir * 3.2 + Vector2(0, -2.2)
	var body := InkPen.smooth_closed(PackedVector2Array([centre + Vector2(-1.8, -3.3), centre + Vector2(1.8, -3.3),
		centre + Vector2(1.8, 3.3), centre + Vector2(-1.8, 3.3)]), 2)
	pen.shape(body, Color("ff4f8b"), 0.6)
	pen.fill(InkPen.ellipse(centre + Vector2(-0.7, -2.1), Vector2(0.55, 0.55), 10), Color("2a1622"))
	pen.dot(centre + Vector2(-0.85, -2.25), 0.18, Color(1, 1, 1, 0.7))
	# Thumb over the edge of the phone.
	var thumb := InkPen.ellipse(wrist + dir * 2.6 + dir.orthogonal() * -1.0, Vector2(1.0, 0.55), 10, dir.angle() - 0.9)
	pen.shape(thumb, skin, 0.5)


# ---------------------------------------------------------------------------
# Torso group
# ---------------------------------------------------------------------------

## Torso, neck, near leg and bust drawn as one merged inked silhouette, then shaded.
static func draw_body(pen: InkPen, model: FigureModel, near_leg: Dictionary, c: Dictionary, sway: float, baked_detail: Array) -> void:
	var torso := FigureModel.shear(model.torso, sway)
	var leg := FigureModel.leg_polygon(near_leg, -0.08, 1.0)
	var parts: Array = [
		[torso, c["lit"], c["mid"]], [model.neck, c["lit"], c["mid"]], [leg, c["lit"], c["mid"]],
		[model.breast_shape(0), c["lit"], c["mid"]], [model.breast_shape(1), c["lit"], c["mid"]],
	]
	pen.group(parts, 0.85)
	pen.replay(baked_detail)
	_leg_shading(pen, near_leg, leg, c)


## Pose-independent torso shading and anatomy lines (recorded once per body and skin tone).
static func bake_torso_detail(pen: InkPen, model: FigureModel, c: Dictionary, spec: Dictionary) -> void:
	pen.shade(model.torso, Vector2(2.6, -0.3), c["shadow"])
	if pen.lod(1.4):
		for piece in InkPen.rim(model.torso, Vector2(-0.8, 0.25)):
			pen.fill_soft(piece, c["light"])
	for i in 2:
		pen.shade(model.breast_shape(i), Vector2(0.3, -1.4), c["shadow"])
	pen.fill_clipped(InkPen.ellipse(Vector2(1.6, -101.0), Vector2(5.0, 2.8), 16), model.neck, c["shadow"])
	pen.shade(model.neck, Vector2(1.6, 0.0), c["shadow"])
	if not pen.lod(1.4):
		return
	# Collarbones, cleavage, navel and (on toned bodies) a hint of abs.
	pen.stroke(InkPen.quad(Vector2(-4.6, -92.2), Vector2(-2.0, -93.0), Vector2(0.2, -92.4), 5), c["line"], 0.2, false, 0.6)
	pen.stroke(InkPen.quad(Vector2(2.6, -92.6), Vector2(4.6, -93.2), Vector2(7.0, -92.3), 5), c["line"], 0.2, false, 0.6)
	var near: Array = model.breasts[1]
	var cl := model.cleavage_x()
	var by := (near[0] as Vector2).y
	if model.bust > 0.7:
		pen.stroke(PackedVector2Array([Vector2(cl + 0.15, by - (near[1] as Vector2).y * 0.55), Vector2(cl - 0.1, by + 0.4)]), c["line"], 0.22, false, 0.6)
	for i in 2:
		var b: Array = model.breasts[i]
		pen.stroke(InkPen.arc(b[0], b[1], PI * 0.2, PI * 0.8, 8), c["line"], 0.2, false, 0.6)
	var navel := Vector2((model.near_x(-66.0) + model.far_x(-66.0)) * 0.5 + 1.9, -66.0)
	pen.stroke(InkPen.quad(navel + Vector2(-0.4, -0.5), navel + Vector2(0.15, 0.2), navel + Vector2(0.3, 0.7), 4), c["line"], 0.25, false, 0.7)
	if model.tone > 1.12:
		pen.stroke(PackedVector2Array([navel + Vector2(-0.2, -9.0), navel + Vector2(-0.1, -2.2)]), Color(c["line"], 0.5), 0.2, false, 0.5)
		for k in 2:
			var y := -75.0 + k * 3.2
			pen.stroke(InkPen.quad(navel + Vector2(-2.2, y + 66.0), navel + Vector2(-1.1, y + 66.6), navel + Vector2(-0.3, y + 66.2), 4), Color(c["line"], 0.4), 0.16, false, 0.5)
			pen.stroke(InkPen.quad(navel + Vector2(0.2, y + 66.2), navel + Vector2(1.2, y + 66.6), navel + Vector2(2.4, y + 66.0), 4), Color(c["line"], 0.4), 0.16, false, 0.5)


# ---------------------------------------------------------------------------
# Body art
# ---------------------------------------------------------------------------

## Rose tattoo on the near thigh and the navel piercing, when the outfit leaves them visible.
static func draw_skin_art(pen: InkPen, spec: Dictionary, model: FigureModel, near_leg: Dictionary, sway: float) -> void:
	var outfit: Dictionary = spec.get("outfit", {})
	var tattoos: Array = spec.get("tattoos", [])
	if tattoos.has("rose_thigh") and not bool(outfit.get("covers_thighs", false)):
		var spot := FigureModel.leg_sample(near_leg, 0.36)
		var centre: Vector2 = (spot[0] as Vector2) + (spot[3] as Vector2) * float(spot[1]) * 0.3
		if centre.y > OutfitPainter.coverage_bottom(outfit) + 1.2:
			_rose(pen, centre, 1.0)
	var piercings: Array = spec.get("piercings", [])
	if piercings.has("belly") and bool(outfit.get("midriff", false)):
		var navel := Vector2((model.near_x(-66.0) + model.far_x(-66.0)) * 0.5 + 1.9 + FigureModel.sway_at(-66.0, sway), -66.0)
		pen.dot(navel + Vector2(0.15, -0.7), 0.35, Color("fff1c4"), 1.2)
		pen.shape(InkPen.ellipse(navel + Vector2(0.25, 1.2), Vector2(0.5, 0.7), 10), Color("7fd3ff"), 0.25)
		pen.dot(navel + Vector2(0.4, 1.0), 0.18, Color.WHITE)
	# Nipple piercings are intentionally never drawn: outfits always cover the chest.


static func _rose(pen: InkPen, centre: Vector2, size: float) -> void:
	var leaf := Color(0.2, 0.55, 0.32)
	if not pen.lod(1.4):
		pen.dot(centre, 1.3 * size, Color(0.78, 0.1, 0.25, 0.9))
		return
	pen.shape(InkPen.ellipse(centre + Vector2(-1.9, 1.6) * size, Vector2(1.4, 0.6) * size, 10, 0.5), leaf, 0.2, Color("1d2a1f"))
	pen.shape(InkPen.ellipse(centre + Vector2(1.9, 1.9) * size, Vector2(1.4, 0.6) * size, 10, -0.5), leaf, 0.2, Color("1d2a1f"))
	pen.shape(InkPen.ellipse(centre, Vector2(1.8, 1.6) * size, 14), Color(0.8, 0.1, 0.26), 0.25, Color("3a0612"))
	pen.stroke(InkPen.arc(centre + Vector2(0.1, 0.1), Vector2(0.9, 0.8) * size, 0.0, TAU * 0.8, 8), Color(0.45, 0.03, 0.12), 0.2, false, 0.5)
	pen.stroke(InkPen.arc(centre + Vector2(-0.2, 0.3), Vector2(1.4, 1.0) * size, 2.0, 3.8, 5), Color(0.45, 0.03, 0.12), 0.18, false, 0.5)


## Floral half-sleeve: blossoms and vines along the near arm, clipped to the arm.
static func _sleeve_tattoo(pen: InkPen, arm: Dictionary, arm_poly: PackedVector2Array) -> void:
	var shoulder: Vector2 = arm["shoulder"]
	var elbow: Vector2 = arm["elbow"]
	var wrist: Vector2 = arm["wrist"]
	var ink := Color(0.16, 0.12, 0.3, 0.85)
	var vine := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		var p := shoulder.lerp(elbow, u * 2.0) if u <= 0.5 else elbow.lerp(wrist, (u - 0.5) * 1.6)
		var n := (elbow - shoulder).orthogonal().normalized() if u <= 0.5 else (wrist - elbow).orthogonal().normalized()
		vine.append(p + n * sin(u * 9.0) * 0.9)
	pen.stroke_clipped(vine, arm_poly, ink, 0.22, 0.6)
	for i in 3:
		var p := shoulder.lerp(elbow, 0.2 + i * 0.3)
		if pen.lod(1.4):
			var flower := InkPen.ellipse(p, Vector2(1.05, 1.05), 10)
			pen.fill_clipped(flower, arm_poly, Color(0.86, 0.18, 0.42))
			pen.stroke_clipped(InkPen.arc(p, Vector2(0.55, 0.55), 0.0, TAU * 0.7, 6), arm_poly, ink, 0.18, 0.5)
		else:
			pen.dot(p, 0.8, Color(0.86, 0.18, 0.42))
	for i in 2:
		var p := elbow.lerp(wrist, 0.3 + i * 0.3)
		pen.fill_clipped(InkPen.ellipse(p, Vector2(0.9, 0.45), 8, (wrist - elbow).angle() + 0.6), arm_poly, Color(0.2, 0.55, 0.32, 0.9))


## Bed covers for sleeping (model space, drawn before the figure is rotated onto the bed).
static func draw_blanket(pen: InkPen, model: FigureModel, sway: float) -> void:
	var top := -63.0
	var far := model.far_x(-56.0) - 3.0 + sway
	var near := model.near_x(-56.0) + 6.5 + sway
	var blanket := InkPen.smooth_closed(PackedVector2Array([Vector2(far, top), Vector2((far + near) * 0.5, top - 0.6), Vector2(near, top),
		Vector2(near + 1.0, -30.0), Vector2(near - 0.5, 2.0), Vector2(far + 1.0, 3.0), Vector2(far - 0.8, -30.0)]), 3)
	var colour := Color("b8a1e3")
	pen.shape_lit(blanket, InkPen.light_of(colour, 0.15), colour, 0.85)
	pen.shade(blanket, Vector2(2.2, 0.0), InkPen.shadow_of(colour, 0.3))
	var sheet := PackedVector2Array([Vector2(far - 0.6, top - 0.4), Vector2(near + 0.4, top - 0.4), Vector2(near + 0.6, top + 3.2), Vector2(far - 0.4, top + 3.2)])
	pen.shape(sheet, Color("fbf3ee"), 0.6)
	if pen.lod(1.2):
		for k in 3:
			var x := lerpf(far + 2.0, near - 2.0, (k + 0.6) / 3.2)
			pen.stroke(InkPen.quad(Vector2(x, top + 6.0), Vector2(x + 1.2, -30.0), Vector2(x - 0.4, -6.0), 6), InkPen.shadow_of(colour, 0.25), 0.3, false, 0.7)
