# Punch List — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. The agreed work queue — single source of
> truth (materialized 2026-06-11 from the agent-memory status ledger; full
> history in `ANALYSIS REPORT/STATUS_DOCS/AGENT_MEMORY_project-status.md`).
> Item format: `- [ ] #N — description` (N never reused; completed items move
> to Done with the date).

## Now (active focus)
- [ ] #1 — **Zones slice 2:** Slayer tasks + AGGRESSIVE monsters (activates
  deaths → gravestone/social negatives) + Scurrius boss gate (kill-count
  unlock) + BRAIN_V2 4th test (activity breadth widened). NOTE: pending
  design rulings, this item ABSORBS reference spec B2 (task gates incl.
  wiring `Combat.fight_is_winnable`, task sizing, on-task bonus, knowledge-
  gated pool, partnering as fast-follow, funded per-kill treasury bounty) —
  see `ANALYSIS REPORT/ANALYSIS_REPORT.md`.

## Next
- [ ] #2 — Catalog migration (M3a remainder, promoted to prerequisite):
  ContentDB-driven goods/prices (replace `Economy.GOODS` hardcodes +
  `Config.GEAR_DROPS` tables), recipes-as-data, tradeable flags, shops trade
  gear.
- [ ] #3 — Shop economy v2 (pending rulings): per-good dynamic buy pricing,
  player price-bias lever (swept clamp), ambient imports/restock-to-baseline
  (C5), shop-level tier-up stock unlocks, possible Varrock shop-roster
  expansion (Q3), possible purchase-gold→treasury routing (Q1).
- [ ] #4 — C1 parameterized nudge popups (+ B4 disabled-with-tooltip
  gating). Fight popup after #1; Skill popup can float earlier. UI-tech
  ruling Q11 first.

## Later / icebox
- [ ] #5 — Bank + GE order book + City BUY orders + City Inventory
  (roadmap wave (d) enlarged by C2/C3; the big gold-ledger unit — sweep g*
  before/after; offline statistical fill model; tax decision Q8).
- [ ] #6 — C4 shop sell-back reconciliation + C3 item-cost upgrade ladders +
  C5 shop crafting queues (all consume #5's outputs; never ship C4 alone).
- [ ] #7 — Content wave (e): death/graves/PK → canon social negatives
  (retire interim competition-friction).
- [ ] #8 — Content wave (f): buildings expansion / reincarnation.
- [ ] #9 — Content wave (g): Zezima endgame.
- [ ] #10 — B3 topbar deltas (Save/Load/Log buttons, subtitle) — render-only,
  anytime.
- [ ] #11 — Save-migration scaffold (versioned upgraders) — wants to land
  before the #5/#6 schema churn (Q10).
- [ ] #12 — Deferred planner calls: funded per-unit bounty for gather
  intents · INCENTIVE_STEP finer notches · Stage-2 combat polish (premise
  undercut, optional) · dead `_route*` heuristic cleanup in SimWorld.

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
