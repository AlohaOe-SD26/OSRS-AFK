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
**MVP COMPLETE; UNIT 0 (Slayer) + UNIT 1 (catalog migration) COMPLETE
2026-06-12** — suite **153/153** + determinism/save-load/offline gates
green; save version **3**. The CATALOG (items.json via ContentDB) is the
single item truth: canon ids are the inv/equip/shop keys, prices anchor on
catalog base values (KI-8 resolved), gear/recipes/tradeable flags are
data. Day-23 per-capita band **1,460 ± 332** (8 seeds; single-seed
telemetry now reads ~1,790, +4% drift — within 1σ). M2 BRAIN_V2
default-OFF (4th test failed it — see KI-4).

## What was just done (this session, 2026-06-12)
- **Unit 2 #3a+#3b SHIPPED** (punch #3, rulings R1/R3): 7-shop roster as
  data (`data/shops.json` — Horvik/Lowe/Zaff/Aubury/Swordshop + the 2
  incumbents; gear re-routed to specialists), per-good dynamic buy pricing
  (`Shop.charge_price` anchored to the validated flat costs), stock-gated
  purchases via `Economy.buy_item`, C5 ambient imports (`import_tick`,
  K=0.5/day; **ammo baselines tuned 8→60** after a measured supply cliff —
  kills −25%, the R3 anti-pattern), tier-up unlocks (buy-side only),
  **40% purchase→treasury routing + 5-counter ledger + telemetry line**,
  save v4 + v3→v4 upgrader. **Offline-gate criterion v2** (re-entry +
  runaway guard; endpoint-only Δ was decoupled-run noise — see decisions).
  Suite **169/169**; 3 gates PASS; drift −2%, kills 20.8k.
- Earlier today: **Unit 1 (catalog migration, #2) SHIPPED** — KI-8
  resolved, canon ids everywhere, save v3; and **Unit 0 closed** (#1e
  sweep: on-task +20 locked, §18 split verdict, BRAIN_V2 stays OFF, band
  1,460±332).

## In progress (and how far along)
- **Unit 2 (punch #3): #3a ✅ #3b ✅ — #3c and #3d remain.**
  - #3c: player price-bias lever (per-good sell-price multiplier) +
    swept clamp (expect narrower than 50–150%) + Town-tab UI row.
  - #3d: KI-4 counter-force sweep (COMBAT_CONGESTION_MULT {0.5/0.75/1.0}
    ± gear-drop reward coupling; two-sided criterion: monoculture must
    drop from ~44%, combat must not crater) + closing band re-baseline.

## Next steps (in order)
1. **#3c** price-bias lever (see punch list for spec).
2. **#3d** KI-4 sweep + lock + Unit-2 closing band report.
3. Unit 3 (C1 nudge popups + B4 gating, punch #4) per R11/R7.

## How to run / build / test
```
godot --headless --path game --script res://tests/test_sim.gd   # 169 checks
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
