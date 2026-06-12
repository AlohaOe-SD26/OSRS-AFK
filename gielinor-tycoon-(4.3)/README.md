# Gielinor Tycoon — Godot 4 Phase-0 build

The first real build of the "ant farm for OSRS" (GDD §22.3 steps 0–1). A deterministic,
headless-runnable **sim core** + a thin **render layer**, with the **validated economy**
carried straight in from the prototype tune.

## What this slice does
- Loads a **content DB** (canon items/monsters/map) — from a hand-authored seed now, from the
  full **osrsreboxed** dataset once ingested (same schema either way).
- Renders **Varrock** (iso tilemap from `WORLD_AND_CHARACTERS.md` §2) with **6 heroes** living
  on the **utility brain** (GDD §18): they choose gather activities, commit to trips (mine /
  chop / fish → cook → sell), and self-balance across nodes via congestion + the economy.
- Runs the **§6 economy** with the sinks that were tuned to a flat total-gold equilibrium
  (saturation-aware prices, town consumption, GE tax, wealth-proportional upkeep).
- Emits the **debug log** (HANDOFF §8) — press **E** in-game, or run the headless test.

## Architecture — the sim/render split is the invariant (GDD §21.2 / HANDOFF §5)
```
game/
  sim/          # DETERMINISTIC SIM CORE — pure RefCounted, no Node, headless-runnable
    Config.gd        tuned constants (validated economy sinks + brain/pacing)
    Rng.gd           seeded deterministic RNG (part of the save, §25)
    XpTables.gd      canon XP curve + combat level (§1)
    Hero.gd / ItemType.gd / Monster.gd   entity data classes (§12)
    ContentDB.gd     loads data/*.json (prefers dataset-ingested *.generated.json)
    Combat.gd        canon combat math — live + statistical share it (§2/§10)
    Economy.gd       shop prices + the validated faucet/sink model (§6)
    Activities.gd    DUAL-RESOLVABLE activities (live trip + expected-yield/hr) (§4/§18.5)
    Brain.gd         the utility function — argmax over feasible activities (§4/§18)
    SimWorld.gd      owns all state; deterministic tick(dt); trip FSM; offline catch-up
    Telemetry.gd     debug-log exporter, steady-state anomaly detection (§8)
  render/         # THIN render/UI — reads SimWorld read-only, never holds game logic
    Main.gd / Main.tscn
  data/           # content DB (canon seed; *.generated.json from ingest takes precedence)
    items.json  monsters.json  varrock_map.json
  tools/
    ingest_osrsreboxed.gd   # dataset → content DB (run headless)
  tests/
    test_sim.gd             # headless sim-core tests
```
The render layer can be removed entirely and the sim still runs (that's what the headless
test proves) — required for offline catch-up, LOD, and save/load.

## Run it
**Needs Godot 4.3+ (desktop).** From `game/`:
- **Editor / play:** open `project.godot` in Godot, press F5 (runs `render/Main.tscn`).
  Controls: **Space** pause · **1/2/4/8** speed · **E** export debug log (also printed to console
  and written to `user://debug_log.txt`) · **click a hero** to read their thoughts.
- **Headless sim tests (no display):**
  ```
  godot --headless --script res://tests/test_sim.gd
  ```
  Asserts the canon XP curve (99 = 13,034,431; 92 ≈ half), combat math, that the economy stays
  **bounded over ~12 sim-days**, and offline catch-up caps at 24h. Exits non-zero on failure.

## Ingesting the real dataset (osrsreboxed)
The ~23k-item dataset isn't bundled. Download `items-complete.json` + `monsters-complete.json`
from the osrsreboxed repo, then:
```
godot --headless --script res://tools/ingest_osrsreboxed.gd -- <items-complete.json> <monsters-complete.json>
```
It writes `data/items.generated.json` + `data/monsters.generated.json` (same schema as the seed;
`ContentDB` prefers them automatically). **Snapshot the patch date you ingest** — several monster
stats are version-dependent (`ITEMS_MONSTERS_BALANCE.md` §8).

## What's verified vs. not (be honest about this)
- ✅ **Logic ported from the validated prototype** — the economy math/constants are the same
  ones taken from +3,557% runaway to bounded equilibrium in the browser tune.
- ✅ **Canon math** is unit-tested in `tests/test_sim.gd`.
- ⚠️ **NOT yet run through a Godot compiler in this environment** (Godot wasn't installed where
  this was authored). First action on your end: run the headless test — it'll surface any GDScript
  parse issue immediately, and the sim core has no engine deps so it's the fastest gate.
- ⚠️ **Economy retune expected:** the tune was done with 8 heroes *including fighters*; this
  Phase-0 slice is **gather-only (no combat loop yet)**, so the faucet/sink mix differs. The
  attractor keeps gold bounded, but the equilibrium *level* may want a light retune once combat
  (build step 2) adds the food-buying sink back.

## Next (build order §22.3)
Step 2 — wire **live combat** (the math + monsters are already here): tick fights vs. local
monsters, death/respawn, and the statistical "am I winning?" check (`Combat.fight_is_winnable`).
