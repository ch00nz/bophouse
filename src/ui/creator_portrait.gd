class_name CreatorPortrait
extends Control
## Head-and-shoulders portrait. Uses appearance.portrait texture if present, else placeholder art.

var appearance: Dictionary = {}
var _t: float = 0.0


func _init(creator_appearance: Dictionary = {}) -> void:
	appearance = creator_appearance
	custom_minimum_size = Vector2(96, 112)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	PlaceholderArt.draw_rounded_rect(self, rect, Color("ffd6e8"), 12)
	var tex := ArtLibrary.texture(str(appearance.get("portrait", "")))
	if tex != null:
		draw_texture_rect(tex, rect, false)
		return
	draw_circle(Vector2(size.x * 0.5, size.y * 0.42), size.x * 0.42, Color(1, 1, 1, 0.45))
	PlaceholderArt.draw_creator(self, appearance, "idle", _t, Vector2(size.x * 0.5 - 2, size.y + 110), 1.0, 1.9)
