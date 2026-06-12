# Handoff — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place, CONTINUOUSLY. A new agent with zero
> context must be able to resume from this file alone.

**Repository:** https://github.com/AlohaOe-SD26/OSRS-AFK
**Last updated:** 2026-06-12

## What is this project?
A Godot 4.6.3 single-player idle/tycoon "ant farm" in canon OSRS Varrock:
autonomous utility-brain heroes gather/fight/trade/socialize; the player
steers (incentivize/nudge/seize) and invests a tax-fed treasury. Read
`00-README.md` → `01` → `02` for the full picture. The live build is
`game/`; the `gielinor-tycoon-(*)` dirs are STALE snapshots.

## Current state
**MVP COMPLETE; UNIT 0 (Slayer slice, punch #1) COMPLETE 2026-06-12** —
suite 141/141 + determinism/save-load/offline gates green. Economy
attractor validated; day-23 per-capita band re-baselined to **1,460 ± 332**
(8 seeds — post-survival-triad; the old 1,065–1,211 band is stale).
Post-MVP merge plan: M1 visual port ✅ · M2 BRAIN_V2 default-OFF (4th test
failed it — see KI-4) · M3 content waves underway.

## What was just done (this session, 2026-06-12)
- **#1e closing sweep + BRAIN_V2 4th test DONE → Unit 0 closed.**
  - NEW `game/tools/diag_unit0.gd` (8 seeds × on-task arms 0/10/20/35):
    **SLAYER_ON_TASK locked at +20** (engagement saturates; +0 collapses
    the Slayer loop, +35 buys nothing).
  - **§18 prediction split:** rival-lean half HELD — social web flipped
    friend-leaning, **KI-5 resolved/removed**. Combat-share half FAILED —
    monoculture 39–44% in every arm (the survival triad removed lethality
    as the hidden counterweight); **KI-4 re-confirmed structural**, fix
    path revised to combat-side reward saturation (home: Unit-1+ pricing).
  - **BRAIN_V2 4th test** (`diag_stage2.gd`, v1 vs v2 on the Unit-0
    surface): v2 WORSENS monoculture 52±3 vs 44±5 (saturating bases make
    untrained strength everyone's refuge) while collapsing gold SD
    ±332→±84. **Default stays OFF**; salvage the variance win after the
    combat base is price-coupled.
  - Tools + docs only — no sim-code changes; #1d's verification verdicts
    stand.

## In progress (and how far along)
- Nothing mid-flight. Unit 0 (#1a–#1e) fully closed.

## Next steps (in order)
1. **Unit 1 (catalog migration, punch #2)** — resolves KI-8 first,
   ContentDB-driven goods/prices, recipes-as-data, tradeable flags, shops
   trade gear; rename `GE_TAX`→`SHOP_TAX` while files are open (R8).
   While in pricing: this is the natural home for the KI-4 fix (combat
   reward saturation / price coupling) — design it into the unit.
2. Unit 2 (shop economy v2, punch #3) per rulings R1/R3.

## How to run / build / test
```
godot --headless --path game --script res://tests/test_sim.gd   # 101 checks
godot --headless --path game --script res://tools/gate_determinism.gd
godot --headless --path game --script res://tools/gate_saveload.gd
godot --headless --path game --script res://tools/gate_offline.gd
godot --headless --path game --script res://tools/headless_log.gd # telemetry
# play: open game/ in Godot 4.6.3, F5 (Space pause · 1/2/4/8 speed · E log ·
# F5/F9 save/load · M menu · R roster)
```
Godot binary path & GDScript 4.6 gotchas: agent memory `godot-environment`.

## Gotchas / unpushed work
- Save-shape changes MUST bump SAVE_VERSION and append an upgrader to `SaveLoad._chain()` (the #1a scaffold) — never ship a schema change without one.
- Fresh tree (no `game/.godot/`): run `godot --headless --path game
  --import` once first, or headless scripts fail to parse `class_name`s.
- Any new sim RNG draw perturbs the seed stream → re-baseline sweeps.
- Don't chase the stale "600–900" gold band; the validated band moved
  (see `02-ARCHITECTURE.md`).
- The probe was READ-ONLY by instruction: known cleanups (dead `_route*`
  code, snapshot dirs, Economy-vs-items.json base-value mismatch) were
  deliberately left untouched.
