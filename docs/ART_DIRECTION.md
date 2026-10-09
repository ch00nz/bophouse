# Bop House: character art direction (milestone 5A)

Style bible for the creators, and a guide to the modular renderer that draws them. Every
character is an adult woman (21+). The tone is glamorous, cheeky and suggestive, never explicit:
garments always cover the chest and groin, and some modifications (e.g. nipple piercings) are
tags only and are never drawn.

## Style

| Element | Rule |
|---|---|
| Overall | Western cartoon glamour (think modern TV animation and mobile pin-up games), not anime, not pixel art, not realism. Bright, saturated, game-friendly colours. |
| Proportions | About 6.3 heads tall. Long legs, clear hourglass. Bust, waist, hips, seat and height come from measurements, so every body is different. |
| View | Three-quarter front view facing the direction of travel. The bust profile reads on the near side, the seat curve (BBL) on the far side. |
| Line | Bold warm-plum ink (`#2a1622`) on outer contours, about 1 px on sprites and capped at 3.4 px in close-ups. Thinner tinted inner lines (collarbones, knees, lips, strands). Overlapping shapes are drawn as one silhouette: contours first, fills second. |
| Shading | Light from the upper front. A soft gradient on big shapes, a cel shadow crescent on the far side, a rim highlight on the near side. Shadows shift toward warm violet, not grey. |
| Face | Adult heart-shaped face with a soft jaw. Almond eyes of realistic size with a lifted outer corner, iris, pupil and catch-lights, and a bold upper lash line. Defined arched brows, a small upturned nose, full lips with a cupid's bow. Makeup: lids, liner wing, glam lashes, blush, highlight, lip colour. |
| Hair | Big readable masses with a back layer (behind the body) and a front layer (crown, fringe, shoulder locks), strand lines and a glossy shine band. The fringe casts a shadow on the forehead. |
| Clothes | Cut from the body contours, so they follow every bust, waist and hip change. Each has a neckline, straps, trim and a fabric pattern (sequins, satin, lace, ribbed, denim, plaid, mesh). |
| Sprites | Same model as the portraits: the head is drawn 14% larger and fine details (lashes, iris highlights, lace, strand lines) drop out below 1.4 px per model unit. |

## Renderer modules (`src/art/`)

```
Appearance.render_spec ─► CreatorRenderer.draw(ci, spec, anim, t, origin, facing, scale, lift)
                            │
   FigureModel  (cached per body)  contours, breasts, neck, joints, landmarks, IK, leg/arm shapes
   FigurePoses  anim + t ─► joint targets, hip sway, head tilt, hand shapes, expression
   BodyPainter  rig (IK), limbs, merged torso/neck/near-leg silhouette, shading, hands,
                tattoos, piercings, sleep blanket
   OutfitPainter  data-driven garment pieces, legwear, shoes
   HairPainter    hairstyle back/front layers (STYLES registry)
   FacePainter    head, face, makeup, EXPRESSIONS
   AccessoryPainter  earrings, choker, pendant, sunglasses, bracelet
   InkPen       screen-space drawing, contours, cel shading, layer recording/replay
```

* **Draw order:** back hair, far arm, far leg (legwear, shoe), body silhouette, tattoos and
  piercings, near legwear and shoe, garments, accessories, near arm (phone), head (ear, earrings,
  face), front hair. A near hand raised in front of the face is drawn after the head.
* **Screen-space pen:** points are transformed before drawing instead of scaling the canvas, so
  antialiasing feathers stay about 1 px at any zoom. Fills are triangulated once in model space and
  drawn as triangle arrays.
* **Caching:** layers that don't depend on the pose (face per expression state, hair, garments,
  torso shading) are recorded once per look, detail tier and hip-sway step, then replayed.
  Limbs are posed live with two-bone IK.
* **Detail tiers** depend on pixels per model unit: sprite (< 1.4), medium (< 1.9) and portrait.
* **Frame rate:** house sprites redraw at 15 fps when walking or celebrating, 8 fps for calm
  poses and 3 fps when asleep. UI previews redraw at 10–30 fps. Moving between rooms stays
  smooth because a position change needs no redraw.

## Data hooks

* `data/appearance.json`
  * `slots.outfit[].pieces` / `legwear` / `shoes` / `accessories`: see the header of
    `outfit_painter.gd` for garment kinds, landmarks (`shoulder`, `bust_top`, `underbust`, `ribs`,
    `waist`, `navel`, `low_waist`, `hip`, `crotch`, `leg:<fraction>`), necklines, cuts and patterns.
    Older `top`/`bottom` outfit data still renders.
  * `slots.makeup[]`: `lips`, `lids`, `liner`, `lashes` (`natural`/`glam`), `highlight`, `blush`.
  * `portrait.trait_expressions`: signature expression per personality trait.
* `data/body.json` `render` curves turn measurements into body parameters (unchanged from milestone 5).
* `creators.json` `appearance`: `skin`, `eyes`, `freckles`. Real art can still replace the
  placeholders through `sprite_frames` / `portrait` (see `assets/README.md`).

### Adding things

* **Outfit:** add a `slots.outfit` entry with `pieces`, plus a `Wardrobe` item. No code needed.
* **Hairstyle:** add control points and a `match` branch in `HairPainter.draw_back`/`draw_front`,
  add the id to `STYLES`, then add the slot option and item in `appearance.json`.
* **Expression:** add an entry to `FacePainter.EXPRESSIONS`. Poses choose expressions in
  `FigurePoses`.
* **Pose:** add a function in `FigurePoses` that returns joint targets.

## Refined style prototype (milestone 6, phase 1)

A polished pass over the same modular renderer, aimed at Ava's painted look in a Western cartoon
style. It is **only applied to Mia** (`RenderStyle.prototype_ids`) until reviewed; everyone else
renders exactly as before (classic output is unchanged byte for byte).

| Area | Refined treatment |
|---|---|
| Face (`refined/refined_face.gd`) | Almond eyes ~8% larger with the lids partly covering the iris, layered iris (limbal ring, lit lower half, two catch-lights), warm lid tone, tapered lash line with a flick and curled outer lashes, pink inner corner; full arched brows that fade in at the head; nose drawn with soft shadow and light only; fuller lips with cupid's-bow peaks, a darker upper lip, gloss and a shadow under the lower lip; sculpted forehead, cheekbone and chin highlights; radial blush. |
| Skin (`refined/refined_body.gd`) | Warm rosy-brown shadows instead of violet; outlines in a deep tone of the skin instead of plum ink; soft gradient shading (`InkPen.soft`) in place of cel crescents; collarbone, shoulder, bust, belly and hip highlights; knee, thigh and shin highlights. |
| Hair (`refined/refined_hair.gd`) | Hair-toned outline, soft volume (lit crown, darker underside), tapered strand clumps with lit edges, soft rim light, a glossy sheen band with crisp highlight strands. Works for every style and colour. |
| Body (`FigureModel`, refined only) | Slimmer neck; shoulders and ribcage taper into the waist; slimmer upper arm, forearm swell, fine wrist; fuller upper thigh tapering to a slim knee, shapely calf, fine ankle. Joints, bone lengths and waist/hip/seat widths are unchanged, so poses, seats, beds, outfits and measurements all still line up. |

New `InkPen` primitives: `fill_mesh`, `fill_radial`, `fill_feather`, `shade_soft`. Below the sprite
tier the refined style keeps cel shading (invisible at that size, and cheaper).

* **Compare:** `tests/visual/style_compare.gd` (below) renders Mia refined | Mia classic | Roxy classic
  at close-up, hero, Room View and house scale, plus an expression strip. In a debug build, **F8**
  (or the Dev panel button, F9) flips the prototype on and off live in the house and Room View.
* **Cost:** about +0.7 ms per refined creator per redraw at Room View scale (sprites redraw at
  8–15 fps); `render_benchmark.gd -- refined 2.6` forces the whole cast refined as a worst case.
* **Revert:** empty `RenderStyle.prototype_ids`, or delete `render_style.gd`, `refined/` and the
  `RenderStyle` / `c.has("refined")` / `pen.soft` branches. **Roll out:** add creator ids, or make
  `RenderStyle.of` return refined for everyone.

## Review tools

```
godot --path . --resolution 1280x720 --script res://tests/visual/character_sheet.gd -- out.png ava [item,item]
godot --path . --script res://tests/visual/style_compare.gd -- out.png [mia] [roxy]
godot --path . --script res://tests/visual/lookbook.gd -- out.png [cast]
godot --path . --resolution 1280x720 --script res://tests/visual/house_scene.gd -- <dir>
godot --path . --resolution 1280x720 --script res://tests/visual/render_benchmark.gd [-- classic|refined [scale]]
```

`InkPen.debug_validate = true` (set by the character sheet) prints a backtrace for any polygon
that can't be triangulated.

## Still placeholder / next steps

* All character art is still procedural. The style is consistent, but it isn't hand-painted. The
  next visual milestone could commission or generate painted layers per body region (torso,
  bust, hips, limbs) and hairstyle, and drop them into the same layer order and joints.
* There is a single 3/4 view. Walking away from the camera and a real back view aren't drawn.
* Hands are simplified mitts with nail colour. There are no per-finger poses beyond open,
  point and holding a phone.
* Face shape is shared. A per-creator jaw, cheek and nose variant (`face_shape`) would add variety.
* Rhinoplasty, dentistry and fitness body-change visuals aren't in the game yet.
* Expressions are shown by pose but aren't yet driven by mood or events (a sad, tired or
  angry face from game state would be cheap to add via `spec.expression`).
