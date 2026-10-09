class_name IllustratedArt
extends RefCounted
## Painted character art for any creator who has it (milestones 5B-5D). Reads the creator's resolved
## art definition (render spec "illustrated", from Appearance.illustrated_definition) and the asset
## manifest the art pipeline generated (art_pipeline/extract_sheets.py):
##   full_body(spec)   hero image for her current (or a previewed) painted outfit
##   sprite(spec, ...) house sprite for an animation ({} = no painted pose: procedural renderer)
##   bust(spec, mood)  expression portrait
##   material_for()    recolour shader for her current hair colour (masked; only hair pixels change)
## Creators with paintings keep them on screen; look changes the paintings can adapt (hair colour)
## are applied with masks, others are reported as "not painted yet" (spec "art_cover").
## Creators without paintings use the procedural renderer.

const MODES: Array[String] = ["auto", "off"]
const MODE_LABELS := {"auto": "Painted", "off": "Classic"}
const SHADER_PATH := "res://src/art/shaders/painted_recolor.gdshader"

## Art mode from the player's settings: auto (paintings for creators who have them) or off (classic).
static var mode: String = "auto"
static var _manifests: Dictionary = {}
static var _materials: Dictionary = {}
static var _shader: Shader = null


static func has_art(spec: Dictionary) -> bool:
	return not (spec.get("illustrated", {}) as Dictionary).is_empty()


## True when her paintings should be drawn instead of the procedural figure.
static func use_art(spec: Dictionary) -> bool:
	return mode != "off" and has_art(spec)


## True when the paintings show everything about her current look (directly or adapted).
static func depicts(spec: Dictionary) -> bool:
	return bool((spec.get("art_cover", {}) as Dictionary).get("ok", false))


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
		if not _asset(def, str(def["full_body"][id]), false).is_empty():
			result.append([str(id), str(labels.get(id, str(id).capitalize()))])
	return result


static func full_body(spec: Dictionary, preview_outfit: String = "") -> Dictionary:
	var def: Dictionary = spec.get("illustrated", {})
	var name := str(def.get("full_body", {}).get(outfit(spec, preview_outfit), ""))
	return _asset(def, name, false)


## House sprite for an animation. {} when there is no painted pose for it, so the caller keeps the
## working procedural animation. Lying animations need an explicit painted pose.
static func sprite(spec: Dictionary, anim: String, on_stairs: bool = false) -> Dictionary:
	var def: Dictionary = spec.get("illustrated", {})
	var poses: Dictionary = def.get("sprites", {}).get(outfit(spec), {})
	var key := "stairs" if on_stairs and poses.has("stairs") else anim
	var name := str(poses.get(key, poses.get("*", "")))
	if (anim == "sleep" or anim == "recline") and not poses.has(anim):
		name = ""
	return _asset(def, name, true)


static func bust(spec: Dictionary, mood: String) -> Dictionary:
	var def: Dictionary = spec.get("illustrated", {})
	var expressions: Dictionary = def.get("expressions", {})
	return _asset(def, str(expressions.get(mood, expressions.get("confident", ""))), false)


## Face region of a bust as a fraction of the image: {centre: Vector2, radius: float}.
static func face(spec: Dictionary) -> Dictionary:
	var f: Dictionary = (spec.get("illustrated", {}) as Dictionary).get("face", {})
	var c: Array = f.get("centre", [0.5, 0.33])
	return {"centre": Vector2(float(c[0]), float(c[1])), "radius": float(f.get("radius", 0.27))}


## Path of the creator's skeletal rig definitions ("" = none).
static func rigs_path(spec: Dictionary) -> String:
	return str((spec.get("illustrated", {}) as Dictionary).get("rigs", ""))


## {texture, anchor (px), units_per_px, name, pose, kind, full_size, hair_mask, hair_lum} for a
## manifest asset; {} if it doesn't exist.
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
	var full_size: Array = entry.get("size", [texture.get_width(), texture.get_height()])
	var lum: Array = entry.get("hair_lum", [0.04, 0.4])
	return {
		"texture": texture, "anchor": Vector2(float(anchor[0]), float(anchor[1])),
		"units_per_px": float(source.get("units_per_px", 0.15)), "name": name, "pose": str(entry.get("pose", "")),
		"kind": str(entry.get("kind", "")), "full_size": Vector2(float(full_size[0]), float(full_size[1])),
		"hair_mask": str((source.get("masks", {}) as Dictionary).get("hair", "")),
		"hair_lum": Vector2(float(lum[0]), float(lum[1])),
	}


static func manifest(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	if not _manifests.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_manifests[path] = parsed if parsed is Dictionary else {}
	return _manifests[path]


# ---------------------------------------------------------------------------
# Recolouring
# ---------------------------------------------------------------------------

## Whether her current hair colour differs from the painted one (and so is recoloured).
static func recolours_hair(spec: Dictionary) -> bool:
	var def: Dictionary = spec.get("illustrated", {})
	var look: Dictionary = spec.get("look", {})
	return (def.get("adapts", []) as Array).has("hair_color") and str(look.get("hair_color", def.get("hair_source", ""))) != str(def.get("hair_source", ""))


## Dark / mid / light hair colours: the hair option's "art_palette" if given, else derived from its
## colour (keeping hue, spreading value so painted shading reads the same).
static func hair_palette(spec: Dictionary) -> Array[Color]:
	var custom: Array = spec.get("hair_palette", [])
	if custom.size() == 3:
		return [Color(str(custom[0])), Color(str(custom[1])), Color(str(custom[2]))]
	var base := Color(str(spec.get("hair_color", "#6b3b2a")))
	var dark := base.darkened(0.68).lerp(Color(0.12, 0.05, 0.08), 0.25)
	var light := base.lightened(0.45)
	return [dark, base, light]


## Recolour material for a painted asset, or null when nothing needs recolouring (the painting is
## drawn exactly as painted). Cached per mask and colour, so every creator view shares materials.
static func material_for(spec: Dictionary, art: Dictionary) -> Material:
	if art.is_empty() or not recolours_hair(spec):
		return null
	var mask_path := str(art.get("hair_mask", ""))
	var mask := ArtLibrary.texture(mask_path)
	if mask == null:
		return null
	var palette := hair_palette(spec)
	var key := "%s|%s|%s|%s" % [mask_path, palette[0].to_html(), palette[1].to_html(), palette[2].to_html()]
	if _materials.has(key):
		return _materials[key]
	if _shader == null:
		_shader = load(SHADER_PATH)
	var material := ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("hair_mask", mask)
	material.set_shader_parameter("hair_enabled", true)
	material.set_shader_parameter("hair_dark", palette[0])
	material.set_shader_parameter("hair_mid", palette[1])
	material.set_shader_parameter("hair_light", palette[2])
	material.set_shader_parameter("hair_lum", art.get("hair_lum", Vector2(0.04, 0.4)))
	if _materials.size() > 200:
		_materials.clear()
	_materials[key] = material
	return material
