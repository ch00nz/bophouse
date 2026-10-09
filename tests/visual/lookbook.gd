extends SceneTree
## Renders a grid of creator looks to a PNG for art review (needs a display, not --headless):
##   godot --path . --script res://tests/visual/lookbook.gd -- <output.png>

const LOOKS := [
	["Base", []],
	["Breast aug.", ["breast_augmentation"]],
	["BBL", ["bbl"]],
	["Glamour + glam", ["outfit:glamour", "makeup:glam", "hair_color:blonde", "lip_filler"]],
	["Lingerie set", ["outfit:lingerie", "breast_augmentation", "bbl", "rose_tattoo"]],
	["Gym set", ["outfit:fitness", "hair_style:high_ponytail", "belly_piercing"]],
	["Alt", ["hair_color:pink", "makeup:smoky_alt", "rose_tattoo", "belly_piercing", "nipple_piercing"]],
	["Casual + tattoo", ["rose_tattoo", "belly_piercing"]],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://lookbook.png"
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)
	for look: Array in LOOKS:
		var creator := state.creators[0].clone()
		for item_id in look[1]:
			Appearance.apply_item(creator, config, config.look_item(str(item_id)))
		creator.recovery = {}
		var preview := CreatorPreview.new("full", Vector2(314, 354))
		preview.pose = "idle"
		preview.show_look(Appearance.render_spec(creator, config))
		grid.add_child(preview)
		var caption := Label.new()
		caption.text = str(look[0])
		caption.position = Vector2(10, 322)
		caption.add_theme_font_size_override("font_size", 18)
		preview.add_child(caption)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("saved ", out_path)
	quit()
