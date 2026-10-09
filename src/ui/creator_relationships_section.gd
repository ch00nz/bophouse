class_name CreatorRelationshipsSection
extends VBoxContainer
## Relationships tab (basic): friendship, trust and rivalry with each housemate, plus her recent
## social moments. Deeper relationship consequences arrive in later milestones.

var creator_id: String = ""

var _rows: Dictionary = {} # other id -> {friendship, trust, rivalry, summary}
var _log: Label


func _init(id: String) -> void:
	creator_id = id
	add_theme_constant_override("separation", 8)


func _ready() -> void:
	var creator := Game.state.get_creator(creator_id)
	add_child(UiTheme.label("Housemates build friendships (and rivalries) while hanging out in shared rooms. Drama-prone personalities clash more often.", 12, UiTheme.MUTED, true))
	var any := false
	for other in Game.state.creators:
		if other == creator:
			continue
		any = true
		var card := UiTheme.card()
		var c: VBoxContainer = card.get_child(0)
		var head := HBoxContainer.new()
		var portrait := CreatorPreview.new("portrait", Vector2(44, 48))
		portrait.pose = "idle"
		portrait.show_look(Appearance.render_spec(other, Game.config))
		head.add_child(portrait)
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_child(UiTheme.label(other.display_name, 15))
		var summary := UiTheme.label("", 12, UiTheme.GOLD)
		names.add_child(summary)
		head.add_child(names)
		c.add_child(head)
		var refs := {"summary": summary}
		for entry: Array in [["friendship", "Friendship", Color("7ae582")], ["trust", "Trust", Color("4cc9f0")], ["rivalry", "Rivalry", Color("ff6b6b")]]:
			var row := HBoxContainer.new()
			var caption := UiTheme.label(str(entry[1]), 12, UiTheme.MUTED)
			caption.custom_minimum_size = Vector2(80, 0)
			row.add_child(caption)
			var bar := UiTheme.bar(0, entry[2], 10)
			row.add_child(bar)
			c.add_child(row)
			refs[entry[0]] = bar
		_rows[other.id] = refs
		add_child(card)
	if not any:
		add_child(UiTheme.label("No housemates yet. Invite creators from Applications to see relationships form.", 13, UiTheme.TEXT, true))
	add_child(UiTheme.header("Recent moments"))
	_log = UiTheme.label("", 12, UiTheme.TEXT, true)
	add_child(_log)
	add_child(UiTheme.label("Romance, jealousy and bigger storylines come in a later milestone.", 11, UiTheme.MUTED, true))
	refresh()


func refresh() -> void:
	var state := Game.state
	var creator := state.get_creator(creator_id)
	if creator == null or _log == null:
		return
	for other_id: String in _rows:
		var other := state.get_creator(other_id)
		if other == null:
			continue
		var rel := Relationships.get_pair(state, Game.config, creator, other)
		var refs: Dictionary = _rows[other_id]
		for value_id in Relationships.VALUES:
			(refs[value_id] as ProgressBar).value = float(rel[value_id])
		(refs["summary"] as Label).text = Relationships.describe(rel)
	var lines := PackedStringArray()
	for i in range(state.social_log.size() - 1, -1, -1):
		var entry: Dictionary = state.social_log[i]
		if str(entry.get("a", "")) == creator_id or str(entry.get("b", "")) == creator_id:
			var minute := float(entry.get("minute", 0.0))
			lines.append("Day %d %02d:%02d  %s" % [int(minute / GameState.MINUTES_PER_DAY) + 1,
				int(fmod(minute, GameState.MINUTES_PER_DAY) / 60.0), int(fmod(minute, 60.0)), str(entry.get("text", ""))])
			if lines.size() >= 8:
				break
	_log.text = "\n".join(lines) if not lines.is_empty() else "Nothing yet."
