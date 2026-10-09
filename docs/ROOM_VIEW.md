# Room View

Click a room in the house cutaway to watch the creators inside it up close. The prototype covers the
living room. Room View is **presentation only**: it reads `Game.state` every frame, never runs its
own simulation, and the game keeps running while it's open and after you leave.

## How it fits together

```
HouseView ──room_clicked──► main.gd ──► RoomInteriorView.open(room)   (house hidden, HUD "Back to House" bar)
                                         │
CreatorStage (base) ◄── HouseView, RoomInteriorView: the interface CreatorView draws through
   stage(creator) -> {pos, visible, anim, lift, face, ease}
                                         │
RoomStaging (pure)  present() / seats() / plan()  ◄── real positions, activities and reactions
InteriorPainter     walls, window (time of day), doorways, furniture from rooms.json, lighting
CreatorView         the same creator rendering as the house: painted art and rigs, procedural
                    renderer, mood, hair colour, speech bubbles
```

* **Who is shown:** everyone whose real position is inside the room, including people walking
  in or out through a doorway.
* **Where they are:**
  * Working creators stay at their simulated spot and perform their real activity: selfies,
    filming, livestreams.
  * Relaxing creators share out the seats the furniture provides, spread out in their real
    left-to-right order. "Relaxing" means the activities listed in `sit_anims`: idle,
    socialising, chatting.
  * Creators walk (the walk animation) to their seat or spot.
* **Facing:** conversation partners (a real social reaction) turn toward each other. Other
  sitters face the nearest housemate.
* **Clicks:** clicking a creator opens her management screen. **Back to House** (or Esc)
  returns to the overview.
* **Upgrades:** the room redraws with its level's colours, wall pattern and furniture.

## Adding another room type

1. Add it to `data/room_interiors.json` → `rooms` (`"enabled": true`, plus any `sit_anims`).
2. Make sure its furniture kinds have seating rules (`seating`) and drawings in `InteriorPainter`.
   Kinds without a detailed drawing fall back to the house view's drawing, so new kinds always
   appear.
3. Bedrooms already have `sleep_surface` beds that `CreatorView` uses for sleeping and reclining.
   Studios, kitchens and outdoor areas need new furniture drawings.

## Limits and missing art

* **Sitting is procedural only.** The procedural renderer gained `sit`, `sit_phone` and `sit_chat`
  poses. Painted creators (Ava) need a painted sitting pose: until it exists they stand at their
  simulated spot, rather than being swapped to procedural art or having a standing painting
  placed on a seat. The art to request, in the same style and scale as Ava's other paintings
  (transparent PNG, 168 cm = 1500 px):
  * seated on a couch, three-quarter view facing right, hips at the seat line, feet on the floor;
  * the same seated pose holding a phone;
  * the same seated pose talking with one open hand;
  * ideally the seated poses as rig parts (pelvis, thighs and shins separate) for the
    Skeleton2D rigs.
* **Positions are 1D.** Positions are left-right only: there's no depth, so creators in front of
  furniture are drawn over it, as in the house view.
* **Furniture is procedural.** Furniture is the procedural interior painter (ink outlines, cel
  shading), not painted art. Painted room backgrounds and furniture can replace it later through
  the existing `background_texture` / `texture` hooks in `rooms.json`.

## Review

```
godot --path . --resolution 1280x720 --script res://tests/visual/room_view.gd -- <dir> [living_level]
```

Writes day and night shots, frames of the live simulation, a creator click opening her
management screen, and the house after Back to House. Unit tests are in
`tests/unit/test_room_view.gd`.
