class_name CreatorView
extends Node2D
## Visual representation of one creator. Reads the creator's logical position and activity
## every frame; never changes simulation state. Uses SpriteFrames from data when available
## (animations named idle / walk / film / socialise / sleep), otherwise placeholder drawing.

## Generous hit area so creators are easy to tap on touch screens.
const STANDING_HIT := Rect2(-30, -150, 60, 172)
const POPUP_INTERVAL := 1.2
## Character animation frame rates. Moving between rooms is smooth (position needs no redraw);
## only the pose is redrawn, like a sprite sheet, which keeps a full house cheap to draw.
const ANIM_FPS := 15.0
const CALM_FPS := 8.0
const SLEEP_FPS := 3.0

var creator: CreatorState
var house: HouseView
var selected: bool = false

var _t: float = 0.0
var _facing: float = 1.0
var _sprite: AnimatedSprite2D = null
var _last_earnings: float = 0.0
var _popup_timer: float = 0.0
var _spec: Dictionary = {}
var _drawn_state: String = ""
## On the stairs (moving between storeys): painted creators show their back view.
var _on_stairs: bool = false
var _last_logical: Vector2 = Vector2.INF
## Skeletal rigs for painted poses (milestone 5C), created on demand per painted asset.
var _rigs: Dictionary = {}
var _rig_active: IllustratedRig = null
## Static paintings (each with its own recolour material) and an overlay drawn above them
## (speech bubble, name, privacy screen).
var _painted: PaintedLayer
var _overlay: Node2D
var _materials: Dictionary = {} # painted asset name -> recolour material (or null), per look
## Painted sleepers sink this far into the mattress (model units) so they rest on it, not float.
const LYING_SINK := 6.0
## Game animation -> painted rig animation (rigs fall back to their own default motion).
const RIG_ANIMS := {"walk": "walk", "film": "film", "stream": "stream", "celebrate": "stream", "selfie": "selfie",
	"socialise": "selfie", "idle": "idle", "chat": "idle", "argue": "idle"}


func setup(creator_state: CreatorState, house_view: HouseView) -> void:
	creator = creator_state
	house = house_view
	_last_earnings = creator.house_earnings
	refresh_look()
	Game.appearance_changed.connect(_on_appearance_changed)
	Game.recovery_finished.connect(_on_appearance_changed.bind(""))
	position = house.logical_to_pixel(creator.position)
	# Painted sprites are downscaled several times; mipmaps keep them smooth.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_painted = PaintedLayer.new()
	add_child(_painted)
	_overlay = Node2D.new()
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	var frames := ArtLibrary.sprite_frames(str(creator.appearance.get("sprite_frames", "")))
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.centered = false
		add_child(_sprite)


## Re-resolves the layered look (call after appearance changes).
func refresh_look() -> void:
	_spec = Appearance.render_spec(creator, house.config)
	_materials.clear()
	_drawn_state = ""


func _on_appearance_changed(creator_id: String, _item_id: String) -> void:
	if creator_id == creator.id:
		refresh_look()


func current_activity() -> Dictionary:
	return ActivityResolver.resolve(creator, creator.activity_id, house.config, house.state.get_room(creator.room_id))


func current_anim() -> String:
	if creator.is_travelling():
		return "walk"
	var anim := str(current_activity().get("anim", "idle"))
	# Social reactions (chatting, celebrating, bickering) override standing poses.
	if creator.has_reaction(house.state.game_minutes) and not is_lying(anim):
		return str(creator.reaction.get("anim", anim))
	return anim


## Poses performed lying on a bed or sofa (lifted onto the sleep surface).
static func is_lying(anim: String) -> bool:
	return anim == "sleep" or anim == "recline"


func hit_rect() -> Rect2:
	if is_lying(current_anim()):
		var lift := house.sleep_surface_height(creator.room_id)
		return Rect2(-62, -lift - 30, 120, 40)
	return STANDING_HIT


func _process(delta: float) -> void:
	var anim := current_anim()
	var rate := 1.0
	if anim == "walk":
		rate = 0.0 if Game.paused else minf(float(Game.speed), 3.0)
	_t += delta * rate

	var target := house.logical_to_pixel(creator.position)
	if creator.is_travelling():
		if absf(target.x - position.x) > 0.01:
			_facing = signf(target.x - position.x)
	else:
		var face := float(current_activity().get("face", 0))
		var partner := _reaction_partner()
		if partner != null and absf(partner.position.x - creator.position.x) > 0.01:
			face = partner.position.x - creator.position.x # turn to the housemate she's with
		if face != 0.0:
			_facing = signf(face)
	position = target
	if creator.is_travelling() and _last_logical != Vector2.INF:
		var moved := creator.position - _last_logical
		if absf(moved.y) > 0.00001:
			_on_stairs = true
		elif absf(moved.x) > 0.00001:
			_on_stairs = false
	else:
		_on_stairs = false
	_last_logical = creator.position
	_update_rig(anim, rate)

	if _sprite != null:
		if _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
			_sprite.play(anim)
		_sprite.flip_h = _facing < 0.0
		var frame_size := _sprite.sprite_frames.get_frame_texture(_sprite.animation, 0).get_size() if _sprite.sprite_frames.get_frame_count(_sprite.animation) > 0 else Vector2.ZERO
		_sprite.position = Vector2(-frame_size.x * 0.5, -frame_size.y)

	_popup_timer += delta
	if _popup_timer >= POPUP_INTERVAL:
		_popup_timer = 0.0
		var earned := creator.house_earnings - _last_earnings # the house's cut, i.e. what the player gets
		_last_earnings = creator.house_earnings
		if earned >= 1.0:
			house.spawn_floating_text(position + Vector2(0, -135), "+" + Fmt.money(earned), Color("7ae582"))
	var fps := ANIM_FPS if anim == "walk" or anim == "celebrate" else (SLEEP_FPS if anim == "sleep" else CALM_FPS)
	var state := "%d|%s|%d|%s|%s|%s|%s|%s|%s" % [int(_t * fps), anim, int(_facing), selected, creator.room_id, creator.activity_id,
		str(creator.reaction.get("kind", "")), _on_stairs, IllustratedArt.mode]
	if state != _drawn_state:
		_drawn_state = state
		queue_redraw()


func _draw() -> void:
	var anim := current_anim()
	var lying := is_lying(anim)
	var lift := house.sleep_surface_height(creator.room_id) if lying else 0.0
	var props: Array = [] if creator.is_travelling() else current_activity().get("props", [])
	if not lying:
		PlaceholderArt.draw_ellipse(self, Vector2.ZERO, Vector2(17, 4), Color(0, 0, 0, 0.2))
	if selected:
		if lying:
			PlaceholderArt.draw_ellipse_outline(self, Vector2(-4, -lift - 12), Vector2(66, 22), Color("ffd166"), 2.5)
		else:
			PlaceholderArt.draw_ellipse_outline(self, Vector2.ZERO, Vector2(22, 6), Color("ffd166"), 2.5)
	_painted.begin()
	if _sprite == null:
		if _draw_painted(anim, lift):
			# Collab guests are drawn around a painted creator; she keeps her paintings.
			CreatorRenderer.draw_guests(self, _spec, anim, _t, Vector2.ZERO, _facing, 1.0, lift, props,
				house.config.look_option("outfit", "glamour"))
		else:
			CreatorRenderer.draw_guests(self, _spec, anim, _t, Vector2.ZERO, _facing, 1.0, lift, props,
				house.config.look_option("outfit", "glamour"))
			CreatorRenderer.draw(self, _spec, anim, _t, Vector2.ZERO, _facing, 1.0, lift)
	_painted.end()
	_overlay.queue_redraw()


## Above every painting: the closed-set screen, speech bubble and name.
func _draw_overlay() -> void:
	var anim := current_anim()
	var lying := is_lying(anim)
	var lift := house.sleep_surface_height(creator.room_id) if lying else 0.0
	var props: Array = [] if creator.is_travelling() else current_activity().get("props", [])
	CreatorRenderer.draw_screen(_overlay, anim, Vector2.ZERO, 1.0, lift, props)
	_draw_bubble(anim, lift)
	var name_y := 18.0 if not lying else 14.0
	PlaceholderArt.draw_text(_overlay, Vector2(-60, name_y), creator.display_name.get_slice(" ", 0), 13,
		Color.WHITE, 120, HORIZONTAL_ALIGNMENT_CENTER, 4)


## Painted art for this moment ({} = use the procedural renderer): the creator has paintings, art
## mode isn't Classic, and there's a painted pose for the animation.
func _painted_art(anim: String) -> Dictionary:
	if _sprite != null or not IllustratedArt.use_art(_spec):
		return {}
	return IllustratedArt.sprite(_spec, anim, _on_stairs)


func _painted_scale() -> float:
	var house_scale := float((_spec.get("illustrated", {}) as Dictionary).get("house_scale", 1.0))
	return float(_spec.get("height_scale", 1.0)) * house_scale


## Recolour material for a painted asset under her current look (hair colour), cached per look.
func _material(art: Dictionary) -> Material:
	var name := str(art.get("name", ""))
	if not _materials.has(name):
		_materials[name] = IllustratedArt.material_for(_spec, art)
	return _materials[name]


## Shows the skeletal rig for the current painted pose (idle breathing, walking strides, filming,
## livestream waves, selfies), hiding the others. Rigs animate every frame on their own.
func _update_rig(anim: String, rate: float) -> void:
	var art := _painted_art(anim)
	var name := str(art.get("name", ""))
	var rigs_path := IllustratedArt.rigs_path(_spec)
	var rig: IllustratedRig = null
	if not name.is_empty() and IllustratedRig.has_rig(rigs_path, name):
		rig = _rigs.get(name)
		if rig == null:
			rig = IllustratedRig.create(art, art["full_size"], rigs_path)
			add_child(rig)
			move_child(_overlay, -1) # bubble and name stay on top
			_rigs[name] = rig
		var s := float(art["units_per_px"]) * _painted_scale()
		var mirror := false
		if anim == "walk" and not _on_stairs:
			mirror = _facing * float((_spec.get("illustrated", {}) as Dictionary).get("walk_facing", 1)) < 0.0
		rig.scale = Vector2(-s if mirror else s, s)
		rig.set_paint_material(_material(art))
		rig.play(str(RIG_ANIMS.get(anim, "idle")), rate if anim == "walk" else 1.0)
	for key: String in _rigs:
		(_rigs[key] as IllustratedRig).visible = _rigs[key] == rig
	if rig != _rig_active:
		_rig_active = rig
		queue_redraw()


## Painted art without a rig: the back view on the stairs (with a step bounce), the lying pose on
## the bed, and painted outfits standing in for unpainted poses. Returns false when the procedural
## renderer should draw instead (no painting for this moment). Rigged poses are drawn by their rig.
func _draw_painted(anim: String, lift: float) -> bool:
	if _rig_active != null and _rig_active.visible:
		return true
	var art := _painted_art(anim)
	if art.is_empty():
		return false
	var scale := _painted_scale()
	if str(art.get("kind", "")) == "lying":
		# Resting on the mattress, centred on the bed spot like the procedural sleeper; slow breathing.
		_painted.add_figure(art, _material(art), Vector2(-4.0, -lift + LYING_SINK), scale, false, sin(_t * 1.4) * 0.012)
		return true
	var origin := Vector2.ZERO
	var mirror := false
	if anim == "walk":
		origin.y = -absf(sin(_t * 9.0)) * 1.6
		if not _on_stairs:
			mirror = _facing * float((_spec.get("illustrated", {}) as Dictionary).get("walk_facing", 1)) < 0.0
	_painted.add_figure(art, _material(art), origin, scale, mirror, sin(_t * 2.0) * 0.004 if anim != "walk" else 0.0)
	return true


func _reaction_partner() -> CreatorState:
	if not creator.has_reaction(house.state.game_minutes):
		return null
	return house.state.get_creator(str(creator.reaction.get("with", "")))


func _draw_bubble(anim: String, lift: float) -> void:
	if anim == "walk":
		return
	var bubble := str(current_activity().get("bubble", "dots"))
	if creator.has_reaction(house.state.game_minutes):
		bubble = str(creator.reaction.get("kind", bubble))
	var centre := Vector2(10, -140) if not is_lying(anim) else Vector2(-30, -lift - 58)
	if anim == "sleep" and str(_painted_art(anim).get("kind", "")) == "lying":
		centre = Vector2(-46, -lift - 70) # clear of the painted sleeper's face
	centre.y += sin(_t * 2.0) * 1.5
	_overlay.draw_colored_polygon(PackedVector2Array([centre + Vector2(-5, 9), centre + Vector2(3, 10), centre + Vector2(-6, 18)]), Color.WHITE)
	_overlay.draw_circle(centre, 13.0, Color.WHITE)
	_overlay.draw_arc(centre, 13.0, 0, TAU, 24, Color(0, 0, 0, 0.25), 1.5, true)
	# Bubble icon comes from data (activity or content), so new content types need no code.
	match bubble:
		"chat":
			PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre + Vector2(-9, -7), Vector2(12, 8)), Color("9d4edd"), 3)
			PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre + Vector2(-2, -1), Vector2(12, 8)), Color("ff7ab8"), 3)
			for i in 3:
				_overlay.draw_circle(centre + Vector2(1.5 + i * 3.0, 3), 0.9 if fmod(_t * 3.0, 3.0) > i else 0.5, Color.WHITE)
		"party":
			_overlay.draw_colored_polygon(PackedVector2Array([centre + Vector2(-7, 8), centre + Vector2(-2, -6), centre + Vector2(4, 4)]), Color("ffb703"))
			for i in 5:
				var a := _t * 2.0 + i * 1.3
				_overlay.draw_circle(centre + Vector2(cos(a) * 7.0, sin(a) * 6.0 - 2.0), 1.4, Color.from_hsv(fmod(i * 0.21, 1.0), 0.7, 1.0))
		"gossip":
			PlaceholderArt.draw_text(_overlay, centre + Vector2(-10, 5), "psst", 10, Color("6a4c93"))
		"angry":
			for sign_x: float in [-1.0, 1.0]:
				_overlay.draw_line(centre + Vector2(sign_x * 2.0, -6), centre + Vector2(sign_x * 7.0, -1), Color("e63946"), 2.5)
				_overlay.draw_line(centre + Vector2(sign_x * 2.0, 6), centre + Vector2(sign_x * 7.0, 1), Color("e63946"), 2.5)
		"camera":
			PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre + Vector2(-8, -5), Vector2(13, 10)), Color("333333"), 2)
			_overlay.draw_colored_polygon(PackedVector2Array([centre + Vector2(5, -2), centre + Vector2(9, -5), centre + Vector2(9, 5), centre + Vector2(5, 2)]), Color("333333"))
			if fmod(_t, 1.0) < 0.6:
				_overlay.draw_circle(centre + Vector2(-4, -1), 2.0, Color("ff3b3b"))
		"phone":
			PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre + Vector2(-5, -8), Vector2(10, 16)), Color("333333"), 2)
			_overlay.draw_rect(Rect2(centre + Vector2(-3.5, -6), Vector2(7, 11)), Color("7fd3ff"))
			PlaceholderArt.draw_heart(_overlay, centre + Vector2(0, -0.5), 7.0 + sin(_t * 5.0), Color("ff4f8b"))
		"star":
			PlaceholderArt.draw_star(_overlay, centre, 9.0 + sin(_t * 4.0), Color("ffb703"))
		"lock":
			_overlay.draw_arc(centre + Vector2(0, -2), 4.5, PI, TAU, 10, Color("6a4c93"), 2.5)
			PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre + Vector2(-6, -2), Vector2(12, 9)), Color("6a4c93"), 2)
		"live":
			PlaceholderArt.draw_rounded_rect(_overlay, Rect2(centre + Vector2(-12, -6), Vector2(24, 12)), Color("e63946"), 3)
			PlaceholderArt.draw_text(_overlay, centre + Vector2(-12, 4), "LIVE", 9, Color.WHITE, 24, HORIZONTAL_ALIGNMENT_CENTER)
		"heal":
			_overlay.draw_rect(Rect2(centre + Vector2(-2, -7), Vector2(4, 14)), Color("2ec4b6"))
			_overlay.draw_rect(Rect2(centre + Vector2(-7, -2), Vector2(14, 4)), Color("2ec4b6"))
		"mail":
			_overlay.draw_rect(Rect2(centre + Vector2(-8, -5), Vector2(16, 11)), Color("ffd166"))
			_overlay.draw_polyline(PackedVector2Array([centre + Vector2(-8, -5), centre + Vector2(0, 1), centre + Vector2(8, -5)]), Color("b5838d"), 1.5)
			PlaceholderArt.draw_heart(_overlay, centre + Vector2(5, 4), 7.0, Color("ff4f8b"))
		"collab":
			PlaceholderArt.draw_heart(_overlay, centre + Vector2(-3.5, 0), 11.0, Color("ff4f8b"))
			PlaceholderArt.draw_heart(_overlay, centre + Vector2(3.5, 1), 11.0 + sin(_t * 5.0), Color("9d4edd"))
		"zz":
			PlaceholderArt.draw_text(_overlay, centre + Vector2(-9, 6), "Zz", 15, Color("5b6ee1"))
		"heart":
			PlaceholderArt.draw_heart(_overlay, centre + Vector2(0, 1), 18.0 + sin(_t * 5.0) * 2.0, Color("ff4f8b"))
		_:
			PlaceholderArt.draw_text(_overlay, centre + Vector2(-9, 4), "...", 15, Color("555555"))
