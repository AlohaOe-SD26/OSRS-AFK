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

## 2026-06-12 — Unit 1: catalog migration (punch-list #2; ruling R8) — KI-8 RESOLVED
- **Catalog is the single item truth.** `items.json` extended: tradeable
  flags, gear `tier`/`style`, slots unified to Hero slot keys (main/off/
  head/torso), 9 new entries (shortbow, apprentice_staff, wooden_shield,
  fishing_rod, arrows, runes, iron_sword, oak_shortbow, battlestaff,
  leather_cowl, iron_helm, iron_platebody), recipes carried in
  `acquisition` (craftSkill/craftLevel/craftXp/recipe/dropPool).
  `ItemType` gained the fields + accessors; `ContentDB` gained
  `gear_drop_pool()` (catalog file order — preserves the old RNG→item
  mapping), `tier()`, `style()`, `craft_output()`.
- **Canon id rename (KI-8):** sim inventory/equipment/shop keys are catalog
  ids now — ore→iron_ore, raw_fish→raw_trout, cooked_fish→trout,
  Arrows/Runes→arrows/runes, Pickaxe/Axe/Fishing rod→bronze_pickaxe/
  bronze_axe/fishing_rod, and all display-name gear → ids (~81 sites,
  14 files). Logs/milestones/render display via new `SimWorld.item_name()`.
- **Economy is ContentDB-driven:** `Economy.new(content)` sources base
  values from the catalog (iron_ore 17 supersedes the hardcoded 16);
  `GEAR_DROPS`/`GEAR_TIER` Config tables RETIRED (drop/tier/style reads go
  to the catalog). **Shops trade gear:** every tradeable tiered item joins
  the General Store board (stock 4/max 8/consume 0.25 — fill 0.5 open
  reproduces the old half-value vendoring; flat 0.5× mint retired;
  gear sales are taxed + backpressured like any good).
- **Recipes-as-data:** cook (raw_trout→trout, craftXp 6) and smith
  (3×iron_ore→iron_sword, craftXp 40) resolve via `craft_output()` —
  behavior identical, the mapping now lives in data.
- **`GE_TAX`→`SHOP_TAX`** (R8 cosmetic): Config, Economy, offline
  projection, telemetry strings.
- **Save v3** + `_migrate_2_to_3`: id remap across hero inv/equipment and
  shop dicts + gear-board injection (frozen inline values — an upgrader
  must not depend on live catalog state); load_world passes content.
- **Verified:** suite **153/153** (+12 Unit-1 checks: KI-8 parity, gear
  routing/pricing/vendoring, tradeable gating, both recipes, drop pool,
  v2→v3 inv/equip/shop migration + load); determinism / save-load /
  offline gates PASS; render parses; telemetry day-23 drift +4%,
  g/cap ~1,790 (within 1σ of 1,460±332). KI-8 removed from
  05-KNOWN-ISSUES; "5 fighters broke & foodless" snapshot flag noted
  under KI-10 watch numbers.

## 2026-06-12 — Unit 2 #3a+#3b: 7-shop roster, dynamic buy pricing, imports, unlocks, treasury ledger (punch #3; rulings R1/R3)
- **NEW `data/shops.json`** — the shop roster is DATA now: 7 shops (General
  Store, Fishmonger + the R3 greenlit Horvik/Lowe/Zaff/Aubury/Swordshop).
  Gear re-routed from the Unit-1 General-Store board to the specialist
  shops; General Store gains tool arms (pickaxe/axe/rod). Loaded by
  ContentDB; Economy builds the roster from it (legacy 2-shop fallback
  for bare rigs).
- **Per-good dynamic BUY pricing**: `Shop.charge_price` (scarcity curve
  normalized so baseline 0.5 fill = the validated flat cost exactly —
  tools 12g, weapon 30g, offhand 35g, ammo bundle 12g). All four buy exec
  sites (tool/weapon/offhand/ammo) route through `Economy.buy_item`:
  purchases draw REAL stock (supply-gated, R3) and affordability checks
  read the live price.
- **Ambient imports (C5)**: `Shop.import_tick` — stock drifts up toward
  per-good `baseline` (K=0.5/day); only town-supplied goods participate
  (hero-supplied goods keep baseline 0 — gather faucet untouched).
  TUNED: ammo baselines 8→60 bundles after the first telemetry run showed
  a supply cliff (kills 21.8k→16.3k, g/cap −24% — fighters dry-punching;
  the exact R3 anti-pattern). Post-fix: kills 20.8k, drift −2%.
- **Tier-up stock unlocks**: per-good `unlockLevel` gates BUYING only
  (tier-2 gear needs shop level 2); vendoring is never gated.
- **R1 ledger**: `PURCHASE_TREASURY_ROUTE = 0.40` — 40% of every hero
  purchase (food included) funds the treasury, 60% burns; five
  inflow/outflow counters (tax/routing/bounty/upgrade/building) wired at
  every site, serialized, and printed by telemetry (day-23 single seed:
  treasury 78k = tax 28k + routing 50k).
- **Save v4** + `_migrate_3_to_4`: roster reshape (gear-arm transplant to
  the new owner shops, tool arms added, frozen inline defs), ledger
  counters; idempotence-guarded appends.
- **OFFLINE GATE CRITERION v2** (measurement fix, documented): the
  endpoint-only Δ compared two DECOUPLED stochastic runs — a seed that
  converged to Δ5% mid-window drifted to Δ29% at the endpoint and failed
  falsely. v2 = re-entry (closest-tail Δ ≤ 25% over the last 4 samples) +
  endpoint runaway guard (≤ 50%). beef01 closest-tail Δ 0%.
- **Verified:** suite **169/169** (+16 Unit-2 checks); determinism /
  save-load / offline gates PASS; render parses; telemetry drift −2%,
  kills 20,829, deaths 9.

## 2026-06-12 — #3c price-bias lever MECHANICS + directive batch (#13–#16, coinpurse invariant) — session wrap-up
- **#3c lever BUILT** (sweep still pending — see punch list): per-good
  `price_bias` on what shops PAY heroes, clamped to `PRICE_BIAS_MIN/MAX`
  (opening stance 0.70–1.30; the diag_bias sweep locks it). Overpay
  premium is TREASURY-FUNDED + affordability-gated per sale (degrades to
  base when unfunded — the bounty pattern; overpay mints gold, so it must
  be funded re-injection per R1); underpay just shrinks the faucet (no
  treasury flow — pocketing savings would mint treasury gold). The brain
  reads the biased price through `sell_price` (steering is organic).
  Town-tab cycle row (100%→MAX→MIN→100%); `treasury_out_bias` counter +
  telemetry; **save v5** + v4→v5 upgrader; NEW `tools/diag_bias.gd`
  (clamp sweep, 4 arms × 6 seeds — WRITTEN, NOT YET RUN).
- **Directive batch (2026-06-12)**: coinpurse invariant LOCKED in the
  decisions log (hero gold never pools); punch items #13 (founders fully
  rolled), #14 (immigrant gold rolled in economy-fitted bands), #15
  (immigrant gear rolls), #16 (Legendary & Easter-Egg arrivals, GE-gated
  per-run) recorded with full specs.
- **Verified:** suite **176/176** (+7 bias checks); determinism /
  save-load / offline gates ALL PASS on the v5 shape.
