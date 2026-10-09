class_name CreatorStatsSection
extends VBoxContainer
## Stats & Measurements tab: core stats, body measurements (metric or imperial), body type tags
## derived from them, and a short note on how her body affects audiences.

var creator_id: String = ""

var _measure_card: VBoxContainer
var _signature: String = ""


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
	add_child(UiTheme.header("Body measurements"))
	var units := HBoxContainer.new()
	units.add_theme_constant_override("separation", 4)
	for entry: Array in [["Metric (cm)", false], ["Imperial (in)", true]]:
		var button := UiTheme.tab_button(str(entry[0]))
		button.set_pressed_no_signal(Game.imperial_units() == bool(entry[1]))
		var imperial: bool = entry[1]
		button.pressed.connect(func() -> void:
			Game.set_imperial_units(imperial)
			for child in units.get_children():
				(child as Button).set_pressed_no_signal((child as Button).text.begins_with("Imperial") == imperial)
			_rebuild_measurements())
		units.add_child(button)
	add_child(units)
	var card := UiTheme.card()
	_measure_card = card.get_child(0)
	add_child(card)
	_rebuild_measurements()

	add_child(HSeparator.new())
	add_child(UiTheme.header("Stats"))
	add_child(CreatorProfileSection.stat_grid(creator))
	add_child(UiTheme.label("Stats are personality and skill. Body measurements are separate and only change through her own procedure decisions.", 11, UiTheme.MUTED, true))


func refresh() -> void:
	var creator := Game.state.get_creator(creator_id)
	if creator == null or _measure_card == null:
		return
	var signature := creator.measurements.summary() + str(Game.imperial_units()) + JSON.stringify(creator.appearance_tags)
	if signature != _signature:
		_rebuild_measurements()


func _rebuild_measurements() -> void:
	var creator := Game.state.get_creator(creator_id)
	var config := Game.config
	var imperial := Game.imperial_units()
	_signature = creator.measurements.summary() + str(imperial) + JSON.stringify(creator.appearance_tags)
	for child in _measure_card.get_children():
		_measure_card.remove_child(child)
		child.queue_free()
	var m := creator.measurements
	var headline := UiTheme.label("%s  -  %s  -  %s" % [creator.first_name(), m.height_text(imperial), m.bwh_text(imperial)], 17, UiTheme.GOLD)
	_measure_card.add_child(UiTheme.tip(headline, "Height, then bust / waist / hips."))
	_measure_card.add_child(UiTheme.row("Height", UiTheme.value_label(m.height_text(imperial))))
	_measure_card.add_child(UiTheme.row("Bust", UiTheme.value_label(_len(m.bust_cm, imperial))))
	_measure_card.add_child(UiTheme.row("Waist", UiTheme.value_label(_len(m.waist_cm, imperial))))
	_measure_card.add_child(UiTheme.row("Hips", UiTheme.value_label(_len(m.hips_cm, imperial))))
	_measure_card.add_child(UiTheme.tip(UiTheme.row("Muscle tone", UiTheme.value_label("%d%%" % roundi(m.tone * 100.0))),
		"Athletic definition. Toned bodies read as athletic to fitness audiences."))
	var metrics := m.metrics()
	_measure_card.add_child(UiTheme.tip(UiTheme.row("Waist-to-hip ratio", UiTheme.value_label("%.2f" % float(metrics["whr"]))),
		"Lower = a more pronounced hourglass."))
	var changed := PackedStringArray()
	for entry: Dictionary in creator.procedure_history:
		var item := config.look_item(str(entry.get("item_id", "")))
		if item.has("measurements"):
			var parts := PackedStringArray()
			for key in item["measurements"]:
				parts.append("%s %+d cm" % [str(key).replace("_cm", ""), roundi(float(item["measurements"][key]))])
			var when := "before joining" if bool(entry.get("before_joining", false)) else "day %d" % int(entry.get("day", 1))
			changed.append("%s (%s): %s" % [Appearance.item_label(config, item), when, ", ".join(parts)])
	if not changed.is_empty():
		_measure_card.add_child(UiTheme.label("Changes: " + "; ".join(changed), 11, UiTheme.MUTED, true))

	_measure_card.add_child(HSeparator.new())
	_measure_card.add_child(UiTheme.header("Body type"))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	var any := false
	for tag_id in config.appearance.get("body_tags", []):
		var strength := creator.tag(str(tag_id))
		if strength < 0.1:
			continue
		any = true
		var colour := PlaceholderArt.color(config.tag_defs.get(tag_id, {}).get("color"), UiTheme.TEXT)
		flow.add_child(UiTheme.chip("%s %d%%" % [config.tag_label(str(tag_id)), roundi(strength * 100.0)], colour,
			"Derived from her measurements. Some audiences love this, others prefer different bodies."))
	if not any:
		flow.add_child(UiTheme.chip("Balanced proportions", UiTheme.MUTED, "No strong body-type tag: broadly neutral appeal."))
	_measure_card.add_child(flow)
	_measure_card.add_child(UiTheme.label(_audience_note(creator), 11, UiTheme.MUTED, true))


## Which audiences her body type helps or hurts most.
func _audience_note(creator: CreatorState) -> String:
	var config := Game.config
	var neutral := creator.clone()
	neutral.measurements = null
	Appearance.refresh(neutral, config)
	var rows: Array = []
	for segment: Dictionary in config.segments:
		var delta := AudienceModel.segment_appeal(segment, creator.appearance_tags, config) - AudienceModel.segment_appeal(segment, neutral.appearance_tags, config)
		if absf(delta) >= 0.05:
			rows.append([str(segment.get("name", "")), delta])
	if rows.is_empty():
		return "Her body type doesn't sway any audience much either way."
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var likes := PackedStringArray()
	var dislikes := PackedStringArray()
	for row: Array in rows:
		if float(row[1]) > 0.0:
			likes.append(str(row[0]))
		else:
			dislikes.append(str(row[0]))
	var text := ""
	if not likes.is_empty():
		text += "Her figure especially appeals to: " + ", ".join(likes.slice(0, 3)) + ". "
	if not dislikes.is_empty():
		text += "Less popular with: " + ", ".join(dislikes.slice(0, 3)) + "."
	return text


static func _len(cm: float, imperial: bool) -> String:
	return "%.1f in" % BodyMeasurements.cm_to_inches(cm) if imperial else "%d cm" % roundi(cm)
