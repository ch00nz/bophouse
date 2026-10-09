class_name PhotoshootPopup
extends Control
## Optional bonus photoshoot mini-game: snap when the marker crosses the sweet spot. A few shots
## give bonus income and followers via Photoshoot.complete(). Never required: automated
## production keeps running for idle players. The game is paused while this is open.

var creator_id: String = ""

var _preview: CreatorPreview
var _meter: Control
var _status: Label
var _snap: Button
var _close: Button
var _shots: Array[float] = []
var _target: float = 0.5
var _phase: float = 0.0
var _speed: float = 2.2
var _flash: float = 0.0
var _done: bool = false
var _was_paused: bool = false
var _rng := RandomNumberGenerator.new()


func _init(id: String) -> void:
	creator_id = id


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_was_paused = Game.paused
	Game.set_paused(true)
	_rng.randomize()

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.6)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var creator := Game.state.get_creator(creator_id)
	var title := UiTheme.label("Bonus photoshoot with %s" % ContentRules.first_name(creator), 22, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiTheme.label("Snap when the marker is in the gold zone. %d shots. This is an optional bonus; she keeps earning without it." % _shot_count(), 12, UiTheme.MUTED, true))

	_preview = CreatorPreview.new("full", Vector2(0, 230))
	_preview.show_look(Appearance.render_spec(creator, Game.config))
	box.add_child(_preview)

	_meter = Control.new()
	_meter.custom_minimum_size = Vector2(0, 30)
	_meter.draw.connect(_draw_meter)
	box.add_child(_meter)

	_status = UiTheme.label("", 16, UiTheme.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_snap = Button.new()
	_snap.text = "SNAP!"
	_snap.custom_minimum_size = Vector2(0, 44)
	_snap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_snap.add_theme_font_size_override("font_size", 20)
	_snap.pressed.connect(_on_snap)
	buttons.add_child(_snap)
	_close = Button.new()
	_close.text = "Skip"
	_close.custom_minimum_size = Vector2(90, 44)
	_close.add_theme_stylebox_override("normal", UiTheme.box(UiTheme.PANEL_LIGHT, 10, 6))
	_close.pressed.connect(_on_close)
	buttons.add_child(_close)
	box.add_child(buttons)
	_new_target()
	_update_status("Shot 1 of %d" % _shot_count())


func _process(delta: float) -> void:
	if not _done:
		_phase += delta * _speed
	_flash = maxf(0.0, _flash - delta * 2.5)
	_meter.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _done:
		_on_snap()
		get_viewport().set_input_as_handled()


func _marker() -> float:
	return 0.5 + 0.5 * sin(_phase)


func _draw_meter() -> void:
	var w := _meter.size.x
	var h := _meter.size.y
	PlaceholderArt.draw_rounded_rect(_meter, Rect2(0, 4, w, h - 8), Color(0, 0, 0, 0.4), 8)
	var zone := 0.25 * 0.5
	_meter.draw_rect(Rect2((_target - zone) * w, 6, zone * 2.0 * w, h - 12), Color(1, 0.82, 0.4, 0.45))
	_meter.draw_rect(Rect2((_target - zone * 0.3) * w, 6, zone * 0.6 * w, h - 12), Color(1, 0.82, 0.4, 0.9))
	var x := _marker() * w
	_meter.draw_rect(Rect2(x - 2, 0, 4, h), Color.WHITE)
	if _flash > 0.0:
		_meter.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, _flash * 0.5))


func _on_snap() -> void:
	if _done:
		return
	var quality := Photoshoot.shot_quality(_marker(), _target, 0.25)
	_shots.append(quality)
	_flash = 1.0
	var verdict := "Perfect!" if quality > 0.85 else ("Great shot!" if quality > 0.6 else ("Nice." if quality > 0.3 else "Missed it..."))
	if _shots.size() >= _shot_count():
		_finish(verdict)
		return
	_speed *= 1.15
	_new_target()
	_update_status("%s  Shot %d of %d" % [verdict, _shots.size() + 1, _shot_count()])


func _finish(verdict: String) -> void:
	_done = true
	var score := 0.0
	for q in _shots:
		score += q
	score /= maxf(float(_shots.size()), 1.0)
	var result := Game.complete_photoshoot(creator_id, score)
	if bool(result.get("ok", false)):
		_update_status("%s  Shoot quality %d%%: +%s to the house (of %s), +%s followers" % [verdict, roundi(score * 100.0),
			Fmt.money(float(result["cash"])), Fmt.money(float(result["gross"])), Fmt.compact(float(result["followers"]))])
	else:
		_update_status(str(result.get("reason", "")))
	_snap.disabled = true
	_close.text = "Done"


func _new_target() -> void:
	_target = _rng.randf_range(0.2, 0.8)


func _update_status(text: String) -> void:
	_status.text = text


func _shot_count() -> int:
	return int(Game.config.tuning("photoshoot", "shots", 3))


func _on_close() -> void:
	Game.set_paused(_was_paused)
	queue_free()
