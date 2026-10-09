# Assets

Rooms and UI placeholders are drawn procedurally by `src/art/placeholder_art.gd`; characters by the modular
renderer in `src/art/character/` (style guide: `docs/ART_DIRECTION.md`). To replace it, add files here and
reference them from `data/*.json`. If a referenced file is missing the game falls back to the placeholder,
so art can be added one piece at a time.

| What | Data field | Format / conventions |
|------|-----------|----------------------|
| Room background (whole room) | `rooms.json` → level → `background_texture` | PNG. One cell is 170×200 px (a 2-wide room is 340×200), so author at 2× (680×400). Floor strip is the bottom 14 px (×2). |
| Single furniture item | `rooms.json` → level → furniture item → `texture` | PNG, transparent. Drawn into the item's x/w/h rect. |
| Creator animations | `creators.json` → `appearance.sprite_frames` | `SpriteFrames` `.tres` with animations `idle`, `walk`, `film`, `selfie`, `stream`, `socialise`, `chat`, `celebrate`, `argue`, `sleep`, `recline`. Feet at the bottom-centre of each frame. ~120 px tall at 1× (author at 2× and scale). Facing **right**. |
| Creator portrait | `creators.json` → `appearance.portrait` | PNG, 96×112 (author at 2× or more). |

Suggested layout:

```
assets/
  characters/<creator_id>/ava_frames.tres, portrait.png, sheets/*.png
  rooms/<room_type>/level_<n>.png
  furniture/<kind>.png
  ui/
```

Painted character sheets go in `assets/characters/<id>/references/` (excluded from builds by `.gdignore`) and
are turned into game assets with `art_pipeline/extract_sheets.py` (see `docs/ILLUSTRATED_ART.md`); the output
lands in `assets/characters/<id>/illustrated/` and is wired up in `data/illustrated_art.json`.

Keep a record of source, prompt/model (for AI-generated art) and licence for every file in `assets/CREDITS.md`.
