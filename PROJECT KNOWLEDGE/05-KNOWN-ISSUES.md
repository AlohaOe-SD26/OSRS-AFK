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
  status: OPEN — structural; #3d (2026-06-13) found NO shippable mitigation)
- **Symptom:** combat's base utility is price-independent (no reward
  saturation) → without enough crowding back-pressure, combat is the
  standing refuge for non-fighters (integrated non-fav share ~28%).
- **#3d closing sweep (`diag_unit2_close.gd`, 8 seeds × 23 days) — TWO
  candidate counter-forces, both rejected:**
  - **Gear-drop reward coupling** (`COMBAT_GEAR_REWARD`, the new lever):
    FALSIFIED — turning it ON WORSENS monoculture at every congestion level.
    It is a POSITIVE ~7-pt reward and the gear board only floors at ~11–17
    (town demand + the 4% drop rate keep it off the floor), so its downward
    saturation is too weak to act as the intended counter-force; it just
    makes combat more attractive. Stays default-OFF.
  - **Raising `COMBAT_CONGESTION_MULT` 0.5 → 1.0:** DOES drop monoculture
    28→23% without cratering kills (~21k) — the intended effect works — BUT
    1.0's higher run-to-run variance (g/cap SD ±355 vs ±235) breaks the
    OFFLINE re-convergence gate (seed beef01 Δ31% vs ≤25%). Gate-blocked, so
    held at 0.5. (0.75 buys no gain and destabilizes g/cap to 1082±470.)
- **Next attempts when revisited:** reformulate the gear coupling as a
  saturation PENALTY (not a positive reward), or couple far harder so the
  board actually crashes; and/or land the BRAIN_V2 base-shape fix first.
  BRAIN_V2 (also default-OFF) still owns a salvageable win — gold variance
  ±332→±84 — once the combat base shape is fixed. The #3d mechanism +
  price-coupling are unit-tested (flag-gated), so a reformulation has a base.

## KI-6 — Ammo economy feel-tuned only (severity: low)
- **Symptom:** with consumption on, kills 812 vs 2634 free — bounded and
  lockout-free (dry-punch fallback), but "is it fun" is unvalidated
  (playtest item).

## KI-7 — Dead pathing heuristics in SimWorld (severity: low, cleanup)
- **Symptom:** `_route`, `_route_river`, `_seg_crosses_city`, `_GATES` are
  unused since the grid-BFS pathfinder shipped. Left untouched by the
  read-only probe.

## KI-9 — `--shot` capture can inherit stray-click popup state
  (severity: cosmetic, capture-only)

## KI-10 — Watch numbers (standing): heavy-shop treasury-throughput ceiling
  (squeezed by 3 consecutive faucets, re-relieved — re-check per economy
  change); post-collision equilibrium is travel-bound (kills ~5× below
  pre-collision peak — watch); post-Unit-1 telemetry flagged "5 fighters
  broke & foodless" at one end-of-run snapshot (momentary-state check,
  suite food-floor checks green, drift +4% — watch, don't react);
  **the rolled-character batch (#13–#15) settled the g/cap band at 1,384 ± 174**
  (1,501 ± 235 all-fixed → 1,482 ± 448 founders → 1,337 ± 269 +immigrant gold →
  1,384 ± 174 +immigrant gear). Variance TIGHTENED and deaths FELL across the
  batch (gear-equipped arrivals survive better); mean held in the attractor
  range, all colonies viable (≥1 fisher). The band is healthy and stable — no
  action; re-run `diag_founders.gd` after any future wealth change.
