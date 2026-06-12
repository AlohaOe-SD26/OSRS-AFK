# PROJECT_STATUS — Gielinor Tycoon

> The thread that survives between sessions. Update this at the end of every phase.
> Last updated: 2026-06-09 — **Step 6 (polish & scale) CLOSED in Godot 4.6.3** (headless test 99/99 green).
> **Build steps 0–6 = the full §22.3 MVP slice, DONE.** Next: take stock, then post-MVP breadth (where §18 comes due).
> Prior: Step 5 (story & society) 92/92; Step 4 78/78; Step 3 52/52.
> Step-5 note: social web is rival-leaning by design-residual (the 32% combat over-concentration, socially masked);
> diagnosed (combat-utility asymmetry, precondition confirmed / causal link deferred), §18 fix queued to first-real-combat.
> Godot binary on this machine:
> `C:\Users\Ripto\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe`
> NOTE: after adding a NEW `class_name` file, run a one-shot import pass before the headless test
> so the global class cache registers it:
> `godot --headless --path game --editor --quit` then run `tests/test_sim.gd`.

## One-liner
A single-player idle/tycoon "ant farm" for canon OSRS: autonomous procgen heroes live in
Varrock — gather, craft, fight, trade, level — while the player incentivizes / nudges / seizes.
Endgame = defeat the escalating rival Zezima. Engine: Godot 4, desktop-first.

## Step 6 — polish & scale (§22.3) — IN PROGRESS (started 2026-06-09)
Order (planner-confirmed): scale-validate → LOD (render+exact-sim opt; byte-identical gate) → save/load (determinism
gate) → offline (faucet-absorption + ceiling, watch bug-class #5). LOD scope = render/display + result-preserving sim
opts ONLY; approximate statistical sim-LOD is OUT (can't be byte-identical — that's offline's machinery).

**STANDING HARNESS RULES (banked 2026-06-09 after two hung gate runs — same class, different members):**
1. **Every SceneTree diag/gate/sweep harness MUST end `_initialize` with `quit(exit_code)`** — without it the
   engine idles forever after computing; piped output never flushes; looks hung. (Instance 1: diag_asymmetry.gd.)
2. **Harnesses must `preload("res://tools/...")` cross-file dependencies — NEVER reference a tool's `class_name`
   global.** A class_name needs the global class cache, which needs an `--import` pass, and headless `--import`
   itself can hang (instance 2: the gate_determinism run — every script had quit(); the import chain was the hang).
   Preload-by-path works regardless of the cache → no --import dependency for any harness. (sim_hash.gd deliberately
   has NO class_name for this reason.)
3. **Short gates (<~3 min) run FOREGROUND with a timeout** — a hang is then visible and bounded, not a silent
   background stall. Long sweeps stay background.

#### S6.1 SCALE VALIDATION — done 2026-06-09 (8 seeds, cap50→~43 vs cap66→~50; `tools/diag_scale.gd`; POP_CAP now static var)
| metric | ~43 (baseline) | ~50 (MVP target) | verdict |
|---|---|---|---|
| per-capita gold | 627±14 (drift 1%) | 586±16 (drift 0%) | **HOLDS — bounded, tighter** |
| perf | 280 ms/1k ticks | 305 ms/1k ticks | **HOLDS — linear, no cliff (0.3ms/work-action)** |
| combat-share (non-fav) | 32%±5 | 42%±6 | **MOVED** |
| social Friend/Rival | 5.6%/17.2% | 4.3%/19.4% | **MOVED (tracks combat)** |

**Gates PASS:** economy attractor bounded at 50 (drift 0%, tighter than at 43); sim perf scales linearly, well within
budget (50-agent GDD target met). **FINDING (not a tuning target): combat-share + rival-lean WORSEN at 50** — and in
the DIRECTION the §18 asymmetry predicts (more pop → harder gather glut → bigger price-independent combat refuge → more
rivals). Corroborates §18 (2-point scale-direction, not a confirmation) and means **§18 matters MORE at the MVP scale
than at 43.** Not a Step-6 blocker. Default POP_CAP stays 50 (→~43 natural plateau); 50 is reachable/healthy at higher cap.

#### S6.2 LOD — done 2026-06-09 (render-only; byte-identical gate PASS)
Built: viewport CULL (skip off-screen drawables) + LABEL THROTTLE (>24 heroes → only the selected hero gets a
name label; `[L]` toggles). Reads sim read-only, writes nothing (`h.flash` is a sim→render cosmetic; feeds no
decision). **Gate: `tools/gate_determinism.gd` PASS** — 3 seeds, identical full-state hashes; LOD lives only in
`render/Main.gd`, the headless sim never instantiates it → LOD-on/off are the same program by construction.
**Visual pass (`--lodshot` captures): label throttle flips EXACTLY at the 24→25 boundary** (pop-24 all labeled,
pop-25 selected-only); LOD-off at 42 shows all labels. **Cull finding:** project uses `stretch/mode=canvas_items`
@1280×800 design res → the viewport rect never changes with window size and the whole 18×18 map always fits →
**nothing is ever off-screen in the fixed-camera build; the cull is correct-by-predicate but INERT** (culled=0 in
every capture; no on-screen hero ever culled). It becomes live when a camera/zoom/larger map arrives. The active
LOD win today is the label throttle (draw_string was the per-hero cost).

#### S6.3 SAVE/LOAD — done 2026-06-09 (determinism gate PASS)
`sim/SaveLoad.gd` (no class_name — preloaded, per harness rule #2): FULL state — heroes (every field incl. act/
nudge/seized/milestones), monsters, shops (stock/max/consume/level), treasury/tax, population, social adj,
incentives/buildings/kick_records/_announced_bonds, chronicle, clock/counters, **and RNG state** (§25: the stream
continues, not restarts). **BINARY Variant serialization** (store_var/get_var — exact float-bit round-trip; text
precision could silently break determinism). **save_world() is a PURE READ** (no log_event) so saving mid-run can't
perturb the run. Render: F5 save / F9 load. SimHash fingerprint extended (RNG state + monsters).
**Gates: `tools/gate_saveload.gd` PASS** — 3 seeds, save@mid→DISK→load→continue ≡ uninterrupted (identical hashes);
test suite 92→**96/96** (round-trip fingerprint ≡ + 2000-tick continued evolution ≡).

#### S6.4 OFFLINE CATCH-UP — done 2026-06-09 (instance-#5 gate PASS; the held offline-yield-ceiling bug FIXED)
**The core insight:** at live cadence 1 real hour ≈ 1.46 sim-days, so a 24h offline window = ~35 sim-day-equivalents
— linear yield×0.75 over that with no sink injects ~100k/hero (the held bug, and bug-class instance #5 stated in
advance). Fix = the projection embeds THE SAME bounds live play has: (1) **market ceiling** — gatherers share the
town's consumption rate per good (shop-level-scaled §19.2), priced at the current (≈floored) sell price, GE-taxed;
(2) **pit throughput** — total offline kill rate = alive rats × solo rate, shared across fighters; (3) **attractor
projection (gold)** — closed form of the live ODE `g' = 0.75·r − upkeep(g)`: gold approaches what live play would
actually HOLD (g*) and cannot overshoot; floored at g0 (§4 safe accrual — never lose gold offline). XP stays linear
×0.75 (no sin k live either — faithful). **Design interpretation flagged for the record: the locked "75% rate"
applies to the EARN RATE inside the projection; the live sinks then bound the held total** (linear-total×0.75 was
the bug). Rare-×0.5 constant plumbed; NO drop tables exist in Phase 0 → nothing to roll yet (noted, not claimed).
**Gates (`tools/gate_offline.gd`, 3 seeds; clones via the proven save/load): PASS** —
- batches BOUNDED & SATURATING: e.g. 537g(2h)→758g(6h)→781g(24h) colony-wide (the exponential approach to g*,
  visibly not linear; old bug ≈118k for ONE miner/10h, new 10h-miner batch = 4,725g — test-asserted)
- **24h cap clamps the YIELD exactly**: gain(30h) == gain(24h) on all seeds
- **post-reconnect re-convergence**: offline-24h arm vs no-offline control over 6 live days → Δ 6% / 2% / 0% —
  no spike, no permanently shifted level; the attractor absorbs the batch
- post-offline **continuation is deterministic** (the approximation is in the batch; continuation is exact)
Tests 96→**99/99** (batch-bounded + cap-yield-equality + post-offline determinism).

#### ✅ STEP 6 CLOSED 2026-06-09 — all four pieces green (99/99): scale-validated to 50, LOD (gate PASS),
#### save/load (gate PASS), offline (instance-#5 gate PASS). MVP slice complete per §22.3.

#### UI overhaul (post-Step-6, player-requested, 2026-06-09) — render-only, 99/99 green
All menus combined into ONE tabbed OVERLAY panel (`render/Main.gd`): top tabs **Colony** (stats + town/shops/
builds/bounties) · **Hero** (sub-tabs + Nudge/Seize/vote commands) · **Chronicle** (full-height log). The panel
no longer squishes the play field — the map centers on the FULL window and the menu draws on top. **Minimizeable,
DEFAULT CLOSED** ("MENU [M]" button / `[M]` key; "X close" in the header); **dock side toggleable** (header
"side: R/L" button), **default right**. Clicking a hero opens the menu on the Hero tab (closeable — fixes the
stuck-open info panel). Clicks on the open panel never fall through to the map. Slim always-on status ribbon
(top-left) + help line. `--shot` captures are forced-deterministic (a stray click in the unattended dev window
once flipped the dock state mid-capture — captures now set their state explicitly).

## MERGE DECISION (2026-06-09) — HTML concept (`gielinor-tycoon (1).html`, ~2,900 lines) reviewed vs this build
The user's second prototype (other AI agent) implements nearly the FULL GDD breadth (items/tiers/recipes, combat
triangle+prayer, zones/Slayer/GE/PK/graves, votes, reincarnation, Zezima) with the LOOK the user wants (canon 46×34
Varrock map, pan/zoom, roster/drawer/HUD UI) and a RICHER BRAIN (Layer-1 drives + skillNeed-saturating scores across
~20 activity types + demand-responsive labor + fear + directives). BUT: zero tests/validation, soft unvalidated
attractor (3%/day above 400g floor), and **its offline catch-up has bug-class instance #5 verbatim** (linear
yield×hours, no market/attractor bound — the exact bug our gate caught). **VERDICT: MERGE on the Godot foundation**
(locked stack §21; validated economy/determinism/harness) adopting from the HTML version: (1) the full look/UX →
render port; (2) the brain design → the queued §18 rebalance blueprint (drives+skillNeed = combat/gather symmetric,
saturating — carries the banked prediction re: monoculture+rival-lean); (3) content breadth → post-MVP roadmap via
ContentDB waves (death/PK/graves wave activates CANON social negatives → retire interim friction, as banked).
**Order: M1 visual/UX port (render-only, sim-byte-identical gate) → M2 brain v2 (multi-seed gates) → M3+ content
waves (each: ContentDB port + §6 re-tune + standing gates).** The HTML file stays as the behavioral/visual reference.

#### M1a — canon map + camera DONE 2026-06-09 (99/99 on the new geography)
Ported from the HTML concept: **46×34 canon Varrock + Barbarian Village** (`data/varrock_map.json` v2 — locations
+ a `terrain` block: city/barb/palace rects, GE circle, river segs, bridges, roads, wall gate-gaps, all data-driven)
and a **camera** (wheel-zoom toward cursor, RMB/MMB-drag pan, [Home] recenter — via `draw_set_transform`, so all
world drawing transforms for free; picking in screen space; **the LOD cull is now LIVE when zoomed**). Terrain
renderer ports bakeTerrain 1:1 (district floors, river/bridges, road net, deterministic deco trees, walls, GE ring);
location renderer gained the full kind set (bank/palace/shop/altar/range/anvil/tavern/gate/hole/ge/fountain/portal/
circle/grass + legacy). **SIM-AFFECTING data change (flagged at gate time): the 6 functional nodes moved to canon
spots → travel distances changed.** Suite re-run on the new geography: **99/99** — day-12 gold 5207/+17% (was
5178/+14%), per-capita band 568..621 (was 611..643 — longer travel, attractor holds), labor-pull strong. NOTE:
heavy shop-leveling run now 54.3k (was 36k; ceiling 60k) — watch at the next economy re-tune. Standing sweep
BASELINES (combat-share 32%/42%, social distribution, Tier-1 dose curve) were measured on the OLD map — re-baseline
before the next comparison (do NOT compare new sweeps against old-map numbers). NEXT: M1b HUD/roster/drawer restyle.

#### M1b(1) — independent HERO POPUP + camera-follow zoom DONE 2026-06-09 (render-only; 99/99 unchanged)
Hero panel separated from the main menu into its own bottom-drawer POPUP (user-spec): clicking a hero opens it;
**the camera snaps to and FOLLOWS that hero at ×2 of the pre-open zoom**; a **slider + readout in the popup header**
varies zoom in [pre-open zoom .. 4× it] (can't zoom out below the open-time zoom); close (X / Esc) **restores the
camera exactly**. Layout: identity | sub-tabs (Stats/Thoughts/Gear/Social/Saga) | commands (Nudge/Seize/vote).
Main menu is now Colony/Chronicle only. Drawer consumes its clicks; exile/departure auto-closes + restores.
REMAINING in M1: HUD top-bar restyle + left roster cards (concept look). NEXT after M1: M2 brain v2.

## Where we are
**Build steps 0–5 DONE & verified green in Godot 4.6.3** (headless test 92/92). Step 5 = story & society
(competition-friction + same-trade kinship social deltas, civic kick votes, gravestone-loot dormant, curated
Chronicle that reads as a story) — CLOSED; see the Step-5 section. Combat over-concentration (32%) + its social
rival-lean diagnosed (combat-utility asymmetry, leading-but-unconfirmed) → §18 fix queued to first-real-combat.
**Next: Step 6 — polish/scale (→50 heroes, LOD, offline catch-up, save/load) per §22.3.**

**Build steps 0–4 DONE & verified green in Godot 4.6.3** (headless test 78/78). Step 4 = the player
control layer (incentivize / nudge / seize) + town building + the command UI — see the Step-4 section below.

**Build steps 0–3 DONE & verified green in Godot 4.6.3** (headless test 52/52).
- Step 0 foundations + step 1 gather loop: ✅ verified 2026-06-08.
- Step 2 **live combat**: ✅ tick fights vs. rats (canon Combat.gd rolls), death/respawn (§14),
  reactive eat/flee, coin drops + Strength/HP XP. Fighters buy food → the food sink returned and
  pulled the economy up from gather-only 2,564g toward ~7,110g (drift +15%, bounded) — as predicted.
- Step 3 **shops / population / relationship graph**: ✅ verified 2026-06-08.
  - **3a NPC shops first-class** (`Shop.gd` + `Economy.gd` facade): two inspectable canon vendors
    (General Store ore/logs · Fishmonger raw/cooked fish), each with stock + a `level` field
    (§19.2 dial, effects in Step 4). Town-consumption promoted to a per-shop first-class sink;
    GE-tax promoted to a tracked `economy.tax_collected`. Behavior-preserving: economy day-12 gold
    = **7152, drift +15% — byte-identical to the Step-2 baseline** (the attractor untouched).
  - **3b Population & immigration** (`Population.gd`): reputation (avg-combat-level driven, bounded
    → no runaway) → immigration rate × **free-capacity fraction** (the damper → asymptote, no
    oscillation); newcomer rarity tiers (Greenhorn→Elite), rep-tilted; voluntary-departure valve
    (§16.1) wired (floored at the founding 6). Town demand now scales with population (§6.5) so
    faucets & sinks grow together. **Result: pop 6→44/cap 50, late-run swing 4 (stable, no
    oscillation); per-capita gold flat at ~810–840 across the whole 6→44 climb (per-cap drift −1%).**
    Both planner watch-numbers green.
  - **3c Relationship graph** (`Social.gd`): directed signed sparse graph R∈[−100,100], nested
    adjacency (only nonzero edges), **lazy O(1) decay on access + self-prune** (perf watch met),
    tiers (§16.3). Phase-0 accrual = proximity + a rat-pit co-op bond. **One** effect wired
    (trade-preference multiplier, latent until hero-hero/GE trade) + a gentle §19.4
    relationship→satisfaction term. PvP-avoid / vote-bias / give-back stay queued for Step 5.
- Step 4 **player control layer**: ✅ verified 2026-06-09 (see the Step-4 section below).

### Step 4 — Player control layer SHIPPED + verified 2026-06-09 (headless 78/78)
Build order followed (Hero Panel → Incentivize → Nudge → Seize → town building). Design rule held
throughout: **everything is player-initiated and default-off → all 52 Step-0..3 checks stay byte-identical**
(economy attractor untouched: per-capita band still 611..643, pop 43, rep 49). No new `class_name` files
(control state lives on SimWorld/Hero; buildings are plain Dicts) → the class-cache reimport gotcha is sidestepped.

- **Tier-1 Incentivize** (`world.incentives` {intent→weight}; `Brain._incentive` adds an `incentive` term to
  every candidate, FIGHT included). A posted bounty steers LABOR via utility — it does NOT touch the gold
  supply (the attractor stays put). **Multi-seed labor-pull result (`tools/diag_incentive.gd`, 16 seeds, pop
  fixed 6, time-integrated share on GATHER_LOGS, mean ± SD):**

  | bounty weight | % labor on target | per-capita gold |
  |---|---|---|
  | 0 (control) | 15% ± 1 | 870 ± 17 |
  | 12 (1 step) | 15% ± 1 | 867 ± 25 |
  | 24 (2 steps)| **18% ± 1** | **921 ± 48** (stable) |
  | 30 | 22% ± 2 | 1612 ± **929** (variance blowing up — edge of instability) |
  | ≥36 (over cap) | 23% ± 1 | **131 ± 0** (CRATER) |

  **The lever measurably pulls labor** (~+20% relative on target at the safe max), distributions separate
  cleanly — the empirical proof that indirect ("incentivize, don't command") control is real, not cosmetic.

  **KEY FINDING (instrumented) — the bounty crater is a RECURRING bug class, not just a knob:** a *pure-utility*
  bounty set too high overproduces what the market can't clear — at ≥36 heroes flood the node, the shop
  SATURATES (stock→max, price→floor 1), they can't sell, per-capita gold craters 870→131. This is structurally
  IDENTICAL to (a) the original saturated-shop mint (Step 1) and (b) the capacity-ceiling failure from the
  labor-spread investigation (Step 3). The common root: **a production lever with NO back-pressure from whether
  the market can absorb the output.** Incentive currently steers *attention* without funding *demand*.

  **INCENTIVE_MAX clamped to 24 is an INTERIM GUARDRAIL (planner-ratified 2026-06-09), NOT the design.** The
  **intended Tier-1 implementation is a FUNDED per-unit bounty**: paid from the treasury, clearing through the
  market, so it steers labor AND creates the demand to absorb the extra production → it CANNOT crater, and it
  makes the treasury load-bearing (Tier-1 becomes a genuine economic act — "player as central bank", §6 — not a
  free utility-nudge with a saturation cliff). Build it when Tier-1 is next touched; until then the clamp holds
  the lever in the stable zone. DO NOT mistake the clamp for the design. **Also:** `INCENTIVE_STEP=12` sitting
  under the +16 favorite-bias gap (gentle notch barely moves specialists) is CORRECT/believable stickiness, not
  a bug — and is a transient of the *unfunded* model (the funded bounty changes the reward term directly), so
  do NOT tune INCENTIVE_STEP against the current model.

- **Tier-2 Nudge** (`hero.nudge`; `nudge_hero` interrupts the trip → re-decides now → the injected activity wins
  via a finite NUDGE_BONUS, then is consumed → autonomy resumes). One-off, not sticky; verified the hero
  re-decides via the brain after the nudged trip.
- **Tier-3 Seize** (`hero.seized`; `_work_action` gates auto-`_start_activity` so a seized hero's brain is
  SUSPENDED — never auto-decides; `command_seized` issues direct activities; `release_hero` restores autonomy).
- **Town building** (§19): `economy.treasury` fed by the GE-tax skim (gold ALREADY removed from hero circulation
  → `total_gold()`/attractor unaffected). **Shop leveling** scales stock capacity AND town demand by the same
  factor (the §6.5 faucet/sink-invariant principle) → bounded by construction; heavy +5/+5 leveling stays bounded
  (gold 35,959 for 6, < 60k ceiling) but DOES raise the equilibrium (investing in shops grows the economy — by
  design). **Buildings** (Lodge=+satisfaction, Monument=+reputation, Tavern=+both) cost treasury + draw daily
  upkeep (the §6 continuous sink); rep/sat bonuses wired into Population. All default-empty.
- **Command UI** (`render/Main.gd`): hero-panel NUDGE/COMMAND row + Seize/Release toggle; a TOWN section with
  shop-upgrade, build, and bounty (click-to-cycle off/+12/+24) buttons; colony header shows Treasury + Rep.
  Immediate-mode clickable rects (`_ui_rects`), render-only. Verified on the real GPU (windowed `--shot`).

### Control-tier × combat-lock PROBE 2026-06-09 (`tools/diag_lock_probe.gd`, 8 seeds, mean ± SD) — CORRECTS a banked diagnosis
Asked: do the new controls reach the held ~32% combat-over-concentrated fighters? Grew to scale (23 days,
immigration ON → 32% ± 5 non-fav fighting, the residual), froze membership, then ran a 2-day probe on the
non-fav fighters (8.9 ± 2.2/seed) under three arms from identical per-seed state:

| arm | % of target fighters who left combat in 2 days |
|---|---|
| none (baseline) | 48% left · **0% ± 0 FROZEN** (every target re-decided ≥once) |
| NUDGE (Tier-2 interrupt) | **100% ± 0** |
| BOUNTY (Tier-1 passive, clamped 24) | 53% ± 26 (≈ baseline; huge variance) |

**FINDINGS — this corrects the earlier "Monoculture CRACKED = re-decision LOCK" note:** (1) **There is NO frozen
lock at a 2-day horizon — 0% frozen.** Every over-concentrated fighter reaches decision points regularly, via
the food/flee/disengage exits (NOT the kills-gate). The earlier "the trip never completes → never re-decides"
premise is empirically false at this horizon; the Stage-1 fix + the survival exits already provide cadence.
(2) **Nudge/Seize (Tier-2/3) are a reliable release valve — 100%** (they INTERRUPT: `nudge_hero`/`seize_hero`
clear `h.act`, no decision point needed). (3) **The clamped Tier-1 bounty does NOT redirect already-committed
fighters** (53% ≈ 48% natural churn, ±26 noise) — at the clamped magnitude it doesn't win at their decision
points and they re-pick combat. So the residual **32% is a congestion-balanced dynamic equilibrium of
normal-cadence heroes, not an unreachable lock**.

**CALIBRATED POSITION (planner-ratified 2026-06-09 — do NOT over-claim in either direction):** we were first
too-pessimistic ("locked"), then nearly too-optimistic ("working-as-designed equilibrium"). The honest, banked
statement: **the 32% is NOT a reachability problem (controls reach 100%, 0% frozen at the 2-day horizon) and is
NOT a Step-5 blocker. Whether it is a *desirable* equilibrium or merely a *benign* one is UNCONFIRMED at sub-day
resolution** — the 2-day window can't distinguish a healthy equilibrium from slow churn that looks like one at
coarse resolution. So: reachable + benign; *desirability* deferred as a feel/polish question, to be judged by
WATCHING it, not by a prerequisite gate.

**IMPLICATION for Stage-2 & Step-5 readiness:** Stage-2 was specced as "re-entrant/timer trip-completion to fix
UNREACHABLE decision points" — but the probe shows decision points ARE reached (0% frozen), so **Stage-2's stated
premise is undercut; it is NOT a prerequisite for Step 5** (heroes re-decide on a normal cadence, and the social
systems' direct controls — kick votes / nudges — reach agents 100%). Step-5 does NOT sit on an unreachable-agent
substrate. What Stage-2 *would* still buy is a tighter combat cadence / lower equilibrium share, but that's polish,
not a blocker. (The genuine Tier-1 reach limit is the unfunded-bounty weakness, which the funded per-unit bounty
addresses — see above.) **Planner to ratify this re-framing of the residual.**

### Step-3 monoculture — INVESTIGATED 2026-06-08 (4-arm × 6-seed controlled sweep)
At ~43 heroes ~66–68% of non-fighting-favorite heroes are fighting (the single rat pit). We chased
the cause through three diagnosed levers, each measured properly (multi-seed — single-seed is
confounded because changing the brain perturbs the RNG stream and thus the newcomer-favorite mix):

| Arm (6 seeds, 23 days) | % non-fav fighting | per-capita gold |
|---|---|---|
| A baseline (orig) | 68% | 1151 (801–2207) |
| B +combat trip-completion (N=6) | 66% | 1083 (777–2551) |
| C +full-weight combat congestion (×1.0) | 66% | 788 (775–795) |
| D +3.75× gather pay (floor 0.12→0.45) | 68% | 2054 (2033–2091) |

**The monoculture is robust to ALL THREE levers** — decision cadence, congestion weight, and gather
profitability. So it is NOT the §18.6 cadence bug, NOT congestion discounting, and NOT the gather
floor — and because it is unresponsive to economic levers it is NOT an economy distortion.

### Monoculture — CRACKED 2026-06-08 (decision-level instrument, `tools/diag_decision.gd`)
Pure-observation instrument (Brain now attaches the same `terms` it scores with → can't diverge).
At a fair re-decision a fighter scores **COMBAT −90 vs GATHER +14.5** — combat LOSES badly (the
−108.5 congestion term buries it). So the reward-asymmetry hypothesis is FALSIFIED: combat's missing
reward term is real but irrelevant; it doesn't win on reward, it loses on congestion. The utility
function is HEALTHY and responsive. The monoculture is a **re-decision LOCK** — two gating bugs keep
fighters from acting on it:
1. **Food-hoard space gate** — `Brain.choose` only offers gather candidates when
   `(28−inv_count) > 4`; **23 of 32 fighters carry ≥24 cooked_fish** (e.g. a fishing-favorite who
   cooked a stack then got pulled into combat) → gather candidates SUPPRESSED → combat is the only
   thing on the menu. They don't choose combat on utility; it's the only option offered.
2. **Kills-gated trip-completion unreachable** — completion needs N=6 kills, but with 4 rats / 32
   fighters the max any fighter reaches is **5** → the trip never completes via that path (§18.6
   "periodically" clause is missing; only "on completion" was wired).
**Step-4 implication (reassuring):** incentivize/nudge act on the same utility function, which is
healthy — they WILL work once heroes can fairly re-decide with all candidates on the menu.

### Monoculture — Stage-1 fix SHIPPED + multi-seed validated 2026-06-08
Per the research brief (candidate-generation failure, not scoring): the gather "room?" gate now
counts CARGO only (food is a reserved partition, `Hero.cargo_count()` / `Config.GATHER_GATE_CARGO_ONLY`),
and `Brain.candidates_with_terms` enforces a never-empty menu (REGROUP→sell fallback). 16-seed sweep
(`tools/diag_sweep.gd`, mean ± SD, distributions separate cleanly):

| metric | BEFORE (bug) | AFTER (fix) |
|---|---|---|
| % non-fav-favorites fighting | 68% ± 6 | **32% ± 5** |
| following-favorite (specialist mix) | 49% ± 8 | **68% ± 5** |
| fight head-count | 33.3 ± 1.5 | **21.4 ± 1.5** |
| per-capita gold | 881 ± 333 | **623 ± 17** |

Monoculture halved, ~6-SD effect (real, not noise); believable specialist mix emerging; per-capita
gold VARIANCE collapsed (±333→±17 — labor was seed-lock-dependent, now consistent). The 6-hero
regression equilibrium shifted too (gold 7152→~5178, kills 1437→1031) — the fix unlocks the 2
food-hoarded founder-fighters into gathering; still bounded (drift 14%), level lower because the
faucet mix shifted off combat (the doc's "re-check sink under the new labor mix" — attractor holds,
±17 SD). 52/52 green. **Queued (Stage 2, only if the remaining 32% matters):** re-entrant / timer
combat trip-completion (kills-gate N=6 is still unreachable at high congestion) + weighted-random
among near-ties + anti-starvation nudge. Stage-3/4 (per-decision logging, per-hero RNG streams) noted.

**KEPT from the investigation (committed):** combat **trip-completion** (`Config.COMBAT_TRIP_KILLS=6`)
— it FIXED a genuine §18.6 compliance bug: the fight loop self-sustained forever, so fighters reached
~0 decision points; now ~5/day (cadence probe). Worth keeping for its own sake (every future
trip-based system — Slayer, zone trips, boss runs — inherits correct re-decision cadence), and
per-capita gold stays bounded. **Reverted (unvalidated):** full-weight congestion (×0.5 kept) and the
raised gather floor (0.12 kept). Levers are now `static var` in Config so `tools/diag_sweep.gd` can
A/B them. 52/52 still green.

**Secondary finding:** per-capita gold has real SEED variance (≈800–2550 across seeds), bounded
per-seed but level-dependent on the emergent mix — the Step-3 "≈800, −1% drift" was a DEFAULT_SEED
artifact. (Curiously, full-weight congestion arm C *tightens* it to 775–795.)

### Social monoculture — being resolved in Step 5 (was: correct-for-Phase-0)
794 friends / 0 rivals was correct for Phase 0 (only positive deltas wired). Step 5 adds the negatives.

### Step 5 — Story & society IN PROGRESS (started 2026-06-09)
**Negative-delta source decision (planner-ratified 2026-06-09).** The §9 canon negatives are PvP-kill (−25),
gravestone-loot (−5/item), yes-vote-to-kick (−15). Reality check: **PvE deaths ≈ 0** (survival-tuned — combat
test shows 0 deaths/0 flees), **PvP is unbuilt/held** (post-MVP), and **kicks are god-initiated** → NONE of the
canon negatives fire autonomously. So Step 5 sources autonomous rivalry from **competition-friction**: the
SYMMETRIC NEGATIVE COUNTERPART to the already-shipped co-op/proximity bond — heroes crowding an OVER-CONGESTED
node take mild rivalry (competing for scarce spots/market), gated on a crowd threshold, weak. **This is the
INTERIM autonomous source — a bridge until PvP brings the canon kill delta (post-MVP)** (same interim-mechanism-
now / richer-version-later pattern as the clamp-vs-funded-bounty). NOT in the §9 delta table; a deliberate,
economically-grounded addition (ties social to the economy: the congestion that breeds friction is the same the
brain routes around → self-correcting → should keep rivalry bounded; VERIFY). Also: **kick-vote** deltas
(yes −15 / defend +10) are the canon civic source (player-initiated). **Gravestone-loot wired DORMANT** (fires on
PvE death ≈never now; ready for PvP/§14-looting). PvP-rivalry + give-back stay HELD.
**Guardrails:** (1) friction weak + symmetric to co-op + saturated/crowded-node-gated (neutral = default); (2)
watch for the INVERSE monoculture — success = a believable distribution (mostly neutral, some friends, a few
rivals, rare nemeses), multi-seed; do NOT trade 794-friends for 794-rivals; (3) re-balancing the *positive* co-op
side is in scope (it currently saturates to Ally → that's the 794-friends cause). Build order: friction+deltas →
measure/tune distribution → kick votes → Chronicle viewer.

#### Step 5 — BUILT & verified 2026-06-09 (headless 92/92; economy still 5178/+14% byte-identical — social is orthogonal to gold)
- **Friction is gated on SCARCITY, not headcount:** the rat pit has N rats; >N fighters = real competition →
  rivalry; gather nodes are abundant → always co-op (`Social._proximity_pass`, `SimWorld.alive_monster_count`).
  Maps to the actual game (scarce mobs vs unlimited gather). The first attempt (headcount>5) failed — at 43
  heroes every node is >5, so friction fired everywhere and killed all friends.
- **Negative deltas wired:** `record_vote` (yes −15/defend +10), `record_graveloot` (−15, DORMANT — deaths≈0),
  competition friction. **Kick vote** (`start_kick_vote`/`force_kick`/`can_force_kick`): eligibility (present +
  not in a work phase), quorum ≥25% (void doesn't consume an attempt), pass >50%, 5-fail→force-kick, cooldown,
  relationship+value-weighted ballots, exile (remove + `social.drop_node` + rep dent). All seeded-deterministic.
- **Chronicle (§17) curated for STORY:** notability field; routine economy/per-kill events demoted to
  notability 0 (NOT in the Chronicle — was burying it); level-ups → Chronicle only at 50/75/90/99 (saga keeps
  all); social events → only Ally/Nemesis reach the town Chronicle (Friend/Rival = saga only), capped 3/day (no
  burst-spam); **unique display names** ("Bjorn III" — 12 names / 45 heroes was colliding). Color-coded viewer
  + kick-vote buttons in `render/Main.gd`.

**DISTRIBUTION (tools/diag_social.gd, locked interim = prox3.6/coop2.4/fric4.5/cap3.0/decay.97, 5 seeds, 23d):**
~76% Neutral · 6.1% Friend · 0% Ally · **16.9% Rival** · 1.3% Nemesis. **It's a real spread (NOT a monoculture)
but RIVAL-LEANING** (rivals ~3× friends). Root cause (multi-seed-diagnosed, not a knob): the combat-locked pit is
a LARGE STABLE group → many durable rival edges; gather co-op is CHURN-LIMITED (the combat draw keeps reshuffling
would-be-stable gatherers) → friends cap ~6% at any amplitude. Amplifying deltas spreads the web across tiers
(the strongest bond was only ±24 before — everything compressed into Neutral) but can't make friends ≥ rivals.

**COLD-READ verdict:** the Chronicle now **READS AS A STORY** (arrivals, alliances, sworn-nemesis feuds, milestone
99-track level-ups, a civic exile "Bjorn is banished from Varrock by decree" after a failed 3–10 vote) and the
per-hero saga reads as a character ("Bjorn — a born prospector, loyal to Varrock; befriended Magnus III; reached
Mining 65"). BUT it reads as a TENSE, feud-ridden boomtown (nemesis lines ~5:1 over ally lines).

**Same-trade KINSHIP — added on its own merit (planner-ratified 2026-06-09).** A stable positive source SYMMETRIC
to friction: friction = competing for scarce resources → rivalry; kinship = shared craft/identity → affinity.
Heroes who share a favorite skill accrue a small steady positive delta, location-INDEPENDENT (stable, because
favorite is fixed — where node co-op is churn-limited). Good regardless of the distribution problem: ties social
to the LABOR structure (the project through-line) and seeds future hero↔hero/GE trade prefs. Guardrail: weak, must
NOT saturate every same-trade pair to Ally (the 794-friends failure in a new outfit) — Friend-tier for colleagues,
Ally rare. NOTE fighters share "fighting" so they get kinship AND friction — friction (scarce rats) dominates → net
rivalrous, which is correct (and self-resolves if the combat lock eases).

**KEY INSIGHT banked: the social web is now a SECOND, INDEPENDENT probe of the 32% combat residual.** The rival-lean
is partly that residual wearing a social mask — friends cap ~6% because the combat draw CHURNS would-be-stable
gatherers off their nodes (co-op never accumulates), while rivals are durable because the pit is a large stable
group. **SEQUENCING RULE (do not violate):** build kinship → multi-seed. If kinship alone yields a believable shape
(friends ~ rivals, nemeses rare) → done. If STILL rival-leaning → **STOP, do NOT keep trimming friction** to
brute-force friends≥rivals; that masks the upstream cause. The principled fix is to UN-DEFER Stage 2 (combat
trip-completion + weighted-random among near-ties), which fixes the social distribution AND tightens combat share
in one move. **This updates the earlier "32% = benign, optional polish" call: it's economically benign but
EXPERIENTIALLY SIGNIFICANT (independent social evidence) → re-promoted to worth-fixing-for-feel.**

#### STAGE 2 ATTEMPTED + MEASURED 2026-06-09 — BOTH LEVERS FAIL; dual-fix hypothesis FALSIFIED
Gate answered from code: (Q2) weighted-random acts at ACTIVITY-CATEGORY level (Brain candidates ARE intents:
FIGHT/GATHER_*/PROVISION; argmax over them; target/which-rat is `_nearest_monster`, not a brain decision, and
rats are the only target) → it CAN influence fight-vs-gather, so the dual-fix logic was structurally sound to test.
(Q1) levers independent by the thrash-definition (weighted-random doesn't re-decide per-tick — the FSM trip-commit
+ sticky throttle it), trip-completion expected to amplify. Built both isolated (Config.COMBAT_TRIP_ROUNDS timer;
Config.BRAIN_WEIGHTED_TIES + `SimWorld._pick_candidate`), swept 8-seed:

| arm | combat-share | Friend | Rival | per-cap gold |
|---|---|---|---|---|
| baseline (argmax, kills-only) | 32% ± 5 | 5.6% | 17.2% | 627 |
| +trip-completion timer (rounds16) | 32% ± 8 | 5.8% | 16.7% | 622 |
| weighted-random alone (band10) | **37% ± 6** | 4.2% | **23.5%** | 626 |
| weighted + trip | **41% ± 6** | 3.9% | 23.2% | 623 |

**Trip-completion = NEUTRAL** (cadence was never the bottleneck — confirms the 0%-frozen probe: fighters already
re-decide, they just re-pick FIGHT). **Weighted-random = WORSE** (combat-share UP 32→37→41%, rivals UP 17→23%):
softening argmax lets the INFERIOR combat option win more often (it's a near-tie when congestion momentarily dips)
→ MORE fighting, more pit-friction, more rivals. **So the Stage-2 spec does NOT fix combat over-concentration, and
therefore does not fix the social rival-lean.** Economy bounded throughout (per-cap ~625, attractor held — combat
throughput barely changed since the levers didn't move share).

**RE-DIAGNOSIS (leading hypothesis, consistent with the Stage-1 investigation):** the combat draw is a SCORING
ASYMMETRY, not a cadence/tie/herding effect. Combat has a flat, PRICE-INDEPENDENT base (14 + str×0.4), congestion
discounted ×0.5 (`COMBAT_CONGESTION_MULT`), and NO reward-saturation term; gather's reward FALLS as prices floor
(over-supply). So when gather nodes glut → gather utility drops → combat becomes the relatively-attractive
price-independent REFUGE. This explains why the monoculture is robust to EVERYTHING tried: cadence (trip-completion,
neutral), tie-spreading (weighted-random, worse), congestion-weight (Stage-1 arm C, ~flat), gather-floor (Stage-1
arm D, ~flat) — none touch the asymmetry. A real fix is a §18 combat-UTILITY rebalance (give combat congestion/
reward dynamics symmetric to gather, or a saturating combat-reward), which is its own investigation, NOT a polish.

**STATUS: both levers coded + measured + DEFAULT-OFF (ROUNDS 9999 / WEIGHTED false) → shipped state unchanged, 92/92
green. STOPPED knob-turning per discipline.**

#### ASYMMETRY CONFIRMATION ATTEMPTED 2026-06-09 (existing-logs correlation, `tools/diag_asymmetry.gd`, 8 seeds) → LEADING-BUT-UNCONFIRMED
Hard-gated to existing telemetry only (`dbg_log`: ore price, acts.fight, pop — no new instrumentation, which would be
§18's first move). Tested the prediction: combat-share rises as gather price falls, at FIXED pop (plateau cut, decisive).
**Result: gather price is PINNED at the floor (2.0 ± 0.0, zero variance, all 8 seeds, full-run + plateau); plateau
fight-share 49%.** Pearson UNDEFINED — no price variance to correlate against. So the causal TRACKING can't be shown
(price never moves), BUT the **PRECONDITION is CONFIRMED**: gather is permanently glutted → reward permanently floored,
exactly the state in which a price-independent combat base becomes the relatively-attractive refuge. **Verdict tag:
LEADING-BUT-UNCONFIRMED (precondition confirmed; per-hero causal link = §18's first move — decision-level logging).**
Not a falsification (fight-share isn't shown independent of a *varying* price; price simply doesn't vary). Did not
torture the no-variance series into a verdict. (Harness note: the read first hung on a missing `quit(0)` — pure
SceneTree-never-exits bug, fixed; no bearing on any conclusion.)

#### ✅ STEP 5 CLOSED 2026-06-09 — shipped green (92/92), economy bounded (5178/+14%, byte-identical), Chronicle reads as a story
- **Social rival-lean: KNOWN / DIAGNOSED / DEFERRED**, confirmation status = **leading-but-unconfirmed** (combat-utility
  asymmetry; precondition confirmed, per-hero causal read deferred to §18). NOT "understood and closed" — the cause is the
  leading hypothesis with its precondition verified, not a proven fact.
- **BUG-CLASS INSTANCE #4 + the generalization (bank this):** #1 saturated-shop mint · #2 capacity-ceiling labor failure ·
  #3 bounty overproduction crater · #4 combat-as-refuge (price-independent base). **Generalization: it's not just MARKETS
  that need back-pressure — EVERY dynamic does. Any force without a counter-force becomes the attractor as everything else
  saturates.** Combat's flat, price-independent base is that uncountered force here (gather saturates against it).
- **§18 combat-utility rebalance QUEUED to the first real-combat-content step** (bosses / zones / Slayer / death-risk /
  gear-gating — where combat gains its OWN internal back-pressure and the correct shape of the fix becomes determinable;
  fixing it now, with rats as the only target, risks over-tuning a transient). Fix = give combat saturation/back-pressure
  symmetric to gather (saturating combat-reward, or full-weight pit congestion + remove the base advantage). **Testable
  prediction to check there: when combat gains internal saturation, do the combat monoculture AND the social rival-lean
  resolve on their own?** (If yes → asymmetry confirmed in one stroke. The §18 first move is the deferred decision-level read.)

#### BRANCH DETERMINED 2026-06-09: STILL-RIVAL-LEANING → Stage-2 (kinship did NOT resolve it)
Kinship sweep (6 seeds, locked friction, vary REL_KINSHIP 0.0→1.1): **friend+ally stays ~7% vs rivals ~17% at
EVERY kinship value** (0.0: F6.1/A0/R17.1/N1.1 · 0.8: F5.7/A1.1/R17.3/N0.3 · 1.1: F5.4/A1.6/R16.8/N0.3). Kinship
did its own-merit job — deepened the strongest gather friendships (Friend→Ally 0→1.6%) and softened borderline
negatives (Nemesis 1.1→0.3%) — **but added NO net friends.** MECHANISM (confirmed): the 32% combat draw pulls
would-be-stable gatherers INTO the pit, where they accrue friction (−4.5) WITH EACH OTHER that swamps kinship
(+0.8); the same heroes that should befriend via shared trade are converted into pit-rivals. Location-independent
kinship can't beat a force that repeatedly co-locates them at the scarce node. **The rival-lean IS the 32% combat
residual, socially masked.** Per the planner's sequencing rule, NOT trimming friction (would mask the upstream
cause). **RECOMMENDATION: un-defer Stage 2** (combat trip-completion + weighted-random among near-ties) — it fixes
the social distribution AND tightens combat share in one move. **Kinship KEPT on its merit, locked at 0.8**
(REL_PROXIMITY 3.6 / REL_COOP 2.4 / REL_FRICTION 4.5 / REL_PROX_CAP 3.0 / REL_DECAY 0.97 / REL_KINSHIP 0.8). Step 5
is BUILT & green (92/92); the social distribution's final shape is gated on the Stage-2 decision. Holding for planner.

### Combat tuning — RESOLVED 2026-06-08
Telemetry now splits **deaths vs flees** (HANDOFF §8). The "913 deaths/flees" was **0 deaths, 913
flees** — purely a food-supply shortfall (`shop food min 0 / avg 18`): the town was eating 260
cooked_fish/day (a gather-only-era food *sink*) and starving the fighters. **Fix: town cooked_fish
consumption 260 → 60** (fighters are now the real food sink, §6). Result: **flees 913 → 38, kills
1,081 → 1,395, kills/food-trip 1.18 → 36.7**, economy still bounded (~6,400g, drift +15%). One lever,
no over-tuning. 28/28 green.

### Still open (combat-adjacent, queued)
- The statistical "am I winning?" pre-engage check (`Combat.fight_is_winnable`) is implemented +
  unit-tested but NOT wired into the live *engage* decision (reactive eat/flee used). No-op for rats
  (always winnable); wire it when tougher monsters/bosses go live so heroes decline unwinnable fights.
- Economy drift is +15% with combat (vs +2% gather-only) — bounded, from combat variance; fine for now.

## Verification status — VERIFIED 2026-06-08 (Godot 4.6.3 headless + windowed)
| Item | Status |
|---|---|
| GDScript parse-cleanliness | ✅ Compiles clean in Godot 4.6.3 (fixed 5 Variant-inference errors — see below) |
| Canon math (XP curve, combat) | ✅ Headless test 23/23: XP 99=13,034,431 · 92=6,517,253 · combat formulas assert |
| Data JSON parses | ✅ 11 items / 9 monsters / 11 map locations |
| Sim/render split | ✅ Headless test runs the sim core with no renderer |
| Render layer | ✅ Windowed run + screenshot: iso Varrock + 6 brain-driven heroes + HUD/Chronicle |
| **Gather-only economy** | ✅ **Bounded:** total gold day 12 = ~2,564 (6 heroes), steady-state drift +2%. Lower than the 8-hero-with-fighters ~5,300 as expected (no fighter food-sink); a *transient* — do not over-tune. |

### Fix log (2026-06-08, found by the first real Godot run)
GDScript 4.6 treats "type inferred from a Variant value" as an ERROR. Fixed 5 sites by using
`floorf()` / explicit type annotations / `int()`-wrap: `XpTables.combat_level` (×3 floor),
`SimWorld._narrate` (Dict.get), `Brain._score` (sell_price on untyped `world`). Also hardened
`tests/test_sim.gd` against false greens (asserts the expected check count actually ran).

### Open finding (queued, not a blocker)
**Offline catch-up over-yields:** `Activities.expected_yield_per_hour` uses the current sell price ×
full action rate, ignoring the shop-saturation / town-demand ceiling that bounds *live* earning — so
offline projects ~118k gold for one miner over 10h (unrealistic). Mechanism is correct (projects,
applies ×0.75, caps 24h); the *magnitude* needs the same saturation-awareness the live economy has.
Fix when we polish offline (build step 6) or alongside the economy re-center.

## The verification loop (runs on the USER's machine — Godot not available to the agent)
1. `cd game && godot --headless --script res://tests/test_sim.gd` — parse + logic + economy-bounded gate.
2. If pass: open in Godot 4.3+, F5 for the live view; let it run; press **E** to export a debug log.
3. Report back: headless test output (pass/fail + any parse errors w/ line numbers) + the first export log.

## Queued
- **Step 4 — Player layer** (§22.3): ✅ **DONE 2026-06-09** (78/78). Watch-numbers answered: Incentivize
  pulls labor multi-seed (15%→18% on target at the safe cap, ±1, distributions separate); Nudge returns
  cleanly to autonomy (one-off, verified); per-capita gold bounded as building/upkeep formalized (shop
  leveling scales faucet+sink together; building upkeep is a treasury sink). See the Step-4 section above.
- **Funded per-unit bounty = the INTENDED Tier-1 design (not a refinement); clamp is interim** (planner-ratified
  2026-06-09). Pays from treasury, clears via the market → steers labor without the overproduction crater, and
  makes the treasury load-bearing (§6 "central bank"). Build when Tier-1 is next touched. Do NOT tune
  INCENTIVE_STEP against the current unfunded model (transient). See the Step-4 section for the full rationale.
- **Step 5 — Story & society** (§22.3, NEXT): kick votes + the antagonistic social events (PvP-avoid /
  vote-bias / give-back — the negative-relationship sources that finally let Rivals/Nemeses form, resolving
  the 794-friends/0-rivals Phase-0 read) + the Chronicle viewer. The social graph + satisfaction + reputation
  scaffolding from Steps 3–4 is in place for it.
- **Stage-2 action-selection polish (DEFERRED — premise UNDERCUT by the 2026-06-09 probe; NOT a Step-5
  blocker):** the 32% residual combat over-concentration remains, but the probe (`tools/diag_lock_probe.gd`)
  showed **0% of those fighters are frozen** over a 2-day window — they DO reach decision points (via the
  food/flee/disengage exits), so Stage-2's stated cause ("unreachable kills-gated trip-completion → never
  re-decides") is empirically false at that horizon. The residual is a congestion-balanced equilibrium of
  normal-cadence heroes, AND the player's controls reach them (Nudge/Seize 100%; clamped bounty weakly,
  ≈natural churn). So the original Stage-2 fix (re-entrant/timer completion + weighted-random near-ties) is
  now **optional polish to tighten the combat equilibrium**, not a reachability fix — revisit only if the 32%
  proves to actually bother gameplay. Planner to ratify this re-framing. (Earlier "CRACKED = re-decision LOCK"
  note in the Step-3 section is superseded by the probe — see the Step-4 PROBE block.)
- **Food-supply / flee tuning** (see finding above) — wire the statistical engage check and/or
  rebalance the cook:fighter:town-demand ratio so fighters stay fed.
- **Offline-yield ceiling** — `expected_yield_per_hour` (gather AND fight) ignores the
  saturation/encounter ceiling that bounds live earning; cap it during the offline-polish pass (step 6).
- **Economy re-center** — with combat in, equilibrium is ~7,110g/6 heroes (drift +15%), bounded and
  near the original tune; no nudge needed yet. Revisit if it drifts as the colony scales.

## Key decisions on record
- **GDScript** (not C#) — HANDOFF §3 allows either; lighter, matches the JS prototype.
- **Seed content DB + ingest pipeline** — osrsreboxed (~23k items) NOT downloaded yet (deliberate);
  Phase 0 boots from a hand-authored canon seed; `tools/ingest_osrsreboxed.gd` writes the same schema
  and `ContentDB` auto-prefers `*.generated.json`. Pull + snapshot patch date when scaling content.
- **Gold is `float`** in the sim — required so the small per-action proportional upkeep accrues
  instead of rounding to 0 (a bug caught in review that would have silently re-inflated the economy).
- **Schemas are top-level `class_name` files** (Hero/ItemType/Monster) — avoids inner-class
  self-reference ambiguity.

## Tuned economy constants (validated; in `sim/Config.gd`)
`geTax 0.03 · upkeepRate 0.40 (wealth-proportional/day) · upkeepFlat 6 · ratDrop 6–16 ·
priceFloorFrac 0.12 · shop.consume {ore 350, logs 350, cooked_fish 60}/day`
(cooked_fish lowered 260→60 once live combat made fighters the food sink — see combat tuning above).
Result in prototype: +3,557%/6-day runaway → bounded ±~15%, "no anomalies".

**Step-4 control/town constants (validated; in `sim/Config.gd`):**
`INCENTIVE_STEP 12 · INCENTIVE_MAX 24 (clamp below the ~36 overproduction crater) · NUDGE_BONUS 1000 ·
SHOP_UPGRADE_BASE_COST 400 · SHOP_UPGRADE_COST_GROWTH 1.6 · SHOP_LEVEL_CAP 99 · SHOP_CAP_PER_LEVEL 0.15
(scales max AND consume together) · BUILDINGS {lodge 600g/8upkeep/+4rep/+6sat · monument 900/5/+14/+2 ·
tavern 500/7/+3/+5}`. Treasury fed by GE-tax skim (does not affect `total_gold()` or the attractor).

## Doc map (repo root)
`HANDOFF.md` (entry) → `GAME_DESIGN_DOC.md` (master, 26 §) → `EQUATIONS_AND_SCHEMAS.md` (formulas+schemas)
→ `ITEMS_MONSTERS_BALANCE.md` → `WORLD_AND_CHARACTERS.md` → `ASSET_PROMPT_PACK.md`; `prototype.html`
(validated behavioral reference). Build lives in `game/` (see `game/README.md`).
