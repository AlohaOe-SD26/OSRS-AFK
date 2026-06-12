# Changelog â€” osrs_afk
> APPEND-ONLY. Every meaningful change, fix, or addition gets a dated entry
> at the END of this file (chronological order, oldest first).
> Entry format:
>
> `## YYYY-MM-DD â€” short summary  (punch-list #N if applicable)`
> followed by bullets: what changed, why, files touched.

---

## 2026-06-11 — Project bootstrapped with Claude Code Project Kit
- Created PROJECT KNOWLEDGE skeleton (00–07), CLAUDE.md standing directives,
  Remote-Start launcher, git repository + remote.

## 2026-06-11 — ANALYSIS REPORT (economy/incentives probe) + PROJECT KNOWLEDGE seeded  (punch-list #0.2)
- Created `ANALYSIS REPORT/` in the repo root: `ANALYSIS_REPORT.md` (full
  Part-A system probe with verbatim constants & file/function refs; fit
  assessment of reference mechanics B1–B4 and new features C1–C5; punch-list
  integration proposal; 12 design questions; environment appendix) + copies
  of the full sim/render/tests/tools/data source, STEP3_HANDOFF.md,
  sweep_out.txt, and the agent-memory status ledger.
- Seeded this PROJECT KNOWLEDGE folder with real content (00–05 filled from
  the probe; 06/07 appended): vision, architecture, materialized punch list
  (previously lived only in agent memory), handoff, known issues KI-1..KI-10.
- **No code or original-doc changes** — the probe was read-only by
  instruction. Files touched: `ANALYSIS REPORT/*` (new),
  `PROJECT KNOWLEDGE/00..07`.
## 2026-06-11 — Initial git commit + push; design rulings recorded
- **Priority #0 (per DESIGN_RULINGS R10 note):** initial commit `5fd5d97`
  pushed to https://github.com/AlohaOe-SD26/OSRS-AFK (main). Added Godot
  editor-cache (`.godot/`) and `*.rar`/`*.zip` ignores; unstaged the cache.
  KI-1 (no git history) RESOLVED and removed from 05-KNOWN-ISSUES.md.
- Copied the design partner's rulings into the repo:
  `ANALYSIS REPORT/DESIGN_RULINGS.md`.
- Punch list restructured under the rulings: #1 = Unit 0 with sub-items
  #1a–#1e (save-migration scaffold pulled forward per R10; Vannaka/bounty/
  sweep-instrumentation scope per R4/R5/R6); #11 merged into #1a; #3/#5/#6
  updated with ruled constants (40% routing, escrow, 1% GE tax, bank-in,
  C4 ceiling formula); decisions log appended.
## 2026-06-11 — Save-migration scaffold (punch-list #1a, ruling R10)
- `SaveLoad.gd`: added `migrate()` — an ordered per-version upgrader chain
  (`_chain()`, injectable for tests) run by `load_from_file` before
  `load_world`; unmigratable saves (future version / chain gap) still
  return null. Ruled contract honored: migrated saves load validly and
  continue deterministically from the load point; cross-version
  byte-equivalence explicitly NOT required.
- `tests/test_sim.gd`: +5 checks (identity at current version; future
  version rejected; synthetic v0 walks the chain; migrated save loads with
  state ≡ source; deterministic continuation 500 ticks). Suite now 106/106.
- Gates: `gate_saveload.gd` IDENTICAL on all 3 seeds (load path now routes
  through `migrate()`). KI-3 RESOLVED — every future save-shape change
  bumps SAVE_VERSION and appends its upgrader.
