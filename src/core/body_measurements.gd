class_name BodyMeasurements
extends RefCounted
## A creator's permanent body measurements (cm) and muscle tone. Plain data, kept separate from
## personality stats and styling. Only procedures with measurement deltas (augmentation, BBL)
## change them; hair, clothing, makeup, tattoos and piercings never do.
## BodyShape turns these numbers into appearance tags and renderer body-region parameters.

const CM_PER_INCH := 2.54
const FIELDS: Array[String] = ["height_cm", "bust_cm", "waist_cm", "hips_cm"]

var height_cm: float = 168.0
var bust_cm: float = 96.0
var waist_cm: float = 66.0
var hips_cm: float = 99.0
## 0..1 muscle definition. Separate from the stamina stat (a body trait, not a capability).
var tone: float = 0.35


static func create(height: float, bust: float, waist: float, hips: float, muscle_tone: float = 0.35) -> BodyMeasurements:
	var m := BodyMeasurements.new()
	m.height_cm = height
	m.bust_cm = bust
	m.waist_cm = waist
	m.hips_cm = hips
	m.tone = muscle_tone
	return m


static func from_dict(data: Dictionary) -> BodyMeasurements:
	var m := BodyMeasurements.new()
	m.height_cm = float(data.get("height_cm", m.height_cm))
	m.bust_cm = float(data.get("bust_cm", m.bust_cm))
	m.waist_cm = float(data.get("waist_cm", m.waist_cm))
	m.hips_cm = float(data.get("hips_cm", m.hips_cm))
	m.tone = clampf(float(data.get("tone", m.tone)), 0.0, 1.0)
	return m


func to_dict() -> Dictionary:
	return {"height_cm": height_cm, "bust_cm": bust_cm, "waist_cm": waist_cm, "hips_cm": hips_cm, "tone": tone}


func clone() -> BodyMeasurements:
	return BodyMeasurements.from_dict(to_dict())


func value(field: String) -> float:
	return float(get(field)) if FIELDS.has(field) or field == "tone" else 0.0


## Adds a delta dictionary such as {"bust_cm": 10}. Unknown keys are ignored.
func apply_delta(delta: Dictionary) -> void:
	for key in delta:
		var field := str(key)
		if FIELDS.has(field):
			set(field, float(get(field)) + float(delta[key]))
		elif field == "tone":
			tone = clampf(tone + float(delta[key]), 0.0, 1.0)


## Derived metrics used by data-driven rules (body.json).
func metrics() -> Dictionary:
	var bust_diff := bust_cm - waist_cm
	var hip_diff := hips_cm - waist_cm
	return {
		"height_cm": height_cm, "bust_cm": bust_cm, "waist_cm": waist_cm, "hips_cm": hips_cm, "tone": tone,
		"bust_diff": bust_diff, "hip_diff": hip_diff,
		"curve_cm": (bust_diff + hip_diff) * 0.5,
		"fullness_cm": (bust_cm + hips_cm) * 0.5,
		"frame": (bust_cm + waist_cm + hips_cm) / 3.0 / maxf(height_cm, 1.0),
		"whr": waist_cm / maxf(hips_cm, 1.0),
	}


## "96 / 66 / 99 cm" or "37.8 / 26.0 / 39.0 in".
func bwh_text(imperial: bool = false) -> String:
	if imperial:
		return "%s / %s / %s in" % [_inches(bust_cm), _inches(waist_cm), _inches(hips_cm)]
	return "%d / %d / %d cm" % [roundi(bust_cm), roundi(waist_cm), roundi(hips_cm)]


## "168 cm" or "5'6\"".
func height_text(imperial: bool = false) -> String:
	if imperial:
		var total := roundi(height_cm / CM_PER_INCH)
		return "%d'%d\"" % [total / 12, total % 12]
	return "%d cm" % roundi(height_cm)


## "168 cm  -  96 / 66 / 99 cm".
func summary(imperial: bool = false) -> String:
	return "%s  -  %s" % [height_text(imperial), bwh_text(imperial)]


static func cm_to_inches(cm: float) -> float:
	return cm / CM_PER_INCH


static func _inches(cm: float) -> String:
	return "%.1f" % cm_to_inches(cm)
