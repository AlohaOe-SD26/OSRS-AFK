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
- **Unit 1 — catalog migration SHIPPED** (punch #2, KI-8 RESOLVED):
  canon-id rename across ~81 sites (ore→iron_ore, cooked_fish→trout,
  display-name gear/tools/ammo→catalog ids); Economy.new(content) sources
  bases from the catalog; GEAR_DROPS/GEAR_TIER retired into items.json
  (dropPool/tier/style); recipes-as-data (`ContentDB.craft_output` powers
  cook + smith); **shops trade gear** (General-Store board, fill-0.5 open
  ≈ the old half-value anchor, flat vendoring retired); `GE_TAX`→
  `SHOP_TAX` (R8); save v3 + v2→v3 upgrader (id remap + gear-board
  injection — frozen inline values). +12 suite checks.
- Earlier today: **#1e closing sweep + BRAIN_V2 4th test → Unit 0 closed**
  (on-task locked +20; §18 split verdict — KI-5 resolved, KI-4 confirmed
  structural; BRAIN_V2 stays OFF; band re-baselined 1,460±332).

## In progress (and how far along)
- Nothing mid-flight. Units 0 and 1 fully closed.

## Next steps (in order)
1. **Unit 2 (shop economy v2, punch #3)** per rulings R1/R3: per-good
   dynamic buy pricing, price-bias lever (swept clamp), ambient imports/
   restock, tier-up stock unlocks, roster expansion (Horvik/Lowe/Zaff/
   Aubury/Swordshop), purchase→treasury routing at 40% (tune 30–50%).
   **Design the KI-4 fix into this unit** (combat reward saturation /
   price coupling) while pricing files are open.
2. Unit 3 (C1 nudge popups + B4 gating, punch #4) per R11/R7.

## How to run / build / test
```
godot --headless --path game --script res://tests/test_sim.gd   # 153 checks
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
