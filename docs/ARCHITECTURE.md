# Bop House Simulator: Architecture

This document describes how the code is organised, the development milestones, and known technical risks.
The product vision lives in [GAME_DESIGN.md](../GAME_DESIGN.md).

## Principles

1. **Simulation is pure and headless.** Everything in `src/core/` extends `RefCounted`, touches no nodes
   and can be run from tests. The same `Simulation.advance()` drives live play *and* offline catch-up,
   so the two can never disagree.
2. **Views are read-only.** `src/views/` and `src/ui/` read `Game.state` and listen to signals. The only
   writes go through `Game` methods (e.g. `Game.upgrade_room`).
3. **Data-driven.** Rooms, upgrade levels, furniture layout, activities, creators, content types,
   house layout and all tuning numbers live in `data/*.json`. Adding a room type or creator is a data change.
4. **Art is swappable.** Every visual first asks `ArtLibrary` for a texture / SpriteFrames path named in data,
   and only falls back to procedural placeholder drawing (`PlaceholderArt`) when the file doesn't exist.

## Runtime structure

```
data/*.json ──► GameConfig (read-only)
                    │
                    ▼
               GameState  ◄── Simulation.advance(state, config, minutes, step, efficiency)
   (cash, clock,             ├─ TrendSystem      (seeded rotation; modifiers per creator+content)
    creators, rooms,         ├─ Economy          (work_breakdown: every income component + multiplier)
    trends, unlocks)         ├─ CreatorBrain     (need-driven state machine with hysteresis)
                    ▲        ├─ ActivityResolver ("work" -> room/pose/label of chosen content)
                    │        ├─ ContentRules     (boundaries, stat requirements, room unlocks)
                    │        └─ HouseNavigator   (grid paths through stairwells)
                    │
   Game (autoload) ─┤  real-time clock, speed/pause, autosave, offline progress, signals
                    │  RoomUpgrades, SaveSystem, OfflineProgress
                    ▼
   Main ─► HouseView ─► RoomView ×N, CreatorView ×N, FloatingText
        ├► RoomInteriorView (Room View) ─► InteriorPainter layers, CreatorView ×N (same views, CreatorStage)
        └► Hud ─► Sidebar ─► OverviewPanel | CreatorPanel | RoomPanel ; OfflinePopup
```

### Logical vs pixel space

Creator positions are stored in **grid units**: `x` = house column (fractional), `y` = storey.
Walking is a simulated travel state (`travel_path`, `travel_progress`) advanced at `walk_cells_per_minute`.
`HouseView.logical_to_pixel()` is the only conversion, so changing cell size, adding a camera or zoom
never touches game logic. Offline catch-up handles travel the same way.

### Time

* 1 real second = `game_minutes_per_real_second` game minutes (default 2, so a game day is 12 real minutes).
* Live play advances by the frame delta (clamped) in sub-steps of `max_sim_step_minutes`.
* Offline uses `offline_step_minutes` (larger steps). A test checks step size barely changes results.

### Offline progress and anti-cheat

* `state.last_seen_unix` is a **high-water mark**; it only moves forward. Rolling the clock back credits
  nothing, and rolling it forward again can't pay the same period twice.
* Credit is capped (`offline.max_seconds`) and scaled (`offline.efficiency`).
* If frames stop for more than `frame_gap_offline_seconds` (hidden browser tab, sleeping laptop), the gap is
  credited as offline time instead of fast-forwarding at full efficiency.
* **Future rule:** major story events must be *queued* during offline simulation, never resolved silently.

### Content, boundaries and trends (milestone 2)

* `content_types.json` defines each category: room/pose/bubble (`activity`), `stat_weights` (content fit),
  `requirements` (stats and room level), and `rates_per_hour`.
* The brain only ever wants `work`; `ActivityResolver` turns that into the creator's chosen content, so
  switching content automatically moves her to the right room with the right animation.
* `ContentRules.check()` is the single gate used by both the UI and `Game.set_content_focus()`.
  Declines are hard boundaries and are checked before anything else, so no unlock or stat can override them.
* `Economy.work_breakdown()` returns every component and multiplier. The simulation and the Income tab
  use the same numbers, and a test asserts that the displayed multipliers multiply out to the actual income.
* `TrendSystem` keeps `active_count` trends with countdowns and a pre-rolled forecast. The RNG seed and state are saved
  (as strings, because JSON doubles can't hold 64-bit integers), so rotations are reproducible across reloads.
* Trend strength = content match x favoured-stat fit x adaptability factor (0.6 to 1.4).
* Trends last one week to one month of game time (`balance.json` `trends.min_duration_hours` / `max_duration_hours`
  clamp every roll; older saves with shorter trends are stretched on load).
* Overnight sales: while a creator sleeps, `Economy.passive_sales_per_hour` pays `passive_sales_fraction`
  (`activities.json`, 25% for sleep) of her current content-focus income. Cash only: no follower or subscriber growth.

### Appearance, tags and audiences (milestone 3)

```
creator.look (slots) ─► Appearance.compute_tags ─► creator.appearance_tags ─┬─► AudienceModel.market(tags, content)
creator.base_tags, age ─┘                                                     │      └─ audience_fit multiplier
                                                                              ├─► TrendSystem (favoured tags)
creator.look ─► Appearance.render_spec ─► CreatorRenderer (layers)            └─► fan_value (existing fans' satisfaction)
```

* **Look** = single slots (hair_color, hair_style, outfit, makeup, bust, body, lips) + lists (piercings, tattoos).
  Options and purchasable items live in `data/appearance.json`; items carry tag deltas and optional recovery rules.
* **Tags** are derived (never hand-edited) and cached on the creator; they're saved for future event eligibility.
* **Rendering** (milestone 5A, see [ART_DIRECTION.md](ART_DIRECTION.md)): `CreatorRenderer` orchestrates modular
  layers in `src/art/character/`: `FigureModel` (body contours from measurements), `FigurePoses` (joint targets per
  animation, two-bone IK), `BodyPainter`, `OutfitPainter` (garment `pieces` cut from the body contours, so outfits are
  data and follow body changes), `HairPainter`, `FacePainter` (expressions) and `AccessoryPainter`, all drawn through
  `InkPen` in screen space. Pose-independent layers are recorded once and replayed. Nipple piercings are intentionally
  never drawn (outfits cover the chest).
* **Audience segments**: appeal = 1 + Σ likes·tag − Σ dislikes·tag (clamped). For a content type, audience fit is the
  share × interest × spend weighted average appeal, and the income multiplier is fit^0.85. `creator.fan_mix` drifts toward
  the target mix while working; subscription value = Σ mix · spend · satisfaction.
* **Autonomy**: `appearance_prefs.declines` blocks purchases in `Appearance.check_item`, and content boundaries are
  unchanged. `MakeoverEvaluator` estimates effects on a cloned creator; previews never touch real state.
* **Extension points**: `procedure_history` (complications or regret events), `appearance_tags` (event eligibility), and
  guest collab content (becomes housemate collabs once recruitment exists), with `age_tags` driving the MILF segment.

### Room-activity system (milestone 4)

```
rooms.json content_support (fit, min_level, pose/spot/props) + level production {equipment, lighting, decor, privacy}
        │                                   content_types.json room_weights, exclusive, peak_hours
        ▼                                                │
RoomProduction.multiplier(room, content) ◄──────────────┘   = fit x lerp(min, max, weighted attribute score)
        │
        ├─► Economy.work_breakdown(creator, ..., room)   income for the room actually used (or best available)
        └─► RoomPlanner.work_score / choose_work_room     capacity, private rooms, exclusivity, quiet activities,
                                                          preferences, stability (last room unless >15% better)
CreatorBrain: desired activity ("work" / sleep / socialise / recover) ─► RoomPlanner for the room
ActivityResolver.resolve(creator, activity, config, room) ─► label, anim, spot, face, bubble, props for that room
```

* Nothing is Ava-specific: any number of creators and rooms work through `RoomPlanner.can_use()`.
  `test_two_creators_never_conflict_over_three_days` runs two residents for three days and checks capacity,
  exclusivity and quiet rules every step.
* Unlocks are room-driven: content is "room-gated" when no room type hosts it at level 1, and unlocks when
  any room in the house can host it (persisted in `unlocked_content`).
* `Photoshoot` is a pure, optional bonus (cooldown, energy cost, reward scales with shot quality). Automated
  production never depends on it.

### Housemates, applications and bodies (milestone 5)

```
creators.json template ─► CreatorSetup.create ─► CreatorState (+ BodyMeasurements, contract, living cost, schedule)
                               │                         │
Applications (expectations,    │                         ├─► BodyShape.render_params ─► Appearance.render_spec ─► CreatorRenderer
  free bedroom, move_in) ──────┘                         ├─► BodyShape.tags (+ tag_bonus) ─► appearance_tags ─► AudienceModel
Housing (beds, capacity, build on lots, bedroom swap)    └─► Contracts.credit (split) / charge_living_costs ─► state.cash
Relationships.step (pairs relaxing together in shared rooms) ─► friendship/trust/rivalry, mood, reaction bubbles, log
```

* **Measurements are body data, not stats.** `BodyMeasurements` (cm + tone) lives on the creator. `data/body.json`
  maps metrics (bust-waist, waist, hips, hip-waist, tone, height) through piecewise curves to renderer parameters and
  defines the body tags. The reference body 168 cm 96/66/99 renders exactly as the old "natural" variant; +10 cm bust
  and +7 cm hips reproduce the old enhanced/BBL variants, so pre-measurement saves keep their look.
* **Rendering** bends silhouette control points per region and scales the whole figure uniformly for height; arms
  anchor to the shoulders, legs to the hips, and garments, hair, tattoos and piercings reuse those curves and joints.
* **Procedures** carry `measurements` deltas in `appearance.json`; `Appearance.apply_item` applies them (previews on a
  clone). `BodyShape.derive` rebuilds measurements from a template's natural body plus applied procedures (new
  creators and save migration use the same path, so numbers always match visuals).
* **Applications**: no fees. `Applications.check` = applicant, expectations met, free bedroom (Housing). Accepting
  moves her in on her own terms (`Contracts.make`). Every resident's `living_cost_per_day` is charged each simulation
  step, including offline, so growth costs money over time instead of up front.
* **Revenue**: all creator income goes through `Simulation._earn` -> `Contracts.credit`: gross is recorded, her share is
  hers, the house share is credited. Totals report gross, house cash, living costs and per-creator splits.
* **Loyalty**: `AudienceModel.unhappiness` (share-weighted dislike of her look) drives slow subscriber churn; the fan
  mix drifts toward what her look + content attract (slower off camera).
* **Rooms**: bedrooms have `beds: 1` (residency) and `capacity` (occupancy). Only residents sleep or film in a private
  room. `Simulation.free_spot` keeps people in the same room apart. Layout rooms missing from a save are added by id.
* **Social**: data-driven interactions (`social.json`) on a saved seeded RNG; weights scale with charisma, drama,
  friendship and rivalry; trait bonuses (Loyal Friend, Drama Queen).

### Saving

* `SaveSystem` writes versioned JSON (`version`, `saved_at_unix`, `state`) to `user://savegame.json`
  using write-then-rename. On the web, `user://` is IndexedDB.
* Autosave every `save.autosave_seconds`, on upgrade, on focus loss and on window close.
* `SaveSystem._migrate()` upgrades old formats step by step (v1 to v2 renames content ids, maps `film_content` to `work`
  and sets a default focus). `SaveSystem.post_load()` then repairs the state against current data (unlocks,
  trends, invalid choices). `tests/fixtures/save_v1.json` is a real prototype save that must keep loading.

## Folder structure

```
data/              JSON configuration (balance, rooms, activities, creators, content types, layout)
src/core/          Pure simulation: state, economy, brain, navigation, save, offline, formatting
src/autoload/      Game singleton (clock, autosave, signals)
src/views/         House / room / creator rendering (Node2D)
src/art/           ArtLibrary (real art lookup), PlaceholderArt (rooms, UI), CreatorRenderer
src/art/character/ Modular character layers (model, poses, body, outfit, hair, face, accessories, pen)
src/art/illustrated_art.gd  Painted art lookup/drawing (milestone 5B); data in data/illustrated_art.json
src/art/illustrated_rig.gd  Skeleton2D + Polygon2D + AnimationPlayer rigs for painted poses (assets/characters/<id>/illustrated/rigs.json)
src/art/painted_layer.gd    Painted images with per-image recolour materials; shaders/painted_recolor.gdshader
art_pipeline/      Python tools that cut painted reference sheets into game assets (docs/ILLUSTRATED_ART.md)
src/ui/            HUD, sidebar panels, theme
src/main/          Composition root
scenes/            .tscn entry points
assets/            Final artwork goes here (see assets/README.md)
tests/             Dependency-free test runner + unit tests
docs/              Architecture and design notes
tools/             Local Godot binary (git-ignored)
build/             Export output (git-ignored)
```

## Milestones

| # | Milestone | Highlights | Status |
|---|-----------|-----------|--------|
| 1 | **First playable** | 3-room house, 1 creator, walking, idle/walk/film/sleep/socialise, clock, income, profile, room upgrades, autosave, offline progress, tests, web export | **Done** |
| 2 | **Creator management & trends** | Content specialisation and boundaries, unlocks, experience, 5 rotating trends, income breakdown, tabbed profile, collapsible sidebar, save v2 | **Done** |
| 3 | **Adult focus, appearance & audiences** | Layered appearance, makeovers with recovery, appearance tags, 10 audience segments, fan mix, 8 content types, reputation, save v3 | **Done** |
| 4 | **Automated multi-room production** | Room content support and production attributes, RoomPlanner (capacity, privacy, exclusivity, stability), bedroom production, props, optional photoshoot, save v4 | **Done** |
| 5 | **Housemates, applications & bodies** | Applications (no fees) with living costs and expectations, bedrooms built on lots, revenue splits, body measurements driving visuals and audiences, loyalty, roster, management and applications screens, basic relationships, save v5 | **Done** |
| 5A | **Character visual overhaul** | Western cartoon glamour renderer (modular body/outfit/hair/face/accessory layers, screen-space ink, shading, expressions), bikini outfit, hero showcase with close-up and line-up, makeover reveal, throttled sprite redraws | **Done** |
| 5B | **Illustrated artwork (prototype)** | Python cut-out pipeline for painted sheets, IllustratedArt with honest look coverage and fallback, mood expressions (CreatorMood), painted portraits, house sprite prototype, wardrobe preview, art mode setting | **Done** |
| 5C | **Character cleanup & animation** | Matting pipeline v2 (no halos), Skeleton2D rigs for painted poses (idle, walk, film, stream, selfie), painted sleeper, edge regression test | **Done** |
| 5D | **Reusable painted characters** | Hair masks + recolour shader on every painted draw, PaintedLayer, convention-based art/rigs per creator id, Painted/Classic art mode | **Done** |
| RV | **Room View prototype** | CreatorStage base shared by the house and room interiors, RoomInteriorView (living room), RoomStaging (presence, seats, facing; presentation only), InteriorPainter, procedural sitting poses, HUD Back to House | **Done** |
| 6 | Collaboration & events | Housemate collabs (consent and chemistry), eligibility rules, weighted events, cooldowns, choices, event inbox; offline queues events | Next |
| 7 | Relationships & storylines | Deeper relationship consequences, first multi-stage arc, journal | |
| 7 | Building | Build rooms on empty lots, more storeys, more room types (gym, livestream, glam...) | |
| 8 | Art pipeline & polish | Layered character sprites, room art, audio, onboarding, accessibility | |

Each milestone ships playable, with tests for any new economy or save logic.

## Technical risks and mitigations

| Risk | Mitigation |
|------|-----------|
| Character movement desync between logic and visuals | Logic owns position; views interpolate nothing and only convert units. |
| Pathing complexity as the house grows | Grid + stairwell "connector" rooms; `HouseNavigator` is tested and can be swapped for A* later without touching views. |
| Many creators and performance | Simulation is O(creators) per step with no allocations in the hot path; views redraw only what changes (rooms only on change). |
| Offline exploits / double-crediting | High-water mark timestamp, cap, efficiency factor, tests for clock rollback. |
| Web: threads/SharedArrayBuffer | Export uses the **no-threads** template, so no COOP/COEP headers are needed (itch.io friendly). |
| Web: persistence | `user://` → IndexedDB; frequent autosave plus save on focus loss. Browsers may evict storage; export/import of saves is planned. |
| Web: hidden tab stops `_process` | Frame-gap detection credits the gap as offline time. |
| Web: JSON data missing from export | `include_filter="data/*.json"` in `export_presets.cfg`. |
| Modular art (bodies, outfits, cosmetic changes) | Procedural layers driven by data and measurements (milestone 5A). Painted art can replace a layer later while keeping the same joints and draw order. |
| Character draw cost | Cached pose-independent layers, pre-triangulated fills, detail tiers, and house sprites redrawn at 3–15 fps (about 4 ms per redraw on desktop; `tests/visual/render_benchmark.gd`). |
| AI art consistency | Style bible plus fixed sprite dimensions and pivot (feet at origin) documented in `assets/README.md`. |
| Adult content and platform compliance | Suggestive only; ages clamped to 18+ in code; boundaries modelled as data the player can't override. |
