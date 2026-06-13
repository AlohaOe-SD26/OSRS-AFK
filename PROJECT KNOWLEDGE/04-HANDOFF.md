# Handoff — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place, CONTINUOUSLY. A new agent with zero
> context must be able to resume from this file alone.

**Repository:** https://github.com/AlohaOe-SD26/OSRS-AFK
**Last updated:** 2026-06-13

## What is this project?
A Godot 4.6.3 single-player idle/tycoon "ant farm" in canon OSRS Varrock:
autonomous utility-brain heroes gather/fight/trade/socialize; the player
steers (incentivize/nudge/seize) and invests a tax-fed treasury. Read
`00-README.md` → `01` → `02` for the full picture. The live build is
`game/`; the `gielinor-tycoon-(*)` dirs are STALE snapshots.

## Current state
**MVP + UNIT 0 (Slayer) + UNIT 1 (catalog) + UNIT 2 (shop economy v2)
COMPLETE 2026-06-13** — suite **179/179** + determinism/save-load/offline
gates green; save version **5**. The CATALOG (items.json via ContentDB) is
the single item truth. Unit 2 shipped: 7-shop roster as data, dynamic buy
pricing, treasury ledger (40% purchase routing), player price-bias lever
(clamp 0.70/1.30), and the KI-4 closing sweep. **Day-23 per-capita band
re-baselined to 1,501 ± 235** (8 seeds, the shipping config = #3d control
arm; supersedes 1,460±332 — tighter variance, mean inside the old band).
`COMBAT_CONGESTION_MULT` stays **0.5** — #3d found NO shippable combat-side
KI-4 mitigation (see below), so KI-4 stays OPEN (structural). Three
falsified levers stay default-OFF: M2 BRAIN_V2, the #3d gear-drop reward
coupling (`COMBAT_GEAR_REWARD`), and congestion 1.0 (gate-blocked) — all
detailed in KI-4.

## What was just done (this session, 2026-06-13)
- **Unit 2 (#3) CLOSED — #3c shipped a lever; #3d was a negative result.**
  #3c: ran `diag_bias.gd`, locked `PRICE_BIAS_MIN/MAX` 0.70/1.30 (binding
  axis = treasury funding; 150% overpay breaks funding). #3d: built the
  combat **gear-drop reward coupling** (flag `COMBAT_GEAR_REWARD` +
  `Economy.gear_board_ref_price()` + gated `gear` brain term, default OFF,
  +3 suite checks → 179), then ran the closing sweep
  `tools/diag_unit2_close.gd` (6 arms, 8 seeds × 23 days). **OUTCOME: no
  shippable mitigation — #3d ships ZERO behavior change.** Gear-coupling
  FALSIFIED (ON worsens monoculture at every level — positive reward, board
  floors at ~11–17). Congestion 1.0 DOES drop monoculture 28→23% without
  cratering kills, BUT its higher variance (g/cap SD ±355 vs ±235) breaks
  the OFFLINE gate (seed beef01 closest-tail Δ31% vs ≤25%) — caught by
  running the gates after the metric-based lock, so REVERTED to 0.5. 0.75
  destabilizes g/cap (1082±470). Closing band re-baselined at the shipping
  config (0.5/off): **1,501 ± 235**. KI-4 stays OPEN. Suite **179/179**; all
  3 gates PASS at 0.5/off (the gear lever is inert at default — identical
  hashes). Full arm table + the process-correction note in 06-DECISIONS-LOG.

## Earlier (session 2026-06-12)
- **#3c price-bias lever BUILT** (mechanics + UI + save v5 + 7 checks;
  clamp sweep authored, run+locked the following session).
- **Directive batch recorded** (2026-06-12, from the user): the COINPURSE
  INVARIANT locked in the decisions log (hero gold never pools); punch
  items **#13** (founders fully rolled), **#14** (immigrant gold in
  economy-fitted rolled bands), **#15** (immigrant gear rolls), **#16**
  (Legendary & Easter-Egg arrivals, GE-gated per-run) — full specs in
  03-PUNCH-LIST.
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
- **Nothing mid-flight.** Unit 2 (#3) is closed and pushed; the tree is
  green at the new defaults. Next is a fresh unit (Unit 3, #4) — not yet
  started.

## Next steps (in order)
1. **Unit 3 (C1 nudge popups + B4 gating, punch #4)** per R11/R7 — Control
   nodes for new popups only, shared visual constants, render-layer only,
   decisions-log entry on the paradigm split. `loot_policy` = drop-filter
   semantics (R7). Fight popup after #1; Skill popup can float earlier.
2. New directive items **#13–#15** (random founders / immigrant gold
   bands / gear rolls — full specs in the punch list). They anchor on the
   gold attractor, so use the FRESH band **1,501 ± 235** (now re-baselined);
   each wealth change re-runs the band sweep. **#16** (Legendary arrivals)
   waits on Unit 4's GE + achievements.

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
