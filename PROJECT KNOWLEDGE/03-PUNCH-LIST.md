# Punch List — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. The agreed work queue — single source of
> truth (materialized 2026-06-11 from the agent-memory status ledger; full
> history in `ANALYSIS REPORT/STATUS_DOCS/AGENT_MEMORY_project-status.md`).
> Item format: `- [ ] #N — description` (N never reused; completed items move
> to Done with the date).

## Now (active focus) — Unit 4: bank + GE + city orders (punch #5)
> Unit 2 (#3) CLOSED, directive batch #13–#15 CLOSED — full entries in Done.

### Awaiting verification
- [~] #4 — Unit 3 nudge popups: **CODE-COMPLETE (#4a/#4b/#4c all shipped &
  green, suite+gates), ONE F5 VISUAL SIGN-OFF OUTSTANDING** (#4b dim-buttons +
  tooltip; #4c "Custom nudge…" Control-node popup — render-only, unverifiable
  headless). F5 checklist in 04-HANDOFF. Sub-item detail in Done once F5 ticks.

### Unit 4 (#5) — the big gold-ledger unit
- [ ] #5 — Unit 4: Bank + GE order book + City BUY orders + City Inventory
  (sweep g* before/after; offline statistical fill). RULED: bank ships WITH the
  order book (R9 — refunds need a deposit target); city buy orders escrow
  treasury at posting, cancel/expiry refunds remainder (R1); GE tax 1% at open,
  treasury-routed, tunable 1–3%; city orders untaxed; tax on hero-side proceeds
  uniformly (R8); shop 3% tax untouched. R5 end state: gather incentives migrate
  to funded mechanisms (buy orders + price-bias), pure-utility incentives retire.
  **COINPURSE INVARIANT: the bank holds PER-HERO deposits, never a pool.**
  Sub-items in build order (foundation/testable first; UI + economic tuning last):
  - [x] #5a — **Bank foundation SHIPPED** (2026-06-14): `Hero.bank` per-hero
    store; `bank_deposit/withdraw/total`; `total_gold()` counts coinpurse+bank;
    upkeep on TOTAL wealth (purse-then-bank → no attractor dodge); death-safe.
    Save **v7** (`_migrate_6_to_7`). Inert (empty bank → live sim byte-identical,
    gates pass, **no re-baseline**). +7 suite checks → **217/217**; 3 gates PASS.
    Decision (banked gold is upkeep-bearing) in 06-DECISIONS-LOG.
  - [x] #5b — **GE order book ENGINE SHIPPED** (2026-06-14): `ge_orders` +
    `ge_post_order`/`ge_match`/`ge_cancel_order`. Price-time priority (highest buy
    × lowest sell, ties by age; fill at the resting price). Escrow at posting (R1:
    sell→goods, buy→gold/treasury). 1% `GE_TAX` on seller proceeds → treasury
    (`treasury_in_ge_tax`, R8). Refunds: buy→bank (R9), sell→inv. `ge_unlocked`
    flag. Save **v8**. INERT (no autonomous posting → empty book → no re-baseline).
    +7 suite checks → **224/224**; 3 gates PASS. DEFERRED: relationship tilt
    (`trade_modifier`), autonomous trading (→ #5c), offline fill (→ #5d), GE
    unlock (→ #5e). Matching model + deferrals in 06-DECISIONS-LOG.
  - [x] #5c — **City BUY orders + City Inventory SHIPPED** (2026-06-14):
    `city_post_buy_order` (treasury escrow via the #5b engine, owner=-1) +
    `city_inventory`; `ge_sell_into_orders` hero hook wired into the FSM sell step
    (fills standing buys at the NPC-price floor, takes the resting buy's price −1%
    tax). Save **v9**. INERT (empty book → sell path byte-identical → no
    re-baseline). +5 suite checks → **229/229**; 3 gates PASS. The autonomous
    brain pull toward gathering FOR posted orders is the R5 end-state (#5e).
  - [x] #5d — **Offline statistical fill model SHIPPED** (2026-06-14): standing
    BUY orders fill from the colony's offline gathering supply over the (capped)
    window — `_offline_fill_orders` bounds each order by the SAME per-good
    throughput as the gold accrual (market-consumption capped), so a single order
    can't fill faster than live gathering would deliver. Goods land for the buyer
    (city → `city_inventory`, hero → inv); seller proceeds (gross − GE_TAX) land in
    the gatherers' **BANK** (R9 — `_bank_split_to_gatherers`, per-hero, no pool);
    tax → treasury. Escrow was taken at posting, so this only MOVES escrow → banks
    (no gold creation, like live `_ge_execute`). A good nobody gathers offline
    can't fill (faithful). Pure function of the capped dt → `gain(30h)==gain(24h)`.
    INERT when the book is empty (GE-locked / no orders) → offline byte-identical
    there, **offline gate unperturbed** (PASS, cap clamps 22096==22096). No save
    bump. +7 suite checks → **245/245**; 3 gates PASS. Simplification logged in
    06-DECISIONS-LOG (goods are gold-abstract offline → a tiny shop-value double
    count on filled units, bounded by CITY_ORDER_QTY, errs toward the player §4).
  - [x] #5e — **GE unlock + funded gather incentive LIVE SHIPPED** (2026-06-14).
    #5e-1: `ge_annex` building (1500g) flips `ge_unlocked`, gated on Gate-1
    (`gate1_reached()` = any hero Combat 40); one-shot, per-run. #5e-2: brain
    gather reward reads `best_sell_price` = max(shop, best buy order) → funded
    orders pull labor (1.6→15.3); `_auto_city_orders` daily (town posts 1/good
    at 1.5× shop, escrow ≤25% treasury, self-limiting); sim_hash += GE state.
    **RE-BASELINE (diag_ge.gd, GE open all run): g/cap 1,378 ± 331 — mean matches
    the locked band 1,384±174, attractor HOLDS, all colonies alive.** Suite
    **238/238** (+9 checks); 3 gates PASS. DEFERRED refinements (not blockers):
    retire utility gather incentives (R5 cleanup, breaks incentive test), #5d
    offline fill, relationship tilt (`trade_modifier`), total_gold-counts-escrow.
  - **OPEN DESIGN QUESTIONS (resolve as reached, sweep-backed):** (1) banked-gold
    vs upkeep — #5a defaults to upkeep-on-total (attractor-safe); revisit only
    with evidence. (2) GE matching/price-discovery model. (3) offline fill rate.
- [~] #6 — Unit 5 — **CODE-COMPLETE (F5-pending)**: C4 shop sell-back (ceiling
  `min(saturation, 0.30 × GE reference)`, graceful degradation when GE illiquid
  — adopted as written, R2) + C3 item-cost upgrade ladders + C5 shop crafting
  queues (reservation-on-start FIFO). Never ship C4 alone; keep bug-class lens on
  the C2→C3/C5 closed loop. **All sub-items #6a–#6d shipped/green** (suite
  267/267, 3 gates PASS, save v10); only the #6d UI F5 visual sign-off remains. **The closed loop:** C2 city-buying (Unit 4)
  ACCUMULATES `city_inventory`; C3 upgrades + C5 crafting DRAIN it; C4
  reshapes the shop economy so trade migrates GE-ward. Decomposed (build
  order — greenfield drains first, the mint-touching C4 LAST with a sweep):
  - [x] #6a — **C3 item-cost upgrade ladders SHIPPED** (2026-06-14). Shop
    level-ups cost city-inventory ITEMS on top of treasury gold:
    `shop_upgrade_item_cost` (Config ladder `SHOP_UPGRADE_ITEM_COST` {logs 15,
    iron_ore 10}, scaled geometrically per level) + `can_upgrade_shop` (level +
    gold + items) folded into the existing `SimWorld.upgrade_shop`;
    ALL-OR-NOTHING (no partial spend). `Economy.try_upgrade_shop` stays the
    gold-only primitive (suite-pinned). Drains what C2 accumulates (the C2→C3
    loop). No save bump (Config ladder; `city_inventory` already serialized).
    +7 suite checks → **252/252**; 3 gates PASS (byte-identical — player action,
    not autonomous). Empty ladder = old gold-only upgrade.
  - [x] #6b — **C5 shop crafting queues SHIPPED** (2026-06-14). Single-server
    FIFO `craft_queue` on SimWorld: `queue_craft` reserves recipe inputs from
    `city_inventory` at enqueue (reservation-on-start), the FRONT job accrues
    sim-time (`_craft_advance`, `CRAFT_DAYS_PER_UNIT` 0.5) and produces output
    into that shop's `stock` (room-gated backpressure; output must be vended);
    `cancel_craft` refunds unmade inputs. Recipes-as-data (`ItemType.recipe`);
    `Economy.shop_by_id` added. Live (per-action) + offline (`offline_catchup`
    replays the window in sim-days → offline-resolvable). **Save v9→v10**
    (`_migrate_9_to_10`, forward-compatible). INERT on an empty queue →
    live/gates byte-identical. +8 suite checks → **260/260**; 3 gates PASS. The
    second C2→C5 drain; the closed loop now has both consumers (C3 + C5).
  - [x] #6c — **C4 shop sell-back ceiling SHIPPED** (2026-06-14). Once the GE
    opens, `Economy.sell_price` ceilings `min(saturation, SHOP_SELLBACK_FRAC
    0.30 × base_value)` (`sell_back_active`, synced to `ge_unlocked` via a
    setter). New `Economy.reference_price` (uncapped) feeds the gather glut term
    + the autonomous city-order premium so the cut doesn't collapse the funded
    incentive; `best_sell_price` keeps the ceilinged shop (the procurement
    steering). GRACEFUL DEGRADATION: GE locked → inert → gates byte-identical.
    No save bump. **RE-BASELINE (diag_ge = GE open + C4, 8 seeds × 23 days):
    g/cap 707 ± 208** (was 1,378 ± 331) — the designed mint cut; attractor HOLDS,
    pop 41 ± 1, ALL ALIVE, deaths 14 ± 9 (WATCH KI-11). Shipped per the user's
    "0.30 as written" ruling. +7 suite checks → **267/267**; 3 gates PASS.
  - [~] #6d — **Unit 5 UI CODE-COMPLETE (F5-pending)** (2026-06-14). TOWN panel
    (immediate-mode): #6a upgrade button gated on `can_upgrade_shop` + item-cost
    tooltip; #6b `_draw_crafting` (city-stock readout, feasibility-gated
    quick-craft presets, live queue with ✕ cancel; new `craft`/`cancel_craft`
    dispatch + `SimWorld.can_queue_craft`); #6c sell-back venue readout (shop pay
    vs best, "(GE-capped)" flagged). Main.gd parses; suite 267/267; 3 gates PASS.
    **VISUAL needs an F5 pass** (render-only) — joins the Unit-3 #4b/#4c F5 queue.
- [ ] #7 — Content wave (e): death/graves/PK → canon social negatives
  (retire interim competition-friction).
- [ ] #8 — Content wave (f): buildings expansion / reincarnation.
- [ ] #9 — Content wave (g): Zezima endgame.
- [ ] #10 — B3 topbar deltas (Save/Load/Log buttons, subtitle) — render-only,
  anytime.
- [x] #11 — MERGED into #1a (R10 pulled the save-migration scaffold forward
  to Unit 0). (2026-06-11)
- [ ] #12 — Deferred planner calls: INCENTIVE_STEP finer notches · Stage-2
  combat polish (premise undercut, optional) · dead `_route*` heuristic
  cleanup in SimWorld · Apothecary + Thessalia shops (R3 deferred) ·
  relocate Vannaka to Edgeville when zones expand westward (R4).
- [ ] #16 — **Legendary & Easter-Egg arrivals — achievement-gated**
  (design reservation, directive 2026-06-12; sits AFTER Unit 4's GE and
  pairs with #9 Zezima endgame). Each immigrant roll has a SMALL chance to
  instead be a **Legendary** — a pre-generated character canon to the real
  OSRS community (e.g. Lynx Titan, Woox, Noobtype, Port Khazard, B0aty,
  Settled, Odablock) arriving with handcrafted stats/gear/gold and a build
  matching their real-world reputation (Lynx Titan = maxed skiller-
  grinder; Woox = elite PvM; B0aty/Odablock = combat/PvP personalities;
  Settled = ironman-style restriction quirks). GATING: Legendaries can
  spawn only once the GE has been unlocked **in the current run** — a
  per-run requirement, NOT a permanent account unlock (after beating
  Zezima and prestiging, each new run re-unlocks the GE first).
  **Easter-Egg characters** are a second, significantly RARER class the
  player designs by hand later; they carry an ADDITIONAL special unlock on
  top of the GE requirement — exact condition TBD/implementer's call,
  balanced and achievable (e.g. GE unlocked + ≥1 Zezima kill this run).
  RECORDED NOW so the immigration, character-template, and achievement/
  unlock systems stay compatible: immigration roll needs a template-
  override hook; character gen needs a handcrafted-template path (vs #13's
  random rolls); a per-run unlock/achievement record must exist and SURVIVE
  prestige resets correctly (i.e. reset with the run).

## Done
- [x] #15 — **Immigrant gear rolls COMPLETE** (2026-06-13): arrivals roll
  starting gear scaled by rarity tier — `ContentDB.equippable(slot,tier,style)`
  + `_roll_arrival_gear` (armor head/torso/off via equip-prob `0.15+boost×0.02`
  + tier-2 chance `boost×0.025`; fighter main upgrades style-matched). No save
  bump. Final batch band **1,384 ± 174** (variance tightened ±448→±269→±174,
  deaths down — equipped arrivals survive better; all viable). Suite 210/210
  (+5 checks); 3 gates PASS. **Directive batch #13–#15 COMPLETE.**
- [x] #14 — **Immigrant gold in economy-fitted bands COMPLETE** (2026-06-13):
  `NEWCOMER_TIERS` gold → `gold_frac` [lo,hi] (fraction of `GOLD_ATTRACTOR_REF`
  1482) — Greenhorn 1–3% … Elite 18–30% (≈267–445g, bounded < g*); rolled per
  arrival via `_roll_tier_gold`. Immigrant fighters roll weapon style (#13d;
  id%3 retired). No SAVE_VERSION bump. Band re-baselined **1,337 ± 269** (8
  seeds, rolled founders + immigrants — within-noise shift, all viable). Suite
  205/205 (+6 checks); 3 gates PASS.
- [x] #13 — **Founders fully randomly generated COMPLETE** (2026-06-13): every
  founder ROLLED on the seeded RNG — favorite (viability floor: ≥1 fisher),
  weapon style (fighters; `id%3` retired), starting gold (band 20–100g), name,
  appearance, spawn inside the city walls. `Config.FOUNDERS_LOCKED` debug flag
  (default OFF=rolled; ON=byte-identical template, pinned by the suite).
  `_new_hero` gained a `weapon` param (the #14/#15 hook). No SAVE_VERSION bump
  (values in existing fields). Band RE-BASELINED to **1,482 ± 448** (8 seeds,
  `diag_founders.gd` — mean preserved, variance widened by random spreads; all
  colonies viable). Suite 199/199 (+7 checks); 3 gates PASS. WATCH in KI-10.
  CONSTRAINTS (a)–(d) all met. (Random spawn-in-walls included; no separate
  sub-item needed.)
- [x] #3 — **Unit 2: shop economy v2 COMPLETE** (2026-06-12 → 2026-06-13;
  rulings R1/R3). #3a supply side (7-shop roster as data, dynamic buy
  pricing, stock-gated purchases, C5 ambient imports, tier-up unlocks, save
  v4) · #3b treasury ledger (40% purchase routing + 5 counters + telemetry)
  · #3c player price-bias lever (treasury-funded overpay, clamp LOCKED
  0.70/1.30 by diag_bias, save v5) · #3d KI-4 closing sweep
  (`diag_unit2_close.gd`, negative result): no shippable combat-side
  mitigation — gear coupling FALSIFIED, congestion 1.0 gate-blocked (offline
  variance), so COMBAT_CONGESTION_MULT HELD at 0.5; KI-4 stays open.
  **Unit-2 closing band re-baselined g/cap 1,501 ± 235**. Suite 179/179;
  3 gates PASS. Sub-item detail above + in 07-CHANGELOG (2026-06-12/13).
- [x] #1 — **Unit 0: Slayer slice COMPLETE** (2026-06-11 → 2026-06-12; zones
  slice 2, absorbs B2; rulings R4/R5/R6/R10). #1a save-migration scaffold
  (upgrader chain, ruled gate green) · #1b Slayer core (Vannaka,
  knowledge-gated feasible tasks, on-task pull, save v2) · #1c funded
  per-kill bounty (one affordability rule, FIGHT utility incentive retired)
  · #1d aggressive monsters + Scurrius gate + canon survival triad (deaths
  2,096→4/24k ticks, rep 0→61) · #1e closing sweep (SLAYER_ON_TASK locked
  +20; §18 split — rival-lean held/KI-5 resolved, combat-share failed/KI-4
  re-confirmed; BRAIN_V2 4th test: worsens monoculture 52±3 vs 44±5,
  default stays OFF; band re-baselined 1,460±332). Full sub-item detail in
  07-CHANGELOG (2026-06-11/12 entries).
- [x] #2 — **Unit 1: catalog migration COMPLETE** (2026-06-12): canon catalog
  ids are the sim's single item truth — inv/equip/shop keys renamed (ore→
  iron_ore, cooked_fish→trout, display-name gear/tools/ammo→ids), shop base
  values catalog-sourced (KI-8 RESOLVED: iron_ore 17), `GEAR_DROPS`/
  `GEAR_TIER` retired into items.json (dropPool/tier/style), recipes-as-data
  (cook raw_trout→trout + smith 3×iron_ore→iron_sword via
  `ContentDB.craft_output`), tradeable flags gate vendoring, SHOPS TRADE
  GEAR (General-Store board, fill-0.5 open ≈ old half-value anchor, flat
  vendoring retired), `GE_TAX`→`SHOP_TAX` (R8). Save v3 + v2→v3 upgrader
  (id remap + gear-board injection). Suite 153/153 (+12 Unit-1 checks);
  3 gates PASS; render parses; telemetry drift +4%, day-23 g/cap ~1,790
  (within 1σ of the 1,460±332 band).
- [x] #0 — MVP slice complete: build steps 0–6 ("A Living Varrock") all
  CLOSED & green (99/99 → now 101/101) — economy attractor validated;
  population/social/control-tiers/save-load/offline/LOD gated. (2026-06-09)
- [x] #0.1 — M1 visual/UX port (canon 46×34→50×38 Varrock map, camera,
  topbar/roster/popup UI); M2 BRAIN_V2 measured (default-off, 4th test
  queued); M3a gear/equipment/smithing slices; M3b styles/ranged/magic/
  triangle plumbing/ammo; pathfinding (grid BFS, walls solid); §6 re-centers
  (RAT_DROP halved; UPKEEP_RATE 0.80); goal system; tool requirements;
  zones slice 1 (6 camps). All gated 101/101. (2026-06-09 → 2026-06-10)
- [x] #0.2 — Read-only economy/incentives probe + ANALYSIS REPORT (Parts
  A–E of the design-partner prompt) + PROJECT KNOWLEDGE seeding. (2026-06-11)
