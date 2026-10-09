class_name OfflinePopup
extends Control
## "Welcome back" modal summarising earnings made while the player was away.

var _away: Label
var _results: Label
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.08, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := UiTheme.label("Welcome back!", 26, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_away = UiTheme.label("", 15, UiTheme.MUTED, true)
	_away.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_away)
	_results = UiTheme.label("", 20, UiTheme.GOOD, true)
	_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_results)
	_note = UiTheme.label("", 12, UiTheme.MUTED, true)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_note)
	var ok := Button.new()
	ok.text = "Nice!"
	ok.custom_minimum_size = Vector2(140, 40)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(hide)
	box.add_child(ok)
	hide()


func show_summary(summary: Dictionary) -> void:
	var config := Game.config
	_away.text = "While you were away for %s, the house kept working:" % Fmt.duration(float(summary.get("raw_seconds", 0.0)))
	_results.text = "%s%s house profit\n+%s followers\n+%s subscribers" % [
		"+" if float(summary.get("cash", 0.0)) >= 0.0 else "", Fmt.money(float(summary.get("cash", 0.0))),
		Fmt.compact(float(summary.get("followers", 0.0))),
		Fmt.compact(maxf(0.0, float(summary.get("subscribers", 0.0))))]
	var lines := PackedStringArray()
	var by_creator: Dictionary = summary.get("by_creator", {})
	for creator_id in by_creator:
		var creator := Game.state.get_creator(str(creator_id))
		if creator != null:
			lines.append("%s: %s gross, %s to the house" % [creator.first_name(),
				Fmt.money(float(by_creator[creator_id]["gross"])), Fmt.money(float(by_creator[creator_id]["house"]))])
	var breakdown := "\n".join(lines) + "\n" if lines.size() > 1 else ""
	var living := float(summary.get("living_costs", 0.0))
	if living > 0.0:
		breakdown += "Living costs: -%s (already taken off)\n" % Fmt.money(living)
	var note := breakdown + "Away earnings run at %d%% efficiency, up to %s." % [
		roundi(config.tuning_f("offline", "efficiency", 0.75) * 100.0),
		Fmt.duration(config.tuning_f("offline", "max_seconds", 28800.0))]
	if bool(summary.get("capped", false)):
		note += " You hit the cap this time."
	_note.text = note
	show()
