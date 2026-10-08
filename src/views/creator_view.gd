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


func setup(creator_state: CreatorState, house_view: HouseView) -> void:
	creator = creator_state
	house = house_view
	_last_earnings = creator.lifetime_earnings
	position = house.logical_to_pixel(creator.position)
	var frames := ArtLibrary.sprite_frames(str(creator.appearance.get("sprite_frames", "")))
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_sprite.centered = false
		add_child(_sprite)


func current_anim() -> String:
	if creator.is_travelling():
		return "walk"
	return str(house.config.activity(creator.activity_id).get("anim", "idle"))


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
		var face := float(house.config.activity(creator.activity_id).get("face", 0))
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
		PlaceholderArt.draw_creator(self, creator.appearance, anim, _t, Vector2.ZERO, _facing, 1.0, lift)
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
	match anim:
		"film":
			PlaceholderArt.draw_rounded_rect(self, Rect2(centre + Vector2(-8, -5), Vector2(13, 10)), Color("333333"), 2)
			draw_colored_polygon(PackedVector2Array([centre + Vector2(5, -2), centre + Vector2(9, -5), centre + Vector2(9, 5), centre + Vector2(5, 2)]), Color("333333"))
			if fmod(_t, 1.0) < 0.6:
				draw_circle(centre + Vector2(-4, -1), 2.0, Color("ff3b3b"))
		"sleep":
			PlaceholderArt.draw_text(self, centre + Vector2(-9, 6), "Zz", 15, Color("5b6ee1"))
		"socialise":
			PlaceholderArt.draw_heart(self, centre + Vector2(0, 1), 18.0 + sin(_t * 5.0) * 2.0, Color("ff4f8b"))
		_:
			PlaceholderArt.draw_text(self, centre + Vector2(-9, 4), "...", 15, Color("555555"))
