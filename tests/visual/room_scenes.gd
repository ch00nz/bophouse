extends SceneTree
## Renders rooms with creators in each content-production pose to a PNG (needs a display):
##   godot --path . --script res://tests/visual/room_scenes.gd -- <output.png>

const CELL_W := 170.0
const STOREY_H := 200.0
const FLOOR_H := 14.0

## [room type, level, content, caption]
const SCENES := [
	["bedroom", 2, "solo_premium", "Bedroom: premium set (recline)"],
	["bedroom", 3, "topless_premium", "Bedroom: closed set (implied)"],
	["bedroom", 2, "livestream", "Bedroom: livestream"],
	["living_room", 2, "social_media", "Lounge: socials selfie"],
	["studio", 3, "glamour", "Studio: glamour posing"],
	["studio", 2, "collab_girl_girl", "Studio: girl/girl collab"],
	["studio", 2, "collab_boy_girl", "Studio: implied b/g collab"],
	["studio", 3, "livestream", "Studio: livestream"],
]


class Figure extends Node2D:
	var spec: Dictionary
	var anim: String
	var facing: float
	var lift: float
	var props: Array
	var guest_outfit: Dictionary
	var t := 0.6

	func _draw() -> void:
		CreatorRenderer.draw_with_props(self, spec, anim, t, Vector2.ZERO, facing, 1.0, lift, props, guest_outfit)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://room_scenes.png"
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var ava := state.creators[0]
	Appearance.apply_item(ava, config, config.look_item("outfit:lingerie"))
	ava.recovery = {}
	var spec := Appearance.render_spec(ava, config)
	var background := ColorRect.new()
	background.color = Color("2b1d3f")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	for i in SCENES.size():
		var scene: Array = SCENES[i]
		var room := RoomState.create("r%d" % i, str(scene[0]), 0, 0, 2, int(scene[1]))
		var origin := Vector2(10 + (i % 4) * 318, 20 + (i / 4) * 350)
		var view := RoomView.new()
		root.add_child(view)
		view.position = origin
		view.setup(room, config, Vector2(2 * CELL_W, STOREY_H), FLOOR_H, false)
		var creator := ava.clone()
		creator.content_focus = str(scene[2])
		var activity := ActivityResolver.resolve(creator, CreatorBrain.WORK, config, room)
		var figure := Figure.new()
		figure.spec = spec
		figure.anim = str(activity.get("anim", "idle"))
		figure.facing = float(activity.get("face", 1)) if float(activity.get("face", 0)) != 0.0 else 1.0
		figure.props = activity.get("props", [])
		figure.guest_outfit = config.look_option("outfit", "glamour")
		figure.lift = 0.0
		if figure.anim == "recline":
			for item: Dictionary in config.room_level_def(room.type_id, room.level).get("furniture", []):
				if bool(item.get("sleep_surface", false)):
					figure.lift = float(item.get("h", 0.0)) * (STOREY_H - FLOOR_H)
		figure.position = origin + Vector2(2 * CELL_W * float(activity.get("spot", 0.5)), STOREY_H - FLOOR_H)
		root.add_child(figure)
		var caption := Label.new()
		caption.text = str(scene[3])
		caption.position = origin + Vector2(0, STOREY_H + 4)
		caption.add_theme_font_size_override("font_size", 15)
		root.add_child(caption)
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("saved ", out_path)
	quit()
