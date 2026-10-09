class_name RefinedHair
extends RefCounted
## Refined-style hair passes (RenderStyle prototype), drawn over HairPainter's shapes for every
## style and any hair colour: an outline in a deep tone of the hair, soft volume shading (lit
## crown, darker underside), strand clumps flowing from the parting, a soft rim light and a glossy
## sheen band that follows the curve of the head.

## Where the hair parts (head-local); crown strands flow out from here.
const PARTING := Vector2(0.4, -11.4)


static func outline(c: Dictionary) -> Color:
	return (c["deep"] as Color).lerp(InkPen.INK, 0.45)


## Back layer: volume, flowing strand clumps and a rim light.
static func back_extra(pen: InkPen, mass: PackedVector2Array, c: Dictionary) -> void:
	if mass.size() < 3 or not pen.lod(1.4):
		return
	pen.shade(mass, Vector2(0.3, -1.6), Color(c["deep"], 0.55))
	var box := _bounds(mass)
	if pen.lod(1.9):
		var count := clampi(int(box.size.x / 2.6), 4, 9)
		for k in count:
			var x := lerpf(box.position.x + 1.5, box.end.x - 1.5, (k + 0.5) / count)
			var path := PackedVector2Array()
			for j in 7:
				var y := lerpf(box.position.y + 2.0, box.end.y - 0.5, j / 6.0)
				path.append(Vector2(x + sin(j * 1.3 + k * 2.1) * 0.7 + (x - box.get_center().x) * 0.08 * j / 6.0, y))
			var colour: Color = Color(c["deep"], 0.4) if k % 2 == 0 else Color(c["light"], 0.4)
			pen.stroke_clipped(InkPen.smooth_open(path, 3), mass, colour, 0.14, 0.6)
	pen.shade(mass, Vector2(-0.8, 0.3), Color(c["light"], 0.5))


## Front layer (crown, fringe and locks): strand clumps from the parting, soft rim light, volume.
static func front_extra(pen: InkPen, masses: Array, c: Dictionary) -> void:
	if not pen.lod(1.4):
		return
	for mass: PackedVector2Array in masses:
		if mass.size() < 3:
			continue
		pen.shade(mass, Vector2(0.2, -1.2), Color(c["deep"], 0.4))
		if pen.lod(1.9):
			_crown_strands(pen, mass, c)
		pen.shade(mass, Vector2(-0.7, 0.35), Color(c["light"], 0.55))


## Glossy sheen across the crown: a soft band that fades at its edges and ends, plus a few crisp
## highlight strands. Replaces HairPainter's flat shine band.
static func sheen(pen: InkPen, c: Dictionary) -> void:
	var shine: Color = c["shine"]
	var centre := Vector2(0.9, -1.6)
	var radii := Vector2(8.6, 8.9)
	var a0 := PI * 1.18
	var a1 := PI * 1.82
	var steps := 14
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for i in steps + 1:
		var u := float(i) / steps
		var a := lerpf(a0, a1, u)
		var dir := Vector2(cos(a), sin(a))
		var p := centre + Vector2(dir.x * radii.x, dir.y * radii.y)
		var fade := pow(sin(u * PI), 0.8)
		var half := 0.55 + 0.55 * fade
		points.append(p + dir * half)
		points.append(p)
		points.append(p - dir * half)
		colours.append(Color(shine, 0.0))
		colours.append(Color(shine, 0.7 * fade))
		colours.append(Color(shine, 0.0))
	var indices := PackedInt32Array()
	for i in steps:
		var k := i * 3
		for row in 2:
			indices.append_array([k + row, k + row + 1, k + row + 3, k + row + 1, k + row + 4, k + row + 3])
	pen.fill_mesh(points, indices, colours, radii.x * 2.2 * 1.1)
	if pen.lod(1.4):
		for k in 4:
			var u := 0.3 + k * 0.13
			var a := lerpf(a0, a1, u)
			var p := centre + Vector2(cos(a) * radii.x, sin(a) * radii.y)
			var along := (p - PARTING).normalized()
			pen.fill(InkPen.taper(PackedVector2Array([p - along * 0.9, p, p + along * 1.1]), 0.05, 0.05, 0.32 - k * 0.04), Color(Color("fffaf2").lerp(shine, 0.3), 0.85))


static func _crown_strands(pen: InkPen, mass: PackedVector2Array, c: Dictionary) -> void:
	# Clumps run from near the parting toward the lower edge of the mass, bowing out over the
	# skull: tapered shadow grooves between locks, with a lit edge beside every other groove.
	var targets: Array[Vector2] = []
	var step := maxi(mass.size() / 9, 1)
	for i in range(step / 2, mass.size(), step):
		var p := mass[i]
		if p.y > PARTING.y + 4.0:
			targets.append(p)
	for k in targets.size():
		var t := targets[k]
		var start := Vector2(lerpf(PARTING.x, t.x, 0.5), PARTING.y + 1.6 + absf(t.x - PARTING.x) * 0.15)
		var bow := ((start + t) * 0.5 - Vector2(0.8, -1.0)).normalized() * 1.5
		var path := InkPen.quad(start, (start + t) * 0.5 + bow, t.lerp(start, 0.12), 10)
		for piece in Geometry2D.intersect_polygons(InkPen.taper(path, 0.05, 0.45, 0.25), mass):
			pen.fill(piece, Color(c["deep"], 0.45))
		if k % 2 == 0:
			var lit := InkPen.translated(path, Vector2(0.45, -0.1))
			for piece in Geometry2D.intersect_polygons(InkPen.taper(lit, 0.02, 0.22, 0.2), mass):
				pen.fill(piece, Color(c["light"], 0.6))


static func _bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box
