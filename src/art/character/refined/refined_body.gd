class_name RefinedBody
extends RefCounted
## Refined-style skin (RenderStyle prototype): a warm palette with peachy-rose shadows instead of
## violet ones, outlines in a deep tone of the skin instead of plum ink, soft gradient shading (the
## pen's `soft` mode) and sculpting highlights on the torso and limbs. Works for any skin colour:
## every tone is derived from the spec's skin.


## Deep, warm tone of the skin used for its outline (reads as a line at sprite size, softer than ink).
static func outline_of(skin: Color) -> Color:
	return skin.darkened(0.62).lerp(Color("4a1a22"), 0.35)


## Warm shadow: toward a rosy brown rather than violet grey (keeps skin luminous).
static func warm_shadow(skin: Color, amount: float = 0.22) -> Color:
	return Color(skin.lerp(Color(0.62, 0.24, 0.26), amount).darkened(amount * 0.35), skin.a)


## BodyPainter palette overrides for the refined style.
static func palette(skin: Color) -> Dictionary:
	return {
		"skin": skin, "lit": InkPen.light_of(skin, 0.1), "mid": skin.lerp(warm_shadow(skin, 0.2), 0.3),
		"shadow": Color(warm_shadow(skin, 0.3), 0.9), "light": Color(InkPen.light_of(skin, 0.45), 0.8),
		"line": skin.lerp(outline_of(skin), 0.55), "back": warm_shadow(skin, 0.1), "back_mid": warm_shadow(skin, 0.2),
		"ink": outline_of(skin), "refined": true,
	}


## Extra torso sculpting (recorded with the torso detail layer): collarbone and shoulder light,
## the soft top of the bust, a lit belly and hip bone, and shadow under the ribs.
static func bake_torso_extra(pen: InkPen, model: FigureModel, c: Dictionary) -> void:
	if not pen.lod(1.4):
		return
	var light: Color = c["light"]
	var shadow: Color = c["shadow"]
	var waist_mid := (model.near_x(-70.0) + model.far_x(-70.0)) * 0.5
	# Under the chin.
	pen.fill_radial(Vector2(0.9, -99.6), Vector2(2.9, 1.8), Color(shadow, 0.6))
	pen.fill_radial(Vector2(3.6, -91.2), Vector2(4.2, 1.1), Color(light, 0.45))
	pen.fill_radial(Vector2(6.8 * model.shoulders, -92.4), Vector2(1.8, 1.2), Color(light, 0.5))
	for i in 2:
		var b: Array = model.breasts[i]
		var centre: Vector2 = b[0]
		var radii: Vector2 = b[1]
		pen.fill_radial(centre + Vector2(radii.x * 0.25, -radii.y * 0.35), radii * 0.6, Color(light, 0.5 if i == 1 else 0.3))
		pen.fill_radial(centre + Vector2(0.0, radii.y * 0.95), Vector2(radii.x * 0.9, radii.y * 0.3), Color(shadow, 0.45))
	pen.fill_radial(Vector2(waist_mid + 2.2, -67.0), Vector2(2.6, 4.6), Color(light, 0.4))
	pen.fill_radial(Vector2(model.near_x(-58.0) - 1.6, -58.5), Vector2(1.6, 2.2), Color(light, 0.45))
	pen.fill_radial(Vector2(model.far_x(-74.0) + 1.8, -74.0), Vector2(2.0, 5.0), Color(shadow, 0.35))


## Soft knee and shin highlights on the near leg (live, follows the pose).
static func leg_detail(pen: InkPen, leg: Dictionary, c: Dictionary) -> void:
	var knee := FigureModel.leg_sample(leg, 0.5)
	var centre: Vector2 = knee[0]
	var normal: Vector2 = knee[3]
	var angle := normal.angle()
	pen.fill_radial(centre + normal * 0.6 + Vector2(0, -0.3), Vector2(1.1, 1.4), Color(c["light"], 0.6), angle, 10)
	var thigh := FigureModel.leg_sample(leg, 0.22)
	pen.fill_radial((thigh[0] as Vector2) + (thigh[3] as Vector2) * 1.2, Vector2(1.6, 4.0), Color(c["light"], 0.4), angle, 10)
	var shin := FigureModel.leg_sample(leg, 0.72)
	pen.fill_radial((shin[0] as Vector2) + (shin[3] as Vector2) * 0.7, Vector2(0.8, 3.4), Color(c["light"], 0.45), angle, 10)
