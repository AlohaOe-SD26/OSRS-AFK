# GIELINOR TYCOON — ECONOMY & INCENTIVE SYSTEMS ANALYSIS REPORT

**Date:** 2026-06-11
**Author:** Claude Code (the project's build agent)
**Audience:** an external design partner with NO access to this codebase. Everything load-bearing is quoted verbatim from source, with file/function references. Status tags: ✅ implemented · 🚧 partial · 📋 planned · ❌ absent.

**Constraints honored while producing this report:** strictly read-only probe; zero modifications to any existing code or documentation; the only writes were (1) this `ANALYSIS REPORT` folder (report + file *copies*) and (2) seeding the `PROJECT KNOWLEDGE` folder per Part E. No implementation of any Part B/C feature has begun. The existing punch list and the side-panel UI (Roster, Menu) are preserved as-is.

---

## MANIFEST — what is in this folder and why

| Path | Why included |
|---|---|
| `ANALYSIS_REPORT.md` | This report (deliverable of record). |
| `SOURCE_COPIES/sim/` (18 files) | The **entire deterministic sim core** — every probed system lives here: `Config.gd` (all tuned constants), `Economy.gd` + `Shop.gd` (shops/treasury), `Brain.gd` (hero AI), `Hero.gd` (inventory/equipment/nudge state), `SimWorld.gd` (tick loop, combat, control tiers, offline catch-up), `Social.gd`, `Population.gd`, `SaveLoad.gd`, `Telemetry.gd`, `Combat.gd`, `Activities.gd`, `ContentDB.gd`, `ItemType.gd`, `Monster.gd`, `MonsterInstance.gd`, `Rng.gd`, `XpTables.gd`. Small enough to copy whole — ground truth for every formula quoted below. |
| `SOURCE_COPIES/render/Main.gd` | The complete render/UI layer (top bar, roster, menu, hero popup, command surfaces). |
| `SOURCE_COPIES/tests/test_sim.gd` | The 101-check headless gate suite ("done" is defined against this). |
| `SOURCE_COPIES/tools/` (17 files) | Determinism / save-load / offline gates + the multi-seed diagnostic sweep harnesses (`diag_*.gd`) referenced throughout; `ingest_osrsreboxed.gd` (dataset ingest); `headless_log.gd`, `sim_hash.gd`. |
| `SOURCE_COPIES/data/` (3 JSON) | The live content catalogs (`items.json`, `monsters.json`, `varrock_map.json`). |
| `STATUS_DOCS/STEP3_HANDOFF.md` | Status doc newer than the original design set (Step-3 findings for the planner). |
| `STATUS_DOCS/sweep_out.txt` | The Stage-1 gate-fix sweep evidence (16 seeds × 2 arms). |
| `STATUS_DOCS/AGENT_MEMORY_project-status.md` | **Copy of the build agent's persistent memory file — this is the de-facto live punch list / status ledger** (see §A1b/§A10: no punch-list file existed in the repo until Part E seeding; the real sequencing record lived here). Dense but it is the honest, complete history of every unit, gate result, and deferred decision. |

Not copied (unchanged originals, design partner already has them): the six root design docs, `prototype.html`. Stale snapshots `gielinor-tycoon-(4.3)/` and `gielinor-tycoon-(copy)/` are described in §A1b but not copied (they are full early-phase project snapshots, ~1.5k lines each, superseded by `game/`).

---

# PART A — PROBE REPORT

## A0. Architecture overview

**Engine & layout.** Godot **4.6.3**, GDScript. One project at `game/`:

- `game/sim/` — the **deterministic SIM CORE**: 17 `RefCounted` classes, zero Node/render dependencies, headless-runnable. ~3,300 lines.
- `game/render/Main.gd` — the **only** render/UI file (1,269 lines, immediate-mode `_draw()` UI; reads the sim read-only every frame).
- `game/tests/test_sim.gd` — the headless gate suite (**101 checks**; exits non-zero on any failure *or* if fewer than the expected check-count ran — a guard against false greens from aborted scripts).
- `game/tools/` — gates (`gate_determinism.gd`, `gate_saveload.gd`, `gate_offline.gd`) + multi-seed diagnostic sweeps (`diag_sweep.gd`, `diag_labor.gd`, `diag_incentive.gd`, `diag_stage2.gd`, `diag_social.gd`, `diag_asymmetry.gd`, `diag_ammo.gd`, `diag_lock_probe.gd`, `diag_decision.gd`, `diag_scale.gd`, `diag_chronicle.gd`) + `ingest_osrsreboxed.gd` + `headless_log.gd` + `sim_hash.gd`.
- `game/data/` — JSON content catalogs (hand-authored canon seed; the osrsreboxed ingest tool writes `*.generated.json` in the same schema, preferred when present — `ContentDB._prefer()`).

**Two sibling directories are STALE SNAPSHOTS, not the live build:** `gielinor-tycoon-(4.3)/` and `gielinor-tycoon-(copy)/` (~1,455 lines each) are Phase-0-era copies of the project; the `PROJECT_STATUS.md` the design partner flagged as stale lives inside them (dated 2026-06-08, "Phase 0 BUILT, NOT YET RUN IN GODOT"). The live build (`game/`, 6,522 lines) is months of work past that.

**Simulation model.**
- `SimWorld.tick(dt)` (SimWorld.gd:507) advances continuous movement/monster-wander per frame-`dt`, and accumulates `dt` into discrete **work-actions**: one action per `WORK_TICKS_PER_ACTION (4) × TICK (0.6s)` = **2.4 real seconds at 1× speed**. All economy/brain/social/population stepping happens per work-action.
- **Determinism:** a single seeded `Rng` (wrapper over Godot's `RandomNumberGenerator`, `Rng.gd`) is threaded through the sim; global `randf()` is banned; **RNG state is serialized into saves** so a reload continues the same stream. Draw-order is treated as part of the contract (e.g. hero BFS paths are *persisted* in saves because a fresh mid-trip BFS could tie-break differently — `Hero.path` comment, Hero.gd:39-41). Gate: `gate_determinism.gd` — same seed → identical state hash, 3 seeds × 12 days.
- **Sim/render separation:** the render layer holds a `SimWorld` and reads it; the LOD system is render-only and gate-proven unable to perturb sim outcomes.

**In-game time model** (several Part B/C specs are denominated in days — use these conversions):
- One work-action advances `SIM_MINUTES_PER_TICK = 1.4` sim-minutes (Config.gd:256; despite the name it is applied **per action**, `SimWorld._advance_clock`).
- **One in-game day = 1440 sim-min ≈ 1,029 work-actions ≈ 41.1 real minutes at 1× speed** (≈ 5.1 min at the 8× max speed).
- A 12-sim-day validation run = 12,000 ticks in the headless suite.
- Offline catch-up: at live cadence **24 real hours ≈ 35 sim-days** (comment at SimWorld.gd:1288).

**State shape & save format.**
- Save = a single binary Variant dictionary (`FileAccess.store_var`), `SAVE_VERSION := 1` (SaveLoad.gd:15). Serializes *everything that evolves*: heroes (incl. act-FSM, paths, nudge/seize state, goals, equipment, run-energy), monsters, shops (stock/max/base/consume/level), treasury + tax_collected, population, social adjacency, incentives, buildings, kick records, chronicle, clock/counters, **and the RNG state**.
- **Migrations: ❌ none.** `load_from_file` returns `null` on any version mismatch (SaveLoad.gd:160) — i.e. an old save is silently refused, the game starts fresh. Every schema-touching feature so far has simply bumped nothing (fields added with `.get(key, default)` fallbacks — see `_load_hero`'s defaulted reads, which is the de-facto *informal* forward-compat mechanism within version 1). **This is a known gap for the Part-C features** (city inventory, order book, craft queues all extend the save).
- Save is a **pure read** (no logging/mutation), so saving mid-run can't perturb the run — that's gate-asserted (`gate_saveload.gd`: save@mid → load → continue ≡ uninterrupted, 3 seeds).

**Checkpointing / versioning — ⚠️ honest flag:** a git repo exists with a GitHub remote (`https://github.com/AlohaOe-SD26/OSRS-AFK`), **but there are zero commits — the entire project is staged-only and never pushed.** Work has been checkpointed via the gate suite + the agent-memory status ledger, not via git history. This predates this exchange and fixing it is out of scope for a read-only probe, but the design partner should know the safety net is thinner than "git repo" implies. (The Project Kit bootstrap on 2026-06-11 added per-work-item commit/push duties going forward.)

**Performance budgets / scale targets.** `POP_CAP = 50` (the MVP "Living Varrock" target). Scale validation (Step 6.1): economy bounded at 50 heroes, **~305 ms per 1,000 ticks** headless; BFS pathfinding later slowed full 16-run sweeps to ~7 min (noted as fine, profile-if-zones-grow-it). Order-book matching at ≤50 heroes + 1 city buyer is comfortably inside this envelope; the expensive thing in this codebase has never been per-tick math, it's been *sweep wall-clock*.

**What "done" means (the verification gates).** A change is done when:
1. **The 101-check suite** passes (`godot --headless --path game --script res://tests/test_sim.gd`). Includes an economy-equilibrium regression: 6 heroes, 12 sim-days, population frozen, asserts `final_gold > 800`, `< 40000`, and **steady-state per-capita drift |%| < 60** (middle-third vs last-third of telemetry — warmup excluded; test_sim.gd:120-126).
2. **The relevant gate** passes: determinism (3 seeds), save/load (byte-identical continuation), offline (return-batch absorbed by the attractor; gain(30h)==gain(24h) exactly).
3. **Any emergent/behavioral claim gets a multi-seed sweep** (8–16 seeds; the measurement-discipline rule — single-seed results are RNG-confounded and have burned us).
4. Render smoke check on a real GPU when UI changed.
5. Sim-affecting changes report the new day-12 gold/drift band vs the previous (the running "economy band" in the status ledger).

**End-to-end narrative.** `Main._ready()` loads `ContentDB` from JSON, builds a `SimWorld` with 6 founder heroes on a 50×38-tile canon Varrock map, and ticks it from `_process`. Each hero runs a utility brain (`Brain.choose`) at trip boundaries: it scores gather/fight/smith/buy candidates from explicit term lists, applies player incentives/nudges, and commits to a trip FSM (travel → work → sell/cook/restock chains) executed one work-action at a time. Selling/buying routes through two NPC `Shop` entities with saturation-aware prices; a 3% tax on every sale accrues to the player's **treasury**, which funds shop leveling and three buildings. Population immigrates/departs against reputation; a sparse signed social graph accrues bonds/rivalries and feeds a Chronicle. Save/load, offline catch-up (attractor-projected), LOD, and a deterministic RNG stream are all gate-protected. The player steers via three tiers: **Incentivize** (standing utility bounty), **Nudge** (one-shot activity override), **Seize** (suspend brain, direct control).

## A1. Project intent & documentation state

**(a) Vision in my own words.** Gielinor Tycoon is a single-player desktop "ant farm" idle/tycoon set in canon OSRS Varrock. A procedurally generated cast of autonomous heroes lives a real player's life — they pick goals, train skills, buy tools, fight, cook, trade, form friendships and feuds — driven by a legible utility brain, not scripts. The player is a god/mayor who *steers* rather than commands: post incentives, nudge a hero once, or seize one outright; invest the town treasury in shops and buildings; curate the colony (kick votes). The economy is the load-bearing system: faucets (monster drops, shop purchases of hero goods) and sinks (proportional wealth upkeep, food/tools/ammo, taxes) are tuned to a **bounded equilibrium attractor** — gold per-capita is pinned regardless of population. The core loop is *watch → understand (Thoughts/Chronicle) → steer → watch the colony respond*. The endgame (post-MVP, designed but unbuilt) is growing the colony strong enough to defeat **Zezima**, an escalating rival, with reincarnation/prestige beneath it. The MVP slice ("A Living Varrock", steps 0–6) is **complete and green**; current work is the planned merge of a second concept prototype's look/brain/content onto this validated foundation (M1 visual port done; M2 brain-v2 measured & deferred; M3 content waves in progress).

**(b) Document inventory.**

| Doc | Role | Status |
|---|---|---|
| `HANDOFF.md`, `GAME_DESIGN_DOC.md`, `EQUATIONS_AND_SCHEMAS.md`, `ITEMS_MONSTERS_BALANCE.md`, `WORLD_AND_CHARACTERS.md`, `ASSET_PROMPT_PACK.md` (root) | The original six-design-doc set; actively worked from (GDD §-references pervade code comments) | **Unmodified from the originals** — confirmed (matches the design partner's verification) |
| `prototype.html` (root) | Behavioral reference carrying the validated Step-1 economy tune | Unmodified |
| `STEP3_HANDOFF.md` (root) | Step-3 findings written for the planner | Newer than the design set; accurate for its date (2026-06-08); superseded by later steps |
| `sweep_out.txt` (root) | Stage-1 gate-fix sweep evidence | Newer than the design set |
| `PROJECT_STATUS.md` | **Lives inside the two snapshot dirs**, NOT the root | **Confirmed stale** (predates Step-3+); the design partner's note is correct |
| **Agent memory** (`project-status.md` + `godot-environment.md` + `measurement-discipline.md`, outside the repo in the Claude memory dir) | **The real, current punch list / status / decision ledger** | Continuously current; copied into `STATUS_DOCS/` here |
| `PROJECT KNOWLEDGE/` (root, 8 files) | Project-Kit onboarding folder bootstrapped **2026-06-11** | Was an **empty skeleton** until this exchange; **now seeded** per Part E (see chat reply) |
| `CLAUDE.md` (root) | Standing per-session directives (Project Kit block) | Active since 2026-06-11 |

**Where the real punch list lives:** until today, in agent memory (`STATUS_DOCS/AGENT_MEMORY_project-status.md` is the copy) — the repo itself had **no punch-list file** (the design partner's observation is confirmed). As of this exchange it is also materialized in `PROJECT KNOWLEDGE/03-PUNCH-LIST.md` (single source of truth going forward).

**(c) Status/progress docs beyond the punch list:** the agent-memory ledger (above), `STEP3_HANDOFF.md`, and now the `PROJECT KNOWLEDGE` files (04-HANDOFF for current state, 06-DECISIONS-LOG, 07-CHANGELOG).

**(d) Standing directives a design partner should know about** (from the original docs + the planner agent's prompts + accumulated ratified rules):

1. **HANDOFF §5 invariants** (locked): dual-agency (every verb is both a player action and an autonomous behavior on the same systems); **dual-resolvability** (every activity needs a live tick path AND a statistical expected-yield path — offline/LOD depend on it); canon stats from the dataset; local perception (no hero omniscience); situational gear mechanics; live-only risk (offline is safe accrual ×0.75, 24h cap, rares ×0.5); quests deferred.
2. **The validated economy attractor is settled ground** — wealth-proportional upkeep + town consumption + tax + saturation pricing. Changes integrate around it; conflicts get flagged, not re-derived. (Same rule Part B states — already our standing rule.)
3. **Measurement discipline:** emergent claims require 8–16-seed sweeps; never tune on a single seed; don't over-tune transients — diagnose from telemetry first.
4. **Bug-class doctrine** (7 instances banked): *every dynamic needs back-pressure; any force without a counter-force becomes the attractor as everything else saturates.* New faucets/flows ship with their negative-feedback loop built in (e.g. smithing shipped glut-gated). This is the lens every Part B/C idea will be evaluated through.
5. **Default-off discipline:** behavior-changing features land behind a Config flag, are A/B'd by sweep, then flipped (e.g. `BRAIN_V2` is built but default-off after three measured failures-then-improvements; `GOALS_ON` flipped on only after an 8-seed gate).
6. **Godot harness rules:** sim classes use `class_name`, but tools/SaveLoad use `preload()` by path (a `class_name` in tools created `--import` hangs); every headless harness ends `_initialize` with `quit()`; GDScript 4.6 treats untyped Variant inference as an error.
7. **Determinism contract:** new RNG draws anywhere in the sim **perturb the seed stream** → all banked sweep baselines must be re-baselined after; this is routine but must be planned (it has invalidated baselines before).
8. **Project Kit directives** (since 2026-06-11): per-work-item doc updates + commit + push; `PROJECT KNOWLEDGE` files 01–05 current-state, 06–07 append-only.

## A2. Shops — ✅ implemented (two NPC shops, dynamic prices, saturation, town-consumption sink, leveling)

**Entities** (`Shop.gd`, instantiated in `Economy._init`, Economy.gd:35-49): exactly **two** canon vendors —

| Shop | Goods (stock / max / base value) |
|---|---|
| `general_store` "Varrock General Store" | ore 20/120/**16** · logs 20/120/**12** |
| `fishmonger` "Varrock Fishmonger" | raw_fish 10/80/**7** · cooked_fish 14/80/**9** |

These four "goods" are the live tradeable economy. (The `items.json` catalog is wider but not yet wired into shop trade — see A9.)

**Sell price (shop pays hero)** — Shop.gd:45-48, verbatim:
```gdscript
var r: float = stock[good] / maximum[good]
var f: float = maxf(Config.PRICE_FLOOR_FRAC, 1.2 - r * 1.4)
return maxi(1, int(round(base[good] * f)))
```
i.e. pays **120% of base when empty, falling linearly to a floor of 12% of base** (`PRICE_FLOOR_FRAC = 0.12`, a sweepable `static var`) as stock fills. Compare reference B1: "margin ~0.55–0.75 falling to a 0.15 floor" — same shape, our top is higher and floor slightly lower.

**Buy price (shop charges hero)** — Shop.gd:52-54, verbatim:
```gdscript
var r: float = stock[good] / maximum[good]
return int(round(charge_base * (1.4 - r * 0.7)))
```
Scarcity raises price (1.4× at empty → 0.7× at full). **Only food currently flows through this** (`FOOD_BUY_BASE = 22.0`, Economy.gd:25; `Economy.food_price()`). Tools (12g), starter weapons (30g), shields (35g), ammo bundles (60 for 12g) are **flat-priced burned sinks** handled in `SimWorld._work_action` chains, not Shop-priced. There is **❌ no player price-bias lever** (reference B1's 50–150% slider does not exist; the closest lever is the Tier-1 incentive, which biases *utility*, not price).

**Saturation refusal — ✅** `Shop.room_for()` (Shop.gd:56-57): sales are capacity-respecting — `Economy.sell_goods` only buys `mini(have, room_for)` whole units; a saturated shop buys zero. This is the validated anti-farming back-pressure (it is the mechanism behind the "shop mints at floor price forever" leak fix — the original Step-1 economy bug).

**Town consumption drain — ✅** (different mechanism than reference B1's ~8% chance): deterministic continuous drain, `Shop.consume_tick(dd, pop_scale)` — `stock -= consume × dd × pop_scale` per work-action. Rates (`Config.SHOP_CONSUME`, units/sim-day): **ore 350 · logs 350 · raw_fish 0 · cooked_fish 60** (cooked deliberately low — the real food sink is *fighters buying food*; 260 starved them, a banked tuning note). `pop_scale = heroes/6` (faucets and sinks grow together — §6.5 principle), and shop leveling scales `consume` and `maximum` by the same factor. Items are destroyed, no gold moves — same intent as the reference's townsfolk drain.

**Restock — ❌ none.** Shops have **no ambient/import restock**; stock comes *only* from hero sales and drains via consumption. (Reference B1's "restock toward baseline" and C5's imports would be a new mechanism — see fit assessment.)

**Shop investment — ✅** `Economy.shop_upgrade_cost` = `400 × 1.6^(level−1)` treasury gold (Config: `SHOP_UPGRADE_BASE_COST 400.0`, `SHOP_UPGRADE_COST_GROWTH 1.6`, `SHOP_LEVEL_CAP 99`). Each level: **+15% stock capacity AND +15% town demand** (`SHOP_CAP_PER_LEVEL 0.15`, `Shop.level_up`) — scaling both keeps the faucet/sink ratio invariant *by construction*, so leveling boosts throughput without a re-tune. **❌ no tier-up unlocks yet** (reference: "level ≥10 stocks adamant") — shops trade the same goods at every level; gear is not yet shop-traded (M3a slice-2 remainder).

**Gold accounting (faucet/sink ledger — differs from reference B1's 50/50 split, flagged):**
- Hero **sells** to shop: gross minted, minus `GE_TAX = 0.03` (3%) skimmed → `tax_collected` AND `treasury` (Economy.gd:64-72). So ~97% of every sale is **new gold** (faucet); 3% is removed from hero circulation and banked as the player's spendable treasury.
- Hero **buys** (food/tools/weapons/ammo): gold is **100% burned** (sink). Nothing routes to the treasury.
- Reference B1: purchases 50% treasury / 50% burn; payouts minted. Both remove the full purchase from hero circulation, so the *attractor* doesn't care — but the **treasury inflow model is structurally different** (ours: tax-on-sales only; theirs: tax + half of purchases). See fit assessment B1.
- The treasury is **outside** `total_gold()` (hero-held gold only), so treasury balance changes never show up as drift.
- Other faucets: monster coin drops (per-catalog ranges; rats use re-tuned `RAT_DROP_MIN 3` + `RAT_DROP_RANGE 5`), gear-drop salvage coins. Other sinks: wealth-proportional upkeep (the attractor: `(UPKEEP_FLAT 6.0 + UPKEEP_RATE 0.80 × hero.gold) × dd`, Economy.economy_tick), 10% gold transfer on death (now a *transfer* to the grave-looter, not a sink), building daily upkeep (treasury-side).

## A3. Grand Exchange / hero-to-hero trading — ❌ absent (hooks exist)

No order book, no offers, no hero↔hero trade of any kind. What exists, ready for it:
- A **"ge" location** on the canon map, rendered as a locked/greyed building ("locked until the GE unlocks", Main.gd:716) and a GE plaza ring drawn in terrain.
- `Social.trade_modifier(buyer, seller)` — relationship-tiered price multiplier (Ally ×0.90 / Friend ×0.95 / Rival ×1.05 / Nemesis ×1.10), **latent**, explicitly waiting for hero↔hero/GE trade (Social.gd:169-175).
- `Social.record_trade` (+3 relationship per trade, daily-capped) — latent, same.
- `REL_TRADE = 3.0` constant. The GDD designs the GE as post-MVP wave (d) of the M3 content roadmap ("bank/GE").

## A4. Slayer & incentives — ❌ Slayer absent (it is literally the NEXT queued punch-list item); incentive levers 🚧 partial

**Slayer: nothing implemented.** No slayer master NPC, no tasks, no slayer points, no per-monster colony kill counts (only the global `total_kills`). The catalog schema *is* ready: `Monster.slayer_level_req` (all 0 in current data), `is_boss` (Scurrius: cl 80, hp 500, coins 3000–8000), and a "slayer" skill would join `GATHER_SKILLS` trivially. **"Zones slice 2 — Slayer tasks + AGGRESSIVE monsters + Scurrius boss gate (kill-count unlock)" is the current top of the punch list** — Part B2 arrives at exactly the right moment.

**Feasibility math exists and is tested but is NOT yet wired into live fight selection:** `Combat.fight_is_winnable(my_dps, enemy_dps, enemy_hp, my_hp, food_heal_available, risk_margin)` (Combat.gd:50-55) — the statistical "am I winning?" check, unit-tested, currently unused live ("live engage check" is a banked deferred item). What gates fights today is the cruder **power gate** in `Brain._score_fight` (Brain.gd:96-97): `style_level + defence < monster.combat_level → no candidate`, plus a food/affordability check. The reference build's "provisioned feasibility check" (B2) is therefore *half-built here*: the math is done and tested, the wiring is the work.

**Monster pool:** 6 camps hardcoded in `SimWorld.CAMPS` (rat ×4 @sewers, chicken ×3 @farm, cow ×3 @meadow, dark_wizard ×3 @stone circle [weak ranged], barbarian ×3 @longhall [weak magic], goblin ×3 @forest). No knowledge-gating; everything is assignable-by-existence, gated only by the power gate.

**Player incentive levers — 🚧:**
- **Tier-1 Incentivize** (✅ wired, deliberately clamped): `world.set_incentive(intent, weight)` adds flat utility to that intent for every hero (`Brain._incentive`). `INCENTIVE_STEP = 12.0`, **clamped at `INCENTIVE_MAX = 24.0`** because a 16-seed sweep (`diag_incentive.gd`) mapped the dose-response: 24 pulls labor 15%→18% with gold stable (921 ± 48); at 30 variance blows up (1612 ± 929); **≥~36 the bounty floods the node, the shop saturates, heroes can't sell, and per-capita gold craters 870→~131**. UI: bounty buttons cycle off/+12/+24 in the Colony menu (Main.gd:1071-1076).
- **The funded per-unit bounty is the INTENDED Tier-1 design and is already banked as a deferred decision** (agent memory, ratified): pay per-kill/per-unit *from the treasury*, clearing through the market — no overproduction crater, treasury becomes load-bearing. **Reference B2's bounty spec ("0–100g per kill, paid from treasury, only if affordable, greed-weighted into fight scoring") is convergent with our own banked design.** Nothing is built yet.
- ❌ No bounty-per-monster, no price biases, no Incentives menu (incentives live as four buttons in the Colony tab).

## A5. Hero brain & commands

**Decision model — ✅ utility argmax over explicit term lists** (`Brain.gd`). At each trip boundary (`SimWorld._start_activity`) every feasible candidate is scored as a `{intent, loc, skill, res, score, terms}` dict where **score is exactly the sum of the named terms** — the decision instrument and the Thoughts UI read the same math (an enforced legibility invariant).

Candidates: 3 gather intents (`GATHER_ORE`/`GATHER_LOGS`/`PROVISION`), **one FIGHT candidate per camp**, `SMITH` (if ore ≥ 3), buy-chains (`BUY_TOOL`/`BUY_WEAPON`/`BUY_OFFHAND` — generated when the tool/weapon gate fails but gold suffices), and a guaranteed `REGROUP` fallback (the "never-empty-menu" invariant).

Gather terms (v1, Brain.gd:154-176, verbatim values): `base = 10.0 + level×0.5` · `favorite = +16 (FAVORITE_MULT 1.6 ×10) / +12 secondary` · `reward = sell_price × 0.25 × (0.6+greed)` (the price-saturating term) · `congestion = −count × CONGESTION_K 7.0` · `travel = −dist × 0.4` · `sticky = +6` (anti-thrash) · `incentive` (player bounty) · `goal = +14 (GOAL_BIAS)` if the active goal matches.

Fight terms (Brain.gd:103-123): `base = 14.0 + strength×0.4` (price-independent — the diagnosed §18 asymmetry) · favorite +16 · `reward = avg_coin_drop × 0.2 × (0.6+greed)` (added with multi-camp — partially closes the asymmetry) · congestion ×**0.5** discount (`COMBAT_CONGESTION_MULT`) · `risk = −(1−risk_trait) × (4 + max_hit×2)` · travel · `food_pen −6` if foodless · sticky · incentive · goal. Plus the **power gate** and food/afford gate (A4).

Decision cadence: trips complete (gather: 14 units or cargo ≥ 27; combat: `COMBAT_TRIP_KILLS = 6` kills, or food/flee/disengage exits) → re-decide. `BRAIN_WEIGHTED_TIES` and `COMBAT_TRIP_ROUNDS` exist as measured-and-rejected levers, default-off. **`BRAIN_V2`** (skillNeed-saturating bases — the §18 rebalance from the concept prototype) is built, A/B-able, **default-off after three 8-seed tests**: it needs *activity breadth* (it improved monotonically 59%→47%→15% combat-share as activities were added; decision point = re-test after zones/Slayer).

Goals (✅, `GOALS_ON = true`): heroes hold "train SKILL to N" goals, 50% favorite / 50% rotating, +14 utility, saga entry on completion.

**Command surface (the current nudge layout — the Part B4 baseline):**
- **Nudge (Tier 2)** — `world.nudge_hero(h, intent)`: clears the current trip, injects a one-off candidate with a dominating `+1000` term (`NUDGE_BONUS`) that wins exactly one decision, then is consumed; the hero resumes autonomy. **Contract matches Part B4/C1's requirement exactly.** Five flat, **unparameterized** buttons: Mine / Chop / Fish / Fight / Town (Main.gd:1034). ❌ No per-target/duration/loot parameters; ❌ no disabled-with-tooltip gating (buttons are always clickable; an infeasible nudge resolves through the brain's redirect logic, e.g. a tool-less Mine nudge becomes a BUY_TOOL trip).
- **Seize (Tier 3)** — brain suspended; direct `command_seized` (same five verbs), click-to-walk, WASD walking, RUN toggle with stamina bar, click-to-equip/unequip in the Gear tab. Release restores autonomy.
- **Incentivize (Tier 1)** — standing per-intent utility weights (A4).
- Dual-agency holds throughout: nudge/seize build the *same* activity dict the brain builds (`_intent_head` is shared, SimWorld.gd:346).

## A6. UI layer inventory (all in `render/Main.gd`; immediate-mode `_draw()` + rect hit-testing — there are NO Godot Control nodes)

- **Top HUD bar** (44 px, `_draw_topbar`): title "GIELINOR TYCOON" · `Day N HH:MM` clock · stat chips **Gold / Treasury / Pop n/cap / Rep** · speed buttons **|| / 1x / 2x / 4x / 8x** · **Center** · **Roster [R]** toggle · **Menu [M]** toggle. (Close to reference B3 already — see fit assessment.)
- **Roster side panel** (left, 196 px, `_draw_roster`) — **being kept**: scrollless card list (portrait dot, name, activity line, HP bar, SEIZED badge); click → selects + opens the hero popup; overflow shows "+N more…".
- **Menu side panel** ("TOWN LEDGER", 366 px overlay, dockable right/left, `_panel_rect`) — **being kept**: tabs **Colony** (colony stats; TOWN section = per-shop level + upgrade-cost buttons, three build buttons, bounty cycle buttons) and **Chronicle** (colored event log).
- **Hero popup** (bottom drawer, 240 px, independent of the menu, `_draw_hero_popup`): camera snaps to & follows the hero (zoom slider, floored at open-time zoom, ×4 cap, restored on close). Three columns: identity | sub-tabs **Stats / Thoughts / Gear / Social / Saga** | command column (Nudge row or Command row when seized, Seize/Release, RUN toggle + stamina, Call-kick-vote, FORCE-KICK when unlocked).
  - **Thoughts tab** is the legibility win: current thought + the top-4 scored candidates with the dominant term each (`> FIGHT 38.2 favorite +16`).
  - **Gear tab**: paper-doll equipped grid (10 slots) + canon 28-slot 7×4 inventory grid; seized-only click-to-(un)equip.
- **Keyboard:** Space pause · 1/2/4/8 speed · E export debug log · L LOD toggle · **F5/F9 save/load** · M/R panels · Tab cycles hero tabs · Home/Center.
- **Wiring:** every button pushes `{rect, kind, arg}` into `_ui_rects` during draw; `_unhandled_input` hit-tests and dispatches to SimWorld methods (`_dispatch_ui`). Adding new controls = adding a kind + a draw site; it's uniform and easy to extend, but **form-style widgets (dropdowns, sliders, multi-field popups — what C1 needs) do not exist** beyond the one hand-rolled zoom slider.
- **Fragile/mid-refactor notes:** dead routing helpers (`_route`, `_route_river`, `_seg_crosses_city`, `_GATES`) remain in SimWorld unused after the BFS pathfinder replaced them (cleanup candidate); `--shot` screenshot captures can inherit a stray-click popup state (cosmetic, capture-only); no UI scaling/theming system — everything is hand-positioned against viewport size.

## A7. Economy invariants & telemetry — ✅ strong

**Telemetry** (`Telemetry.gd`): snapshot every 30 work-actions (~42 sim-min): total gold, **gold-per-capita** (the population-robust signal), pop, reputation, ore price, food price/stock, activity histogram, kills/deaths/flees, avg combat. Export (`E` key / `headless_log.gd`) computes **steady-state per-capita drift** (middle-third vs last-third — warmup excluded) and auto-flags anomalies: `GOLD INFLATING` (> +25%), `GOLD STARVING` (< −25%), broke-and-foodless fighters.

**Test gates protecting the economy:** the suite's equilibrium regression (drift |%| < 60, gold ∈ (800, 40000) at day 12 / 6 heroes — test_sim.gd:124-126); the offline gate (return batch must be absorbed by the attractor — `gain(30h) == gain(24h)` exactly, post-reconnect re-convergence ≤ 25% vs control); the determinism gate; plus per-feature multi-seed sweeps.

**Quantitative snapshot (current validated state — use these to scale any price/limit proposals):**
- **Per-capita hero gold band: ~1,065–1,211** at day 12 (the post-pathfinder re-centered band; the older "600–900" band is stale — the world genuinely became more productive when exact BFS pathing removed wasted walking, and `UPKEEP_RATE` was doubled 0.40→0.80 to re-center). Most recent slices ran bands 926–1,058 (+3%) and 682–1,249 (+2%) as camp economics diversified.
- Day-12 total gold (6 founders → ~40 pop via immigration): ~6,300–8,900 depending on slice; **drift +2% to +6%** lately (tightest ever: +4% after the upkeep re-center).
- Treasury: tax-fed only; a deliberately heavy shop-leveling stress run reached ~13.9k–55k treasury spend across slices (the "heavy-shop ceiling" watch number).
- Founders start with 20g; newcomer tiers start 20/45/130/320g (Greenhorn/Seasoned/Veteran/Elite).
- Scale: at pop 50, drift 0%, gpc 586±16 (older band; pre-pathfinder); perf ~305 ms/1k ticks.
- Attractor math (for modeling): live gold follows `g' = rate − (UPKEEP_FLAT + UPKEEP_RATE·g)` per sim-day; equilibrium `g* = (rate − 6.0)/0.80`. The offline projection applies the closed form `g(T) = g* + (g0 − g*)e^(−kT)` — **any new income stream you add changes g\* linearly; the attractor absorbs it but the band moves.** That is why every faucet ships gated.

**Anti-hoarding:** heroes currently *cannot* hoard — no bank exists, inventories are 28 canon slots, and the trip FSM sells everything not reserved (food/ammo) every cycle. Hoarding becomes possible only when banks + a carried-gear economy land (roadmap wave (d)/(e)) — which is exactly where C2's anti-hoarding rationale will start to matter.

## A8. Buildings, treasury & storage plumbing

- **Treasury** (`Economy.treasury`): fed **only** by the 3% sale tax; spent on shop upgrades (A2) and buildings; building upkeep debits it daily and **may drive it negative** (a deficit blocks new builds — SimWorld._town_daily comment). It is the player's pool, outside hero circulation and outside `total_gold()`.
- **Buildings** (`Config.BUILDINGS`, SimWorld.build): catalog of three — lodge (600g, upkeep 8/day, rep +4, sat +6), monument (900g, 5, rep +14, sat +2), tavern (500g, 7, rep +3, sat +5). One-time cost + daily upkeep + reputation/satisfaction bonuses. **Gold-only costs; no item costs anywhere** (C3 is greenfield).
- **Crafting — 🚧 one recipe:** SMITH activity at the anvil: **3 ore → 1 Iron sword + 40 smithing XP**, hardcoded in `SimWorld._work_action` ("smith" chain) and gated in the brain by ore ≥ 3 plus a **glut term** `+2.5 × max(0, 6 − ore_price)` — smithing turns on exactly when the ore market floors (the over-supply release valve; the bug-class counter-force built in). Cooking (raw→cooked fish) is the other transform. **No recipe data shape exists** — recipes-as-data is the M3a slice-2 remainder ("crafting recipes + ContentDB catalog migration"), queued.
- **Hero storage:** canon 28-slot inventory (1 slot/unit; `STACKABLES = [Arrows, Runes, Fishing bait]` stack in one slot; `CONSUMABLES` partition [cooked_fish, Arrows, Runes] is *reserved* — excluded from the gather-room check, the Stage-1 "starved menu" fix). 10 equipment slots (head/cape/neck/main/torso/off/gloves/legs/boots/ring), one item per slot, equip moves item out of inventory. **❌ No bank** — the bank building is decorative on the map; "banking" today = selling at the shop.

## A9. Content catalogs

**Items** (`data/items.json`): **11 entries**, base values **1–112** (iron_ore 17, logs 12, raw_trout 7, trout 9, bronze pickaxe/axe 1, bronze_sword 26, iron_scimitar 112, leather_body 21, cowhide 8, bones 1). Schema per `ItemType.gd`: id/name/slot/levelReqs/baseStats(per-style bonuses)/baseValue/stackable/**acquisition** (`{type: Gathered|Craftable|DropOnly|Hybrid, craftSkill, craftLevel, recipe[]}` — note trout already carries `recipe: ["raw_trout"]`, so a recipe field exists in the schema)/isFood/heals/iconId. **❌ No tradeable/untradeable flag** (everything implicitly tradeable). ⚠️ **Catalog vs live economy disconnect:** the live shops trade 4 goods with base values hardcoded in `Economy._init` (ore **16** vs catalog iron_ore **17**, etc.), and gear lives in `Config.GEAR_DROPS/GEAR_TIER` tables (7 items, values 16–90), not the catalog. Unifying onto ContentDB is the queued "catalog migration". The osrsreboxed ingest tool (~23k items) exists and writes the same schema; it has not been run into the live game.
- **Value scale for translation:** our base values are *canon OSRS-ish low-level values* (logs 12, ore 16–17, food 9). Reference-build prices should be translated as **ratios to base_value**, which transfers cleanly.

**Monsters** (`data/monsters.json`): **10 entries** — chicken (cl1), rat (cl1, hp15), giant_rat (cl3), cow (cl2), goblin (cl5, aggressive), dark_wizard (cl7, weak ranged, aggressive), zombie (cl13), barbarian (cl10, weak magic), guard (cl21), **Scurrius (cl80, hp500, boss, coins 3000–8000)**. Schema: combatLevel/hitpoints/attackStyles/maxHit/weaknessStyle/attackSpeed/aggressive/undeadFlag/**slayerLevelReq** (all 0 currently)/region/**isBoss**/coinDropRange/**dropTable** `[{itemTypeId, rate}]`. Drop tables exist in data (bones, cowhide) but **live combat only rolls coin ranges + the Config gear-drop table**; itemized drops are unwired. `aggressive` is also unwired (no monster-initiated combat yet — it's in the NEXT punch item).

## A10. Punch list — in full, verbatim, with status

**Honest framing:** the repo had no punch-list *file* until today (Part E seeding). The live queue has been maintained in the build agent's memory ledger (copied to `STATUS_DOCS/AGENT_MEMORY_project-status.md`) as a NEXT pointer + the merge-plan roadmap + a deferred-decisions list. Quoted verbatim from that ledger:

> **NEXT: zones slice 2 — Slayer tasks + AGGRESSIVE monsters (deaths→gravestone negatives live) + v2 4th test + Scurrius boss gate (kill-count unlock).**

> **Order: M1 visual/UX → M2 brain v2 (multi-seed gates, carries the banked monoculture/rival-lean prediction) → M3+ content waves.** [M1 ✅ complete; M2 measured → BRAIN_V2 default-off, 4th test queued after activity breadth widens]

> Then M3 content waves: **(a) items/gear/recipes, (b) combat triangle+monsters, (c) zones+Slayer, (d) bank/GE, (e) death/graves/PK→canon social negatives, (f) buildings/reincarnation, (g) Zezima. ~8-10 majors to GDD-complete.**

> **Deferred (planner calls):** funded per-unit bounty (intended Tier-1); Stage-2 combat polish (premise undercut, optional); INCENTIVE_STEP finer notches; "am I winning?" live engage; offline-yield saturation ceiling [since done in Step 6].

Status against the waves: (a) 🚧 (gear drops/equipment/smithing done; recipes-as-data + ContentDB migration + shops-trade-gear remain), (b) 🚧 (triangle plumbing live, weaknesses in catalog; more monsters with the zones), (c) 🚧 (6 camps live = slice 1; **slice 2 = Slayer = the active item**), (d) 📋, (e) 📋, (f) 🚧 (buildings exist; reincarnation 📋), (g) 📋.

**Reasoning behind the ordering** (mine, as the agent driving it): each wave activates the next wave's prerequisites — zones/Slayer widen *activity breadth* (which the measured BRAIN_V2 verdict explicitly waits on), aggressive monsters produce real deaths (which activates the dormant gravestone/social-negative machinery and lets the interim competition-friction be retired), the catalog migration must precede any system that prices many items (GE, item-cost upgrades, crafting), and bank/GE precede death/PK item-looting because lost gear needs somewhere to have been kept. The sequencing constraint that bites hardest: **economy faucets must land one at a time** so the band re-centering (a routine, gate-protected operation) stays attributable.

**What I am actively doing right now:** nothing was mid-flight this session — the previous session closed with the seize-control/collision/economy-re-center cluster green (101/101) and "zones slice 2" queued as next. This probe is therefore landing at a clean boundary.

## A11. Known issues in the probed systems

1. **No git history** (A0) — process risk, not code risk. Biggest single fragility.
2. **Save-version migrations absent** — `SAVE_VERSION` mismatch silently refuses the save (returns null → fresh world). Within version 1, new hero fields use `.get(default)` fallbacks, which has worked, but Part-C features add whole new top-level structures; repeated saves-breaking is guaranteed without a migration scaffold.
3. **§18 combat-utility asymmetry** — diagnosed, *substantially mitigated* by accumulated fixes (combat-share 32%→~8–20% across re-baselines), formally "leading-but-unconfirmed". `BRAIN_V2` is the designed fix, default-off pending activity breadth. Any new income stream for combat (bounties!) interacts with this — the incentive sweep's overproduction cliff is the guardrail.
4. **Social web is rival-leaning** (rivals ~10–13% vs friends ~8–9% — actually near-balanced after the tool/goal units; nemeses ~0). Banked as KNOWN/DIAGNOSED/DEFERRED; the canon negative sources (PvP/death) arrive with wave (e) and the interim competition-friction then retires.
5. **Ammo economy is feel-tuned, not validated-fun**: dry-punch fallback fixed the capital lockout (instance #7), kills 812 with ammo on vs 2634 free — "further balance = playtest feel" is an open note.
6. **Dead code**: the pre-BFS routing heuristics in SimWorld (`_route*`, `_GATES`) are unused — cleanup candidate (deliberately not touched in this read-only probe).
7. **Stale docs**: `PROJECT_STATUS.md` (in the snapshot dirs) and the two `gielinor-tycoon-(*)` snapshot dirs themselves; superseded but still present and confusable with the live build.
8. **Watch numbers**: the heavy-shop stress ceiling (treasury throughput) has been squeezed by three consecutive faucet additions and re-relieved; re-check after each economy-touching change. The post-collision equilibrium is travel-bound (kills 5× below pre-collision peak) — flagged "watch next session".
9. **`--shot` capture quirk** (cosmetic, capture-only).
10. **Economy.GOODS base values vs items.json mismatch** (ore 16 vs 17) — harmless today, must be resolved by the catalog migration, **before** C2/C3 price anything against `base_value`.

## A12. Anything else a designer should know

- **Naming/NPC mapping:** there is no Vannaka, no Horvik, no Lowe, no Aubury in the build — Varrock's canon NPCs are *designed* in `WORLD_AND_CHARACTERS.md` but the live shop roster is just General Store + Fishmonger. "City" = Varrock; "city treasury" = `Economy.treasury`; the current "GE_TAX" is a **misnomer** — it taxes NPC-shop sales (there is no GE); when a real GE lands, naming and rates need reconciling (see Q8).
- **Determinism tax on every Part-C feature:** anything that adds RNG draws or changes draw order perturbs the seed stream → banked sweep baselines must be re-run. Routine, but it means features should land in *gated units*, not one mega-merge.
- **Dual-resolvability is a real gate, not a slogan:** offline catch-up reads `hero.act.intent` and projects per-activity expected yields under live bounds (market ceiling per good, shared pit throughput, the attractor closed-form — SimWorld.offline_catchup, SimWorld.gd:1294-1347). Every new activity (GE trading, selling to city orders, crafting) must define what a hero "doing it" yields offline, or define itself as a town-side (non-hero) process that ticks statistically anyway.
- **The Chronicle/notability system** (§17 curation) should receive events from any new system (orders filled, crafts completed, tasks assigned) at the right notability — there's an established pattern (`log_event(text, cls, notability)`, 0 = telemetry-only).
- **UI conventions:** new menus should be new tabs/sections in the existing TOWN LEDGER overlay or new bottom-drawer popups, not new window systems. The immediate-mode toolkit has buttons and one slider; forms (C1) need either toolkit extension or first Control-node usage (Q11).

---

# PART B — FIT ASSESSMENT (reference-build mechanics)

Standard applied: *fits the game as it stands*, integrates around the locked attractor, ships gated per the verification discipline.

## B1. Shop system — **adapt** (we have a validated sibling of most of it; adopt the missing levers, reconcile accounting)

| Reference mechanic | Verdict | Detail |
|---|---|---|
| Dynamic buy price `base × clamp(1+0.6(1−stock/max), 0.4, 1.3) × bias` | **Adapt** | We have `charge_base × (1.4 − 0.7·fill)` — same shape, only wired for food. When shops trade many goods (post catalog-migration), generalize our curve per-good. Re-deriving to their exact constants is unnecessary; ours is the validated one. |
| **Player price-bias slider (50–150%)** | **Adopt, gated** | Genuinely new lever; fits Tier-1 ("bounties/prices raise relevant utilities" is literally GDD §18.4). Implementation: per-good `price_bias` on Shop, serialized, UI slider in the shop section. **Must sweep**: a 150% sell-side bias is a faucet multiplier — the incentive sweep showed exactly where standing amplifiers crater (≥~1.5× equivalent). Expect a clamp narrower than 50–150% on the *pay-hero* side; the *charge-hero* side is a sink and is safer. |
| Sell margin 0.55–0.75 → 0.15 floor | **Keep ours** | `1.2−1.4·fill, floor 0.12` is the validated equilibrium curve. Same design intent (anti-dumping diminishing returns). Flag: ours pays *more* than base when stock is low — that's load-bearing (it pulls labor toward scarce goods). |
| Saturation refusal | **Already have** | `room_for` capacity-respecting sales — validated as our anti-farming loop (their fur-hunter story is our ore-miner story). |
| Townsfolk consumption drain (~8% + 0.2%/lvl chance) | **Keep ours** | Deterministic `consume × dd × pop_scale` is strictly better for determinism and is already population- and shop-level-scaled. Same item-sink semantics (no gold moves). |
| Restock toward baseline | **Adopt — merged with C5 imports** | We have NO ambient restock; stock starves when heroes stop supplying. A slow trickle toward baseline is the missing counter-process and is C5's "imports" — implement once, in `consume_tick`'s mirror image. New item faucet → gate (it interacts with saturation refusal: imports must respect `maximum` and ideally stop at baseline, not cap). |
| Shop investment `150 × 1.18^level`, tier-up unlocks | **Have cost ladder; adopt unlocks** | Ours: `400 × 1.6^(L−1)`, cap 99, +15% cap&demand/level — validated-bounded by construction. Their growth (1.18) is shallower; ours is deliberately steep early (treasury is small). Re-deriving toward a shallower curve is a pacing question for the planner, not a stability one. **Tier-up unlocks (level ≥10 stocks better gear) — adopt enthusiastically**: it's the visible payoff our leveling lacks, and it needs the catalog migration first. |
| Gold accounting: purchases 50% treasury / 50% burn; payouts minted | **Conflict — flagged, with a safe adaptation** | Ours burns 100% of purchases and feeds the treasury from a 3% sales tax instead. Both schemes remove the full purchase from hero circulation, so **the attractor is indifferent** — but switching changes treasury *pacing* enormously (purchases ≫ 3% of sales). If the design partner wants the EHT-style "buying funds the town" feel: route X% of purchase gold to treasury and burn (100−X)% — `total_gold()` and drift are untouched *by construction* (treasury is outside circulation), so this is safe to tune. But treasury inflow interacts with C2 (treasury *outflow* to buy orders) — decide the two together (see Q1/Q2). |

## B2. Slayer & incentive system — **adopt-adapt; it merges INTO the currently-queued punch item**

This lands at the perfect moment: "zones slice 2 — Slayer tasks" is the active queue head. Verdicts per sub-mechanic:

- **Task assignment with the two gates — adopt.** Gate (1) slayer-level ≤ hero's slayer level: trivial (add "slayer" skill; `slayerLevelReq` already in schema). Gate (2) **provisioned feasibility (DPS-vs-DPS survival with banked-food loadout)**: `Combat.fight_is_winnable` is implemented and unit-tested — wiring it into assignment is exactly the "live engage check" already on our deferred list. Their 688→35 deaths validation story is strong evidence for a check we already believed in. Adapt: "banked-food loadout" → we have no banks; use *affordable* food (gold ÷ food_price, capped at the FOOD_BUY_QTY pattern) until banks land. Prayer-aware: we have no prayer yet — the `prayer_mult` parameter already exists in `Combat.effective_level`, defaulting 1.0; honest to note it's inert.
- **Task sizing inversely with toughness (boss 3–8 / HP≥80 8–20 / HP≥40 14–35 / small 20–60) — adopt as-is.** Pure data; our HP scale is comparable (rat 15 → Scurrius 500). Sizes also matter for *trip cadence*: a 20–60-rat task spans many 6-kill trips — the task is a standing goal layered over trips, which our goal system already models (a task is structurally a goal with a kill counter).
- **On-task utility bonus (+26 in their scale) + bonus slayer XP (~0.9×HP) + 8–16 points — adapt with re-derived magnitude.** Our term scale: bases 8–30, favorite +16, goal +14, incentive cap +24 (with a measured overproduction cliff at ~+36 *standing on one node*). An on-task bonus is per-hero and task-rotated (not colony-wide standing), so it's safer than a bounty at equal magnitude, but I'd open at **+18–22, swept** before locking. Slayer points: new currency, fine (player-facing spending of points = later design; reference uses them for unlocks).
- **Knowledge-gated pool (colony kills 100 / boss 15 to unlock) — adopt; needs per-monster kill counts** (new `Dictionary` on SimWorld, serialized — trivial). This also gives the **Scurrius boss gate (kill-count unlock)** already named in our queue a general mechanism. Player curation (enable/disable unlocked monsters) → an Incentives/Slayer section in the TOWN LEDGER.
- **Partnering (≤2 Friend+ heroes who pass feasibility join, shared counter, mutual rel points) — adopt, slightly later.** The social graph and Friend tier (≥+20) are live; `record_trade`-style mutual bumps exist as a pattern. The work is in the trip FSM (two heroes sharing a task target). I'd sequence it as a fast-follow to solo tasks, not in the first slice — it touches the FSM and the offline projection (shared kill attribution) at once.
- **Bounties (0–100g/kill from treasury, affordability-gated, greed-weighted) — adopt: this IS our banked "funded per-unit bounty" design.** Convergent evolution; the reference validates it. Re-derive the range to our scale: rat coin drops are 3–8g, so a 0–100g bounty is enormous here — translate as *0–3× the monster's average coin drop*, clamped, treasury-affordability-checked per kill (their rule). It enters fight scoring through the existing `reward` term (greed-weighted already). **This retires the clamped utility bounty for FIGHT** (keep utility incentives for gather intents, or migrate those to price-bias — Q5). Drift note: bounty gold is treasury→hero = **re-injection of previously-taxed gold** — see the C2 settlement analysis; same ledger, decide together.

## B3. Top HUD layout — **mostly already true; adopt the deltas (render-only)**

Have: title · Day N HH:MM · speed buttons (we have 5 incl. 2×; reference has ⏸/1/3/8 — keep ours) · Treasury/Pop-with-cap/Rep counters · Roster/Menu toggles. Deltas to adopt: a subtitle; surface **Save/Load** and **Export-log** as topbar buttons (currently F5/F9/E keys only — discoverability win); Build/Incentives shortcuts can deep-link to the TOWN LEDGER sections rather than becoming new menus (prompt's own rule: fit into existing conventions). "Zezima-slain count" — 📋 until Zezima exists. Total: small, render-only, zero sim risk. The current **Gold** chip (total hero gold) is a debug-ish stat; consider replacing with reference's hero-count emphasis once Treasury/Rep stay.

## B4. Current nudge layout — **the contract matches; adopt the gating polish with C1**

Our nudge is exactly their "one-shot override, brain resumes" contract (`NUDGE_BONUS` consumed after one decision). Missing vs reference: per-button **disabled-with-tooltip** when infeasible (we currently let the brain's redirect logic absorb infeasible nudges — functional but illegible), "Get Slayer task" (arrives with B2), "Rest" (no rest/energy-sleep mechanic; run-energy exists — a Rest verb could regen it, minor), gated endgame attempts (📋 post-MVP). Recommend: implement feasibility-tooltips as part of the C1 popup work (same feasibility predicates feed both).

---

# PART C — FIT ASSESSMENT (new features)

**Dual-agency / dual-resolvability compliance is assessed per feature, as required.**

## C1. Parameterized nudge popups — **adopt-adapt; cleanest of the four; UI is the real work**

- **Fits the brain/FSM cleanly.** A nudge already injects a candidate head `{intent, loc, skill, res}`; parameterization extends this dict: `{intent: FIGHT, camp/monster: id|null(random), kill_range: [min,max] or duration_range, loot_policy}` and `{intent: GATHER_*, loc: site|null, qty_range, suggested_items[]}`. The trip FSM reads the rolled commitment instead of the constants (`COMBAT_TRIP_KILLS = 6` generalizes to a per-trip rolled value; gather's `>= 14` likewise). **Hero rolls within the range using the seeded RNG — preserves agency AND determinism** (one extra draw → stream perturbation → re-baseline; routine).
- **Suggestions-as-influence** maps directly onto the term system: a suggested-items list adds a bounded `suggestion +k` term to matching gather targets — literally how incentives/goals already work. The hero can still out-score it. This is the most natural translation in the whole prompt.
- **Loot settings:** ⚠️ translation needed — we have no ground loot. Drops auto-resolve (coins; gear auto-equip-if-better, else carried-if-space, else salvage). Honest reading: loot_policy = a **drop-filter** (keep-everything / keep-upgrades-and-valuables / salvage-all) governing the carried-vs-salvage branch in `_gear_drop`. If the design intent requires literal ground items, that's a new system (gravestone/vulture logic §14 wants it eventually) — Q7.
- **Dual-agency:** the autonomous brain already chooses camps and (with goals) skills; rolled trip-lengths become shared machinery — autonomous trips can roll from default ranges, so the player's popup sets the *range*, the same roll the hero uses alone. ✅
- **Dual-resolvability:** parameters modulate live trips; offline projection reads `act.intent` and is unaffected by trip-length parameters (they don't change steady-state rates materially). Loot-filter affects offline gear-drop yields → fold the filter into the rare-drop projection when itemized offline drops exist (today: none). ✅
- **UI:** this is the feature that exceeds the immediate-mode toolkit (dropdowns, dual-handle ranges, item pickers). Recommendation in Q11.
- **Risks:** low. No economy coupling beyond what nudges already do. Sequencing: monster dropdown wants the Slayer/unlock state (B2) for its roster, so C1-Fight lands after B2; C1-Skill could land anytime.

## C2. OSRS-style GE order book + City BUY orders — **adopt-adapt; the architecture fits; the gold-ledger interaction is THE thing to design carefully**

- **Architecture: clean fit.** A sim-core `OrderBook` (RefCounted) with deterministic price-time-priority matching (buyer pays their posted price or better, partial fills, expiry+refund — OSRS semantics), serialized in the save, GE location already on the map, `trade_modifier`/`record_trade` social hooks waiting. Matching cost is trivial at ≤50 heroes + city orders (A0 perf envelope). Determinism: matching iterates in insertion/price order — naturally deterministic; expiry uses sim-time. ✅
- **City as buyer ONLY, posting standing BUY orders from player-set per-item limits, settled treasury→hero into a City Inventory — adopt.** This is also the general form of our banked funded-bounty thinking applied to goods: *the player pays real treasury gold to steer labor, clearing through a market* — the design our incentive sweep concluded was the right one. The affordability gate (only fills while treasury covers it) mirrors B2's bounty rule.
- **⚠️ THE flag — treasury re-injection vs the attractor.** "City buys are circulation, not minting; drift-neutral" is true in the reference's ledger but **not quite in ours**: our treasury is funded by the 3% tax, i.e. gold *already removed* from hero circulation; the validated equilibrium implicitly treats it as sunk. Paying it back out to heroes is a **new faucet into hero circulation** (bounded by tax inflow + player intent, but real). The attractor absorbs bounded faucets (g* shifts up; upkeep is proportional), so this is *safe by construction* but **not drift-neutral**: expect the per-capita band to move with city-buy volume and plan the standard re-center. If B1's 50/50 purchase-routing is also adopted, treasury inflow grows too and the loop (heroes buy → treasury → city buys → heroes) becomes a genuine circulation loop — that's the EHT design, and it's fine, but it must be swept as ONE ledger change, not two independent ones. **Recommendation: adopt, model g* before/after, single gated unit.** (Q1/Q2)
- **GE tax:** keep a tax as the sink on hero↔hero and hero↔city trades — reference's 1% vs our 3% shop tax: see Q8. With C4 making shops the *bad* price, trade volume migrates GE-ward; the GE tax partially replaces shrinking shop-tax treasury inflow. The whole tax architecture should be set in one decision.
- **Dual-agency:** heroes post buy AND sell offers autonomously (greed/needs-driven: fighters post buy-food orders when shop price > GE price; gatherers post sells at reference price vs dumping at shop) — the same order objects the player's city orders are. ✅ The brain needs a "post/check GE" errand in trip chains (a `then: "ge"` stop like `"sell"` is today).
- **Dual-resolvability:** offline, the order book must not tick order-by-order. Statistical path: standing city/hero orders fill at expected rates = `min(remaining limit, expected production surplus of that good over the window)` at posted prices, with the same attractor projection bounding gold. Unfilled-order expiry resolves on return. This needs explicit design but has a clear shape. ✅ (must be in the unit's gate)
- **Anti-hoarding rationale:** today heroes can't hoard (no bank). C2 *prevents* the hoarding problem from ever forming once banks land — sequencing argument for keeping C2 adjacent to the bank in wave (d), exactly where the roadmap already put "bank/GE". ✅

## C3. City Inventory + item-cost upgrades — **adopt; hard dependency on the catalog migration**

- **City Inventory:** a serialized `Dictionary` (good → qty) on the economy; filled by C2 city purchases (and, future: confiscations, tribute — proposals for later). Plumbing is trivial; the design weight is all in what consumes it. UI: a section in TOWN LEDGER → Colony.
- **Item-cost upgrades:** evolve `shop_upgrade_cost`/`Config.BUILDINGS` costs from `int gold` to `{gold, items: {id: qty}}`. Affordability checks read City Inventory; spend consumes it (an item *sink* — good: city stock needs an outlet or it's a one-way accumulator; bug-class rule satisfied by construction *only if* upgrades are the planned consumer at every tier).
- **Coherent cost ladder (proposal sketch, to be designed properly post-ruling):** General Store wants logs/planks (shelving); Fishmonger wants logs (smoking racks) + raw fish (stock); future Smithy (Horvik) wants ore/bars; future Archery (Lowe) wants logs/feathers; town buildings want logs/ore/bars by tier. Principle: **each building consumes the goods its function processes**, quantities scaled so a tier costs ~N days of realistic city-buy throughput at current production (computable from `SHOP_CONSUME`-scale numbers; e.g. tier-2 ≈ 50–150 logs when colony log production is ~350/day-equivalent).
- **Dependency:** meaningful item variety (bars, feathers, planks…) doesn't exist in the live 4-good economy — **the ContentDB catalog migration (queued M3a remainder) must land first**, or the ladder is logs-and-ore-only. Dual-agency/resolvability: city inventory is town-side state, not a hero activity — no live/statistical split needed beyond C2's settlement; upgrades are player actions (existing pattern). ✅

## C4. Shop sell-back rules — **adopt the intent; reconcile the two pricing models explicitly (proposal below)**

- **Intent (shops = convenient-but-bad; GE/city orders win on price)** — fully compatible with our direction; today shops are the *only* buyer, so "bad price" can't exist yet. Once C2 exists:
- **The reconciliation (the prompt asks for the merge proposal):** keep our saturation curve as the *shape*, add a GE-anchored *ceiling*: `shop_pays = min(saturation_curve(stock) × base, 0.30 × GE_reference_price)` where GE_reference = recent average traded price (fallback: base_value). Saturation refusal stays (a full shop still refuses). Net effect: when the GE is healthy, shops pay ≈30% of it (the "~70% below" rule); when the GE is empty/illiquid, shops degrade gracefully to today's validated behavior instead of becoming a free-money arb. **This preserves the current economy as the floor-case — important because…**
- **⚠️ The deepest economy question in this prompt:** today, **NPC shop purchases of hero goods are the gather economy's ONLY mint**. C4 cuts that mint ~70% while C2 shifts volume to city orders, which pay from a treasury fed by taxes (and possibly B1 purchase-routing). If the player posts no buy orders, gatherer income collapses to the 30%-shop trickle. Is that intended pressure (the player MUST run procurement — very EHT) or does a baseline NPC demand persist? This decides whether C4 ships before, with, or after C2 — and is Q2. My engineering recommendation: ship C4's specialty-shop rules and the 0.30 ceiling **together with** C2 in one gated unit, never C4 alone.
- **Specialty shops accept only what they carry; sold items restock that shop (not city inventory); General Store accepts anything** — adopt as-is; `Shop.trades()` and per-shop stock already model this; "General Store accepts anything" needs the catalog migration (selling arbitrary gear into Gen-Store stock for resale = also the natural home of the current vendor-gear half-value path).
- Dual-agency ✅ (heroes choose shop-vs-GE by price, the same comparison the player sees). Dual-resolvability ✅ (offline gather yields price at the blended expected venue — needs the C2 statistical fill model).

## C5. Shop crafting + slow imports — **adopt-adapt; smithing slice-1 is the proven template; queueing rules proposed**

- **Imports (1–3 units / 3 in-game days ≈ 0.3–1.0 units/day per item):** adopt; tiny deterministic drip toward each shop's baseline (not max), implemented beside `consume_tick`. At our scale (`SHOP_CONSUME` ore = 350/day) this is correctly negligible-but-nonzero — it un-deadlocks stock without competing with heroes. Item faucet, no gold movement → gate trivially.
- **Shop crafting from City Inventory:** fits as the town-side production counterpart of hero smithing (which shipped glut-gated and bounded — the template). Recipes-as-data is *already* the queued catalog-migration work (`acquisition.recipe[]` exists in the item schema — trout already uses it). Crafted goods → that shop's stock for heroes to buy (a hero gold-sink at the buy step: healthy). **This makes City Inventory's consumer story complete: upgrades (C3) + crafting (C5) drain what city buying (C2) accumulates — a closed loop with player-controlled valves at each step.** Bug-class review passes: every flow has a counter-flow.
- **Queueing (proposal, per the prompt's ask):** per-shop FIFO queues; the player may queue with missing materials; a queued order **reserves nothing until it starts** (reservation-on-start, not on-queue — simplest, no phantom-reservation deadlocks across shops); when the head order's materials are present in City Inventory, consume them atomically and start a craft timer (sim-days scaled by shop level); cross-shop contention resolves by deterministic shop iteration order (and is rare — different shops want different goods). Cancel = refund nothing if started, nothing was taken if not. UI: a craft section in each shop's TOWN LEDGER block with the queue listed.
- Dual-agency: crafting here is a *facility/player* verb (like building), not a hero verb — the invariant binds hero verbs; heroes participate as suppliers (C2) and buyers of the output. If the planner wants hero-side crafting breadth too, that's the existing recipes roadmap (hero smithing generalizes). ✅ Dual-resolvability: craft timers are sim-time-based → trivially resolvable offline (complete what the elapsed window covers). ✅

---

# PUNCH-LIST INTEGRATION PROPOSAL

(Sequencing is mine per the prompt's division of labor; nothing here preempts the in-flight item. Each unit ships gated: 101-suite + relevant gates + multi-seed sweep + band report.)

**Unit 0 (active, unchanged): Zones slice 2 — Slayer + aggressive monsters + Scurrius gate — ABSORBS B2.**
The queued item and B2 are the same work. Scope: slayer skill + per-monster colony kill counts (knowledge gating, generalizing the planned Scurrius unlock) + slayer-master NPC + task assignment with the two gates (wiring `fight_is_winnable` = the deferred "live engage" item) + task sizing + on-task utility/XP (swept magnitude) + aggressive monsters (activates deaths → gravestone negatives). The **funded per-kill bounty** (B2's bounty = our banked intended design) lands here or as Unit 0.5 — it's the treasury's first outflow-to-heroes and previews the C2 settlement ledger at small scale. *Prereq: none. Save schema touched (Q10).*

**Unit 1: Catalog migration (already queued as M3a remainder) — PREREQUISITE promoted.**
ContentDB-driven goods/prices replacing `Economy.GOODS` hardcodes + `Config.GEAR_DROPS` tables; recipes-as-data; tradeable flags (A9 gap). Everything in B1/C2–C5 prices against `base_value` — this must come first and is already on the list; the new features raise its priority.

**Unit 2: Shop economy v2 — B1 deltas + C5 imports.**
Per-good dynamic buy pricing; price-bias lever (swept clamp); ambient imports/restock-to-baseline; tier-up stock unlocks (needs Unit 1); optional purchase-gold routing to treasury (Q1, decide with Unit 4's ledger); + the **Varrock shop-roster expansion** if greenlit (Q3) — specialty shops are prerequisites for C4's specialty rules and C5's crafting menus.

**Unit 3: C1 parameterized nudges (+ B4 tooltip gating).**
Skill popup can land any time after Unit 0; Fight popup wants Unit 0's roster/unlock state. UI-tech decision Q11 first. Independent of Units 1–2 — can interleave as a UI-flavored breather between economy units.

**Unit 4: Bank + GE order book + City BUY orders + City Inventory (C2 + C3-inventory) — the existing roadmap wave (d), enlarged.**
Bank (hero storage; makes hoarding possible the same moment its antidote arrives), order book + matching + expiry, hero autonomous order behavior, city standing buys → City Inventory, settlement + tax decision (Q8), offline statistical fill model, **the full gold-ledger sweep** (this unit moves g* — plan the re-center). Biggest unit; the report's central economy questions (Q1/Q2) gate its design.

**Unit 5: C4 sell-back reconciliation + C3 item-cost upgrades + C5 shop crafting queues.**
All three consume Unit 4's outputs (GE reference price; City Inventory). C4 must not ship before Unit 4 (it would cut the only mint). Cost ladders and craft recipes need Unit 1.

**Unchanged downstream:** wave (e) death/graves/PK (retires interim friction), (f) reincarnation, (g) Zezima. B3 topbar deltas: anytime, render-only. BRAIN_V2 4th test: after Unit 0 (activity breadth widens — as already planned).

**Dependency summary:** 0 → (1 → 2 → 4 → 5), 3 floats, B3 floats. Units 0–2 are individually small-to-medium; 4 is large; 5 is medium.

---

# QUESTIONS (design rulings requested before estimation)

1. **Treasury ledger & re-injection.** City buy orders (C2) and funded bounties (B2) pay treasury gold *back into hero circulation*; our treasury is currently tax-fed (sunk gold), so this is a new bounded faucet, not a neutral transfer (analysis in C2). Acceptable as a player-throttled faucet absorbed by the attractor (my recommendation), or do you want an additional hard cap (e.g. max treasury outflow/day)? Relatedly: adopt B1's purchase-gold→treasury routing (and at what %), or keep purchases 100% burned?
2. **Who is the gatherer's buyer of last resort?** Under C4 (+C2), NPC shops pay ~30% of GE and the city pays full price *only when the player posts orders*. If the player posts nothing, gather income craters. Intended pressure (player-as-procurement, EHT-style), or should baseline NPC town demand keep a survivable floor income (my lean: keep the floor; it's the current validated behavior and the C4 ceiling formula preserves it)?
3. **Shop roster expansion.** C4/C5 presuppose specialty shops (armour/archery/etc.). Only General Store + Fishmonger exist. Greenlight a canon Varrock roster (e.g. Horvik smithy, Lowe archery, Zaff staves, Thessalia clothes, Aubury runes — all designed in WORLD_AND_CHARACTERS) as part of Unit 2, and which subset?
4. **Slayer-master identity.** No Vannaka in canon Varrock. Use Vannaka anyway (reference parity), or a Varrock-flavored stand-in (e.g. a Champions' Guild figure)? Pure naming/lore call.
5. **Bounty unification.** Adopt the funded per-kill bounty and *retire* the clamped utility bounty for FIGHT — and do gather incentives stay utility-based, migrate to price-bias (B1), or also become funded per-unit deliveries?
6. **On-task bonus scale.** Reference +26 flat. Our term scale puts the safe-by-evidence zone at ≈ +18–24 (incentive sweep cliff at ~+36 standing). OK to open at +20 and lock via the standard sweep, i.e. is the *number* mine to tune within gates while the *mechanic* is locked?
7. **Loot settings semantics (C1).** No ground loot exists; drops auto-resolve. Is loot_policy as a **drop-filter** (keep-all / upgrades-and-valuables-only / salvage-all) an acceptable reading, or is literal ground loot (items dropped to tiles, pickup trips) the design intent (a substantially bigger system that §14 gravestone logic will eventually want anyway)?
8. **Tax architecture.** Current: 3% on NPC-shop sales (misnamed GE_TAX), funding the treasury. With a real GE: reference says 1% GE trade tax. Unify (e.g. 1–2% everywhere)? Does the GE tax also fund the treasury (my lean: yes — it partially replaces shop-tax inflow as volume migrates)? City buy orders presumably untaxed (the city is the buyer)?
9. **Bank scope.** Is the bank (hero item storage) in scope for Unit 4 as assumed (it's the same roadmap wave, and C2's anti-hoarding rationale presumes it), or deferred further? If deferred, C2 still works — heroes just keep selling everything each trip.
10. **Save migrations.** Part-C features each extend the save; `SAVE_VERSION` mismatch currently discards saves. Greenlight a small migration scaffold (versioned upgraders, oldest→newest) as part of Unit 0 or 1, before the schema churn starts?
11. **UI tech for C1 popups.** The hand-rolled immediate-mode UI has no dropdowns/range-sliders/forms. Options: (a) extend the immediate-mode toolkit (uniform with everything else, more hand-rolling), or (b) introduce Godot Control nodes for *new popups only*, keeping all existing panels untouched. I lean (b) — it's the engine's intended path and reduces bespoke code — but it introduces the project's first Control-node UI and a mixed paradigm. Preference?
12. **Day-length denominated specs.** Our in-game day ≈ 41 real minutes at 1×, and 24h offline ≈ 35 sim-days. C5's "1–3 units per 3 in-game days" translated literally is ~0.1–0.3/unit/real-hour at 1× — confirm specs like this should be read in *sim-days* (my assumption throughout), not real-time.

---

# APPENDIX — One-time environment check

1. **`claude --version`:** `2.1.174 (Claude Code)`. Note: the binary is at `C:\Users\Ripto\.local\bin\claude.exe` and is **not on PATH** in PowerShell or bash on this machine — `claude --version` fails in a plain shell; the full path works.
2. **Desktop app vs terminal:** **Claude Code Desktop app**, as best determined: the session's parent-process chain is `powershell ← claude.exe ← claude.exe ← explorer.exe` (launched from the Windows shell, not from any terminal emulator), and Claude-Code-Desktop-specific session/MCP tooling (`ccd_session`, `ccd_directory`, preview tools) is present in the session. Not a standalone PowerShell/Windows-Terminal CLI session.
3. **`%USERPROFILE%\.claude.json`:** exists. The **`remoteControlAtStartup` key is absent** from it (checked for exactly that key; nothing else read or dumped).
4. **OS & shell:** Windows 11 Home, version 10.0.26200. Primary shell: Windows PowerShell 5.1 (`powershell.exe`); Git-Bash (POSIX) also available to the agent.
5. **Git:** yes — a `.git` repository is initialized at the project root, remote `origin = https://github.com/AlohaOe-SD26/OSRS-AFK`. **Caveat:** branch `main` has **zero commits** — all files are staged but never committed or pushed (flagged in §A0/§A11).

*— end of report —*
