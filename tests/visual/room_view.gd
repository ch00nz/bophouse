extends SceneTree
## Screenshots the Room View prototype in the real game (needs a display):
##   godot --path . --resolution 1280x720 --script res://tests/visual/room_view.gd -- <output_dir> [living_level]
## Writes room_day.png (three residents: two relaxing on the couch and chatting, Ava filming socials),
## room_night.png, room_live_*.png (the simulation running for a few seconds: people walking in and
## out, changing activities), room_manager.png (clicking a creator in the room opens her management
## screen) and house_after.png (Back to House; the house view is intact). Uses a tool save.

var _out := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var level := int(args[1]) if args.size() > 1 else 2
	var game: Node = root.get_node("Game")
	var config: GameConfig = game.config
	var state := GameState.new_game(config, 2026)
	state.cash = 1_000_000.0
	for id in ["mia", "roxy"]:
		if Housing.buildable_lots(state, config, "bedroom").is_empty():
			Upgrades.purchase(state, config, Upgrades.EXPANSION)
		var lot: RoomState = Housing.buildable_lots(state, config, "bedroom")[0]
		Housing.build(state, config, lot.id, "bedroom")
		Applications.move_in(state, config, id)
	state.get_room("living_1").level = level
	ContentRules.refresh_unlocks(state, config)
	state.game_minutes = 14.0 * 60.0
	state.cash = 12_500.0
	state.last_seen_unix = game.now_unix()
	# Mia and Roxy relax in the lounge and chat; Ava films social content there.
	_place(state, "mia", 0.42, "socialise")
	_place(state, "roxy", 0.6, "socialise")
	state.get_creator("mia").reaction = {"kind": "chat", "anim": "chat", "with": "roxy", "until": state.game_minutes + 120.0, "label": "chatting"}
	state.get_creator("roxy").reaction = {"kind": "chat", "anim": "chat", "with": "mia", "until": state.game_minutes + 120.0, "label": "chatting"}
	var ava := state.get_creator("ava")
	ava.content_focus = "social_media"
	_place(state, "ava", 0.86, "work")
	game.state = state
	game.set("pending_offline_summary", {})
	game.call("set_paused", true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(6)
	main.call("open_room", "living_1")
	await _frames(20)
	await _shot("room_day.png")
	state.game_minutes = 22.5 * 60.0
	await _frames(8)
	await _shot("room_night.png")
	state.game_minutes = 15.0 * 60.0
	# Let the real simulation run: activities change, people leave and arrive.
	game.call("set_speed", 3)
	game.call("set_paused", false)
	for i in 4:
		await _seconds(4.0)
		await _shot("room_live_%d.png" % i)
	game.call("set_paused", true)
	# Click whoever is in the room: her management screen opens on top of the Room View.
	var interior: Node = main.get_node("RoomView")
	var target: Node2D = null
	for view: Node in interior.find_children("Creator_*", "", true, false):
		if (view as Node2D).visible:
			target = view
			break
	if target != null:
		var screen := target.get_global_transform_with_canvas() * Vector2(0, -60)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = screen
		press.global_position = screen
		root.push_input(press)
		await _frames(6)
		await _shot("room_manager.png")
		root.get_tree().get_first_node_in_group("hud").call("_close_overlay")
	main.call("close_room")
	await _frames(6)
	await _shot("house_after.png")
	print("room open after back: ", main.call("is_room_open"))
	quit()


func _place(state: GameState, id: String, x: float, activity: String) -> void:
	var creator := state.get_creator(id)
	var room := state.get_room("living_1")
	creator.travel_path = []
	creator.target_room_id = ""
	creator.room_id = room.id
	creator.position = Vector2(room.column + x * room.width, room.storey)
	creator.activity_id = activity
	creator.energy = 80.0
	creator.mood = 75.0


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < s * 1000.0:
		await process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(file_name)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
