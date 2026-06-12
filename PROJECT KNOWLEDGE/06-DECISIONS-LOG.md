# Decisions Log â€” osrs_afk
> APPEND-ONLY. New entries at the end. Never rewrite history â€” if a decision
> is reversed, append a NEW entry that supersedes the old one and says so.

---

## 2026-06-11 â€” Adopted the Claude Code Project Kit
- **Decision:** Standardize on the kit's CLAUDE.md directives + PROJECT
  KNOWLEDGE structure + per-item commit/push definition of done.
- **Context:** Make every session resumable by any agent with zero context.
- **Alternatives rejected:** Ad-hoc per-chat context pasting (doesn't scale,
  loses history).

## 2026-06-11 — Backfill: standing decisions inherited from the pre-Kit era
(One-time summary so this log is complete from here on; full provenance in
`ANALYSIS REPORT/STATUS_DOCS/AGENT_MEMORY_project-status.md`.)
- **Economy attractor locked** (Step 1): wealth-proportional upkeep + town
  consumption + saturation pricing + sale tax — validated to bounded
  equilibrium; never re-derived, only integrated around.
- **Back-pressure doctrine:** every dynamic ships with its counter-force
  (generalized from 7 banked bug-class instances).
- **Measurement discipline:** emergent claims need 8–16-seed sweeps;
  default-off flags for behavior changes until gate-validated.
- **Merge plan (2026-06-09):** adopt the 2nd concept prototype's look/brain/
  content ON the validated Godot foundation; order M1→M2→M3. BRAIN_V2 kept
  default-off after 3 measured tests (needs activity breadth).
- **Funded per-unit bounty = intended Tier-1 design** (utility bounty
  clamped at +24 as interim; sweep showed ≥~36 craters the market).
- **Standing harness rules:** preload() not class_name in tools; quit() ends
  every harness; foreground gates with timeout.

## 2026-06-11 — Economy/incentives feature set: discuss-first, no code
- **Decision:** Respond to the external design partner's prompt
  (`readthis.md`) with a read-only probe + written report
  (`ANALYSIS REPORT/ANALYSIS_REPORT.md`); defer ALL B/C feature work until
  design rulings return. Sequencing proposal recorded in the report and
  mirrored as punch-list #1–#6/#10–#11 placeholders.
- **Context:** Hard rules in the prompt (read-only probe; side panels kept;
  punch list preserved; report travels to a designer without code access).
- **Alternatives rejected:** starting implementation alongside the report
  (violates the prompt's discussion-first contract).

## 2026-06-11 — Design rulings R1–R12 adopted (DESIGN_RULINGS.md)
- **Decision:** All twelve ANALYSIS_REPORT questions ruled by the design
  partner; rulings preserved at `ANALYSIS REPORT/DESIGN_RULINGS.md` and
  folded into the punch list. Headlines: treasury re-injection accepted with
  **escrow-at-posting** for city buy orders (no flow cap); purchase→treasury
  routing 40% (tune 30–50%); NPC demand floor KEPT (autonomy is the
  product); shop roster greenlit (Horvik/Lowe/Zaff/Aubury/Swordshop —
  combat-triangle supply-gating rationale); **Vannaka** (designed cast, not
  parity) at west gate with documented divergence; **one funded incentive
  doctrine** — bounty payout drives attraction through the greed-weighted
  reward term, clamped utility FIGHT bounty retires same unit; on-task
  bonus +20 open, mine to lock within gates, sweep instrumented for the §18
  monoculture prediction; loot_policy = drop-filter; shop 3% tax locked,
  GE 1% treasury-routed at open, city orders untaxed, tax on hero-side
  proceeds uniformly; bank ships WITH the GE (refund deposit target);
  save-migration scaffold pulled to Unit 0 (gate = migrated save loads +
  continues deterministically); C1 popups = Control nodes (new popups only,
  shared visual constants, render-layer, paradigm-split rule to be logged);
  day-denominated specs = sim-days. Sequencing Units 0–5 endorsed as-is.
- **Alternatives rejected (by ruling):** hard treasury outflow cap (escrow
  is structural and simpler); invented Slayer-master stand-in (lore
  invariant); separate flat utility knob for bounty attraction (one lever,
  two effects); taxing city orders (ledger noise); bank deferral (reference
  build's expiry-refund deadlock lesson).

## 2026-06-11 — Process: initial commit + push (priority #0)
- **Decision:** Committed the entire pre-rulings green state as the initial
  commit (`5fd5d97`) and pushed to origin/main; added Godot-cache and
  archive ignores first so `.godot/` never enters history. Per-item commit
  discipline (Project Kit DoD) applies from here on.

## 2026-06-12 — Live-aggro survival: canon mechanics over knob-tuning (punch-list #1d)
- **Decision:** The aggressive-monster death-loop (workers chipped faster
  than they could ever recover) is solved with three CANON OSRS mechanics —
  passive regen (1 HP/min), aggression tolerance (monsters ignore heroes
  settled >8s into a trip; harassment = arrival tax), and lair-bound bosses
  (strike trespassers only) — plus one brain term (danger = −threat ×
  frailty on gather candidates at aggro-shared camps). Deaths fell
  2,096 → 4 per 24k ticks; reputation recovered 0 → 61; goblin culling
  and the Scurrius fight both became functional for the first time.
- **Why this shape:** the bug-class rule (every force needs a counter-force)
  said the fix belongs at the SOURCE (exposure time) and in the BRAIN
  (priced risk), not in the damage numbers. Tolerance also fixed a second-
  order failure for free: perma-chasing goblins never stood still, so
  fighters stopped culling them (kills 96 → 3,730 once they wander again).
- **Alternatives rejected:** scaling the danger term alone (measured
  insufficient — favorite bias +14 outbids any sane penalty at full HP, and
  at low HP the worker is already in the loop); softening REP_PER_DEATH
  (treats the symptom, keeps the meat grinder); nerfing aggro damage
  (makes aggression cosmetic); per-pair tolerance state (canon-truer but
  save-shape-heavy; per-hero trip clock captures the same behavior).
- **Note:** per-capita gold drifted above the validated 1,065–1,211 band
  (~1,485 at day 23 — fewer deaths/flees = more productive hours). Formal
  re-baseline belongs to the #1e instrumented sweep, not a knob reaction.

## 2026-06-12 — #1e verdicts: on-task locked +20; §18 split; BRAIN_V2 stays OFF; band re-baselined
- **SLAYER_ON_TASK locked at +20** (R6 — "the number is yours"). Sweep
  (`tools/diag_unit0.gd`, 8 seeds × arms 0/10/20/35, 23d): engagement
  saturates at +20 (tasks 14→59→68→68; on-task fighters 1→9→10→11%;
  deaths/run 7.1→5.9→5.0→5.0). +35 buys nothing over +20; +0 collapses
  the Slayer loop. Alternatives rejected: +10 (half the engagement for
  the same monoculture level), +35 (no measurable return, stronger
  standing attractor on principle).
- **The banked §18 prediction held HALF-way** (R6 instrumentation):
  - Rival-lean half HELD: the social web flipped friend-leaning
    (Friend ≈ 3.5% vs Rival ≈ 0.7% of ordered pairs; KI-5-era lean was
    Rival > Friend on stored edges — sign flip is denominator-invariant).
    KI-5 RESOLVED and removed.
  - Combat-share half FAILED: monoculture 39–44% across ALL arms — above
    the bug-era 32%. Cause: the old ~8–20% "mitigation" was lethality;
    the #1d survival triad removed that counterweight and the
    price-independent combat base reasserted itself. Slayer tasks
    ORGANIZE combat (feasible targets, fewer deaths); they do not shrink
    it. KI-4 re-confirmed structural, fix path revised (combat-side
    reward saturation / price coupling, natural home = Unit-1+ pricing).
- **BRAIN_V2 default stays OFF** (4th test, `tools/diag_stage2.gd`, 8
  seeds, v1 vs v2 on the Unit-0 surface): v2 WORSENS monoculture
  (52±3 vs 44±5). Mechanism: saturating bases drain a gatherer's trained
  favorite while untrained strength remains a maximal-need refuge —
  breadth was never the missing precondition; a combat-side counter-force
  is. Keep v2's measured win in mind (per-capita gold variance ±332→±84)
  and salvage it once the combat base is price-coupled.
- **Per-capita gold band re-baselined: 1,460 ± 332** (day-23, 8 seeds,
  on-task +20; old band 1,065–1,211 was pre-survival-triad — fewer
  deaths/flees = more productive hours; variance widened because rare
  deaths now swing trajectories instead of truncating them).
