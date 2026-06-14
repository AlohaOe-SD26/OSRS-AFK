# Architecture — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. Describes how it is built TODAY.
> (Exhaustive system-by-system detail with verbatim constants:
> `ANALYSIS REPORT/ANALYSIS_REPORT.md` Part A, dated 2026-06-11.)

## Tech stack
Godot **4.6.3** (GDScript only). No external libraries. Data = JSON catalogs;
an osrsreboxed dataset ingest tool exists (writes `*.generated.json`,
preferred by ContentDB when present). Engine path & gotchas: agent memory
`godot-environment.md`.

## Folder / module map
```
game/
  sim/        # deterministic SIM CORE — 17 RefCounted classes, no Node deps
    SimWorld.gd   # tick loop, trip FSM, combat, control tiers, kick votes,
                  # buildings, offline catch-up, chronicle
    Config.gd     # ALL tuned constants (mirrors EQUATIONS CONFIG.*)
    Economy.gd    # market facade over the 7-shop roster (Unit 2), treasury +
                  # ledger, tax, price-bias, upkeep attractor; base values
                  # catalog-sourced (Unit 1)
    Shop.gd       # per-shop stock / dynamic prices / consumption / leveling
    Brain.gd      # utility scoring (score == sum of named terms)
    Hero.gd       # 28-slot canon inventory, 10 equip slots, goals,
                  # nudge/seize state, run energy, BFS path (serialized)
    Activities.gd # dual-resolvable activity catalog + expected yields
    Combat.gd     # canon OSRS combat math (stateless; live + statistical)
    Social.gd     # sparse signed relationship graph (lazy decay, self-prune)
    Population.gd # reputation / immigration / departures
    SaveLoad.gd   # binary full-state save incl. RNG state (no class_name)
    Telemetry.gd  # snapshots + steady-state drift / anomaly export
    ContentDB.gd / ItemType.gd / Monster.gd / MonsterInstance.gd
    Rng.gd        # seeded RNG wrapper (global randf banned in sim)
    XpTables.gd   # canon XP curve + combat level
  render/Main.gd  # the ONLY render/UI file (immediate-mode _draw + rect
                  # hit-testing: top bar, roster, TOWN LEDGER, hero popup)
  tests/test_sim.gd   # 229-check headless gate suite
  tools/              # gates (determinism/saveload/offline) + diag_* sweeps
  data/               # items.json (23 — THE item truth: ids/values/tiers/
                      # styles/recipes/tradeable, Unit 1) · shops.json (7-shop
                      # roster + charge/baseline/unlock defs, Unit 2) ·
                      # monsters.json (10) · varrock_map.json
```
Root: 6 original design docs (unmodified), `prototype.html`,
`STEP3_HANDOFF.md`, `sweep_out.txt`, `ANALYSIS REPORT/`, this folder.
`gielinor-tycoon-(4.3)/` and `(copy)/` = **stale early-phase snapshots**,
not the live build.

## How the pieces talk
`Main._ready` loads ContentDB → builds SimWorld (6 founders, seed) → ticks it
from `_process(delta × speed)`. `SimWorld.tick` = continuous movement +
discrete work-actions (one per 2.4 real s at 1×): per action — hero trip-FSM
step, `economy_tick` (town consumption + wealth-proportional upkeep), social
pass, population step, daily rollovers (building upkeep, satisfaction,
chronicle), telemetry every 30 actions. Render reads world read-only; all
player input dispatches to SimWorld methods (`_dispatch_ui`).

## Time model
TICK 0.6 s × 4 ticks/action = 2.4 s/action; 1.4 sim-min/action →
**1 in-game day ≈ 1,029 actions ≈ 41 real min at 1×** (≈5 min at 8×).
Offline: 24 real h ≈ 35 sim-days, resolved statistically with live bounds
(market ceiling per good, shared pit throughput, attractor closed form
g(T) = g* + (g0−g*)e^(−kT) — cannot overshoot live play).

## State / save shape
`SaveLoad.save_world` → one binary Variant dict, `SAVE_VERSION = 9`:
heroes (full FSM/paths/goals/equipment + nudge/seize + C1 nudge params + bank),
GE order book (ge_orders/ge_unlocked) + city_inventory + treasury ledger,
monsters, shops, treasury + ledger counters + price-bias, population, social
adjacency, incentives/buildings/kick records, chronicle, clock/counters,
**RNG state**. Old saves are walked up an ordered upgrader chain
(`SaveLoad._chain()`, v1→…→v6); an unreachable/future version → load refused.
Save is a pure read (cannot perturb the run being saved).

## Determinism contract
One seeded `Rng` threaded everywhere; draw ORDER is part of the contract
(hero BFS paths are persisted in saves for this reason). Any new RNG draw
perturbs the stream → banked sweep baselines must be re-baselined (routine,
plan for it).

## Test gates — what "done" means
1. 101-check suite green; includes the economy regression (6 heroes, 12
   sim-days, population frozen: gold ∈ (800, 40000), steady-state per-capita
   drift |%| < 60).
2. Relevant gate: determinism (3 seeds → identical hash) · save/load
   (byte-identical continuation) · offline (batch absorbed by the attractor;
   gain(30h) == gain(24h) exactly).
3. Emergent/behavioral claims: 8–16-seed sweeps (measurement discipline —
   single-seed results are RNG-confounded).
4. Render smoke on GPU when UI changed; report the new economy band vs prior.

## Current validated economy band
Day-12 per-capita gold ≈ **1,065–1,211** (post-pathfinder re-center,
UPKEEP_RATE 0.80); recent content slices ran 926–1,058 and 682–1,249,
drift +2–6%. The old "600–900" band is stale. POP_CAP 50; perf ≈ 305 ms /
1k ticks at 50 heroes headless.
**Post-#1d drift (2026-06-12, awaiting #1e re-baseline):** the survival
triad (regen/tolerance — deaths 2,096→4, flees ~0) lifted per-capita to
~1,485 at day 23 in the aggro diagnostic. More productive hours, same
attractor; formally re-baseline in the #1e instrumented sweep before
treating any number as a regression.

## External dependencies & services
None at runtime. GitHub remote `https://github.com/AlohaOe-SD26/OSRS-AFK`
(⚠️ zero commits as of 2026-06-11 — see KI-1).

## How to run / build / test
```
# tests (101 checks; exit 0 = pass)
godot --headless --path game --script res://tests/test_sim.gd
# gates
godot --headless --path game --script res://tools/gate_determinism.gd
godot --headless --path game --script res://tools/gate_saveload.gd
godot --headless --path game --script res://tools/gate_offline.gd
# full telemetry export
godot --headless --path game --script res://tools/headless_log.gd
# play: open game/ in Godot 4.6.3, F5. Keys: Space pause · 1/2/4/8 speed ·
# E export log · F5/F9 save/load · M menu · R roster · L LOD toggle
```
Harness rules (standing): tools use `preload()` by path, never `class_name`
(a tool class_name created `--import` hangs); every SceneTree harness ends
`_initialize` with `quit()`; run gates foreground with a timeout.
