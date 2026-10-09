class_name OutfitPainter
extends RefCounted
## Outfit layers, all data-driven from data/appearance.json (outfit options):
##   "pieces": torso garments drawn in order (bottoms first). Kinds:
##      top     band from `from` to `to` (landmarks, see FigureModel.LANDMARKS) covering the bust,
##              cut by a `neckline` (high, scoop, sweetheart, straight, v); `straps` thin|wide
##      dress   like top but continues below the crotch to `to` = "leg:<fraction>" with `flare`
##      skirt   waistband at `from`, hem at `to`, `flare`, optional `pleats`
##      briefs  from `from` to the crotch; `cut` high|bikini|full; optional `ties`
##      bra     `style` triangle|balconette cups that follow each breast
##     Fabric: `color`, `trim`, `pattern` (sequins, satin, lace, ribbed, denim, plaid + `plaid` colour),
##     `lacing` (corset front).
##   "legwear": {type stockings|fishnets|leggings|socks, from (leg fraction), color, trim, garters}
##   "shoes": {type heels|sneakers|boots|sandals, color, trim}
## Garments are cut from the same body contours as the skin (FigureModel), so every outfit follows
## bust, waist, hip and seat changes from measurements and procedures. Presentation stays
## non-explicit: tops, bras and briefs always cover the chest and groin.

const FABRIC_GROW := 0.35


# ---------------------------------------------------------------------------
# Torso garments (pose independent: baked once, replayed with the hip sway)
# ---------------------------------------------------------------------------

static func draw_torso_garments(pen: InkPen, model: FigureModel, outfit: Dictionary, skin: Color) -> void:
	for piece: Dictionary in pieces(outfit):
		match str(piece.get("kind", "top")):
			"skirt":
				_skirt(pen, model, piece)
			"briefs":
				_briefs(pen, model, piece)
			"bra":
				_bra(pen, model, piece, skin)
			_:
				_top(pen, model, piece)


## Pieces for an outfit, including older top/bottom data (pre-5A saves and mods).
static func pieces(outfit: Dictionary) -> Array:
	if outfit.has("pieces"):
		return outfit["pieces"]
	var result: Array = []
	if outfit.has("bottom"):
		var bottom: Dictionary = (outfit["bottom"] as Dictionary).duplicate()
		bottom["kind"] = "skirt"
		result.append(bottom)
	if outfit.has("top"):
		var top: Dictionary = (outfit["top"] as Dictionary).duplicate()
		top["kind"] = "top"
		result.append(top)
	return result


## Lowest y the outfit covers on the body (thigh tattoos below it stay visible).
static func coverage_bottom(outfit: Dictionary) -> float:
	var lowest := -200.0
	for piece: Dictionary in pieces(outfit):
		var kind := str(piece.get("kind", "top"))
		var to := FigureModel.CROTCH_Y if kind == "briefs" or kind == "bra" else FigureModel.landmark(piece.get("to", "crotch"), FigureModel.CROTCH_Y)
		lowest = maxf(lowest, to)
	return lowest


static func _colours(piece: Dictionary) -> Dictionary:
	var base := PlaceholderArt.color(piece.get("color"), Color("e0457b"))
	base.a = 1.0
	return {
		"base": base, "lit": InkPen.light_of(base, 0.1), "shade": InkPen.shadow_of(base, 0.14),
		"shadow": InkPen.shadow_of(base, 0.32), "light": InkPen.light_of(base, 0.3),
		"trim": PlaceholderArt.color(piece.get("trim"), InkPen.shadow_of(base, 0.4)),
		"line": InkPen.line_of(base, 0.45),
	}


static func _top(pen: InkPen, model: FigureModel, piece: Dictionary) -> void:
	var c := _colours(piece)
	var y0 := FigureModel.landmark(piece.get("from", "shoulder"), FigureModel.SHOULDER_Y)
	var y1 := FigureModel.landmark(piece.get("to", "crotch"), FigureModel.CROTCH_Y)
	var flare := float(piece.get("flare", 0.0))
	var raw := model.band(y0, y1, FABRIC_GROW, flare)
	var covers_bust := y0 < -80.0 and y1 > -82.0
	if covers_bust:
		for i in 2:
			raw = _union(raw, model.breast_shape(i, 0.45))
	var neckline := str(piece.get("neckline", "high"))
	var shapes := Geometry2D.intersect_polygons(raw, _neck_mask(model, neckline))
	for shape in shapes:
		if not _is_outer(shape, raw):
			continue
		pen.shape_lit(shape, c["lit"], c["shade"], 0.75)
		pen.shade(shape, Vector2(1.9, -0.2), c["shadow"])
		if covers_bust:
			_bust_shading(pen, model, shape, c)
		_pattern(pen, model, shape, piece, c, y0, y1)
		# Trim along the neckline and hem.
		pen.stroke_clipped(_neck_edge(model, neckline, 0.45), shape, c["trim"], 0.5)
		pen.stroke_clipped(_hem_line(model, y1 - 0.45, flare), shape, c["trim"], 0.5)
		if bool(piece.get("lacing", false)):
			_lacing(pen, model, shape, c, y1)
	_straps(pen, model, piece, neckline, c)


static func _skirt(pen: InkPen, model: FigureModel, piece: Dictionary) -> void:
	var c := _colours(piece)
	var y0 := FigureModel.landmark(piece.get("from", "low_waist"), -62.5)
	var y1 := FigureModel.landmark(piece.get("to", "leg:0.28"), -40.0)
	var flare := float(piece.get("flare", 2.0))
	var shape := model.band(y0, y1, FABRIC_GROW + 0.1, flare)
	pen.shape_lit(shape, c["lit"], c["shade"], 0.75)
	pen.shade(shape, Vector2(2.0, -0.3), c["shadow"])
	if bool(piece.get("pleats", false)) or str(piece.get("pattern", "")) == "plaid":
		var count := 7
		for k in count:
			var u := (k + 0.5) / count
			var top := Vector2(lerpf(model.far_x(y0 + 2.0), model.near_x(y0 + 2.0), u), y0 + 2.0)
			var bottom := Vector2(lerpf(model.far_x(FigureModel.CROTCH_Y) - flare - 1.0, model.near_x(FigureModel.CROTCH_Y) + flare + 0.5, u), y1)
			pen.stroke_clipped(PackedVector2Array([top, bottom]), shape, c["line"], 0.22, 0.6)
			if k % 2 == 0:
				pen.fill_clipped(PackedVector2Array([top, top + Vector2(1.2, 0), bottom + Vector2(1.6, 0), bottom]), shape, c["shade"])
	_pattern(pen, model, shape, piece, c, y0, y1)
	# Waistband and hem.
	var band := model.band(y0, y0 + 1.5, FABRIC_GROW + 0.2)
	pen.shape(band, c["base"].darkened(0.1), 0.5)
	pen.stroke_clipped(_hem_line(model, y1 - 0.5, flare, true), shape, c["trim"], 0.55)
	if str(piece.get("pattern", "")) == "denim":
		var bx := (model.near_x(y0) + model.far_x(y0)) * 0.5 + 2.0
		pen.shape(InkPen.ellipse(Vector2(bx, y0 + 0.75), Vector2(0.55, 0.55), 10), Color("e9c46a"), 0.25)
		pen.stroke_clipped(InkPen.smooth_open(PackedVector2Array([Vector2(bx + 0.3, y0 + 1.6), Vector2(bx + 0.9, y0 + 5.0), Vector2(bx + 0.6, -50.0)]), 3), shape, c["trim"], 0.18, 0.5)


static func _briefs(pen: InkPen, model: FigureModel, piece: Dictionary) -> void:
	var c := _colours(piece)
	var y0 := FigureModel.landmark(piece.get("from", "low_waist"), -62.5)
	var cut := str(piece.get("cut", "high"))
	# A "full" cut is the top of leggings/pants: it continues into the legwear without a hem line.
	var g := 0.02 if cut == "full" else FABRIC_GROW
	var poly := PackedVector2Array()
	var side := FigureModel.CROTCH_Y if cut == "full" else y0 + (1.4 if cut == "bikini" else 2.4)
	var y := y0
	while y < side:
		poly.append(Vector2(model.near_x(y) + g, y))
		y += 1.0
	poly.append(Vector2(model.near_x(side) + g, side))
	var nx := model.near_x(side)
	var fx := model.far_x(side)
	if cut == "full":
		poly.append_array(PackedVector2Array([Vector2(5.4 * model.hips + g, -46.2), Vector2(0.6, -45.0), Vector2(-4.4 * model.hips - g, -46.2)]))
	else:
		var narrow := 0.75 if cut == "bikini" else 1.0
		poly.append_array(InkPen.quad(Vector2(nx + g, side), Vector2(nx - 3.6, -48.8), Vector2(2.6 * narrow, -46.0), 6))
		poly.append(Vector2(0.6, -45.2))
		# The back of the briefs covers the seat (the far side is her back in the 3/4 view).
		var seat := -51.0
		poly.append_array(InkPen.quad(Vector2(-2.0 * narrow, -45.8), Vector2(model.far_x(seat) + 1.6, -46.4), Vector2(model.far_x(seat) - g, seat), 6))
		side = seat
	y = side
	while y > y0:
		poly.append(Vector2(model.far_x(y) - g, y))
		y -= 1.0
	poly.append(Vector2(model.far_x(y0) - g, y0))
	if cut == "full":
		pen.fill_lit(poly, InkPen.light_of(c["base"], 0.08), InkPen.shadow_of(c["base"], 0.12))
		pen.stroke(PackedVector2Array([Vector2(model.far_x(y0) - 0.2, y0), Vector2(model.near_x(y0) + 0.2, y0)]), InkPen.INK, 0.8, false, 1.2)
	else:
		pen.shape_lit(poly, c["lit"], c["shade"], 0.7)
	pen.shade(poly, Vector2(1.6, -0.3), c["shadow"])
	_pattern(pen, model, poly, piece, c, y0, FigureModel.CROTCH_Y)
	pen.stroke_clipped(_hem_line(model, y0 + 0.5, 0.0), poly, c["trim"], 0.55)
	if bool(piece.get("ties", false)):
		var knot := Vector2(model.near_x(y0 + 0.7) + 0.3, y0 + 0.7)
		pen.shape(InkPen.ellipse(knot + Vector2(0.9, -0.5), Vector2(1.0, 0.6), 10, -0.4), c["base"], 0.35)
		pen.shape(InkPen.ellipse(knot + Vector2(0.7, 0.7), Vector2(0.9, 0.55), 10, 0.5), c["base"], 0.35)
		pen.stroke(PackedVector2Array([knot, knot + Vector2(0.9, 2.8)]), c["trim"], 0.3, false, 0.8)
		pen.stroke(PackedVector2Array([knot, knot + Vector2(0.1, 3.2)]), c["trim"], 0.3, false, 0.8)


static func _bra(pen: InkPen, model: FigureModel, piece: Dictionary, skin: Color) -> void:
	var c := _colours(piece)
	var style := str(piece.get("style", "triangle"))
	var cups: Array[PackedVector2Array] = []
	var apexes: Array[Vector2] = []
	for i in 2:
		var b: Array = model.breasts[i]
		var centre: Vector2 = b[0]
		var r: Vector2 = (b[1] as Vector2) + Vector2(0.45, 0.45)
		if style == "balconette":
			var cup := model.breast_shape(i, 0.45)
			var mask := PackedVector2Array([Vector2(centre.x - 20, centre.y - r.y * 0.2), Vector2(centre.x, centre.y - r.y * 0.35),
				Vector2(centre.x + 20, centre.y - r.y * 0.2), Vector2(centre.x + 20, centre.y + 20), Vector2(centre.x - 20, centre.y + 20)])
			for piece_poly in Geometry2D.intersect_polygons(cup, mask):
				cups.append(piece_poly)
			apexes.append(centre + Vector2(0.2 * r.x, -r.y * 0.3))
		else:
			var apex := centre + Vector2(0.15 * r.x, -1.08 * r.y)
			var left := centre + Vector2(-0.98 * r.x, 0.42 * r.y)
			var right := centre + Vector2(1.0 * r.x, 0.48 * r.y)
			var cup := InkPen.arc(centre, r, PI * 0.86, PI * 0.14, 10)
			cup.append_array(InkPen.quad(right, centre + Vector2(1.05 * r.x, -0.55 * r.y), apex, 6))
			cup.append_array(InkPen.quad(apex, centre + Vector2(-0.95 * r.x, -0.5 * r.y), left, 6))
			cups.append(cup)
			apexes.append(apex)
	# Strings / straps behind the cups.
	var string_w := 0.4 if style == "triangle" else 0.55
	pen.stroke(PackedVector2Array([apexes[1], Vector2(4.6, -96.6)]), InkPen.INK, string_w + 0.5, false, 1.4)
	pen.stroke(PackedVector2Array([apexes[1], Vector2(4.6, -96.6)]), c["trim"], string_w, false, 0.8)
	pen.stroke(PackedVector2Array([apexes[0], Vector2(-2.0, -97.0)]), InkPen.INK, string_w + 0.5, false, 1.4)
	pen.stroke(PackedVector2Array([apexes[0], Vector2(-2.0, -97.0)]), c["trim"], string_w, false, 0.8)
	var near_b: Array = model.breasts[1]
	var under: float = (near_b[0] as Vector2).y + (near_b[1] as Vector2).y * 0.45
	var band_line := PackedVector2Array([Vector2(model.far_x(under) - 0.3, under + 0.4), Vector2(model.near_x(under) + 0.3, under)])
	if style == "balconette":
		pen.shape(model.band(-79.8, -77.6, FABRIC_GROW), c["base"], 0.6)
	else:
		pen.stroke(band_line, InkPen.INK, 0.9, false, 1.4)
		pen.stroke(band_line, c["trim"], 0.4, false, 0.8)
	for i in cups.size():
		var cup := cups[i]
		pen.shape_lit(cup, c["lit"], c["shade"], 0.7)
		for rim_piece in InkPen.rim(cup, Vector2(0.4, -1.0)):
			pen.fill_soft(rim_piece, c["shadow"])
		var b: Array = model.breasts[mini(i, 1)]
		var centre: Vector2 = b[0]
		var r: Vector2 = b[1]
		pen.fill_clipped(InkPen.ellipse(centre + Vector2(0.28 * r.x, -0.3 * r.y), Vector2(0.38 * r.x, 0.26 * r.y), 12, -0.4), cup, c["light"])
		_pattern(pen, model, cup, piece, c, centre.y - r.y, centre.y + r.y)
	var cl := model.cleavage_x()
	if pen.lod(1.9):
		pen.stroke(PackedVector2Array([Vector2(cl + 0.1, (near_b[0] as Vector2).y - 1.0), Vector2(cl - 0.1, (near_b[0] as Vector2).y + 1.2)]), InkPen.line_of(skin, 0.4), 0.22, false, 0.6)


## Shadows under each breast and a soft sheen on the near one, so the bust reads under fabric.
static func _bust_shading(pen: InkPen, model: FigureModel, shape: PackedVector2Array, c: Dictionary) -> void:
	for i in 2:
		var b: Array = model.breasts[i]
		var centre: Vector2 = b[0]
		var r: Vector2 = b[1]
		var grown := model.breast_shape(i, 0.45)
		if pen.soft: # refined style: soft volume instead of cel rings
			pen.shade_soft(grown, Vector2(0.3, -1.4) * InkPen.SOFT_SPREAD, c["shadow"], shape)
			pen.fill_radial(centre + Vector2(0.2 * r.x, -0.3 * r.y), Vector2(0.55 * r.x, 0.4 * r.y), Color(c["light"], 0.7 if i == 1 else 0.35), -0.4)
			continue
		for rim_piece in InkPen.rim(grown, Vector2(0.3, -1.4)):
			pen.fill_clipped(rim_piece, shape, c["shadow"])
		if i == 1:
			pen.fill_clipped(InkPen.ellipse(centre + Vector2(0.25 * r.x, -0.32 * r.y), Vector2(0.42 * r.x, 0.28 * r.y), 12, -0.4), shape, c["light"])
	if pen.lod(1.9):
		var near: Array = model.breasts[1]
		var nc: Vector2 = near[0]
		var nr: Vector2 = near[1]
		pen.stroke_clipped(InkPen.arc(nc, nr + Vector2(0.3, 0.3), PI * 0.15, PI * 0.75, 8), shape, Color(c["line"], 0.35) if pen.soft else c["line"], 0.25, 0.6)


static func _pattern(pen: InkPen, model: FigureModel, shape: PackedVector2Array, piece: Dictionary, c: Dictionary, y0: float, y1: float) -> void:
	var detail := pen.lod(1.9)
	match str(piece.get("pattern", "")):
		"sequins":
			var glint := Color("fff6d0")
			for i in (70 if detail else 26):
				var y := lerpf(y0 + 1.0, y1 - 1.0, fmod(i * 0.618, 1.0))
				var x := lerpf(model.far_x(minf(y, FigureModel.CROTCH_Y)) - 2.0, model.near_x(minf(y, FigureModel.CROTCH_Y)) + 3.0, fmod(i * 0.377 + 0.13, 1.0))
				var p := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(p, shape):
					var bright := fmod(i * 0.29, 1.0)
					pen.dot(p, 0.26 if bright < 0.8 else 0.38, c["light"] if bright < 0.6 else glint, 0.8 if bright > 0.85 else 0.0)
		"satin":
			for k in 3:
				var x := lerpf(model.far_x(-66.0), model.near_x(-66.0), 0.55 + k * 0.14)
				var path := InkPen.smooth_open(PackedVector2Array([Vector2(x - 1.5, y0 + 2.0), Vector2(x + 0.6, (y0 + y1) * 0.5), Vector2(x - 0.4, y1 - 1.0)]), 4)
				pen.fill_clipped(InkPen.taper(path, 0.2, 0.2, 0.9 - k * 0.25), shape, c["light"])
		"ribbed":
			if detail:
				var x := model.far_x((y0 + y1) * 0.5) - 1.0
				while x < model.near_x((y0 + y1) * 0.5) + 4.0:
					pen.stroke_clipped(PackedVector2Array([Vector2(x, y0 - 4.0), Vector2(x + 0.4, y1 + 2.0)]), shape, Color(c["line"], 0.22), 0.16, 0.5)
					x += 1.3
		"plaid":
			var check := PlaceholderArt.color(piece.get("plaid"), Color.WHITE)
			var y := y0 + 2.4
			while y < y1 + 4.0:
				pen.stroke_clipped(PackedVector2Array([Vector2(-30, y), Vector2(30, y + 0.6)]), shape, Color(check, 0.55), 0.35, 0.7)
				y += 3.0
			var x := -16.0
			while x < 18.0:
				pen.stroke_clipped(PackedVector2Array([Vector2(x, y0), Vector2(x + x * 0.12, y1 + 2.0)]), shape, Color(check, 0.4), 0.3, 0.6)
				x += 3.0
		"lace":
			if detail:
				var y := y0 + 1.6
				var row := 0
				while y < y1:
					var x := model.far_x(minf(y, FigureModel.CROTCH_Y)) + (0.0 if row % 2 == 0 else 0.9)
					while x < model.near_x(minf(y, FigureModel.CROTCH_Y)) + 4.0:
						if Geometry2D.is_point_in_polygon(Vector2(x, y), shape):
							pen.stroke(InkPen.ellipse(Vector2(x, y), Vector2(0.45, 0.45), 6), Color(c["trim"], 0.35), 0.12, true, 0.5)
						x += 1.8
					y += 1.6
					row += 1
		"denim":
			if detail:
				pen.stroke_clipped(_hem_line(model, y1 - 1.4, float(piece.get("flare", 0.0)), true), shape, Color(c["trim"], 0.9), 0.15, 0.5)
		"mesh":
			if detail:
				var y := y0
				while y < y1:
					pen.stroke_clipped(PackedVector2Array([Vector2(-20, y), Vector2(20, y + 6.0)]), shape, Color(c["trim"], 0.3), 0.12, 0.5)
					y += 1.4


static func _lacing(pen: InkPen, model: FigureModel, shape: PackedVector2Array, c: Dictionary, y1: float) -> void:
	var top := -77.5
	var x := (model.near_x(-70.0) + model.far_x(-70.0)) * 0.5 + 1.9
	var y := top
	var k := 0
	while y < y1 - 1.0:
		var a := Vector2(x - 0.8, y)
		var b := Vector2(x + 0.8, y + 1.6)
		pen.stroke_clipped(PackedVector2Array([a, b]), shape, c["trim"], 0.22, 0.6)
		pen.stroke_clipped(PackedVector2Array([Vector2(x + 0.8, y), Vector2(x - 0.8, y + 1.6)]), shape, c["trim"], 0.22, 0.6)
		y += 1.8
		k += 1
	pen.stroke_clipped(PackedVector2Array([Vector2(x - 1.0, top), Vector2(x - 1.0, y1)]), shape, c["line"], 0.18, 0.5)
	pen.stroke_clipped(PackedVector2Array([Vector2(x + 1.0, top), Vector2(x + 1.0, y1)]), shape, c["line"], 0.18, 0.5)


static func _straps(pen: InkPen, model: FigureModel, piece: Dictionary, neckline: String, c: Dictionary) -> void:
	var straps := str(piece.get("straps", ""))
	if straps.is_empty() or straps == "false":
		return
	var w := 1.5 if straps == "wide" else 0.55
	var edge := _neck_edge(model, neckline, 0.0)
	# Each strap rises from the neckline above a breast to the shoulder.
	var near: Array = model.breasts[1]
	var far: Array = model.breasts[0]
	var targets := [[(far[0] as Vector2).x - 0.2, Vector2(-3.9, -95.2)], [(near[0] as Vector2).x + 0.2, Vector2(5.3, -95.0)]]
	for target: Array in targets:
		var x := float(target[0])
		var start := Vector2(x, _edge_y(edge, x) + 0.6)
		var path := PackedVector2Array([start, start.lerp(target[1], 0.5) + Vector2(0, -0.3), target[1]])
		pen.fill(InkPen.taper(path, w + 0.9, w + 0.9), InkPen.INK)
		pen.fill(InkPen.taper(path, w, w), c["trim"] if straps == "thin" else c["base"])


# ---------------------------------------------------------------------------
# Necklines
# ---------------------------------------------------------------------------

## The top edge of a garment, far side to near side.
static func _neck_edge(model: FigureModel, neckline: String, inset: float) -> PackedVector2Array:
	var far: Array = model.breasts[0]
	var near: Array = model.breasts[1]
	var cf: Vector2 = far[0]
	var rf: Vector2 = far[1]
	var cn: Vector2 = near[0]
	var rn: Vector2 = near[1]
	var cl := model.cleavage_x()
	var inner := PackedVector2Array()
	var side := -92.6
	match neckline:
		"scoop":
			side = -93.8
			inner = InkPen.smooth_open(PackedVector2Array([Vector2(-4.6, -93.8), Vector2(-2.8, -90.2), Vector2(0.9, -88.2), Vector2(4.8, -90.2), Vector2(6.7, -93.8)]), 4)
		"sweetheart":
			side = minf(cn.y - rn.y * 0.3, -86.0)
			inner = InkPen.smooth_open(PackedVector2Array([Vector2(cf.x - rf.x * 1.1, minf(cf.y - rf.y * 0.4, -85.5)), Vector2(cf.x, cf.y - rf.y * 0.62),
				Vector2(cl, cf.y - rf.y * 0.08)]), 4)
			inner.append_array(InkPen.smooth_open(PackedVector2Array([Vector2(cl, cn.y - rn.y * 0.08), Vector2(cn.x, cn.y - rn.y * 0.62),
				Vector2(cn.x + rn.x * 1.15, minf(cn.y - rn.y * 0.4, -85.5))]), 4))
		"straight":
			side = minf(cn.y - rn.y * 0.45, -86.0)
			inner = InkPen.smooth_open(PackedVector2Array([Vector2(cf.x - rf.x, cf.y - rf.y * 0.5), Vector2(cf.x, cf.y - rf.y * 0.62),
				Vector2(cl, cf.y - rf.y * 0.3), Vector2(cn.x, cn.y - rn.y * 0.62), Vector2(cn.x + rn.x, cn.y - rn.y * 0.5)]), 4)
		"v":
			side = -93.8
			inner = PackedVector2Array([Vector2(-4.4, -93.8), Vector2(cl, cn.y - rn.y * 0.1), Vector2(6.6, -93.8)])
		_: # high / crew
			side = -92.4
			inner = InkPen.smooth_open(PackedVector2Array([Vector2(-3.8, -92.4), Vector2(0.9, -91.0), Vector2(5.2, -92.4)]), 4)
	var edge := PackedVector2Array([Vector2(-30.0, side)])
	edge.append_array(inner)
	edge.append(Vector2(30.0, side))
	if inset != 0.0:
		edge = InkPen.translated(edge, Vector2(0, inset))
	return edge


static func _neck_mask(model: FigureModel, neckline: String) -> PackedVector2Array:
	var mask := _neck_edge(model, neckline, 0.0)
	mask.append(Vector2(30.0, 60.0))
	mask.append(Vector2(-30.0, 60.0))
	return mask


static func _edge_y(edge: PackedVector2Array, x: float) -> float:
	for i in edge.size() - 1:
		var a := edge[i]
		var b := edge[i + 1]
		if (x >= a.x and x <= b.x) or (x >= b.x and x <= a.x):
			return lerpf(a.y, b.y, (x - a.x) / maxf(b.x - a.x, 0.001))
	return edge[0].y


static func _hem_line(model: FigureModel, y: float, flare: float, skirt: bool = false) -> PackedVector2Array:
	if y > FigureModel.CROTCH_Y or skirt and y > FigureModel.CROTCH_Y - 0.5:
		var drop := y - FigureModel.CROTCH_Y
		return PackedVector2Array([Vector2(model.far_x(FigureModel.CROTCH_Y) - flare - drop * 0.06 - 2.0, y), Vector2(model.near_x(FigureModel.CROTCH_Y) + flare + drop * 0.04 + 2.0, y)])
	return PackedVector2Array([Vector2(model.far_x(y) - 2.0, y), Vector2(model.near_x(y) + 2.0, y)])


# ---------------------------------------------------------------------------
# Legwear and shoes (per leg, per frame)
# ---------------------------------------------------------------------------

static func draw_legwear(pen: InkPen, leg: Dictionary, legwear: Dictionary, skin: Color, is_far: bool) -> void:
	if legwear.is_empty():
		return
	var colour := PlaceholderArt.color(legwear.get("color"), Color("222222"))
	colour.a = 1.0
	if is_far:
		colour = InkPen.shadow_of(colour, 0.12)
	var from := float(legwear.get("from", 0.0))
	var trim := PlaceholderArt.color(legwear.get("trim"), colour)
	match str(legwear.get("type", "")):
		"fishnets":
			var poly := FigureModel.leg_polygon(leg, from, 0.97, 0.0)
			if not pen.lod(1.4):
				pen.fill(poly, Color(colour, 0.35))
			else:
				var count := 16
				for i in count:
					var a := FigureModel.leg_sample(leg, lerpf(from, 0.97, float(i) / count))
					var b := FigureModel.leg_sample(leg, lerpf(from, 0.97, float(i + 1.6) / count))
					for sgn: float in [-1.0, 1.0]:
						var p0: Vector2 = (a[0] as Vector2) + (a[3] as Vector2) * float(a[1]) * sgn * 1.1
						var p1: Vector2 = (b[0] as Vector2) - (b[3] as Vector2) * float(b[2]) * sgn * 1.1
						pen.stroke_clipped(PackedVector2Array([p0, p1]), poly, Color(colour, 0.9), 0.16, 0.6)
			pen.fill(FigureModel.leg_polygon(leg, from, from + 0.03, 0.2), colour)
		"stockings":
			var poly := FigureModel.leg_polygon(leg, from, 0.98, 0.05)
			pen.fill_lit(poly, skin.lerp(colour, 0.5), skin.lerp(colour, 0.78))
			for piece in InkPen.rim(poly, Vector2(-0.8, 0.0)):
				pen.fill_soft(piece, skin.lerp(colour, 0.85))
			var band := FigureModel.leg_polygon(leg, from, from + 0.04, 0.3)
			pen.shape(band, trim, 0.35)
			if pen.lod(1.9):
				for k in 7:
					var s := FigureModel.leg_sample(leg, from + 0.04)
					var p: Vector2 = (s[0] as Vector2) + (s[3] as Vector2) * lerpf(-float(s[2]), float(s[1]), (k + 0.5) / 7.0)
					pen.dot(p + Vector2(0, 0.3), 0.32, trim)
			if bool(legwear.get("garters", false)):
				var top := FigureModel.leg_sample(leg, from)
				var side := 1.0 if float(leg["side"]) > 0 else -1.0
				var anchor: Vector2 = (top[0] as Vector2) + (top[3] as Vector2) * float(top[1] if side > 0 else top[2]) * 0.55 * side
				pen.stroke(PackedVector2Array([anchor, anchor + Vector2(0.3 * side, -9.5)]), trim, 0.35, false, 0.8)
		"socks":
			pen.shape(FigureModel.leg_polygon(leg, 0.88, 0.98, 0.15), colour, 0.4)
		_: # leggings / opaque tights
			var poly := FigureModel.leg_polygon(leg, from, 0.975, 0.02)
			pen.fill_lit(poly, InkPen.light_of(colour, 0.08), InkPen.shadow_of(colour, 0.12))
			pen.shade(poly, Vector2(1.4, 0.0), InkPen.shadow_of(colour, 0.3))
			if legwear.has("trim"):
				var stripe := PackedVector2Array()
				for i in 12:
					var s := FigureModel.leg_sample(leg, lerpf(from + 0.02, 0.95, i / 11.0))
					var outer_half := float(s[1]) if float(leg["side"]) > 0 else -float(s[1])
					stripe.append((s[0] as Vector2) + (s[3] as Vector2) * outer_half * 0.72)
				pen.stroke(stripe, trim, 0.45, false, 0.8)


## Shoes, drawn in an ankle-local frame (ankle at the origin, toes toward +x, ground at y = +4.5).
static func draw_shoe(pen: InkPen, leg: Dictionary, shoes: Dictionary, skin: Color, is_far: bool) -> void:
	var colour := PlaceholderArt.color(shoes.get("color"), Color("ffd166"))
	var trim := PlaceholderArt.color(shoes.get("trim"), InkPen.shadow_of(colour, 0.35))
	if is_far:
		colour = InkPen.shadow_of(colour, 0.12)
		skin = InkPen.shadow_of(skin, 0.12)
	var kind := str(shoes.get("type", "heels"))
	if kind == "boots":
		var shaft := FigureModel.leg_polygon(leg, 0.56, 0.99, 0.45)
		pen.shape_lit(shaft, InkPen.light_of(colour, 0.1), colour, 0.75)
		pen.shade(shaft, Vector2(1.4, 0.0), InkPen.shadow_of(colour, 0.3))
		if pen.lod(1.5):
			for k in 3:
				var s := FigureModel.leg_sample(leg, 0.66 + k * 0.1)
				var c: Vector2 = s[0]
				var n: Vector2 = s[3]
				pen.stroke(PackedVector2Array([c - n * float(s[2]), c + n * float(s[1])]), Color("b8b8c8"), 0.4, false, 0.8)
	pen.push(Transform2D(float(leg.get("foot_angle", 0.0)), leg["ankle"]))
	match kind:
		"sneakers":
			var shoe := InkPen.smooth_closed(PackedVector2Array([Vector2(-2.3, -1.4), Vector2(1.5, -1.4), Vector2(2.4, 0.8), Vector2(5.0, 2.0),
				Vector2(6.6, 3.2), Vector2(6.5, 4.6), Vector2(-2.6, 4.6), Vector2(-2.9, 2.0)]), 2)
			pen.shape_lit(shoe, InkPen.light_of(colour, 0.1), InkPen.shadow_of(colour, 0.12), 0.75)
			pen.fill(PackedVector2Array([Vector2(-2.7, 3.4), Vector2(6.6, 3.4), Vector2(6.5, 4.6), Vector2(-2.6, 4.6)]), Color("f4f1ee"))
			pen.stroke(PackedVector2Array([Vector2(-2.7, 3.4), Vector2(6.6, 3.4)]), InkPen.line_of(colour, 0.4), 0.2, false, 0.6)
			pen.stroke(InkPen.quad(Vector2(-1.4, 2.6), Vector2(1.6, 1.0), Vector2(4.2, 2.8), 6), trim, 0.45, false, 0.8)
		"boots":
			var boot := InkPen.smooth_closed(PackedVector2Array([Vector2(-2.6, -1.6), Vector2(2.0, -1.6), Vector2(2.8, 1.0), Vector2(5.6, 2.2),
				Vector2(6.8, 3.4), Vector2(6.8, 5.2), Vector2(-2.8, 5.2)]), 2)
			pen.shape_lit(boot, InkPen.light_of(colour, 0.12), colour, 0.75)
			pen.fill(PackedVector2Array([Vector2(-2.8, 3.8), Vector2(6.8, 3.8), Vector2(6.8, 5.2), Vector2(-2.8, 5.2)]), InkPen.shadow_of(colour, 0.3))
		"sandals":
			var foot := InkPen.smooth_closed(PackedVector2Array([Vector2(-1.5, -2.0), Vector2(1.3, -2.0), Vector2(1.7, 0.2), Vector2(3.6, 2.2),
				Vector2(5.8, 3.8), Vector2(6.0, 4.6), Vector2(4.2, 4.6), Vector2(1.0, 3.0), Vector2(-1.7, 2.2)]), 2)
			pen.shape(foot, skin, 0.65)
			pen.stroke(InkPen.quad(Vector2(-1.8, 2.1), Vector2(2.2, 3.4), Vector2(6.2, 4.6), 6), InkPen.INK, 0.6, false, 1.0)
			pen.fill(PackedVector2Array([Vector2(-1.9, 2.0), Vector2(-1.1, 2.3), Vector2(-1.3, 4.6), Vector2(-1.75, 4.6)]), colour)
			for strap: Array in [[Vector2(-1.5, -0.4), Vector2(1.6, -0.6)], [Vector2(3.2, 1.6), Vector2(4.0, 3.6)], [Vector2(4.8, 2.6), Vector2(5.4, 4.2)]]:
				pen.stroke(PackedVector2Array(strap), colour, 0.55, false, 0.9)
			if pen.lod(1.9):
				pen.dot(Vector2(5.9, 4.3), 0.35, Color("ff4f8b"))
		_: # stiletto pumps
			var foot := InkPen.smooth_closed(PackedVector2Array([Vector2(-1.5, -2.0), Vector2(1.3, -2.0), Vector2(1.6, 0.2), Vector2(3.4, 2.0),
				Vector2(5.4, 3.7), Vector2(5.8, 4.4), Vector2(4.2, 4.3), Vector2(1.0, 2.9), Vector2(-1.6, 2.2)]), 2)
			pen.shape(foot, skin, 0.65)
			var pump := InkPen.smooth_closed(PackedVector2Array([Vector2(-1.8, 0.4), Vector2(0.4, 1.4), Vector2(2.4, 2.0), Vector2(4.4, 3.0),
				Vector2(6.3, 4.0), Vector2(6.4, 4.7), Vector2(4.0, 4.7), Vector2(1.0, 3.4), Vector2(-1.2, 2.7), Vector2(-2.0, 1.6)]), 2)
			pen.shape_lit(pump, InkPen.light_of(colour, 0.15), colour, 0.7)
			var heel := PackedVector2Array([Vector2(-2.0, 1.8), Vector2(-1.0, 2.2), Vector2(-1.25, 4.7), Vector2(-1.75, 4.7)])
			pen.shape(heel, InkPen.shadow_of(colour, 0.2), 0.45)
			if pen.lod(1.9):
				pen.stroke(InkPen.quad(Vector2(0.6, 2.4), Vector2(3.0, 3.0), Vector2(5.6, 4.1), 6), InkPen.light_of(colour, 0.5), 0.3, false, 0.6)
	pen.pop()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _union(a: PackedVector2Array, b: PackedVector2Array) -> PackedVector2Array:
	var merged := Geometry2D.merge_polygons(a, b)
	var best := a
	var best_area := -1.0
	for poly in merged:
		var area := absf(_area(poly))
		if area > best_area and Geometry2D.is_polygon_clockwise(poly) == Geometry2D.is_polygon_clockwise(a):
			best = poly
			best_area = area
	return best


static func _is_outer(poly: PackedVector2Array, reference: PackedVector2Array) -> bool:
	return poly.size() >= 3 and Geometry2D.is_polygon_clockwise(poly) == Geometry2D.is_polygon_clockwise(reference)


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
