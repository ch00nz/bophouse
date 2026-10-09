# Bop House Simulator

Adult-themed (suggestive, non-explicit) cartoon idle management game built with **Godot 4.7 + GDScript**.
All characters are adults (18+). See [GAME_DESIGN.md](GAME_DESIGN.md) for the vision and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the code structure, milestones and risks.

## Current milestone: 2, Creator Management & Content Trends

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
