# Economy & Incentive Systems — Discussion Prompt (NOT an implementation order)

## How to treat this prompt

This is an **ideas-and-discovery prompt**, not a work order. You have an existing punch list and process — **keep following it**. The game is a **work in progress** — partial, in-flux, or half-implemented systems are completely expected, and an honest "this is half-built / stubbed / not started" is far more useful than a polished description of intended behavior. The goal of this exchange is to land the improvements below **without disrupting what already works** — your current UI, systems, progress, and goals stay intact except where these ideas genuinely improve or extend them, and even then they must be made to *fit* the game as it stands. In particular, the **existing side-panel system (Roster, Menu, etc.) is working well and must be retained** — nothing below is a request to restructure it.

Your probe report (Part A) will be relayed to an external design partner who does **not** have access to this codebase — so err heavily on the side of over-explaining. Your job right now is to:

1. **Probe the current build** and report back how the relevant systems work today (Part A).
2. **Read the mechanics below** — they come from a separate working reference build of this same game concept, plus design intent borrowed from **Evil Hunter Tycoon (EHT)** with custom tweaks. Evaluate what fits, what conflicts, and what you'd do differently (Parts B & C).
3. **Propose where these additions slot into your punch list** — wherever they logically fit. Nothing here needs to happen immediately. Do not derail in-flight work.
4. **Come back with a probe report + your questions** before writing any code for these features (Part D).

**Hard rules for this exchange:** the probe is **strictly read-only** — no refactors, cleanups, or "drive-by fixes" while exploring, no matter how tempting; do not modify **any existing files — code or documentation** — as part of responding to this prompt. **The only permitted writes**: (1) create a new folder named `ANALYSIS REPORT` in the project root and write your report and file *copies* into it, per Part D — copies only, never move, edit, or delete originals; (2) create and seed the `PROJECT KNOWLEDGE` folder per Part E. Begin your reply by **restating these constraints in your own words** (read-only probe except the ANALYSIS REPORT and PROJECT KNOWLEDGE folders, punch list preserved, side panels retained, no implementation yet) so we're aligned before the report.

EHT context, in case it isn't in your knowledge: it's a mobile idle/tycoon game where autonomous hunters fight, gather, and trade while the player runs the town. Two of its systems matter here: (a) the **town buy-order board** — the player posts "town wants to buy N of item X at price Y," hunters sell into it, the town pays, and the items land in a **town inventory** that fuels building upgrades and crafting; and (b) **facility upgrades that cost items, not just gold**. We're adapting both, with OSRS-flavored tweaks described below.

---

## Part A — Probe the current build and report (be exhaustive)

This report travels to a design partner working blind — **more detail is always better**. Two accuracy rules: (1) tag every system and sub-feature you describe with its real status — **✅ implemented / 🚧 partial (what works, what doesn't) / 📋 planned / ❌ absent** — the game is WIP and honest status beats polish; (2) **verify against the source, not memory** — you've been working on this codebase a long time, and mental models drift; for anything load-bearing (formulas, constants, control flow), read the actual code before describing it. Inspect the current codebase and write up, with file/function references throughout:

0. **Architecture overview** — File/module structure, simulation model (tick rate, determinism, RNG handling), state shape, sim/render separation, **in-game time model** (how long is a day in ticks/real time — several specs below are denominated in in-game days), save format **and how save-schema changes/migrations are handled**, how work is **checkpointed/versioned** (git? manual copies?), any **performance budgets or scale targets** (hero-count goals, tick-time limits — relevant to order-book matching costs), and how/where verification or testing happens — what does "done" mean for a change, i.e., what gates must it pass. A short "how this program works end-to-end" narrative.
1. **Project intent & documentation state** — (a) Restate the game's vision and goals **in your own words** — what is this game, what's the core loop, what's the endgame — so we can confirm shared understanding. (b) Inventory the design documents you have: filenames, which ones you actively work from, and **whether any have been updated, extended, or superseded since the project began**. Known starting point (already verified by the design partner): the six core design docs in the repo root are unmodified from the originals; `prototype.html` carries the validated Step-1 economy tune; `PROJECT_STATUS.md` is **known to be stale** (it predates the Step-3 handoff and the later gate-fix sweep) — reconcile repo-root docs against actual progress, state where the **real, current punch list lives** (no punch-list file was found in the root), and report anything newer than `STEP3_HANDOFF.md` / `sweep_out.txt`. (c) List any status/progress/handoff documents you maintain beyond the punch list. (d) Summarize any **standing directives, constraints, or conventions you're operating under from prior prompts** (your instructions came from the original docs plus prompts from another AI agent) that a design partner should know about before proposing changes — especially anything that might conflict with the ideas below.
2. **Shops** — How do shops currently work? Stock model, pricing (static or dynamic?), restocking, what heroes can buy/sell, any player controls (price levers, investment), and how shop gold interacts with the economy (faucet/sink accounting).
3. **Grand Exchange / hero-to-hero trading** — Does one exist? If so: offer model, matching logic, who can post what, tax/sink behavior, expiry handling.
4. **Slayer & incentives** — Task assignment logic (who gives tasks, eligibility/feasibility checks, task sizing), how monsters enter the assignable pool, any on-task reward bonuses, and any player-facing incentive levers (bounties, price biases) and how they're paid for.
5. **Hero brain & commands** — How heroes decide what to do (utility scoring? state machine? priorities?), and the full nudge/command surface: what per-hero commands exist, how they're parameterized (if at all), and how a command interacts with autonomy (one-shot override? standing directive? how does the brain resume control?).
6. **UI layer inventory** — The full current UI map: the **side-panel system (Roster, Menu, and any others — these are being kept)**, the top HUD contents, per-hero popups/panels, modals, and how each is wired to game state. Note anything fragile or mid-refactor.
7. **Economy invariants & telemetry** — Any existing telemetry on gold drift, faucet/sink balance, item flows, or anti-hoarding behavior, and any test gates that protect them — **including a quantitative snapshot if available** (typical hero gold, treasury size, drift rates from a recent test run) so price/limit proposals can be scaled correctly. We care a lot about not destabilizing this.
8. **Buildings, treasury & storage plumbing** — Current building/upgrade system and its cost model; how the town treasury earns and spends; any **existing crafting/production systems** (hero-side or shop-side) and their recipe data shapes; and the **hero inventory/bank model** (slots, stacking, caps) — the anti-hoarding features below need to know how hoarding actually works here.
9. **Content catalogs** — Summarize the item catalog (rough count, **base-value scale and range**, tradeable/untradeable flags, equipment vs. materials vs. consumables) and the monster roster (drop-table shape, any boss/elite flags). New features below (city buy orders, item-cost upgrades, shop crafting) hinge on these.
10. **Punch list — in full** — Paste your current punch list **verbatim**, with per-item status (done / in-flight / queued), and briefly explain the reasoning behind its current ordering and what you're actively working on right now. You've been driving this list for a long time and know the codebase's real sequencing constraints better than anyone — we want to understand your plan well enough to fit these ideas *into* it, not to rewrite it.
11. **Known issues in the probed systems** — Any known bugs, instabilities, or "works but fragile" areas in shops, trading, economy, hero brain, or UI. New systems shouldn't be stacked on shaky foundations without everyone knowing — if a foundation needs fixing first, say so and it becomes a sequencing input.
12. **Anything else** a designer would need to know to propose changes that fit cleanly — known debt, conventions, planned refactors, naming/NPC differences from descriptions below, etc.

Report findings before proposing changes. If any of these systems don't exist yet, say so plainly.

---

## Part B — Reference-build mechanics that worked well (evaluate for adoption)

A separate working prototype of this game implemented the following. These are known-good behaviors validated under headless simulation testing (stable gold drift, no degenerate loops). Weigh them against what you found in Part A — adopt, adapt, or argue for something better.

**Translate, don't transplant**: all constants, prices, and rates below are scaled to the *reference build's* economy and clock — treat them as **ratios and design intent**, not literals; re-derive equivalents for your build's value scale and day length. Likewise, NPC/location names (e.g., "Vannaka") map to whatever your build's equivalents are.

**Your validated economy attractor is locked.** The wealth-proportional upkeep / town-consumption / GE-tax / saturation-aware-pricing model you tuned to bounded equilibrium is settled ground — everything below **integrates around it**, never re-derives it. If any proposal here appears to conflict with the attractor, flag the conflict in your fit assessment rather than adjusting the attractor.

### B1. Shop system

- **Dynamic buy prices** (hero buying from shop): `price = base_value × clamp(1 + 0.6 × (1 − stock/maxStock), floor 0.4, ceil 1.3) × playerPriceBias`. Scarcity raises prices, glut lowers them, and the player has a per-item price-bias slider (50%–150%) acting as a central-bank lever.
- **Dynamic sell prices** (hero selling to shop): margin starts near ~0.55–0.75 of base value and **falls toward a 0.15 floor as the shop's stock of that item fills** — diminishing returns on dumping.
- **Saturation refusal**: once a shop's stock of an item hits max+small buffer, it **refuses to buy more**. This is the anti-farming negative-feedback loop — when one good saturates, the income stream dries up and heroes autonomously redistribute their labor. Validated to work: a hunter whose fur market saturated pivoted to other skills with no scripting.
- **Townsfolk consumption drain**: each restock tick, surplus stock above the shop's baseline has a small chance (~8% + 0.2%/shop level) to decrement — off-screen townsfolk "buy" it, so saturation isn't permanent. Items are destroyed (item sink), no gold moves.
- **Restock toward baseline**: under-stocked baseline items refill probabilistically each tick, faster with shop level.
- **Shop investment**: player spends treasury to level shops (cost `150 × 1.18^level`, to 99). Levels: faster restock, larger stock caps, and **tier-up unlocks** — e.g., at level ≥10 the sword shop occasionally stocks adamant scimitars; at ≥25, rune. Gives the player a long gold sink that visibly improves the gear ladder.
- **Gold accounting**: hero purchases route 50% of the price to the town treasury and burn 50% (sink); shop sell payouts are minted gold (faucet). These ratios were load-bearing for drift stability — flag if your economy accounts differently.

### B2. Slayer & incentive system

- **Vannaka task assignment** with two gates: (1) monster's slayer-level requirement ≤ hero's slayer level, and (2) a **provisioned feasibility check** — Vannaka never assigns a task the hero can't plausibly survive with a banked-food loadout (DPS-vs-DPS survival math, prayer-aware). This single check eliminated a mass-death loop in testing (688 deaths from one over-tuned monster dropped to 35).
- **Task sizing scales inversely with monster toughness**: bosses 3–8 kills; HP ≥ 80 → 8–20; HP ≥ 40 → 14–35; small mobs 20–60.
- **On-task is the best grind by design**: being on-task adds a large flat utility bonus (+26 in that build's scoring scale) to fighting the task monster, plus bonus slayer XP per kill (~0.9 × monster HP) and 8–16 slayer points on completion. Heroes genuinely prioritize tasks without being forced.
- **Knowledge-gated pool**: monsters only become assignable after the **colony** has killed 100 of them (15 for bosses) — the town "learns" content. The player can curate the pool (enable/disable unlocked monsters) from the Incentives menu.
- **Partnering**: when a task is assigned, up to 2 heroes at Friend+ relationship tier who also pass the feasibility check may join, sharing the kill counter and gaining mutual relationship points.
- **Bounties**: player sets a per-monster gold bounty (0–100g) paid **from the treasury per kill** — only paid if the treasury can afford it. Bounty value also feeds into the hero brain's fight-scoring (greed-weighted), so bounties genuinely steer behavior.

### B3. Top HUD layout (adopt the arrangement — **top bar only**)

Single bar: **game title + subtitle** | **Day N · HH:MM clock** | **speed buttons (⏸ / 1× / 3× / 8×)** | **live counters: Treasury, Reputation, Hero count (n/cap), Zezima-slain count** | spacer | **action buttons: ⚒ Build, ⚖ Incentives, 💾 Save/Load, ⚙ Settings, Debug log export**.

This concerns the **top bar arrangement only**. Your existing side-panel system (Roster, Menu, etc.) stays as-is — fit the new menus/popups from Part C into your current UI conventions rather than restructuring around them.

### B4. Current nudge layout (baseline that Part C extends)

Per-hero panel has a "Nudge (one-off)" section: buttons for Train favorite / Fight <best feasible target> / Get Slayer task / Go bank / Rest, plus gated endgame attempts — each button **disabled with a tooltip explaining the unmet requirement** when infeasible (e.g., "Gate: Combat 70"). A nudge is a one-shot override: the hero complies, then their autonomous brain resumes. Keep that contract.

---

## Part C — New features to design around (discuss before building)

These extend the above. For each: assess fit with your architecture, surface conflicts (especially economy-drift and anti-hoarding behavior), and propose punch-list placement.

**All new systems remain subject to the HANDOFF §5 invariants** — in particular **dual-agency** (every new verb is both a player action and an autonomous behavior on the same systems) and **dual-resolvability** (every new activity — GE order trading, selling to city buy orders, shop crafting — needs both a live tick path and a statistical expected-yield path, or it breaks offline catch-up and LOD). Call out in your fit assessment how each feature satisfies both.

### C1. Parameterized nudge popups

Replace the flat nudge buttons with two structured commands, while preserving the "hero remains autonomous" contract:

- **"Fight" popup**: choose **Random monster** or **Specific monster** (dropdown of the currently available/unlocked roster). Shared parameters regardless of mode: **duration or kill-count as min/max ranges** (the hero rolls within the range to decide how long/many — preserving agency), and **looting settings** (e.g., loot everything / valuables only / ignore loot) governing behavior during the trip.
- **"Skill" popup**: choose a skill; choose **random or specific training location** from valid spots; same min/max duration/quantity ranges; and a **suggested-items list** the player builds (e.g., "prefer yew logs, magic logs"). Critically: suggestions are **influence, not commands** — they bias the hero's gather-target scoring, but the hero may still choose other targets per its own utility logic.

### C2. OSRS-style GE order book + City BUY orders (the EHT adaptation)

- The GE becomes a true **buy/sell order queue** in the OSRS style: heroes post buy offers and sell offers with prices and quantities; matching crosses compatible orders; partial fills allowed; unfilled orders expire and refund/return. Research OSRS GE mechanics for the matching model (price-priority crossing; buyer pays their offer or better).
- **The City participates as a buyer ONLY.** The player sets buy limits per item (e.g., "buy up to 100 Logs") — the city posts standing BUY orders, behaving exactly like a hero's buy order in the queue. Any hero can fill it, in any chunk sizes, until the limit is met.
- **Settlement**: city purchases are paid from the **Treasury**; purchased items land in the new **City Inventory** (C3). This is the anti-hoarding incentive — heroes get a reliable buyer for surplus instead of stuffing banks.
- **Economy note for your analysis**: city buys are treasury→hero transfers (circulation, not minting), so this should be drift-neutral on gold but creates an item flow into city stock. Confirm against your faucet/sink accounting and the GE tax (the reference build taxed 1% on GE trades as a sink — keep or propose otherwise).

### C3. City Inventory + item-cost upgrades

- New persistent **City Inventory** (EHT-style), filled **only** by city GE purchases (and possibly future sources you propose).
- **Building/shop upgrades evolve from gold-only to gold + items**: higher tiers require more, rarer, or higher-tier materials that **logically fit the building** (smithy annex wants bars/ore; archery range wants logs/feathers; etc.). Propose a coherent cost ladder rather than arbitrary lists.

### C4. Shop sell-back rules (OSRS-flavored, deliberately worse than GE)

- **General Store**: accepts **any** sellable item, paying **~70% below** what the hero would expect on the GE. Items go to the General Store's own stock (resellable), **not** city inventory.
- **Specialty shops** (armour, archery, etc.): accept **only items they themselves carry** (OSRS rule), same ~70%-reduced price, and the sold items **restock that shop's inventory** — not city inventory.
- Intent: shops are the convenient-but-bad option; the GE (and especially city buy orders) should clearly win on price, pulling trade volume there. Check this interacts sanely with the reference build's saturation-refusal and dynamic sell-price mechanics — you may be reconciling two pricing models; propose the merge.

### C5. Shop crafting + slow imports

- **Slow ambient restock ("imports")**: shops trickle-restock their own catalog at roughly **1–3 units per 3 in-game days**, so stock never fully stagnates even with no other activity.
- **Crafting in shop menus**: each specialty shop can **craft its own catalog items from City Inventory materials** (Horvik: ores/bars → weapons/armour; Lowe: logs/feathers → bows/arrows; etc.). Crafted goods enter that shop's stock for heroes to buy.
- **Queueing**: the player can queue craft orders **even when materials are missing** — the queue waits and auto-executes as materials arrive in city inventory. Propose the UI and the consumption/priority rules (e.g., does the queue reserve materials? FIFO across shops?).

---

## Part D — What to send back

**Delivery format — write to disk, not just chat.** Chat output gets truncated; files don't. Create a folder named **`ANALYSIS REPORT`** in the project root containing:

- **`ANALYSIS_REPORT.md`** — the full report (everything below). Write it at whatever length completeness demands; this file is the deliverable of record and will be reviewed externally, so do not compress for chat's sake.
- **Copies of supporting files** so the report can be verified against ground truth — at minimum: your punch list (if it lives in a file), every design/status/handoff document that is **new or changed** since the original document set, and the **source files for the probed systems** (shops, trading/GE, economy, hero brain, the relevant UI). If the codebase is small enough, copying it in its entirety is welcome. **Copies only** — originals stay untouched.
- A **manifest section** at the top of `ANALYSIS_REPORT.md` listing every file in the folder and one line on why it's included.

Your **chat reply** should then be short: the constraints restatement (per the hard rules), a brief summary of headline findings, a pointer to the folder, and your Part D questions echoed inline (questions go in **both** the file and chat so nothing is lost either way).

The report itself must contain:

1. **Probe report** (all of Part A, with file/function references — exhaustive; it will be read by someone without code access). Where systems have tuned numbers, **quote the actual constants and formulas verbatim** so they can be compared apples-to-apples with the reference values in Part B.
2. **Fit assessment** — for each item in B and C: adopt as-is / adapt (how) / conflicts with current architecture (why) / better alternative (what). Be opinionated; flag anything that threatens economy stability, determinism, the existing UI (which we're keeping), or your existing test gates. The standard for every item is *fits the game as it stands* — improvements and new additions are welcome, but they must land cleanly, with the expectation they'll be further iterated per the punch list and the game's overall goals.
3. **Punch-list integration proposal** — where each piece slots into your existing list, what it depends on, and rough sequencing, with brief reasoning per placement. To be explicit about the division of labor: **sequencing is yours** — you've been deep in this codebase long enough that you have the best judgment on where things fit, and we will weigh in on placement but not override it arbitrarily; **design intent is ours** — the rulings you'll receive concern *what* the features should do, not *when* you build them. Nothing here preempts in-flight work.
4. **Questions** — anything ambiguous, underspecified, or where you need a design ruling before estimating.

Do **not** start implementing these systems yet, and make **no code changes** while producing this report. Discussion first — your report and questions will be reviewed, and you'll receive design rulings before any of this becomes work items.

---

## Part E — Standing practice from now on: the `PROJECT KNOWLEDGE` folder

Separate from the one-time `ANALYSIS REPORT`, create a persistent folder named **`PROJECT KNOWLEDGE`** in the project root and **maintain it from now on** as part of your normal workflow. Its purpose: any new AI agent (or external design partner) should be able to read this folder alone and come up to speed on the entire program — intent, design, architecture, status, history — well enough to collaborate immediately. Treat it as the project's onboarding path and institutional memory.

**Structure** (adapt names if you have a better convention, but keep the coverage):

- `00_README.md` — what this folder is, reading order, and a 1-paragraph project summary.
- `01_VISION_AND_DESIGN.md` — the game's intent, core loop, design pillars, and endgame, plus pointers to the authoritative design docs (summarize and link; don't duplicate them — but DO record where current direction deviates from the original docs and why).
- `02_ARCHITECTURE.md` — how the program works end-to-end: modules, sim model, time model, state/save shapes, key data structures, test gates.
- `03_PUNCH_LIST.md` — the live punch list with per-item status (or a pointer if it already lives elsewhere; one source of truth, no forks).
- `04_DECISIONS_LOG.md` — append-only: greenlit decisions and design rulings, dated, with one-line rationale each.
- `05_KNOWN_ISSUES.md` — current bugs, fragile areas, and notable past corrections with their root causes.
- `06_CHANGELOG.md` — append-only: notable changes per work session.

**Maintenance rules:** update the relevant files as part of your **definition of done** for each work item — a change isn't finished until the knowledge folder reflects it. Files `01`–`03` and `05` are kept **current** (edit in place; stale info is worse than missing info); `04` and `06` are **append-only** history. Verify against source when updating — same rule as the probe. Keep it clean and organized; this folder is judged by whether a stranger could onboard from it.

**Bootstrap now:** seed the folder as part of this exchange — most of its initial content falls straight out of your ANALYSIS_REPORT work (vision restatement → 01, architecture probe → 02, punch list → 03, known issues → 05). Note its creation in your chat reply.

---

## Appendix — One-time environment check (include as the final section of ANALYSIS_REPORT.md)

Unrelated to game design: report the following facts about the environment this session runs in, so remote-access setup can be configured correctly on this machine (read-only commands are fine; change nothing):

1. Output of `claude --version`.
2. Whether this session is running inside the **Claude Desktop app** or a **standalone terminal** (PowerShell/etc.), as best you can determine.
3. Whether `%USERPROFILE%\.claude.json` exists and, if readable, the value of its `remoteControlAtStartup` key (just that key — do not dump the whole file, it may contain account data).
4. Operating system and shell.
5. Whether a `.git` repository is initialized in the project root.
