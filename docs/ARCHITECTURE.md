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
src/art/           ArtLibrary (real art lookup) + PlaceholderArt (procedural drawing)
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
| 3 | Recruitment & capacity | Recruit pool (data), 3+ creators, room capacity contention, house-wide income overview, camera pan/zoom, money sinks (wages, rent) | Next |
| 5 | Events | Eligibility rules, weighted selection, cooldowns, choices, event inbox; offline queues events | |
| 6 | Relationships & storylines | Pairwise friendship/rivalry, first multi-stage arc, journal | |
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
| Modular art (bodies, outfits, cosmetic changes) | Appearance is data (colours/tags now; layer paths later). Plan: layered `Sprite2D` stack (body, hair, outfit, accessories) with shared animation timing. |
| AI art consistency | Style bible plus fixed sprite dimensions and pivot (feet at origin) documented in `assets/README.md`. |
| Adult content and platform compliance | Suggestive only; ages clamped to 18+ in code; boundaries modelled as data the player can't override. |
