extends SceneTree
## Art review sheet for one creator (needs a display, not --headless):
##   godot --path . --resolution 1280x720 --script res://tests/visual/character_sheet.gd -- <output.png> [creator_id] [items,comma,separated]
## Top: hero-size renders (portrait scale) in several poses. Bottom: gameplay-size sprites
## (1x, as in the house) for every animation, plus a 3x nearest-neighbour zoom of the sprite row.

const HERO_POSES := ["idle", "film", "selfie", "celebrate"]
const SPRITE_POSES := ["idle", "walk", "film", "selfie", "stream", "socialise", "chat", "celebrate", "argue", "sleep", "recline"]


class Figure extends Node2D:
	var spec: Dictionary
	var anim: String
	var t := 0.7
	var figure_scale := 1.0
	var facing := 1.0

	func _draw() -> void:
		var lift := 22.0 if anim == "sleep" or anim == "recline" else 0.0
		if lift > 0.0:
			draw_rect(Rect2(-70 * figure_scale, -lift * figure_scale, 140 * figure_scale, lift * figure_scale), Color("fbf3ee"))
		CreatorRenderer.draw(self, spec, anim, t, Vector2.ZERO, facing, figure_scale, lift)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://character_sheet.png"
	var creator_id: String = args[1] if args.size() > 1 else "ava"
	InkPen.debug_validate = true
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var creator := CreatorSetup.create(config.creator_templates[creator_id], config, state)
	if args.size() > 2 and not args[2].is_empty():
		for item_id in args[2].split(","):
			Appearance.apply_item(creator, config, config.look_item(item_id))
	creator.recovery = {}
	var spec := Appearance.render_spec(creator, config)
	var bg := ColorRect.new()
	bg.color = Color("3a1d4a")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	for i in HERO_POSES.size():
		var f := Figure.new()
		f.spec = spec
		f.anim = HERO_POSES[i]
		f.figure_scale = 3.5
		f.t = 0.7 + i * 2.6
		f.position = Vector2(120 + i * 240, 455)
		root.add_child(f)
	for i in SPRITE_POSES.size():
		var f := Figure.new()
		f.spec = spec
		f.anim = SPRITE_POSES[i]
		f.position = Vector2(50 + i * 108 + (40 if SPRITE_POSES[i] == "recline" else 0), 640)
		root.add_child(f)
	var label := Label.new()
	label.text = "%s  %s" % [creator.display_name, creator.measurements.bwh_text()]
	label.position = Vector2(10, 6)
	root.add_child(label)
	await _save(out_path)


func _save(out_path: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var k := image.get_width() / 1280.0
	# 3x zoom of a few gameplay sprites (nearest) to judge readability.
	var crop := image.get_region(Rect2i(0, int(500 * k), int(440 * k), int(150 * k)))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(image.get_width(), image.get_height() + crop.get_height(), false, image.get_format())
	canvas.fill(Color("3a1d4a"))
	canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
	canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(0, image.get_height()))
	canvas.save_png(out_path)
	print("saved ", out_path)
	quit()
