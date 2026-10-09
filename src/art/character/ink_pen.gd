class_name InkPen
extends RefCounted
## Screen-space drawing helper for the character art.
##
## Character geometry is authored in small "model units" (a 168 cm woman is ~120 units tall, feet at
## the origin, facing +x). Instead of scaling the canvas (which blurs antialiased edges and leaves
## filled polygons jagged at portrait sizes), the pen transforms every point to the canvas itself, so
## line widths and antialiasing feathers stay ~1 screen pixel at any zoom: crisp at 120 px in the
## house and at 600 px in the creator portrait.
##
## A pen can also *record* (see recorder()): painters draw pose-independent layers (garments, face,
## hair) once into a command list that is cached and replayed each frame, optionally with the hip
## sway shear applied, so a house full of creators stays cheap.
##
## Style rules (docs/ART_DIRECTION.md): bold ink outer contours, thinner tinted inner lines, opaque
## two-tone cel shading with a soft gradient on large shapes, light from the upper front (+x).

## Ink used for every outer contour (warm dark plum, never pure black).
const INK := Color("2a1622")
## Light direction in model space (toward the light: upper front), used for gradients.
const LIGHT := Vector2(0.55, -0.83)

enum Op { FILL, LIT, STROKE, DOT }

const MIN_AREA := 0.04
## Polygons smaller than this many square pixels aren't drawn (invisible, and unreliable to triangulate).
const MIN_PIXEL_AREA := 0.6

## Visible outer outline never exceeds this many screen pixels.
const MAX_OUTLINE_PX := 3.4
## Soft shading reaches this much further than a cel crescent (it fades out over its width).
const SOFT_SPREAD := 1.7

## Art debugging: report polygons the renderer can't triangulate (with a script backtrace).
static var debug_validate: bool = false

var ci: CanvasItem
## Model -> canvas-local transform (stack via push/pop).
var xf: Transform2D
## Screen pixels per model unit (includes the canvas item's own global scale).
var px: float = 1.0
var _local_per_px: float = 1.0
var _stack: Array[Transform2D] = []
var _recording: bool = false
var _commands: Array = []
## Refined style (RenderStyle): outlines drawn with the default INK use this colour instead (painters
## set it to a darker tone of the skin or hair), and shade() draws soft gradient shading.
var ink: Color = INK
var soft: bool = false


func _init(canvas_item: CanvasItem = null, base: Transform2D = Transform2D.IDENTITY) -> void:
	ci = canvas_item
	xf = base
	var canvas_scale := 1.0
	if ci != null and ci.is_inside_tree():
		var s := ci.get_global_transform_with_canvas().get_scale().abs()
		canvas_scale = maxf((s.x + s.y) * 0.5, 0.01)
	_local_per_px = 1.0 / canvas_scale
	px = _model_scale() * canvas_scale


## A recording pen with this pen's level of detail. Draw into it, then take commands().
func recorder() -> InkPen:
	var rec := InkPen.new()
	rec._recording = true
	rec.px = px
	rec.soft = soft
	return rec


func commands() -> Array:
	return _commands


func _model_scale() -> float:
	return sqrt(absf(xf.determinant()))


## True when the figure is drawn large enough for details that need `min_px` pixels per unit.
func lod(min_px: float) -> bool:
	return px >= min_px


func push(local: Transform2D) -> void:
	_stack.push_back(xf)
	xf = xf * local


func pop() -> void:
	if not _stack.is_empty():
		xf = _stack.pop_back()


## Line width in canvas-local units: `model_w` model units, but never thinner than `min_px` pixels.
func width(model_w: float, min_px: float = 1.0) -> float:
	return maxf(model_w * _model_scale(), min_px * _local_per_px)


# ---------------------------------------------------------------------------
# Primitives (all other drawing goes through these four)
# ---------------------------------------------------------------------------

func fill(points: PackedVector2Array, colour: Color) -> void:
	if points.size() < 3 or colour.a <= 0.0:
		return
	# Triangulated once in model space (always well-formed there) and drawn as a triangle array,
	# so tiny scaled-down shapes can't fail the engine's own triangulation.
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		if debug_validate:
			print("INVALID POLYGON (%d points) first=%s" % [points.size(), points[0]])
			print_stack()
		return
	var canvas_points := xf * points
	if _recording:
		_commands.append([Op.FILL, canvas_points, PackedColorArray([colour]), absf(area(canvas_points)), indices])
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, canvas_points, PackedColorArray([colour]))


## Fill with a soft linear gradient along the light direction (lit side -> shade side).
func fill_lit(points: PackedVector2Array, lit: Color, shade_colour: Color) -> void:
	if points.size() < 3:
		return
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		if debug_validate:
			print("INVALID LIT POLYGON (%d points) first=%s" % [points.size(), points[0]])
			print_stack()
		return
	var colours := gradient(points, lit, shade_colour)
	var canvas_points := xf * points
	if _recording:
		_commands.append([Op.LIT, canvas_points, colours, absf(area(canvas_points)), indices])
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, canvas_points, colours)


## Per-vertex colours for a soft gradient along the light direction.
static func gradient(points: PackedVector2Array, lit: Color, shade_colour: Color) -> PackedColorArray:
	var lo := INF
	var hi := -INF
	var n := points.size()
	var d := PackedFloat32Array()
	d.resize(n)
	for i in n:
		var v := points[i].x * LIGHT.x + points[i].y * LIGHT.y
		d[i] = v
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var inv := 1.0 / maxf(hi - lo, 0.001)
	var colours := PackedColorArray()
	colours.resize(n)
	for i in n:
		colours[i] = shade_colour.lerp(lit, (d[i] - lo) * inv)
	return colours


## Triangle mesh with per-vertex colours (soft gradients: see fill_radial / fill_feather).
## `area_hint` is the shape's model-space area, used to skip it when it's too small to see.
func fill_mesh(points: PackedVector2Array, indices: PackedInt32Array, colours: PackedColorArray, area_hint: float) -> void:
	if indices.is_empty():
		return
	var canvas_points := xf * points
	if _recording:
		_commands.append([Op.LIT, canvas_points, colours, absf(area_hint) * absf(xf.determinant()), indices])
		return
	RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, canvas_points, colours)


## Soft radial glow/shadow: full `colour` in the centre fading to transparent at the rim (blush,
## highlights, soft shadows). One triangle mesh, so it costs a single draw.
func fill_radial(centre: Vector2, radii: Vector2, colour: Color, rotation: float = 0.0, segments: int = 16, core: float = 0.0) -> void:
	if colour.a <= 0.0:
		return
	var points := PackedVector2Array([centre])
	var colours := PackedColorArray([colour])
	var mid := Color(colour, colour.a * 0.55)
	var clear := Color(colour, 0.0)
	var inner := ellipse(centre, radii * lerpf(0.5, 0.8, core), segments, rotation)
	var outer := ellipse(centre, radii, segments, rotation)
	points.append_array(inner)
	points.append_array(outer)
	for i in segments:
		colours.append(colour if core > 0.0 else mid)
	for i in segments:
		colours.append(clear)
	var indices := PackedInt32Array()
	for i in segments:
		var a := 1 + i
		var b := 1 + (i + 1) % segments
		indices.append_array([0, a, b, a, segments + a, b, b, segments + a, segments + b])
	fill_mesh(points, indices, colours, PI * radii.x * radii.y)


## Fills `points` with an edge that fades out over `feather` model units (soft shadows and
## highlights with an arbitrary shape). Works for shapes that are star-shaped around their centroid.
func fill_feather(points: PackedVector2Array, colour: Color, feather: float) -> void:
	var n := points.size()
	if n < 3 or colour.a <= 0.0:
		return
	var inner_idx := Geometry2D.triangulate_polygon(points)
	if inner_idx.is_empty():
		return
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= n
	var all := points.duplicate()
	var colours := PackedColorArray()
	colours.resize(n * 2)
	for i in n:
		colours[i] = colour
		var out := points[i] - centroid
		all.append(points[i] + out.normalized() * feather)
		colours[n + i] = Color(colour, 0.0)
	var indices := inner_idx.duplicate()
	for i in n:
		var j := (i + 1) % n
		indices.append_array([i, n + i, j, j, n + i, n + j])
	fill_mesh(all, indices, colours, area(points))


## Soft shading: the crescent of shade() as a gradient, opaque along the silhouette and fading to
## nothing where it meets the lit side (no hard cel edge). One mesh per crescent. With a `mask`, the
## crescent is clipped to it (shading on a garment).
func shade_soft(points: PackedVector2Array, offset: Vector2, colour: Color, mask: PackedVector2Array = PackedVector2Array()) -> void:
	var pieces := rim(points, offset)
	if mask.size() >= 3:
		var clipped: Array[PackedVector2Array] = []
		for piece in pieces:
			for part in Geometry2D.intersect_polygons(piece, mask):
				if not Geometry2D.is_polygon_clockwise(part) == Geometry2D.is_polygon_clockwise(piece) or absf(area(part)) <= MIN_AREA:
					continue
				clipped.append(part)
		pieces = clipped
	if pieces.is_empty():
		return
	# Vertices on the silhouette sit on `points`' edge; the inner (fading) edge lies inside it.
	var shrunk := Geometry2D.offset_polygon(points, -0.06)
	var inside: PackedVector2Array = shrunk[0] if shrunk.size() > 0 else points
	var clear := Color(colour, 0.0)
	for piece in pieces:
		var indices := Geometry2D.triangulate_polygon(piece)
		if indices.is_empty():
			continue
		var colours := PackedColorArray()
		colours.resize(piece.size())
		for i in piece.size():
			colours[i] = clear if Geometry2D.is_point_in_polygon(piece[i], inside) else colour
		fill_mesh(piece, indices, colours, area(piece))


func stroke(points: PackedVector2Array, colour: Color, model_w: float, closed: bool = false, min_px: float = 1.0, max_px: float = INF) -> void:
	if points.size() < 2 or colour.a <= 0.0:
		return
	var path := xf * points
	if closed:
		path.append(path[0])
		if path.size() > 2:
			path.append(path[1])
	if _recording:
		_commands.append([Op.STROKE, path, colour, model_w * _model_scale(), min_px, max_px])
		return
	ci.draw_polyline(path, colour, minf(width(model_w, min_px), max_px * _local_per_px), true)


func dot(centre: Vector2, radius: float, colour: Color, min_px: float = 0.0) -> void:
	if colour.a <= 0.0:
		return
	if _recording:
		_commands.append([Op.DOT, PackedVector2Array([xf * centre]), colour, radius * _model_scale(), min_px])
		return
	var r := maxf(radius * _model_scale(), min_px * _local_per_px * 0.5)
	ci.draw_circle(xf * centre, r, colour, true, -1.0, true)


## Applies the hip-sway shear to recorded commands once (cached per sway step), so replaying needs
## no per-point work.
static func sheared(recorded: Array, sway: float) -> Array:
	if sway == 0.0:
		return recorded
	var result: Array = []
	for command: Array in recorded:
		var copy := command.duplicate()
		copy[1] = FigureModel.shear(command[1], sway)
		result.append(copy)
	return result


## Replays recorded commands through this pen's transform. `sway` applies the hip-sway shear
## (FigureModel.shear) to every point first, so cached torso layers follow the pose.
func replay(recorded: Array, sway: float = 0.0) -> void:
	var model_scale := _model_scale()
	# Recorded polygons know their area, so slivers too small to draw are skipped without a check.
	var min_area := MIN_PIXEL_AREA * _local_per_px * _local_per_px / maxf(model_scale * model_scale, 0.0001)
	var rid := ci.get_canvas_item() if ci != null else RID()
	for command: Array in recorded:
		var points: PackedVector2Array = command[1]
		if sway != 0.0:
			points = FigureModel.shear(points, sway)
		if _recording: # nested recording (tests, baking): re-record through this transform
			var copy := command.duplicate()
			copy[1] = xf * points
			if int(command[0]) == Op.STROKE or int(command[0]) == Op.DOT:
				copy[3] = float(command[3]) * model_scale
			_commands.append(copy)
			continue
		match int(command[0]):
			Op.FILL, Op.LIT:
				if float(command[3]) >= min_area:
					RenderingServer.canvas_item_add_triangle_array(rid, command[4], xf * points, command[2])
			Op.STROKE:
				var w := maxf(float(command[3]) * model_scale, float(command[4]) * _local_per_px)
				ci.draw_polyline(xf * points, command[2], minf(w, float(command[5]) * _local_per_px), true)
			Op.DOT:
				ci.draw_circle(xf * points[0], maxf(float(command[3]) * model_scale, float(command[4]) * _local_per_px * 0.5), command[2], true, -1.0, true)




# ---------------------------------------------------------------------------
# Composite helpers
# ---------------------------------------------------------------------------

## Fill plus a same-colour hairline, which antialiases the polygon's edge (shading shapes, details).
func fill_soft(points: PackedVector2Array, colour: Color) -> void:
	if points.size() < 3:
		return
	fill(points, colour)
	if px >= 1.4: # invisible at sprite size, and strokes are the costliest draw call
		stroke(points, colour, 0.0, true, 1.0)


func line(a: Vector2, b: Vector2, colour: Color, model_w: float, min_px: float = 1.0) -> void:
	stroke(PackedVector2Array([a, b]), colour, model_w, false, min_px)


## Outline pass: a thick ink stroke whose inner half the fill pass covers, leaving a clean contour.
func contour(points: PackedVector2Array, model_w: float, colour: Color = INK, min_px: float = 1.1) -> void:
	# Bold, but capped so close-ups don't turn into thick marker lines.
	stroke(points, ink if colour == INK else colour, model_w * 2.0, true, min_px * 2.0, MAX_OUTLINE_PX * 2.0)


## Outline + fill in one go (a single isolated shape).
func shape(points: PackedVector2Array, colour: Color, outline_w: float = 0.85, outline: Color = INK) -> void:
	contour(points, outline_w, outline)
	fill(points, colour)


## Outline + gradient fill.
func shape_lit(points: PackedVector2Array, lit: Color, shade_colour: Color, outline_w: float = 0.85, outline: Color = INK) -> void:
	contour(points, outline_w, outline)
	fill_lit(points, lit, shade_colour)


## Draws several shapes as one merged silhouette: all contours first, then all fills, so where
## shapes overlap there is no seam and only the outer edge is inked.
## `parts`: Array of [points, colour] or [points, lit_colour, shade_colour].
func group(parts: Array, outline_w: float = 0.85, outline: Color = INK) -> void:
	for part: Array in parts:
		contour(part[0], outline_w, outline)
	for part: Array in parts:
		if part.size() > 2:
			fill_lit(part[0], part[1], part[2])
		else:
			fill(part[0], part[1])


## Cel shadow: the part of `points` not covered by itself shifted by `offset` (a crescent on the
## side opposite the offset), filled opaque and softened at the edge.
func shade(points: PackedVector2Array, offset: Vector2, colour: Color) -> void:
	if soft:
		shade_soft(points, offset * SOFT_SPREAD, colour)
		return
	for piece in rim(points, offset):
		fill_soft(piece, colour)


## Fills `points` clipped to `mask` (patterns on garments, shadows on skin).
func fill_clipped(points: PackedVector2Array, mask: PackedVector2Array, colour: Color) -> void:
	if points.size() < 3 or mask.size() < 3:
		return
	for piece in Geometry2D.intersect_polygons(points, mask):
		if Geometry2D.is_polygon_clockwise(piece) != Geometry2D.is_polygon_clockwise(points) or absf(area(piece)) <= MIN_AREA:
			continue # a hole or a sliver
		fill_soft(piece, colour)


## Strokes a polyline clipped to `mask`.
func stroke_clipped(path: PackedVector2Array, mask: PackedVector2Array, colour: Color, model_w: float, min_px: float = 0.6) -> void:
	if path.size() < 2 or mask.size() < 3:
		return
	for piece in Geometry2D.intersect_polyline_with_polygon(path, mask):
		stroke(piece, colour, model_w, false, min_px)


# ---------------------------------------------------------------------------
# Geometry helpers (model space, no drawing)
# ---------------------------------------------------------------------------

static func rim(points: PackedVector2Array, offset: Vector2) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if points.size() < 3:
		return result
	var clockwise := Geometry2D.is_polygon_clockwise(points)
	for piece in Geometry2D.clip_polygons(points, translated(points, offset)):
		if piece.size() >= 3 and Geometry2D.is_polygon_clockwise(piece) == clockwise and absf(area(piece)) > MIN_AREA:
			result.append(piece)
	return result


## Signed area (slivers below MIN_AREA are skipped).
static func area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func ellipse(centre: Vector2, radii: Vector2, segments: int = 20, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(segments)
	var c := cos(rotation)
	var s := sin(rotation)
	for i in segments:
		var a := TAU * i / segments
		var x := cos(a) * radii.x
		var y := sin(a) * radii.y
		points[i] = centre + Vector2(x * c - y * s, x * s + y * c)
	return points


## Arc of an ellipse from angle a0 to a1 (radians, y down), inclusive.
static func arc(centre: Vector2, radii: Vector2, a0: float, a1: float, segments: int = 10) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(a0, a1, float(i) / segments)
		points.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return points


## Quadratic Bezier from a to b with control c.
static func quad(a: Vector2, c: Vector2, b: Vector2, segments: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var u := float(i) / segments
		points.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
	return points


## Closed Catmull-Rom curve through `ctrl` (sub points per segment).
static func smooth_closed(ctrl: PackedVector2Array, sub: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in sub:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / sub))
	return out


## Open Catmull-Rom curve through `ctrl` (end points included).
static func smooth_open(ctrl: PackedVector2Array, sub: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ctrl.size()
	if n < 2:
		return ctrl
	for i in n - 1:
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, n - 1)]
		for s in sub:
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / sub))
	out.append(ctrl[n - 1])
	return out


## A tapered stroke (brow, lash wing, hair strand) as a polygon: width w0 at the start, w1 at the end,
## plus `belly` extra width in the middle.
static func taper(path: PackedVector2Array, w0: float, w1: float, belly: float = 0.0) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := path.size()
	if n < 2:
		return PackedVector2Array()
	for i in n:
		var u := float(i) / (n - 1)
		var a := path[maxi(i - 1, 0)]
		var b := path[mini(i + 1, n - 1)]
		var normal := (b - a).normalized().orthogonal()
		var half := (lerpf(w0, w1, u) + sin(u * PI) * belly) * 0.5
		left.append(path[i] + normal * half)
		right.append(path[i] - normal * half)
	right.reverse()
	left.append_array(right)
	return left


static func translated(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, offset) * points


## Opaque colour mixes shared by every layer, so palettes stay coherent across skin tones and fabrics.
static func shadow_of(colour: Color, amount: float = 0.22) -> Color:
	# Shadows shift toward a warm violet rather than grey, which keeps skin and fabric lively.
	return Color(colour.lerp(Color(0.36, 0.13, 0.33), amount).darkened(amount * 0.3), colour.a)


static func light_of(colour: Color, amount: float = 0.18) -> Color:
	return Color(colour.lerp(Color(1.0, 0.97, 0.93), amount), colour.a)


static func line_of(colour: Color, amount: float = 0.62) -> Color:
	return colour.lerp(INK, amount)
