# Vision & Design — osrs_afk (Gielinor Tycoon)
> Current-state file: edit in place. Source of truth for INTENT.

## One-liner
A single-player desktop idle/tycoon "ant farm" for canon OSRS: autonomous
procgen heroes live full adventurer lives in Varrock while the player
incentivizes, nudges, or seizes — endgame: defeat the escalating rival Zezima.

## Problem & purpose
A Dwarf-Fortress-style emergent-story machine wearing OSRS's skin. The fun is
*watching and steering*, not piloting: heroes are legible (the Thoughts tab
shows the exact utility math behind every decision), the colony writes its own
Chronicle (alliances, feuds, exiles, milestones), and the player's levers are
indirect by design.

## Goals
- A believable autonomous colony (division of labor, social web, sagas) with
  no scripting — emergent from the utility brain + economy back-pressure.
- A bounded, legible economy the player can steer but cannot crater
  (clamped/gated levers, sweep-validated).
- Full determinism: seeded RNG, byte-identical save/load, offline catch-up
  that cannot overshoot live play.

## Non-goals (explicitly out of scope)
- Quests as content (deferred; level+item+kill gates stand in).
- Multiplayer; mobile-first (desktop-first, exports kept open).
- Piloting heroes as the primary mode (Seize is a tier, not the game).

## Whole-program intent — design pillars (locked, HANDOFF §5)
- **Dual-agency:** every economic/RPG verb is BOTH a player action AND an
  autonomous AI behavior on the same systems.
- **Dual-resolvability:** every activity has a live tick path AND a
  statistical expected-yield path (offline catch-up + LOD depend on it).
- **Canon from dataset** (osrsreboxed); our systems wrap canon stats.
- **Local perception:** heroes act only on what they know.
- **Live-only risk:** deaths only in active play; offline = safe accrual
  (×0.75, 24h cap, rares ×0.5).
- **Back-pressure doctrine (earned across 7 banked bug instances):** every
  dynamic needs a counter-force; any force without one becomes the attractor
  as everything else saturates. New faucets ship with negative feedback
  built in (e.g. smithing shipped glut-gated).

## Components & their individual intent
### Sim core (`game/sim/`)
- **Purpose:** the entire deterministic game state + rules; headless-runnable.
- **Must not:** touch rendering, use unseeded RNG, ship a flow without its
  counter-flow.
### Economy/shops (`Economy.gd`, `Shop.gd`)
- **Purpose:** the validated bounded-equilibrium market — saturation pricing,
  capacity-respecting sales, town-consumption sink, wealth-proportional
  upkeep attractor, 3% sale tax → treasury. **The attractor is settled
  ground: integrate around it, never re-derive it.**
### Brain (`Brain.gd`) + goal system
- **Purpose:** legible utility scoring (score == sum of named terms, always
  inspectable); favorite/reward/congestion/risk/sticky/incentive/goal terms.
### Player layer (control tiers, treasury, buildings — `SimWorld.gd`)
- **Purpose:** indirect steering on the same systems heroes use (dual-agency):
  Tier-1 incentives, Tier-2 one-shot nudges, Tier-3 seize.
### Social / Population / Chronicle (`Social.gd`, `Population.gd`)
- **Purpose:** the story substrate — sparse signed relationship graph,
  reputation-driven immigration, curated notability-filtered event log.
### Render/UI (`game/render/Main.gd`)
- **Purpose:** the ONLY drawing code; reads sim read-only; LOD render-only.

## Endgame (designed, post-MVP)
Defeat **Zezima**; reincarnation/prestige beneath it.

## Authoritative design docs (repo root — unmodified originals)
`HANDOFF.md` → `GAME_DESIGN_DOC.md` (master, 26 §) →
`EQUATIONS_AND_SCHEMAS.md` → `ITEMS_MONSTERS_BALANCE.md` →
`WORLD_AND_CHARACTERS.md` → `ASSET_PROMPT_PACK.md`; `prototype.html` =
behavioral reference carrying the validated Step-1 economy tune.

## Where current direction deviates from the originals (and why)
- **Merge plan (decided 2026-06-09):** a second concept prototype supplied
  the desired look/UX, a richer brain (§18 rebalance = `BRAIN_V2`, built,
  default-off pending activity breadth), and content tables as the post-MVP
  roadmap. Order: M1 visual/UX (✅ done) → M2 brain v2 (measured, deferred)
  → M3+ content waves (in progress).
- **Interim social negatives:** canon sources (PvP/death-loot) don't exist
  yet; scarcity-gated competition-friction bridges until content wave (e),
  then retires.
- **Tier-1 incentives (combat half DONE 2026-06-12, R5):** combat steering
  is now the funded per-kill bounty — one player-set number (0–3× the
  monster's avg coin drop) that is BOTH the treasury-paid reward and,
  through the greed-weighted reward term, the attraction; an empty treasury
  attracts nobody. The unfunded utility FIGHT bounty is retired. GATHER
  incentives remain utility-clamped (+24) until Unit 4 migrates them to
  funded buy orders / price bias (R5 end state).
- **Living danger (#1d, 2026-06-12):** aggressive monsters harass
  non-fighting heroes — by design an ARRIVAL TAX, not sustained DPS. Three
  canon mechanics keep deaths rare-but-real (the gravestone/grudge channel
  fires occasionally, not constantly): passive regen (1 HP/min), aggression
  tolerance (settled heroes are ignored after ~8s), lair-bound bosses
  (Scurrius punishes trespassers only, unlocked at 300 colony rat kills).
  The brain prices workplace danger (frailty-scaled term) — every force has
  its counter-force.
- **Economy & incentive feature set under design review (2026-06-11):** GE
  order book + city buy orders, city inventory + item-cost upgrades, shop
  sell-back rules, shop crafting + imports, parameterized nudge popups — see
  `ANALYSIS REPORT/ANALYSIS_REPORT.md` (probe + fit assessment + questions).
  Awaiting external design rulings before any build.

## Design principles & style
Pixel-art 2.5D isometric, 8-direction sprites (item icons from osrsreboxed;
world/character sprites generated per ASSET_PROMPT_PACK). UI: side panels
(Roster left, TOWN LEDGER overlay) + bottom hero-popup drawer — new features
fit these conventions rather than restructuring them. Legibility beats
realism: every hero decision must be explainable from on-screen numbers.
