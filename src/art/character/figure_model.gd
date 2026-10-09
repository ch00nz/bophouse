class_name FigureModel
extends RefCounted
## Pose-independent body geometry for one look, built from a render spec and cached.
##
## Model space: facing +x in a 3/4 front view, feet at y = 0, a 168 cm woman's head top at ~-120.
## The torso is two contours (near side +x, far side -x) bent by the body-region parameters that
## BodyShape derives from measurements:
##   bust     -> breast size, projection past the near contour, and how low they sit
##   waist    -> waist pinch
##   hips     -> hip width (both sides) and thigh width
##   glutes   -> the seat curve on the far (back) contour, the readable BBL silhouette
##   shoulders/limb_tone -> shoulder width, arm and calf definition
## Height is a uniform scale applied by the renderer, so proportions never stretch.
## Garments (OutfitPainter) are cut from these same contours, so clothes follow every body.

const LANDMARKS := {
	"shoulder": -93.0, "bust_top": -88.5, "bust": -83.0, "underbust": -78.5, "ribs": -75.0,
	"waist": -69.5, "navel": -66.0, "low_waist": -62.5, "hip": -56.0, "crotch": -49.0,
}
const SHOULDER_Y := -93.0
const CROTCH_Y := -49.0
const HIP_JOINT_Y := -54.0
const THIGH_LENGTH := 25.5
const SHIN_LENGTH := 24.5
const UPPER_ARM := 15.5
const FOREARM := 14.0
const NECK_TOP := Vector2(0.7, -101.5)
## Head centre relative to the top of the neck (head-local origin).
const HEAD_OFFSET := Vector2(0.6, -8.8)
const STEP := 1.0

## Leg half-widths along the leg (t = 0 hip .. 1 ankle): [t, outer, inner].
const LEG_PROFILE := [
	[-0.08, 5.9, 5.0], [0.0, 5.8, 4.9], [0.12, 5.4, 4.4], [0.26, 4.6, 3.7], [0.4, 3.6, 2.9],
	[0.5, 2.75, 2.45], [0.6, 3.15, 2.75], [0.7, 2.95, 2.5], [0.84, 2.05, 1.75], [0.97, 1.5, 1.35], [1.0, 1.45, 1.3],
]

var spec: Dictionary
var key: String = ""
var bust: float
var waist: float
var hips: float
var glutes: float
var shoulders: float
var tone: float
var near_ctrl: PackedVector2Array # (y, x) pairs
var far_ctrl: PackedVector2Array
var torso: PackedVector2Array
var neck: PackedVector2Array
## [[centre, radii], ...] far breast first, near breast last.
var breasts: Array = []
var hip_joints: Array[Vector2] = [] # far, near (before sway)
var shoulder_joints: Array[Vector2] = [] # far, near

static var _cache: Dictionary = {}


## Cached model for a spec (only body-shape keys matter, so outfit/hair changes share a body).
static func for_spec(render_spec: Dictionary) -> FigureModel:
	var key := "%.3f|%.3f|%.3f|%.3f|%.3f|%.3f" % [
		float(render_spec.get("bust", 1.0)), float(render_spec.get("waist", 1.0)), float(render_spec.get("hips", 1.0)),
		float(render_spec.get("glutes", 1.0)), float(render_spec.get("shoulders", 1.0)), float(render_spec.get("limb_tone", 1.0))]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 64:
		_cache.clear()
	var model := FigureModel.new(render_spec)
	model.key = key
	_cache[key] = model
	return model


func _init(render_spec: Dictionary) -> void:
	spec = render_spec
	bust = float(spec.get("bust", 1.0))
	waist = float(spec.get("waist", 1.0))
	hips = float(spec.get("hips", 1.0))
	glutes = float(spec.get("glutes", 1.0))
	shoulders = float(spec.get("shoulders", 1.0))
	tone = float(spec.get("limb_tone", 1.0))
	_build_contours()
	_build_breasts()
	torso = _torso_polygon()
	neck = InkPen.smooth_closed(PackedVector2Array([
		Vector2(-3.4, -93.6), Vector2(-2.5, -98.5), Vector2(-2.3, -104.0), Vector2(3.2, -104.0),
		Vector2(3.2, -98.5), Vector2(4.6, -93.8), Vector2(0.6, -92.6)]), 3)
	hip_joints = [Vector2(-4.0 * hips, HIP_JOINT_Y), Vector2(4.4 * hips, HIP_JOINT_Y)]
	shoulder_joints = [Vector2(-6.4 * shoulders, -91.4), Vector2(7.3 * shoulders, -91.6)]


func _build_contours() -> void:
	var sh := shoulders
	var w := waist
	var h := hips
	var g := glutes
	var hm := h * lerpf(1.0, w, 0.25)
	near_ctrl = PackedVector2Array([
		Vector2(-93.0, 9.3 * sh), Vector2(-90.0, 9.6 * sh), Vector2(-86.0, 9.0 * lerpf(1.0, sh, 0.5)),
		Vector2(-81.0, 8.3 * lerpf(1.0, w, 0.3)), Vector2(-76.0, 7.5 * lerpf(1.0, w, 0.6)), Vector2(-69.5, 6.7 * w),
		Vector2(-64.0, 7.9 * hm), Vector2(-59.5, 9.4 * h), Vector2(-55.0, 10.0 * h), Vector2(-51.0, 9.6 * h), Vector2(-49.0, 9.1 * h),
	])
	far_ctrl = PackedVector2Array([
		Vector2(-93.0, -8.1 * sh), Vector2(-90.0, -8.4 * sh), Vector2(-86.0, -8.0 * lerpf(1.0, sh, 0.5)),
		Vector2(-81.0, -7.4 * lerpf(1.0, w, 0.3)), Vector2(-76.0, -6.7 * lerpf(1.0, w, 0.6)), Vector2(-69.5, -5.9 * w),
		Vector2(-64.0, -7.1 * hm - 0.5 * (g - 1.0)), Vector2(-59.5, -8.3 * h - 1.5 * g + 0.3),
		Vector2(-55.0, -8.6 * h - 2.0 * g), Vector2(-51.0, -8.2 * h - 1.5 * g), Vector2(-49.0, -7.7 * h - 0.9 * g),
	])


func _build_breasts() -> void:
	var b := bust
	var r := 3.9 * pow(maxf(b, 0.2), 0.6)
	var y := LANDMARKS["bust"] + 0.9 * (b - 1.0)
	breasts = [
		[Vector2(-2.6 - 0.4 * (b - 1.0), y + 0.2), Vector2(r * 0.88, r * 0.98)],
		[Vector2(5.6 + 1.6 * (b - 1.0), y), Vector2(r * 1.05, r * 0.98)],
	]


## Hip sway: everything below the waist slides sideways (a contrapposto hip pop); the chest doesn't.
static func sway_at(y: float, sway: float) -> float:
	return sway * smoothstep(-77.0, -57.0, y)


static func shear(points: PackedVector2Array, sway: float) -> PackedVector2Array:
	var out := points.duplicate()
	for i in out.size():
		var p := out[i]
		out[i] = Vector2(p.x + sway * smoothstep(-77.0, -57.0, p.y), p.y)
	return out


## y of a named landmark ("waist", "crotch"...), a number, or a leg fraction "leg:0.3" (below the crotch).
static func landmark(value: Variant, fallback: float = 0.0) -> float:
	if value is float or value is int:
		return float(value)
	var key := str(value)
	if LANDMARKS.has(key):
		return float(LANDMARKS[key])
	if key.begins_with("leg:"):
		return HIP_JOINT_Y + float(key.substr(4)) * (THIGH_LENGTH + SHIN_LENGTH)
	return fallback


## Catmull-Rom interpolation of x for y over (y, x) control points sorted by y.
static func edge_x(points: PackedVector2Array, y: float) -> float:
	var last := points.size() - 1
	if y <= points[0].x:
		return points[0].y
	if y >= points[last].x:
		return points[last].y
	for i in last:
		if y <= points[i + 1].x:
			var p0 := points[maxi(i - 1, 0)]
			var p1 := points[i]
			var p2 := points[i + 1]
			var p3 := points[mini(i + 2, last)]
			var u := (y - p1.x) / maxf(p2.x - p1.x, 0.001)
			return p1.y + 0.5 * u * (p2.y - p0.y + u * (2.0 * p0.y - 5.0 * p1.y + 4.0 * p2.y - p3.y + u * (3.0 * (p1.y - p2.y) + p3.y - p0.y)))
	return points[last].y


func near_x(y: float) -> float:
	return edge_x(near_ctrl, y)


func far_x(y: float) -> float:
	return edge_x(far_ctrl, y)


func _torso_polygon() -> PackedVector2Array:
	var poly := PackedVector2Array([Vector2(-6.6 * shoulders, -94.6), Vector2(-2.8, -95.7), Vector2(3.4, -95.7), Vector2(7.6 * shoulders, -94.8)])
	var y := SHOULDER_Y
	while y < CROTCH_Y:
		poly.append(Vector2(near_x(y), y))
		y += STEP
	poly.append(Vector2(near_x(CROTCH_Y), CROTCH_Y))
	poly.append_array(PackedVector2Array([Vector2(5.4 * hips, -46.6), Vector2(0.6, -45.4), Vector2(-4.4 * hips, -46.6)]))
	y = CROTCH_Y
	while y > SHOULDER_Y:
		poly.append(Vector2(far_x(y), y))
		y -= STEP
	return poly


## Closed band of the torso between y0 and y1, padded by `grow` (fabric thickness).
## Below the crotch the band continues over both thighs as a skirt flaring by `flare`.
func band(y0: float, y1: float, grow: float = 0.0, flare: float = 0.0) -> PackedVector2Array:
	var poly := PackedVector2Array()
	var torso_end := minf(y1, CROTCH_Y)
	var y := y0
	while y < torso_end:
		poly.append(Vector2(near_x(y) + grow, y))
		y += STEP
	poly.append(Vector2(near_x(torso_end) + grow, torso_end))
	if y1 > CROTCH_Y:
		# Skirt: hang from the hip line over both thighs.
		var drop := y1 - CROTCH_Y
		poly.append(Vector2(near_x(CROTCH_Y) + grow + flare + drop * 0.04, y1))
		poly.append(Vector2(far_x(CROTCH_Y) - grow - flare - drop * 0.06, y1))
	else:
		poly.append(Vector2(far_x(torso_end) - grow, torso_end))
	y = torso_end - STEP
	while y > y0:
		poly.append(Vector2(far_x(y) - grow, y))
		y -= STEP
	poly.append(Vector2(far_x(y0) - grow, y0))
	return poly


## Breast shape padded by `grow` (cups and fabric over the bust follow the same curve).
func breast_shape(index: int, grow: float = 0.0, segments: int = 22) -> PackedVector2Array:
	var b: Array = breasts[index]
	return InkPen.ellipse(b[0], (b[1] as Vector2) + Vector2(grow, grow), segments)


## x where the two breasts meet (cleavage line).
func cleavage_x() -> float:
	var far_b: Array = breasts[0]
	var near_b: Array = breasts[1]
	return ((far_b[0] as Vector2).x + (far_b[1] as Vector2).x + (near_b[0] as Vector2).x - (near_b[1] as Vector2).x) * 0.5


# ---------------------------------------------------------------------------
# Limbs (pose-dependent, computed per frame from joints)
# ---------------------------------------------------------------------------

## Leg sample: [centre, outer_half, inner_half, normal] at t (0 hip .. 1 ankle).
static func leg_sample(leg: Dictionary, t: float) -> Array:
	var hip: Vector2 = leg["hip"]
	var knee: Vector2 = leg["knee"]
	var ankle: Vector2 = leg["ankle"]
	var centre: Vector2
	var dir: Vector2
	if t <= 0.5:
		centre = hip.lerp(knee, t / 0.5)
		dir = (knee - hip).normalized()
		if t > 0.38: # smooth the knee joint
			dir = dir.lerp((ankle - knee).normalized(), (t - 0.38) / 0.24).normalized()
	else:
		centre = knee.lerp(ankle, (t - 0.5) / 0.5)
		dir = (ankle - knee).normalized()
		if t < 0.62:
			dir = (knee - hip).normalized().lerp(dir, 0.5 + (t - 0.5) / 0.24).normalized()
	var outer := 0.0
	var inner := 0.0
	for i in LEG_PROFILE.size() - 1:
		var a: Array = LEG_PROFILE[i]
		var b: Array = LEG_PROFILE[i + 1]
		if t <= float(b[0]) or i == LEG_PROFILE.size() - 2:
			var u := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001), 0.0, 1.0)
			outer = lerpf(float(a[1]), float(b[1]), u)
			inner = lerpf(float(a[2]), float(b[2]), u)
			break
	var thigh := float(leg["thigh"])
	var calf := float(leg["calf"])
	var k := clampf(t / 0.5, 0.0, 1.0)
	var s := lerpf(thigh, 1.0, k) if t <= 0.5 else lerpf(1.0, calf, sin(clampf((t - 0.5) / 0.4, 0.0, 1.0) * PI))
	return [centre, outer * s, inner * s, dir.orthogonal()]


## Polygon of a leg from t0 to t1, padded by `grow`. side: +1 near leg (outer = +x), -1 far leg.
## A sharply bent knee would fold the outline over itself, so thigh and shin are merged instead.
static func leg_polygon(leg: Dictionary, t0: float, t1: float, grow: float = 0.0, steps: int = 14) -> PackedVector2Array:
	var thigh_dir := ((leg["knee"] as Vector2) - (leg["hip"] as Vector2)).normalized()
	var shin_dir := ((leg["ankle"] as Vector2) - (leg["knee"] as Vector2)).normalized()
	if t0 < 0.45 and t1 > 0.55 and absf(thigh_dir.angle_to(shin_dir)) > 0.45:
		var merged := Geometry2D.merge_polygons(_leg_strip(leg, t0, 0.52, grow, 8), _leg_strip(leg, 0.48, t1, grow, 8))
		for poly in merged:
			if not Geometry2D.is_polygon_clockwise(poly) == Geometry2D.is_polygon_clockwise(merged[0]) or poly.size() < 3:
				continue
			return poly
	return _leg_strip(leg, t0, t1, grow, steps)


static func _leg_strip(leg: Dictionary, t0: float, t1: float, grow: float, steps: int) -> PackedVector2Array:
	var side := float(leg["side"])
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for i in steps + 1:
		var sample := leg_sample(leg, lerpf(t0, t1, float(i) / steps))
		var centre: Vector2 = sample[0]
		var normal: Vector2 = sample[3]
		a.append(centre + normal * (float(sample[1] if side > 0 else sample[2]) + grow))
		b.append(centre - normal * (float(sample[2] if side > 0 else sample[1]) + grow))
	b.reverse()
	a.append_array(b)
	return a


## Arm polygon: shoulder -> elbow -> wrist with a rounded deltoid cap.
static func arm_polygon(arm: Dictionary, grow: float = 0.0) -> PackedVector2Array:
	var shoulder: Vector2 = arm["shoulder"]
	var elbow: Vector2 = arm["elbow"]
	var wrist: Vector2 = arm["wrist"]
	var t := float(arm["tone"])
	var widths := [3.0 * t, 2.55 * t, 1.95, 1.9, 1.75, 1.25]
	var path := [shoulder, shoulder.lerp(elbow, 0.45), elbow, elbow.lerp(wrist, 0.3), elbow.lerp(wrist, 0.6), wrist]
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in path.size():
		var p: Vector2 = path[i]
		var prev: Vector2 = path[maxi(i - 1, 0)]
		var next: Vector2 = path[mini(i + 1, path.size() - 1)]
		var normal := (next - prev).normalized().orthogonal()
		var half := float(widths[i]) + grow
		left.append(p + normal * half)
		right.append(p - normal * half)
	right.reverse()
	left.append_array(right)
	# Round shoulder cap.
	var cap := InkPen.ellipse(shoulder + (elbow - shoulder).normalized() * 1.2, Vector2(3.2, 3.2) * t + Vector2(grow, grow), 14)
	var merged := Geometry2D.merge_polygons(left, cap)
	return merged[0] if merged.size() > 0 else left


## Two-bone IK: elbow/knee for a joint chain reaching for `target`, bending toward `hint`.
static func solve_joint(root: Vector2, target: Vector2, l1: float, l2: float, hint: Vector2) -> Array:
	var to_target := target - root
	var dist := clampf(to_target.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var dir := to_target.normalized() if to_target.length() > 0.001 else Vector2.DOWN
	var end := root + dir * dist
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var perp := dir.orthogonal()
	if perp.dot(hint) < 0.0:
		perp = -perp
	return [root + dir * a + perp * h, end]
