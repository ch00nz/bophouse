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
	get_tree().set_auto_accept_quit(false)
	_load_or_create()


func _load_or_create() -> void:
	var now := now_unix()
	var loaded := SaveSystem.read(save_path)
	if loaded != null and SaveSystem.is_compatible(loaded, config):
		state = loaded
		var summary := OfflineProgress.apply(state, config, now)
		if float(summary["real_seconds"]) >= config.tuning_f("offline", "min_seconds_for_popup", 30.0):
			pending_offline_summary = summary
	else:
		state = GameState.new_game(config)
		state.last_seen_unix = now
	_last_frame_unix = now
	save_game()


func _process(delta: float) -> void:
	if state == null:
		return
	var now := now_unix()
	_check_frame_gap(now)
	_last_frame_unix = now
	if not paused:
		var real_delta := minf(delta, config.tuning_f("time", "max_frame_delta_seconds", 0.25))
		var minutes := real_delta * config.tuning_f("time", "game_minutes_per_real_second", 2.0) * speed
		Simulation.advance(state, config, minutes, config.tuning_f("time", "max_sim_step_minutes", 1.0))
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
	save_game()


func save_game() -> void:
	_autosave_elapsed = 0.0
	var now := now_unix()
	state.last_seen_unix = maxf(state.last_seen_unix, now)
	if SaveSystem.write(save_path, state, now) == OK:
		saved.emit()
	else:
		push_warning("Game: failed to save to %s" % save_path)


func upgrade_room(room_id: String) -> bool:
	if not RoomUpgrades.try_upgrade(state, config, room_id):
		return false
	room_upgraded.emit(room_id)
	save_game()
	return true


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
	state_replaced.emit()
	save_game()


## Human-readable description of what a creator is doing.
func describe_activity(creator: CreatorState) -> String:
	if creator.is_travelling():
		var target := state.get_room(creator.target_room_id)
		var room_name := str(config.room_type(target.type_id).get("name", "")) if target != null else ""
		return "Walking to the %s" % room_name if not room_name.is_empty() else "Walking"
	var label := str(config.activity(creator.activity_id).get("label", creator.activity_id))
	var room := state.get_room(creator.room_id)
	if room != null and not str(config.activity(creator.activity_id).get("room_type", "")).is_empty():
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
