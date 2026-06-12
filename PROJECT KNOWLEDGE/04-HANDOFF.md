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
**MVP COMPLETE** — build steps 0–6 all closed and green (101/101 suite +
determinism/save-load/offline gates). Economy attractor validated; current
day-12 per-capita band ~1,065–1,211, drift +2–6%. Post-MVP merge plan in
progress: M1 visual port ✅ · M2 brain-v2 measured (default-off) · M3
content waves underway (gear/equipment/smithing/zones-slice-1 done).

## What was just done (this session, 2026-06-12)
- **#1c funded bounty SHIPPED** (R5): `set_bounty` 0–3× avg drop, one
  affordability rule for payment AND attraction, per-kill treasury→hero
  payout, utility FIGHT incentive retired, Town-tab bounty row.
- **#1d aggressive monsters + Scurrius SHIPPED**: aggro chase/strike,
  shared death handler (gravestone grudges + rep dents LIVE), Scurrius
  behind 300 rat kills. First cut was a meat grinder (2,096 deaths/24k
  ticks, rep pinned 0); fixed with the canon survival triad — passive
  regen (1 HP/min off action_n), aggression tolerance (`tol_t` 8s
  arrival-tax; also restored goblin culling 96→3,730), brain danger term,
  lair-bound bosses. Measured: deaths 4/24k ticks, rep 61, Scurrius slain
  16×. Suite 141/141; determinism/save-load/offline gates green; render
  parses.
- Fixed a malformed `.claude/settings.local.json` allow-entry
  (`Bash(python -c ' *)`) that crashed the permission matcher.

## In progress (and how far along)
- **Punch #1 — Unit 0: Slayer slice**: #1a ✅ #1b ✅ #1c ✅ #1d ✅ — only
  **#1e remains** (instrumented closing sweep + BRAIN_V2 4th test).

## Next steps (in order)
1. **#1e**: Unit-0 closing sweep with monoculture/rival-lean metrics (R6;
   multi-seed — single-seed is RNG-confounded); record whether the §18
   prediction held in the decisions log. NOTE: per-capita gold drifted to
   ~1,485 (validated band was 1,065–1,211; fewer deaths/flees = more
   productive hours) — re-baseline the band as part of this sweep.
2. BRAIN_V2 4th test (activity breadth now widened — decision point).
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
- Save-shape changes MUST bump SAVE_VERSION and append an upgrader to `SaveLoad._chain()` (the #1a scaffold) — never ship a schema change without one.
- Any new sim RNG draw perturbs the seed stream → re-baseline sweeps.
- Don't chase the stale "600–900" gold band; the validated band moved
  (see `02-ARCHITECTURE.md`).
- The probe was READ-ONLY by instruction: known cleanups (dead `_route*`
  code, snapshot dirs, Economy-vs-items.json base-value mismatch) were
  deliberately left untouched.
