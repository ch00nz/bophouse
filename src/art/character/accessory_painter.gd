class_name AccessoryPainter
extends RefCounted
## Jewellery and accessories listed by an outfit (`"accessories"` in data/appearance.json):
##   hoops, studs, drop_earrings  (far ear lobe, head layer)
##   choker, pendant              (neck and chest, body layer)
##   sunglasses                   (pushed up on the hair, head layer)
##   bracelet                     (near wrist, arm layer)
## Without a list, creators wear small studs.

const GOLD := Color("ffd166")


static func list(spec: Dictionary) -> Array:
	var outfit: Dictionary = spec.get("outfit", {})
	return outfit.get("accessories", ["studs"])


## Earrings: drawn after the head shape and before the front hair.
static func draw_ears(pen: InkPen, spec: Dictionary) -> void:
	var items := list(spec)
	var lobe := FacePainter.EARLOBE
	if items.has("hoops"):
		var ring := InkPen.ellipse(lobe + Vector2(0.1, 1.6), Vector2(1.45, 1.75), 16)
		pen.stroke(ring, InkPen.INK, 0.75, true, 1.4)
		pen.stroke(ring, GOLD, 0.38, true, 0.8)
	elif items.has("drop_earrings"):
		pen.line(lobe, lobe + Vector2(0, 2.0), GOLD, 0.25, 0.7)
		var gem := InkPen.smooth_closed(PackedVector2Array([lobe + Vector2(0, 1.8), lobe + Vector2(0.8, 3.0), lobe + Vector2(0, 4.4), lobe + Vector2(-0.8, 3.0)]), 3)
		pen.shape(gem, Color("ff7ab8"), 0.35)
		pen.dot(lobe + Vector2(0.25, 2.8), 0.25, Color.WHITE)
	else:
		pen.dot(lobe + Vector2(0, 0.4), 0.45, Color("fff1c4"), 1.4)


## Sunglasses pushed up into the hair (after the front hair).
static func draw_head_top(pen: InkPen, spec: Dictionary) -> void:
	if not list(spec).has("sunglasses"):
		return
	var frame := Color("1d1a24")
	var lens := Color("3a2f5b")
	for centre: Vector2 in [Vector2(5.0, -10.4), Vector2(-1.4, -11.0)]:
		var shape := InkPen.ellipse(centre, Vector2(2.4, 1.5), 16, -0.12)
		pen.shape(shape, lens, 0.55, frame)
		pen.fill(InkPen.ellipse(centre + Vector2(0.7, -0.4), Vector2(0.8, 0.35), 10, -0.3), Color(1, 1, 1, 0.45))
	pen.line(Vector2(1.0, -10.6), Vector2(2.6, -10.6), frame, 0.5, 1.0)
	pen.line(Vector2(-3.8, -10.8), Vector2(-7.6, -9.0), frame, 0.5, 1.0)


## Choker and pendant (body layer, above the garments).
static func draw_neck(pen: InkPen, spec: Dictionary, model: FigureModel) -> void:
	var items := list(spec)
	if items.has("choker"):
		var band := InkPen.smooth_open(PackedVector2Array([Vector2(-2.6, -98.4), Vector2(0.4, -97.6), Vector2(3.4, -98.2)]), 4)
		pen.stroke(band, InkPen.INK, 1.7, false, 2.0)
		pen.stroke(band, Color("1d1a24"), 1.1, false, 1.2)
		pen.stroke(InkPen.ellipse(Vector2(0.6, -96.4), Vector2(0.65, 0.75), 10), Color("e0e0ee"), 0.25, true, 0.8)
	if items.has("pendant"):
		var near: Array = model.breasts[1]
		var tip := Vector2(model.cleavage_x() + 0.2, (near[0] as Vector2).y - (near[1] as Vector2).y * 0.85)
		var chain := InkPen.smooth_open(PackedVector2Array([Vector2(-2.4, -96.6), tip + Vector2(-0.4, -1.0), tip]), 4)
		chain.append_array(InkPen.smooth_open(PackedVector2Array([tip, tip + Vector2(0.6, -1.0), Vector2(3.4, -96.8)]), 4))
		pen.stroke(chain, GOLD, 0.22, false, 0.7)
		pen.shape(InkPen.ellipse(tip + Vector2(0, 0.7), Vector2(0.65, 0.85), 10), Color("ff4f8b"), 0.3)
		pen.dot(tip + Vector2(0.2, 0.4), 0.2, Color.WHITE)


static func draw_wrist(pen: InkPen, spec: Dictionary, wrist: Vector2, along: Vector2) -> void:
	if not list(spec).has("bracelet"):
		return
	var n := along.orthogonal()
	var c := wrist - along * 0.9
	pen.stroke(PackedVector2Array([c - n * 1.5, c + n * 1.5]), InkPen.INK, 1.3, false, 1.6)
	pen.stroke(PackedVector2Array([c - n * 1.45, c + n * 1.45]), GOLD, 0.7, false, 0.9)
