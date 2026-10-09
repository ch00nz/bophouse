extends Node
## Autoload "Game". Owns config + state, drives the real-time clock, autosaves and applies
## offline progress. The only bridge between pure simulation code and the scene tree:
## views read Game.state and listen to signals; they never mutate state directly.

signal ticked
signal state_replaced
signal room_upgraded(room_id: String)
signal offline_progress_applied(summary: Dictionary)
signal saved
signal speed_changed(speed: int, paused: bool)
signal content_focus_changed(creator_id: String, content_id: String)
signal content_unlocked(content_id: String)
signal trends_changed(started_ids: Array)
signal appearance_changed(creator_id: String, item_id: String)
signal recovery_finished(creator_id: String)
signal photoshoot_completed(creator_id: String, result: Dictionary)
signal creator_joined(creator_id: String)
signal room_built(room_id: String)
signal bedroom_changed(creator_id: String)
signal social_interaction(event: Dictionary)
signal settings_changed
signal upgrade_purchased(upgrade_id: String)

var config: GameConfig
var state: GameState
var speed: int = 1
var paused: bool = false
## Offline summary computed at startup, shown once the UI is ready.
var pending_offline_summary: Dictionary = {}
var save_path: String = "user://savegame.json"

var _autosave_elapsed: float = 0.0
var _last_frame_unix: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	config = GameConfig.load_from_dir()
	save_path = str(config.tuning("save", "path", save_path))
	# Test runners and visual tools (godot --script ...) must never load or overwrite the player's save.
	if OS.get_cmdline_args().has("--script"):
		save_path = "user://tool_savegame.json"
	get_tree().set_auto_accept_quit(false)
	_load_or_create()


func _load_or_create() -> void:
	var now := now_unix()
	var loaded := SaveSystem.read(save_path)
	if loaded != null and SaveSystem.is_compatible(loaded, config):
		state = loaded
		SaveSystem.post_load(state, config)
		var summary := OfflineProgress.apply(state, config, now)
		if float(summary["real_seconds"]) >= config.tuning_f("offline", "min_seconds_for_popup", 30.0):
			pending_offline_summary = summary
	else:
		state = GameState.new_game(config)
		state.last_seen_unix = now
	_last_frame_unix = now
	IllustratedArt.mode = art_mode()
	save_game()


func _process(delta: float) -> void:
	if state == null:
		return
	var now := now_unix()
	_check_frame_gap(now)
	_last_frame_unix = now
	if not paused:
		var minutes := TimeControl.frame_minutes(delta, speed, paused, config)
		var totals := Simulation.advance(state, config, minutes, config.tuning_f("time", "max_sim_step_minutes", 1.0))
		if totals.has("trends_started"):
			trends_changed.emit(totals["trends_started"])
		for creator_id in totals.get("recovered", []):
			recovery_finished.emit(str(creator_id))
		for event: Dictionary in totals.get("social", []):
			social_interaction.emit(event)
		ticked.emit()
	_autosave_elapsed += delta
	if _autosave_elapsed >= config.tuning_f("save", "autosave_seconds", 15.0):
		save_game()


## Browsers stop running hidden tabs and laptops sleep; treat a long frame gap as offline time
## instead of either losing it or fast-forwarding it at full efficiency.
func _check_frame_gap(now: float) -> void:
	if _last_frame_unix <= 0.0 or now - _last_frame_unix < config.tuning_f("time", "frame_gap_offline_seconds", 5.0):
		return
	state.last_seen_unix = maxf(state.last_seen_unix, _last_frame_unix)
	var summary := OfflineProgress.apply(state, config, now)
	if float(summary["real_seconds"]) >= config.tuning_f("offline", "min_seconds_for_popup", 30.0):
		offline_progress_applied.emit(summary)
	trends_changed.emit([])
	save_game()


func save_game() -> void:
	_autosave_elapsed = 0.0
	var now := now_unix()
	state.last_seen_unix = maxf(state.last_seen_unix, now)
	if SaveSystem.write(save_path, state, now) == OK:
		saved.emit()
	else:
		push_warning("Game: failed to save to %s" % save_path)


## Accepts a creator's application to move in. Returns Applications.check() (plus "creator" on success).
func accept_application(template_id: String) -> Dictionary:
	var result := Applications.accept(state, config, template_id)
	if bool(result["ok"]):
		for content_id in ContentRules.refresh_unlocks(state, config):
			content_unlocked.emit(content_id)
		creator_joined.emit(template_id)
		save_game()
	return result


## Builds a room type on an empty lot. Returns Housing.check_build().
func build_room(room_id: String, type_id: String) -> Dictionary:
	var result := Housing.build(state, config, room_id, type_id)
	if bool(result["ok"]):
		RoomPlanner.assign_home_rooms(state, config)
		room_built.emit(room_id)
		for content_id in ContentRules.refresh_unlocks(state, config):
			content_unlocked.emit(content_id)
		save_game()
	return result


## Moves a creator into another bedroom (swapping if it's taken). Returns Housing.assign_bedroom().
func assign_bedroom(creator_id: String, room_id: String) -> Dictionary:
	var creator := state.get_creator(creator_id)
	if creator == null:
		return {"ok": false, "reason": "Unknown creator"}
	var result := Housing.assign_bedroom(state, config, creator, room_id)
	if bool(result["ok"]):
		bedroom_changed.emit(creator_id)
		if not str(result["swapped_with"]).is_empty():
			bedroom_changed.emit(str(result["swapped_with"]))
		save_game()
	return result


## Measurement display units (metric by default).
func imperial_units() -> bool:
	return bool(state.settings.get("imperial", false))


func set_imperial_units(value: bool) -> void:
	state.settings["imperial"] = value
	settings_changed.emit()


## Painted character art mode: "auto" (paintings for every creator who has them) or "off" (classic
## procedural art for everyone).
func art_mode() -> String:
	var value := str(state.settings.get("illustrated_art", "auto"))
	return value if IllustratedArt.MODES.has(value) else "auto" # older saves: "always" -> auto


func set_art_mode(value: String) -> void:
	state.settings["illustrated_art"] = value if IllustratedArt.MODES.has(value) else "auto"
	IllustratedArt.mode = art_mode()
	settings_changed.emit()
	save_game()


## Developer tools (debug builds only): advance time through the real simulation at full efficiency.
func dev_advance(minutes: float) -> void:
	if not OS.is_debug_build():
		return
	var totals := Simulation.advance(state, config, minutes, 5.0)
	if totals.has("trends_started"):
		trends_changed.emit(totals["trends_started"])
	for creator_id in totals.get("recovered", []):
		recovery_finished.emit(str(creator_id))
	ticked.emit()
	save_game()


func dev_add_cash(amount: float) -> void:
	if not OS.is_debug_build():
		return
	state.cash += amount
	save_game()


## Buys an equipment / business upgrade. Returns Upgrades.check().
func purchase_upgrade(upgrade_id: String) -> Dictionary:
	var result := Upgrades.purchase(state, config, upgrade_id)
	if bool(result["ok"]):
		upgrade_purchased.emit(upgrade_id)
		for content_id in ContentRules.refresh_unlocks(state, config):
			content_unlocked.emit(content_id)
		save_game()
	return result


func upgrade_room(room_id: String) -> bool:
	if not RoomUpgrades.try_upgrade(state, config, room_id):
		return false
	room_upgraded.emit(room_id)
	for content_id in ContentRules.refresh_unlocks(state, config):
		content_unlocked.emit(content_id)
	save_game()
	return true


## Buys a makeover item for a creator (she must be willing). Returns Appearance.check_item().
func purchase_appearance(creator_id: String, item_id: String) -> Dictionary:
	var creator := state.get_creator(creator_id)
	if creator == null:
		return {"ok": false, "reason": "Unknown creator"}
	var result := Appearance.purchase(state, config, creator, item_id)
	if bool(result["ok"]):
		appearance_changed.emit(creator_id, item_id)
		save_game()
	return result


## Pays out an optional bonus photoshoot with the given average shot quality (0..1).
func complete_photoshoot(creator_id: String, score: float) -> Dictionary:
	var creator := state.get_creator(creator_id)
	if creator == null:
		return {"ok": false, "reason": "Unknown creator"}
	var result := Photoshoot.complete(creator, state, config, score)
	if bool(result.get("ok", false)):
		photoshoot_completed.emit(creator_id, result)
		save_game()
	return result


## Assigns a creator's content specialisation. Returns ContentRules.check() so the UI can
## explain refusals; boundaries are enforced here, not just hidden in the UI.
func set_content_focus(creator_id: String, content_id: String) -> Dictionary:
	var creator := state.get_creator(creator_id)
	if creator == null:
		return {"ok": false, "reason": "Unknown creator"}
	var result := ContentRules.check(creator, content_id, state, config)
	if bool(result["ok"]) and creator.content_focus != content_id:
		creator.content_focus = content_id
		content_focus_changed.emit(creator_id, content_id)
		save_game()
	return result


func set_speed(new_speed: int) -> void:
	speed = maxi(1, new_speed)
	paused = false
	speed_changed.emit(speed, paused)


func set_paused(value: bool) -> void:
	paused = value
	speed_changed.emit(speed, paused)


func reset_game() -> void:
	SaveSystem.delete(save_path)
	state = GameState.new_game(config)
	state.last_seen_unix = now_unix()
	pending_offline_summary = {}
	IllustratedArt.mode = art_mode()
	state_replaced.emit()
	save_game()


## Human-readable description of what a creator is doing.
func describe_activity(creator: CreatorState) -> String:
	if creator.is_travelling():
		var target := state.get_room(creator.target_room_id)
		var room_name := str(config.room_type(target.type_id).get("name", "")) if target != null else ""
		return "Walking to the %s" % room_name if not room_name.is_empty() else "Walking"
	var room := state.get_room(creator.room_id)
	var activity := ActivityResolver.resolve(creator, creator.activity_id, config, room)
	var label := str(activity.get("label", creator.activity_id))
	if creator.has_reaction(state.game_minutes):
		var other := state.get_creator(str(creator.reaction.get("with", "")))
		if other != null and not str(creator.reaction.get("label", "")).is_empty():
			label = "%s with %s" % [str(creator.reaction["label"]).capitalize(), other.first_name()]
	if room != null and not str(activity.get("room_type", "")).is_empty():
		return "%s in the %s" % [label, config.room_type(room.type_id).get("name", "")]
	return label


func now_unix() -> float:
	return Time.get_unix_time_from_system()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			if state != null:
				save_game()
			get_tree().quit()
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if state != null:
				save_game()
