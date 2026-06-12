# Punch List — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. The agreed work queue — single source of
> truth (materialized 2026-06-11 from the agent-memory status ledger; full
> history in `ANALYSIS REPORT/STATUS_DOCS/AGENT_MEMORY_project-status.md`).
> Item format: `- [ ] #N — description` (N never reused; completed items move
> to Done with the date).

## Now (active focus) — Unit 2: shop economy v2 (punch #3)
- [ ] #3 — Unit 2: shop economy v2 (rulings R1/R3). Sub-items in build order:
  - [x] #3a — Supply side SHIPPED: 7-shop roster via new `data/shops.json`
    (R3 cast), gear re-routed to specialist shops, dynamic buy pricing
    (`charge_price`, anchored to the validated flat costs at baseline
    fill), stock-gated purchases, C5 ambient imports (ammo baselines tuned
    8→60 after a measured supply cliff: kills −25% — the R3 anti-pattern,
    caught and fixed), tier-up unlocks (buy-side only), save v4 + v3→v4
    upgrader. Offline-gate criterion v2 (re-entry + runaway guard —
    endpoint-only Δ was decoupled-run noise). (2026-06-12)
  - [x] #3b — Ledger SHIPPED: `PURCHASE_TREASURY_ROUTE` 0.40 (all hero
    shop spend incl. food; hero-side sink unchanged), 5 treasury
    inflow/outflow counters wired/serialized + telemetry line (day-23:
    treasury 78k = tax 28k + routing 50k, outflows 0 until player acts);
    band verified: drift −2%, kills 20.8k vs 21.8k pre-Unit-2, g/cap
    ~1,829 (band edge — formal re-baseline at #3d closing report).
    Suite 169/169; 3 gates PASS. (2026-06-12)
  - [ ] #3c — Player price-bias lever: **MECHANICS BUILT 2026-06-12**
    (per-good multiplier on what shops pay; treasury-funded overpay,
    affordability-gated, degrades to base when unfunded; underpay = smaller
    faucet, no treasury flow; brain reads the biased price via sell_price;
    Town-tab cycle row; `treasury_out_bias` ledger; save v5 + v4→v5
    upgrader; 7 suite checks — 176/176). **REMAINS: the clamp sweep** —
    `tools/diag_bias.gd` written/UNRUN (4 arms × 6 seeds; lock criterion
    in its header); run it, lock PRICE_BIAS_MIN/MAX (opening stance
    0.70–1.30), update Config comment + decisions log, then close.
  - [ ] #3d — KI-4 counter-force experiment (designed into this unit per
    #1e): sweep COMBAT_CONGESTION_MULT {0.5 current, 0.75, 1.0} ±
    gear-drop reward coupling through the now-real gear-board price;
    two-sided criterion (monoculture must drop from ~44%, combat must not
    crater). Lock the winner; closing band report.
- [ ] #4 — Unit 3: C1 parameterized nudge popups (+ B4 disabled-with-tooltip
  gating). UI tech RULED (R11): Control nodes for new popups only, shared
  visual constants, render-layer only, decisions-log entry on the paradigm
  split. `loot_policy` = drop-filter semantics (R7). Fight popup after #1;
  Skill popup can float earlier.
- [ ] #13 — **Founders fully randomly generated** (directive 2026-06-12).
  On a fresh start every founder is ROLLED, not templated: random name,
  random appearance colors (skin/hair/shirt), random skills/stats incl.
  the favorite-activity spread, random starting gold in a band (opening
  stance 20–100g; the BAND is the implementer's to recommend against the
  attractor — the REQUIREMENT is random rolls), random spawn placement
  within the city walls. Today: fixed favorites list (SimWorld ~146),
  id-indexed SKIN/HAIR picks (~161), id-based names, `weapon = id % 3`
  (~196) — all become seeded rolls. CONSTRAINTS: (a) all randomness on the
  seeded sim RNG — same seed ⇒ same founders (determinism gate holds);
  (b) keep a debug path to lock founders (fixed preset or pinned seed)
  for testing/repro; (c) the favorite spread must not roll a structurally
  unviable colony (e.g. zero fishers) — constrain the roll or PROVE the
  brain recovers; (d) fighting-favorite founders ROLL their weapon/style
  (sword/bow/staff) — the `id % 3` assignment retires (same rule for
  immigrant fighters, #14). Engineering: wealth changes move the gold
  attractor → re-run the band sweep + re-baseline; gates stay green;
  SAVE_VERSION bump + upgrader on any save-shape change.
- [ ] #14 — **Immigrant gold rolled in economy-fitted bands** (directive
  2026-06-12). Replace the fixed per-tier gold (NEWCOMER_TIERS 20/45/130/
  320, Config ~161) with ROLLED ranges per tier, scaled so higher-tier
  joiners arrive meaningfully funded relative to their level — sized to
  FIT THE ECONOMY, not preset numbers. Derive bands from the current
  attractor (anchor each tier to a sensible fraction of the per-capita
  band — e.g. Greenhorn a few % of g*, Elite a substantial-but-bounded
  fraction), propose with sweep evidence, tune within gates. The SHAPE is
  the requirement: random rolls; low tiers modest; high tiers wealthy but
  not economy-breaking. Same engineering constraints as #13.
- [ ] #15 — **Immigrant gear rolls** (directive 2026-06-12). Arrivals roll
  random starting gear of random quality; higher stats/levels add a BONUS
  to the roll (better heroes arrive better-equipped). Gear-as-data exists
  since Unit 1 (items.json tiers/styles/slots) — roll against the catalog.
  Style-matched main-hand for fighters per the #13(d) rolled style; armor
  slots may roll for any tier-appropriate arrival. Same engineering
  constraints as #13 (seeded RNG, gates, save migration if shape changes).

## Later / icebox
- [ ] #5 — Unit 4: Bank + GE order book + City BUY orders + City Inventory
  (the big gold-ledger unit — sweep g* before/after; offline statistical
  fill model). RULED: bank ships WITH the order book (R9 — refunds need a
  deposit target); **city buy orders escrow treasury gold at posting**,
  cancel/expiry refunds remainder (R1); GE tax 1% at open, treasury-routed,
  tunable 1–3%; city orders untaxed; tax on hero-side proceeds uniformly
  (R8); shop 3% tax untouched. After this unit, gather incentives migrate
  to funded mechanisms (buy orders + price-bias) and pure-utility incentives
  retire (R5 end state).
- [ ] #6 — Unit 5: C4 shop sell-back (ceiling `min(saturation, 0.30 × GE
  reference)`, graceful degradation when GE illiquid — adopted as written,
  R2) + C3 item-cost upgrade ladders + C5 shop crafting queues
  (reservation-on-start FIFO). Never ship C4 alone; keep bug-class lens on
  the C2→C3/C5 closed loop.
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
