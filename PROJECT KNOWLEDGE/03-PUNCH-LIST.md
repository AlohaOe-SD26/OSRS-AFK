# Punch List — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. The agreed work queue — single source of
> truth (materialized 2026-06-11 from the agent-memory status ledger; full
> history in `ANALYSIS REPORT/STATUS_DOCS/AGENT_MEMORY_project-status.md`).
> Item format: `- [ ] #N — description` (N never reused; completed items move
> to Done with the date).

## Now (active focus) — Unit 0, per DESIGN_RULINGS.md (2026-06-11)
- [ ] #1 — **Unit 0: Slayer slice** (zones slice 2, absorbs B2; rulings
  R4/R5/R6/R10 govern). Sub-items in build order:
  - [x] #1a — Save-migration scaffold (R10, absorbs old #11): upgrader
    chain in `SaveLoad.migrate()` run before load; 5 new suite checks
    (106/106) incl. the ruled gate (migrated save loads validly + continues
    deterministically from the load point); save/load gate green. (2026-06-11)
  - [x] #1b — Slayer core SHIPPED: Vannaka at the west gate (map loc
    `vannaka`, documented divergence per R4), Combat-40 gate, knowledge-
    gated pool (`kill_counts`, generalizes to the Scurrius unlock),
    feasibility via `fight_is_winnable` (affordable-food loadout), HP-band
    task sizing, on-task +20 brain term (`SLAYER_ON_TASK`, sweepable) +
    0.9×HP slayer XP + 8–16 points, Vannaka check-in chained into FIGHT
    trips (organic uptake), Chronicle events, save v2 + real v1→v2
    upgrader. Suite 122/122; all 3 gates green. (2026-06-11)
  - [ ] #1c — Funded per-kill treasury bounty; RETIRE the clamped utility
    FIGHT bounty same unit (R5). Bounty payout enters scoring through the
    greed-weighted `reward` term; per-kill affordability check; player range
    0–3× avg coin drop.
  - [ ] #1d — AGGRESSIVE monsters (deaths → gravestone/social negatives)
    + Scurrius boss gate (kill-count unlock).
  - [ ] #1e — Unit-0 sweep instrumented with monoculture/rival-lean metrics
    (R6 — verifies the banked §18 prediction); then BRAIN_V2 4th test
    (activity breadth widened).

## Next
- [ ] #2 — Unit 1: catalog migration (prerequisite for all pricing work):
  ContentDB-driven goods/prices (replace `Economy.GOODS` hardcodes +
  `Config.GEAR_DROPS` tables), recipes-as-data, tradeable flags, shops trade
  gear. Resolves KI-8 first. Rename `GE_TAX`→`SHOP_TAX` while files are open
  (R8, cosmetic).
- [ ] #3 — Unit 2: shop economy v2 (rulings R1/R3): per-good dynamic buy
  pricing, player price-bias lever (swept clamp, expect narrower than
  50–150%), ambient imports/restock-to-baseline (C5), tier-up stock unlocks,
  shop roster expansion — **Horvik, Lowe, Zaff, Aubury, Swordshop greenlit**
  (Apothecary/Thessalia deferred; stagger openings optional),
  **purchase→treasury routing at 40%** (tune 30–50% band; one ledger unit
  with city-buy outflow — sweep once, re-center once; add treasury
  inflow/outflow telemetry lines).
- [ ] #4 — Unit 3: C1 parameterized nudge popups (+ B4 disabled-with-tooltip
  gating). UI tech RULED (R11): Control nodes for new popups only, shared
  visual constants, render-layer only, decisions-log entry on the paradigm
  split. `loot_policy` = drop-filter semantics (R7). Fight popup after #1;
  Skill popup can float earlier.

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

## Done
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
