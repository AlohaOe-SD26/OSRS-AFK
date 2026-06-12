# HANDOFF — Build Brief for Claude Code

**Read this first.** It tells you how to use the design docs, what to build in what order, the tech stack, and the rules you must not break. This is a **single-player desktop simulation game** (an idle/tycoon "ant farm" set in the canon Old School RuneScape world).

---

## 1. The one-paragraph pitch
You build and steer the canon city of **Varrock**; a procedurally generated cast of autonomous "players" (heroes) live there — training the OSRS skills, fighting canon monsters, banking, trading, leveling, forming friendships and feuds — entirely on their own, while the player **incentivizes, nudges, or seizes** control. The world is 100% canon OSRS; the *heroes and their emergent sagas* are generated. Endgame goal: grow strong enough to defeat **Zezima**, an ever-escalating final rival. There is a working proof-of-concept: open **`prototype.html`** in a browser to see the core loop running.

## 2. The documents (read in this order)
1. **`GAME_DESIGN_DOC.md`** — the master spec (26 sections). Start with the **TL;DR** and **Contents**, then read in order. The **🟡/✅/⬜ markers** tell you what's locked vs tunable vs deferred.
2. **`EQUATIONS_AND_SCHEMAS.md`** — every formula (XP, combat, AI utility function, economy, etc.) + the **data schemas** for Hero/Item/Monster/Town/Zone/Chronicle. This is your implementation math.
3. **`ITEMS_MONSTERS_BALANCE.md`** — gear ladders, the "highest-tier ≠ best" situational mechanics, the multi-region monster roster, God Wars, and the **item acquisition rules** (craftable vs drop-only vs hybrid).
4. **`WORLD_AND_CHARACTERS.md`** — Varrock NPC sheets, the city + region **map blueprints**, and the **sprite/asset-generation reference**.
5. **`ASSET_PROMPT_PACK.md`** — reusable image-gen prompts (style bible + per-category) for generating the 2.5D iso art. Item icons come from osrsreboxed; generate world/character/monster sprites + tiles.
6. **`prototype.html`** — a runnable Phase-0 slice; treat it as a *behavioral reference* for the brain/economy feel, **not** as architecture to copy (single-file throwaway). It has a **debug-log export** (see §8).

## 3. Tech stack (locked — GDD §21)
- **Engine:** Godot 4 (GDScript or C#), **desktop-first** (mobile/web export kept open).
- **Architecture (critical):** **separate the deterministic SIM CORE from RENDER/UI.** The sim must run headless. This is what makes offline catch-up, the level-of-detail trick, testability, and save/load all work.
- **Art:** pixel-art **2.5D isometric**, 8-direction sprites (see WORLD_AND_CHARACTERS §4).
- **OSRS data:** ingest the **osrsreboxed** dataset (~23k items + monsters + icons) at build → your local content DB; canon stats come from there, not from memory. Snapshot a target patch date.

## 4. Build order — start at Phase 0 (GDD §22.3)
0. **Foundations:** data ingest (osrsreboxed → content DB), Varrock map render, one hero standing in town. Sim/render split from line one.
1. **One skill loop:** brain + a gathering trip (mine → sell), using the dual-resolvable activity model.
2. **Combat:** tick combat (canon formulas) + local monsters + death/respawn + the statistical "am I winning?" check.
3. **Economy & population:** NPC shops (buy/sell w/ dynamic prices + sinks), multiple heroes, immigration; basic relationship graph.
4. **Player layer:** the three control tiers (incentivize/nudge/seize) + town building/upgrades (bank, shops) + the **Hero Panel** (stats/thoughts/gear).
5. **Story & society:** kick votes + social effects + the Chronicle.
6. **Polish/scale:** push toward 50 heroes, LOD, offline catch-up, save/load.
*The MVP target is "A Living Varrock" (GDD §22.1). Everything endgame (teleport zones, Slayer, raids, GE, top-tier gear, Zezima) is post-MVP but already designed.*

## 5. Invariants — do NOT break these
- **Dual-agency:** every economic/RPG verb is both a player action AND an autonomous AI behavior on the *same* systems.
- **Dual-resolvability:** every activity needs a live (tick) path AND a statistical (expected-yield) path — required for offline catch-up & LOD.
- **Canon from dataset:** item/monster *stats* come from the dataset; our *additions* (quality tiers, AI, social, economy) wrap them. Lore & item identity stay 100% canon; only stat *values* (procedural quality rolls) deliberately diverge — documented in GDD §3/§11.
- **Local perception:** heroes act only on what they've perceived/know — no global omniscience (drives the gravestone/vulture logic, §14/§18).
- **Situational mechanics:** "highest tier ≠ always best" — implement Salve-vs-undead (overrides Slayer helm), on-task bonuses, Berserker+obsidian, etc. as conditional multipliers (ITEMS_MONSTERS_BALANCE §1.1).
- **Live-only risk:** deaths/PvP/boss-loss happen only in active play; offline is safe accrual (24h cap, ×0.75, rares ×0.5).
- **No-quest gating (interim):** quests are deferred; quest-locked content uses level+item+kill gates until quests exist (§3).

## 6. Validated by the prototype (GDD §23)
The utility brain reads as believable (trip-commitment prevents thrashing), congestion self-spreads labor, the Fisher→Cook→Warrior economy creates real division of labor, and the Hero-Panel "thoughts" are the legibility win. **Known open tuning:** economy gold isn't sink-balanced yet — wire the §6 sinks and tune to a stable total-gold curve.

## 7. Status snapshot
- **Locked (✅):** vision, control model, canon rules, time/offline model, the full loop (incl. reincarnation + Zezima win condition), combat math, item acquisition, God Wars, tech stack, MVP slice, save/load schema, prototype learnings.
- **Tunable (🟡):** exact balance constants (all named `CONFIG.*` in EQUATIONS_AND_SCHEMAS) — tune via playtest; exact dataset values — pull at build.
- **Deferred (⬜):** quests as content; exact resource-node placement around Varrock; Nex/Ancient-godsword wing; audio.

## 8. Debug logging & telemetry (build this in)
The prototype emits a copy-paste **debug log** (the "Export Debug Log" button) — the real build should emit the **same kind of telemetry** so issues can be diagnosed remotely. Implement a debug overlay + a "save session log to file" action that captures:

- **Startup:** build/version, CONFIG snapshot, dataset patch-date/version, hero count, seed.
- **Periodic snapshot (every sim period):** sim day/tick, population, **total gold**, key prices (ore/food) + shop stock, **activity histogram** (how many heroes mining/fishing/fighting/idle), avg combat level, kills, deaths.
- **Events:** level-ups, deaths/flees, kicks, exiles, Zezima attempts, **errors/exceptions with stack traces**.
- **Performance:** tick duration, FPS, agent count (flag if a tick exceeds budget at 50 heroes).
- **Auto-flagged anomalies** (like the prototype): gold inflating/starving, heroes broke+foodless, AI thrashing (too many activity switches/period), stuck/idle heroes.

Format: human-readable lines or JSON-lines, written to a log file the player can attach. Gate verbose logging behind a `--debug` flag / in-game toggle. **Goal:** the player can run the build, hit "export log," and send it back for tuning — exactly like the prototype.

## 9. The package — what to send / run
**Send all of these to Claude Code (read in order):**
`HANDOFF.md` (this file) → `GAME_DESIGN_DOC.md` → `EQUATIONS_AND_SCHEMAS.md` → `ITEMS_MONSTERS_BALANCE.md` → `WORLD_AND_CHARACTERS.md` → `ASSET_PROMPT_PACK.md`, plus `prototype.html` as a behavioral reference.

**To test & report back (loop):**
1. Run `prototype.html` in a browser (or, once built, the Godot Phase-0 build).
2. Let it run, watch the brain/economy; click heroes to read their "thoughts."
3. Hit **⤓ Export Debug Log** → **Copy** → paste it back here. That telemetry (esp. the gold trend + anomalies) is what I use to tune the economy/AI and plan the next step.

---
*Entry point for the Gielinor Tycoon documentation set. Last updated: this session.*
