class_name CreatorRenderer
extends RefCounted
## Layered, data-driven creator drawing (placeholder art pipeline).
##
## The body is built from front/back silhouette curves that body-shape parameters (bust, hips,
## glutes) bend. Garments are drawn by re-using that silhouette over a vertical range, so outfits
## are pure data (appearance.json) and automatically follow body changes.
## Layer order: back hair > back arm > legs > legwear > shoes > torso skin > bottom > top >
## trims/details > tattoo/piercing > front arm > neck/head > makeup > front hair.
## All characters are adult women; everything is clothed / non-explicit.
##
## Coordinates: facing +x, feet at (0, 0), head top ~ -118. Callers set the transform.

const OUTLINE_STEP := 1.0
const SHOULDER_Y := -89.0
const CROTCH_Y := -47.0
const HIP_Y := -50.0
const LEG_LENGTH := 46.0


## Draws a creator with feet at `origin`. Poses: idle, walk, film, socialise, selfie, stream, sleep.
static func draw(ci: CanvasItem, spec: Dictionary, anim: String, t: float, origin: Vector2, facing: float = 1.0, scale: float = 1.0, sleep_lift: float = 0.0) -> void:
	if anim == "sleep":
		ci.draw_set_transform(origin + Vector2(56.0, -sleep_lift - 12.0) * scale, -PI / 2.0, Vector2(scale, scale))
	else:
		var bob := -absf(cos(t * 9.0)) * 2.0 if anim == "walk" else sin(t * 2.2) * 0.7
		ci.draw_set_transform(origin + Vector2(0.0, bob) * scale, 0.0, Vector2(facing * scale, scale))
	_draw_body(ci, spec, anim, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------------
# Pose
# ---------------------------------------------------------------------------

static func _pose(anim: String, t: float) -> Dictionary:
	var pose := {
		"leg_swing": 0.0, "hand_front": Vector2(14.0, -57.0), "hand_back": Vector2(-12.5, -57.0),
		"phone": false, "eyes_closed": anim == "sleep", "hip_shift": 0.0,
	}
	match anim:
		"walk":
			var s := sin(t * 9.0)
			pose["leg_swing"] = s * 0.35
			pose["hand_front"] = Vector2(7.0 - s * 9.0, -56.0)
			pose["hand_back"] = Vector2(-7.0 + s * 9.0, -56.0)
		"film":
			if fmod(t, 3.0) < 1.5: # hand in hair, hand on hip
				pose["hand_front"] = Vector2(7.0, -110.0)
				pose["hand_back"] = Vector2(-11.0, -63.0)
				pose["hip_shift"] = 1.2
			else: # both hands on hips
				pose["hand_front"] = Vector2(11.0, -63.0)
				pose["hand_back"] = Vector2(-11.0, -63.0)
				pose["hip_shift"] = -0.8
		"socialise":
			pose["hand_front"] = Vector2(10.0, -80.0)
			pose["hand_back"] = Vector2(-10.0, -62.0)
			pose["phone"] = true
		"selfie":
			pose["hand_front"] = Vector2(17.0, -106.0)
			pose["hand_back"] = Vector2(-11.0, -63.0) if fmod(t, 4.0) < 2.5 else Vector2(-14.0, -102.0)
			pose["phone"] = true
			pose["hip_shift"] = 1.0
		"stream":
			pose["hand_front"] = Vector2(15.0 + sin(t * 6.0) * 3.0, -97.0 + cos(t * 6.0) * 3.0)
			pose["hand_back"] = Vector2(-11.0, -63.0) if fmod(t, 3.0) < 2.0 else Vector2(10.0, -78.0)
		"sleep":
			pose["hand_front"] = Vector2(9.0, -58.0)
			pose["hand_back"] = Vector2(-9.0, -58.0)
	return pose


# ---------------------------------------------------------------------------
# Silhouette
# ---------------------------------------------------------------------------

## Front (+x) edge control points (y, x) from shoulder to crotch.
## Hourglass silhouette. The bust is drawn as separate rounded shapes (see _bust_shapes).
static func _front_points(spec: Dictionary) -> PackedVector2Array:
	var hips := float(spec.get("hips", 1.0))
	return PackedVector2Array([
		Vector2(-90.0, 7.2), Vector2(-86.0, 9.0), Vector2(-80.0, 9.2), Vector2(-74.0, 7.6),
		Vector2(-67.0, 6.3), Vector2(-60.0, 8.0 * hips), Vector2(-54.0, 9.2 * hips), Vector2(-46.0, 8.6 * hips),
	])


## Back (-x) edge control points (y, x). Glutes push the lower back edge out (3/4 view).
static func _back_points(spec: Dictionary) -> PackedVector2Array:
	var hips := float(spec.get("hips", 1.0))
	var glutes := float(spec.get("glutes", 1.0))
	return PackedVector2Array([
		Vector2(-90.0, -7.6), Vector2(-84.0, -9.2), Vector2(-76.0, -8.2),
		Vector2(-67.0, -6.9), Vector2(-61.0, -8.9 * hips - 0.9 * (glutes - 1.0)),
		Vector2(-54.0, -10.2 * hips - 2.4 * glutes + 0.6), Vector2(-46.0, -8.8 * hips - 0.9 * glutes),
	])


## Near and far bust shapes for a 3/4 view: [centre, radii] pairs, near one last.
static func _bust_shapes(spec: Dictionary) -> Array:
	var bust := float(spec.get("bust", 1.0))
	var scale := pow(bust, 0.8)
	return [
		[Vector2(2.6, -79.2 + 0.4 * (bust - 1.0)), Vector2(3.9, 3.6) * scale],
		[Vector2(7.6 + 0.9 * (bust - 1.0), -78.8 + 0.6 * (bust - 1.0)), Vector2(4.3, 3.9) * scale],
	]


## Ellipse polygon with everything above `top_y` flattened (a garment's neckline).
static func _clipped_ellipse(centre: Vector2, radii: Vector2, top_y: float, bottom_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * i / 20.0
		var p := centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		p.y = clampf(p.y, top_y, bottom_y)
		points.append(p)
	return points


## Catmull-Rom interpolation of x for a given y over control points sorted by y.
static func _edge_x(points: PackedVector2Array, y: float) -> float:
	if y <= points[0].x:
		return points[0].y
	var last := points.size() - 1
	if y >= points[last].x:
		return points[last].y
	for i in last:
		if y <= points[i + 1].x:
			var p0: Vector2 = points[maxi(i - 1, 0)]
			var p1: Vector2 = points[i]
			var p2: Vector2 = points[i + 1]
			var p3: Vector2 = points[mini(i + 2, last)]
			var u := (y - p1.x) / maxf(p2.x - p1.x, 0.001)
			var u2 := u * u
			var u3 := u2 * u
			return 0.5 * ((2.0 * p1.y) + (-p0.y + p2.y) * u + (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y) * u2 + (-p0.y + 3.0 * p1.y - 3.0 * p2.y + p3.y) * u3)
	return points[last].y


## Closed torso polygon between y0 (top) and y1 (bottom). `grow` pads outward (cloth),
## `flare` widens toward the bottom (skirts).
static func _torso(spec: Dictionary, y0: float, y1: float, grow: float = 0.0, flare: float = 0.0) -> PackedVector2Array:
	var front := _front_points(spec)
	var back := _back_points(spec)
	var poly := PackedVector2Array()
	var span := maxf(y1 - y0, 0.001)
	var y := y0
	while y < y1:
		var f := pow((y - y0) / span, 2.0) * flare
		poly.append(Vector2(_edge_x(front, y) + grow + f, y))
		y += OUTLINE_STEP
	poly.append(Vector2(_edge_x(front, y1) + grow + flare, y1))
	poly.append(Vector2(_edge_x(back, y1) - grow - flare, y1))
	y = y1 - OUTLINE_STEP
	while y > y0:
		var f := pow((y - y0) / span, 2.0) * flare
		poly.append(Vector2(_edge_x(back, y) - grow - f, y))
		y -= OUTLINE_STEP
	poly.append(Vector2(_edge_x(back, y0) - grow, y0))
	return poly


static func _edge_line(spec: Dictionary, y: float, grow: float = 0.0, flare: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(_edge_x(_back_points(spec), y) - grow - flare, y),
		Vector2(_edge_x(_front_points(spec), y) + grow + flare, y)])


# ---------------------------------------------------------------------------
# Body
# ---------------------------------------------------------------------------

static func _draw_body(ci: CanvasItem, spec: Dictionary, anim: String, t: float) -> void:
	var pose := _pose(anim, t)
	var skin := PlaceholderArt.color(spec.get("skin"), Color("f1c6a5"))
	var skin_shade := skin.darkened(0.13)
	var hair := PlaceholderArt.color(spec.get("hair_color"), Color("6b3b2a"))
	var outfit: Dictionary = spec.get("outfit", {})

	_draw_back_hair(ci, spec, hair, t)
	_draw_arm(ci, Vector2(-8, -87), pose["hand_back"], skin_shade)

	var line := skin.darkened(0.35)
	var legs := _leg_geometry(spec, float(pose["leg_swing"]))
	for i in 2: # back leg first
		_draw_leg(ci, legs[i], skin_shade if i == 0 else skin, line)
		_draw_legwear(ci, legs[i], outfit.get("legwear", {}), i == 0)
		_draw_shoe(ci, legs[i], outfit.get("shoes", {}), i == 0)

	var torso := _torso(spec, SHOULDER_Y, CROTCH_Y)
	var outline := torso.duplicate()
	outline.append(torso[0])
	ci.draw_polyline(outline, line, 1.4, true)
	ci.draw_colored_polygon(torso, skin)
	for shape: Array in _bust_shapes(spec):
		PlaceholderArt.draw_ellipse(ci, shape[0], shape[1], skin)
	# Collarbone and neck shading for definition.
	ci.draw_line(Vector2(-3, -87.5), Vector2(4, -87.8), skin_shade, 0.8, true)

	_draw_garment(ci, spec, outfit.get("bottom", {}), t)
	_draw_garment(ci, spec, outfit.get("top", {}), t)
	_draw_skin_details(ci, spec, outfit, legs[1], skin_shade)

	_draw_arm(ci, Vector2(7.5, -87), pose["hand_front"], skin)
	if bool(pose["phone"]):
		var hand: Vector2 = pose["hand_front"]
		PlaceholderArt.draw_rounded_rect(ci, Rect2(hand + Vector2(-2.5, -10), Vector2(6, 11)), Color("222222"), 1)
		ci.draw_rect(Rect2(hand + Vector2(-1.5, -9), Vector2(4, 8)), Color("7fd3ff"))
	_draw_head(ci, spec, skin, skin_shade, hair, bool(pose["eyes_closed"]), t)


static func _leg_geometry(spec: Dictionary, swing: float) -> Array:
	var hips := float(spec.get("hips", 1.0))
	var result: Array = []
	for side: int in [-1, 1]: # -1 = back leg
		var angle := swing * side
		var hip := Vector2(4.0 * side * hips + (0.6 if side > 0 else -0.8), HIP_Y)
		var direction := Vector2(sin(angle), cos(angle))
		var knee := hip + direction * (LEG_LENGTH * 0.5) + Vector2(0.6, 0)
		var ankle := hip + direction * LEG_LENGTH
		result.append({"hip": hip, "knee": knee, "ankle": ankle, "thigh": 5.4 * hips, "knee_w": 2.8, "ankle_w": 1.6})
	return result


## Point and half-width along a leg at t in 0..1 (hip -> ankle).
static func _leg_at(leg: Dictionary, t: float) -> Array:
	var hip: Vector2 = leg["hip"]
	var knee: Vector2 = leg["knee"]
	var ankle: Vector2 = leg["ankle"]
	if t <= 0.5:
		var u := t / 0.5
		return [hip.lerp(knee, u), lerpf(float(leg["thigh"]), float(leg["knee_w"]), pow(u, 0.8))]
	var v := (t - 0.5) / 0.5
	var calf := sin(v * PI) * 1.0 # a little calf curve
	return [knee.lerp(ankle, v), lerpf(float(leg["knee_w"]), float(leg["ankle_w"]), v) + calf]


static func _leg_polygon(leg: Dictionary, t0: float, t1: float, grow: float = 0.0) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 10
	for i in steps + 1:
		var t := lerpf(t0, t1, float(i) / steps)
		var sample := _leg_at(leg, t)
		var centre: Vector2 = sample[0]
		var half := float(sample[1]) + grow
		var along: Vector2 = (_leg_at(leg, minf(t + 0.02, 1.0))[0] - _leg_at(leg, maxf(t - 0.02, 0.0))[0]).normalized()
		var normal := Vector2(-along.y, along.x)
		left.append(centre + normal * half)
		right.append(centre - normal * half)
	right.reverse()
	left.append_array(right)
	return left


static func _draw_leg(ci: CanvasItem, leg: Dictionary, skin: Color, line: Color) -> void:
	var poly := _leg_polygon(leg, 0.0, 1.0)
	var outline := poly.duplicate()
	outline.append(poly[0])
	ci.draw_polyline(outline, line, 1.3, true)
	ci.draw_colored_polygon(poly, skin)


static func _draw_legwear(ci: CanvasItem, leg: Dictionary, legwear: Dictionary, is_back: bool) -> void:
	if legwear.is_empty():
		return
	var colour := PlaceholderArt.color(legwear.get("color"), Color("222222"))
	if is_back:
		colour = colour.darkened(0.12)
	var from := float(legwear.get("from", 0.0))
	ci.draw_colored_polygon(_leg_polygon(leg, from, 0.97, 0.15), colour)
	if str(legwear.get("type", "")) == "stockings":
		var band := _leg_at(leg, from)
		var trim := PlaceholderArt.color(legwear.get("trim"), Color.BLACK)
		var centre: Vector2 = band[0]
		var half := float(band[1]) + 0.4
		ci.draw_line(centre + Vector2(-half, 0), centre + Vector2(half, 0), trim, 1.4, true)


static func _draw_shoe(ci: CanvasItem, leg: Dictionary, shoes: Dictionary, is_back: bool) -> void:
	var ankle: Vector2 = leg["ankle"]
	var colour := PlaceholderArt.color(shoes.get("color"), Color("ffd166"))
	if is_back:
		colour = colour.darkened(0.15)
	if str(shoes.get("type", "heels")) == "sneakers":
		var shoe := PackedVector2Array([ankle + Vector2(-3, -2), ankle + Vector2(3, -2.5), ankle + Vector2(7.5, 1.5),
			ankle + Vector2(7.5, 4), ankle + Vector2(-3.5, 4)])
		ci.draw_colored_polygon(shoe, colour)
		ci.draw_line(ankle + Vector2(-3.5, 3.6), ankle + Vector2(7.5, 3.6), colour.darkened(0.25), 1.2)
	else:
		# Pointed stiletto: arched foot, thin heel.
		var shoe := PackedVector2Array([ankle + Vector2(-2.2, -2), ankle + Vector2(2, -1), ankle + Vector2(7.5, 3.4),
			ankle + Vector2(7.5, 4.2), ankle + Vector2(1.5, 2.2), ankle + Vector2(-2.2, 1.2)])
		ci.draw_colored_polygon(shoe, colour)
		ci.draw_line(ankle + Vector2(-1.8, 1), ankle + Vector2(-1.5, 4.3), colour.darkened(0.3), 1.2, true)


static func _draw_garment(ci: CanvasItem, spec: Dictionary, garment: Dictionary, t: float) -> void:
	if garment.is_empty():
		return
	var colour := PlaceholderArt.color(garment.get("color"), Color("e0457b"))
	var trim := PlaceholderArt.color(garment.get("trim"), colour.darkened(0.25))
	var y0 := float(garment.get("from", SHOULDER_Y))
	var y1 := float(garment.get("to", CROTCH_Y))
	var flare := float(garment.get("flare", 0.0))
	ci.draw_colored_polygon(_torso(spec, y0, y1, 0.35, flare), colour)
	# Cover the bust shapes too, flattened at the neckline so the garment shape follows the body.
	if y0 < -76.0 and y1 > -80.0:
		var shapes := _bust_shapes(spec)
		for i in shapes.size():
			var shape: Array = shapes[i]
			var radii: Vector2 = shape[1] + Vector2(0.35, 0.35)
			ci.draw_colored_polygon(_clipped_ellipse(shape[0], radii, y0, y1), colour.darkened(0.06) if i == 0 else colour)
		var near: Array = shapes[shapes.size() - 1]
		var near_centre: Vector2 = near[0]
		var near_radii: Vector2 = near[1]
		ci.draw_arc(near_centre, near_radii.x, 0.35, PI - 0.5, 10, colour.darkened(0.25), 1.0, true)
		ci.draw_line(near_centre + Vector2(-near_radii.x * 0.6, -near_radii.y * 0.4), near_centre + Vector2(-near_radii.x * 0.1, -near_radii.y * 0.6), colour.lightened(0.25), 0.8, true)
	var neckline := str(garment.get("neckline", ""))
	match neckline:
		"scoop":
			PlaceholderArt.draw_ellipse(ci, Vector2(1.0, y0), Vector2(4.5, 3.2), PlaceholderArt.color(spec.get("skin"), Color("f1c6a5")))
		"sweetheart":
			# Gentle cleavage hint at the top of a sweetheart neckline (non-explicit).
			var shapes := _bust_shapes(spec)
			var between := ((shapes[0][0] as Vector2) + (shapes[1][0] as Vector2)) * 0.5
			ci.draw_line(Vector2(between.x + 0.3, y0 - 0.6), Vector2(between.x, y0 + 1.8), PlaceholderArt.color(spec.get("skin"), Color("f1c6a5")).darkened(0.25), 0.8, true)
	if bool(garment.get("straps", false)):
		ci.draw_line(Vector2(-3.5, SHOULDER_Y + 0.5), Vector2(-4.0, y0 + 0.5), trim, 0.9, true)
		ci.draw_line(Vector2(4.5, SHOULDER_Y + 0.5), Vector2(6.2, y0 + 0.5), trim, 0.9, true)
	ci.draw_polyline(_edge_line(spec, y0 + 0.4, 0.35), trim, 1.0, true)
	ci.draw_polyline(_edge_line(spec, y1 - 0.4, 0.35, flare), trim, 1.0, true)
	if bool(garment.get("lace", false)):
		for edge_y in [y0 + 1.2, y1 - 1.2]:
			var line := _edge_line(spec, edge_y, 0.35)
			var x := line[0].x
			while x < line[1].x:
				ci.draw_circle(Vector2(x, edge_y), 0.7, trim)
				x += 2.2
		# Corset lacing down the front.
		var lace_x := _edge_x(_front_points(spec), -64.0) - 1.5
		for i in 4:
			var ly := -70.0 + i * 3.5
			ci.draw_line(Vector2(lace_x - 1.0, ly), Vector2(lace_x + 1.0, ly + 1.5), trim, 0.6, true)
	if bool(garment.get("sparkle", false)):
		for i in 9:
			var sy := lerpf(y0 + 3.0, y1 - 2.0, fmod(i * 0.37, 1.0))
			var sx := lerpf(_edge_x(_back_points(spec), sy) + 1.5, _edge_x(_front_points(spec), sy) - 1.5, fmod(i * 0.61, 1.0))
			var glint := 0.5 + 0.5 * sin(t * 3.0 + i * 1.7)
			ci.draw_circle(Vector2(sx, sy), 0.55 + glint * 0.35, Color(1, 0.95, 0.7, 0.5 + glint * 0.5))


## Tattoos and visible piercings. Hidden when an outfit covers the area.
static func _draw_skin_details(ci: CanvasItem, spec: Dictionary, outfit: Dictionary, front_leg: Dictionary, skin_shade: Color) -> void:
	var piercings: Array = spec.get("piercings", [])
	if piercings.has("belly") and bool(outfit.get("midriff", false)):
		var navel := Vector2(_edge_x(_front_points(spec), -66.0) - 2.6, -66.0)
		ci.draw_circle(navel, 0.6, skin_shade.darkened(0.2))
		ci.draw_circle(navel + Vector2(0, 1.4), 0.9, Color("ffd166"))
		ci.draw_circle(navel + Vector2(0.2, 1.2), 0.35, Color.WHITE)
	# Nipple piercings are intentionally never drawn: outfits always cover the chest.
	var tattoos: Array = spec.get("tattoos", [])
	if tattoos.has("rose_thigh") and not bool(outfit.get("covers_thighs", false)):
		var bottom_edge := float(outfit.get("bottom", outfit.get("top", {})).get("to", CROTCH_Y))
		var spot := _leg_at(front_leg, 0.24)
		var centre: Vector2 = spot[0] + Vector2(1.0, 0)
		if centre.y > bottom_edge + 1.0:
			_draw_rose(ci, centre)


static func _draw_rose(ci: CanvasItem, centre: Vector2) -> void:
	PlaceholderArt.draw_ellipse(ci, centre + Vector2(-1.6, 1.6), Vector2(1.3, 0.6), Color(0.2, 0.55, 0.3, 0.9))
	PlaceholderArt.draw_ellipse(ci, centre + Vector2(1.6, 1.8), Vector2(1.3, 0.6), Color(0.2, 0.55, 0.3, 0.9))
	ci.draw_circle(centre, 1.7, Color(0.78, 0.1, 0.25, 0.92))
	ci.draw_arc(centre, 0.9, 0.0, TAU * 0.75, 8, Color(0.45, 0.03, 0.12), 0.5, true)


static func _draw_arm(ci: CanvasItem, shoulder: Vector2, hand: Vector2, skin: Color) -> void:
	var mid := (shoulder + hand) * 0.5
	var bend := (hand - shoulder).orthogonal().normalized() * 3.0
	if bend.x > 0.0:
		bend = -bend
	var elbow := mid + bend
	var line := skin.darkened(0.3)
	ci.draw_line(shoulder, elbow, line, 5.6, true)
	ci.draw_line(elbow, hand, line, 4.6, true)
	ci.draw_line(shoulder, elbow, skin, 4.4, true)
	ci.draw_circle(elbow, 2.0, skin)
	ci.draw_line(elbow, hand, skin, 3.5, true)
	ci.draw_circle(shoulder, 2.6, skin)
	ci.draw_circle(hand, 2.1, skin)


# ---------------------------------------------------------------------------
# Head, face and hair
# ---------------------------------------------------------------------------

static func _draw_head(ci: CanvasItem, spec: Dictionary, skin: Color, skin_shade: Color, hair: Color, eyes_closed: bool, t: float) -> void:
	var makeup: Dictionary = spec.get("makeup", {})
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-2.8, -96), Vector2(3.2, -96), Vector2(3.6, -88), Vector2(-3.2, -88)]), skin)
	ci.draw_line(Vector2(-2.6, -93), Vector2(2.4, -91.5), skin_shade, 0.7, true)
	PlaceholderArt.draw_ellipse(ci, Vector2(1.5, -104.5), Vector2(9.6, 10.6), skin)
	# Jaw toward the front for a more mature, defined face.
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-2, -99), Vector2(9.5, -101), Vector2(8.5, -96.5), Vector2(5, -94), Vector2(0, -95)]), skin)
	# Hoop earring just below the hairline at the jaw.
	ci.draw_arc(Vector2(-2.2, -97.4), 1.5, 0.0, TAU, 12, Color("ffd166"), 0.8, true)

	var lids := str(makeup.get("lids", ""))
	var liner := bool(makeup.get("liner", false))
	var eye_color := PlaceholderArt.color(spec.get("eyes"), Color("2f5d7c"))
	var lash := Color("1e1118")
	# Near eye large, far eye smaller and closer to the nose bridge (3/4 view).
	for eye: Array in [[Vector2(6.6, -104.8), 2.2, 1.9], [Vector2(0.9, -104.8), 1.4, 1.8]]:
		var c: Vector2 = eye[0]
		var w: float = eye[1]
		var h: float = eye[2]
		if not lids.is_empty():
			PlaceholderArt.draw_ellipse(ci, c + Vector2(0.1, -1.5), Vector2(w + 0.7, 1.4), PlaceholderArt.color(lids, Color.BROWN))
		if eyes_closed:
			ci.draw_arc(c + Vector2(0, -0.3), w, 0.3, PI - 0.3, 6, lash, 1.0, true)
			continue
		PlaceholderArt.draw_ellipse(ci, c, Vector2(w, h), Color.WHITE)
		ci.draw_circle(c + Vector2(0.5 * w / 2.2, 0.2), h * 0.72, eye_color)
		ci.draw_circle(c + Vector2(0.6 * w / 2.2, 0.2), h * 0.36, Color.BLACK)
		ci.draw_circle(c + Vector2(0.9 * w / 2.2, -0.4), 0.35, Color.WHITE)
		# Upper lash line only (no lower line, so eyes don't read as glasses).
		ci.draw_arc(c + Vector2(0, 0.4), w + 0.1, PI + 0.35, TAU - 0.05, 8, lash, 1.2 if liner else 0.8, true)
		if liner:
			ci.draw_line(c + Vector2(w, -0.9), c + Vector2(w + 1.7, -2.1), lash, 0.9, true)
		ci.draw_line(c + Vector2(w - 0.2, -1.2), c + Vector2(w + 0.7, -2.3), lash, 0.6, true)
	# Brows
	ci.draw_line(Vector2(3.6, -109.6), Vector2(8.4, -109.3), hair.darkened(0.3), 1.0, true)
	ci.draw_line(Vector2(-2.0, -109.3), Vector2(1.0, -109.6), hair.darkened(0.3), 0.9, true)
	# Nose
	ci.draw_line(Vector2(9.2, -104.5), Vector2(10.2, -101.5), skin_shade, 0.8, true)
	ci.draw_line(Vector2(10.2, -101.5), Vector2(9.0, -101.0), skin_shade, 0.8, true)
	# Blush
	var blush := float(makeup.get("blush", 0.3))
	ci.draw_circle(Vector2(7.2, -101.2), 2.2, Color(1.0, 0.42, 0.52, blush))
	# Lips (lip filler scales them)
	var lip_size := float(spec.get("lip_size", 1.0))
	var lip_color := PlaceholderArt.color(makeup.get("lips"), Color("c2185b"))
	PlaceholderArt.draw_ellipse(ci, Vector2(6.8, -98.9), Vector2(2.3, 0.75) * Vector2(1.0, lip_size), lip_color.darkened(0.1))
	PlaceholderArt.draw_ellipse(ci, Vector2(6.8, -97.6), Vector2(2.4, 0.95) * Vector2(1.0, lip_size), lip_color)
	ci.draw_circle(Vector2(7.4, -97.4 - 0.2 * lip_size), 0.4, Color(1, 1, 1, 0.5))
	_draw_front_hair(ci, spec, hair, t)


static func _draw_back_hair(ci: CanvasItem, spec: Dictionary, hair: Color, t: float) -> void:
	var dark := hair.darkened(0.12)
	if str(spec.get("hair_style", "long_waves")) == "high_ponytail":
		var sway := sin(t * 2.5) * 1.5
		var tail := PackedVector2Array([Vector2(-6, -115), Vector2(-2, -116), Vector2(-7 + sway * 0.3, -104),
			Vector2(-12 + sway, -92), Vector2(-15 + sway, -84), Vector2(-17 + sway, -88), Vector2(-14 + sway * 0.6, -100), Vector2(-10, -112)])
		ci.draw_colored_polygon(tail, dark)
		return
	# Long waves: wavy hem down the back.
	var poly := PackedVector2Array([Vector2(-11, -113), Vector2(2, -117), Vector2(12, -110), Vector2(13, -98), Vector2(11, -88)])
	var hem_points := 9
	for i in hem_points + 1:
		var x := lerpf(9.0, -15.0, float(i) / hem_points)
		poly.append(Vector2(x, -71.0 + sin(i * 1.4 + t * 1.5) * 1.6 - (2.0 if i == 0 else 0.0)))
	poly.append_array(PackedVector2Array([Vector2(-16, -86), Vector2(-15, -102)]))
	ci.draw_colored_polygon(poly, dark)


static func _draw_front_hair(ci: CanvasItem, spec: Dictionary, hair: Color, _t: float) -> void:
	var crown := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * i / 12.0
		crown.append(Vector2(1.5, -105.0) + Vector2(cos(angle) * 10.8, sin(angle) * 12.0))
	if str(spec.get("hair_style", "long_waves")) == "high_ponytail":
		# Sleek pulled-back hair with a tie.
		crown.append_array(PackedVector2Array([Vector2(11, -108), Vector2(4, -111.5), Vector2(-4, -110), Vector2(-9.5, -104)]))
		ci.draw_colored_polygon(crown, hair)
		ci.draw_circle(Vector2(-6.0, -114.5), 1.6, Color("ff4f8b"))
		ci.draw_line(Vector2(-6, -114), Vector2(6, -113), hair.lightened(0.25), 0.8, true)
		return
	# Side-swept fringe with a lock falling over the front shoulder.
	crown.append_array(PackedVector2Array([Vector2(12.4, -103), Vector2(9, -109), Vector2(3.5, -106.5),
		Vector2(-2.5, -109), Vector2(-8.5, -104), Vector2(-10.5, -97)]))
	ci.draw_colored_polygon(crown, hair)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(10.5, -104), Vector2(12.6, -100), Vector2(12.4, -90),
		Vector2(10.5, -80), Vector2(8.2, -84), Vector2(9.6, -94)]), hair)
	ci.draw_line(Vector2(2, -114), Vector2(9, -108), hair.lightened(0.3), 1.0, true)
