class_name HairPainter
extends RefCounted
## Hairstyle layers (head-local coordinates, see FacePainter). Each style has a BACK layer (drawn
## behind the body: the long mass, ponytail, far bun) and a FRONT layer (crown, fringe/bangs and
## locks over the shoulder, drawn over the face). Styles are registered by id in STYLES; adding a
## hairstyle means adding control points here plus an entry in data/appearance.json.
##
## Rendering: bold outline, gradient fill, a darker under-layer, flowing strand lines, a glossy
## shine band on the crown, and the fringe casting a soft shadow on the forehead.
## The back layer is drawn under a swing transform by the renderer (hair moves with the pose).

const STYLES := ["long_waves", "high_ponytail", "bob", "curls", "space_buns"]

const LONG_WAVES_BACK := [
	Vector2(-0.5, -11.8), Vector2(6.4, -10.6), Vector2(10.4, -5.8), Vector2(11.6, 1.0), Vector2(11.2, 8.0),
	Vector2(12.9, 14.0), Vector2(12.1, 20.0), Vector2(13.4, 26.0), Vector2(12.0, 32.0), Vector2(12.4, 37.0),
	Vector2(9.2, 39.6), Vector2(5.0, 37.4), Vector2(1.0, 40.2), Vector2(-3.2, 37.8), Vector2(-7.4, 40.4),
	Vector2(-11.2, 37.4), Vector2(-13.8, 31.0), Vector2(-12.9, 24.0), Vector2(-14.6, 17.0), Vector2(-13.4, 9.0),
	Vector2(-12.6, 2.0), Vector2(-11.8, -5.0), Vector2(-7.8, -10.2),
]
const LONG_WAVES_FRONT := [
	Vector2(-9.2, 3.6), Vector2(-9.9, -3.6), Vector2(-7.2, -9.9), Vector2(-0.8, -12.3), Vector2(5.9, -10.9),
	Vector2(9.8, -6.7), Vector2(10.7, -1.4), Vector2(10.3, 1.6), Vector2(8.9, -0.8), Vector2(7.3, -3.6),
	Vector2(4.2, -5.6), Vector2(0.8, -6.6), Vector2(-2.2, -8.6), Vector2(-4.9, -6.6), Vector2(-6.9, -2.6),
	Vector2(-7.5, 2.8),
]
const LONG_WAVES_LOCK := [
	Vector2(8.0, -2.4), Vector2(10.9, -0.8), Vector2(12.2, 5.0), Vector2(12.0, 10.5), Vector2(13.4, 15.5),
	Vector2(12.9, 20.5), Vector2(11.2, 23.6), Vector2(11.3, 18.5), Vector2(10.2, 13.0), Vector2(9.6, 7.0), Vector2(8.4, 2.0),
]
const SLEEK_CAP := [
	Vector2(-9.0, 3.0), Vector2(-9.6, -3.8), Vector2(-7.0, -9.8), Vector2(-0.8, -11.9), Vector2(5.8, -10.6),
	Vector2(9.3, -6.6), Vector2(9.9, -2.4), Vector2(9.0, -1.4), Vector2(8.2, -4.6), Vector2(5.6, -6.9),
	Vector2(2.0, -7.9), Vector2(-1.8, -7.8), Vector2(-5.2, -6.0), Vector2(-7.0, -2.2), Vector2(-7.4, 2.8),
]
const PONYTAIL := [
	Vector2(-4.6, -12.6), Vector2(-8.4, -13.8), Vector2(-12.6, -11.2), Vector2(-15.0, -4.0), Vector2(-15.8, 4.0),
	Vector2(-14.8, 12.0), Vector2(-12.6, 19.8), Vector2(-12.9, 12.0), Vector2(-12.3, 4.0), Vector2(-10.6, -3.0),
	Vector2(-8.0, -8.4), Vector2(-5.6, -9.6),
]
const BOB_BACK := [
	Vector2(-0.8, -11.8), Vector2(6.2, -10.6), Vector2(10.4, -5.8), Vector2(11.4, 1.0), Vector2(11.1, 7.6),
	Vector2(9.2, 10.9), Vector2(4.8, 10.4), Vector2(-1.0, 11.4), Vector2(-7.6, 11.2), Vector2(-11.8, 8.2),
	Vector2(-12.3, 1.0), Vector2(-11.2, -5.6), Vector2(-7.4, -10.2),
]
const BOB_FRONT := [
	Vector2(-10.9, 8.4), Vector2(-10.6, -3.8), Vector2(-7.4, -10.0), Vector2(-0.8, -12.3), Vector2(5.9, -11.0),
	Vector2(9.9, -6.8), Vector2(11.2, -0.6), Vector2(11.5, 5.8), Vector2(10.2, 10.2), Vector2(8.9, 9.2),
	Vector2(9.3, 4.6), Vector2(9.0, -0.2), Vector2(7.6, -4.0), Vector2(4.6, -4.7), Vector2(1.4, -4.4),
	Vector2(-1.8, -4.9), Vector2(-4.8, -4.3), Vector2(-6.9, -1.0), Vector2(-7.7, 4.6), Vector2(-9.1, 8.8),
]
const CURLS_CAP := [
	Vector2(-9.4, 3.6), Vector2(-10.0, -3.6), Vector2(-7.4, -9.9), Vector2(-0.8, -12.4), Vector2(5.9, -11.0),
	Vector2(9.8, -6.8), Vector2(10.6, -2.0), Vector2(8.6, -3.6), Vector2(5.4, -5.2), Vector2(1.8, -6.0),
	Vector2(-1.8, -6.2), Vector2(-5.0, -5.0), Vector2(-7.0, -1.6), Vector2(-7.6, 3.0),
]
const CURLS_FRINGE := [
	[Vector2(8.8, -4.4), 2.6], [Vector2(6.0, -6.4), 2.8], [Vector2(2.8, -7.6), 2.8], [Vector2(-0.6, -7.8), 2.7],
	[Vector2(-3.8, -7.0), 2.6], [Vector2(-6.4, -4.6), 2.5], [Vector2(10.6, -0.6), 2.4], [Vector2(11.2, 3.6), 2.3],
	[Vector2(11.5, 7.8), 2.2], [Vector2(11.0, 12.0), 2.0], [Vector2(11.6, 16.0), 1.9], [Vector2(-8.8, 1.8), 2.4],
	[Vector2(-9.6, 6.0), 2.2], [Vector2(-9.8, 10.0), 2.0],
]
const BUNS_BACK := [
	Vector2(-0.6, -11.6), Vector2(6.0, -10.4), Vector2(10.0, -5.6), Vector2(10.9, 1.6), Vector2(10.6, 10.0),
	Vector2(11.6, 19.0), Vector2(10.8, 24.4), Vector2(6.0, 23.0), Vector2(0.0, 24.2), Vector2(-6.0, 23.0),
	Vector2(-11.2, 24.4), Vector2(-12.6, 16.0), Vector2(-12.4, 6.0), Vector2(-11.4, -4.0), Vector2(-7.4, -9.8),
]
const BUNS_CAP := [
	Vector2(-9.0, 3.0), Vector2(-9.6, -3.8), Vector2(-7.0, -9.8), Vector2(-0.8, -11.9), Vector2(5.8, -10.6),
	Vector2(9.3, -6.6), Vector2(9.9, -2.0), Vector2(9.0, -1.2), Vector2(8.0, -4.6), Vector2(5.6, -6.6),
	Vector2(2.6, -7.8), Vector2(1.2, -8.5), Vector2(-0.6, -7.8), Vector2(-4.6, -6.4), Vector2(-6.8, -2.6), Vector2(-7.4, 2.8),
]

## Refined style (RenderStyle) for the look being drawn: hair-toned outline and RefinedHair passes.
static var _refined: bool = false


static func palette(spec: Dictionary) -> Dictionary:
	var base := PlaceholderArt.color(spec.get("hair_color"), Color("6b3b2a"))
	return {
		"base": base, "light": InkPen.light_of(base, 0.22), "shine": InkPen.light_of(base, 0.5).lerp(Color("fff4e8"), 0.15),
		"shadow": InkPen.shadow_of(base, 0.34), "deep": InkPen.shadow_of(base, 0.5), "line": base.lerp(InkPen.INK, 0.5),
	}


static func style_of(spec: Dictionary) -> String:
	var style := str(spec.get("hair_style", "long_waves"))
	return style if STYLES.has(style) else "long_waves"


# ---------------------------------------------------------------------------
# Back layer (behind the body)
# ---------------------------------------------------------------------------

static func draw_back(pen: InkPen, spec: Dictionary) -> void:
	var c := palette(spec)
	var detail := pen.lod(1.9)
	_begin(pen, spec, c)
	match style_of(spec):
		"high_ponytail":
			var tail := _curve(PONYTAIL)
			pen.shape_lit(tail, c["base"], c["shadow"])
			pen.shade(tail, Vector2(1.4, -0.6), c["shadow"])
			if detail:
				for path in [[Vector2(-7.0, -12.0), Vector2(-12.4, -6.0), Vector2(-13.8, 4.0), Vector2(-13.0, 15.0)],
						[Vector2(-9.0, -11.0), Vector2(-11.0, -2.0), Vector2(-12.6, 10.0)]]:
					pen.stroke(InkPen.smooth_open(PackedVector2Array(path), 4), c["line"], 0.25, false, 0.6)
				pen.fill(InkPen.taper(InkPen.smooth_open(PackedVector2Array([Vector2(-10.6, -10.6), Vector2(-13.4, -4.0), Vector2(-14.0, 3.0)]), 4), 0.4, 0.2, 0.7), c["shine"])
		"bob":
			var back := _curve(BOB_BACK)
			pen.shape_lit(back, c["shadow"], c["deep"])
		"curls":
			var parts: Array = [[InkPen.ellipse(Vector2(-0.5, 8.0), Vector2(12.6, 20.5), 24), c["base"], c["shadow"]]]
			for i in 18:
				var a := TAU * i / 18.0
				var centre := Vector2(-0.5, 8.0) + Vector2(cos(a) * 12.6, sin(a) * 20.5)
				parts.append([InkPen.ellipse(centre, Vector2(4.6, 4.6) * (0.9 + 0.12 * sin(i * 2.3)), 14), c["base"], c["shadow"]])
			pen.group(parts)
			if detail:
				# Loose S-shaped strands instead of a ring per curl, so the mass reads as hair.
				for i in 7:
					var a := TAU * (i + 0.3) / 7.0
					var centre := Vector2(-0.5, 8.0) + Vector2(cos(a) * 9.5, sin(a) * 16.0)
					var path := InkPen.smooth_open(PackedVector2Array([centre + Vector2(-1.2, -2.4), centre + Vector2(1.0, -0.6), centre + Vector2(-0.8, 1.2), centre + Vector2(1.0, 3.0)]), 3)
					pen.stroke(path, c["line"], 0.26, false, 0.6)
				pen.fill(InkPen.taper(InkPen.arc(Vector2(-0.5, 8.0), Vector2(11.0, 18.0), PI * 1.15, PI * 1.35, 6), 0.3, 0.3, 1.0), c["light"])
		"space_buns":
			var back := _curve(BUNS_BACK)
			pen.shape_lit(back, c["base"], c["shadow"])
			pen.shade(back, Vector2(1.6, -0.8), c["shadow"])
			_bun(pen, Vector2(-5.8, -12.8), 4.6, c, detail)
			if detail:
				_strands(pen, c, [[Vector2(10.0, 0.0), Vector2(10.8, 10.0), Vector2(10.8, 22.0)], [Vector2(-11.0, 0.0), Vector2(-11.6, 12.0), Vector2(-11.2, 22.0)]])
		_:
			var back := _curve(LONG_WAVES_BACK)
			pen.shape_lit(back, c["base"], c["shadow"])
			pen.shade(back, Vector2(1.8, -0.8), c["shadow"])
			if detail:
				_strands(pen, c, [
					[Vector2(10.4, -2.0), Vector2(11.0, 8.0), Vector2(11.6, 18.0), Vector2(11.0, 30.0), Vector2(10.6, 36.0)],
					[Vector2(-11.2, -2.0), Vector2(-12.0, 10.0), Vector2(-12.8, 22.0), Vector2(-12.0, 33.0)],
					[Vector2(-8.0, 6.0), Vector2(-9.4, 18.0), Vector2(-8.4, 30.0), Vector2(-9.0, 37.0)],
					[Vector2(8.6, 6.0), Vector2(9.8, 18.0), Vector2(8.8, 30.0), Vector2(7.6, 36.0)],
				])
				pen.fill(InkPen.taper(InkPen.smooth_open(PackedVector2Array([Vector2(11.6, 10.0), Vector2(12.2, 18.0), Vector2(12.0, 26.0)]), 4), 0.3, 0.2, 0.8), c["light"])
	# Depth behind the neck.
	pen.fill_clipped(InkPen.ellipse(Vector2(0.4, 6.0), Vector2(9.5, 9.0), 18), _back_shape(spec), c["deep"])
	if _refined:
		var mass := _back_shape(spec) if style_of(spec) != "high_ponytail" else _curve(PONYTAIL)
		RefinedHair.back_extra(pen, mass, c)
	pen.ink = InkPen.INK


static func _back_shape(spec: Dictionary) -> PackedVector2Array:
	match style_of(spec):
		"high_ponytail":
			return PackedVector2Array()
		"bob":
			return _curve(BOB_BACK)
		"curls":
			return InkPen.ellipse(Vector2(-0.5, 8.0), Vector2(12.6, 20.5), 24)
		"space_buns":
			return _curve(BUNS_BACK)
	return _curve(LONG_WAVES_BACK)


# ---------------------------------------------------------------------------
# Front layer (over the face)
# ---------------------------------------------------------------------------

static func draw_front(pen: InkPen, spec: Dictionary) -> void:
	var c := palette(spec)
	var detail := pen.lod(1.9)
	var skin := PlaceholderArt.color(spec.get("skin"), Color("f1c6a5"))
	var head := FacePainter.head_shape()
	_begin(pen, spec, c)
	if _refined:
		head = RefinedFace.head_shape()
	match style_of(spec):
		"high_ponytail":
			var cap := _curve(SLEEK_CAP)
			_fringe_shadow(pen, cap, head, skin)
			_crown(pen, cap, c)
			# Scrunchie where the ponytail is tied.
			pen.shape(InkPen.ellipse(Vector2(-5.8, -10.6), Vector2(1.7, 2.1), 14, 0.5), Color("ff4f8b"), 0.6)
			if detail:
				pen.stroke(InkPen.arc(Vector2(-5.8, -10.6), Vector2(1.0, 1.4), 0.5, 3.6, 6), Color("ff9ec4"), 0.25)
				_strands(pen, c, [[Vector2(8.4, -4.8), Vector2(5.0, -9.0), Vector2(-1.8, -11.0), Vector2(-5.2, -10.8)],
					[Vector2(2.0, -7.9), Vector2(-1.0, -9.8), Vector2(-4.6, -10.4)], [Vector2(-6.8, -1.0), Vector2(-7.9, -6.0), Vector2(-6.4, -9.6)]])
			_wisp(pen, [Vector2(9.4, -3.4), Vector2(10.7, 1.4), Vector2(9.8, 6.6)], c)
			_wisp(pen, [Vector2(-7.2, -1.2), Vector2(-8.3, 3.0), Vector2(-7.5, 6.8)], c)
		"bob":
			var front := _curve(BOB_FRONT)
			_fringe_shadow(pen, front, head, skin)
			_crown(pen, front, c)
			if detail:
				_strands(pen, c, [[Vector2(5.8, -9.2), Vector2(5.5, -5.2)], [Vector2(2.2, -9.8), Vector2(2.0, -5.0)],
					[Vector2(-1.4, -9.6), Vector2(-1.6, -5.4)], [Vector2(-4.6, -8.6), Vector2(-5.0, -4.9)],
					[Vector2(10.2, -2.0), Vector2(10.7, 4.0), Vector2(9.9, 8.8)], [Vector2(-9.2, -2.0), Vector2(-9.6, 4.0), Vector2(-9.8, 8.0)]])
		"curls":
			var cap := _curve(CURLS_CAP)
			_fringe_shadow(pen, cap, head, skin)
			var parts: Array = [[cap, c["light"], c["base"]]]
			for curl: Array in CURLS_FRINGE:
				parts.append([InkPen.ellipse(curl[0], Vector2(float(curl[1]), float(curl[1])), 14), c["light"], c["base"]])
			pen.group(parts)
			pen.shade(cap, Vector2(1.6, 0.8), c["shadow"])
			if detail:
				for k in CURLS_FRINGE.size():
					var curl: Array = CURLS_FRINGE[k]
					var r := float(curl[1])
					pen.stroke(InkPen.arc(curl[0], Vector2(r * 0.55, r * 0.55), 0.9 + k, 3.4 + k, 6), c["shadow"], 0.24, false, 0.6)
					if k % 3 == 0:
						pen.fill(InkPen.taper(InkPen.arc(curl[0], Vector2(r * 0.6, r * 0.6), 3.7, 4.9, 4), 0.2, 0.2, 0.5), c["shine"])
			_shine(pen, c)
		"space_buns":
			var cap := _curve(BUNS_CAP)
			_fringe_shadow(pen, cap, head, skin)
			_crown(pen, cap, c)
			_bun(pen, Vector2(4.4, -13.6), 5.0, c, detail)
			_wisp(pen, [Vector2(9.2, -3.5), Vector2(10.5, 1.0), Vector2(9.6, 5.0), Vector2(10.5, 9.4)], c)
			_wisp(pen, [Vector2(-7.0, -1.5), Vector2(-8.3, 2.5), Vector2(-7.4, 6.5), Vector2(-8.1, 10.0)], c)
			if detail:
				_strands(pen, c, [[Vector2(1.2, -8.4), Vector2(3.4, -11.0)], [Vector2(1.2, -8.4), Vector2(-2.6, -11.2), Vector2(-5.0, -11.4)]])
		_:
			var front := _curve(LONG_WAVES_FRONT)
			var lock := _curve(LONG_WAVES_LOCK)
			_fringe_shadow(pen, front, head, skin)
			pen.group([[front, c["light"], c["base"]], [lock, c["light"], c["base"]]])
			pen.shade(front, Vector2(1.6, 0.8), c["shadow"])
			pen.shade(lock, Vector2(-1.0, -0.4), c["shadow"])
			if detail:
				_strands(pen, c, [[Vector2(-2.0, -10.6), Vector2(2.6, -8.8), Vector2(6.6, -6.2), Vector2(9.2, -2.2)],
					[Vector2(-0.4, -9.0), Vector2(3.4, -7.2), Vector2(6.4, -4.6)], [Vector2(-4.6, -9.6), Vector2(-6.9, -5.0), Vector2(-7.7, 0.8)],
					[Vector2(10.0, 0.0), Vector2(11.0, 8.0), Vector2(11.9, 15.0), Vector2(11.9, 21.0)]])
				pen.fill(InkPen.taper(InkPen.smooth_open(PackedVector2Array([Vector2(11.1, 4.0), Vector2(11.2, 9.0), Vector2(12.0, 14.0)]), 3), 0.25, 0.15, 0.7), c["shine"])
			_shine(pen, c)
	if _refined:
		RefinedHair.front_extra(pen, front_masses(spec), c)
	pen.ink = InkPen.INK


## The crown/fringe shapes of the front layer (refined passes are clipped to them).
static func front_masses(spec: Dictionary) -> Array:
	match style_of(spec):
		"high_ponytail":
			return [_curve(SLEEK_CAP)]
		"bob":
			return [_curve(BOB_FRONT)]
		"curls":
			return [_curve(CURLS_CAP)]
		"space_buns":
			return [_curve(BUNS_CAP)]
	return [_curve(LONG_WAVES_FRONT), _curve(LONG_WAVES_LOCK)]


static func _begin(pen: InkPen, spec: Dictionary, c: Dictionary) -> void:
	_refined = RenderStyle.refined(spec)
	if _refined:
		pen.ink = RefinedHair.outline(c)


static func _crown(pen: InkPen, shape: PackedVector2Array, c: Dictionary) -> void:
	pen.shape_lit(shape, c["light"], c["base"])
	pen.shade(shape, Vector2(1.6, 0.8), c["shadow"])
	_shine(pen, c)


static func _shine(pen: InkPen, c: Dictionary) -> void:
	if _refined:
		RefinedHair.sheen(pen, c)
		return
	pen.fill(InkPen.taper(InkPen.quad(Vector2(-4.4, -9.2), Vector2(0.8, -11.9), Vector2(5.6, -9.6), 10), 0.35, 0.35, 0.95), c["shine"])
	if pen.lod(1.9):
		pen.fill(InkPen.taper(InkPen.quad(Vector2(6.6, -8.6), Vector2(7.6, -7.6), Vector2(8.3, -6.2), 4), 0.4, 0.1), c["shine"])


static func _fringe_shadow(pen: InkPen, hair_shape: PackedVector2Array, head: PackedVector2Array, skin: Color) -> void:
	if _refined: # a soft shadow: two translucent steps
		var shadow := RefinedBody.warm_shadow(skin, 0.35)
		pen.fill_clipped(InkPen.translated(hair_shape, Vector2(0.3, 1.5)), head, Color(shadow, 0.3))
		pen.fill_clipped(InkPen.translated(hair_shape, Vector2(0.2, 0.75)), head, Color(shadow, 0.45))
		return
	pen.fill_clipped(InkPen.translated(hair_shape, Vector2(0.3, 1.1)), head, InkPen.shadow_of(skin, 0.3))


static func _bun(pen: InkPen, centre: Vector2, r: float, c: Dictionary, detail: bool) -> void:
	var bun := InkPen.ellipse(centre, Vector2(r, r * 0.92), 18)
	pen.shape_lit(bun, c["light"], c["base"])
	pen.shade(bun, Vector2(1.2, -0.8), c["shadow"])
	if detail:
		pen.stroke(InkPen.arc(centre, Vector2(r * 0.62, r * 0.55), 0.3, 4.6, 10), c["shadow"], 0.3, false, 0.6)
		pen.stroke(InkPen.arc(centre + Vector2(0.4, 0.2), Vector2(r * 0.3, r * 0.26), 2.0, 6.0, 8), c["shadow"], 0.28, false, 0.6)
	pen.fill(InkPen.taper(InkPen.arc(centre, Vector2(r * 0.7, r * 0.66), 3.6, 4.9, 6), 0.3, 0.3, 0.6), c["shine"])


static func _wisp(pen: InkPen, points: Array, c: Dictionary) -> void:
	var path := InkPen.smooth_open(PackedVector2Array(points), 4)
	pen.fill(InkPen.taper(path, 0.95, 0.05), c["line"])
	pen.fill(InkPen.taper(path, 0.55, 0.02), c["base"])


static func _strands(pen: InkPen, c: Dictionary, paths: Array) -> void:
	for path: Array in paths:
		if _refined:
			pen.stroke(InkPen.smooth_open(PackedVector2Array(path), 4), Color(c["line"], 0.5), 0.14, false, 0.6)
			continue
		pen.stroke(InkPen.smooth_open(PackedVector2Array(path), 4), Color(c["line"], 0.75), 0.24, false, 0.6)


static func _curve(points: Array) -> PackedVector2Array:
	return InkPen.smooth_closed(PackedVector2Array(points), 3)
