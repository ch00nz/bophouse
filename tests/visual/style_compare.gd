extends SceneTree
## Before/after review sheet for the refined renderer prototype (RenderStyle). Needs a display:
##   godot --path . --script res://tests/visual/style_compare.gd -- <output.png> [subject_id] [reference_id]
## Columns: <subject> refined | <subject> classic | <reference> classic (defaults: mia, roxy).
## Rows: face close-up, hero poses, Room View scale (seated chat on a couch) and house sprites.
## Also writes <output>_expressions.png: the subject's expressions, refined (top) vs classic (bottom).

const SIZE := Vector2i(1800, 1260)
const BG := Color("3a1d4a")
const ROOM_WALL := Color("eadfd3")
## Room View draws the living room at roughly this many pixels per model unit (1280x720 window).
const ROOM_SCALE := 2.6


class Figure extends Node2D:
	var spec: Dictionary
	var anim := "idle"
	var t := 0.7
	var figure_scale := 1.0
	var facing := 1.0
	var lift := 0.0

	func _draw() -> void:
		if anim == "sleep" or anim == "recline":
			draw_rect(Rect2(-70 * figure_scale, -lift * figure_scale, 140 * figure_scale, lift * figure_scale), Color("fbf3ee"))
		elif anim.begins_with("sit"):
			var s := figure_scale
			draw_rect(Rect2(-20 * s, -lift * s, 58 * s, lift * s), Color("8a5a7a"))
			draw_rect(Rect2(-26 * s, -(lift + 26.0) * s, 10 * s, (lift + 26.0) * s), Color("754a68"))
		CreatorRenderer.draw(self, spec, anim, t, Vector2.ZERO, facing, figure_scale, lift)


var _viewport: SubViewport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://style_compare.png"
	var subject_id: String = args[1] if args.size() > 1 else "mia"
	var reference_id: String = args[2] if args.size() > 2 else "roxy"
	InkPen.debug_validate = true
	var config := GameConfig.load_from_dir()
	var state := GameState.new_game(config, 1)
	var subject := _spec(config, state, subject_id)
	var reference := _spec(config, state, reference_id)
	var columns := [
		[_styled(subject, RenderStyle.REFINED), "%s: refined prototype" % _name(config, subject_id)],
		[_styled(subject, RenderStyle.CLASSIC), "%s: classic (before)" % _name(config, subject_id)],
		[_styled(reference, RenderStyle.CLASSIC), "%s: classic (reference)" % _name(config, reference_id)],
	]

	_viewport = _new_viewport(SIZE)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(SIZE)
	_viewport.add_child(bg)
	var room := ColorRect.new()
	room.color = ROOM_WALL
	room.position = Vector2(0, 880)
	room.size = Vector2(SIZE.x, SIZE.y - 880)
	_viewport.add_child(room)
	for i in columns.size():
		var spec: Dictionary = columns[i][0]
		var x0 := 600.0 * i
		_label(str(columns[i][1]), Vector2(x0 + 16, 8), 20)
		# Face close-up, clipped to a panel.
		var panel := Control.new()
		panel.clip_contents = true
		panel.position = Vector2(x0 + 20, 40)
		panel.size = Vector2(560, 400)
		_viewport.add_child(panel)
		var panel_bg := ColorRect.new()
		panel_bg.color = Color("f3e7df")
		panel_bg.size = panel.size
		panel.add_child(panel_bg)
		var face_scale := 15.0
		var hs := float(spec.get("height_scale", 1.0))
		panel.add_child(_figure(spec, "idle", Vector2(280, 215) - Vector2(1.5, -110.0) * face_scale * hs, face_scale, 0.7))
		# Hero poses.
		_viewport.add_child(_figure(spec, "idle", Vector2(x0 + 170, 860), 3.2, 0.7))
		_viewport.add_child(_figure(spec, "film", Vector2(x0 + 430, 860), 3.2, 3.3))
		# Room View scale: seated chat on a couch, and house-scale sprites.
		var sit := _figure(spec, "sit_chat", Vector2(x0 + 150, 1240), ROOM_SCALE, 1.4)
		sit.lift = 20.0
		_viewport.add_child(sit)
		_label("Room View %.1fx" % ROOM_SCALE, Vector2(x0 + 16, 888), 14, Color("5a3a50"))
		for k in 3:
			var anim: String = ["idle", "walk", "chat"][k]
			_viewport.add_child(_figure(spec, anim, Vector2(x0 + 380 + k * 70, 1230), 1.0, 0.9 + k))
		_label("house 1x", Vector2(x0 + 380, 1236), 12, Color("5a3a50"))
	await _save(out_path)

	# Expression strip.
	var expressions := ["smile", "grin", "laugh", "wink", "sultry", "kiss", "talk", "surprised", "annoyed", "sad", "sleep"]
	_viewport = _new_viewport(Vector2i(1800, 560))
	var bg2 := ColorRect.new()
	bg2.color = Color("f3e7df")
	bg2.size = Vector2(1800, 560)
	_viewport.add_child(bg2)
	for row in 2:
		var spec: Dictionary = columns[row][0]
		_label(str(columns[row][1]), Vector2(10, 4 + row * 280), 16, Color("3a1d4a"))
		for i in expressions.size():
			var e := spec.duplicate()
			e.erase("look_hash")
			e["expression"] = expressions[i]
			var cell := Control.new()
			cell.clip_contents = true
			cell.position = Vector2(10 + i * 162, 30 + row * 280)
			cell.size = Vector2(156, 240)
			_viewport.add_child(cell)
			var s := 5.6
			var hs := float(spec.get("height_scale", 1.0))
			cell.add_child(_figure(e, "idle", Vector2(78, 92) - Vector2(1.5, -110.0) * s * hs, s, 0.7))
			_label(str(expressions[i]), cell.position + Vector2(4, 222), 13, Color("3a1d4a"))
	await _save(out_path.get_basename() + "_expressions.png")
	quit()


func _spec(config: GameConfig, state: GameState, creator_id: String) -> Dictionary:
	var creator := CreatorSetup.create(config.creator_templates[creator_id], config, state)
	creator.recovery = {}
	return Appearance.render_spec(creator, config)


func _styled(spec: Dictionary, style: String) -> Dictionary:
	var copy := spec.duplicate()
	copy["render_style"] = style
	copy.erase("illustrated") # always the procedural renderer here
	return copy


func _name(config: GameConfig, creator_id: String) -> String:
	return str(config.creator_templates[creator_id].get("name", creator_id)).get_slice(" ", 0)


func _figure(spec: Dictionary, anim: String, pos: Vector2, scale: float, t: float) -> Figure:
	var f := Figure.new()
	f.spec = spec
	f.anim = anim
	f.figure_scale = scale
	f.t = t
	f.position = pos
	return f


func _label(text: String, pos: Vector2, size: int, colour: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	_viewport.add_child(label)


func _new_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


func _save(path: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(path)
	print("saved ", path)
	_viewport.queue_free()
