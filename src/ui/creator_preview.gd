class_name CreatorPreview
extends Control
## Glamorous animated creator showcase. Shows one look, a before/after comparison, or a line-up of
## several creators at their true relative heights. Uses CreatorRenderer, so every appearance layer
## (outfit, body shape, hair, makeup, tattoos, piercings) shows exactly as in the house.
## framing: "full" (whole body), "portrait" (head to hips, small cards) or "closeup" (face and
## styling, for makeup and hair). A caption plate (name, subtitle) can be drawn over the stage, and
## reveal() plays a sparkle burst when a new look is applied.
## Creators with painted art (IllustratedArt, milestone 5B) are shown with their paintings when they
## match her look: a full-body painting with a mood inset, painted expression busts in close-up and
## roster portraits, and a preview-only wardrobe (preview_outfit) that never changes her state.
## set_mood() takes a CreatorMood expression; procedural creators map it onto their faces.

var framing: String = "full"
var pose: String = "film"
var caption_title: String = ""
var caption_subtitle: String = ""
var _specs: Array = []
var _labels: Array = []
var _t: float = 0.0
var _reveal_t: float = -1.0
var _drawn_frame: int = -1
var _mood: String = ""
var _flash_mood: String = ""
var _flash_t: float = 0.0
var _outfit_preview: String = ""
## Paintings (each with its own recolour material) and an overlay above them for badges, the
## caption and the reveal. Overlay drawing is queued during _draw and replayed by the overlay.
var _painted: PaintedLayer
var _overlay: Node2D
var _ops: Array[Callable] = []


func _init(preview_framing: String = "full", min_size: Vector2 = Vector2(300, 300)) -> void:
	framing = preview_framing
	custom_minimum_size = min_size
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Paintings are downscaled a lot; mipmaps keep them smooth.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_painted = PaintedLayer.new()
	add_child(_painted)
	_overlay = Node2D.new()
	_overlay.draw.connect(func() -> void:
		for op in _ops:
			op.call())
	add_child(_overlay)


## Mood expression from CreatorMood (confident, happy, sad, angry, surprised, playful).
func set_mood(mood: String) -> void:
	if mood != _mood:
		_mood = mood
		queue_redraw()


## Shows a mood briefly (e.g. "surprised" when a new look is revealed).
func flash_mood(mood: String, seconds: float = 2.0) -> void:
	_flash_mood = mood
	_flash_t = seconds


## Previews a painted outfit on the single shown creator ("" = her current look). Display only.
func preview_outfit(painted_outfit: String) -> void:
	_outfit_preview = painted_outfit
	queue_redraw()


func previewed_outfit() -> String:
	return _outfit_preview


func current_mood() -> String:
	if _flash_t > 0.0:
		return _flash_mood
	return _mood if not _mood.is_empty() else "confident"


func show_look(spec: Dictionary) -> void:
	_specs = [spec]
	_labels = []
	queue_redraw()


func show_compare(before: Dictionary, after: Dictionary) -> void:
	_specs = [before, after]
	_labels = ["BEFORE", "AFTER"]
	queue_redraw()


## Several creators side by side (true relative heights), labelled with their names.
func show_lineup(specs: Array, names: Array) -> void:
	_specs = specs.duplicate()
	_labels = names.duplicate()
	queue_redraw()


func set_caption(title: String, subtitle: String = "") -> void:
	caption_title = title
	caption_subtitle = subtitle
	queue_redraw()


func set_framing(value: String) -> void:
	framing = value
	queue_redraw()


## Sparkle burst and "NEW LOOK" flourish (after a purchase or procedure).
func reveal() -> void:
	_reveal_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _flash_t > 0.0:
		_flash_t -= delta
	if _reveal_t >= 0.0:
		_reveal_t += delta
		if _reveal_t > 2.2:
			_reveal_t = -1.0
	if not is_visible_in_tree():
		return
	# Animation frame rate: smooth for the hero, gentler for line-ups and small roster cards.
	var fps := 30.0
	if _specs.size() > 2:
		fps = 15.0
	elif size.x < 200.0:
		fps = 10.0
	if _reveal_t >= 0.0:
		fps = 30.0
	var frame := int(_t * fps)
	if frame != _drawn_frame:
		_drawn_frame = frame
		queue_redraw()


func _draw() -> void:
	_ops.clear()
	_painted.begin()
	_draw_stage()
	_painted.end()
	_overlay.queue_redraw()


func _draw_stage() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	_draw_backdrop(rect)
	_ops.append(func() -> void: _overlay.draw_rect(rect.grow(-1.5), Color("ffd166").darkened(0.2), false, 2.0))
	if _specs.is_empty():
		return
	if _specs.size() == 1 and framing == "portrait":
		var tex := ArtLibrary.texture(str(_specs[0].get("portrait", "")))
		if tex != null:
			draw_texture_rect(tex, rect, false)
			return
	var count := _specs.size()
	var lineup := count > 2
	var caption_space := 46.0 if not caption_title.is_empty() and count == 1 else 0.0
	# A before/after comparison uses the paintings only when they can show the change (e.g. a hair
	# colour); otherwise both sides use the classic renderer so the difference is visible.
	var compare_painted := count == 2 and IllustratedArt.use_art(_specs[0]) and IllustratedArt.use_art(_specs[1]) \
		and str((_specs[0] as Dictionary).get("art_cover", {}).get("missing", [])) == str((_specs[1] as Dictionary).get("art_cover", {}).get("missing", []))
	if count == 2 and not compare_painted and IllustratedArt.use_art(_specs[0]):
		_badge(Vector2(size.x * 0.5, size.y - 14.0), "CLASSIC PREVIEW: not painted yet", Color("ffb3c1"))
	# Paintings are wider than procedural figures (hair, poses): shrink the whole stage uniformly so
	# every painted figure fits its column and relative heights stay true.
	var width_limit := INF
	if framing == "full":
		for spec: Dictionary in _specs:
			if IllustratedArt.use_art(spec) and (count != 2 or compare_painted):
				var art := IllustratedArt.full_body(spec)
				if not art.is_empty():
					var units := float((art["texture"] as Texture2D).get_width()) * float(art["units_per_px"]) * float(spec.get("height_scale", 1.0))
					width_limit = minf(width_limit, size.x / count * 0.98 / maxf(units, 1.0))
	for i in count:
		var spec: Dictionary = _specs[i]
		var column_centre := size.x * (i + 0.5) / count
		var column := Rect2(size.x * i / count, 0.0, size.x / count, size.y)
		var painted := IllustratedArt.use_art(spec) and (count != 2 or compare_painted)
		if count == 1 and not _outfit_preview.is_empty() and IllustratedArt.has_art(spec) and IllustratedArt.mode != "off":
			painted = true # the wardrobe preview always shows the painting
		var scale := 1.0
		var origin := Vector2.ZERO
		var anim := pose
		if framing == "portrait" or framing == "closeup":
			if painted and _draw_painted_bust(spec, column.grow_side(SIDE_BOTTOM, -caption_space * 0.5)):
				_column_badges(i, count, lineup, column_centre, caption_space, spec)
				continue
			# Head-and-shoulders framing ignores height so faces line up between creators.
			spec = spec.duplicate()
			spec["height_scale"] = 1.0
			if not _mood.is_empty() or _flash_t > 0.0:
				spec["expression"] = CreatorMood.procedural(current_mood(), str(spec.get("expression", "smile")))
			var span := 72.0 if framing == "portrait" else 62.0
			scale = size.y / span
			if framing == "closeup":
				scale = minf(scale, size.x / count / 34.0)
			origin = Vector2(column_centre - 3.0 * scale, 4.0 + 133.0 * scale)
			if framing == "closeup" and anim == "showcase":
				anim = "idle"
		else:
			# Room for the tallest bodies and hair (height scale up to ~1.1), so real height differences show.
			scale = minf(minf((size.y - 24.0 - caption_space * 0.6 - (18.0 if lineup else 0.0)) / 140.0, size.x / count / 46.0), width_limit)
			origin = Vector2(column_centre - 2.0 * scale, size.y - 12.0 - caption_space * 0.6 - (18.0 if lineup else 0.0))
			PlaceholderArt.draw_ellipse(self, origin, Vector2(19, 4.0) * scale, Color(0, 0, 0, 0.28))
			if painted:
				var art := IllustratedArt.full_body(spec, _outfit_preview if count == 1 else "")
				if not art.is_empty():
					var hop := absf(sin(_t * 7.0)) * 3.0 * scale if _reveal_t >= 0.0 and _reveal_t < 1.4 and i == count - 1 else 0.0
					_painted.add_figure(art, IllustratedArt.material_for(spec, art), origin - Vector2(0, hop), scale * float(spec.get("height_scale", 1.0)), false, sin(_t * 2.0 + i) * 0.004)
					if count == 1:
						_draw_mood_inset(spec)
						_draw_art_notes(spec)
					_column_badges(i, count, lineup, column_centre, caption_space, spec)
					continue
		if pose == "film" and fmod(_t + i * 1.3, 9.0) >= 7.0:
			anim = "idle"
		if _reveal_t >= 0.0 and _reveal_t < 1.4 and (i == count - 1) and not lineup:
			anim = "celebrate"
		CreatorRenderer.draw(self, spec, anim, _t + i * 0.9, origin, 1.0, scale)
		_column_badges(i, count, lineup, column_centre, caption_space, spec)
	if count == 2:
		draw_line(Vector2(size.x * 0.5, 30), Vector2(size.x * 0.5, size.y - 8), Color(1, 1, 1, 0.15), 1.0)
	if caption_space > 0.0:
		_ops.append(_draw_caption)
	if _reveal_t >= 0.0:
		_ops.append(_draw_reveal.bind(Vector2(size.x * (count - 0.5) / count, size.y * 0.42)))


func _column_badges(i: int, count: int, lineup: bool, column_centre: float, caption_space: float, spec: Dictionary) -> void:
	if bool(spec.get("recovering", false)) and framing == "full":
		_badge(Vector2(column_centre, size.y - 22.0 - caption_space), "RECOVERING", Color("2ec4b6"))
	if i < _labels.size():
		if lineup:
			_badge(Vector2(column_centre, size.y - 14.0), str(_labels[i]), Color(1, 1, 1, 0.9))
		else:
			_badge(Vector2(column_centre, 16.0), str(_labels[i]), UiTheme.GOLD if i == count - 1 else Color(1, 1, 1, 0.8))


## Painted expression bust: the whole bust in close-up, the face only in small portraits.
func _draw_painted_bust(spec: Dictionary, area: Rect2) -> bool:
	# Expression busts are painted in the casual top; for other painted outfits the close-up crops the
	# outfit painting instead (correct clothes) and shows her mood in the inset.
	if framing == "closeup" and IllustratedArt.outfit(spec, _outfit_preview) != "casual":
		var art := IllustratedArt.full_body(spec, _outfit_preview)
		if not art.is_empty():
			var full: Texture2D = art["texture"]
			var region := Rect2(0.0, 0.0, full.get_width(), full.get_height() * 0.42)
			var k := minf(area.size.x / region.size.x, area.size.y * 0.97 / region.size.y)
			var dest := Rect2(Vector2(area.position.x + (area.size.x - region.size.x * k) * 0.5, area.end.y - region.size.y * k), region.size * k)
			_painted.add_region(full, IllustratedArt.material_for(spec, art), dest, region)
			_draw_mood_inset(spec)
			if not _outfit_preview.is_empty():
				_badge(Vector2(size.x * 0.5, 48.0), "WARDROBE PREVIEW", UiTheme.GOLD)
			return true
	var bust := IllustratedArt.bust(spec, current_mood())
	if bust.is_empty():
		return false
	var texture: Texture2D = bust["texture"]
	var paint := IllustratedArt.material_for(spec, bust)
	var tex_size := texture.get_size()
	if framing == "portrait":
		var face := IllustratedArt.face(spec)
		var r := float(face["radius"]) * tex_size.x
		var centre: Vector2 = (face["centre"] as Vector2) * tex_size
		# Crop around the face, matching the card's aspect ratio.
		var aspect := area.size.x / maxf(area.size.y, 1.0)
		var half := Vector2(r * 1.2 * aspect, r * 1.2)
		_painted.add_region(texture, paint, area, Rect2(centre - half + Vector2(0, r * 0.3), half * 2.0))
		return true
	var fit := minf(area.size.x / tex_size.x, area.size.y * 0.97 / tex_size.y)
	var draw_size := tex_size * fit
	var pos := Vector2(area.position.x + (area.size.x - draw_size.x) * 0.5, area.end.y - draw_size.y)
	_painted.add_region(texture, paint, Rect2(pos, draw_size), Rect2(Vector2.ZERO, tex_size))
	var badge_y := area.position.y + 48.0 if area.size.x >= 200.0 else area.end.y - 12.0
	_badge(Vector2(area.position.x + area.size.x * 0.5, badge_y), current_mood().to_upper(), UiTheme.GOLD)
	return true


## Small framed face showing her current mood over the full-body painting.
func _draw_mood_inset(spec: Dictionary) -> void:
	var bust := IllustratedArt.bust(spec, current_mood())
	if bust.is_empty() or size.x < 200.0:
		return
	var texture: Texture2D = bust["texture"]
	var tex_size := texture.get_size()
	var face := IllustratedArt.face(spec)
	var r := float(face["radius"]) * tex_size.x
	var centre: Vector2 = (face["centre"] as Vector2) * tex_size
	var box := Rect2(size.x - 84.0, 40.0, 72.0, 72.0)
	PlaceholderArt.draw_rounded_rect(self, box.grow(3.0), Color("2b1236"), 12, UiTheme.GOLD, 2)
	_painted.add_region(texture, IllustratedArt.material_for(spec, bust), box, Rect2(centre - Vector2(r, r) + Vector2(0, r * 0.25), Vector2(r, r) * 2.0))
	_badge(Vector2(box.get_center().x, box.end.y + 12.0), current_mood().to_upper(), UiTheme.GOLD)


## Honest labels when the painting isn't exactly her current look.
func _draw_art_notes(spec: Dictionary) -> void:
	var cover: Dictionary = spec.get("art_cover", {})
	if not _outfit_preview.is_empty():
		_badge(Vector2(size.x * 0.5, 48.0 if size.x >= 200.0 else 14.0), "WARDROBE PREVIEW" if size.x >= 200.0 else "PREVIEW", UiTheme.GOLD)
	if bool(cover.get("ok", false)):
		return
	var shown: Array[String] = []
	for reason: Variant in cover.get("missing", []):
		# While previewing a painted outfit, her current (unpainted) outfit isn't relevant.
		if not _outfit_preview.is_empty() and str(reason) == str(cover.get("missing_outfit", "")):
			continue
		shown.append(str(reason).to_lower())
	if shown.is_empty():
		return
	var y := size.y - 66.0 - (46.0 if not caption_title.is_empty() else 0.0)
	_badge(Vector2(size.x * 0.5, y), "Not painted yet: " + ", ".join(PackedStringArray(shown)), Color("ffb3c1"))


func _draw_backdrop(rect: Rect2) -> void:
	PlaceholderArt.draw_rounded_rect(self, rect, Color("2b1236"), 14)
	# Studio: vertical glam gradient, a soft key light behind her, a glossy floor and drifting sparkles.
	var top := Color("3d1350")
	var bottom := Color("ff5fa2").darkened(0.4)
	draw_polygon(PackedVector2Array([Vector2(3, 3), Vector2(size.x - 3, 3), Vector2(size.x - 3, size.y - 3), Vector2(3, size.y - 3)]),
		PackedColorArray([top, top, bottom, bottom]))
	var floor_y := size.y * 0.86 if framing == "full" else size.y + 10.0
	if framing == "full":
		draw_polygon(PackedVector2Array([Vector2(3, floor_y), Vector2(size.x - 3, floor_y), Vector2(size.x - 3, size.y - 3), Vector2(3, size.y - 3)]),
			PackedColorArray([Color(0.2, 0.05, 0.22, 0.0), Color(0.2, 0.05, 0.22, 0.0), Color(0.12, 0.02, 0.14, 0.55), Color(0.12, 0.02, 0.14, 0.55)]))
	for k in 4:
		var r := 1.0 - k * 0.2
		PlaceholderArt.draw_ellipse(self, Vector2(size.x * 0.5, size.y * 0.42), Vector2(size.x * 0.48 * r, size.y * 0.52 * r), Color(1, 0.82, 0.95, 0.045))
	# Light beams from above.
	for side: float in [-1.0, 1.0]:
		var x := size.x * 0.5 + side * size.x * 0.32
		var b0 := size.x * 0.5 + side * size.x * 0.12
		var b1 := size.x * 0.5 - side * size.x * 0.02
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 0), Vector2(x + 6, 0), Vector2(maxf(b0, b1), size.y), Vector2(minf(b0, b1), size.y)]),
			Color(1, 0.9, 0.98, 0.035))
	for i in 12:
		var x := fmod(i * 73.0 + _t * (6.0 + i), size.x)
		var y := fmod(i * 41.0 + 20.0, size.y)
		var glint := 0.4 + 0.6 * absf(sin(_t * 1.5 + i))
		PlaceholderArt.draw_star(self, Vector2(x, y), 2.0 + glint * 1.5, Color(1, 0.9, 0.6, 0.25 * glint))


func _draw_caption() -> void:
	var plate := Rect2(8, size.y - 52, size.x - 16, 44)
	_overlay.draw_polygon(PackedVector2Array([plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]),
		PackedColorArray([Color(0.06, 0.02, 0.08, 0.35), Color(0.06, 0.02, 0.08, 0.1), Color(0.06, 0.02, 0.08, 0.1), Color(0.06, 0.02, 0.08, 0.75)]))
	PlaceholderArt.draw_text(_overlay, Vector2(18, size.y - 28), caption_title, 22, Color.WHITE, -1, HORIZONTAL_ALIGNMENT_LEFT, 4, Color(0.1, 0.02, 0.1, 0.8))
	if not caption_subtitle.is_empty():
		PlaceholderArt.draw_text(_overlay, Vector2(19, size.y - 11), caption_subtitle, 13, UiTheme.GOLD, size.x - 30, HORIZONTAL_ALIGNMENT_LEFT, 3, Color(0.1, 0.02, 0.1, 0.8))


func _draw_reveal(centre: Vector2) -> void:
	var u := _reveal_t / 2.2
	var flash := clampf(1.0 - _reveal_t / 0.35, 0.0, 1.0)
	if flash > 0.0:
		_overlay.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.95, 1, 0.45 * flash))
	for i in 18:
		var a := TAU * i / 18.0 + u * 1.5
		var d := (40.0 + 160.0 * u) * (0.7 + 0.3 * sin(i * 2.1))
		var alpha := clampf(1.0 - u, 0.0, 1.0)
		var p := centre + Vector2(cos(a), sin(a) * 1.2) * d
		if i % 3 == 0:
			PlaceholderArt.draw_heart(_overlay, p, 12.0, Color(1, 0.4, 0.7, alpha))
		else:
			PlaceholderArt.draw_star(_overlay, p, 5.0 + 3.0 * sin(i + _reveal_t * 6.0), Color(1, 0.9, 0.5, alpha))
	if _reveal_t < 1.9:
		var pop := minf(_reveal_t / 0.25, 1.0)
		var w := 150.0 * pop
		PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre.x - w * 0.5, 30, w, 30), Color("ff4f8b"), 15, Color.WHITE, 2)
		if pop >= 1.0:
			PlaceholderArt.draw_text(_overlay, Vector2(centre.x - 75, 51), "NEW LOOK!", 18, Color.WHITE, 150, HORIZONTAL_ALIGNMENT_CENTER)


func _badge(centre: Vector2, text: String, colour: Color) -> void:
	_ops.append(_badge_now.bind(centre, text, colour))


func _badge_now(centre: Vector2, text: String, colour: Color) -> void:
	var width := text.length() * 7.0 + 14.0
	PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre.x - width * 0.5, centre.y - 9.0, width, 18.0), Color(0.08, 0.03, 0.1, 0.75), 9)
	PlaceholderArt.draw_text(_overlay, Vector2(centre.x - width * 0.5, centre.y + 4.5), text, 11, colour, width, HORIZONTAL_ALIGNMENT_CENTER)
