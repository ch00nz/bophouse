class_name CreatorPreview
extends Control
## Glamorous animated creator preview. Shows one look, or two side by side ("Before" / "After").
## framing: "full" (whole body) or "portrait" (head to hips). Uses CreatorRenderer, so every
## appearance layer (outfit, body shape, hair, makeup, tattoo, piercings) shows exactly as in game.

var framing: String = "full"
var pose: String = "film"
var _specs: Array = []
var _labels: Array = []
var _t: float = 0.0


func _init(preview_framing: String = "full", min_size: Vector2 = Vector2(300, 300)) -> void:
	framing = preview_framing
	custom_minimum_size = min_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_look(spec: Dictionary) -> void:
	_specs = [spec]
	_labels = []
	queue_redraw()


func show_compare(before: Dictionary, after: Dictionary) -> void:
	_specs = [before, after]
	_labels = ["BEFORE", "AFTER"]
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_draw_backdrop(rect)
	if _specs.is_empty():
		return
	if _specs.size() == 1 and framing == "portrait":
		var tex := ArtLibrary.texture(str(_specs[0].get("portrait", "")))
		if tex != null:
			draw_texture_rect(tex, rect, false)
			return
	var count := _specs.size()
	for i in count:
		var spec: Dictionary = _specs[i]
		var column_centre := size.x * (i + 0.5) / count
		var scale := 1.0
		var origin := Vector2.ZERO
		if framing == "portrait":
			scale = size.y / 72.0
			origin = Vector2(column_centre - 2.0 * scale, 6.0 + 120.0 * scale)
		else:
			scale = minf((size.y - 26.0) / 124.0, size.x / count / 62.0)
			origin = Vector2(column_centre - 2.0 * scale, size.y - 10.0)
			PlaceholderArt.draw_ellipse(self, origin, Vector2(20, 4.5) * scale, Color(0, 0, 0, 0.25))
		var anim := pose if fmod(_t + i * 1.3, 8.0) < 6.0 else "idle"
		CreatorRenderer.draw(self, spec, anim, _t + i * 0.9, origin, 1.0, scale)
		if bool(spec.get("recovering", false)) and framing == "full":
			_badge(Vector2(column_centre, size.y - 22.0), "RECOVERING", Color("2ec4b6"))
		if i < _labels.size():
			_badge(Vector2(column_centre, 16.0), str(_labels[i]), UiTheme.GOLD if i == count - 1 else Color(1, 1, 1, 0.8))
	if count == 2:
		draw_line(Vector2(size.x * 0.5, 30), Vector2(size.x * 0.5, size.y - 8), Color(1, 1, 1, 0.15), 1.0)


func _draw_backdrop(rect: Rect2) -> void:
	PlaceholderArt.draw_rounded_rect(self, rect, Color("2b1236"), 14)
	# Vertical glam gradient, spotlight and drifting sparkles.
	var top := Color("4a1a5c")
	var bottom := Color("ff5fa2").darkened(0.35)
	draw_polygon(PackedVector2Array([Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(size.x - 4, size.y - 4), Vector2(4, size.y - 4)]),
		PackedColorArray([top, top, bottom, bottom]))
	PlaceholderArt.draw_ellipse(self, Vector2(size.x * 0.5, size.y * 0.45), Vector2(size.x * 0.42, size.y * 0.5), Color(1, 0.85, 0.95, 0.10))
	PlaceholderArt.draw_ellipse(self, Vector2(size.x * 0.5, size.y * 0.45), Vector2(size.x * 0.25, size.y * 0.38), Color(1, 0.9, 0.97, 0.08))
	for i in 10:
		var x := fmod(i * 73.0 + _t * (6.0 + i), size.x)
		var y := fmod(i * 41.0 + 20.0, size.y)
		var glint := 0.4 + 0.6 * absf(sin(_t * 1.5 + i))
		PlaceholderArt.draw_star(self, Vector2(x, y), 2.0 + glint * 1.5, Color(1, 0.9, 0.6, 0.25 * glint))
	draw_rect(rect.grow(-1.5), Color("ffd166").darkened(0.2), false, 2.0)


func _badge(centre: Vector2, text: String, colour: Color) -> void:
	var width := text.length() * 7.0 + 14.0
	PlaceholderArt.draw_rounded_rect(self, Rect2(centre.x - width * 0.5, centre.y - 9.0, width, 18.0), Color(0.08, 0.03, 0.1, 0.75), 9)
	PlaceholderArt.draw_text(self, Vector2(centre.x - width * 0.5, centre.y + 4.5), text, 11, colour, width, HORIZONTAL_ALIGNMENT_CENTER)
