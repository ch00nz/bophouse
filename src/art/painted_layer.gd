class_name PaintedLayer
extends Node2D
## Draws painted character images, each with its own recolour material (hair colour masks, see
## IllustratedArt.material_for). A CanvasItem can only carry one material, so every painting is a
## pooled child node instead of a draw call on the owner. Usage, once per redraw of the owner:
##   layer.begin()
##   layer.add_figure(art, material, origin, scale, mirror, breath)   # feet-anchored figure
##   layer.add_region(texture, material, dest_rect, src_rect)          # crops (busts, faces)
##   layer.end()                                                       # hides unused items

var _items: Array[PaintedItem] = []
var _used: int = 0


class PaintedItem extends Node2D:
	var texture: Texture2D
	var anchor: Vector2 = Vector2.ZERO
	var dest: Rect2 = Rect2()
	var src: Rect2 = Rect2()

	func _draw() -> void:
		if texture == null:
			return
		if dest.size != Vector2.ZERO:
			draw_texture_rect_region(texture, dest, src)
		else:
			draw_texture(texture, -anchor)


func begin() -> void:
	_used = 0


func end() -> void:
	for i in range(_used, _items.size()):
		_items[i].visible = false


## A whole painted figure with its feet anchor at `origin`; `scale` is model units -> pixels.
func add_figure(art: Dictionary, material: Material, origin: Vector2, scale: float, mirror: bool = false, breath: float = 0.0) -> void:
	var item := _next(material)
	var s := scale * float(art["units_per_px"])
	item.position = origin
	item.scale = Vector2(-s if mirror else s, s * (1.0 + breath))
	item.texture = art["texture"]
	item.anchor = art["anchor"]
	item.dest = Rect2()
	item.queue_redraw()


## Part of a painting (`src`, texture pixels) drawn into `dest` (layer coordinates).
func add_region(texture: Texture2D, material: Material, dest: Rect2, src: Rect2) -> void:
	var item := _next(material)
	item.position = Vector2.ZERO
	item.scale = Vector2.ONE
	item.texture = texture
	item.dest = dest
	item.src = src
	item.queue_redraw()


func _next(material: Material) -> PaintedItem:
	if _used >= _items.size():
		var item := PaintedItem.new()
		item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(item)
		_items.append(item)
	var item := _items[_used]
	_used += 1
	item.visible = true
	item.material = material
	return item
