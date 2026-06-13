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

## 2026-06-13 — #3c price-bias clamp LOCKED → Unit 2 sub-item #3c CLOSED
- **Ran the clamp sweep** (`tools/diag_bias.gd`, 6 seeds × 16 days, bias
  on logs from day 3, organic treasury). **Locked `PRICE_BIAS_MIN/MAX` at
  0.70 / 1.30** — the opening stance, now evidence-backed. The binding
  axis is treasury FUNDING: 130% overpay stays funded (treasury end
  16.7k), 150% breaks it (9.6k ± 9.9k, crosses 0 within 1σ; 37k drain ≈
  full organic inflow). Steering is real & monotonic (WC share
  13.1→14.0→14.7%); g* bounded in every arm. Underpay 0.70 floor is
  structurally safe (no treasury flow). Full arm table + rejected 1.50
  ceiling in 06-DECISIONS-LOG.
- Config comment updated with the sweep result (was "the #3c sweep locks
  the number"); no code/save-shape change — the clamp values were already
  the opening stance, so suite/gates unaffected.
- **Verified:** suite **176/176**; determinism / save-load / offline gates
  ALL PASS. **Unit 2 sub-item #3c is DONE.** Remaining in Unit 2: #3d
  (KI-4 counter-force sweep + Unit-2 closing band re-baseline).

## 2026-06-13 — #3d KI-4 closing sweep (NEGATIVE RESULT) → Unit 2 (#3) CLOSED
- **Built the combat gear-drop reward coupling** (KI-4 counter-force candidate):
  `Config.COMBAT_GEAR_REWARD` flag + `COMBAT_GEAR_K`, `Economy.gear_board_ref_
  price()` (avg saturation-aware sell_price over drop-pool gear), and a gated
  greed-weighted `gear` term in `Brain._score_fight` symmetric to gather's
  price-saturating reward. Default OFF → zero change to the shipped sim. +3 suite
  checks (flag gate / price read / flood-shrinks-reward) — **179/179**; 3 gates
  PASS with hashes IDENTICAL to pre-#3d (default-OFF proven inert).
- **Ran the closing sweep** (`diag_unit2_close.gd`, 6 arms = congestion {0.5/0.75/
  1.0} × coupling {off/on}, 8 seeds × 23 days, integrated monoculture).
- **OUTCOME: no shippable combat-side KI-4 mitigation — #3d ships ZERO behavior
  change** (COMBAT_CONGESTION_MULT HELD at 0.5; gear-coupling stays OFF):
  - **Gear-coupling FALSIFIED:** ON worsens monoculture at every congestion level
    (+4..+7 pts) — it's a positive ~7-pt reward and the board only floors at
    ~11–17, so its downward saturation is too weak to bite. Stays default-OFF for
    future salvage (cf. BRAIN_V2).
  - **Congestion 1.0 gate-BLOCKED:** it DOES drop monoculture 28→23% without
    cratering kills (~21k flat), but its higher variance (g/cap SD ±355 vs ±235)
    breaks the OFFLINE re-convergence gate (seed beef01: closest-tail Δ31% vs ≤25%;
    was Δ0–2% at 0.5). Caught by running the gates AFTER the metric-based lock — so
    reverted. A green release gate must not be weakened to ship a tune.
  - **0.75 rejected:** no monoculture gain (27%) + destabilized g/cap (1082±470).
- **Unit-2 closing band re-baselined at the shipping config (0.5/off): per-capita
  gold 1,501 ± 235** (8 seeds, control arm) — supersedes 1,460±332; tighter variance,
  mean inside the old band.
- **Verified (0.5/off):** suite 179/179; determinism / save-load / offline gates
  PASS. KI-4 stays OPEN (structural, documented — 05-KNOWN-ISSUES). **Unit 2
  (punch #3) CLOSED** (negative result; code delivered = the OFF gear lever +
  diag_unit2_close.gd). Full arm table + rationale in 06-DECISIONS-LOG.

## 2026-06-13 — #4a parameterized-nudge SIM CORE + loot-filter (Unit 3 begins)
- **Parameterized nudges (C1 sim core).** `nudge_hero(h, intent, params={})` now
  accepts optional per-trip params, merged onto the intent head by
  `_apply_nudge_params`: `loc` (gather site / combat camp override), `count_range`
  `[min,max]`, `loot_policy`, plus `mon`/`suggested_items` carried for #4c. When the
  nudge wins the decision, `_apply_choice` ROLLS `count_range` (seeded) into
  `act["count_target"]` and stores `act["loot_policy"]`. The trip FSM reads the rolled
  target at all three completion sites (FIGHT `COMBAT_TRIP_KILLS`, gather 14, fish 8
  → `count_target` when set). An empty `params` = a plain nudge = the old behavior.
- **loot_policy drop-filter (R7).** `SimWorld.loot_keeps(policy, it)` gates the
  carried-vs-salvage branch in `_gear_drop` for NON-upgrade drops (upgrades still
  auto-equip): keep-all (default/autonomous) carries if room; upgrades-and-valuables
  carries only base_value >= `LOOT_VALUABLE_MIN` (40); salvage-all always salvages.
  NOT ground loot (graves = wave e).
- **Determinism preserved WITHOUT a re-baseline:** the new RNG roll is drawn ONLY on
  the parameterized-nudge path (`if c.has("count_range")`), never autonomous play —
  so the gate hashes are IDENTICAL to pre-#4a (determinism/save-load 3974639208).
- **Save v5 → v6:** the new keys are OPTIONAL on the per-hero act/nudge dicts (read
  with defaults), so a v5 save loads and continues correctly; the `_migrate_5_to_6`
  upgrader just stamps the version (forward-compatible, R10).
- **Verified:** suite **186/186** (+7 #4a checks); determinism / save-load / offline
  gates PASS (identical hashes — autonomous stream unperturbed). Next: #4b feasibility
  gating, then #4c the Control-node popups (needs F5 visual verification).

## 2026-06-13 — #4b nudge feasibility gating (B4)
- **Sim predicate** `SimWorld.nudge_feasible(h, intent) -> {ok, reason}`: a nudge
  is feasible if the hero can act now, ALLOWING a cheap acquisition step they can
  afford (buy the missing tool/weapon/food — matching the brain's own affordability
  gates); it disables only when they categorically can't (no kit AND broke), or when
  seized (use direct Command). Pure read; +6 suite checks.
- **Render gating (Main.gd, immediate-mode — existing paradigm, no Control nodes yet).**
  `_button` gained `enabled`/`tip` params: an infeasible NUDGE button draws dimmed,
  absorbs its click as a no-op (kind "noop" → never falls through to deselect the
  hero), and registers a hover-tooltip with the reason. New lightweight tooltip
  layer: `_tips` (rebuilt each draw), `_mouse_pos` (tracked on MouseMotion),
  `_draw_tooltips`/`_draw_tip_box` drawn last (on top) at both `_draw_hud` exits.
  Seized DIRECT commands are NOT gated (direct control, different contract).
- **Verified:** suite **192/192**; determinism / save-load / offline gates PASS;
  Main.gd parses clean (--import). The VISUAL (dim buttons + tooltip box) is
  render-only and needs an F5 pass to confirm appearance — flagged for the user.
  Next: #4c Control-node parameterized popups (R11).

## 2026-06-13 — #4c Control-node parameterized nudge popup (R11) — Unit 3 feature-complete
- **New `render/NudgePopup.gd`** — the project's FIRST Godot Control-node UI. A modal
  popup (CenterContainer → PanelContainer → VBox of OptionButton/SpinBox/Button rows,
  on a dedicated CanvasLayer above the HUD): pick the ACTIVITY (Fight / Mine / Chop /
  Fish), the TRIP LENGTH as a [min,max] range the hero rolls within (#4a count_range →
  count_target), and the LOOT POLICY for fights (#4a drop-filter). Feasibility (#4b
  `nudge_feasible`) disables the Nudge button + shows the reason. Palette mirrors Main's
  HUD hexes (R11 cond. 2). Render-layer only: reads the sim read-only, emits
  `submitted(intent, params)` for Main to dispatch via `nudge_hero(...)`.
- **Main.gd wiring:** a CanvasLayer + the popup are built in `_ready`; a "Custom nudge…"
  button on the hero command row (kind `nudge_popup`) opens it; `_on_nudge_submitted`
  dispatches the commitment. Immediate-mode HUD otherwise untouched.
- **Paradigm split LOGGED** (06-DECISIONS-LOG, R11): complex-input forms → Control
  nodes; HUD/panels → immediate-mode. Target/monster routing DEFERRED (one combat camp
  today; FSM mon-routing unwired) — the popup exposes only the FSM-wired params.
- **Verified (logic/parse):** suite **192/192**; determinism / save-load / offline gates
  PASS; both Main.gd and NudgePopup.gd compile (`--import`). **The VISUAL + interaction
  (popup layout, dropdowns, the #4b dim-buttons/tooltip) CANNOT be confirmed headless —
  needs an F5 pass by the user.** Unit 3 is feature-complete pending that visual sign-off.

## 2026-06-13 — #13 rolled founders (random character generation) + band re-baseline
- **Founders are fully ROLLED on the seeded RNG** (was a fixed template): per-founder
  random favorite, weapon style (fighters), starting gold (band 20–100g), name,
  appearance (skin/hair/shirt), and a spawn tile rolled inside the city walls. Same
  seed ⇒ same founders (determinism holds). `_make_hero(i, favorite)` now does the
  rolls over the id-indexed defaults; `_founder_favorites` rolls the spread with a
  viability floor (≥1 fisher — the colony's only food source); `_new_hero` gained a
  `weapon` param so the style-skill boost and `h.weapon` agree (id%3 retires for
  rolled founders; kept for locked/immigrants until #14); `_roll_city_spawn` picks a
  cached walkable city cell.
- **`Config.FOUNDERS_LOCKED`** debug/repro flag (default OFF = rolled): ON = the
  original fixed template, byte-identical (no extra RNG draws). The test suite pins it
  ON so role-dependent checks stay stable; +7 dedicated rolled-founder checks exercise
  the OFF path (determinism, viability, gold band, weapon-style, spawn-in-walls).
- **No SAVE_VERSION bump** (rolled values live in already-serialized hero fields).
- **Band RE-BASELINED** (`tools/diag_founders.gd`, 8 seeds × 23 days, rolled): per-capita
  gold **1,482 ± 448** (supersedes 1,501 ± 235) — mean preserved (attractor pins it),
  variance widened by the random favorite-spreads. Viability VALIDATED: ≥1 fisher every
  seed, all colonies alive (pop 40–43). WATCH (KI-10): deaths 11.4 ± 16.1 — seed 7a11 an
  outlier (50 deaths, combat-heavy roll), two seeds low g/cap (~880, alive).
- **Verified:** suite **199/199**; determinism / save-load / offline gates PASS (rolled
  founders; offline re-convergence held). Determinism hash re-baselined (1847147488).

## 2026-06-13 — #14 immigrant gold in economy-fitted bands + rolled weapon style
- **Immigrant starting gold is now a rolled tier BAND** (fraction of GOLD_ATTRACTOR_REF
  1482), replacing the fixed 20/45/130/320: NEWCOMER_TIERS gains `gold_frac` [lo,hi]
  per tier (Greenhorn 1–3% ≈15–44g, Seasoned 3–7%, Veteran 8–15%, Elite 18–30%
  ≈267–445g — tiered, low-modest / high-wealthy-but-bounded < g*). `spawn_immigrant`
  rolls gold via `_roll_tier_gold` on the seeded RNG.
- **Immigrant fighters roll their weapon style** (#13(d) for arrivals): the `_new_hero`
  weapon param carries a rolled sword/bow/staff; immigrant id%3 retired.
- **No SAVE_VERSION bump** (values in existing fields; tier shape is a Config const).
- **Band RE-BASELINED** (`diag_founders.gd`, 8 seeds × 23 days, rolled founders + rolled
  immigrants): per-capita gold **1,337 ± 269** (supersedes 1,482 ± 448). Within-noise
  stream shift (the immigrant rolls perturb the RNG from the first arrival); all colonies
  viable (≥1 fisher, pop 40–43), the #13 death outlier washed out (deaths 11.1 ± 7.4).
- **Verified:** suite **205/205** (+6 #14 checks: gold-in-band per tier, tiered,
  bounded < g*, fighter weapon valid, determinism); determinism / save-load / offline
  gates PASS.
