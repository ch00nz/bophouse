extends SceneTree
## Screenshots the real game UI with a three-creator house (needs a display, not --headless):
##   godot --path . --resolution 1280x720 --script res://tests/visual/house_scene.gd -- <output_dir>
## Writes house.png, manager_overview.png, manager_stats.png, manager_makeover.png,
## manager_finances.png, manager_relationships.png, manager_closeup.png, manager_lineup.png, manager_reveal.png, applications.png, applications_compare.png,
## finances.png, upgrades.png and new_game.png.
## Uses a separate tool save (see Game), so the player's save is never touched.

var _out := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else OS.get_user_data_dir()
	_run.call_deferred()


func _run() -> void:
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
	state.get_room("studio_1").level = 2
	ContentRules.refresh_unlocks(state, config)
	Simulation.advance(state, config, 6.0 * 60.0, 1.0) # into the afternoon: working, socialising
	state.cash = 12_500.0
	state.last_seen_unix = game.now_unix()
	game.state = state
	game.set_paused(true)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	await _shot("house.png")
	var hud: Node = root.get_tree().get_first_node_in_group("hud")
	hud.call("open_manager", "roxy", "Overview")
	await _frames(6)
	await _shot("manager_overview.png")
	hud.call("open_manager", "roxy", "Stats & Measurements")
	await _frames(6)
	await _shot("manager_stats.png")
	hud.call("open_manager", "mia", "Makeover")
	await _frames(6)
	await _shot("manager_makeover.png")
	hud.call("open_manager", "ava", "Finances")
	await _frames(6)
	await _shot("manager_finances.png")
	hud.call("open_manager", "ava", "Relationships")
	await _frames(6)
	await _shot("manager_relationships.png")
	var manager_script: GDScript = load("res://src/ui/creator_manager.gd")
	manager_script.set("hero_view", "closeup")
	hud.call("open_manager", "ava", "Makeover")
	await _frames(6)
	await _shot("manager_closeup.png")
	manager_script.set("hero_view", "lineup")
	hud.call("open_manager", "mia", "Overview")
	await _frames(6)
	await _shot("manager_lineup.png")
	manager_script.set("hero_view", "full")
	# Buying a new look: the hero shows before/after with the reveal flourish.
	hud.call("open_manager", "ava", "Makeover")
	await _frames(4)
	var hero: Node = root.find_children("*", "CreatorPreview", true, false).filter(
		func(n: Node) -> bool: return (n as Control).size.x > 300)[0]
	var ava: CreatorState = game.state.get_creator("ava")
	var before := Appearance.render_spec(ava, config)
	game.call("purchase_appearance", "ava", "outfit:bikini")
	hero.call("show_compare", before, Appearance.render_spec(ava, config))
	hero.call("reveal")
	await _frames(20)
	await _shot("manager_reveal.png")
	hud.call("open_applications")
	await _frames(6)
	await _shot("applications.png")
	var market: Node = root.find_children("*", "ApplicationsPanel", true, false)[0]
	market.set("_compare", true)
	market.call("_show_detail")
	await _frames(6)
	await _shot("applications_compare.png")
	Simulation.advance(state, config, 26.0 * 60.0, 5.0) # a full day of finances
	hud.call("open_finances")
	await _frames(6)
	await _shot("finances.png")
	hud.call("open_upgrades")
	await _frames(6)
	await _shot("upgrades.png")
	# A brand-new game: the humble start.
	game.state = GameState.new_game(config, 7)
	game.state.last_seen_unix = game.now_unix()
	game.state_replaced.emit()
	await _frames(8)
	await _shot("new_game.png")
	quit()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(file_name)
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
