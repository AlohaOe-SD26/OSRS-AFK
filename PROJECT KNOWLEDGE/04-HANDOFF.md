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
**MVP + UNIT 0–2 COMPLETE; UNIT 3 (#4) CODE-COMPLETE (F5-pending); DIRECTIVE
BATCH #13–#15 COMPLETE; UNIT 4 (#5) — #5a bank + #5b GE order book + #5c city
orders shipped 2026-06-14 (#5d/#5e remain).** suite **229/229** + determinism/
save-load/offline gates green; save version **9**.
**Day-23 per-capita band = 1,384 ± 174** (8 seeds, the full rolled stack:
founders + immigrant gold/weapon/gear — variance tightened across the batch,
deaths down, all colonies viable, ≥1 fisher; within noise of the original
1,501±235). Characters are now fully rolled: founders (favorite/weapon/gold
20–100/name/look/spawn; `Config.FOUNDERS_LOCKED` ON = old template, suite-pinned)
and immigrants (favorite/weapon/gold=tiered fraction of `GOLD_ATTRACTOR_REF`
1482/boost-scaled gear). **OUTSTANDING: an F5 visual sign-off on Unit 3** (#4b
dim-buttons + tooltip; #4c "Custom nudge…" Control-node popup) — render-only,
unverifiable headless; everything else (sim/logic/parse) is green. The CATALOG (items.json via ContentDB) is
the single item truth. Unit 2 shipped: 7-shop roster as data, dynamic buy
pricing, treasury ledger (40% purchase routing), player price-bias lever
(clamp 0.70/1.30). **Day-23 per-capita band 1,501 ± 235** (8 seeds, shipping
config). `COMBAT_CONGESTION_MULT` stays **0.5** — #3d found NO shippable
combat-side KI-4 mitigation, so KI-4 stays OPEN (structural). Three falsified
levers stay default-OFF: M2 BRAIN_V2, the #3d gear-drop reward coupling
(`COMBAT_GEAR_REWARD`), congestion 1.0 (gate-blocked) — all detailed in KI-4.
**Unit 3 #4a (parameterized-nudge sim core + loot-filter) is shipped**; #4b
(feasibility gating) and #4c (Control-node popups, needs F5) remain.

## What was just done (this session, 2026-06-13/14)
- **#5c SHIPPED — Unit 4 city buy orders + city inventory.** `city_post_buy_order`
  (treasury escrow via the #5b engine, owner=-1) + `city_inventory`;
  `ge_sell_into_orders` wired before the FSM's NPC sell (a selling hero fills
  standing buy orders at the NPC-price floor, takes the resting buy's price −1%
  tax). Save **v9**. INERT (empty book → sell path byte-identical → no
  re-baseline). Suite **229/229**; 3 gates PASS. The R5 end-state (autonomous
  gather-for-orders + retiring utility incentives + GE unlock) is #5e.
- **#5b SHIPPED — Unit 4 GE order book ENGINE.** `ge_orders` + `ge_post_order`/
  `ge_match`/`ge_cancel_order`: price-time priority matching (fill at the resting
  price), escrow at posting (R1; sell→goods, buy→gold/treasury), 1% `GE_TAX` on
  seller proceeds → treasury (`treasury_in_ge_tax`, R8), refunds buy→bank (R9) /
  sell→inv. `ge_unlocked` flag. Save **v8**. INERT in live play (no autonomous
  posting → empty book → no re-baseline). Suite **224/224**; 3 gates PASS.
  DEFERRED to later sub-items: relationship tilt, autonomous trading (#5c),
  offline fill (#5d), GE unlock (#5e).
- **#5a SHIPPED — Unit 4 BANK foundation (R9).** `Hero.bank` (per-hero,
  coinpurse invariant) + `bank_deposit/withdraw/total`; `total_gold()` counts
  coinpurse+bank; upkeep now on TOTAL wealth (purse-then-bank → banked gold
  can't dodge the attractor); death-transfer leaves the bank untouched. Save
  **v7** (`_migrate_6_to_7`). Inert until #5b (empty bank → live sim
  byte-identical, gates pass, no re-baseline). Suite **217/217**; 3 gates PASS.
  Unit 4 decomposed into #5a–#5e (punch list) with the open economic questions.
- **#15 SHIPPED — immigrant gear rolls (directive batch #13–#15 COMPLETE).**
  Arrivals roll starting gear scaled by rarity tier: `ContentDB.equippable` +
  `_roll_arrival_gear` (armor head/torso/off, equip-prob `0.15+boost×0.02`,
  tier-2 chance `boost×0.025`; fighter main upgrades style-matched). No save
  bump. Final batch band **1,384 ± 174** (variance tightened ±448→±269→±174,
  deaths down — equipped arrivals survive better; all viable). Suite **210/210**
  (+5 checks); 3 gates PASS.
- **#14 SHIPPED — immigrant gold in economy-fitted bands + rolled weapon.**
  `NEWCOMER_TIERS` gold → `gold_frac` (fraction of `GOLD_ATTRACTOR_REF` 1482):
  Greenhorn 1–3% … Elite 18–30% (≈267–445g, bounded < g*), rolled per arrival;
  immigrant fighters roll weapon style (id%3 retired). No save bump. Band
  re-baselined **1,337 ± 269** (within-noise; all viable). Suite **205/205**
  (+6 checks); 3 gates PASS.
- **#13 SHIPPED — founders fully rolled (random character generation).** Every
  founder is ROLLED on the seeded RNG: favorite (viability floor ≥1 fisher),
  weapon style (fighters; `id%3` retired), gold (band 20–100), name, appearance,
  spawn inside the city walls. `Config.FOUNDERS_LOCKED` debug flag (OFF=rolled,
  ON=byte-identical old template — the suite pins ON for role-stable tests; +7
  rolled-path checks). `_new_hero` gained a `weapon` param (the #14/#15 hook). No
  SAVE_VERSION bump. **Band re-baselined to 1,482 ± 448** (`diag_founders.gd`, 8
  seeds — mean preserved, variance up; all viable). Suite **199/199**; 3 gates
  PASS; determinism hash re-baselined. WATCH (KI-10): widened g/cap spread + one
  high-death seed (7a11, 50 deaths, alive).
- **Unit 3 #4c CODE-COMPLETE — Control-node parameterized nudge popup (R11).**
  New `render/NudgePopup.gd` (the project's FIRST Godot Control-node UI): a
  modal popup with an activity OptionButton, trip-length min/max SpinBoxes
  (#4a count_range), and a fights-only loot-policy OptionButton (#4a filter);
  #4b feasibility disables the Nudge button + shows the reason. Palette mirrors
  the HUD (R11 cond. 2); render-layer only — emits `submitted(intent, params)`,
  Main dispatches via `nudge_hero(...)`. Opened by a "Custom nudge…" command-
  row button on a CanvasLayer. **Paradigm split LOGGED** (06-DECISIONS-LOG:
  complex forms → Control nodes; HUD → immediate-mode). Target/monster routing
  DEFERRED (one combat camp; FSM mon-routing unwired). Suite **192/192**; 3
  gates PASS; both files parse. **The VISUAL needs an F5 pass.**
- **Unit 3 #4b SHIPPED — B4 feasibility gating.** `SimWorld.nudge_feasible(h,
  intent) -> {ok, reason}` (feasible if the hero can act now, allowing an
  affordable buy step; disabled only when categorically blocked, or seized).
  Render: `Main._button` gained enabled/tip — an infeasible NUDGE button draws
  dim, absorbs its click ("noop" kind so it never deselects the hero), and
  shows a hover-tooltip with the reason (new `_tips`/`_mouse_pos`/
  `_draw_tooltips` layer). Seized direct commands stay un-gated. +6 suite
  checks → **192/192**; 3 gates PASS; Main.gd parses. **VISUAL (dim buttons +
  tooltip) needs an F5 pass — render-only, unverifiable headless.**
- **Unit 3 #4a SHIPPED — parameterized-nudge SIM CORE + loot-filter.**
  `nudge_hero(h, intent, params={})` takes optional per-trip params
  (loc / count_range / loot_policy / mon / suggested_items); the won nudge
  rolls `count_range` (seeded) into `act["count_target"]` (the FSM reads it at
  the FIGHT/gather/fish completion sites) and carries `act["loot_policy"]`
  (the `SimWorld.loot_keeps` drop-filter in `_gear_drop`: keep-all /
  upgrades-and-valuables≥40g / salvage-all; R7, NOT ground loot). The new RNG
  roll fires ONLY on the parameterized path, so autonomous play is byte-
  identical (gate hashes 3974639208 unchanged — no re-baseline). Save **v5→v6**
  (`_migrate_5_to_6`, forward-compatible — new keys optional/default-guarded).
  +7 suite checks → **186/186**; 3 gates PASS. Plain nudges = unchanged.
- **Unit 2 (#3) CLOSED earlier today — #3c shipped a lever; #3d was a negative result.**
  #3c: ran `diag_bias.gd`, locked `PRICE_BIAS_MIN/MAX` 0.70/1.30 (binding
  axis = treasury funding; 150% overpay breaks funding). #3d: built the
  combat **gear-drop reward coupling** (flag `COMBAT_GEAR_REWARD` +
  `Economy.gear_board_ref_price()` + gated `gear` brain term, default OFF),
  then ran the closing sweep `tools/diag_unit2_close.gd` (6 arms, 8 seeds ×
  23 days). **OUTCOME: no shippable mitigation — #3d shipped ZERO behavior
  change.** Gear-coupling FALSIFIED (ON worsens monoculture at every level).
  Congestion 1.0 DOES drop monoculture 28→23% without cratering kills, BUT its
  higher variance (g/cap SD ±355 vs ±235) breaks the OFFLINE gate (seed beef01
  closest-tail Δ31% vs ≤25%) — caught by running the gates after the
  metric-based lock, so REVERTED to 0.5. 0.75 destabilizes g/cap (1082±470).
  Closing band re-baselined at the shipping config: **1,501 ± 235**. KI-4
  stays OPEN. Full arm table + process-correction note in 06-DECISIONS-LOG.
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
- **Unit 3 (punch #4): #4a ✅ · #4b ✅ · #4c ✅ (code) — ONE F5 VISUAL
  SIGN-OFF OUTSTANDING.** All code is shipped, green, and parses. The only
  remaining step is a human F5 pass to confirm the render visuals:
  1. Open the app (F5 in Godot), click a hero → hero popup.
  2. **#4b:** when the hero lacks a tool/weapon/food and can't afford it, the
     matching nudge button (Mine/Fight/…) should be DIM and show a reason
     tooltip on hover; clicking it should do nothing (not deselect).
  3. **#4c:** click "Custom nudge…" → the Control-node popup opens; pick an
     activity, set the trip-length min/max, (for Fight) a loot policy, hit
     Nudge → the hero takes the parameterized trip; infeasible activity →
     Nudge disabled + reason shown.
  If anything looks wrong, that's the next fix; otherwise tick the F5 box and
  Unit 3 is closed.
- **#13 + #14 + #15: DONE** (directive batch). **Unit 4 (#5): #5a bank + #5b GE
  engine + #5c city orders DONE; #5d/#5e remain** (decomposed in the punch list).
  No code item is mid-flight (each sub-item ships green & inert until wired).

## Next steps (in order)
1. **#5d — Offline statistical fill** for GE + city orders (orders fill while
   away, bounded like `offline_catchup`; the #5a bank is the gold landing target).
   The offline-gate criterion must hold. Likely still inert-ish (no live orders
   yet) — testable in isolation.
2. **#5e — Incentive migration + GE unlock (the economically-LIVE step, R5 end
   state):** make the city autonomously post buy orders (or the player UI), add
   the brain pull toward gathering-for-orders, retire the pure-utility gather
   incentives, and add the GE-unlock mechanism (recommended: Gate-1
   combat-40/reputation gates availability + a treasury-funded GE-annex building
   flips `ge_unlocked`; per-run, see the 2026-06-14 GE-unlock answer). THIS is
   where the book goes non-inert → add GE state to sim_hash + the closing band
   RE-BASELINE + the shop→GE tax-migration report (R8). Also revisit the deferred
   relationship-tilt (`Social.trade_modifier`) and whether total_gold counts
   escrowed/city gold.
2. **F5 sign-off on Unit 3** (#4b/#4c visuals — checklist above) — the one
   non-code thread; can happen anytime, independent of Unit 4.
3. **#16** (Legendary & Easter-Egg arrivals) — gated behind Unit 4's GE + an
   achievement record; the immigration template-override hook is the
   `_new_hero`/`spawn_immigrant` path built out by #13–#15.

## How to run / build / test
```
godot --headless --path game --script res://tests/test_sim.gd   # 229 checks
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
