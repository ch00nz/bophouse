class_name FacePainter
extends RefCounted
## Head and face layer (head-local coordinates: origin at the head centre, face turned 3/4 toward +x,
## chin at y ~ +9.8, crown at ~ -10).
##
## Western cartoon glamour: an adult heart-shaped face with a soft jaw, almond eyes of realistic
## size (never anime-large) with a lifted outer corner, defined arched brows, a small upturned nose
## and full lips with a cupid's bow. Makeup (lids, liner, lashes, blush, lip colour, highlight),
## freckles, lip filler and the nose stud come from the render spec.
##
## Expressions are data: lid openness per eye, brow raise, anger and a mouth shape. Portraits cycle
## them per pose; the creator's signature expression (render spec "expression") is the default.

const EXPRESSIONS := {
	"smile": {"lids": [1.0, 1.0], "mouth": "smile", "brows": [0.15, 0.15]},
	"grin": {"lids": [0.8, 0.8], "mouth": "grin", "brows": [0.35, 0.35]},
	"laugh": {"lids": [0.0, 0.0], "happy": [true, true], "mouth": "laugh", "brows": [0.55, 0.55]},
	"smirk": {"lids": [0.82, 0.88], "mouth": "smirk", "brows": [0.7, 0.0]},
	"sultry": {"lids": [0.52, 0.52], "mouth": "parted", "brows": [0.3, 0.3]},
	"wink": {"lids": [0.0, 0.95], "happy": [true, false], "mouth": "smirk", "brows": [-0.25, 0.45]},
	"kiss": {"lids": [0.55, 0.55], "mouth": "pout", "brows": [0.35, 0.35]},
	"talk": {"lids": [1.0, 1.0], "mouth": "talk", "brows": [0.25, 0.25]},
	"annoyed": {"lids": [0.72, 0.72], "mouth": "frown", "brows": [0.0, 0.0], "angry": 1.0},
	"sleep": {"lids": [0.0, 0.0], "mouth": "soft", "brows": [0.0, 0.0]},
	"soft": {"lids": [0.9, 0.9], "mouth": "soft", "brows": [0.2, 0.2]},
	"sad": {"lids": [0.68, 0.68], "mouth": "frown", "brows": [0.35, 0.35], "angry": -1.0},
	"surprised": {"lids": [1.0, 1.0], "mouth": "gasp", "brows": [1.1, 1.1]},
}

const HEAD_CTRL := [
	Vector2(0.6, -10.0), Vector2(5.6, -8.5), Vector2(8.6, -4.5), Vector2(9.25, -0.2), Vector2(8.9, 3.3),
	Vector2(7.3, 6.5), Vector2(4.9, 8.9), Vector2(2.9, 9.85), Vector2(1.0, 9.3), Vector2(-3.2, 7.0),
	Vector2(-6.4, 3.6), Vector2(-8.2, -0.6), Vector2(-7.9, -5.2), Vector2(-5.0, -8.7),
]
const NEAR_EYE := Vector2(5.0, 0.7)
const FAR_EYE := Vector2(-1.15, 0.7)
const EAR := Vector2(-7.6, 1.9)
## Where earrings hang (far ear lobe).
const EARLOBE := Vector2(-7.3, 4.1)
const SCLERA := Color("fffaf6")

static var _head: PackedVector2Array = PackedVector2Array()


static func head_shape() -> PackedVector2Array:
	if _head.is_empty():
		_head = InkPen.smooth_closed(PackedVector2Array(HEAD_CTRL), 4)
	return _head


## Resolved expression for this moment: blinking and talking are applied here.
## Returns {lids, happy, mouth, open, brows, angry, key}.
static func expression(name: String, t: float, seed: float) -> Dictionary:
	var def: Dictionary = EXPRESSIONS.get(name, EXPRESSIONS["smile"])
	var lids: Array = (def["lids"] as Array).duplicate()
	var happy: Array = (def.get("happy", [false, false]) as Array).duplicate()
	if name != "sleep" and fmod(t + seed, 4.3) < 0.13:
		for i in 2:
			if float(lids[i]) > 0.3:
				lids[i] = 0.0
				happy[i] = false
	var open := 0.0
	match str(def["mouth"]):
		"talk":
			open = [0.25, 0.75, 0.45, 0.6][int((t + seed) * 7.0) % 4]
		"grin":
			open = 0.9
		"laugh":
			open = 1.0 + 0.25 * absf(sin(t * 7.0))
		"parted":
			open = 0.3
		"pout":
			open = 0.25
		"gasp":
			open = 1.0
	open = snappedf(open, 0.125)
	var brows: Array = def["brows"]
	var result := {
		"lids": lids, "happy": happy, "mouth": str(def["mouth"]), "open": open,
		"brows": brows, "angry": float(def.get("angry", 0.0)),
	}
	result["key"] = "%s|%.2f|%.2f|%s|%s|%.3f" % [result["mouth"], lids[0], lids[1], happy[0], happy[1], open]
	return result


## Ear on the far side; drawn before the head so the jaw overlaps it.
static func draw_ear(pen: InkPen, skin: Color) -> void:
	var ear := InkPen.ellipse(EAR, Vector2(1.55, 2.4), 14, 0.15)
	pen.shape(ear, InkPen.shadow_of(skin, 0.12), 0.7)
	if pen.lod(2.0):
		pen.stroke(InkPen.arc(EAR + Vector2(0.2, 0.1), Vector2(0.8, 1.4), -1.2, 1.6, 6), InkPen.line_of(skin, 0.45), 0.2)


static func draw(pen: InkPen, spec: Dictionary, expr: Dictionary) -> void:
	var skin := PlaceholderArt.color(spec.get("skin"), Color("f1c6a5"))
	var shadow := InkPen.shadow_of(skin, 0.2)
	var hair := PlaceholderArt.color(spec.get("hair_color"), Color("6b3b2a"))
	var makeup: Dictionary = spec.get("makeup", {})
	var detail := pen.lod(1.9)
	var head := head_shape()

	pen.shape_lit(head, InkPen.light_of(skin, 0.06), skin.lerp(shadow, 0.35), 0.85)
	pen.shade(head, Vector2(2.0, -0.4), shadow)
	if detail:
		# Cheekbone glow and a soft contour under it (stronger with glam makeup).
		pen.fill_soft(InkPen.ellipse(Vector2(7.4, 1.5), Vector2(1.3, 0.6), 12, -0.3), InkPen.light_of(skin, 0.28))
		if bool(makeup.get("highlight", false)):
			pen.fill_soft(InkPen.taper(InkPen.quad(Vector2(8.7, 2.8), Vector2(7.6, 4.2), Vector2(6.0, 4.9), 6), 0.2, 0.9), skin.lerp(shadow, 0.55))
			pen.dot(Vector2(3.9, 3.0), 0.35, Color(1, 1, 1, 0.55))

	_blush(pen, makeup)
	if bool(spec.get("freckles", false)):
		_freckles(pen, shadow)
	_brows(pen, hair, expr)
	var iris := PlaceholderArt.color(spec.get("eyes"), Color("2f5d7c"))
	var lids: Array = expr["lids"]
	var happy: Array = expr["happy"]
	_eye(pen, NEAR_EYE, 2.3, 1.0, float(lids[0]), bool(happy[0]), iris, makeup, skin, detail)
	_eye(pen, FAR_EYE, 1.85, -1.0, float(lids[1]), bool(happy[1]), iris, makeup, skin, detail)
	_nose(pen, skin, shadow, detail)
	if (spec.get("piercings", []) as Array).has("nose"):
		pen.dot(Vector2(4.25, 4.0), 0.36, Color("ffe7a3"), 1.6)
		pen.dot(Vector2(4.15, 3.9), 0.14, Color.WHITE)
	_mouth(pen, spec, makeup, expr, detail)


# ---------------------------------------------------------------------------
# Features
# ---------------------------------------------------------------------------

static func _eye(pen: InkPen, c: Vector2, hw: float, o: float, open: float, happy: bool, iris: Color, makeup: Dictionary, skin: Color, detail: bool) -> void:
	var lash := Color("1c0f17")
	var glam := str(makeup.get("lashes", "natural")) == "glam"
	var lid_colour := PlaceholderArt.color(makeup.get("lids"), Color.TRANSPARENT)
	var inner := c + Vector2(-o * hw, 0.25)
	var outer := c + Vector2(o * hw, -0.35)
	if open < 0.12:
		if lid_colour.a > 0.0:
			var lid := InkPen.quad(inner + Vector2(0, -0.2), c + Vector2(o * 0.2 * hw, -2.6), outer + Vector2(0, -0.4), 8)
			lid.append_array(InkPen.quad(outer, c + Vector2(0, 0.8), inner, 8))
			pen.fill_soft(lid, skin.lerp(lid_colour, 0.6))
		if happy: # smiling eyes: an upward curve
			pen.fill(InkPen.taper(InkPen.quad(inner + Vector2(0, 0.4), c + Vector2(0, -1.7), outer + Vector2(0, 0.4), 8), 0.35, 0.65, 0.35), lash)
		else: # closed lid with lashes
			var lid_line := InkPen.quad(inner, c + Vector2(o * 0.1, 1.1), outer + Vector2(0, 0.2), 8)
			pen.fill(InkPen.taper(lid_line, 0.3, 0.7, 0.2), lash)
			if detail:
				for k in 3:
					var p := lid_line[5 + k]
					pen.fill(InkPen.taper(PackedVector2Array([p, p + Vector2(o * 0.5, 0.6 + k * 0.1)]), 0.25, 0.03), lash)
		return
	var up_h := 1.9 * open
	var upper := InkPen.quad(inner, Vector2(c.x + o * 0.18 * hw, c.y - 2.0 * up_h + 0.15), outer, 10)
	var lower := InkPen.quad(outer, Vector2(c.x + o * 0.05 * hw, c.y + 1.75), inner, 10)
	var sclera := upper.duplicate()
	sclera.append_array(lower)
	if lid_colour.a > 0.0:
		var crease := InkPen.quad(outer + Vector2(o * 0.4, -0.9), Vector2(c.x + o * 0.1 * hw, c.y - 2.0 * up_h - 2.2), inner + Vector2(0, -0.5), 10)
		var lid := upper.duplicate()
		lid.append_array(crease)
		pen.fill_soft(lid, skin.lerp(lid_colour, 0.72))
	pen.fill(sclera, SCLERA)
	var r := 1.22 * hw / 2.3
	# Both eyes look toward the viewer (the face is turned 3/4 toward +x).
	var iris_c := c + Vector2((0.02 if o > 0 else -0.2) * hw, 0.2 + (1.0 - open) * 0.25)
	var iris_shape := InkPen.ellipse(iris_c, Vector2(r * (0.92 if o > 0 else 0.8), r), 16)
	if detail:
		pen.fill_clipped(iris_shape, sclera, iris)
		pen.fill_clipped(InkPen.ellipse(iris_c + Vector2(0, r * 0.45), Vector2(r * 0.6, r * 0.4), 12), sclera, InkPen.light_of(iris, 0.3))
		pen.fill_clipped(InkPen.ellipse(iris_c, Vector2(r * 0.45, r * 0.5), 12), sclera, Color("140a10"))
		# Shadow of the upper lid on the eye.
		pen.fill_clipped(InkPen.taper(upper, 0.9, 0.9), sclera, Color(0.42, 0.24, 0.33, 0.35))
		pen.dot(iris_c + Vector2(o * 0.3 * r, -0.42 * r), 0.3 * r + 0.08, Color.WHITE)
		pen.dot(iris_c + Vector2(-o * 0.35 * r, 0.4 * r), 0.13 * r, Color(1, 1, 1, 0.8))
	else:
		pen.fill_clipped(iris_shape, sclera, iris.darkened(0.25))
	# Upper lash line: thin at the inner corner, bold at the outer corner.
	pen.fill(InkPen.taper(upper, 0.3, 1.05 if glam else 0.8, 0.15), lash)
	var wing := 1.6 if bool(makeup.get("liner", false)) else 0.75
	pen.fill(InkPen.taper(PackedVector2Array([outer + Vector2(-o * 0.4, -0.15), outer + Vector2(o * wing * 0.55, -wing * 0.4), outer + Vector2(o * wing, -wing * 0.7)]), 0.75, 0.05), lash)
	if detail:
		var lash_count := 4 if glam else 2
		for k in lash_count:
			var p := upper[upper.size() - 2 - k * 2]
			var dir := Vector2(o * (0.5 + 0.1 * k), -0.85).normalized()
			pen.fill(InkPen.taper(PackedVector2Array([p, p + dir * (0.7 + (0.35 if glam else 0.0)), p + dir * (1.0 + (0.5 if glam else 0.0)) + Vector2(o * 0.25, 0)]), 0.35, 0.03), lash)
		# Lower lash line (outer half) and the lid crease.
		var lower_outer := PackedVector2Array()
		for i in 6:
			lower_outer.append(lower[i])
		pen.stroke(lower_outer, Color(lash, 0.55), 0.2, false, 0.6)
		if lid_colour.a <= 0.0:
			pen.stroke(InkPen.quad(outer + Vector2(o * 0.2, -0.9), Vector2(c.x + o * 0.15 * hw, c.y - 2.0 * up_h - 1.4), c + Vector2(-o * hw * 0.3, -1.5), 8), InkPen.line_of(skin, 0.4), 0.16, false, 0.6)


static func _brows(pen: InkPen, hair: Color, expr: Dictionary) -> void:
	var brow := hair.darkened(0.3).lerp(InkPen.INK, 0.3)
	var raise: Array = expr["brows"]
	var angry := float(expr["angry"])
	var rn := float(raise[0])
	var rf := float(raise[1])
	var near := InkPen.quad(Vector2(3.0, -2.8 - rn * 0.6 + angry * 0.9), Vector2(5.4, -4.5 - rn), Vector2(7.8, -3.3 - rn * 0.7 - angry * 0.3), 8)
	var far := InkPen.quad(Vector2(0.75, -2.9 - rf * 0.6 + angry * 0.9), Vector2(-1.3, -4.2 - rf), Vector2(-3.4, -2.9 - rf * 0.7 - angry * 0.3), 8)
	pen.fill(InkPen.taper(near, 0.85, 0.25, 0.15), brow)
	pen.fill(InkPen.taper(far, 0.75, 0.22, 0.12), brow)


static func _nose(pen: InkPen, skin: Color, shadow: Color, detail: bool) -> void:
	pen.fill(InkPen.taper(InkPen.quad(Vector2(2.55, 0.9), Vector2(2.7, 2.6), Vector2(3.35, 3.6), 6), 0.05, 0.45), skin.lerp(shadow, 0.8))
	pen.stroke(InkPen.quad(Vector2(3.0, 4.15), Vector2(3.8, 4.65), Vector2(4.55, 3.95), 6), InkPen.line_of(skin, 0.5), 0.3, false, 0.9)
	if detail:
		pen.dot(Vector2(3.35, 4.05), 0.2, InkPen.line_of(skin, 0.4))
		pen.dot(Vector2(4.05, 3.25), 0.35, InkPen.light_of(skin, 0.45))


static func _blush(pen: InkPen, makeup: Dictionary) -> void:
	var amount := float(makeup.get("blush", 0.3))
	if amount <= 0.0:
		return
	var colour := Color(1.0, 0.38, 0.5, amount * 0.5)
	pen.fill(InkPen.ellipse(Vector2(6.7, 3.6), Vector2(2.0, 1.05), 14), colour)
	pen.fill(InkPen.ellipse(Vector2(-2.5, 3.7), Vector2(1.4, 0.95), 12), colour)


static func _freckles(pen: InkPen, shadow: Color) -> void:
	var freckle := Color(shadow.darkened(0.2), 0.75)
	for p: Vector2 in [Vector2(5.5, 2.4), Vector2(6.6, 2.9), Vector2(7.7, 2.4), Vector2(6.2, 1.9), Vector2(3.6, 2.6),
			Vector2(2.4, 2.2), Vector2(1.2, 2.6), Vector2(-0.4, 2.5), Vector2(-1.6, 2.9), Vector2(4.8, 3.0)]:
		pen.dot(p, 0.2, freckle, 0.9)


## Lips: an upper lip with a cupid's bow over the mouth line, a fuller lower lip, and an open mouth
## (teeth, tongue) for talking and laughing. Lip filler scales thickness.
static func _mouth(pen: InkPen, spec: Dictionary, makeup: Dictionary, expr: Dictionary, detail: bool) -> void:
	var size := float(spec.get("lip_size", 1.0))
	var lip := PlaceholderArt.color(makeup.get("lips"), Color("c2185b"))
	var kind := str(expr["mouth"])
	var open := float(expr["open"])
	var fc := Vector2(0.75, 6.55)
	var mc := Vector2(2.75, 6.95)
	var nc := Vector2(4.9, 6.4)
	var ut := 0.62 * size
	var lt := 0.95 * size
	match kind:
		"smile":
			fc = Vector2(0.65, 6.25)
			nc = Vector2(5.0, 6.0)
			mc = Vector2(2.75, 7.15)
		"smirk":
			fc = Vector2(0.8, 6.7)
			nc = Vector2(5.05, 5.9)
			mc = Vector2(2.8, 6.95)
		"pout":
			fc = Vector2(1.45, 6.55)
			nc = Vector2(4.2, 6.45)
			mc = Vector2(2.8, 6.7)
			ut *= 1.3
			lt *= 1.2
		"gasp":
			fc = Vector2(1.5, 6.5)
			nc = Vector2(4.1, 6.4)
			mc = Vector2(2.8, 6.4)
		"frown":
			fc = Vector2(0.8, 7.0)
			nc = Vector2(4.85, 6.95)
			mc = Vector2(2.75, 6.6)
		"grin":
			fc = Vector2(0.55, 6.15)
			nc = Vector2(5.15, 5.9)
			mc = Vector2(2.8, 6.85)
		"laugh":
			fc = Vector2(0.45, 6.0)
			nc = Vector2(5.3, 5.85)
			mc = Vector2(2.85, 6.6)
	var line := InkPen.quad(fc, mc, nc, 10)
	var n := line.size()
	var upper_top := PackedVector2Array()
	var opening := PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		var p := line[i]
		var bow := 1.0 - 0.32 * exp(-pow((p.x - mc.x) / 0.4, 2.0))
		upper_top.append(p - Vector2(0, ut * pow(sin(u * PI), 0.55) * bow + 0.05))
		opening.append(p + Vector2(0, open * 1.9 * pow(sin(u * PI), 0.8)))
	# Lip shapes share their corner points, so the closing edges use interior points only.
	var upper := line.duplicate()
	upper.append_array(_interior_reversed(upper_top))
	var lower_top := opening if open > 0.0 else line
	var lower_bottom := PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		lower_bottom.append(lower_top[i] + Vector2(0.0, lt * pow(sin(u * PI), 0.7)))
	var lower := lower_top.duplicate()
	lower.append_array(_interior_reversed(lower_bottom))
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
	pen.fill_soft(lower, lip)
	pen.fill_soft(upper, lip.darkened(0.14))
	if detail:
		pen.fill_soft(InkPen.ellipse(lower_top[n / 2] + Vector2(0.55, lt * 0.42), Vector2(0.75 * size, 0.2 * size), 10), InkPen.light_of(lip, 0.55))
		pen.stroke(lower_bottom, lip.darkened(0.3), 0.14, false, 0.5)
	if open <= 0.0:
		pen.stroke(line, lip.darkened(0.55), 0.3, false, 0.9)
	# Corner tucks give the smile its shape.
	if detail and (kind == "smile" or kind == "smirk"):
		pen.stroke(PackedVector2Array([nc + Vector2(-0.15, -0.1), nc + Vector2(0.35, -0.35)]), lip.darkened(0.45), 0.18, false, 0.5)


static func _interior_reversed(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(points.size() - 2, 0, -1):
		result.append(points[i])
	return result
