class_name FigurePoses
extends RefCounted
## Pose library. Every animation is expressed as joint targets in model space (feet at 0, facing +x):
## where the ankles and wrists go, which way elbows/knees bend, how far the hips sway, the head
## tilt, hand shapes and the facial expression. FigureModel's two-bone IK turns targets into limbs,
## so poses work for every body (tall, petite, curvy) without per-creator animation.
##
## Anims: idle, walk, film, selfie, stream, socialise, chat, celebrate, argue, sleep, recline.
## "film" cycles three glamour poses; transitions blend smoothly.

const GROUND := -4.5
const FAR := 0
const NEAR := 1


static func pose(anim: String, t: float) -> Dictionary:
	match anim:
		"walk":
			return _walk(t)
		"film":
			return _cycle([_pose_hair_and_hip(t), _pose_hands_on_hips(t), _pose_blow_kiss(t)], t, 2.4)
		"selfie":
			return _selfie(t)
		"stream":
			return _stream(t)
		"socialise":
			return _socialise(t)
		"chat":
			return _chat(t)
		"celebrate":
			return _celebrate(t)
		"argue":
			return _argue(t)
		"sleep":
			return _sleep(t)
		"recline":
			return _recline(t)
		"showcase": # portrait hero loop: idle, posing and a playful wink
			return _cycle([_idle(t), _pose_hair_and_hip(t), _pose_hands_on_hips(t), _pose_blow_kiss(t)], t, 3.2)
	return _idle(t)


static func _base() -> Dictionary:
	return {
		"sway": 0.0, "bob": 0.0, "head_tilt": 0.04, "expression": "",
		"ankles": [Vector2(-2.6, GROUND), Vector2(2.4, GROUND)],
		"wrists": [Vector2(-9.4, -64.5), Vector2(10.6, -64.0)],
		"elbows": [Vector2(-1, 0.3), Vector2(1, 0.3)],
		"knees": [Vector2(1, 0), Vector2(1, 0)],
		"hands": ["relaxed", "relaxed"],
		"phone": false, "blanket": false, "lying": false, "hair_swing": 0.0,
	}


# ---------------------------------------------------------------------------
# Standing
# ---------------------------------------------------------------------------

## Contrapposto: weight on the near leg, hip popped toward the camera side, a hand on the hip.
static func _idle(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 1.6
	p["bob"] = sin(t * 2.2) * 0.35
	p["head_tilt"] = 0.07 + sin(t * 0.9) * 0.025
	p["ankles"] = [Vector2(-3.4, GROUND - 1.0), Vector2(2.6, GROUND)]
	p["wrists"] = [Vector2(-9.6, -64.0), Vector2(11.2, -65.5)]
	p["elbows"] = [Vector2(-1, 0.4), Vector2(1, 0.15)]
	p["hands"] = ["relaxed", "hip"]
	p["hair_swing"] = sin(t * 1.3) * 0.3
	return p


static func _walk(t: float) -> Dictionary:
	var p := _base()
	var phase := t * 9.0
	var s := sin(phase)
	var c := cos(phase)
	p["sway"] = 0.9 * s
	p["bob"] = -absf(c) * 1.3 + 0.6
	p["head_tilt"] = 0.03
	p["ankles"] = [Vector2(-0.8 - 7.0 * s, GROUND - 2.4 * maxf(0.0, -c)), Vector2(1.6 + 7.0 * s, GROUND - 2.4 * maxf(0.0, c))]
	p["wrists"] = [Vector2(-8.6 + 5.5 * s, -64.5), Vector2(9.8 - 5.5 * s, -64.5)]
	p["elbows"] = [Vector2(-1, 0.6), Vector2(-0.3, 1)]
	p["hair_swing"] = -c * 0.9
	p["expression"] = "smile"
	return p


## Hand behind her head, other hand on the hip, big hip pop.
static func _pose_hair_and_hip(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 2.4
	p["bob"] = sin(t * 2.0) * 0.3
	p["head_tilt"] = -0.06
	p["ankles"] = [Vector2(-4.4, GROUND - 1.4), Vector2(2.8, GROUND)]
	p["wrists"] = [Vector2(-9.2, -65.0), Vector2(1.2, -114.0)]
	p["elbows"] = [Vector2(-1, 0.1), Vector2(1, -0.6)]
	p["hands"] = ["hip", "hidden"]
	p["expression"] = "sultry"
	p["hair_swing"] = sin(t * 1.6) * 0.4
	return p


static func _pose_hands_on_hips(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = -1.4
	p["bob"] = sin(t * 2.0) * 0.3
	p["head_tilt"] = 0.11
	p["ankles"] = [Vector2(-4.0, GROUND), Vector2(4.0, GROUND - 1.2)]
	p["wrists"] = [Vector2(-9.4, -65.0), Vector2(11.4, -65.5)]
	p["elbows"] = [Vector2(-1, 0.1), Vector2(1, 0.1)]
	p["hands"] = ["hip", "hip"]
	p["knees"] = [Vector2(1, 0), Vector2(1, 0)]
	p["expression"] = "smirk"
	return p


## Blows a kiss to the camera, then winks.
static func _pose_blow_kiss(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 1.9
	p["bob"] = sin(t * 2.0) * 0.3
	p["head_tilt"] = 0.13
	p["ankles"] = [Vector2(-3.0, GROUND - 1.2), Vector2(2.6, GROUND)]
	p["wrists"] = [Vector2(-9.2, -65.0), Vector2(13.4, -100.0)]
	p["elbows"] = [Vector2(-1, 0.1), Vector2(0.6, 1)]
	p["hands"] = ["hip", "open"]
	p["expression"] = "kiss" if fmod(t, 2.4) < 1.2 else "wink"
	return p


static func _selfie(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 1.4
	p["bob"] = sin(t * 2.0) * 0.3
	p["head_tilt"] = 0.15
	p["ankles"] = [Vector2(-3.2, GROUND - 1.0), Vector2(2.6, GROUND)]
	p["wrists"] = [Vector2(-9.2, -65.0), Vector2(16.0, -109.0)]
	p["elbows"] = [Vector2(-1, 0.1), Vector2(0.4, 1)]
	p["hands"] = ["hip", "phone"]
	p["phone"] = true
	p["expression"] = "kiss" if fmod(t, 4.0) < 2.0 else "smile"
	return p


static func _stream(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 1.0
	p["bob"] = sin(t * 2.4) * 0.35
	p["head_tilt"] = 0.05
	p["wrists"] = [Vector2(-9.4, -65.0) if fmod(t, 3.0) < 2.0 else Vector2(-3.0, -80.0),
		Vector2(15.0 + sin(t * 6.0) * 2.5, -98.0 + cos(t * 6.0) * 2.5)]
	p["elbows"] = [Vector2(-1, 0.4), Vector2(1, 0.6)]
	p["hands"] = ["hip" if fmod(t, 3.0) < 2.0 else "relaxed", "open"]
	p["expression"] = "talk"
	return p


static func _socialise(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 1.2
	p["bob"] = sin(t * 2.0) * 0.3
	p["head_tilt"] = 0.2
	p["ankles"] = [Vector2(-3.2, GROUND - 1.0), Vector2(2.6, GROUND)]
	p["wrists"] = [Vector2(-9.6, -64.0), Vector2(9.0, -79.0)]
	p["elbows"] = [Vector2(-1, 0.4), Vector2(0.5, 1)]
	p["hands"] = ["relaxed", "phone"]
	p["phone"] = true
	p["expression"] = "smile"
	return p


static func _chat(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = 1.2
	p["bob"] = sin(t * 2.0) * 0.3
	p["head_tilt"] = 0.06 + sin(t * 1.7) * 0.04
	p["wrists"] = [Vector2(-9.2, -65.0), Vector2(14.0 + sin(t * 4.0) * 2.5, -79.0 + cos(t * 3.0) * 3.5)]
	p["elbows"] = [Vector2(-1, 0.1), Vector2(0.4, 1)]
	p["hands"] = ["hip", "open"]
	p["expression"] = "talk"
	return p


static func _celebrate(t: float) -> Dictionary:
	var p := _base()
	p["bob"] = -absf(sin(t * 7.0)) * 3.5
	p["head_tilt"] = -0.05
	p["ankles"] = [Vector2(-3.0, GROUND - 1.5), Vector2(3.0, GROUND - 1.5)]
	p["wrists"] = [Vector2(-8.0, -122.0 + cos(t * 7.0) * 2.5), Vector2(10.0, -123.0 + sin(t * 7.0) * 2.5)]
	p["elbows"] = [Vector2(-1, 0), Vector2(1, 0)]
	p["hands"] = ["open", "open"]
	p["expression"] = "laugh"
	p["hair_swing"] = sin(t * 7.0) * 1.0
	return p


static func _argue(t: float) -> Dictionary:
	var p := _base()
	p["sway"] = -1.4
	p["bob"] = sin(t * 3.0) * 0.3
	p["head_tilt"] = -0.08
	p["ankles"] = [Vector2(-4.0, GROUND), Vector2(3.6, GROUND)]
	var pointing := fmod(t, 2.4) >= 1.2
	p["wrists"] = [Vector2(-9.4, -65.0), Vector2(19.0, -89.0) if pointing else Vector2(11.4, -65.5)]
	p["elbows"] = [Vector2(-1, 0.1), Vector2(0.3, 1) if pointing else Vector2(1, 0.1)]
	p["hands"] = ["hip", "point" if pointing else "hip"]
	p["expression"] = "annoyed"
	return p


# ---------------------------------------------------------------------------
# Lying (the renderer rotates the figure onto the bed; +x is "up" once rotated)
# ---------------------------------------------------------------------------

static func _sleep(t: float) -> Dictionary:
	var p := _base()
	p["lying"] = true
	p["blanket"] = true
	p["bob"] = sin(t * 1.2) * 0.25
	p["head_tilt"] = 0.0
	p["ankles"] = [Vector2(-1.4, GROUND), Vector2(1.4, GROUND)]
	p["wrists"] = [Vector2(-7.0, -66.0), Vector2(9.5, -70.0)]
	p["elbows"] = [Vector2(-1, 0.2), Vector2(1, 0.2)]
	p["expression"] = "sleep"
	return p


static func _recline(t: float) -> Dictionary:
	var p := _base()
	p["lying"] = true
	p["sway"] = 0.0
	p["head_tilt"] = -0.12 + sin(t * 1.1) * 0.03
	# Propped on the far elbow, near knee raised.
	p["ankles"] = [Vector2(1.2, GROUND), Vector2(1.0, -14.0)]
	p["knees"] = [Vector2(1, 0), Vector2(1, 0)]
	var playful := fmod(t, 5.0) >= 3.0
	p["wrists"] = [Vector2(-7.0, -112.0), Vector2(4.0, -112.0) if playful else Vector2(11.0, -64.0)]
	p["elbows"] = [Vector2(-1, 0.3), Vector2(1, -0.4) if playful else Vector2(1, 0.2)]
	p["hands"] = ["hidden", "hidden" if playful else "hip"]
	p["expression"] = "sultry" if not playful else "wink"
	return p


# ---------------------------------------------------------------------------
# Blending
# ---------------------------------------------------------------------------

## Holds each pose for `hold` seconds, blending into the next over the first 0.45 s.
static func _cycle(poses: Array, t: float, hold: float) -> Dictionary:
	var count := poses.size()
	var k := fmod(t, hold * count)
	var index := int(k / hold) % count
	var local := k - index * hold
	var current: Dictionary = poses[index]
	if local >= 0.45:
		return current
	var previous: Dictionary = poses[(index - 1 + count) % count]
	return blend(previous, current, smoothstep(0.0, 1.0, local / 0.45))


static func blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var result := {}
	for key in b:
		var va: Variant = a.get(key, b[key])
		var vb: Variant = b[key]
		if vb is float and va is float:
			result[key] = lerpf(va, vb, u)
		elif vb is Vector2 and va is Vector2:
			result[key] = (va as Vector2).lerp(vb, u)
		elif vb is Array and va is Array and (vb as Array).size() == (va as Array).size():
			var mixed := []
			for i in (vb as Array).size():
				var ea: Variant = (va as Array)[i]
				var eb: Variant = (vb as Array)[i]
				if ea is Vector2 and eb is Vector2:
					mixed.append((ea as Vector2).lerp(eb, u))
				else:
					mixed.append(eb if u >= 0.5 else ea)
			result[key] = mixed
		else:
			result[key] = vb if u >= 0.5 else va
	return result
