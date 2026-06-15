# Handoff — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place, CONTINUOUSLY. A new agent with zero
> context must be able to resume from this file alone.

**Repository:** https://github.com/AlohaOe-SD26/OSRS-AFK
**Last updated:** 2026-06-14

## What is this project?
A Godot 4.6.3 single-player idle/tycoon "ant farm" in canon OSRS Varrock:
autonomous utility-brain heroes gather/fight/trade/socialize; the player
steers (incentivize/nudge/seize) and invests a tax-fed treasury. Read
`00-README.md` → `01` → `02` for the full picture. The live build is
`game/`; the `gielinor-tycoon-(*)` dirs are STALE snapshots.

## Current state
**MVP + UNIT 0–2 COMPLETE; UNIT 3 (#4) CODE-COMPLETE (F5-pending); DIRECTIVE
BATCH #13–#15 COMPLETE; UNIT 4 (#5) FUNCTIONALLY COMPLETE 2026-06-14 — bank +
GE order book + city orders + GE unlock + funded gather incentive LIVE + #5d
offline order-fill (only the R5 utility-incentive retirement remains as an
optional cleanup). UNIT 5 (#6) CODE-COMPLETE (F5-PENDING) — #6a C3 item-cost
upgrade ladders + #6b C5 shop crafting queues + #6c C4 sell-back ceiling + #6d
TOWN-panel UI all SHIPPED 2026-06-14 (the full C2→C3/C5 loop + the mint reshape
+ the controls); only a combined F5 visual sign-off remains.**
suite **267/267** + determinism/save-load/offline gates green; save version
**10**. **C4-active band re-baselined: g/cap 707 ± 208** (GE open + sell-back,
8 seeds; was 1,378 ± 331 pre-C4 — the designed mint cut, attractor holds, all
colonies alive, deaths 14 ± 9 / WATCH KI-11). GE-active band 1,378 ± 331 (≈ the GE-locked band 1,384 ± 174 — attractor
holds with the GE live).
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
- **#6d SHIPPED (code) — Unit 5 TOWN-panel UI (render-only, F5-pending).** The
  TOWN panel now surfaces all three Unit-5 mechanics (immediate-mode HUD):
  #6a the shop upgrade button gated on `can_upgrade_shop` + an item-cost
  tooltip; #6b a **TOWN CRAFTING** subsection (`_draw_crafting`: city-stock
  readout, feasibility-gated quick-craft presets, the live queue with ✕ cancel;
  new `craft`/`cancel_craft` dispatch + `SimWorld.can_queue_craft`); #6c a
  **sell-back venue** readout (shop pay vs best, "(GE-capped)" flagged). Main.gd
  parses; suite **267/267**; 3 gates PASS. **The VISUAL needs an F5 pass** —
  joins the Unit-3 #4b/#4c F5 queue. **Unit 5 is CODE-COMPLETE.**
- **#6c SHIPPED — C4 shop sell-back ceiling (the mint-touching keystone).** Once
  the GE opens, `Economy.sell_price` ceilings at `min(saturation, 0.30 × base_value)`
  (`sell_back_active`, kept in sync with `ge_unlocked` by a SETTER). Shops become
  the bad buyer; funded GE/city orders win → trade goes GE-ward (the player runs
  procurement). New `Economy.reference_price` (uncapped) feeds the gather glut term
  + the city-order premium so the cut doesn't collapse the incentive;
  `best_sell_price` keeps the ceilinged shop (the steering). GRACEFUL DEGRADATION:
  GE locked → inert → gates byte-identical. No save bump. **RE-BASELINE
  (diag_ge = GE open + C4, 8 seeds × 23 days): g/cap 707 ± 208** (was 1,378 ± 331)
  — the designed mint cut; the attractor HOLDS (bounded, re-pinned lower), pop
  41 ± 1, ALL colonies alive, deaths 14 ± 9 (WATCH KI-11). Shipped per the user's
  "0.30 as written" ruling (the agreed revert-if-broken criterion was not
  triggered). Suite **267/267** (+7); 3 gates PASS (byte-identical, GE-locked).
- **#6b SHIPPED — C5 shop crafting queues (the second C2→C5 drain).** A
  single-server FIFO `craft_queue` on SimWorld: `queue_craft(shop, output, qty)`
  RESERVES the recipe inputs from `city_inventory` at enqueue, the FRONT job
  accrues sim-time (`_craft_advance`, `CRAFT_DAYS_PER_UNIT` 0.5) and produces
  output into that shop's `stock` (room-gated backpressure; output must be a good
  the shop vends → guaranteed buyer = the gold-sink); `cancel_craft` refunds the
  unmade inputs. Recipes-as-data (`ItemType.recipe`); `Economy.shop_by_id` added.
  Runs live (per work-action) and offline (`offline_catchup` replays the window in
  sim-days). **Save v9→v10** (`_migrate_9_to_10`). INERT on an empty queue →
  live/gates byte-identical. Suite **260/260** (+8); 3 gates PASS. The C2→C3/C5
  closed loop now has BOTH drains (C3 upgrades + C5 crafting).
- **#6a SHIPPED — Unit 5 opens: C3 item-cost upgrade ladders.** Shop level-ups
  now cost city-inventory ITEMS as well as treasury gold — the existing
  `SimWorld.upgrade_shop` gained `shop_upgrade_item_cost` (Config ladder
  `SHOP_UPGRADE_ITEM_COST` {logs 15, iron_ore 10}, geometric per level) +
  `can_upgrade_shop` (level + gold + items); ALL-OR-NOTHING (no partial spend).
  This DRAINS what C2 city-buying accumulates (logs/iron_ore) — the first half of
  the C2→C3/C5 closed loop. `Economy.try_upgrade_shop` untouched (gold primitive,
  suite-pinned). No save bump. Suite **252/252** (+7); 3 gates PASS
  (byte-identical — upgrades are a player action, never autonomous).
- **#5d SHIPPED — offline statistical fill (Unit 4 refinement closed).** Standing
  BUY orders now fill while the player is away: `_offline_fill_orders` (end of
  `offline_catchup`) delivers each order from the colony's offline gathering supply
  for that good, bounded by the SAME per-good throughput as the gold accrual (a
  single order can't fill faster than live gathering would). Goods land for the
  buyer (city → `city_inventory`, hero → inv); seller proceeds (gross − GE_TAX) →
  the gatherers' **BANK** (`_bank_split_to_gatherers`, per-hero, no pool); tax →
  treasury. Escrow was taken at posting → this only MOVES escrow → banks (no gold
  creation, like live `_ge_execute`). Pure function of the capped dt →
  `gain(30h)==gain(24h)`. **INERT with an empty book (GE-locked) → offline gate
  byte-identical (PASS, cap clamps 22096==22096).** No save bump. Suite **245/245**
  (+7); 3 gates PASS. Logged simplification (goods are gold-abstract offline → a
  tiny bounded shop-value double-count on filled units; errs toward the player §4).
- **#5e-2 SHIPPED — funded gather incentive goes LIVE (the attractor holds).**
  Brain gather reward reads `best_sell_price` = max(shop, best buy order) → a
  funded city/GE order pulls labor (1.6→15.3 on GATHER_LOGS); `_auto_city_orders`
  daily (town posts 1 buy order/gather-good at 1.5× shop, escrow ≤25% treasury,
  self-limiting); sim_hash gains a GE-state line. **RE-BASELINE (diag_ge.gd, GE
  open all run, 8 seeds): g/cap 1,378 ± 331 — mean ≈ the locked band 1,384±174,
  the upkeep attractor absorbs the re-injection faucet, all colonies alive.**
  Suite **238/238**; 3 gates PASS (GE-locked). Deferred refinements: retire
  utility gather incentives (R5 cleanup; breaks the incentive test), #5d offline
  fill, relationship tilt. **Unit 4 is functionally COMPLETE.**
- **#5e-1 SHIPPED — Unit 4 GE unlock.** A `ge_annex` building (1500g) opens the
  Grand Exchange (`build("ge_annex")` → `ge_unlocked`), gated on Gate-1
  (`gate1_reached()` = any hero Combat 40, the canon road-north milestone);
  one-shot, per-run; render button gated. No save bump (`ge_unlocked` already
  serialized). Inert in autonomous play (flag only flips on a player build).
  Suite **232/232**; 3 gates PASS. **#5e-2 (the live-economy step) remains.**
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
- **Unit 5 (punch #6): #6a/#6b/#6c ✅ · #6d ✅ (code) — F5 VISUAL SIGN-OFF
  OUTSTANDING** (same combined pass). Open the menu → Colony tab → TOWN panel:
  1. **#6a:** a shop whose upgrade you can't afford (missing city materials)
     shows a DIM upgrade button; hovering it shows "cost: Ng + <items>".
  2. **#6b:** the **TOWN CRAFTING** section lists city stock + "Craft 5× <item>"
     buttons (dim with a "needs …" tip when materials are short); clicking an
     enabled one adds a job; the queue shows "✕ made/qty <item>" — clicking ✕
     cancels and refunds. (Easiest to exercise with the GE open + treasury, so
     city orders fill the inventory; iron_sword from iron_ore is the reliable one.)
  3. **#6c:** the **sell-back venue** line shows "shop pay / best" per gather
     good; once the GE is open it's labelled "(GE-capped)" and the shop number
     drops well below "best".
  If it reads right, tick the box — Unit 5 is closed.
- **#13 + #14 + #15: DONE** (directive batch). **Unit 4 (#5): FUNCTIONALLY
  COMPLETE** — #5a bank + #5b GE engine + #5c city orders + #5e GE unlock +
  funded gather incentive live + #5d offline order-fill, all shipped/green.
- **Unit 5 (#6): CODE-COMPLETE (F5-pending).** **#6a ✅ · #6b ✅ · #6c ✅ · #6d
  ✅ (code).** All sim/logic/render shipped & green; the only remaining thread is
  a combined F5 visual sign-off (Unit-5 TOWN-panel UI + Unit-3 #4b/#4c). No code
  item mid-flight.

## Next steps (in order)
1. **Next big unit — pick one (Units 4 & 5 are code-complete):**
   - **#7 — Content wave (e):** death/graves/PK → canon social negatives (retire
     the interim competition-friction). Pairs naturally with KI-11 (deaths rose
     under C4) — graves give those deaths narrative + social weight.
   - **#16 — Legendary & Easter-Egg arrivals** (now unblocked — the GE is built):
     the immigration template-override hook is the `_new_hero`/`spawn_immigrant`
     path from #13–#15; needs a per-run unlock/achievement record that resets
     with prestige.
   - **#8/#9** — buildings/reincarnation; Zezima endgame (later waves).
2. **Unit-4 refinements (optional, not blockers; #5d done):** the R5 cleanup to
   retire the pure-utility gather incentives (breaks the existing incentive test,
   needs rewriting; the utility lever sits unused at 0 autonomously); the deferred
   relationship-tilt (`Social.trade_modifier`); whether `total_gold` should count
   escrowed/city gold. Each is a small, contained follow-up.
3. **F5 sign-off on Unit 3** (#4b/#4c visuals — checklist above) — the one
   non-code thread; anytime, independent.
4. **#16** (Legendary & Easter-Egg arrivals) — gated behind Unit 4's GE (now
   built) + an achievement record; the immigration template-override hook is the
   `_new_hero`/`spawn_immigrant` path built out by #13–#15.

## How to run / build / test
```
godot --headless --path game --script res://tests/test_sim.gd   # 267 checks
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
