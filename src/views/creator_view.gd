class_name CreatorView
extends Node2D
## Visual representation of one creator. Reads the creator's logical position and activity
## every frame; never changes simulation state. Uses SpriteFrames from data when available
## (animations named idle / walk / film / socialise / sleep), otherwise placeholder drawing.

## Generous hit area so creators are easy to tap on touch screens.
const STANDING_HIT := Rect2(-30, -150, 60, 172)
const POPUP_INTERVAL := 1.2

var creator: CreatorState
var house: HouseView
var selected: bool = false

var _t: float = 0.0
var _facing: float = 1.0
var _sprite: AnimatedSprite2D = null
var _last_earnings: float = 0.0
var _popup_timer: float = 0.0
var _spec: Dictionary = {}


func setup(creator_state: CreatorState, house_view: HouseView) -> void:
	creator = creator_state
	house = house_view
	_last_earnings = creator.lifetime_earnings
	refresh_look()
	Game.appearance_changed.connect(_on_appearance_changed)
	Game.recovery_finished.connect(_on_appearance_changed.bind(""))
	position = house.logical_to_pixel(creator.position)
	var frames := ArtLibrary.sprite_frames(str(creator.appearance.get("sprite_frames", "")))
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.centered = false
		add_child(_sprite)


## Re-resolves the layered look (call after appearance changes).
func refresh_look() -> void:
	_spec = Appearance.render_spec(creator, house.config)


func _on_appearance_changed(creator_id: String, _item_id: String) -> void:
	if creator_id == creator.id:
		refresh_look()


func current_activity() -> Dictionary:
	return ActivityResolver.resolve(creator, creator.activity_id, house.config)


func current_anim() -> String:
	if creator.is_travelling():
		return "walk"
	return str(current_activity().get("anim", "idle"))


func hit_rect() -> Rect2:
	if current_anim() == "sleep":
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
		if face != 0.0:
			_facing = signf(face)
	position = target

	if _sprite != null:
		if _sprite.sprite_frames.has_animation(anim) and _sprite.animation != anim:
			_sprite.play(anim)
		_sprite.flip_h = _facing < 0.0
		var frame_size := _sprite.sprite_frames.get_frame_texture(_sprite.animation, 0).get_size() if _sprite.sprite_frames.get_frame_count(_sprite.animation) > 0 else Vector2.ZERO
		_sprite.position = Vector2(-frame_size.x * 0.5, -frame_size.y)

	_popup_timer += delta
	if _popup_timer >= POPUP_INTERVAL:
		_popup_timer = 0.0
		var earned := creator.lifetime_earnings - _last_earnings
		_last_earnings = creator.lifetime_earnings
		if earned >= 1.0:
			house.spawn_floating_text(position + Vector2(0, -135), "+" + Fmt.money(earned), Color("7ae582"))
	queue_redraw()


func _draw() -> void:
	var anim := current_anim()
	var lift := house.sleep_surface_height(creator.room_id) if anim == "sleep" else 0.0
	if anim != "sleep":
		PlaceholderArt.draw_ellipse(self, Vector2.ZERO, Vector2(17, 4), Color(0, 0, 0, 0.2))
	if selected:
		if anim == "sleep":
			PlaceholderArt.draw_ellipse_outline(self, Vector2(-4, -lift - 12), Vector2(66, 22), Color("ffd166"), 2.5)
		else:
			PlaceholderArt.draw_ellipse_outline(self, Vector2.ZERO, Vector2(22, 6), Color("ffd166"), 2.5)
	if _sprite == null:
		CreatorRenderer.draw(self, _spec, anim, _t, Vector2.ZERO, _facing, 1.0, lift)
	_draw_bubble(anim, lift)
	var name_y := 18.0 if anim != "sleep" else 14.0
	PlaceholderArt.draw_text(self, Vector2(-60, name_y), creator.display_name.get_slice(" ", 0), 13,
		Color.WHITE, 120, HORIZONTAL_ALIGNMENT_CENTER, 4)


func _draw_bubble(anim: String, lift: float) -> void:
	if anim == "walk":
		return
	var centre := Vector2(10, -140) if anim != "sleep" else Vector2(-30, -lift - 58)
	centre.y += sin(_t * 2.0) * 1.5
	draw_colored_polygon(PackedVector2Array([centre + Vector2(-5, 9), centre + Vector2(3, 10), centre + Vector2(-6, 18)]), Color.WHITE)
	draw_circle(centre, 13.0, Color.WHITE)
	draw_arc(centre, 13.0, 0, TAU, 24, Color(0, 0, 0, 0.25), 1.5, true)
	# Bubble icon comes from data (activity or content), so new content types need no code.
	match str(current_activity().get("bubble", "dots")):
		"camera":
			PlaceholderArt.draw_rounded_rect(self, Rect2(centre + Vector2(-8, -5), Vector2(13, 10)), Color("333333"), 2)
			draw_colored_polygon(PackedVector2Array([centre + Vector2(5, -2), centre + Vector2(9, -5), centre + Vector2(9, 5), centre + Vector2(5, 2)]), Color("333333"))
			if fmod(_t, 1.0) < 0.6:
				draw_circle(centre + Vector2(-4, -1), 2.0, Color("ff3b3b"))
		"phone":
			PlaceholderArt.draw_rounded_rect(self, Rect2(centre + Vector2(-5, -8), Vector2(10, 16)), Color("333333"), 2)
			draw_rect(Rect2(centre + Vector2(-3.5, -6), Vector2(7, 11)), Color("7fd3ff"))
			PlaceholderArt.draw_heart(self, centre + Vector2(0, -0.5), 7.0 + sin(_t * 5.0), Color("ff4f8b"))
		"star":
			PlaceholderArt.draw_star(self, centre, 9.0 + sin(_t * 4.0), Color("ffb703"))
		"lock":
			draw_arc(centre + Vector2(0, -2), 4.5, PI, TAU, 10, Color("6a4c93"), 2.5)
			PlaceholderArt.draw_rounded_rect(self, Rect2(centre + Vector2(-6, -2), Vector2(12, 9)), Color("6a4c93"), 2)
		"live":
			PlaceholderArt.draw_rounded_rect(self, Rect2(centre + Vector2(-12, -6), Vector2(24, 12)), Color("e63946"), 3)
			PlaceholderArt.draw_text(self, centre + Vector2(-12, 4), "LIVE", 9, Color.WHITE, 24, HORIZONTAL_ALIGNMENT_CENTER)
		"heal":
			draw_rect(Rect2(centre + Vector2(-2, -7), Vector2(4, 14)), Color("2ec4b6"))
			draw_rect(Rect2(centre + Vector2(-7, -2), Vector2(14, 4)), Color("2ec4b6"))
		"mail":
			draw_rect(Rect2(centre + Vector2(-8, -5), Vector2(16, 11)), Color("ffd166"))
			draw_polyline(PackedVector2Array([centre + Vector2(-8, -5), centre + Vector2(0, 1), centre + Vector2(8, -5)]), Color("b5838d"), 1.5)
			PlaceholderArt.draw_heart(self, centre + Vector2(5, 4), 7.0, Color("ff4f8b"))
		"collab":
			PlaceholderArt.draw_heart(self, centre + Vector2(-3.5, 0), 11.0, Color("ff4f8b"))
			PlaceholderArt.draw_heart(self, centre + Vector2(3.5, 1), 11.0 + sin(_t * 5.0), Color("9d4edd"))
		"zz":
			PlaceholderArt.draw_text(self, centre + Vector2(-9, 6), "Zz", 15, Color("5b6ee1"))
		"heart":
			PlaceholderArt.draw_heart(self, centre + Vector2(0, 1), 18.0 + sin(_t * 5.0) * 2.0, Color("ff4f8b"))
		_:
			PlaceholderArt.draw_text(self, centre + Vector2(-9, 4), "...", 15, Color("555555"))
