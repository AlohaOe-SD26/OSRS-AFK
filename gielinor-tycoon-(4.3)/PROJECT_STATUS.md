# PROJECT_STATUS — Gielinor Tycoon

> The thread that survives between sessions. Update this at the end of every phase.
> Last updated: 2026-06-08 (end of Godot Phase-0 authoring; awaiting first real Godot run).

## One-liner
A single-player idle/tycoon "ant farm" for canon OSRS: autonomous procgen heroes live in
Varrock — gather, craft, fight, trade, level — while the player incentivizes / nudges / seizes.
Endgame = defeat the escalating rival Zezima. Engine: Godot 4, desktop-first.

## Where we are
**Phase 0 (Foundations + one skill loop) — BUILT, NOT YET RUN IN GODOT.**
Build order per GDD §22.3: step 0 (foundations) + step 1 (gather loop) are implemented; the
live combat loop (step 2) is staged but not wired.

## Verification status (be honest about the line)
| Item | Status |
|---|---|
| Economy model + constants | ✅ Validated live in the browser prototype (the Step-1 tune) |
| Canon math (XP curve, combat) | ✅ Ported from validated code; unit-tested in `tests/test_sim.gd` |
| Data JSON parses | ✅ Checked (11 items / 9 monsters / 11 map locations) |
| Project structure / sim-render split | ✅ Sim core is zero-dependency `RefCounted` (headless test proves it) |
| **GDScript parse-cleanliness in Godot** | ⚠️ **UNVERIFIED** — Godot not installed in the authoring env |
| **Gather-only economy equilibrium level** | ⚠️ **UNKNOWN** — differs from the 8-hero-with-fighters tune; needs a real log |

## The verification loop (runs on the USER's machine — Godot not available to the agent)
1. `cd game && godot --headless --script res://tests/test_sim.gd` — parse + logic + economy-bounded gate.
2. If pass: open in Godot 4.3+, F5 for the live view; let it run; press **E** to export a debug log.
3. Report back: headless test output (pass/fail + any parse errors w/ line numbers) + the first export log.

## Queued (do NOT start until the foundation verifies)
- **Live combat (build step 2):** tick fights vs. local monsters, death/respawn, the statistical
  "am I winning?" check (`Combat.fight_is_winnable` is already implemented + tested). Watch the
  flee logic and the **fighter-food sink returning** (shifts the economy back toward the original tune).
- **Economy re-center:** once a real gather-only log exists, expect a small `CONFIG` nudge to the
  equilibrium *level* (the attractor guarantees *bounded*; we just re-center). Do NOT over-tune the
  gather-only number — it's a transient that moves again when combat re-adds the food sink.

## Key decisions on record
- **GDScript** (not C#) — HANDOFF §3 allows either; lighter, matches the JS prototype.
- **Seed content DB + ingest pipeline** — osrsreboxed (~23k items) NOT downloaded yet (deliberate);
  Phase 0 boots from a hand-authored canon seed; `tools/ingest_osrsreboxed.gd` writes the same schema
  and `ContentDB` auto-prefers `*.generated.json`. Pull + snapshot patch date when scaling content.
- **Gold is `float`** in the sim — required so the small per-action proportional upkeep accrues
  instead of rounding to 0 (a bug caught in review that would have silently re-inflated the economy).
- **Schemas are top-level `class_name` files** (Hero/ItemType/Monster) — avoids inner-class
  self-reference ambiguity.

## Tuned economy constants (validated; in `sim/Config.gd`)
`geTax 0.03 · upkeepRate 0.40 (wealth-proportional/day) · upkeepFlat 6 · ratDrop 6–16 ·
priceFloorFrac 0.12 · shop.consume {ore 350, logs 350, cooked_fish 260}/day`.
Result in prototype: +3,557%/6-day runaway → bounded ±~15%, "no anomalies".

## Doc map (repo root)
`HANDOFF.md` (entry) → `GAME_DESIGN_DOC.md` (master, 26 §) → `EQUATIONS_AND_SCHEMAS.md` (formulas+schemas)
→ `ITEMS_MONSTERS_BALANCE.md` → `WORLD_AND_CHARACTERS.md` → `ASSET_PROMPT_PACK.md`; `prototype.html`
(validated behavioral reference). Build lives in `game/` (see `game/README.md`).
