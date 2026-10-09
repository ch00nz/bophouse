extends SceneTree
## Review sheet for painted creator art (needs a display):
##   godot --path . --resolution 1280x720 --script res://tests/visual/illustrated_sheet.gd -- <output.png> [creator_id]
## Row 1: house sprites at gameplay scale, painted (top) vs procedural (below) for each animation,
##        including walking both ways and the stairs back view. Sleep uses the procedural fallback.
## Row 2: the six mood expressions and the four painted outfits.

const ANIMS := [["idle", 1.0, false], ["walk", 1.0, false], ["walk", -1.0, false], ["walk", 1.0, true],
	["film", 1.0, false], ["selfie", 1.0, false], ["socialise", 1.0, false], ["sleep", 1.0, false]]
const LABELS := ["idle", "walk >", "< walk", "stairs", "film", "selfie", "socialise", "sleep"]


class Sprite extends Node2D:
	var spec: Dictionary
	var anim: String
	var facing := 1.0
	var stairs := false
	var painted := true

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func _draw() -> void:
		var lying := anim == "sleep"
		var lift := 22.0 if lying else 0.0
		if lying:
			draw_rect(Rect2(-70, -lift, 140, lift), Color("fbf3ee"))
		draw_set_transform(Vector2.ZERO)
		var art := IllustratedArt.sprite(spec, anim, stairs) if painted else {}
		if not art.is_empty():
			var mirror := anim == "walk" and not stairs and facing < 0.0
			IllustratedArt.draw(self, art, Vector2.ZERO, 1.0, mirror)
		else:
			CreatorRenderer.draw(self, spec, anim, 0.7, Vector2.ZERO, facing, 1.0, lift)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://illustrated_sheet.png"
	var creator_id: String = args[1] if args.size() > 1 else "ava"
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var creator := CreatorSetup.create(config.creator_templates[creator_id], config, state)
	var spec := Appearance.render_spec(creator, config)
	var bg := ColorRect.new()
	bg.color = Color("e9e1f0")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	for i in ANIMS.size():
		var entry: Array = ANIMS[i]
		for row in 2:
			var s := Sprite.new()
			s.spec = spec
			s.anim = entry[0]
			s.facing = entry[1]
			s.stairs = entry[2]
			s.painted = row == 0
			s.position = Vector2(70 + i * 150, 150 + row * 160)
			root.add_child(s)
		var label := Label.new()
		label.text = LABELS[i]
		label.position = Vector2(40 + i * 150, 318)
		label.add_theme_color_override("font_color", Color("2b1236"))
		root.add_child(label)
	for i in CreatorMood.EXPRESSIONS.size():
		var face := CreatorPreview.new("closeup", Vector2(118, 130))
		face.show_look(spec)
		face.set_mood(CreatorMood.EXPRESSIONS[i])
		face.position = Vector2(8 + i * 122, 340)
		root.add_child(face)
	var outfits := IllustratedArt.outfits(spec)
	for i in outfits.size():
		var preview := CreatorPreview.new("full", Vector2(130, 240))
		preview.pose = "idle"
		preview.show_look(spec)
		preview.preview_outfit(str((outfits[i] as Array)[0]))
		preview.position = Vector2(745 + i * 133, 340)
		root.add_child(preview)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("saved ", out_path)
	quit()
