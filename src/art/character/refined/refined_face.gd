class_name RefinedFace
extends RefCounted
## Refined-style head and face (RenderStyle prototype). Same head-local space, feature anchors,
## expressions, makeup data, freckles, lip filler and nose stud as FacePainter, painted with soft
## gradients instead of flat cel shapes:
##   skin    colour-matched outline, soft far-side shading, sculpted highlights (forehead, nose
##           bridge, cheekbone, chin) and a gentle contour under the cheekbone
##   eyes    slightly larger almond eyes with a lifted outer corner, layered iris (limbal ring,
##           lit lower half, two catch-lights), eyelid shading, a tapered lash line with curled
##           outer lashes, soft lower lashes and a pink inner corner
##   brows   full arched brows that fade in at the head and taper to a fine tail
##   nose    no hard lines: soft bridge shadow, tip highlight and a small nostril curve
##   lips    fuller, with a darker upper lip, a lit lower lip, gloss and a soft shadow under the lip

const HEAD_CTRL := [
	Vector2(0.6, -10.0), Vector2(5.6, -8.5), Vector2(8.6, -4.5), Vector2(9.3, -0.4), Vector2(9.05, 2.8),
	Vector2(7.7, 5.9), Vector2(5.3, 8.6), Vector2(3.0, 9.85), Vector2(1.2, 9.45), Vector2(-3.0, 7.2),
	Vector2(-6.3, 3.8), Vector2(-8.2, -0.6), Vector2(-7.9, -5.2), Vector2(-5.0, -8.7),
]
const NEAR_EYE := Vector2(5.0, 0.75)
const FAR_EYE := Vector2(-1.1, 0.75)
const LASH := Color("1e0d14")

static var _head: PackedVector2Array = PackedVector2Array()


static func head_shape() -> PackedVector2Array:
	if _head.is_empty():
		_head = InkPen.smooth_closed(PackedVector2Array(HEAD_CTRL), 4)
	return _head


static func draw_ear(pen: InkPen, skin: Color) -> void:
	var ear := InkPen.ellipse(FacePainter.EAR, Vector2(1.55, 2.4), 14, 0.15)
	pen.shape(ear, InkPen.shadow_of(skin, 0.1), 0.6, RefinedBody.outline_of(skin))
	if pen.lod(1.4):
		pen.fill_radial(FacePainter.EAR + Vector2(0.2, 0.2), Vector2(0.9, 1.5), Color(RefinedBody.warm_shadow(skin, 0.3), 0.7), 0.15, 12)
	if pen.lod(1.9):
		pen.stroke(InkPen.arc(FacePainter.EAR + Vector2(0.2, 0.1), Vector2(0.8, 1.4), -1.2, 1.6, 6), RefinedBody.outline_of(skin).lerp(skin, 0.4), 0.18)


static func draw(pen: InkPen, spec: Dictionary, expr: Dictionary) -> void:
	var skin := PlaceholderArt.color(spec.get("skin"), Color("f1c6a5"))
	var shadow := RefinedBody.warm_shadow(skin, 0.24)
	var light := InkPen.light_of(skin, 0.4)
	var hair := PlaceholderArt.color(spec.get("hair_color"), Color("6b3b2a"))
	var makeup: Dictionary = spec.get("makeup", {})
	var mid := pen.lod(1.4)
	var detail := pen.lod(1.9)
	var head := head_shape()

	pen.shape_lit(head, InkPen.light_of(skin, 0.1), skin.lerp(shadow, 0.25), 0.72, RefinedBody.outline_of(skin))
	pen.shade_soft(head, Vector2(3.6, -0.4), Color(shadow, 0.85))
	if mid:
		# Sculpting: soft light on the forehead, nose bridge, cheekbone and chin; contour under the
		# cheekbone and along the far jaw.
		pen.fill_radial(Vector2(3.4, -5.4), Vector2(3.6, 2.0), Color(light, 0.45))
		pen.fill_radial(Vector2(7.3, 1.7), Vector2(1.9, 0.95), Color(light, 0.55), -0.35)
		pen.fill_radial(Vector2(3.3, 8.5), Vector2(1.3, 0.7), Color(light, 0.45))
		pen.fill_radial(Vector2(7.2, 4.6), Vector2(1.9, 0.75), Color(shadow, 0.28), -0.75)
		pen.fill_radial(Vector2(-3.6, 5.8), Vector2(3.0, 1.6), Color(shadow, 0.3), -0.6)
		if bool(makeup.get("highlight", false)):
			pen.fill_radial(Vector2(7.6, 1.4), Vector2(1.3, 0.55), Color(1, 1, 1, 0.45), -0.35)
			pen.fill_radial(Vector2(7.8, 4.7), Vector2(1.6, 0.6), Color(shadow, 0.3), -0.8)
		# Eye sockets: a little depth under the brows.
		pen.fill_radial(NEAR_EYE + Vector2(-0.4, -1.7), Vector2(2.7, 1.1), Color(shadow, 0.1))
		pen.fill_radial(FAR_EYE + Vector2(0.3, -1.6), Vector2(2.1, 1.0), Color(shadow, 0.12))

	_blush(pen, makeup, mid)
	if bool(spec.get("freckles", false)):
		_freckles(pen, skin, mid)
	_brows(pen, hair, expr, mid)
	var iris := PlaceholderArt.color(spec.get("eyes"), Color("2f5d7c"))
	var lids: Array = expr["lids"]
	var happy: Array = expr["happy"]
	_eye(pen, NEAR_EYE, 2.5, 1.0, float(lids[0]), bool(happy[0]), iris, makeup, skin, mid, detail)
	_eye(pen, FAR_EYE, 2.0, -1.0, float(lids[1]), bool(happy[1]), iris, makeup, skin, mid, detail)
	_nose(pen, skin, shadow, light, mid)
	if (spec.get("piercings", []) as Array).has("nose"):
		pen.dot(Vector2(4.25, 4.0), 0.34, Color("ffe7a3"), 1.6)
		pen.dot(Vector2(4.15, 3.9), 0.13, Color.WHITE)
	_mouth(pen, spec, makeup, expr, skin, shadow, mid, detail)


# ---------------------------------------------------------------------------
# Eyes
# ---------------------------------------------------------------------------

static func _eye(pen: InkPen, c: Vector2, hw: float, o: float, open: float, happy: bool, iris: Color, makeup: Dictionary, skin: Color, mid: bool, detail: bool) -> void:
	var glam := str(makeup.get("lashes", "natural")) == "glam"
	var lid_colour := PlaceholderArt.color(makeup.get("lids"), Color.TRANSPARENT)
	# Natural makeup still gets a soft warm lid tone; makeup colours replace it.
	var lid_tone := skin.lerp(lid_colour, 0.7) if lid_colour.a > 0.0 else RefinedBody.warm_shadow(skin, 0.3)
	var lid_alpha := 0.85 if lid_colour.a > 0.0 else 0.4
	var inner := c + Vector2(-o * hw, 0.35)
	var outer := c + Vector2(o * hw, -0.5)
	if open < 0.12:
		var lid_line: PackedVector2Array
		if happy: # smiling eyes: an upward curve
			lid_line = InkPen.quad(inner + Vector2(0, 0.45), c + Vector2(0, -1.7), outer + Vector2(0, 0.5), 10)
		else: # closed lid curving down, lashes resting on the cheek
			lid_line = InkPen.quad(inner, c + Vector2(o * 0.1, 1.25), outer + Vector2(0, 0.25), 10)
		if mid:
			var lid := InkPen.quad(inner + Vector2(0, -0.3), c + Vector2(o * 0.15 * hw, -2.6), outer + Vector2(0, -0.5), 8)
			lid.append_array(_reversed(lid_line))
			pen.fill_feather(lid, Color(lid_tone, lid_alpha * 0.8), 0.5)
		pen.fill(InkPen.taper(lid_line, 0.3, 0.75, 0.3), LASH)
		if detail and not happy:
			for k in 4:
				var p := lid_line[4 + k * 2]
				pen.fill(InkPen.taper(InkPen.quad(p, p + Vector2(o * 0.25, 0.55), p + Vector2(o * 0.7, 0.75 + k * 0.08), 4), 0.22, 0.02), LASH)
		return
	var up_h := 1.75 * open
	var upper := InkPen.quad(inner, Vector2(c.x - o * 0.12 * hw, c.y - 2.0 * up_h + 0.2), outer, 12)
	var lower := InkPen.quad(outer, Vector2(c.x + o * 0.12 * hw, c.y + 2.0), inner, 12)
	var sclera := upper.duplicate()
	sclera.append_array(lower)
	# Eyelid: soft colour from the lash line up to the crease.
	var crease := InkPen.quad(outer + Vector2(o * 0.35, -0.95), Vector2(c.x - o * 0.05 * hw, c.y - 2.0 * up_h - 2.0), inner + Vector2(-o * 0.1, -0.55), 12)
	if mid:
		var lid := upper.duplicate()
		lid.append_array(crease)
		pen.fill_feather(lid, Color(lid_tone, lid_alpha), 0.7 if lid_colour.a > 0.0 else 0.45)
		# Brow-bone highlight.
		pen.fill_radial(c + Vector2(o * 0.4, -2.0 * up_h - 2.2), Vector2(1.3, 0.5), Color(InkPen.light_of(skin, 0.5), 0.5))
	pen.fill_lit(sclera, Color("fffbf7"), Color("ecdcd8"))
	var r := 1.58 * hw / 2.5
	# Both eyes look toward the viewer (the face is turned 3/4 toward +x).
	var iris_c := c + Vector2((0.04 if o > 0 else -0.16) * hw, -0.1 + (1.0 - open) * 0.45)
	var squash := 0.9 if o > 0 else 0.78
	var iris_shape := InkPen.ellipse(iris_c, Vector2(r * squash, r), 18)
	if mid:
		pen.fill_clipped(iris_shape, sclera, InkPen.shadow_of(iris, 0.45))
		pen.fill_clipped(InkPen.ellipse(iris_c, Vector2(r * squash * 0.8, r * 0.8), 16), sclera, iris)
		pen.fill_clipped(InkPen.ellipse(iris_c + Vector2(0, r * 0.38), Vector2(r * squash * 0.62, r * 0.42), 14), sclera, InkPen.light_of(iris, 0.38))
		pen.fill_clipped(InkPen.ellipse(iris_c + Vector2(0, -r * 0.05), Vector2(r * squash * 0.4, r * 0.44), 14), sclera, Color("150a10"))
		# The upper lid casts a soft shadow over the top of the eye.
		pen.fill_clipped(InkPen.taper(upper, 1.5, 1.5), sclera, Color(0.35, 0.18, 0.25, 0.32))
		if detail:
			pen.fill_clipped(InkPen.taper(upper, 0.7, 0.7), sclera, Color(0.3, 0.14, 0.2, 0.3))
		pen.dot(iris_c + Vector2(o * 0.32 * r, -0.4 * r), 0.24 * r + 0.06, Color.WHITE)
		pen.dot(iris_c + Vector2(-o * 0.3 * r, 0.42 * r), 0.11 * r, Color(1, 1, 1, 0.75))
		# Pink inner corner.
		pen.dot(inner + Vector2(o * 0.3, -0.05), 0.24, Color(0.93, 0.6, 0.62, 0.9))
	else:
		pen.fill_clipped(iris_shape, sclera, InkPen.shadow_of(iris, 0.3))
		pen.fill_clipped(InkPen.ellipse(iris_c, Vector2(r * 0.4, r * 0.45), 10), sclera, Color("150a10"))
	# Lash line: fine at the inner corner, bold toward the outer corner, ending in a small flick.
	pen.fill(InkPen.taper(upper, 0.35, 1.3 if glam else 1.1, 0.32), LASH)
	var liner := bool(makeup.get("liner", false))
	var wing := 1.75 if liner else 0.95
	var wing_path := InkPen.quad(outer + Vector2(-o * 0.6, -0.1), outer + Vector2(o * wing * 0.45, -wing * 0.2), outer + Vector2(o * wing, -wing * 0.6), 5)
	pen.fill(InkPen.taper(wing_path, 0.85 if liner else 0.65, 0.05), LASH)
	if mid:
		pen.stroke(crease, Color(RefinedBody.outline_of(skin), 0.45), 0.15, false, 0.6)
		# Lower lash line: soft and only on the outer two thirds.
		var lower_outer := PackedVector2Array()
		for i in 8:
			lower_outer.append(lower[i])
		pen.fill(InkPen.taper(lower_outer, 0.32, 0.04), Color(LASH, 0.5))
	if detail:
		# Curled lashes on the outer half, longest at the corner.
		var count := 5 if glam else 3
		for k in count:
			var idx := upper.size() - 2 - k * 2
			var p := upper[idx]
			var length := (1.15 if glam else 0.85) * (1.0 - k * 0.12)
			var dir := Vector2(o * (0.8 - 0.12 * k), -0.62).normalized()
			pen.fill(InkPen.taper(InkPen.quad(p, p + dir * length * 0.6, p + dir * length + Vector2(o * 0.4 * length, 0.2), 5), 0.42, 0.02), LASH)
		if glam:
			for k in 3:
				var p := lower[2 + k * 2]
				pen.fill(InkPen.taper(PackedVector2Array([p, p + Vector2(o * 0.25, 0.55)]), 0.16, 0.02), Color(LASH, 0.7))


# ---------------------------------------------------------------------------
# Brows, nose, cheeks
# ---------------------------------------------------------------------------

static func _brows(pen: InkPen, hair: Color, expr: Dictionary, mid: bool) -> void:
	var brow := hair.darkened(0.42).lerp(Color("2a1418"), 0.42)
	var raise: Array = expr["brows"]
	var angry := float(expr["angry"])
	var rn := float(raise[0])
	var rf := float(raise[1])
	var near := InkPen.smooth_open(PackedVector2Array([
		Vector2(2.9, -2.75 - rn * 0.55 + angry * 0.9), Vector2(4.9, -3.95 - rn * 0.9 + angry * 0.3),
		Vector2(6.6, -4.45 - rn), Vector2(8.15, -3.35 - rn * 0.7 - angry * 0.3)]), 4)
	var far := InkPen.smooth_open(PackedVector2Array([
		Vector2(0.8, -2.85 - rf * 0.55 + angry * 0.9), Vector2(-0.9, -3.85 - rf * 0.9 + angry * 0.3),
		Vector2(-2.3, -4.1 - rf), Vector2(-3.55, -2.9 - rf * 0.7 - angry * 0.3)]), 4)
	_gradient_stroke(pen, near, 1.05, 0.14, 0.22, Color(brow, 0.6), brow)
	_gradient_stroke(pen, far, 0.9, 0.12, 0.18, Color(brow, 0.6), brow)
	if mid:
		# A few hairs at the head of each brow keep it soft rather than painted on.
		for k in 3:
			var p := near[k]
			pen.stroke(PackedVector2Array([p + Vector2(0.0, 0.35), p + Vector2(0.25, -0.35)]), Color(brow, 0.5), 0.1, false, 0.5)


static func _nose(pen: InkPen, skin: Color, shadow: Color, light: Color, mid: bool) -> void:
	var line := RefinedBody.outline_of(skin)
	# Bridge: a soft shadow on the far side, no outline.
	_gradient_stroke(pen, InkPen.quad(Vector2(2.5, 1.2), Vector2(2.6, 2.7), Vector2(3.2, 3.75), 8), 0.05, 0.6, 0.15, Color(shadow, 0.0), Color(shadow, 0.4))
	# Under the tip and the nostril.
	pen.fill_radial(Vector2(3.75, 4.55), Vector2(1.2, 0.4), Color(shadow, 0.55))
	pen.stroke(InkPen.quad(Vector2(3.05, 4.2), Vector2(3.35, 4.55), Vector2(3.85, 4.45), 5), Color(line, 0.75), 0.2, false, 0.7)
	if mid:
		pen.stroke(InkPen.quad(Vector2(4.5, 3.6), Vector2(4.8, 4.05), Vector2(4.45, 4.4), 4), Color(line, 0.35), 0.13, false, 0.5)
		pen.fill_radial(Vector2(3.95, 3.35), Vector2(0.75, 0.55), Color(light, 0.8))
		pen.fill_radial(Vector2(3.4, 1.4), Vector2(0.3, 1.2), Color(light, 0.5))


static func _blush(pen: InkPen, makeup: Dictionary, mid: bool) -> void:
	var amount := float(makeup.get("blush", 0.3))
	if amount <= 0.0:
		return
	var colour := Color(1.0, 0.42, 0.48, minf(amount * 1.2, 0.6))
	if mid:
		pen.fill_radial(Vector2(6.7, 3.5), Vector2(2.4, 1.35), colour, -0.15)
		pen.fill_radial(Vector2(-2.6, 3.6), Vector2(1.7, 1.2), colour)
	else:
		pen.fill(InkPen.ellipse(Vector2(6.7, 3.6), Vector2(1.8, 1.0), 12), Color(colour, amount * 0.45))


static func _freckles(pen: InkPen, skin: Color, mid: bool) -> void:
	var freckle := Color(RefinedBody.warm_shadow(skin, 0.5).darkened(0.15), 0.55)
	var spots := [Vector2(5.5, 2.4), Vector2(6.6, 2.9), Vector2(7.7, 2.4), Vector2(6.2, 1.9), Vector2(3.6, 2.6), Vector2(2.4, 2.2),
		Vector2(1.2, 2.6), Vector2(-0.4, 2.5), Vector2(-1.6, 2.9), Vector2(4.8, 3.0), Vector2(7.1, 3.4), Vector2(5.9, 3.3),
		Vector2(3.1, 2.0), Vector2(-0.9, 3.1)]
	for i in spots.size():
		if not mid and i % 2 == 1:
			continue
		pen.dot(spots[i], 0.13 + 0.06 * float((i * 7) % 3) / 2.0, freckle, 0.8)


# ---------------------------------------------------------------------------
# Lips
# ---------------------------------------------------------------------------

## Mouth shapes match FacePainter (same expressions), with fuller, softly shaded lips.
static func _mouth(pen: InkPen, spec: Dictionary, makeup: Dictionary, expr: Dictionary, skin: Color, shadow: Color, mid: bool, detail: bool) -> void:
	var size := float(spec.get("lip_size", 1.0))
	var lip := PlaceholderArt.color(makeup.get("lips"), Color("c2185b"))
	var kind := str(expr["mouth"])
	var open := float(expr["open"])
	var fc := Vector2(0.55, 6.6)
	var mc := Vector2(2.75, 6.95)
	var nc := Vector2(5.1, 6.4)
	var ut := 0.72 * size
	var lt := 1.12 * size
	match kind:
		"smile":
			fc = Vector2(0.45, 6.3)
			nc = Vector2(5.2, 5.95)
			mc = Vector2(2.75, 7.15)
		"smirk":
			fc = Vector2(0.6, 6.75)
			nc = Vector2(5.25, 5.85)
			mc = Vector2(2.8, 6.95)
		"pout":
			fc = Vector2(1.3, 6.55)
			nc = Vector2(4.3, 6.45)
			mc = Vector2(2.8, 6.7)
			ut *= 1.25
			lt *= 1.15
		"gasp":
			fc = Vector2(1.4, 6.5)
			nc = Vector2(4.2, 6.4)
			mc = Vector2(2.8, 6.4)
		"frown":
			fc = Vector2(0.65, 7.0)
			nc = Vector2(5.0, 6.95)
			mc = Vector2(2.75, 6.6)
		"grin":
			fc = Vector2(0.4, 6.15)
			nc = Vector2(5.35, 5.85)
			mc = Vector2(2.8, 6.85)
		"laugh":
			fc = Vector2(0.3, 6.0)
			nc = Vector2(5.5, 5.8)
			mc = Vector2(2.85, 6.6)
	var line := InkPen.quad(fc, mc, nc, 12)
	var n := line.size()
	var upper_top := PackedVector2Array()
	var opening := PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		var p := line[i]
		var bow := 1.0 - 0.36 * exp(-pow((p.x - mc.x) / 0.42, 2.0))
		# Peaks of the cupid's bow sit either side of the centre.
		var peaks := 0.12 * exp(-pow((absf(p.x - mc.x) - 0.75) / 0.45, 2.0))
		upper_top.append(p - Vector2(0, ut * (pow(sin(u * PI), 0.5) * bow + peaks) + 0.05))
		opening.append(p + Vector2(0, open * 1.9 * pow(sin(u * PI), 0.8)))
	var upper := line.duplicate()
	upper.append_array(_interior_reversed(upper_top))
	var lower_top := opening if open > 0.0 else line
	var lower_bottom := PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		lower_bottom.append(lower_top[i] + Vector2(0.0, lt * pow(sin(u * PI), 0.65)))
	var lower := lower_top.duplicate()
	lower.append_array(_interior_reversed(lower_bottom))
	if mid:
		# Soft shadow under the lower lip and a lit philtrum above the bow.
		pen.fill_radial(lower_bottom[n / 2] + Vector2(0.2, 0.55), Vector2(1.7, 0.5), Color(shadow, 0.4))
		pen.fill_radial(upper_top[n / 2] + Vector2(0.15, -0.5), Vector2(0.45, 0.5), Color(InkPen.light_of(skin, 0.45), 0.6))
	if open > 0.0:
		var mouth := line.duplicate()
		mouth.append_array(_interior_reversed(opening))
		pen.fill_soft(mouth, Color("4a1022"))
		if open >= 0.6:
			var teeth_bottom := PackedVector2Array()
			for i in n:
				teeth_bottom.append(line[i] + Vector2(0, minf(open * 0.5, 0.75) * pow(sin(float(i) / (n - 1) * PI), 0.5)))
			var teeth := line.duplicate()
			teeth.append_array(_interior_reversed(teeth_bottom))
			pen.fill_clipped(teeth, mouth, Color("fffaf4"))
			if detail:
				pen.fill_clipped(InkPen.ellipse(mc + Vector2(0.2, open * 1.6), Vector2(1.4, 0.8), 12), mouth, Color("e5647e"))
	var lip_line := lip.darkened(0.5)
	if mid:
		pen.contour(lower, 0.12, Color(lip.darkened(0.35), 0.8), 0.6)
		pen.contour(upper, 0.12, Color(lip.darkened(0.4), 0.8), 0.6)
	pen.fill_lit(lower, InkPen.light_of(lip, 0.12), lip.darkened(0.08))
	pen.fill_lit(upper, lip.darkened(0.1), lip.darkened(0.26))
	if mid:
		# Lower-lip volume: darker toward the mouth line, then a soft gloss and a crisp sheen.
		pen.fill_feather(_band(lower_top, lower_bottom, 0.0, 0.3), Color(lip.darkened(0.3), 0.55), 0.18)
		var centre := lower_top[n / 2].lerp(lower_bottom[n / 2], 0.5) + Vector2(0.45, 0.0)
		pen.fill_radial(centre, Vector2(1.25 * size, 0.38 * size), Color(InkPen.light_of(lip, 0.55), 0.85))
		if detail:
			pen.fill_radial(centre + Vector2(0.25, -0.08), Vector2(0.45 * size, 0.13 * size), Color(1, 1, 1, 0.75), 0.0, 10, 0.4)
			pen.fill_radial(upper_top[n / 2 + 2] + Vector2(0.1, 0.25), Vector2(0.5, 0.12), Color(InkPen.light_of(lip, 0.5), 0.6))
	if open <= 0.0:
		pen.stroke(line, lip_line, 0.24, false, 0.9)
	# Corner tucks.
	if mid and (kind == "smile" or kind == "smirk" or kind == "grin"):
		pen.stroke(PackedVector2Array([nc + Vector2(-0.2, -0.05), nc + Vector2(0.3, -0.35)]), Color(lip_line, 0.7), 0.15, false, 0.5)
		pen.fill_radial(nc + Vector2(0.35, -0.2), Vector2(0.45, 0.45), Color(shadow, 0.35))
	elif mid:
		pen.dot(nc, 0.16, Color(lip_line, 0.6))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Tapered stroke whose colour runs from c0 at the start to c1 at the end (one mesh).
static func _gradient_stroke(pen: InkPen, path: PackedVector2Array, w0: float, w1: float, belly: float, c0: Color, c1: Color) -> void:
	var n := path.size()
	if n < 2:
		return
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for i in n:
		var u := float(i) / (n - 1)
		var a := path[maxi(i - 1, 0)]
		var b := path[mini(i + 1, n - 1)]
		var normal := (b - a).normalized().orthogonal()
		var half := (lerpf(w0, w1, u) + sin(u * PI) * belly) * 0.5
		points.append(path[i] + normal * half)
		points.append(path[i] - normal * half)
		var colour := c0.lerp(c1, minf(u * 2.5, 1.0))
		colours.append(colour)
		colours.append(colour)
	var indices := PackedInt32Array()
	for i in n - 1:
		var k := i * 2
		indices.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var length := 0.0
	for i in n - 1:
		length += path[i].distance_to(path[i + 1])
	pen.fill_mesh(points, indices, colours, length * maxf(w0, w1) * 0.6)


## The part of a lip between two of its edges: fraction f0..f1 of the way from `top` to `bottom`.
static func _band(top: PackedVector2Array, bottom: PackedVector2Array, f0: float, f1: float) -> PackedVector2Array:
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in range(1, top.size() - 1):
		a.append(top[i].lerp(bottom[i], f0))
		b.append(top[i].lerp(bottom[i], f1))
	b.reverse()
	a.append_array(b)
	return a


static func _reversed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.reverse()
	return result


static func _interior_reversed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size() - 2, 0, -1):
		result.append(points[i])
	return result
