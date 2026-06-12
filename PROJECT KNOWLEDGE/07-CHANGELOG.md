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
## 2026-06-11 — Slayer core: Vannaka, tasks, on-task pull (punch-list #1b; rulings R4–R6)
- **Sim:** `kill_counts` colony-knowledge dict + `slayer_tasks_assigned` on
  SimWorld; `slayer_task`/`slayer_points` + slayer skill on Hero; Vannaka
  assignment (`slayer_pool` → knowledge gate 100/15-boss, slayer-level req,
  `Combat.fight_is_winnable` feasibility with affordable-food loadout +
  risk-trait margin), HP-band task sizing (boss 3–8 / ≥20hp 8–20 / ≥10hp
  14–35 / else 20–60), kill attribution (`_record_kill`: 0.9×HP slayer XP
  on-task, 8–16 points on completion), Vannaka check-in chained into FIGHT
  trips like buyfood/buyammo. Combat-40 canon gate (`SLAYER_COMBAT_GATE`).
- **Brain:** `task` term (+`SLAYER_ON_TASK` 20, static var → sweepable) on
  the FIGHT candidate of the task camp.
- **Content/render:** `vannaka` map location on the Edgeville road outside
  the west gate (R4 documented divergence; comment in varrock_map.json);
  `npc` location kind (armoured figure).
- **Save v2** (first real use of the #1a scaffold): new fields serialized;
  `_migrate_1_to_2` upgrader; `sim_hash` fingerprint extended with
  kill_counts + per-hero task state.
- **Verified:** suite 122/122 (14 slayer checks + 2 real-migration checks);
  determinism/save-load/offline gates all PASS (Slayer inert below combat
  40 → validated baselines untouched in 12-day runs).
## 2026-06-12 — Funded per-kill bounty; FIGHT incentive retired (punch-list #1c, ruling R5)
- **Sim:** `bounties` dict on SimWorld (monster type_id → gold/kill);
  `set_bounty` clamps to 0–3× the monster's average coin drop
  (`bounty_cap`/`avg_coin_drop` — rats use the re-tuned Config range);
  `bounty_affordable` is the ONE affordability rule read by both payment
  and attraction; `_record_kill` pays treasury→hero per kill (overdraw
  impossible). `set_incentive("FIGHT")` now rejects — the clamped utility
  combat bounty is retired same-unit per R5.
- **Brain:** `bounty` term on FIGHT candidates = affordable payout × 0.2 ×
  (0.6+greed) — the same greed-weighted reward shape as coin drops; one
  lever, two effects. Empty treasury → zero attraction.
- **Render:** topbar Town tab — "Kill bounties" row (per KNOWN monster,
  click cycles 0→1×→2×→3× avg drop→off); gather-incentive row keeps
  Mine/Chop/Fish only.
- **Save v2 extended** (defensive `.get` defaults, same pattern as atk_cd):
  bounties + scurrius_unlocked serialized; sim_hash fingerprints bounties.
- **Verified:** 6 new suite checks (clamp, term derivation, affordability
  symmetry, payment, overdraw guard, FIGHT-incentive rejection).

## 2026-06-12 — Aggressive monsters + Scurrius gate + the survival triad (punch-list #1d)
- **Sim:** aggressive monsters (goblins/dark wizards/zombies/Scurrius per
  catalog flags) chase the nearest non-fighting hero within 2.4 tiles and
  strike when adjacent (same mitigation math as fight-phase retaliation;
  `atk_cd` per monster, serialized). Struck workers eat at <45% HP or
  abandon the trip below 60% and fall back to town. `_hero_death` extracted
  to a shared handler (fight loop + aggro strikes): death counter, §8
  reputation dent, §14 gravestone-loot grudge, town respawn.
- **Scurrius:** boss camp `scurrius` (Rat Pit nest, map loc added) locked
  until 300 colony rat kills (`_check_boss_unlock`, same kill_counts
  knowledge as the Slayer pool); brain hides locked-boss candidates;
  240s boss respawn; boss kill = milestone + town-news Chronicle line.
- **The survival triad** (first cut was a meat grinder — 2,096 deaths/24k
  ticks, reputation pinned 0, goblin culling collapsed to 96 kills because
  perma-chasing goblins never stood still):
  1. **Canon passive regen** — 1 HP/min, pulsed off the serialized
     `action_n` counter (no new save state).
  2. **Canon aggression tolerance** — `tol_t` per hero (serialized);
     monsters ignore heroes >8s into their current trip. Harassment is an
     ARRIVAL TAX, not sustained DPS — the OSRS rule that lets players
     skill near aggressive mobs.
  3. **Brain danger term** — gather candidates at camps with live
     aggressive monsters carry −threat × frailty (hurt/foodless heroes
     look elsewhere; bug-class rule: every force needs a counter-force).
  Plus: **bosses are lair-bound** — they strike only trespassers whose
  trip targets the lair (first cut: Scurrius farmed the adjacent rat pit,
  ~800 hero kills).
- **Measured (diag_aggro.gd, 24k ticks, immigration on):** deaths 2,096→4
  (rare, narratable — the gravestone/grudge channel is LIVE but
  occasional); reputation 0→60.8; goblin kills 96→3,730; Scurrius slain
  16× vs 2 trespasser deaths; pop 42; economy bounded.
- **Verified:** suite 141/141 (13 aggro/boss/bounty + 6 survival-triad
  checks); determinism / save-load / offline gates PASS; render parses.

## 2026-06-12 — Unit-0 closing sweep + BRAIN_V2 4th test (punch-list #1e; ruling R6) — UNIT 0 COMPLETE
- NEW `game/tools/diag_unit0.gd`: the instrumented Unit-0 sweep — 8 seeds ×
  SLAYER_ON_TASK arms {0, 10, 20, 35} × 23 sim-days, reporting per arm:
  monoculture (% non-favorite-fighting), full social-tier distribution +
  rival-lean delta, per-capita gold (band re-baseline), deaths/run, tasks
  assigned, % of fighters on-task.
- `game/tools/diag_stage2.gd`: arms relabeled/repinned as the BRAIN_V2
  4th test (v1 vs v2 on the post-Unit-0 surface).
- **Results:** SLAYER_ON_TASK locked at +20 (saturation; see decisions
  log). §18 prediction split — rival-lean half held (web friend-leaning;
  **KI-5 resolved & removed**), combat-share half failed (39–44% all arms;
  **KI-4 re-confirmed**, fix path revised to combat-side reward
  saturation). **BRAIN_V2 4th test: v2 worsens monoculture 52±3 vs 44±5,
  collapses gold SD ±332→±84 — default stays OFF.** Gold band
  re-baselined to 1,460 ± 332 (day-23, 8 seeds).
- No sim-code changes this item (tools + docs only) — suite/gates verdicts
  from #1d (141/141, 3 gates green) remain the standing verification.
- Note: `.godot/` editor cache was absent after the gitignore cleanup; the
  first headless run on a fresh tree must rebuild it (`godot --headless
  --path game --import`) or new tool scripts fail to parse class names.
