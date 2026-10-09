# Illustrated character art (milestone 5B)

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
