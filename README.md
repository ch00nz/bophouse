# Bop House Simulator

Adult-themed (suggestive, non-explicit) cartoon idle management game built with **Godot 4.7 + GDScript**.
All characters are adults (18+). See [GAME_DESIGN.md](GAME_DESIGN.md) for the vision and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the code structure, milestones and risks.

## Current milestone: 5C, Character Graphics Cleanup & Animation

**Milestone 1 (first playable):**
* Side-on cutaway house: bedroom, living room, content studio, stairwell and an empty lot for later.
* One creator (Ava, 24) who autonomously works, socialises and sleeps, walking between floors.
* Game clock with day/night sky, pause and 1x/3x/10x speed.
* Room upgrades (3 levels each) that visibly change the room and boost its effect.
* Autosave, save on exit, and capped offline earnings with a "welcome back" summary.

**Milestone 2:**
* **Content specialisation:** Instagram & socials, glamour, solo premium, topless premium and livestreaming.
  Each has its own room, pose, earnings, follower growth, subscriber conversion, energy cost and stat requirements.
* **Boundaries:** creators' declined content can never be assigned. Content she loves is less draining on mood.
* **Unlocks:** livestreaming (and topless premium, for creators who choose it) need Studio level 2.
* **Experience:** new content starts at 70% effectiveness and improves while working; adaptability speeds it up.
* **Five rotating trends:** two active at once plus a forecast. Each favours content categories and creator stats;
  adaptability amplifies the effect. Shown in a ticker, a Trends panel with strategy advice, and toasts.
* **Explainable income:** the Income tab itemises sales, audience earnings and subscriptions, and every multiplier
  (content fit, room, energy & mood, each trend, experience). Follower growth is polynomial with a soft cap,
  so there is no runaway exponential growth.
* **Creator panel tabs** (Profile / Content / Income) with tooltips on stats, traits and every income line.
* **Collapsible sidebar**; the house re-centres.
* **Save v2** with automatic migration of v1 prototype saves.

**Milestone 3 (adult creator focus):**
* **Layered appearance system** (`data/appearance.json`): 3 hair colours, 2 hairstyles, 4 outfits (casual,
  sequin bodycon, lace lingerie set, gym set), 3 makeup styles, breast augmentation, BBL, lip filler,
  belly and nipple piercings, and a rose thigh tattoo. Body shape bends a silhouette that garments follow.
* **Makeover tab**: big animated preview with before/after comparison, estimated effects on income, audiences and
  subscriptions, recovery info, greyed-out unaffordable or declined items, and confirmation before spending.
  Creators can decline changes (`appearance_prefs`); wished-for changes boost mood.
* **Appearance tags** (Natural, Enhanced, Glamour, Alternative, Fitness, Luxury, Cute, Bombshell, Wholesome, Mature)
  derived from base tags, age, styling and procedures. They feed audiences, trends and (later) events.
* **Subscriber preference segments** (`data/audiences.json`): 10 audiences with tag likes/dislikes and content interest.
  Audience fit multiplies content income; each creator's **fan mix** drifts toward whoever her content and look attract,
  and subscription value depends on how happy those fans are. No change is a universal upgrade.
* **Adult content economy**: 8 categories (adds boy/girl and girl/girl collabs with guest fees, and custom subscriber content).
  Socials are a follower and reputation funnel; premium content is the earner. Reputation boosts subscriber conversion.
* **Recovery**: procedures and modifications have recovery time, reduced output, content restrictions and mood effects.
  Creators rest in the bedroom while recovering.
* **Bigger portrait header** with appeal tags and status; Income tab explains audience fit, fan value, reputation and
  who's buying.
* **Save v3** (v1 and v2 saves migrate; both are tested against real saved files).

**Milestone 4 (automated multi-room production):**
* Rooms declare which content they can host (`content_support` in `data/rooms.json`) with a fit, minimum level and
  pose overrides. Bedrooms host socials, solo premium (reclining on the bed), custom content, boudoir glamour and,
  from Lv 2, closed-set premium and livestreaming. **The studio is optional**; it just has the best gear.
* Production quality = room fit x set quality, where each level has **equipment, lighting, decor and privacy** scores
  and each content type weights them (livestreams want gear, premium sets want privacy).
* `RoomPlanner` picks where to work from content, room quality, trends, time of day, energy/mood (via income),
  availability and personal room preferences. It respects capacity, **private bedrooms** (only the owner films there),
  **exclusive** content (needs the room to herself) and quiet activities (no filming next to a sleeper).
  Work sessions keep their room; a new session only moves if another room is >15% better.
* Creators have a home bedroom: they film there by day and sleep there at night.
* Visuals: posing for camera, selfies, ring lights, livestreams, reclining on the bed; collabs show a consenting guest
  (styled guest creator or an anonymous clothed silhouette); implied closed-set content uses a privacy screen.
* Peak hours (e.g. evening livestreams) and a room-aware Income tab; room panels show the set's attributes and what
  each content earns there.
* **Optional Photoshoot Mode**: a 3-shot timing mini-game for bonus cash and followers, on a 12-hour cooldown.
  Idle play never needs it.
* Save v4 (v1, v2 and v3 saves load; all tested against real saves).

**Milestone 5 (housemates, applications & body measurements):**
* **Applications, not purchases:** creators apply to live and work in the house (`data/creators.json`, six applicants:
  bombshell, girl next door, alternative, fitness, newcomer, party girl). Joining is free; each brings her own revenue
  split and adds **living costs** per day. Some only apply once the house meets their expectations (e.g. a Lv 2 studio,
  a bigger combined audience). Everyone needs her own bedroom; bedrooms are built on empty lots (each costs more).
* **Revenue split:** gross revenue per creator, her share, the house share (the only part credited to cash), living
  costs, and growth since joining are tracked per creator and for the whole house. Offline income uses the same split.
* **Body measurements** (height, bust/waist/hips, muscle tone) for every creator, shown in cm or inches. They drive the
  renderer's body regions (bust, waist, hips, glutes, shoulders, limbs, uniform height scale), so every body looks
  different in the house and the big previews, with clothes, hair, tattoos and piercings staying aligned.
* **Body tags** (petite, slim, curvy, voluptuous, athletic) derive from measurement combinations; two new audience
  segments (petite & slim fans, curves lovers) and updated likes mean no body type wins everywhere.
* Breast augmentation (+10 cm bust) and BBL (+7 cm hips) change measurements and visuals; styling, tattoos and
  piercings never do. Creators still decide: refusals can't be overridden. New styling: 4 hair colours, 3 hairstyles,
  2 outfits, nose stud, floral arm sleeve.
* **Audience loyalty:** fans who dislike a new look slowly cancel; the fan mix drifts gradually (also off camera),
  explained in the Finances tab.
* **Many autonomous residents:** independent movement, schedules (night owls, early birds), work-session lengths,
  room choice with capacity/privacy rules, own bedrooms for sleep and private filming, spread-out standing spots.
* **Housemate relationships:** friendship, trust and rivalry; chats, hangouts, celebrations, gossip and minor
  disagreements in shared rooms, with reaction bubbles and poses (drama-prone personalities clash more).
* **UI:** left roster (portrait, activity, energy/mood, fans, $/hr, recovery), full management screen (Overview,
  Stats & Measurements, Content, Makeover, Finances, Relationships) with a big preview and creator switcher,
  Applications screen with profiles and a compare-all table, a three-storey house that scales to fit 1280x720.
* **Save v5:** v1 to v4 saves load; old single-creator saves get measurements derived from their procedures, a
  founder agreement for Ava, a ledger seeded from past earnings and the new lots, with nothing reset or duplicated.

**Milestone 5A (character visual overhaul):**
* **Western cartoon glamour style** for every creator: an adult three-quarter-view figure with bold ink outlines,
  soft shading and rim light, a detailed face (almond eyes, lashes and liner, arched brows, full lips),
  glossy layered hair and a clear hourglass. See [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md).
* **Modular renderer** (`src/art/character/`): body model from measurements, pose library with IK limbs,
  and separate body, outfit, hair, face/expression and accessory layers. Garments are data `pieces` (tops,
  dresses, skirts, bras, briefs) cut from the body, so breast augmentation, BBL, waist and height changes all
  show, while tattoos and piercings stay aligned in every pose.
* **Expressions:** smile, grin, laugh, smirk, sultry, wink, kiss, talk, annoyed and sleep, plus blinking.
  Each creator has a signature expression from her personality.
* **New outfit:** poolside bikini. Outfits now have accessories (hoops, drop earrings, choker, pendant,
  bracelet, sunglasses) and makeup has lash styles and highlight.
* **Hero showcase** on the management screen: a larger full-body stage with a name plate, close-up
  (face and styling) and house line-up (true relative heights) views. Buying a look plays a "new look" reveal.
* **House sprites:** the same art at gameplay size with a slightly larger head for readability, and
  sleeping under a blanket. Sprites redraw at 3–15 fps, so a full house costs less than the old
  prototype did.
* Saves are unchanged (still v6). Outfit ids are the same, and older top/bottom outfit data still renders.

**Milestone 5B (illustrated artwork, prototype):** see [docs/ILLUSTRATED_ART.md](docs/ILLUSTRATED_ART.md).
* **Asset pipeline** (`art_pipeline/`, Python): crops every figure, bust and pose from the painted reference sheets,
  removes the paper background and floor shadows with clean edges, keeps one scale per sheet with feet anchors,
  paints out a real brand logo, and writes full-size and sprite PNGs plus a manifest. The references are never
  modified and are excluded from builds.
* **Ava's paintings in the game** whenever they truthfully match her look: hero full body, close-up expression busts,
  roster faces, and house sprites (standing, walking, filming, selfie, back view on the stairs). Procedures, other
  hair, tattoos and unpainted outfits fall back to the procedural art, and the profile says what isn't painted yet.
  Sleep and recline keep the procedural animation; the painted walk is one pose, not a cycle.
* **Mood expressions** (happy, confident, sad, angry, surprised, playful) from mood, energy, recovery, work and
  housemate reactions, for painted and procedural creators alike.
* **Wardrobe preview** (casual, glamour, fitness, swimwear) on the profile hero: display only. An **Art** mode
  button (Auto / Always / Off) is saved in settings; old saves default to Auto.

**Milestone 5C (character graphics cleanup and animation):** see [docs/ILLUSTRATED_ART.md](docs/ILLUSTRATED_ART.md) section 5.
* **Clean cut-outs:** the pipeline now matts edges properly (trimap and colour unmixing against the local
  paper or shadow colour), removes paper streaks between hair strands and the light rim AI art leaves around
  outlines, and keeps teeth, eyes, white shoes and highlights. The sheer cover-up is clean white fabric.
  `art_pipeline/inspect_edges.py` previews halos on dark and bright backgrounds, and a unit test guards edges.
* **Skeletal animation** for painted poses with Godot's Skeleton2D, Bone2D, a skinned Polygon2D mesh and
  AnimationPlayer (`IllustratedRig`, `data/illustrated_rigs.json`): idle breathing, a walk with alternating legs
  and arm swing, filming, livestream waves and selfies, with blending. Feet stay planted, the walk is mirrored to
  her direction, and its speed follows the game speed.
* **Painted sleeping pose** on the bed (bedding removed from the reference and turned to lie along the bed).
* Flattened paintings only allow small limb swings; the exact layered rig art needed for full animation is
  specified in the docs. The procedural renderer remains the fallback for every look the paintings don't show.

**Economy rebalance:** start with $250, 350 followers and 8 subscribers (~$18 gross per productive hour).
Running costs (rent, utilities, equipment maintenance, residents' living costs) are charged continuously and shown
line by line in **Finances** (yesterday / today / lifetime). **Upgrades** (`data/upgrades.json`: ring light $150,
phone $400, wardrobe $650, pro camera $1,500, editing suite, streaming rig, studio renovation $3,500, bigger house
$25,000) show maintenance, effects and estimated payback; bonuses within a category have diminishing returns.
Audiences saturate (soft cap, daily unfollows, subscriber churn), repeated content loses freshness, offline time
runs at 10% speed and 70% earnings, and new housemates need a bedroom plus a cash reserve. Debug builds have an
economy inspector (F9) to skip time and adjust cash. Balance report:
`godot --headless --path . --script res://tests/balance/run_balance.gd -- [all|idle,casual,upgrades,recruitment,optimised] [days] [seed]`.

Art review: `tests/visual/illustrated_sheet.gd -- out.png` (painted vs procedural sprites, expressions, outfits),
`tests/visual/house_walk.gd -- out.png` (a creator walking upstairs to bed in the real house),
`tests/visual/rig_sheet.gd -- out.png [creator] [anim]` (skeletal rig weights and animation frames),
`tests/visual/character_sheet.gd -- out.png ava [items]` renders one creator in hero poses and every
gameplay animation (with a 3x zoom of the sprites); `tests/visual/render_benchmark.gd` measures draw cost;
`godot --path . --script res://tests/visual/lookbook.gd -- out.png [cast]` renders a grid of looks
(`cast` = every creator side by side); `tests/visual/house_scene.gd -- <dir>` screenshots the house, management
and applications screens with three residents;
`tests/visual/room_scenes.gd` renders every production pose in its room.

## Running

Requires Godot **4.7** (standard build, not .NET). Open the folder in the Godot editor and press F5, or:

```bash
./tools.sh run        # run the game
./tools.sh test       # run the unit tests headless
./tools.sh web        # export to build/web
```

`tools.sh` looks for a Godot binary in `tools/` (git-ignored) or uses `$GODOT` / `godot` on PATH.

### Testing in a browser

```bash
./tools.sh web
py -m http.server 8060 --directory build/web
```

Then open http://localhost:8060. The web export uses the no-threads template, so no special headers are required
and the build can be uploaded to itch.io as-is.

## Tuning

All balance numbers live in `data/balance.json`, `data/activities.json` and `data/rooms.json`.
Tests assert relationships (e.g. "better rooms earn more") rather than tuned values, so tuning doesn't break them.

## Tests

`tests/run_tests.gd` is a small dependency-free runner. Any `tests/unit/test_*.gd` file extending `TestCase`
is discovered automatically; engine script errors raised during a test count as failures.
