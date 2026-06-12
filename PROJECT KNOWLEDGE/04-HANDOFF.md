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

## What was just done (last session, 2026-06-11)
- **Read-only probe + `ANALYSIS REPORT/`** answering an external design
  partner's economy/incentives prompt (`readthis.md` in root): full Part-A
  system probe with verbatim constants, fit assessment of reference-build
  shop/Slayer/HUD mechanics (B1–B4) and new features (C1 parameterized
  nudges, C2 GE order book + city buy orders, C3 city inventory + item-cost
  upgrades, C4 shop sell-back, C5 crafting+imports), punch-list integration
  proposal, and 12 design questions. **No code changed.**
- Seeded this PROJECT KNOWLEDGE folder (was an empty bootstrap skeleton).

## In progress (and how far along)
- Nothing mid-flight in code. **Holding for design rulings** on the
  ANALYSIS_REPORT questions before B/C features become work items.
- Punch-list #1 (zones slice 2: Slayer + aggressive monsters) is the queued
  next build item and will absorb spec B2 once rulings arrive.

## Next steps (in order)
1. Receive design rulings → convert ANALYSIS_REPORT Parts B/C into concrete
   punch-list scope (see `03-PUNCH-LIST.md` #1–#6 placeholders).
2. Build punch #1 (Slayer slice) under the standard gates.
3. **First commit + push** (see Gotchas — the repo has NO commits yet).

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
- **⚠️ EVERYTHING IS UNPUSHED:** git has a remote but ZERO commits — the
  whole project is staged-only (KI-1). First action of the next build
  session should be an initial commit + push.
- Save-version mismatch silently discards saves (no migrations — KI-3).
- Any new sim RNG draw perturbs the seed stream → re-baseline sweeps.
- Don't chase the stale "600–900" gold band; the validated band moved
  (see `02-ARCHITECTURE.md`).
- The probe was READ-ONLY by instruction: known cleanups (dead `_route*`
  code, snapshot dirs, Economy-vs-items.json base-value mismatch) were
  deliberately left untouched.
