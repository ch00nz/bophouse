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
   (cash, clock,             ├─ Economy        (pure formulas: appeal, productivity, rates)
    creators, rooms)         ├─ CreatorBrain   (need-driven state machine with hysteresis)
                    ▲        └─ HouseNavigator (grid paths through stairwells)
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

### Saving

* `SaveSystem` writes versioned JSON (`version`, `saved_at_unix`, `state`) to `user://savegame.json`
  using write-then-rename. On the web, `user://` is IndexedDB.
* Autosave every `save.autosave_seconds`, on upgrade, on focus loss and on window close.
* `SaveSystem._migrate()` is the place to add format upgrades when `SAVE_VERSION` increases.

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
| 2 | Recruitment & capacity | Recruit pool (data), 3+ creators, room capacity contention, income breakdown panel, camera pan/zoom | Next |
| 3 | Content & boundaries | Content types per activity, creators accept/decline, subscriber churn, per-content equipment | |
| 4 | Trends | `data/trends.json`, weekly rotation, trend panel; plugs into `Economy.activity_rates(trend_multiplier)` | |
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
