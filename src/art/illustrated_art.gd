class_name IllustratedArt
extends RefCounted
## Painted character art (milestone 5B prototype). Reads a creator's entry from
## data/illustrated_art.json (carried in the render spec as "illustrated") and the asset manifest the
## art pipeline generated (art_pipeline/extract_sheets.py), and draws the matching painting:
##   full_body(spec)   hero image for her current (or a previewed) painted outfit
##   sprite(spec, ...) house sprite for an animation ({} = no painted pose: use the procedural renderer)
##   bust(spec, mood)  expression portrait
## The render spec's "art_cover" (Appearance.illustrated_coverage) says whether the paintings depict
## her current look; in the default "auto" mode anything they don't show (procedures, other hair,
## tattoos, unpainted outfits) falls back to the procedural renderer. Images are never stretched to
## fake body changes.

const MODES: Array[String] = ["auto", "always", "off"]
const MODE_LABELS := {"auto": "Auto", "always": "Always", "off": "Off"}

## Art mode from the player's settings: auto (only when it matches), always (review), off.
static var mode: String = "auto"
static var _manifests: Dictionary = {}


static func has_art(spec: Dictionary) -> bool:
	return not (spec.get("illustrated", {}) as Dictionary).is_empty()


## True when her painting should be drawn instead of the procedural figure.
static func use_art(spec: Dictionary) -> bool:
	if mode == "off" or not has_art(spec):
		return false
	return mode == "always" or bool((spec.get("art_cover", {}) as Dictionary).get("ok", false))


## Painted outfit to show: an explicit preview, her current outfit if painted, else casual.
static func outfit(spec: Dictionary, preview: String = "") -> String:
	if not preview.is_empty():
		return preview
	var painted := str((spec.get("art_cover", {}) as Dictionary).get("outfit", ""))
	return painted if not painted.is_empty() else "casual"


## Painted outfits available for previews: [[id, label], ...].
static func outfits(spec: Dictionary) -> Array:
	var def: Dictionary = spec.get("illustrated", {})
	var labels: Dictionary = def.get("outfit_labels", {})
	var result: Array = []
	for id in (def.get("full_body", {}) as Dictionary):
		result.append([str(id), str(labels.get(id, str(id).capitalize()))])
	return result


static func full_body(spec: Dictionary, preview_outfit: String = "") -> Dictionary:
	var def: Dictionary = spec.get("illustrated", {})
	var name := str(def.get("full_body", {}).get(outfit(spec, preview_outfit), ""))
	return _asset(def, name, false)


## House sprite for an animation. {} when there is no painted pose for it (sleep, recline), so the
## caller keeps the working procedural animation.
static func sprite(spec: Dictionary, anim: String, on_stairs: bool = false) -> Dictionary:
	var def: Dictionary = spec.get("illustrated", {})
	var poses: Dictionary = def.get("sprites", {}).get(outfit(spec), {})
	var key := "stairs" if on_stairs and poses.has("stairs") else anim
	var name := str(poses.get(key, poses.get("*", "")))
	if anim == "sleep" or anim == "recline":
		name = ""
	return _asset(def, name, true)


static func bust(spec: Dictionary, mood: String) -> Texture2D:
	var def: Dictionary = spec.get("illustrated", {})
	var expressions: Dictionary = def.get("expressions", {})
	var name := str(expressions.get(mood, expressions.get("confident", "")))
	var asset := _asset(def, name, false)
	return asset.get("texture") as Texture2D if not asset.is_empty() else null


## Face region of a bust as a fraction of the image: {centre: Vector2, radius: float}.
static func face(spec: Dictionary) -> Dictionary:
	var f: Dictionary = (spec.get("illustrated", {}) as Dictionary).get("face", {})
	var c: Array = f.get("centre", [0.5, 0.33])
	return {"centre": Vector2(float(c[0]), float(c[1])), "radius": float(f.get("radius", 0.27))}


## {texture, anchor (px), units_per_px, name, walk} for a manifest asset; {} if missing.
static func _asset(def: Dictionary, name: String, as_sprite: bool) -> Dictionary:
	if name.is_empty():
		return {}
	var assets: Dictionary = manifest(str(def.get("manifest", ""))).get("assets", {})
	if not assets.has(name):
		return {}
	var entry: Dictionary = assets[name]
	var source: Dictionary = entry.get("sprite", entry) if as_sprite else entry
	var texture := ArtLibrary.texture(str(source.get("file", "")))
	if texture == null:
		return {}
	var anchor: Array = source.get("anchor", [float(texture.get_width()) * 0.5, float(texture.get_height())])
	return {
		"texture": texture, "anchor": Vector2(float(anchor[0]), float(anchor[1])),
		"units_per_px": float(source.get("units_per_px", 0.15)), "name": name, "pose": str(entry.get("pose", "")),
	}


static func manifest(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if not _manifests.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_manifests[path] = parsed if parsed is Dictionary else {}
	return _manifests[path]


## Draws a painted figure with her feet at `origin`, `scale` model units -> pixels (like
## CreatorRenderer), optionally mirrored. `breath` adds a tiny idle sway (anchored at the feet).
static func draw(ci: CanvasItem, art: Dictionary, origin: Vector2, scale: float, mirror: bool = false, breath: float = 0.0) -> void:
	var texture: Texture2D = art["texture"]
	var s := scale * float(art["units_per_px"])
	ci.draw_set_transform(origin, 0.0, Vector2(s * (-1.0 if mirror else 1.0), s * (1.0 + breath)))
	ci.draw_texture(texture, -(art["anchor"] as Vector2))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
