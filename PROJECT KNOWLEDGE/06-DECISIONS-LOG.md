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
