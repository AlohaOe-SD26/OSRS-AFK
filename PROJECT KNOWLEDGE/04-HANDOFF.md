# Handoff — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place, CONTINUOUSLY. A new agent with zero
> context must be able to resume from this file alone.

**Repository:** https://github.com/AlohaOe-SD26/OSRS-AFK
**Last updated:** 2026-06-11

## What is this project?
A Godot 4.6.3 single-player idle/tycoon "ant farm" in canon OSRS Varrock:
autonomous utility-brain heroes gather/fight/trade/socialize; the player
steers (incentivize/nudge/seize) and invests a tax-fed treasury. Read
`00-README.md` → `01` → `02` for the full picture. The live build is
`game/`; the `gielinor-tycoon-(*)` dirs are STALE snapshots.

## Current state
**MVP COMPLETE** — build steps 0–6 all closed and green (101/101 suite +
determinism/save-load/offline gates). Economy attractor validated; current
day-12 per-capita band ~1,065–1,211, drift +2–6%. Post-MVP merge plan in
progress: M1 visual port ✅ · M2 brain-v2 measured (default-off) · M3
content waves underway (gear/equipment/smithing/zones-slice-1 done).

## What was just done (this session, 2026-06-11)
- **Design rulings received** (`ANALYSIS REPORT/DESIGN_RULINGS.md` — R1–R12,
  all 12 report questions ruled; sequencing Units 0–5 endorsed as-is). The
  hold is lifted; punch list updated with ruled scope/constants.
- **Initial commit + push DONE** (`5fd5d97` → origin/main). KI-1 resolved.
- Unit 0 build started (see In progress).

## In progress (and how far along)
- **Punch #1 — Unit 0: Slayer slice** (see `03-PUNCH-LIST.md` #1a–#1e for
  exact ruled scope). Build order: #1a save-migration scaffold → #1b Slayer
  core (Vannaka) → #1c funded bounty (retires utility FIGHT bounty) →
  #1d aggressive monsters + Scurrius gate → #1e instrumented sweep +
  BRAIN_V2 4th test.

## Next steps (in order)
1. Finish Unit 0 sub-items, gating + committing each.
2. Unit 0 closing sweep with monoculture/rival-lean metrics (R6); record
   whether the §18 prediction held in the decisions log.
3. Unit 1 (catalog migration, punch #2) — resolves KI-8, renames GE_TAX.

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
- Save-version mismatch silently discards saves until #1a lands (KI-3).
- Any new sim RNG draw perturbs the seed stream → re-baseline sweeps.
- Don't chase the stale "600–900" gold band; the validated band moved
  (see `02-ARCHITECTURE.md`).
- The probe was READ-ONLY by instruction: known cleanups (dead `_route*`
  code, snapshot dirs, Economy-vs-items.json base-value mismatch) were
  deliberately left untouched.
