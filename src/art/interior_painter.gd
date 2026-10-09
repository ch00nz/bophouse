class_name InteriorPainter
extends RefCounted
## Detailed side-on room interiors for Room View, in the same ink-and-cel style as the characters
## (InkPen: bold outlines, gradient fills, soft shadows). Everything is driven by data: the room
## level's wall/floor colours, wall pattern and furniture list (rooms.json), the time of day, and
## which walls open onto stairs (doorways). Furniture kinds without a detailed drawing fall back to
## the house view's PlaceholderArt drawing, so new kinds always show up.
##
## Coordinates: room-local, origin at the room's top-left, `size` = room size (width x storey
## height); the floor line is at size.y - CreatorStage.FLOOR_H.

const INK := Color("2a1622")
const DETAILED := ["window", "couch", "tv", "coffee_table", "plant", "beanbag", "rug", "poster", "neon_sign"]


static func interior_h(size: Vector2) -> float:
	return size.y - CreatorStage.FLOOR_H


## Back wall, wall decor, floor, doorways and the ceiling light (behind the creators).
static func draw_room(ci: CanvasItem, level_def: Dictionary, size: Vector2, daylight: float, t: float, doors: Array) -> void:
	var pen := InkPen.new(ci, Transform2D.IDENTITY)
	var ih := interior_h(size)
	var wall := PlaceholderArt.color(level_def.get("wall", null), Color("cccccc"))
	var floor_color := PlaceholderArt.color(level_def.get("floor", null), Color("8b6b55"))
	# Wall with a soft vertical light falloff, pattern, ceiling shadow, crown moulding and skirting.
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, ih), Vector2(0, ih)]),
		PackedColorArray([wall.darkened(0.12), wall.darkened(0.12), wall.lightened(0.04), wall.lightened(0.04)]))
	_wall_pattern(ci, str(level_def.get("pattern", "none")), wall, Rect2(0, 12, size.x, ih - 24))
	ci.draw_rect(Rect2(0, 0, size.x, 10), wall.darkened(0.3))
	ci.draw_rect(Rect2(0, 10, size.x, 3), wall.lightened(0.35))
	ci.draw_line(Vector2(0, 13.5), Vector2(size.x, 13.5), wall.darkened(0.25), 1.0)
	var trim := wall.lightened(0.45)
	ci.draw_rect(Rect2(0, ih - 9, size.x, 9), trim)
	ci.draw_line(Vector2(0, ih - 9), Vector2(size.x, ih - 9), wall.darkened(0.3), 1.0)
	# Floor boards (the thin strip of floor seen side-on) and a contact shadow along the wall.
	ci.draw_rect(Rect2(0, ih, size.x, CreatorStage.FLOOR_H), floor_color)
	ci.draw_rect(Rect2(0, ih, size.x, 3), floor_color.lightened(0.18))
	var x := 9.0
	var row := 0
	while x < size.x:
		ci.draw_line(Vector2(x, ih + 3), Vector2(x, ih + CreatorStage.FLOOR_H), floor_color.darkened(0.2), 1.0)
		x += 34.0 + (row % 3) * 9.0
		row += 1
	ci.draw_rect(Rect2(0, ih - 2, size.x, 2), Color(0, 0, 0, 0.12))
	for side: int in doors:
		_doorway(pen, ci, side, size, wall, trim)


## Furniture from the level's data, in list order (rugs first in the data, so they sit underneath).
static func draw_furniture(ci: CanvasItem, items: Array, size: Vector2, daylight: float, t: float, tv_on: bool) -> void:
	var pen := InkPen.new(ci, Transform2D.IDENTITY)
	var ih := interior_h(size)
	for item: Dictionary in items:
		var w := float(item.get("w", 0.1)) * size.x
		var h := float(item.get("h", 0.1)) * ih
		var x := float(item.get("x", 0.0)) * size.x
		var y := float(item.get("y", 0.0)) * ih if bool(item.get("wall", false)) else ih - h
		var rect := Rect2(x, y, w, h)
		var colour := PlaceholderArt.color(item.get("color", null), Color("b08968"))
		match str(item.get("kind", "")):
			"window":
				_window(pen, ci, rect, daylight, t)
			"couch":
				_couch(pen, ci, rect, colour, item, ih)
			"tv":
				_tv(pen, ci, rect, colour, tv_on, t)
			"coffee_table":
				_coffee_table(pen, ci, rect, colour)
			"plant":
				_plant(pen, ci, rect)
			"beanbag":
				_beanbag(pen, ci, rect, colour)
			"rug":
				_rug(pen, ci, rect, colour)
			"poster":
				_poster(pen, ci, rect, colour)
			"neon_sign":
				_neon(pen, ci, rect, colour, str(item.get("text", "")), t)
			_:
				PlaceholderArt.draw_furniture(ci, item, rect)


## Night falls inside too: a cool dim over the room, warm pools of light from lamps and the TV.
static func draw_lighting(ci: CanvasItem, size: Vector2, daylight: float, light_spots: Array) -> void:
	var night := 1.0 - daylight
	if night <= 0.01:
		return
	ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.18, 0.45 * night))
	for spot: Array in light_spots:
		var centre: Vector2 = spot[0]
		var radius: float = spot[1]
		var colour: Color = spot[2]
		for k in 10:
			var r := radius * (1.0 - k * 0.09)
			PlaceholderArt.draw_ellipse(ci, centre, Vector2(r, r * 0.8), Color(colour, 0.028 * night))


## The cut-away edge of the dollhouse: wall section around the room, ceiling and floor slabs.
static func draw_frame(ci: CanvasItem, size: Vector2, exterior: Color) -> void:
	var wall_w := 10.0
	ci.draw_rect(Rect2(-wall_w, -wall_w, size.x + wall_w * 2.0, wall_w), exterior)
	ci.draw_rect(Rect2(-wall_w, size.y, size.x + wall_w * 2.0, wall_w + 4.0), exterior.darkened(0.35))
	ci.draw_rect(Rect2(-wall_w, 0, wall_w, size.y), exterior)
	ci.draw_rect(Rect2(size.x, 0, wall_w, size.y), exterior)
	ci.draw_rect(Rect2(-wall_w, -wall_w, size.x + wall_w * 2.0, size.y + wall_w * 2.0 + 4.0), INK, false, 2.5)
	ci.draw_rect(Rect2(Vector2.ZERO, size), INK, false, 2.0)


# ---------------------------------------------------------------------------
# Architecture
# ---------------------------------------------------------------------------

static func _wall_pattern(ci: CanvasItem, pattern: String, wall: Color, rect: Rect2) -> void:
	match pattern:
		"stripes":
			var x := rect.position.x + 6.0
			while x < rect.end.x:
				ci.draw_rect(Rect2(x, rect.position.y, 9.0, rect.size.y), Color(wall.darkened(0.08), 0.8))
				ci.draw_line(Vector2(x + 11.0, rect.position.y), Vector2(x + 11.0, rect.end.y), Color(wall.lightened(0.25), 0.6), 1.0)
				x += 22.0
		"dots":
			var row := 0
			var y := rect.position.y + 10.0
			while y < rect.end.y:
				var x := rect.position.x + (10.0 if row % 2 == 0 else 22.0)
				while x < rect.end.x:
					ci.draw_circle(Vector2(x, y), 2.0, Color(wall.lightened(0.2), 0.9))
					ci.draw_circle(Vector2(x + 0.6, y + 0.6), 2.0, Color(wall.darkened(0.15), 0.25))
					x += 24.0
				y += 18.0
				row += 1
		_:
			# Subtle diamond wallpaper so plain walls still read as a finished room.
			var y := rect.position.y
			var row := 0
			while y < rect.end.y:
				var x := rect.position.x + (0.0 if row % 2 == 0 else 14.0)
				while x < rect.end.x:
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x, y - 3), Vector2(x + 3, y), Vector2(x, y + 3), Vector2(x - 3, y)]), Color(wall.darkened(0.1), 0.35))
					x += 28.0
				y += 20.0
				row += 1


static func _doorway(pen: InkPen, ci: CanvasItem, side: int, size: Vector2, wall: Color, trim: Color) -> void:
	var ih := interior_h(size)
	var w := 34.0
	var top := ih * 0.24
	var x := size.x - w - 6.0 if side > 0 else 6.0
	var opening := Rect2(x, top, w, ih - top)
	ci.draw_polygon(PackedVector2Array([opening.position, Vector2(opening.end.x, opening.position.y), opening.end, Vector2(opening.position.x, opening.end.y)]),
		PackedColorArray([wall.darkened(0.55), wall.darkened(0.55), wall.darkened(0.4), wall.darkened(0.4)]))
	var frame := PackedVector2Array([Vector2(x - 4, ih), Vector2(x - 4, top - 5), Vector2(x + w + 4, top - 5), Vector2(x + w + 4, ih),
		Vector2(x + w, ih), Vector2(x + w, top), Vector2(x, top), Vector2(x, ih)])
	pen.shape(frame, trim, 0.6)
	# Light switch on the wall beside the doorway.
	var sx := x - 14.0 if side > 0 else x + w + 8.0
	pen.shape(PackedVector2Array([Vector2(sx, ih * 0.5), Vector2(sx + 6, ih * 0.5), Vector2(sx + 6, ih * 0.5 + 9), Vector2(sx, ih * 0.5 + 9)]), Color("fbf3ee"), 0.4)
	ci.draw_rect(Rect2(sx + 2.2, ih * 0.5 + 2.5, 1.6, 4), Color("c9b8a8"))


## Pendant lamp hanging from the ceiling (drawn in front of wall decor).
static func draw_ceiling_light(ci: CanvasItem, at: Vector2, daylight: float) -> void:
	var pen := InkPen.new(ci, Transform2D.IDENTITY)
	ci.draw_line(at, at + Vector2(0, 16), INK, 1.0)
	var shade := PackedVector2Array([at + Vector2(-9, 26), at + Vector2(-4, 16), at + Vector2(4, 16), at + Vector2(9, 26)])
	pen.shape_lit(shade, Color("ffe2b8"), Color("e8b48a"), 0.6)
	var glow := 1.0 - daylight
	if glow > 0.01:
		ci.draw_circle(at + Vector2(0, 27), 3.0, Color(1, 0.95, 0.75, 0.9 * glow))


# ---------------------------------------------------------------------------
# Furniture
# ---------------------------------------------------------------------------

static func _window(pen: InkPen, ci: CanvasItem, r: Rect2, daylight: float, t: float) -> void:
	var sky_top := Color("16153a").lerp(Color("59b7f0"), daylight)
	var sky_bottom := Color("3a2f6b").lerp(Color("cfeefc"), daylight)
	var frame := r.grow(4.0)
	pen.shape(PackedVector2Array([frame.position, Vector2(frame.end.x, frame.position.y), frame.end, Vector2(frame.position.x, frame.end.y)]), Color("fbf3ee"), 0.6)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	if daylight > 0.3:
		var cx := r.position.x + fmod(t * 2.0, r.size.x + 20.0) - 10.0
		for k in 3:
			PlaceholderArt.draw_ellipse(ci, Vector2(clampf(cx + k * 6.0, r.position.x + 4, r.end.x - 4), r.position.y + r.size.y * 0.3 - (k % 2) * 3.0), Vector2(6, 3), Color(1, 1, 1, 0.75 * daylight))
	else:
		for i in 5:
			var p := r.position + Vector2(fmod(i * 13.7, r.size.x - 4) + 2, fmod(i * 9.3, r.size.y * 0.7) + 3)
			ci.draw_circle(p, 0.8 + 0.4 * absf(sin(t * 2.0 + i)), Color(1, 1, 0.9, 1.0 - daylight))
	ci.draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color("fbf3ee"), 2.5)
	ci.draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color("fbf3ee"), 2.5)
	ci.draw_line(r.position + Vector2(3, r.size.y - 5), r.position + Vector2(r.size.x * 0.4, 4), Color(1, 1, 1, 0.35), 1.5)
	# Sill and curtains with folds and tie-backs.
	pen.shape(PackedVector2Array([Vector2(frame.position.x - 4, frame.end.y), Vector2(frame.end.x + 4, frame.end.y),
		Vector2(frame.end.x + 4, frame.end.y + 4), Vector2(frame.position.x - 4, frame.end.y + 4)]), Color("efe2d6"), 0.5)
	var curtain := Color("ff8fb8")
	for side: float in [-1.0, 1.0]:
		# Hangs from the rod just outside the frame, overlaps the glass a little, gathered by a tie-back.
		var edge := frame.position.x if side < 0 else frame.end.x
		var outer := edge + side * 10.0
		var inner := edge - side * 7.0
		var tie_y := r.get_center().y + 6.0
		var poly := PackedVector2Array([Vector2(outer, frame.position.y - 6), Vector2(inner, frame.position.y - 6),
			Vector2(edge - side * 1.0, tie_y), Vector2(inner + side * 1.0, frame.end.y + 12), Vector2(outer + side * 2.0, frame.end.y + 14)])
		pen.shape_lit(poly, curtain.lightened(0.15), curtain.darkened(0.12), 0.55)
		for k in 2:
			var fx := lerpf(inner, outer, 0.35 + k * 0.3)
			ci.draw_line(Vector2(fx, frame.position.y - 4), Vector2(fx + side * 1.5, frame.end.y + 8), curtain.darkened(0.25), 0.8)
		ci.draw_line(Vector2(edge - side * 2.0, tie_y), Vector2(outer + side * 1.0, tie_y + 1.0), Color("ffd166"), 1.5)
	ci.draw_line(Vector2(frame.position.x - 16, frame.position.y - 7), Vector2(frame.end.x + 16, frame.position.y - 7), Color("8d6e63"), 2.0)
	# Daylight pouring in.
	if daylight > 0.05:
		ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, r.size.y), r.end, Vector2(r.end.x + 40, r.end.y + 70), Vector2(r.position.x + 30, r.end.y + 70)]),
			Color(1, 0.97, 0.8, 0.07 * daylight))


static func _couch(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color, item: Dictionary, ih: float) -> void:
	var seat_top := ih - 0.115 * ih
	var arm_w := r.size.x * 0.1
	var lit := colour.lightened(0.12)
	var shade := colour.darkened(0.18)
	# Legs, back, seat base and cushions, arms and pillows.
	for lx: float in [r.position.x + arm_w * 0.6, r.end.x - arm_w * 0.6]:
		pen.shape(PackedVector2Array([Vector2(lx - 2, ih - 5), Vector2(lx + 2, ih - 5), Vector2(lx + 1.5, ih), Vector2(lx - 1.5, ih)]), Color("5d4037"), 0.4)
	var back := InkPen.smooth_closed(PackedVector2Array([Vector2(r.position.x + arm_w * 0.6, seat_top + 2), Vector2(r.position.x + arm_w * 0.7, r.position.y + 4),
		Vector2(r.get_center().x, r.position.y - 1), Vector2(r.end.x - arm_w * 0.7, r.position.y + 4), Vector2(r.end.x - arm_w * 0.6, seat_top + 2)]), 3)
	pen.shape_lit(back, lit, shade, 0.7)
	var seats := int(maxi(1, roundi(r.size.x * 0.74 / 39.0)))
	var inner := Rect2(r.position.x + arm_w * 0.8, r.position.y, r.size.x - arm_w * 1.6, r.size.y)
	for i in seats:
		var cx := inner.position.x + inner.size.x * (i + 0.5) / seats
		var cw := inner.size.x / seats * 0.5
		var cushion := InkPen.smooth_closed(PackedVector2Array([Vector2(cx - cw + 1, r.position.y + 7), Vector2(cx + cw - 1, r.position.y + 7),
			Vector2(cx + cw - 1, seat_top - 2), Vector2(cx - cw + 1, seat_top - 2)]), 3)
		pen.fill_lit(cushion, colour.lightened(0.18), colour)
		pen.stroke(cushion, colour.darkened(0.35), 0.35, true)
	var base := PackedVector2Array([Vector2(r.position.x + arm_w * 0.5, seat_top), Vector2(r.end.x - arm_w * 0.5, seat_top),
		Vector2(r.end.x - arm_w * 0.5, ih - 5), Vector2(r.position.x + arm_w * 0.5, ih - 5)])
	pen.shape_lit(base, colour, shade.darkened(0.1), 0.7)
	for i in seats:
		var cx := inner.position.x + inner.size.x * (i + 0.5) / seats
		var cw := inner.size.x / seats * 0.5
		var seat := InkPen.smooth_closed(PackedVector2Array([Vector2(cx - cw + 0.5, seat_top - 3), Vector2(cx + cw - 0.5, seat_top - 3),
			Vector2(cx + cw - 0.5, seat_top + 6), Vector2(cx - cw + 0.5, seat_top + 6)]), 3)
		pen.shape_lit(seat, lit.lightened(0.08), colour, 0.5)
	for side: float in [-1.0, 1.0]:
		var ax := r.position.x if side < 0 else r.end.x - arm_w
		var arm := InkPen.smooth_closed(PackedVector2Array([Vector2(ax, seat_top - 10), Vector2(ax + arm_w, seat_top - 12), Vector2(ax + arm_w, ih - 5), Vector2(ax, ih - 5)]), 3)
		pen.shape_lit(arm, lit, shade, 0.7)
		pen.fill(InkPen.ellipse(Vector2(ax + arm_w * 0.5, seat_top - 10), Vector2(arm_w * 0.45, 2.2), 12), Color(lit.lightened(0.2), 0.8))
	var pillow := Color("ffd166") if colour.get_luminance() < 0.55 else Color("6a4c93")
	for side: float in [-1.0, 1.0]:
		var px := (inner.position.x + 8.0) if side < 0 else (inner.end.x - 8.0)
		var poly := InkPen.smooth_closed(PackedVector2Array([Vector2(px - 7, seat_top - 4), Vector2(px - 5, seat_top - 15), Vector2(px + 5, seat_top - 16), Vector2(px + 7, seat_top - 4)]), 3)
		pen.shape_lit(poly, pillow.lightened(0.15), pillow.darkened(0.15), 0.5)


static func _tv(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color, on: bool, t: float) -> void:
	var cabinet := Rect2(r.position.x, r.end.y - r.size.y * 0.34, r.size.x, r.size.y * 0.34)
	pen.shape_lit(_rect(cabinet), colour.lightened(0.2), colour.darkened(0.15), 0.7)
	ci.draw_line(Vector2(cabinet.get_center().x, cabinet.position.y + 3), Vector2(cabinet.get_center().x, cabinet.end.y - 3), colour.darkened(0.35), 1.0)
	for kx: float in [0.25, 0.75]:
		ci.draw_circle(Vector2(cabinet.position.x + cabinet.size.x * kx + (3.0 if kx < 0.5 else -3.0), cabinet.get_center().y), 1.2, Color("ffd166"))
	var screen := Rect2(r.position.x + r.size.x * 0.08, r.position.y, r.size.x * 0.84, r.size.y * 0.6)
	ci.draw_rect(Rect2(screen.get_center().x - 3, screen.end.y, 6, cabinet.position.y - screen.end.y), Color("2b2b2b"))
	pen.shape(_rect(screen), Color("1b1b22"), 0.7)
	var glass := screen.grow(-2.5)
	if on:
		var hue := fmod(t * 0.05, 1.0)
		var a := Color.from_hsv(hue, 0.55, 0.95)
		var b := Color.from_hsv(fmod(hue + 0.35, 1.0), 0.6, 0.7)
		ci.draw_polygon(_rect(glass), PackedColorArray([a, b, a.darkened(0.2), b.darkened(0.3)]))
		PlaceholderArt.draw_heart(ci, glass.get_center() + Vector2(sin(t * 1.3) * glass.size.x * 0.25, 0), glass.size.y * 0.5, Color(1, 1, 1, 0.55))
	else:
		ci.draw_rect(glass, Color("2a2f3a"))
	ci.draw_line(glass.position + Vector2(2, glass.size.y - 2), glass.position + Vector2(glass.size.x * 0.35, 2), Color(1, 1, 1, 0.12), 2.0)


static func _coffee_table(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color) -> void:
	var top := Rect2(r.position.x, r.position.y + r.size.y * 0.25, r.size.x, r.size.y * 0.18)
	for lx: float in [r.position.x + 3.0, r.end.x - 5.0]:
		pen.shape(_rect(Rect2(lx, top.end.y, 2.5, r.end.y - top.end.y)), colour.darkened(0.2), 0.4)
	pen.shape_lit(_rect(top), colour.lightened(0.2), colour, 0.6)
	# A mug and a stack of magazines.
	var mug := Vector2(r.position.x + r.size.x * 0.68, top.position.y)
	pen.shape(_rect(Rect2(mug + Vector2(-3, -6), Vector2(6, 6))), Color("fbf3ee"), 0.4)
	ci.draw_arc(mug + Vector2(4, -3), 2.0, -PI * 0.5, PI * 0.5, 6, INK, 0.8)
	pen.shape(_rect(Rect2(r.position.x + 3, top.position.y - 2.5, r.size.x * 0.45, 2.5)), Color("ff7ab8"), 0.3)
	pen.shape(_rect(Rect2(r.position.x + 4, top.position.y - 4.5, r.size.x * 0.4, 2.0)), Color("7ec4cf"), 0.3)


static func _plant(pen: InkPen, ci: CanvasItem, r: Rect2) -> void:
	var pot_h := r.size.y * 0.3
	var pot := PackedVector2Array([Vector2(r.position.x, r.end.y - pot_h), Vector2(r.end.x, r.end.y - pot_h), Vector2(r.end.x - r.size.x * 0.15, r.end.y), Vector2(r.position.x + r.size.x * 0.15, r.end.y)])
	var leaf := Color("3fa34d")
	var base := Vector2(r.get_center().x, r.end.y - pot_h)
	for i in 7:
		var a := -PI * 0.5 + (i - 3) * 0.32
		var length := r.size.y * (0.55 + 0.12 * (i % 3))
		var tip := base + Vector2(cos(a), sin(a)) * length
		var blade := InkPen.taper(InkPen.quad(base, base.lerp(tip, 0.5) + Vector2(cos(a + 1.2), 0) * 4.0, tip, 6), 3.5, 0.3, 2.0)
		pen.shape(blade, leaf.darkened(0.12 * (i % 2)), 0.4)
	pen.shape_lit(pot, Color("e07a5f"), Color("b5543c"), 0.6)
	ci.draw_rect(Rect2(r.position.x - 1, r.end.y - pot_h, r.size.x + 2, 3), Color("c4644a"))


static func _beanbag(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color) -> void:
	var blob := InkPen.smooth_closed(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x + 1, r.position.y + r.size.y * 0.45),
		Vector2(r.position.x + r.size.x * 0.3, r.position.y), Vector2(r.position.x + r.size.x * 0.75, r.position.y + 2), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Vector2(r.end.x, r.end.y)]), 4)
	pen.shape_lit(blob, colour.lightened(0.15), colour.darkened(0.2), 0.7)
	pen.fill(InkPen.ellipse(Vector2(r.get_center().x, r.position.y + r.size.y * 0.42), Vector2(r.size.x * 0.28, r.size.y * 0.1), 14), colour.darkened(0.12))
	ci.draw_arc(Vector2(r.position.x + r.size.x * 0.3, r.position.y + r.size.y * 0.3), r.size.x * 0.12, PI * 1.1, PI * 1.6, 6, Color(1, 1, 1, 0.4), 1.5)


static func _rug(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color) -> void:
	var floor_y := r.end.y
	var band := InkPen.smooth_closed(PackedVector2Array([Vector2(r.position.x, floor_y + 1), Vector2(r.position.x + 6, floor_y - 3), Vector2(r.end.x - 6, floor_y - 3), Vector2(r.end.x, floor_y + 1),
		Vector2(r.end.x - 6, floor_y + 6), Vector2(r.position.x + 6, floor_y + 6)]), 3)
	pen.shape_lit(band, colour.lightened(0.1), colour.darkened(0.1), 0.5)
	var x := r.position.x + 10.0
	while x < r.end.x - 8.0:
		ci.draw_line(Vector2(x, floor_y - 1), Vector2(x + 4, floor_y + 4), colour.darkened(0.25), 1.0)
		x += 12.0
	for side: float in [r.position.x - 3.0, r.end.x + 1.0]:
		for k in 3:
			ci.draw_line(Vector2(side, floor_y + k * 2.0), Vector2(side + 2.0, floor_y + k * 2.0), colour.darkened(0.3), 0.8)


static func _poster(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color) -> void:
	pen.shape(_rect(r.grow(2.5)), Color("3b2433"), 0.5)
	ci.draw_polygon(_rect(r), PackedColorArray([colour.lightened(0.3), colour.lightened(0.3), colour.darkened(0.2), colour.darkened(0.2)]))
	PlaceholderArt.draw_star(ci, r.get_center() + Vector2(-r.size.x * 0.12, -r.size.y * 0.1), r.size.y * 0.22, Color("ffd166"))
	PlaceholderArt.draw_heart(ci, r.get_center() + Vector2(r.size.x * 0.16, r.size.y * 0.18), r.size.y * 0.35, Color("ff5fa2"))


static func _neon(pen: InkPen, ci: CanvasItem, r: Rect2, colour: Color, text: String, t: float) -> void:
	var flicker := 0.85 + 0.15 * sin(t * 7.0) * sin(t * 2.3)
	PlaceholderArt.draw_rounded_rect(ci, r.grow(6), Color(colour, 0.12 * flicker), 14)
	PlaceholderArt.draw_rounded_rect(ci, r, Color(0.08, 0.04, 0.12, 0.85), 8, Color(colour, flicker), 2)
	var size := int(clampf(r.size.y * 0.55, 8.0, 22.0))
	PlaceholderArt.draw_text(ci, Vector2(r.position.x, r.get_center().y + size * 0.36), text, size, Color(colour.lightened(0.5), flicker), r.size.x, HORIZONTAL_ALIGNMENT_CENTER, 3, Color(colour, 0.6 * flicker))


static func _rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
