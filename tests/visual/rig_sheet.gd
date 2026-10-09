extends SceneTree
## Review sheet for painted skeletal rigs (needs a display):
##   godot --path . --resolution 1280x720 --script res://tests/visual/rig_sheet.gd -- <output.png> [creator_id] [anim] [items]
## For each rigged pose: the bone-weight regions, then 5 frames across its main animation (large,
## on dark purple), so limb motion, seams and tearing are visible.

const FRAMES := 5


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://rig_sheet.png"
	var creator_id: String = args[1] if args.size() > 1 else "ava"
	var only: String = args[2] if args.size() > 2 else ""
	var items: String = args[3] if args.size() > 3 else ""
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var creator := CreatorSetup.create(config.creator_templates[creator_id], config, state)
	for item_id in items.split(",", false):
		Appearance.apply_item(creator, config, config.look_item(item_id))
	var spec := Appearance.render_spec(creator, config)
	var bg := ColorRect.new()
	bg.color = Color("2b1236")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var rows := [["idle", "idle"], ["walk", "walk"], ["film", "film"], ["stream", "stream"], ["selfie", "selfie"]]
	if not only.is_empty():
		rows = rows.filter(func(row: Array) -> bool: return row[0] == only)
	var big := not only.is_empty()
	for r in rows.size():
		var anim: String = rows[r][0]
		var art := IllustratedArt.sprite(spec, anim)
		if art.is_empty() or not IllustratedRig.has_rig(IllustratedArt.rigs_path(spec), str(art["name"])):
			continue
		for f in FRAMES + 1:
			var rig := IllustratedRig.create(art, art["full_size"], IllustratedArt.rigs_path(spec))
			rig.set_paint_material(IllustratedArt.material_for(spec, art))
			rig.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			root.add_child(rig)
			var s := 2.6 if big else 0.52
			rig.scale = Vector2(s, s)
			rig.position = Vector2(110 + f * 210, 700) if big else Vector2(50 + f * 98 + (r % 2) * 640, 135 + (r / 2) * 140)
			if f == 0:
				rig.show_weights(true)
				rig.pose_at(str(rows[r][1]), 0.0)
			else:
				var length := 1.0
				rig.pose_at(str(rows[r][1]), 0.0)
				length = rig.get_node("Player").get_animation(rig.current_animation()).length if rig.current_animation() != "" else 1.0
				rig.pose_at(str(rows[r][1]), length * (f - 1) / float(FRAMES - 1) * (1.0 if big else 0.5))
		var label := Label.new()
		label.text = "%s  (%s)" % [anim, art["name"]]
		label.position = Vector2(10 + (r % 2) * 640, 4 + (r / 2) * 140)
		root.add_child(label)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("saved ", out_path)
	quit()
