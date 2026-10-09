class_name PlaceholderArt
extends RefCounted
## Procedural placeholder art. Functions draw onto any CanvasItem so the same art is reused
## by the house view and UI portraits. Real artwork replaces these via ArtLibrary paths in data.

const OUTLINE := Color(0.17, 0.1, 0.16, 0.85)


static func color(value: Variant, fallback: Color) -> Color:
	if value is String and Color.html_is_valid(value):
		return Color.html(value)
	return fallback


static func ellipse_points(center: Vector2, radii: Vector2, segments: int = 24) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


static func draw_ellipse(ci: CanvasItem, center: Vector2, radii: Vector2, fill: Color) -> void:
	ci.draw_colored_polygon(ellipse_points(center, radii), fill)


static func draw_ellipse_outline(ci: CanvasItem, center: Vector2, radii: Vector2, line: Color, width: float = 2.0) -> void:
	var points := ellipse_points(center, radii)
	points.append(points[0])
	ci.draw_polyline(points, line, width, true)


static func draw_rounded_rect(ci: CanvasItem, rect: Rect2, fill: Color, radius: float = 6.0, border: Color = Color.TRANSPARENT, border_width: int = 0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(radius))
	if border_width > 0:
		box.border_color = border
		box.set_border_width_all(border_width)
	box.anti_aliasing = true
	box.draw(ci.get_canvas_item(), rect)


static func draw_star(ci: CanvasItem, center: Vector2, radius: float, fill: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var angle := -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	ci.draw_colored_polygon(points, fill)


static func draw_heart(ci: CanvasItem, center: Vector2, size: float, fill: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(center + Vector2(x, y) * (size / 32.0))
	ci.draw_colored_polygon(points, fill)


static func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: int, fill: Color, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, outline: int = 0, outline_color: Color = OUTLINE) -> void:
	var font := ThemeDB.fallback_font
	if outline > 0:
		ci.draw_string_outline(font, pos, text, align, width, size, outline, outline_color)
	ci.draw_string(font, pos, text, align, width, size, fill)


# ---------------------------------------------------------------------------
# Rooms
# ---------------------------------------------------------------------------

static func draw_wall_pattern(ci: CanvasItem, rect: Rect2, pattern: String, wall: Color) -> void:
	match pattern:
		"stripes":
			var stripe := wall.darkened(0.06)
			var x := rect.position.x + 6.0
			while x < rect.end.x:
				ci.draw_rect(Rect2(x, rect.position.y, 9.0, rect.size.y), stripe)
				x += 22.0
		"dots":
			var dot := wall.lightened(0.18)
			var row := 0
			var y := rect.position.y + 12.0
			while y < rect.end.y:
				var x := rect.position.x + (12.0 if row % 2 == 0 else 24.0)
				while x < rect.end.x:
					ci.draw_circle(Vector2(x, y), 2.2, dot)
					x += 24.0
				y += 18.0
				row += 1


static func draw_floor(ci: CanvasItem, rect: Rect2, floor_color: Color) -> void:
	ci.draw_rect(rect, floor_color)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0)), floor_color.lightened(0.15))
	var x := rect.position.x + 30.0
	while x < rect.end.x:
		ci.draw_line(Vector2(x, rect.position.y + 3.0), Vector2(x, rect.end.y), floor_color.darkened(0.15), 1.0)
		x += 46.0


## Draws one furniture item. `rect` is in the caller's coordinates; y is the item's top.
static func draw_furniture(ci: CanvasItem, item: Dictionary, rect: Rect2) -> void:
	var tex := ArtLibrary.texture(str(item.get("texture", "")))
	if tex != null:
		ci.draw_texture_rect(tex, rect, false)
		return
	var c := color(item.get("color", null), Color("b08968"))
	var p := rect.position
	var s := rect.size
	var wood := Color("6d4c41")
	match str(item.get("kind", "")):
		"bed":
			ci.draw_rect(Rect2(p.x, p.y - s.y * 0.7, s.x * 0.06, s.y * 1.7), wood)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.03, p.y + s.y * 0.45, s.x * 0.97, s.y * 0.4), wood, 3)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.05, p.y + s.y * 0.1, s.x * 0.94, s.y * 0.45), Color("fbf3ee"), 5)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.36, p.y + s.y * 0.05, s.x * 0.64, s.y * 0.55), c, 6)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.08, p.y - s.y * 0.12, s.x * 0.2, s.y * 0.38), Color.WHITE, 6)
			ci.draw_rect(Rect2(p.x + s.x * 0.06, p.y + s.y * 0.85, 5.0, s.y * 0.15), wood)
			ci.draw_rect(Rect2(p.x + s.x * 0.95, p.y + s.y * 0.85, 5.0, s.y * 0.15), wood)
		"mattress":
			draw_rounded_rect(ci, rect, c, 5)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.04, p.y - s.y * 0.35, s.x * 0.2, s.y * 0.6), Color("f2f2f2"), 5)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.4, p.y - s.y * 0.15, s.x * 0.55, s.y * 0.5), c.lightened(0.25), 6)
		"box":
			ci.draw_rect(rect, c)
			ci.draw_rect(Rect2(p.x, p.y, s.x, s.y * 0.18), c.darkened(0.15))
			ci.draw_rect(Rect2(p.x + s.x * 0.42, p.y, s.x * 0.16, s.y), Color(1, 1, 1, 0.25))
		"window":
			draw_rounded_rect(ci, rect, Color.WHITE, 4)
			ci.draw_rect(rect.grow(-4.0), Color("a8dcff"))
			ci.draw_rect(Rect2(p.x + 4.0, p.y + 4.0, s.x * 0.35, s.y - 8.0), Color(1, 1, 1, 0.25))
			ci.draw_line(Vector2(p.x + s.x / 2.0, p.y), Vector2(p.x + s.x / 2.0, p.y + s.y), Color.WHITE, 3.0)
			ci.draw_line(Vector2(p.x, p.y + s.y / 2.0), Vector2(p.x + s.x, p.y + s.y / 2.0), Color.WHITE, 3.0)
			ci.draw_rect(Rect2(p.x - 4.0, p.y + s.y, s.x + 8.0, 5.0), Color("eeeeee"))
		"poster":
			ci.draw_rect(rect, Color.WHITE)
			ci.draw_rect(rect.grow(-3.0), c)
			ci.draw_circle(p + s * Vector2(0.5, 0.4), minf(s.x, s.y) * 0.22, c.lightened(0.4))
		"lamp":
			draw_ellipse(ci, Vector2(p.x + s.x / 2.0, p.y + s.y - 2.0), Vector2(s.x * 0.5, 3.0), wood)
			ci.draw_line(Vector2(p.x + s.x / 2.0, p.y + s.y), Vector2(p.x + s.x / 2.0, p.y + s.y * 0.2), Color("555555"), 2.0)
			ci.draw_circle(Vector2(p.x + s.x / 2.0, p.y + s.y * 0.2), s.x * 1.6, Color(c.r, c.g, c.b, 0.18))
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(p.x + s.x * 0.15, p.y), Vector2(p.x + s.x * 0.85, p.y),
				Vector2(p.x + s.x * 1.1, p.y + s.y * 0.25), Vector2(p.x - s.x * 0.1, p.y + s.y * 0.25)]), c)
		"plant":
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(p.x, p.y + s.y * 0.6), Vector2(p.x + s.x, p.y + s.y * 0.6),
				Vector2(p.x + s.x * 0.85, p.y + s.y), Vector2(p.x + s.x * 0.15, p.y + s.y)]), Color("c56a3a"))
			var leaf := Color("3fa34d")
			draw_ellipse(ci, Vector2(p.x + s.x * 0.5, p.y + s.y * 0.25), Vector2(s.x * 0.35, s.y * 0.25), leaf)
			draw_ellipse(ci, Vector2(p.x + s.x * 0.2, p.y + s.y * 0.42), Vector2(s.x * 0.35, s.y * 0.14), leaf.darkened(0.1))
			draw_ellipse(ci, Vector2(p.x + s.x * 0.8, p.y + s.y * 0.4), Vector2(s.x * 0.35, s.y * 0.14), leaf.lightened(0.1))
		"rug":
			draw_rounded_rect(ci, Rect2(p.x, p.y, s.x, maxf(s.y, 5.0)), c, 3)
			ci.draw_line(Vector2(p.x + 6.0, p.y + 2.0), Vector2(p.x + s.x - 6.0, p.y + 2.0), c.lightened(0.3), 1.0)
		"couch":
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.06, p.y, s.x * 0.88, s.y * 0.55), c.darkened(0.08), 8)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.06, p.y + s.y * 0.45, s.x * 0.88, s.y * 0.38), c, 6)
			draw_rounded_rect(ci, Rect2(p.x, p.y + s.y * 0.3, s.x * 0.1, s.y * 0.55), c.darkened(0.15), 6)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.9, p.y + s.y * 0.3, s.x * 0.1, s.y * 0.55), c.darkened(0.15), 6)
			ci.draw_line(Vector2(p.x + s.x * 0.5, p.y + s.y * 0.48), Vector2(p.x + s.x * 0.5, p.y + s.y * 0.8), c.darkened(0.2), 1.5)
			ci.draw_rect(Rect2(p.x + s.x * 0.08, p.y + s.y * 0.83, 4.0, s.y * 0.17), wood)
			ci.draw_rect(Rect2(p.x + s.x * 0.9, p.y + s.y * 0.83, 4.0, s.y * 0.17), wood)
			draw_rounded_rect(ci, Rect2(p.x + s.x * 0.14, p.y + s.y * 0.2, s.x * 0.14, s.y * 0.3), Color("ffd166"), 5)
		"tv":
			draw_rounded_rect(ci, Rect2(p.x, p.y + s.y * 0.62, s.x, s.y * 0.38), c, 3)
			ci.draw_rect(Rect2(p.x + s.x * 0.05, p.y, s.x * 0.9, s.y * 0.55), Color("1b1b1b"))
			ci.draw_rect(Rect2(p.x + s.x * 0.09, p.y + s.y * 0.05, s.x * 0.82, s.y * 0.45), Color("3d7fb8"))
			ci.draw_line(Vector2(p.x + s.x * 0.15, p.y + s.y * 0.1), Vector2(p.x + s.x * 0.35, p.y + s.y * 0.1), Color(1, 1, 1, 0.4), 2.0)
		"coffee_table":
			ci.draw_rect(Rect2(p.x, p.y, s.x, s.y * 0.25), c)
			ci.draw_rect(Rect2(p.x + 3.0, p.y + s.y * 0.25, 3.0, s.y * 0.75), c.darkened(0.2))
			ci.draw_rect(Rect2(p.x + s.x - 6.0, p.y + s.y * 0.25, 3.0, s.y * 0.75), c.darkened(0.2))
			ci.draw_rect(Rect2(p.x + s.x * 0.3, p.y - 7.0, 6.0, 7.0), Color("ff7aa8"))
		"fairy_lights":
			var bulbs := [Color("ffd166"), Color("ff7aa8"), Color("7df9ff"), Color("b8f2a0")]
			var prev := p
			for i in range(1, 15):
				var f := i / 14.0
				var point := Vector2(p.x + s.x * f, p.y + sin(f * PI * 3.0) * s.y * 0.5 + s.y * 0.5)
				ci.draw_line(prev, point, Color("444444"), 1.0)
				ci.draw_circle(point, 2.6, bulbs[i % bulbs.size()])
				prev = point
		"chandelier":
			ci.draw_line(Vector2(p.x + s.x / 2.0, p.y), Vector2(p.x + s.x / 2.0, p.y + s.y * 0.5), Color("b8860b"), 2.0)
			draw_ellipse(ci, Vector2(p.x + s.x / 2.0, p.y + s.y * 0.65), Vector2(s.x * 0.5, s.y * 0.14), Color("d4af37"))
			for i in 4:
				var cx := p.x + s.x * (0.1 + 0.27 * i)
				ci.draw_circle(Vector2(cx, p.y + s.y * 0.5), 3.0, Color("fff3b0"))
				ci.draw_circle(Vector2(cx, p.y + s.y * 0.5), 7.0, Color(1, 0.95, 0.7, 0.25))
		"vanity":
			draw_ellipse(ci, Vector2(p.x + s.x / 2.0, p.y + s.y * 0.05), Vector2(s.x * 0.36, s.y * 0.42), Color("d4af37"))
			draw_ellipse(ci, Vector2(p.x + s.x / 2.0, p.y + s.y * 0.05), Vector2(s.x * 0.3, s.y * 0.36), Color("cfe9ff"))
			draw_rounded_rect(ci, Rect2(p.x, p.y + s.y * 0.48, s.x, s.y * 0.2), c, 3)
			ci.draw_rect(Rect2(p.x + 3.0, p.y + s.y * 0.68, 3.0, s.y * 0.32), c.darkened(0.25))
			ci.draw_rect(Rect2(p.x + s.x - 6.0, p.y + s.y * 0.68, 3.0, s.y * 0.32), c.darkened(0.25))
			ci.draw_rect(Rect2(p.x + s.x * 0.15, p.y + s.y * 0.38, 4.0, s.y * 0.1), Color("ff5fa2"))
			ci.draw_rect(Rect2(p.x + s.x * 0.75, p.y + s.y * 0.4, 5.0, s.y * 0.08), Color("7ec4cf"))
		"neon_sign":
			draw_rounded_rect(ci, rect, Color(0.08, 0.05, 0.12, 0.85), 8)
			var text := str(item.get("text", "BOP"))
			var font_size := int(clampf(s.y * 0.62, 10.0, 28.0))
			var baseline := Vector2(p.x, p.y + s.y * 0.5 + font_size * 0.36)
			draw_text(ci, baseline, text, font_size, Color.WHITE, s.x, HORIZONTAL_ALIGNMENT_CENTER, 6, Color(c.r, c.g, c.b, 0.7))
		"beanbag":
			draw_ellipse(ci, Vector2(p.x + s.x / 2.0, p.y + s.y * 0.6), Vector2(s.x / 2.0, s.y * 0.45), c)
			draw_ellipse(ci, Vector2(p.x + s.x * 0.4, p.y + s.y * 0.45), Vector2(s.x * 0.2, s.y * 0.15), c.lightened(0.2))
		"backdrop":
			ci.draw_rect(Rect2(p.x - 4.0, p.y - 6.0, s.x + 8.0, 8.0), Color("333333"))
			ci.draw_rect(rect, c)
			ci.draw_rect(Rect2(p.x, p.y, s.x * 0.12, s.y), c.darkened(0.06))
			ci.draw_rect(Rect2(p.x + s.x * 0.88, p.y, s.x * 0.12, s.y), c.darkened(0.06))
		"phone_stand":
			var top := Vector2(p.x + s.x / 2.0, p.y + s.y * 0.3)
			ci.draw_line(top, Vector2(p.x, p.y + s.y), c, 2.0)
			ci.draw_line(top, Vector2(p.x + s.x, p.y + s.y), c, 2.0)
			ci.draw_rect(Rect2(top.x - 4.0, p.y, 8.0, s.y * 0.32), Color("222222"))
			ci.draw_rect(Rect2(top.x - 3.0, p.y + 2.0, 6.0, s.y * 0.26), Color("7fd3ff"))
		"camera":
			var head := Vector2(p.x + s.x / 2.0, p.y + s.y * 0.25)
			ci.draw_line(head, Vector2(p.x, p.y + s.y), Color("444444"), 2.5)
			ci.draw_line(head, Vector2(p.x + s.x, p.y + s.y), Color("444444"), 2.5)
			ci.draw_line(head, Vector2(p.x + s.x / 2.0, p.y + s.y), Color("444444"), 2.5)
			draw_rounded_rect(ci, Rect2(p.x - s.x * 0.1, p.y, s.x * 1.0, s.y * 0.27), c, 4)
			ci.draw_rect(Rect2(p.x + s.x * 0.9, p.y + s.y * 0.05, s.x * 0.35, s.y * 0.17), Color("1a1a1a"))
			ci.draw_circle(Vector2(p.x + s.x * 1.25, p.y + s.y * 0.135), s.y * 0.07, Color("5fa8d3"))
			ci.draw_circle(Vector2(p.x + s.x * 0.1, p.y + s.y * 0.06), 2.0, Color("ff3b3b"))
		"ring_light":
			var center := Vector2(p.x + s.x / 2.0, p.y + s.x / 2.0)
			ci.draw_line(Vector2(center.x, center.y + s.x / 2.0), Vector2(center.x, p.y + s.y), Color("555555"), 2.5)
			ci.draw_line(Vector2(center.x, p.y + s.y - 4.0), Vector2(center.x - 8.0, p.y + s.y), Color("555555"), 2.0)
			ci.draw_line(Vector2(center.x, p.y + s.y - 4.0), Vector2(center.x + 8.0, p.y + s.y), Color("555555"), 2.0)
			ci.draw_circle(center, s.x * 0.9, Color(1, 1, 0.95, 0.15))
			ci.draw_arc(center, s.x * 0.42, 0.0, TAU, 32, c, 4.0, true)
		"softbox":
			ci.draw_line(Vector2(p.x + s.x / 2.0, p.y + s.y * 0.3), Vector2(p.x + s.x / 2.0, p.y + s.y), Color("555555"), 2.5)
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(p.x, p.y), Vector2(p.x + s.x, p.y + s.y * 0.05),
				Vector2(p.x + s.x, p.y + s.y * 0.3), Vector2(p.x, p.y + s.y * 0.35)]), Color("dddddd"))
			ci.draw_circle(Vector2(p.x + s.x * 0.3, p.y + s.y * 0.17), s.x * 1.4, Color(1, 1, 1, 0.12))
		_:
			draw_rounded_rect(ci, rect, c, 4)


# ---------------------------------------------------------------------------
# Creators
# ---------------------------------------------------------------------------

## Draws a creator with feet at `origin`. Poses: idle, walk, film, socialise, sleep.
## `sleep_lift` raises a sleeping creator onto the bed surface.
static func draw_creator(ci: CanvasItem, appearance: Dictionary, anim: String, t: float, origin: Vector2, facing: float = 1.0, scale: float = 1.0, sleep_lift: float = 0.0) -> void:
	if anim == "sleep":
		ci.draw_set_transform(origin + Vector2(54.0, -sleep_lift - 12.0) * scale, -PI / 2.0, Vector2(scale, scale))
	else:
		var bob := 0.0
		match anim:
			"walk":
				bob = -absf(cos(t * 9.0)) * 2.0
			_:
				bob = sin(t * 2.2) * 0.7
		ci.draw_set_transform(origin + Vector2(0.0, bob) * scale, 0.0, Vector2(facing * scale, scale))
	_draw_figure(ci, appearance, anim, t)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _draw_figure(ci: CanvasItem, ap: Dictionary, anim: String, t: float) -> void:
	var skin := color(ap.get("skin"), Color("f1c6a5"))
	var skin_shade := skin.darkened(0.12)
	var hair := color(ap.get("hair"), Color("6b3b2a"))
	var outfit := color(ap.get("outfit"), Color("e0457b"))
	var accent := color(ap.get("outfit_accent"), Color("ffd166"))
	var lips := color(ap.get("lips"), Color("c2185b"))
	var eye_color := color(ap.get("eyes"), Color("2f5d7c"))

	var leg_swing := 0.0
	var hand_front := Vector2(11.0, -57.0)
	var hand_back := Vector2(-11.0, -57.0)
	var holding_phone := false
	var eyes_closed := anim == "sleep"
	match anim:
		"walk":
			var s := sin(t * 9.0)
			leg_swing = s * 0.35
			hand_front = Vector2(8.0 - s * 9.0, -57.0)
			hand_back = Vector2(-8.0 + s * 9.0, -57.0)
		"film":
			# Alternates between two poses for the camera.
			if fmod(t, 3.0) < 1.5:
				hand_front = Vector2(8.0, -108.0)
				hand_back = Vector2(-12.0, -67.0)
			else:
				hand_front = Vector2(12.0, -67.0)
				hand_back = Vector2(-12.0, -67.0)
		"socialise":
			hand_front = Vector2(10.0, -80.0)
			hand_back = Vector2(-11.0, -64.0)
			holding_phone = true
		"selfie":
			# Phone held up at arm's length, free hand alternating between hip and a wave.
			hand_front = Vector2(17.0, -104.0)
			hand_back = Vector2(-12.0, -67.0) if fmod(t, 4.0) < 2.5 else Vector2(-14.0, -100.0)
			holding_phone = true
		"stream":
			# Chatting to camera: animated wave and gestures.
			hand_front = Vector2(15.0 + sin(t * 6.0) * 3.0, -96.0 + cos(t * 6.0) * 3.0)
			hand_back = Vector2(-12.0, -66.0) if fmod(t, 3.0) < 2.0 else Vector2(10.0, -78.0)
		"sleep":
			hand_front = Vector2(9.0, -60.0)
			hand_back = Vector2(-9.0, -60.0)

	# Back hair
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-12, -112), Vector2(11, -114), Vector2(13, -96), Vector2(10, -77),
		Vector2(-5, -73), Vector2(-14, -79), Vector2(-15, -100)]), hair.darkened(0.1))

	# Back arm
	_draw_arm(ci, Vector2(-8, -86), hand_back, skin_shade)

	# Legs and heels
	for side in [-1, 1]:
		var angle: float = leg_swing * side
		var hip := Vector2(3.0 * side, -50.0)
		var foot := hip + Vector2(sin(angle), cos(angle)) * 46.0
		ci.draw_line(hip, foot, skin if side > 0 else skin_shade, 6.5, true)
		ci.draw_colored_polygon(PackedVector2Array([
			foot + Vector2(-3, -3), foot + Vector2(7, -1), foot + Vector2(7, 2), foot + Vector2(-3, 1)]), accent.darkened(0.1))
		ci.draw_line(foot + Vector2(-3, 1), foot + Vector2(-3, 4), accent.darkened(0.3), 1.5)

	# Dress
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-8, -68), Vector2(8, -68), Vector2(13, -42), Vector2(-13, -42)]), outfit)
	ci.draw_line(Vector2(-13, -42), Vector2(13, -42), outfit.darkened(0.2), 2.0)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -89), Vector2(9, -89), Vector2(11, -84), Vector2(11, -78),
		Vector2(7, -68), Vector2(-7, -68), Vector2(-10, -78), Vector2(-10, -84)]), outfit)
	ci.draw_arc(Vector2(5, -81), 4.5, 0.3, PI - 0.3, 8, outfit.darkened(0.18), 1.2, true)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -89), Vector2(5, -89), Vector2(0, -83)]), skin)
	ci.draw_line(Vector2(-7.5, -68), Vector2(7.5, -68), accent, 2.0)

	# Neck and head
	ci.draw_rect(Rect2(-3, -95, 6, 7), skin)
	ci.draw_circle(Vector2(1, -104), 11.0, skin)
	ci.draw_circle(Vector2(-4, -97), 1.6, accent)

	# Face (looking toward +x)
	if eyes_closed:
		ci.draw_arc(Vector2(5, -105), 2.2, 0.2, PI - 0.2, 6, Color("3a2530"), 1.3)
		ci.draw_arc(Vector2(-1.5, -105), 1.8, 0.2, PI - 0.2, 6, Color("3a2530"), 1.3)
	else:
		draw_ellipse(ci, Vector2(5, -105), Vector2(2.2, 2.7), Color.WHITE)
		ci.draw_circle(Vector2(5.6, -104.8), 1.5, eye_color)
		ci.draw_circle(Vector2(5.8, -104.9), 0.7, Color.BLACK)
		draw_ellipse(ci, Vector2(-1.5, -105), Vector2(1.6, 2.5), Color.WHITE)
		ci.draw_circle(Vector2(-1.1, -104.8), 1.2, eye_color)
		ci.draw_line(Vector2(2.6, -107.6), Vector2(7.8, -107.6), Color("2a1a22"), 1.3)
		ci.draw_line(Vector2(7.8, -107.6), Vector2(9.0, -108.8), Color("2a1a22"), 1.1)
	ci.draw_line(Vector2(2.5, -110.5), Vector2(7.5, -110.8), hair.darkened(0.2), 1.2)
	ci.draw_circle(Vector2(7.5, -101.0), 2.3, Color(1.0, 0.45, 0.55, 0.35))
	draw_ellipse(ci, Vector2(5.5, -98.3), Vector2(2.6, 1.3), lips)

	# Fringe over the top of the head
	var fringe := PackedVector2Array()
	for i in 13:
		var angle := PI + PI * i / 12.0
		fringe.append(Vector2(1, -105) + Vector2(cos(angle), sin(angle)) * 12.0)
	fringe.append_array(PackedVector2Array([
		Vector2(12, -102), Vector2(8, -108), Vector2(2, -106), Vector2(-4, -108),
		Vector2(-9, -104), Vector2(-12, -98)]))
	ci.draw_colored_polygon(fringe, hair)

	# Front arm and phone
	_draw_arm(ci, Vector2(8, -86), hand_front, skin)
	if holding_phone:
		ci.draw_rect(Rect2(hand_front + Vector2(-2, -9), Vector2(6, 10)), Color("222222"))
		ci.draw_rect(Rect2(hand_front + Vector2(-1, -8), Vector2(4, 7)), Color("7fd3ff"))


static func _draw_arm(ci: CanvasItem, shoulder: Vector2, hand: Vector2, skin: Color) -> void:
	# Two-segment arm with the elbow pushed outward for a natural bend.
	var mid := (shoulder + hand) * 0.5
	var bend := (hand - shoulder).orthogonal().normalized() * 3.0
	if bend.x > 0.0:
		bend = -bend
	var elbow := mid + bend
	ci.draw_line(shoulder, elbow, skin, 4.5, true)
	ci.draw_line(elbow, hand, skin, 4.0, true)
	ci.draw_circle(hand, 2.4, skin)
