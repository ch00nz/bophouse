extends SceneTree
## Renders creator looks to a PNG for art review (needs a display, not --headless):
##   godot --path . --script res://tests/visual/lookbook.gd -- <output.png> [cast]
## With "cast", only row 1 is rendered with large previews (for checking body proportions).
## Row 1: every creator template as she'd join the house (body from her measurements).
## Rows 2-3: Ava with makeovers and procedures (measurement changes show as body changes).

const LOOKS := [
	["Ava + breast aug.", ["breast_augmentation"]],
	["Ava + BBL", ["bbl"]],
	["Glamour + glam", ["outfit:glamour", "makeup:glam", "hair_color:blonde", "lip_filler"]],
	["Lingerie + both", ["outfit:lingerie", "breast_augmentation", "bbl", "rose_tattoo"]],
	["Gym set", ["outfit:fitness", "hair_style:high_ponytail", "belly_piercing"]],
	["Alt", ["hair_color:pink", "makeup:smoky_alt", "rose_tattoo", "arm_sleeve", "outfit:alt_punk", "hair_style:space_buns", "nose_piercing"]],
	["Party + curls", ["outfit:party_dress", "hair_style:curls", "hair_color:cherry"]],
	["Poolside bikini", ["outfit:bikini", "hair_color:honey", "makeup:glam"]],
]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://lookbook.png"
	var cast_only := args.size() > 1 and args[1] == "cast"
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)
	for template_id in config.creator_order:
		var creator := CreatorSetup.create(config.creator_templates[template_id], config, state)
		_add(grid, config, creator, "%s %s" % [creator.first_name(), creator.measurements.bwh_text().replace(" cm", "")],
			Vector2(300, 600) if cast_only else Vector2(250, 300))
	var ava := state.creators[0]
	if cast_only:
		await _save(out_path)
		return
	_add(grid, config, ava, "Ava (base)")
	for look: Array in LOOKS:
		var creator := ava.clone()
		for item_id in look[1]:
			Appearance.apply_item(creator, config, config.look_item(str(item_id)))
		creator.recovery = {}
		_add(grid, config, creator, str(look[0]))
	await _save(out_path)


func _save(out_path: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("saved ", out_path)
	quit()


func _add(grid: GridContainer, config: GameConfig, creator: CreatorState, caption_text: String, size: Vector2 = Vector2(250, 300)) -> void:
	var preview := CreatorPreview.new("full", size)
	preview.pose = "idle"
	preview.show_look(Appearance.render_spec(creator, config))
	grid.add_child(preview)
	var caption := Label.new()
	caption.text = caption_text
	caption.position = Vector2(8, size.y - 28)
	caption.add_theme_font_size_override("font_size", 14)
	preview.add_child(caption)
