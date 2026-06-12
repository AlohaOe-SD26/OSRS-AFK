# Known Issues — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. Open problems only — when an issue is
> fixed, remove it here and record the fix in 07-CHANGELOG.md.
> KI numbers never get reused. (Seeded 2026-06-11 from the probe; details in
> `ANALYSIS REPORT/ANALYSIS_REPORT.md` §A11.)

## KI-2 — Stale snapshot dirs & docs (opened 2026-06-11, severity: low)
- **Symptom:** `gielinor-tycoon-(4.3)/` and `(copy)/` are early-phase project
  snapshots containing the outdated `PROJECT_STATUS.md`; confusable with the
  live `game/` build.

## KI-4 — §18 combat-utility asymmetry (opened ~2026-06-09, severity: med,
  status: CONFIRMED structural by the #1e sweep, 2026-06-12)
- **Symptom:** combat's base utility is price-independent (no reward
  saturation) + congestion discounted ×0.5 → combat is the standing refuge.
  The old ~8–20% mitigation was lethality in disguise: once the #1d
  survival triad made combat safe, combat-share rebounded to 39–44%
  (8 seeds, all on-task arms — `tools/diag_unit0.gd`).
- **Fix path REVISED by the BRAIN_V2 4th test (#1e):** V2 as built makes it
  WORSE (52±3 vs 44±5) — saturating bases drain appeal from a gatherer's
  trained favorite while untrained strength stays a maximal-need refuge for
  everyone. V2 stays default-OFF. A real fix needs a combat-side
  counter-force: reward saturation / price coupling on the combat base
  (Unit-1+ catalog/pricing work is the natural home), not more breadth.
  V2's one clear win — gold variance collapses ±332→±84 — is worth
  salvaging when the base shape is fixed.

## KI-6 — Ammo economy feel-tuned only (severity: low)
- **Symptom:** with consumption on, kills 812 vs 2634 free — bounded and
  lockout-free (dry-punch fallback), but "is it fun" is unvalidated
  (playtest item).

## KI-7 — Dead pathing heuristics in SimWorld (severity: low, cleanup)
- **Symptom:** `_route`, `_route_river`, `_seg_crosses_city`, `_GATES` are
  unused since the grid-BFS pathfinder shipped. Left untouched by the
  read-only probe.

## KI-8 — Economy.GOODS vs items.json base-value mismatch (severity: low,
  blocks pricing work)
- **Symptom:** live shop base values are hardcoded in `Economy._init`
  (ore 16) while the catalog says iron_ore 17, etc.; gear lives in Config
  tables, not the catalog.
- **Fix path:** the catalog migration (punch #2) — must precede GE/city-
  order/item-cost features.

## KI-9 — `--shot` capture can inherit stray-click popup state
  (severity: cosmetic, capture-only)

## KI-10 — Watch numbers (standing): heavy-shop treasury-throughput ceiling
  (squeezed by 3 consecutive faucets, re-relieved — re-check per economy
  change); post-collision equilibrium is travel-bound (kills ~5× below
  pre-collision peak — watch).
