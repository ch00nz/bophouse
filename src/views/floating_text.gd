class_name FloatingText
extends Node2D
## Short-lived rising text (e.g. "+$12") for idle-game feedback.

var text: String = ""
var color: Color = Color.WHITE
var font_size: int = 16
var lifetime: float = 1.4

var _age: float = 0.0


func _process(delta: float) -> void:
	_age += delta
	position.y -= 26.0 * delta
	modulate.a = 1.0 - pow(_age / lifetime, 2.0)
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	PlaceholderArt.draw_text(self, Vector2(-80, 0), text, font_size, color, 160, HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0.1, 0.05, 0.1, 0.8))
