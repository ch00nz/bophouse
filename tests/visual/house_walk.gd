extends SceneTree
## Captures a creator moving through the real house (needs a display):
##   godot --path . --resolution 1280x720 --script res://tests/visual/house_walk.gd -- <output.png> [creator_id]
## Drains her energy so her own brain sends her upstairs to bed, then grabs frames of the walk, the
## stairs and the sleep fallback into one strip (crops of the house area). Uses a tool save.

const FRAMES := 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://house_walk.png"
	var creator_id: String = args[1] if args.size() > 1 else "ava"
	var game: Node = root.get_node("Game")
	var config: GameConfig = game.config
	var state := GameState.new_game(config, 7)
	state.last_seen_unix = game.now_unix()
	game.state = state
	game.set("pending_offline_summary", {}) # a previous tool run's save must not show "welcome back"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await process_frame
	var creator: CreatorState = state.get_creator(creator_id)
	creator.energy = 2.0
	creator.mood = 25.0
	game.call("set_speed", 3)
	game.call("set_paused", false)
	var shots: Array[Image] = []
	var waited := 0
	while shots.size() < FRAMES and waited < 2400:
		await process_frame
		waited += 1
		if waited % 45 == 0:
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var k := image.get_width() / 1280.0
			shots.append(image.get_region(Rect2i(int(240 * k), int(225 * k), int(660 * k), int(450 * k))))
	var w := shots[0].get_width()
	var h := shots[0].get_height()
	var strip := Image.create(w * 4, h * 3, false, shots[0].get_format())
	for i in shots.size():
		strip.blit_rect(shots[i], Rect2i(Vector2i.ZERO, shots[i].get_size()), Vector2i((i % 4) * w, (i / 4) * h))
	strip.save_png(out_path)
	print("saved ", out_path, " (", shots.size(), " frames)")
	quit()
