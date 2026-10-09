class_name RenderStyle
extends RefCounted
## Visual-upgrade prototype switch (milestone 6, phase 1).
##
## The "refined" style is a polished pass over the procedural renderer: painterly face (larger
## almond eyes with layered lashes, fuller brows, soft nose, glossy shaded lips), soft gradient skin
## shading instead of hard cel crescents, hair with volume, sheen and strand clumps, colour-matched
## outlines, and smoother limb and torso contours. Geometry, joints, poses, outfits and every
## appearance setting are shared with the classic style; only how the figure is painted changes.
##
## Until the prototype is reviewed it only applies to the creators in `prototype_ids`; everyone
## else keeps the classic renderer. Reverting = emptying `prototype_ids` (or deleting this file,
## src/art/character/refined/ and the `RenderStyle.refined(...)` branches).
## A render spec can force a style with "render_style": "classic" | "refined" (comparison sheets).

const CLASSIC := "classic"
const REFINED := "refined"

## Creators drawn with the refined prototype.
static var prototype_ids: Array[String] = ["mia"]
## Developer toggle (DevPanel, F8): false draws everyone classic.
static var enabled: bool = true


static func of(spec: Dictionary) -> String:
	var forced := str(spec.get("render_style", ""))
	if forced == CLASSIC or forced == REFINED:
		return forced
	return REFINED if enabled and prototype_ids.has(str(spec.get("creator_id", ""))) else CLASSIC


static func refined(spec: Dictionary) -> bool:
	return of(spec) == REFINED


## Flips the developer toggle; returns the new state.
static func toggle() -> bool:
	enabled = not enabled
	return enabled
