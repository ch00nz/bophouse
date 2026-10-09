# Illustrated character art (milestones 5B to 5D)

Painted Western-cartoon art for Ava, used as the new visual benchmark. This covers the asset
pipeline, how the game uses the paintings today, the plan for full customisation, and exactly which
artwork to generate next.

## 1. Asset pipeline (`art_pipeline/`)

```bash
py -m venv tools/artenv
tools/artenv/Scripts/python -m pip install -r art_pipeline/requirements.txt
tools/artenv/Scripts/python art_pipeline/extract_sheets.py art_pipeline/ava_sheets.json --preview contact.png
```

* **Input:** the reference sheets in `assets/characters/ava/references/`. They are only ever read, and a
  `.gdignore` file keeps them out of the game build.
* **Manifest** (`ava_sheets.json`): one box per figure, its kind (`full_body`, `bust` or `scene`), view,
  outfit, pose and expression, a scale reference per sheet, plus fixes:
  * `patches`: repaint a small area. The real sportswear logo on the fitness top is inpainted from the
    surrounding fabric, since the game uses fictional branding only.
  * `sheer`: semi-transparent fabric, such as the beach cover-up.
* **Background removal** (`cutout.py`):
  * The paper colour and its floor shadows are removed when they connect to the image border. Both are
    warm greys, so cool or neutral whites (sneakers, fabric) are kept.
  * Enclosed pockets of exact paper colour (for example between an arm and the body) are also removed.
  * Edges get a soft alpha, and the paper colour is un-blended out of edge pixels so there are no halos.
* **Figure isolation:** the largest blob in each box, plus strands and earrings near it. Neighbouring
  figures' parts cut by the box edge and distant labels are dropped.
* **Outputs** in `assets/characters/ava/illustrated/`:
  * `full/`: full-resolution cut-outs for hero and portrait use.
  * `sprite/`: house sprites at 256 px for a 168 cm figure, resampled with premultiplied Lanczos.
  * `portrait/`: expression busts.
  * `reference/`: the sleeping scene, which keeps its bed. It isn't used in the game.
  * `illustrated.json`: per asset, the file, size, feet anchor, figure height and `units_per_px`.
    Every figure on a sheet shares one scale, and every sheet is normalised so a standing figure is
    124 model units tall, the same height as a 168 cm procedural creator.
* Textures import with mipmaps (`project.godot` `[importer_defaults]`). Nodes that draw paintings use
  linear-with-mipmaps filtering.

## 2. In-game use (prototype)

`data/illustrated_art.json` maps game data to paintings: game outfit to painted outfit, animation to
painted pose, and mood to painted bust. `Appearance.illustrated_coverage()` decides whether the
paintings truthfully show her current look:

* **Covered:** brunette long waves, natural or glam makeup, natural bust, body and lips, measurements
  matching the painted body, no tattoos or visible piercings, and an outfit with a painting (casual,
  glamour, fitness or bikini).
* **Anything else:** breast augmentation, BBL, lip filler, other hair, tattoos, piercings, lingerie,
  goth or party outfits, or changed measurements. These fall back to the procedural renderer, and the
  profile lists exactly what isn't painted yet. Images are never stretched to fake a procedure.
* **Art mode** (the "Art:" button on the profile hero, saved in settings):
  * **Auto** (default): use paintings when they match.
  * **Always:** show the paintings even when they don't match, to review the art. The mismatch is
    labelled.
  * **Off:** procedural art only.

Where the paintings appear:

| Place | Painted art |
|---|---|
| Profile hero, full body | Her painted outfit, a gentle idle sway, a mood face inset, a "new look" hop on purchase |
| Profile hero, close-up | The painted expression bust for her mood. For non-casual outfits, the outfit painting is cropped and the mood shows in the inset |
| Roster cards, side panel, relationship portraits | The painted face for her mood |
| Wardrobe chips (Her look / Casual / Glamour / Fitness / Swimwear) | Preview only: never changes her look, ownership or money |
| House | Standing (idle, chat, argue), walking, filming (also livestream and celebrate), selfie (also socialising), and the back view on the stairs |
| House, sleep and recline | The existing procedural animation (no side-on painted pose yet) |

**Moods** (`CreatorMood`):

| Mood | When |
|---|---|
| Angry | Bickering, or low mood with a dramatic personality |
| Happy | Celebrating, a good chat, or mood ≥ 72 |
| Sad | Mood < 30, exhausted, or recovering while low |
| Playful | Working on camera |
| Confident | Her default |
| Surprised | When a makeover is revealed |

Procedural creators map the same moods onto their drawn faces, including new `sad` and `surprised`
expressions.

**The walk is not animated.** It's the single painted walking pose with a step bounce, mirrored to
match her direction. It's a placeholder until a real walk cycle exists.

## 3. Path to full customisation (evaluation)

| Approach | Supports measurements and procedures? | Cost | Verdict |
|---|---|---|---|
| Stretching the whole painting | No: distorts the face, hands and clothes | none | Rejected |
| Pre-rendered full figures per body × outfit × pose | Yes, but it explodes: 4 bust × 4 hip × 7 outfits × 8 poses ≈ 900 paintings per creator | very high | Only for a few hero images |
| **Layered paper doll + skeletal rig** (Godot `Skeleton2D` + `Polygon2D` meshes, or Spine) | Yes: swap body-region layers per measurement tier, smoothly blend within a tier with bone scale, keep garments as separate layers per tier | moderate, reusable for every creator | **Recommended** |
| Fully 3D-rendered to 2D | Yes | high pipeline change | Not now |

Recommended design:

* **Rig parts:** hair back, head, face features (eyes, brows, mouth sets), hair front, neck, torso,
  pelvis, upper and lower arms, hands (several grips), thighs, shins, and feet with shoe overlays.
* **Body variants:** discrete painted tiers for the regions measurements and procedures change:
  * bust: small, natural, full, augmented;
  * hips and seat: slim, natural, curvy, BBL;
  * waist: slim, natural, soft.
  
  `BodyShape.render_params` picks the tier, and bone scale handles the small in-between differences.
  Tiers share fixed seam lines at the shoulders, waist and upper thigh so they swap cleanly.
* **Clothing:** each garment is a layer bound to the same bones, painted once per body tier it covers
  (tops per bust tier, bottoms per hip tier).
* **Hair and makeup:** hair layers painted in neutral greys plus a colour map, tinted in the engine for
  hair colours. Eyeshadow and lip layers are tintable too.
* **Tattoos and piercings:** small overlay sprites parented to the relevant bone.
* **Animation:** idle, walk and filming move through the rig, so a real walk cycle costs keyframes,
  not paintings.

## 4. Artwork needed next (precise requests)

All requests use the same style as `ava_master.png`, with these rules:
* a transparent background, or flat paper with no cast shadow;
* no text, labels or real brand logos;
* scale: Ava 168 cm = about 1500 px from crown to sole (a 2048 px canvas), feet on the same baseline;
* PNG output; layered PSDs welcome.

**A. Immediate (finish the house prototype)**
1. **Sleeping, side-on:** lying on her back, head to the left, viewed from the side as if on the
   house's side-view bed. Two versions: without bedding, and with a separate blanket overlay layer.
   Casual outfit.
2. **Reclining, side-on:** propped on one elbow on a bed, knees bent, side view, without the bed.
   Casual outfit.
3. **Walk cycle, side view facing right:** 8 frames (contact, down, passing, up, for each leg), the
   same scale and baseline in every frame. Casual outfit, then each painted outfit.
4. **Standing poses for the glamour, fitness and swimwear outfits:** filming, selfie and walking,
   so these outfits get the same set as casual.
5. **Expression busts per outfit:** the six expressions in the glamour dress, fitness top and
   bikini, or one set of head-only expressions on a transparent neck, to composite on any outfit.

**B. Customisation (rig package, per creator)**
6. **Layered rig sheet:** front three-quarter A-pose, every part from section 3 on its own layer with
   overlap at the joints, in neutral nude-tone underwear for non-explicit base layers.
7. **Body tiers:**
   * torso in 4 bust sizes (small, natural, full, augmented);
   * pelvis and upper thighs in 4 sizes (slim, natural, curvy, BBL), front and side view.
8. **Clothing layers per tier:**
   * tops per bust tier: casual crop tee, glamour dress top, sports bra, bikini top, lace bustier;
   * bottoms per hip tier: denim shorts or skirt, dress skirt, leggings, bikini bottoms, lace briefs
     and stockings, party mini, goth plaid skirt.
9. **Hair:** long waves, high ponytail, bob, big curls and space buns, as back and front layers in
   greyscale with highlights, for tinting.
10. **Face parts** for the rig head angle:
    * eyes: open, closed, wink, happy-closed;
    * brows: neutral, raised, angry, sad;
    * mouths: smile, laugh, O, frown, pout, plus talk A/E/O.
11. **Overlays:** rose thigh tattoo, floral half-sleeve split per arm segment, nose stud, belly ring.
12. **The same package for each housemate** (Chloe, Mia, Jade, Sienna, Lily, Roxy) once Ava's rig is
    proven.

## 5. Milestone 5C: transparency cleanup and skeletal animation

### Transparency (pipeline v2, `art_pipeline/cutout.py`)

What was wrong in 5B, and how v2 fixes it:

| Problem | Fix |
|---|---|
| White and beige streaks between hair strands | Enclosed pockets are removed when they're paper-coloured and large. Small or near-white ones are removed only when **ringed by dark hair** (judged on the non-background ring) and either thin (3 px half-width or less) or touching the outside. Teeth, eye whites, sneakers and highlights fail those tests and stay. |
| A lighter-than-paper rim that AI art paints around outlines | Paper-**hued** light pixels count as background only within 3 px of real background, so large light areas (white soles, fabric) are never eaten. |
| Hard, stair-stepped edges and paper contamination | A trimap with a 3 px unknown band and closed-form matting: each edge pixel is unmixed between its nearest solid colour F and the local background B (paper, or the floor shadow under the feet), then decontaminated. Then subpixel alpha smoothing, and fully transparent pixels take the nearest visible colour so mipmaps never bleed paper. |
| A blotchy sheer cover-up with holes | The cloth's silhouette is closed, and each pixel is unmixed between white fabric and paper with an opacity floor. Fold shading is kept as neutral grey, since the beige came from the paper behind it. |
| A light band along the busts' cut edge | Removed by the rim rule. |

* Review: `tools/artenv/Scripts/python art_pipeline/inspect_edges.py assets/characters/ava/illustrated --preview out.png`
  reports the paper-coloured, light and partial edge pixels per PNG, and writes zoomed crops on dark purple and
  bright green.
* Regression test: `test_cutout_edges_have_no_paper_halo` scans every cut-out's edges. The limit is 3% at full
  size and 8% for downscaled sprites (sheer-fabric folds average into beige-ish pixels).

### Animation (`IllustratedRig`, `data/illustrated_rigs.json`)

Godot 2D skeletal animation on the flattened paintings:
* **Skeleton2D and Bone2D:** a hierarchy per painted pose (pelvis root, chest, head, arm segments, lower legs).
* **Polygon2D:** a 4 px grid mesh over the painting's opaque pixels. Each vertex is skinned to the bone whose
  region (a polygon in the data) contains it, and weights are smoothed along mesh edges. Smoothing never crosses
  empty space between limbs, so joints bend instead of tearing.
* **AnimationPlayer:** looping sine tracks built from data, with 0.2 s blending between animations. The root
  bone never animates, so the feet stay planted.

| Game animation | Painted pose | Motion |
|---|---|---|
| idle, chat, argue | standing | Breathing, upper-body sway, head tilt, free-arm sway |
| walk | walking | Alternating lower-leg strides, opposite arm swing, upper-body bob. Mirrored to the walking direction; speed follows the game speed |
| film | filming | Waving hand, camera bob, head tilt, sway |
| stream, celebrate | filming | Faster wave, talking nod, bounce |
| selfie, socialise | selfie | Peace-sign wiggle, phone hand, head tilt |
| stairs | back view | Static, with a step bounce |
| sleep | the painted sleeper, bedding removed and turned to lie along the bed | Slow breathing; rests on the mattress |
| recline, collabs | (procedural) | No suitable painting |

**What this can't do with flattened art.** Nothing is painted behind a limb, so limbs only swing about
10 degrees. The legs keep the drawn crossing at the knee; a walk can't show a full stride, a turn, or a side
view; arms can't cross the body; and outfits other than casual have one standing painting each (no rig,
static). This is a convincing stand-in, not a walk cycle.

### Artwork needed for full skeletal animation (precise spec)

Deliver as transparent PNG layers (a layered PSD is ideal). Shared rules for every layer:
* **Style:** the same as `ava_master.png`.
* **Canvas:** 2048 x 2048, feet on y = 1950, body centred on x = 1024.
* **Scale:** 168 cm = 1500 px from crown to sole.
* **Content:** no shadows, text or real logos.
* **Overlaps:** each part extends **25 to 40 px past its joint**, painted as if the neighbouring part weren't
  there (e.g. the shoulder painted under where the arm attaches). This is what lets limbs rotate without gaps.
* **Pivots:** list each joint's pixel position in a text file.

**1. Three-quarter front rig (facing right), A-pose, arms 20 degrees from the body, legs slightly apart.**

Parts, one layer each:

| Part | Notes |
|---|---|
| hair_back | Everything behind the head and shoulders |
| head | Face without hair, neutral expression; with neck stub |
| hair_front | Fringe and front locks |
| torso | Neck base to waist, natural bust; includes shoulders |
| pelvis | Waist to upper thighs; includes the crotch |
| upper_arm_near, upper_arm_far | |
| forearm_near, forearm_far | |
| hand_near, hand_far | 4 grips each: relaxed, open/wave, holding a phone, on hip |
| thigh_near, thigh_far | |
| shin_near, shin_far | |
| foot_near, foot_far | Bare foot, plus a separate sneaker and heel layer per foot |

**2. Side view rig (facing right)** with the same part list, for walking.

**3. Expression parts** for the rig head:
* eyes: open, half-lidded, closed, wink, happy-closed;
* brows: neutral, raised, angry, sad;
* mouths: smile, laugh/open, O, frown, pout, plus talk A/E/O.

**4. Body variants** (same pivots):
* torso: 4 bust sizes (small, natural, full, augmented);
* pelvis and thighs: 4 hip/seat sizes (slim, natural, curvy, BBL).

**5. Clothing layers** fitted per body variant, cut along the same part boundaries:
* tops: casual crop tee, glamour dress top, sports bra, bikini top, lace bustier, party dress top;
* bottoms: denim shorts, glamour dress skirt, leggings, bikini bottoms, lace briefs + stockings, party mini,
  plaid skirt.

**6. Hair** (front and back layers) for long waves, ponytail, bob, curls and space buns, painted in
greyscale for tinting.

**7. Overlays:**
* rose thigh tattoo (on thigh_near);
* floral sleeve, split across upper arm and forearm;
* nose stud, belly ring.

**8. Lying poses** without a bed, as separate full images until the rig can lie down:
* sleeping on her back with her head to the left, side view;
* reclining propped on one elbow, side view.

## 6. Milestone 5D: a reusable painted renderer and hair colour

### Why hair colour didn't change the paintings (audit)
1. The paintings are flattened: hair, skin and clothes are baked into one image.
2. The art policy hid the paintings: a look that differed from the painted brunette long waves
   failed the coverage check, and the game switched to the procedural renderer.
3. Paintings were drawn with plain `draw_texture`, with no material that could recolour anything.

### How it works now
* **Hair masks (pipeline):** `art_pipeline/masks.py` segments the hair of every extracted painting
  (full size, sprites, busts, back view, lying pose). It works by colour (desaturated red-brown),
  removes line art and brows by shape, keeps the mass connected to the crown, and grows back strands.
  Masks are saved to `illustrated/masks/<folder>/<asset>_hair.png`, and the manifest records them along
  with the hair's luminance range. A hand-painted mask with the same file name replaces an automatic one.
* **Recolour shader:** `src/art/shaders/painted_recolor.gdshader` changes only masked pixels. It maps
  the painted luminance onto the hair colour's `art_palette` (dark, mid and light, in
  `data/appearance.json`), so strands, highlights and line art survive. Nothing else in the sprite changes.
* **Every painted draw uses it:** `PaintedLayer` gives each painting its own material, and rigs set it
  on their skinned mesh. That covers house sprites in every animation, the walk in both directions,
  the stairs back view, the lying pose, the hero, close-up busts, the mood inset and roster faces.
* **Art policy:** creators who have paintings keep them. Hair colour is adapted. Other differences
  (hairstyles, procedures, unpainted outfits, tattoos, piercings) are listed as "Not painted yet"
  rather than swapping to procedural art. Art mode is now Painted or Classic (Classic = procedural
  art, which shows every change). Old "always" saves load as Painted.
* **Reusable for every creator:** nothing is Ava-specific in code.
  * Paintings are found by convention at `assets/characters/<id>/illustrated/illustrated.json`.
  * Rigs live in `assets/characters/<id>/illustrated/rigs.json`.
  * Shared defaults (outfit, pose and expression mapping) are in `data/illustrated_art.json`, with
    optional per-creator overrides.
  * What a creator's paintings depict (painted hair colour, hairstyle, natural body) is read from her
    own template in `data/creators.json`.
  * A recruit gets painted art by adding sheets, a manifest entry and a rigs file. No code change.
* **Fallbacks:** a recruit without paintings keeps the procedural renderer. A painted creator's
  before/after makeover preview uses Classic for changes the paintings can't show, so the difference
  stays visible.

### Adding painted art for another creator (e.g. Chloe)
1. Put her sheets in `assets/characters/chloe/references/`. The sheets need the same content as
   Ava's (master, turnaround, expressions, outfits, poses).
2. Copy `art_pipeline/ava_sheets.json` to `chloe_sheets.json`, then set `character`, `source_dir`,
   `out_dir` and the boxes for her sheets.
3. Run `extract_sheets.py art_pipeline/chloe_sheets.json`. It produces cut-outs, sprites, masks and the
   manifest. Check `inspect_edges.py` and the mask overlays.
4. Write `assets/characters/chloe/illustrated/rigs.json`: joint positions in her paintings, using Ava's
   as the template.
5. Her template look in `creators.json` must match what's painted. Chloe's painted hair would be
   `blonde`, and the paintings must show her template outfit, bust and body.

### Art needed for interchangeable hairstyles, outfits, skin tones and body types
Hair colour works from masks. The other changes need separately painted layers, because hidden
pixels (the scalp under long hair, the body under clothes) don't exist in flattened art.

**Shared rules**
* **Format:** PNG with transparency.
* **Canvas and scale:** the same canvas, scale and feet baseline as the rig spec in section 5
  (2048 x 2048, 168 cm = 1500 px, feet on y = 1950).
* **Coverage:** one file per layer, per view (front three-quarter, side, back), per rig pose.
* **Naming:** `assets/characters/<id>/layers/<view>/<layer>__<variant>.png`, for example
  `front34/hair_back__ponytail.png` or `front34/top__casual__bust_full.png`.

**Layers**

| Layer | Variants | Notes |
|---|---|---|
| `head` | per creator | Face and ears, no hair |
| `body` | 4 bust x 4 hip/seat tiers | Nude-tone base, non-explicit, with seams at the waist and upper thigh |
| `hair_back__<style>` and `hair_front__<style>` | long_waves, high_ponytail, bob, curls, space_buns | Painted in neutral greyscale (value only) so the shader can tint any colour; a separate `__mask` file is optional |
| `top__<outfit>__<bust tier>` | each top, for each bust tier | |
| `bottom__<outfit>__<hip tier>` | each bottom, for each hip tier | |
| `legwear__<type>` | stockings, fishnets, leggings | |
| `shoes__<type>` | sneakers, heels, boots, sandals | One file per foot |
| Skin tone | per painting | Either a `skin_mask` (white = skin) per painting for shader tinting, or base layers painted per tone |
| Tattoo and piercing overlays | each design | Per body tier, positioned on the rig bone |
