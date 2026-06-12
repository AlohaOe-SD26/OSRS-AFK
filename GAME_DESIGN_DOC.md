# Gielinor Tycoon (working title) — Game Design Document
> **Living design doc.** Working draft, built collaboratively for handoff to Claude Code.
> **Thesis: an "ant farm" for Old School RuneScape** — you don't *play* RuneScape, you watch a colony of procedurally generated "players" live their RuneScape lives in a canon-accurate world you build and steer.

---

## TL;DR

**Gielinor Tycoon (working title)** is a desktop (Godot 4) pixel-art **hero-town simulator — an "ant farm" for Old School RuneScape.** You build and steer the canon city of **Varrock**; a procedurally generated cast of autonomous "players" (heroes) live there — training the OSRS skills, fighting canon monsters, banking, trading, leveling, forming friendships and feuds — entirely on their own, while you **incentivize, nudge, or seize** control at will. The *world* is 100% canon OSRS; the *heroes and their emergent sagas* are what's generated. Plays as an idle/AFK sim or a hands-on tycoon. **Endgame goal:** grow the colony strong enough to defeat **Zezima** — an escalating final rival who reincarnates stronger each time he's beaten.

- **Core principle — Dual-agency:** every verb (buy, sell, train, fight, equip, loot) is both a player action and an autonomous AI behavior on the same shared systems.
- **Control — three tiers:** Incentivize (prices/bounties/stock/presets) → Nudge (tap a hero) → Seize (direct control).
- **Time:** hybrid — live 0.6s-tick sim while open; statistical catch-up offline (24h cap, 75% rate).
- **First build (MVP, §22):** *"A Living Varrock"* — ~10–20 heroes gather → craft → fight (up to Scurrius) → bank → trade → level in Varrock + surroundings, with death/respawn, a relationship graph + kick votes, town building, the three control tiers, a clickable hero panel, and a Chronicle logging the emergent story.
- **Tech:** Godot 4 desktop; OSRS content from **osrsreboxed** (~23k items + monsters + icons); simulation core separated from rendering.

---

## Contents

**Part I — Foundations**
1. Vision & Pillars · 2. Player Role & Control Model · 3. OSRS Theming & Canon Rules · 4. Time & Simulation Model · 5. Core Gameplay Loop & Progression · 6. Economy & Gold Balance

**Part II — The World**
7. Starting Region — Varrock & Surroundings · 8. World Structure & Travel

**Part III — Heroes & Their Systems**
9. Skills System · 10. Combat Resolution · 11. Items & Loot · 12. Gear & Equipment Roster · 13. Inventory, Equipment, Banking & Presets · 14. Death, Gravestones & Looting · 15. Slayer & Tasks · 16. Population & Social Systems · 17. The Chronicle · 18. Hero AI — The "Brain"

**Part IV — Player Layer, Tech & Build**
19. Town & Facilities · 20. UI — Hero Inspection & Command Panel · 21. Tech & Data Foundations · 22. MVP Slice & Build Order · 23. Prototype Learnings · 24. Onboarding & First-Time Experience · 25. Save / Load & Persistence

**Appendix:** 26. IP / Legal Note · Roadmap & Status

---

## 0. How to Read This

| Marker | Meaning |
|---|---|
| ✅ | **Locked** | 🟡 **In discussion** | ⬜ **Not yet discussed** |

---

## 1. Vision & Pillars ✅

**Pitch:** A pixel-art hero-town simulator set in the *canon OSRS world*, where a generated cast of adventurers (the "players") train, quest, fight, and trade inside a town you build — playable hands-off (idle sim) or hands-on (tycoon).

| Reference | Contribution |
|---|---|
| **Old School RuneScape** | The authored world: map, cities, NPCs, shops, quests, lore, 24-skill system (MVP implements 17 — §9), items, monsters, Grand Exchange. |
| **Dwarf Fortress** | Procgen + emergent storytelling — relocated to the **heroes**: generated adventurers & their sagas. |
| **Evil Hunter Tycoon** | Management loop + dual-agency economy + dynamic prices + reincarnation-style scaling. |
| **Kairosoft – Dungeon Village** | Cozy living economy: fight then return to shop/rest; jobs affect growth & prices; upkeep; restocking. |
| **Majesty** | Indirect control via incentives, not commands. |

**Core principle — DUAL-AGENCY:** every economic/RPG verb works two ways — a player button AND a hero AI behavior — on the same shared systems.

**Art:** Pixel-art **2.5D isometric**. ✅ (see §21 Tech for sprite/asset pipeline)

---

## 2. Player Role & Control Model ✅

A **blend**, three tiers: **Incentivize** (bounties/prices/stock/posted quests/**loadout presets**) → **Nudge** (tap a hero, prompt an action) → **Seize** (directly micromanage). Fully playable at any single tier.

---

## 3. OSRS Theming & Canon Rules ✅

**Authored / Generated split:**

| Layer | Source | Examples |
|---|---|---|
| **Authored & fixed (canon)** | OSRS | Map, cities, NPCs, shop locations, quests, lore, 24 skills, monsters, item identities, GE |
| **Procedurally generated** | Our sim | Heroes: names, skill builds, traits, goals, sagas — and **item stat values** (see *Items & Loot*) |

**Heroes = "the players"** (canon's *Adventurer*). They train the skills, do canon quests, fight canon monsters, trade in the canon economy.

**Procgen scope:** ✅ Build **A** (heroes + sagas; world fixed) first, design toward **B** (+variable spawns/loot/events within canon). C (living history) deferred.

**Canon vs mechanics:** *Lore* and *item identity* stay 100% canon; *item stat values* deliberately diverge (procedural rolls) for loot-game feel — documented, intentional.

**No-quest gating (global rule):** ✅ quests are deferred (post-MVP). Until they exist, **all** content normally locked behind a quest (gear like Ava's/RFD gloves/god capes, teleport access, Slayer unlocks, zone entry) is gated instead by **level + item/material + kill-count** requirements. *Quests will later be added as mainline/mandatory progression that replaces these interim gates.*

---

## 4. Time & Simulation Model ✅

**Hybrid:** live sim while open; fast catch-up sim while away.
**Keystone:** every event resolvable two ways — live (tick) AND statistical (expected outcome over elapsed time).
**Offline:** 24h cap; 75% of active rate; EXP/gold/items only; no consequential events (reinforced by LIVE-ONLY risk, §8).
✅ **Offline rare/boss drops:** can occur offline, but at **50% reduced chance** vs active play (common drops/gold/XP unaffected) — preserves the active-play incentive without locking rares behind being online.

---

## 5. Core Gameplay Loop & Progression 🟡

Synthesis of every system into one satisfying, balanced, gated loop — the EHT idle-tycoon engine adapted to our OSRS ant farm.

### 5.1 The loop at three scales
- **Hero (seconds–minutes):** the brain's trip cycle — pick activity → gear up → travel → gather/fight → react (eat/flee/loot) → return → bank/sell/restock → repeat (§18).
- **Player session (minutes–hour):** check colony → read the Chronicle (§17) → set incentives (prices/bounties/posted tasks) → build/upgrade a facility (§19) → nudge/gear a favourite hero → watch progress → seize for a tough boss. *Hooks:* a hero nearing a 99, a monster nearing its 100-kill Slayer unlock, a shop level-up, a new applicant, a kick vote.
- **Colony (hours–days):** gather → craft → fight → trade → upgrade → unlock harder content → better loot → repeat; the town levels (reputation → population → economy) while heroes level (skills → gear → zones → Slayer → bosses → endgame → reincarnation).

### 5.2 The progression spine (gated & broad)
Each gate needs **multiple systems** so there's no single-stat rush:
| Stage | Heroes do | Gates / unlocks |
|---|---|---|
| **Early (home Varrock)** | combat → ~40; gather + craft; gear bronze→rune→dragon; local mobs → **Scurrius** | reputation grows population; build/upgrade basic facilities |
| **Gate 1** | — | **Combat 40** → Slayer (Vannaka, §15); **unlock road north** → the **GE** player-driven market; first teleport zone (Al Kharid) |
| **Mid (zones open)** | Slayer tasks (kill → 100 → unlock monsters); harder zones; gear → Barrows/Bandos; Wilderness for risk-takers | Slayer gates 5→50; town toward 50 pop; higher shop levels |
| **Late (endgame)** | Fight Caves → Inferno (capes); Kourend bosses (Sarachnis, Alch. Hydra); Wildy bosses; raids; endgame gear (Torva/Masori/Twisted bow/Kodai) | Slayer 75–95; high reputation; teleport unlocks |
| **Long-tail** | **Reincarnation** — maxed heroes rebirth for permanent scaling | infinite progression; veterans become Chronicle legends |

### 5.3 What keeps it balanced
- **Broad gates** (combat + reputation + gear + Slayer) prevent one-stat rushing.
- **Self-balancing economy** — node congestion + supply/demand redistribute heroes (§18); if everyone mines, ore price falls and mining's utility drops.
- **Situational gear + cost asymmetry** (companion doc) — no single build dominates; the right tool wins per target.
- **Risk vs reward** — Wilderness/bosses are **live-only** high-reward; offline is safe at 75% rate, keeping idle vs active balanced.
- **Feasibility-gated AI** — heroes won't attempt content above their power (and flee if losing), so they flow through appropriate tiers.

### 5.4 Pacing levers (all tunable)
XP-compression slider (§9) · monster unlock thresholds (100 kills; scaled for bosses, §15) · reputation→immigration rate (§16) · shop levels & bank capacity (§19) · reincarnation bonuses.

### 5.5 EHT loop — adopt / adapt / reject
- **Adopt:** idle progression; the **dual-economy** (heroes spend their own gold → you reinvest via prices/upgrades); facility upgrades driving the loop; difficulty/zone gating; the gather→craft→enhance→harder-content cycle; **reincarnation** long-tail; attract/retain heroes via town quality (satisfaction).
- **Adapt:** EHT's single gear set → our inventory/bank/loadouts (deeper, §13); EHT's 4 fixed classes → our **procgen traits/archetypes + OSRS skills** (emergent, not fixed); EHT's risky **Enhancement Forge** → our quality tiers + Enhancement (§5.6); EHT appearance customization → our procgen character appearance (§21.3).
- **Reject:** F2P gacha / pay-to-win / currency-sale timewalls — this is a sim, not a monetization funnel.

### 5.6 Enhancement — gear upgrading + economy sink ✅ (curves tunable)
A gather → craft → **enhance** sink that fits our quality tiers (§12) and delivers EHT's "one more upgrade" hook. Raise an item's **quality tier** by spending **gold + materials** on an attempt with a sub-100% success chance.

**Tier curve (tunable defaults):**
| Attempt | Success | Cost (gold + materials) | On failure |
|---|---|---|---|
| Standard → **Fine** | 90% | low (common mats) | lose materials only |
| Fine → **Pristine** | 65% | medium (uncommon mats + tier-relevant item) | lose materials only |
| Pristine → **Masterwork** | 35% | high (rare mats + gold) | lose materials; **10% chance to drop back to Fine** |

- **Idle-friendly by design:** failures cost *materials*, never the item itself, except the small Masterwork-downgrade risk — so it's a real sink without feel-bad item loss (consistent with our cozy-leaning philosophy).
- **Materials** come from the gather/craft loop and monster drops → ties Mining/Smithing/Crafting/Slayer into the upgrade economy and gives those skills end-purpose.
- **Protection items (optional, design-toward):** a consumable that prevents downgrade on a failed Masterwork attempt — a premium material sink.
- **Dual-agency:** heroes enhance their own gear when utility says it's worth it (greedy/ambitious heroes more so) OR the player enhances a favourite's gear. A strong **gold + material sink** that keeps the economy from inflating.
🟡 *Numbers above are starting points — tune success rates / costs against the XP-compression pacing.*

### 5.7 Reincarnation — the infinite long-tail ✅
The endgame engine (EHT's rebirth, adapted): a hero who has **completed a full life** can **reincarnate** — start over, permanently stronger. This is what turns a colony's veterans into Chronicle legends.

**Trigger:** ✅ **all skills at level 99** (a true "maxed / completed life" milestone). Until then, reincarnation is unavailable. *(With the active MVP skill set this means all of them at 99; as more skills are added, the bar rises with them.)*

**Resets (the fresh life):**
- All **skill levels & XP → 1 / 0** (Hitpoints to its base 10, per canon).
- All **equipped gear is unequipped to the bank** — the hero starts a fresh life wearing nothing.

**Persists (meta-progress is never lost):**
- The hero's **identity & appearance**, their **bank & inventory** (all gear kept — see gear note below), **relationships** (§16), **Chronicle/saga** (§17), reincarnation **count**, and all **echo bonuses**.

**Echo bonus (per reincarnation, stacking):**
| Trigger | Permanent bonus (stacking, tunable) |
|---|---|
| each rebirth | **+10% XP gain** and **+5% combat damage/accuracy** (multiplicative) |
| each rebirth | a **trait re-roll token** (re-roll one personality/aptitude trait — lets a hero "find their calling") |
| milestone rebirths (5th, 10th, …) | a **prestige cosmetic** (Chronicle title, sprite flourish) |

**Gear & equip implications (the core tradeoff):** ✅
- A maxed hero's bank is full of **endgame gear they can no longer equip** at level 1 — this is the intended cost of rebirth, and it's *temporary*, not a loss.
- **Nothing is destroyed.** All gear stays safe in the bank; it simply can't be re-equipped until the relevant levels climb back (Torva needs the Defence/levels again, etc.).
- **Re-gearing is automatic.** The brain (§18) always equips the *best gear the hero can currently use*, so a fresh-life hero naturally drops to low-tier gear (bronze/leather/basic robes) and works back up the ladder — no special handling; it falls straight out of the existing loadout logic (§13).
- **The "loaded veteran" power spike:** because of the echo **+XP**, a reincarnated hero re-walks the level/gear ladder in a *fraction* of the original time, then re-equips their banked endgame kit — so each rebirth *feels* like a fast, satisfying climb back to power, not a punishment.
- **Head-start (soften the early grind):** ✅ on reincarnation the hero keeps a **starter loadout** of their choice from the bank — i.e., the best gear they'll be *able* to equip soon — auto-equipped as levels allow; plus a small **gold/material rebate** scaling with reincarnation count (a gentle leg-up that also feeds the enhancement/economy sink). 🟡 rebate size tunable.

**Why it's balanced:** levels reset so the hero re-walks the entire progression spine (re-engaging gather→craft→fight→gear), but each pass is faster + stronger → the classic idle prestige curve. The +XP makes re-leveling quick; the +damage lets veterans push deeper endgame content each life; the gear reset guarantees the *whole* loop (not just bossing) gets replayed.

**Dual-agency:** a maxed hero's brain (§18) treats reincarnation as a high-utility "life complete → rebirth" goal (the **ambition** trait raises the inclination — some heroes rebirth eagerly, some linger at max enjoying their power) OR the player prompts it from the hero panel (§20).

**Colony effect:** reincarnated veterans become the colony's powerhouses and most-storied characters — a prime source of Chronicle legends ("Bjorn, on his 4th life, …") and a reason to grow attached to specific heroes.

🟡 *Open: echo-bonus magnitudes; head-start rebate size; whether the count is capped or truly infinite (default: infinite, diminishing relative impact).*

### 5.8 The Win Condition — Zezima, the Escalating Rival ✅
The colony's ultimate goal: **defeat Zezima** — a nod to the legendary real-life OSRS player, here the apex adversary. He is an *escalating mirror* of our own reincarnation engine, so the game always has a "next Zezima" to chase.

**The recurring rival (escalation):**
- When defeated, **Zezima reincarnates like a hero** — but uniquely **keeps all skills at 99** and takes the full stacking **echo bonuses** (§5.7). The +XP is moot (he stays maxed), but the **+combat damage/accuracy per reincarnation compounds** → each Zezima is stronger than the last.
- A **Zezima counter** is the colony's ultimate scoreboard and its highest Chronicle honour (defeating Zezima #1, #2, #3…). This sits **above** normal reincarnation as the apex goal — an endless arms race that gives the whole colony purpose.

**The signature fight — hybrid triangle-punisher:**
- Zezima fluidly uses **all three combat styles** and **switches protection prayers to counter the triangle** — praying against the style that beats his *current* offence (melee phase → prays Magic; ranged phase → prays Melee; magic phase → prays Ranged). A single-style assault gets walled, so the fight rewards **mixed-style pressure**.
- **Escalating reaction speed (his difficulty curve):** ✅ early Zezimas switch prayers **and gear** with a **slight delay** (exploitable windows a sharp hero can slip damage through); **from his 3rd reincarnation onward, switches are instant** — a flawless triangle-punisher that genuinely demands coordinated mixed-style attack.

**Party — no size limit:** ✅ challengeable **solo or in a group of any size** — a godlike solo hero *can* attempt it (especially early Zezimas with delay windows), or the colony can throw a whole mixed-style army at him. No cap → the showdown scales from a lone legend to a town-wide war (a spectacular Chronicle event either way). Extends the Slayer-partnering tech (§15.4) without the 3-cap.

**Access gate:** a hero/party may challenge Zezima only after **matching his legend** — maxed (all-99) **and** cleared the hardest content (e.g., the Inferno / endgame zones). The apex of the progression spine (§5.2).

🟡 *Open: Zezima's base stats & per-reincarnation scaling curve; arena/access location; group reward split; whether each Zezima tier drops unique trophies/cosmetics for the Chronicle.*

🟡 **NEXT PASS:** world map refinement, teleport-unlock system (magic-level + teleport-item gates), God Wars Dungeon + bosses, Godswords + god capes/stoles, and the full location-unlock progression flow.

---

## 6. Economy & Gold Balance 🟡

The colony is a **closed dual-agency economy**: heroes earn and spend their own gold; the player reinvests via prices, stock, and facilities. The non-negotiable rule: **total gold must stay roughly stable over time** — faucets (gold created) and sinks (gold destroyed) must balance, or the currency inflates (gold becomes meaningless) or starves (heroes stall). This section defines both sides, the pricing mechanism, and the equilibrium logic.

### 6.1 Two distinct money flows (don't confuse them)
- **Gold creation/destruction (the macro balance):** gold enters and leaves the *whole system*. This is what must net to ~zero over time.
- **Gold circulation (hero ↔ shop ↔ hero):** gold moving *between* agents (a hero buys from an NPC shop you own → that gold returns to your treasury → you reinvest). Circulation doesn't change the total; it just flows. **Healthy economy = lots of circulation, near-zero net creation.**

### 6.2 Faucets (gold created — must be capped/throttled)
| Faucet | Where gold enters | Throttle |
|---|---|---|
| **Monster drops** (coins) | combat loot tables | scales with monster tier; the dominant early faucet |
| **NPC shop *sells*** (hero sells loot to an NPC shop for gold) | NPC buys items → mints gold | **shops pay below base value**; price drops as stock rises (anti-farming) |
| **Offline accrual** | catch-up sim | already ×75%, 24h cap (§4) |
| **Quest/task rewards** (later) | Slayer points, future quests | fixed, designed amounts |

### 6.3 Sinks (gold destroyed — the critical, easy-to-underbuild half)
| Sink | Where gold leaves | Role |
|---|---|---|
| **NPC shop *buys*** (hero buys gear/food/runes/ammo) | gold paid to NPC shop = removed* | primary everyday sink; ammo/runes are recurring (ranged/mage cost asymmetry, §9) |
| **Shop leveling** (player invests gold + items, §19) | removed | big player-driven sink |
| **Enhancement** (gold + materials per attempt, §5.6) | removed | scaling late-game sink |
| **Town facilities** — build + **upkeep** (§19) | removed | continuous structural sink |
| **Death reclaim fee** (10%, §14) | removed | risk-driven sink |
| **Bank/teleport/repair costs** (degradable gear, teleport items) | removed | recurring sinks |
| **GE tax** (small % on sales, post-unlock) | removed | scales the sink with economic activity |
*Treat NPC-shop gold as **minted on sell / burned on buy** (the shop is a faucet *and* a sink, net-tunable), OR route it through the player treasury (circulation). Pick one model per shop — see 6.5.*

### 6.4 The pricing mechanism (two markets)
- **NPC shops (early game): dynamic price around a base value.** Each item has a canon **base value** (from the dataset). Shop price = base × (stock modifier): **buying** price rises as stock falls (scarcity); **selling** price falls as stock rises (anti-dumping). Bounded by floor/ceiling (e.g. 40%–130% of base) so it can't spiral. This *is* the EHT/Dungeon Village dynamic-price feel and a natural sink/faucet throttle.
- **Grand Exchange (post-unlock): offer-matching market.** Heroes and the player post buy/sell offers; the system matches them (§7). Price = emergent from supply/demand among the colony itself. A small **GE tax** on each completed sale is the key sink that scales with activity. **Fungibility** holds because of the Floor+tiers model (§11) — items trade per (type × quality tier).

### 6.5 Equilibrium logic (how it self-balances)
- **Negative feedback loops keep it stable:** more heroes mining → ore supply up → ore price down → mining less attractive (brain re-weights, §18) → heroes diversify. Same for any over-farmed good. The economy *redistributes labor automatically*.
- **Gold equilibrium:** tune so that **faucets ≈ sinks at the colony's current size**. As the town grows (more heroes, more activity), *both* scale together; the **GE tax + upkeep + enhancement** are the sinks that grow with wealth, absorbing late-game gold to prevent inflation.
- **The player as central bank:** by setting shop prices and stock, and investing in facilities/enhancement, the player is effectively managing monetary policy — a core part of the tycoon fantasy. Setting prices too high → heroes can't afford gear → they leave (satisfaction, §16); too generous → inflation. The *interesting decisions* live here.

### 6.6 Tunable levers (the economy's dials)
Drop coin amounts · NPC buy/sell margins & price-band width · GE tax % · upkeep costs · enhancement costs · reclaim fee % · offline rate (already 75%). All exposed for balancing against the XP-compression pacing (§9).

🟡 **OPEN:** exact base-value scaling & price-band numbers; NPC-shop gold model (mint/burn vs treasury) per shop; GE tax %; whether a soft gold cap or decay is needed as a backstop against runaway hoarding.

---

## 7. Starting Region — Varrock & Surroundings 🟡

First build = **Varrock + its immediate, lore-accurate surroundings**, expanding outward via teleport spokes (see *World Structure & Travel*).

**The city — basic NPC shops at start (fixed-price):** General Store, Aubury's Rune Shop, Zaff's Superior Staffs, Horvik's Armour Shop, Lowe's Archery Emporium, Thessalia's Fine Clothes, Varrock Swordshop, the Apothecary.
**Notable NPCs (seed):** King Roald, Aubury, Horvik, Zaff, Lowe, Thessalia, Baraek, Gypsy Aris, Apothecary, Museum Curator, Reldo.
**Banks:** Varrock **west** & **east** banks — deposits & loadout swaps.
**Grand Exchange (behind unlock):** NW of Varrock; offer-matching market (post buy/sell offers, system matches; 8 slots / 3 F2P). Early game = NPC shops only; after unlock = player-driven floating market where heroes & player post offers.

**Immediate surroundings (canon):**
| Direction | Canon content |
|---|---|
| **West** | Path to **Barbarian Village** (Gunnarsgrunn); Gertrude's house en route; River Lum fishing |
| **North** | North gate by the **Wilderness** wall → rarer loot + risk (LIVE-ONLY). GE sits NW |
| **East** | Woodland (yew trees) + road to the **Digsite** and the Al Kharid crossroads |
| **South** | Farmland toward Lumbridge; **dark-wizard Stone Circle** by the south gate (lvl 7 & 20; where Delrith is summoned in **Demon Slayer**) |

**In-city / adjacent content hooks for the MVP:**
- **Varrock Sewers** (beneath the palace) — dungeon with bosses **Scurrius** (beginner rat boss) and **Bryophyta**. A real boss without needing teleports.
- **Stone Circle** dark wizards (rune drops; Demon Slayer / Delrith).
- **Tolna's Rift** (A Soul's Bane); **Digsite** (east).
- Quest seeds: Demon Slayer, Dragon Slayer (Champions' Guild, 30 QP), Gertrude's Cat, Shield of Arrav, Family Crest.

---

## 8. World Structure & Travel ✅ structure / 🟡 details

**Hub-and-spoke world.** ✅
- **Home region** = Varrock + immediate surroundings (a real, contiguous, explorable map).
- **Destination zones** = teleport-gated, self-contained content packages (own monsters, loot tables, boss/raid).
- **Abstraction (documented):** the land *between* regions is NOT simulated. Each *place* stays lore-accurate; distant ones are reached by teleport, not by walking a simulated overworld. Keeps scope bounded; zones added one at a time.

**Teleportation = travel + progression gate.** ✅ Unlocked three canon ways:
1. **Magic level** — teleport spells unlock with level.
2. **Items** — teleport tablets/jewellery bought from shops or the GE, or given as quest rewards.
3. **Quest completion** — unlocks specific destinations.

**Destination-zone map — canon teleport access → our level+item gates** (no-quest gating §3 applies; exact reqs validated vs dataset at build):
| Zone | Canon access (mapped to our gate) | Tier | Content |
|---|---|---|---|
| **Edgeville** (Vannaka/Slayer) | Amulet of Glory (no-req jewellery) | Early | Slayer master; Wilderness edge |
| **Al Kharid** | Amulet of Glory / Ring of Dueling | Early | Desert hub; warriors, scorpions, strykewyrms |
| **Great Kourend** | Teleport to Kourend (**69 Magic**) / Xeric's Talisman (item) | Mid | Sub-continent: lizardmen→shaman, Karuulm (Wyrm/Drake/Hydra), Sarachnis, Alch. Hydra |
| **Morytania** (Canifis/Slayer Tower) | Kharyrll (**66 Mag**) / Fenkenstrain's (**48 Mag**, Arceuus) / Slayer ring (item) | Mid | Undead + Slayer Tower (Salve-amulet territory); Grotesque Guardians |
| **Barrows** | Barrows Teleport (**83 Mag**, Arceuus) / tablet (item) | Mid–Late | Boss run (6 brothers; degradable set drops) |
| **Karamja — Fight Caves** | Magic-level teleport / TokKul-Zo (item) | Late | Solo wave survival → **TzTok-Jad** → **Fire cape** |
| **Karamja — The Inferno** | Magic-level teleport; **requires Fire cape** | Endgame | Solo waves → **TzKal-Zuk** → **Infernal cape** |
| **God Wars Dungeon** *(Troll Country, N of Trollheim — NOT Wilderness)* | GWD Teleport (**61 Mag**) / Trollheim Teleport (**61 Mag**) + **60 Str OR 60 Agi** entry | Late–Endgame | 4 generals (see §8.x) → **Godswords**, GWD armour |
| **Weiss** | Icy basalt / Weiss Portal (item) | Late | Far-north |
| **Wilderness** | edge teleports (live-only, PvP) | any | Revenants, Wildy bosses (Callisto/Venenatis/Vet'ion…) |
| **Raids** | Various | Endgame | Boss-run packages |
*Teleport gate tiers: **Early** = no-req jewellery (Glory/dueling/games necklace); **Mid** = 48–69 Magic spells or earned items; **Late/Endgame** = 61–83 Magic + skill/item/kill gates. Fight Caves/Inferno are **solo wave-survival** (no mid-run banking; death ends the run, no item loss per canon).*

**📍 LOCATION-UNLOCK PROGRESSION FLOW** ✅ (the world's gated spine):
1. **Home (start):** Varrock + immediate surroundings (W Barbarian Village, N Wilderness edge, E Digsite/Al Kharid road, S farms/Stone Circle) + Varrock Sewers. No teleports needed.
2. **Gate 1 (Combat 40 / reputation):** GE unlocks (road north); **Edgeville/Vannaka** (Glory) → Slayer begins; **Al Kharid** (Glory/dueling).
3. **Mid (Magic 48–69 + items):** **Morytania** (Slayer Tower, undead/Salve) · **Great Kourend** (Karuulm Slayer chain) · **Barrows** (degradable sets). Slayer level + the 100-kill monster unlocks pace this.
4. **Late (Magic 61–83 + skill gates):** **Fight Caves** → Fire cape · **God Wars Dungeon** (60 Str/Agi entry + per-wing 70 Str/Agi/Rng/HP). 
5. **Endgame:** **The Inferno** (needs Fire cape) → Infernal cape · **Wilderness bosses** · **Raids**. Endgame gear (Godswords, Torva/Masori/Twisted bow/Kodai) flows from here.
6. **Apex:** challenge **Zezima** (§5.8) once maxed + hardest content cleared.

*Each location's exact monster/boss stats come from the dataset at build (snapshot a target patch date — boss stats are version-dependent). This doc fixes the **gates & flow**, not the raw numbers.*

### 8.x God Wars Dungeon (mid-to-endgame zone package) 🟡
Location: **Troll Country, north of Trollheim** (canon — *not* the Wilderness; the Wilderness GWD is a separate minor site, deferred). Entry: **60 Strength OR 60 Agility** + a teleport (GWD/Trollheim, 61 Magic) or climb.
- **Killcount gate (slots into our "kill to unlock" mechanic, §15):** slay **40 followers** of a god to enter that general's chamber; **leaving the dungeon resets killcount** (a built-in risk/commitment mechanic). Reducible via Combat-Achievement-style milestones later.
- **Per-wing skill gates (canon):** Bandos = **70 Str**, Saradomin = **70 Agi**, Armadyl = **70 Ranged**, Zamorak = **70 HP**.
- **Four generals** (mixed-style boss fights, each demands the right prayer/style — a great showcase of our combat-triangle systems): **Kree'arra** (Armadyl, fly — ranged only), **General Graardor** (Bandos, melee), **Commander Zilyana** (Saradomin, fast melee+magic), **K'ril Tsutsaroth** (Zamorak, melee+prayer-smash). Stats & drop tables in companion *Items, Monsters & Balance*.
- **Rewards:** **Godsword shards + hilts** → Godswords; **GWD armour** (Armadyl/Bandos sets). Each general also drops a unique (Sara sword, Zamorakian spear, Staff of the dead, Armadyl crossbow).
- **Nex / Ancient Prison wing** (Ancient godsword, Torva) — **slated for a later pass.**

**Risk is LIVE-ONLY.** ✅ Wilderness, boss runs, raids, and any **item-loss-on-death** happen only during active play — consistent with "no consequential events offline." Offline heroes stay in safe accrual, so the active-play incentive bites through *risk*, not just the 25% rate.

**Wilderness behavior → seeds Hero-AI traits.** Not all heroes go to the Wilderness; some never do, some seek it out. Driven by procgen **personality/risk traits** (risk tolerance, greed, caution) — the first concrete requirement for the Hero-AI trait system (see Roadmap).
✅ **Wilderness risk model: A+B** — dangerous PvE **and** hostile **rival-adventurer PKers** (Wilderness only). Item-loss, gravestones & looting → see *Death, Gravestones & Looting*.

---

## 9. Skills System 🟡

**Combat is primary; supporting skills drive the economy.** MVP uses a focused subset; the rest are deferred.

**MVP skill set (17):**
- **Combat (7):** Attack, Strength, Defence, **Hitpoints**, Magic, Ranged, Prayer *(Hitpoints = mandatory HP pool)*
- **Gathering (4):** Mining, Woodcutting, Fishing, Hunter
- **Artisan/Production (5):** Crafting, Smithing, **Cooking**, Fletching, Runecraft
- **Support/Utility (1):** **Slayer** *(mid-game; gated — see §15 Slayer & Tasks)*

**Leveling & Pacing** ✅
- **Faithful OSRS XP:** XP per skill action; **level cap 99**; canonical XP curve preserved → **level 92 ≈ halfway to 99** in total XP.
- **Compression:** faster than OSRS but still a real grind — a **uniform XP-rate multiplier** (scales XP gained uniformly), preserving the curve shape *and* the 92-halfway property. Kept as a **slider**; default **moderate**.

**Deferred (canon, add later):** Herblore, Firemaking, Agility, Thieving, Farming, Construction, Sailing. *(Cooking & Slayer were promoted into the MVP set above.)*
**Naming:** canon spellings used (Defence, Ranged, Runecraft, Hunter); "Fetching" read as **Fletching**.

**Economy loop:** Gather (outside Varrock) → **import into the city** → Artisan crafts gear/runes/goods → Combat uses/consumes → loot & products → Trade (NPC shops early, GE later) → fund more gathering/gear.

**MVP gatherable surroundings:**
| Skill | Canon resource access near Varrock |
|---|---|
| Woodcutting | Yews in/around the city; willows/oaks south; yews east |
| Mining | Mine south-east of Varrock |
| Runecraft | Rune Essence mine via Aubury's teleport; Varrock altars |
| Fishing | River Lum at Barbarian Village (just west) |
| Hunter | **Outlier** — grounds aren't near Varrock; needs a designated nearby area or trails behind |

✅ **Specialization — favorite-skill model (locked; full detail §18.3):** every hero aims for **all-99 eventually**, but each has a procgen **favorite skill** trained first/hardest → soft specialization, division of labor, inter-hero trade, and no monoculture.

### 9.x Production Chains (gather → refine → craft → use)
The skills interlock into supply chains. **Exact recipes come from the osrsreboxed dataset (§21); this defines the chain *structure* and which chains matter for the MVP.** Each step is a hero activity (utility-scored by the brain, §18) and a tradeable good (economy, §6), so chains create **inter-hero trade** (a miner sells ore → a smith buys it → sells armour → a warrior buys it).

**MVP chains:**
| Chain | Gather → Refine → Craft → Use | Skills involved |
|---|---|---|
| **Metal/melee gear** | Ore (Mining) → Bar (Smithing, at a furnace) → Weapon/armour (Smithing, at an anvil) → equip/sell | Mining → Smithing |
| **Food** | Raw fish (Fishing) → Cooked food (Cooking, at a range/fire) → eaten in combat | Fishing → Cooking |
| **Runes** | Essence (Runecraft mine) → Runes (Runecraft, at altars) → Magic combat / sold to Aubury | Runecraft → Magic |
| **Ranged ammo** | Logs (Woodcutting) + tips → Arrows/bolts (Fletching) → Ranged combat | Woodcutting → Fletching |
| **Bows** | Logs (Woodcutting) → Bows (Fletching) → equip/sell | Woodcutting → Fletching |
| **Crafting goods** | Hides (monster drops, e.g. cowhide) → Leather → armour/products (Crafting); gems (Mining) → jewellery | Crafting (+ Mining for gems) |

**How chains tie the game together:**
- **They make skills *matter to each other*** — a hero's favorite (e.g. Mining) produces a good others need, which is what drives the division-of-labor economy (§6) and inter-hero trade rather than 50 self-sufficient loners.
- **They feed Enhancement (§5.6)** — crafted/refined materials are the inputs to gear upgrades, giving artisan skills late-game purpose.
- **Consumable sinks** — food (Cooking) and ammo/runes (Fletching/Runecraft) are *consumed* in combat, creating constant demand → steady circulation (§6).
- **Recurring vs one-off:** gear is one-off (craft once, use long-term); food/ammo/runes are recurring (the cost-asymmetry balance lever, §10). 

**Deferred chains** (arrive with their skills): Herblore (potions — currently buy-only from the Apothecary, §10), Farming, Construction, etc.

🟡 **OPEN:** exact recipe inputs/outputs (from dataset); per-step XP & time; which production buildings (§19.3) boost which chains.

---

## 10. Combat Resolution 🟡

Combat is the focus, built on OSRS's **exact** mechanics. Because OSRS combat is a per-tick probability model, the same stat math powers both the **live** fight and the **statistical** view — they can never diverge.

### 10.1 Foundations (canon)
- **Tick = 0.6s** (the live-sim quantum, ties to Time §4). Weapons have a speed in ticks (speed 4 = 2.4s, speed 6 = 3.6s).
- **Combat triangle: Melee > Ranged > Magic > Melee** (Melee beats Ranged, Ranged beats Magic, Magic beats Melee). Hitting a monster's weakness style boosts accuracy/effectiveness.
- **Stats:** MVP combat skills (Attack, Strength, Defence, Hitpoints, Ranged, Magic, Prayer). Gear & monsters carry per-style attack/strength/defence bonuses (from the item-tier model, §11).

### 10.2 The math (OSRS-exact — the shared core)
- **Effective level** = floor(visibleLevel × prayerMultiplier) + stanceBonus + 8.
- **Max hit (melee/ranged)** = floor(0.5 + EffStrength × (GearStrBonus + 64) ÷ 640). **Magic** = baseSpellDmg × (1 + MagicDmgBonus).
- **Attack roll** = EffAttackLevel × (GearAttackBonus + 64). **Defence roll** = (TargetDefLevel + 9) × (TargetDefBonus + 64).
- **Hit chance:** if AttackRoll > DefenceRoll → 1 − (DefRoll + 2) ÷ (2 × (AttRoll + 1)); else → AttRoll ÷ (2 × (DefRoll + 1)).
- **Average hit** = (MaxHit + 1) ÷ 2.
- *(Verified against OSRS Wiki / DPS calculators; exact coefficients pulled precisely at implementation.)*

### 10.3 Live vs Statistical — one core, two views
- **Live (tick):** each attack (every weaponSpeed ticks) rolls accuracy (hit/miss) then damage (uniform 0..MaxHit) → subtract HP → 0 HP = death (§14 respawn/loot).
- **Statistical:** **DPS** = AvgHit × Accuracy ÷ (weaponSpeedTicks × 0.6) → **time-to-kill** = monsterHP ÷ DPS; **food used** & **win probability** from incoming-DPS × TTK vs effective HP + supplies.
- **Used for:** offline catch-up (kills/hr → loot/XP/hr × 75%), AND the brain's reactive **"am I winning?"** check — a hero compares expected DPS both ways and flees if losing (risk trait sets the margin). This is how heroes play smart.

### 10.4 XP, styles, prayer
- **Combat XP** from damage dealt (OSRS-style: ~4 XP/damage to the trained style + Hitpoints XP); **attack style** (accurate/aggressive/defensive/controlled) sets which skill trains.
- **Prayer** (MVP): protection prayers reduce incoming damage from a style; offensive prayers boost; points drain (gear prayer bonus slows it). Heroes pray in dangerous fights (brain). Simplified set early; full prayer book design-toward.
- **Slayer on-task** adds Slayer XP + bonus combat XP + the +1 drop (§15).
- **Consumables (MVP):** **food** from Cooking (Fisher→Cook→Warrior loop); **potions are buy-only from the Apothecary** (Herblore deferred → added later to let heroes brew their own).

### 10.5 Monsters & bosses
- Canon monsters with canon combat stats (HP, attack/defence, max hit, style + weakness, aggression, drop table) — **data-driven from the OSRS dataset** (→ tech/data roadmap). Each monster also carries a **weakness** (style to counter) and an **`undead` flag** (drives the Salve situational bonus). Full region roster + weaknesses → companion *Items, Monsters & Balance* §7.
- **Bosses** = high-stat monsters; full **boss mechanics** (specials, phases) are **design-toward** — early bosses use the core model with elevated stats + a signature attack.

### 10.6 Performance & scope
- **Level-of-detail (LOD):** fully tick-simulate **observed/on-screen** fights; approximate off-screen/idle fights with the statistical model **even during live play** — same math, no visible seam → ~50 heroes + monsters stay cheap.
- **Calibration:** statistical TTK tracks live averages automatically (shared formulas); guard against drift when tuning.
- ✅ **Pacing:** faithful XP curve + 99 cap + 92-halfway preserved; compressed via a **uniform XP-rate multiplier** (slider; default moderate). See Skills §9 → Leveling & Pacing.
- 🟡 Design-toward: special attacks + spec energy, full prayer book, complex boss mechanics.

---

## 11. Items & Loot 🟡

**Content goal:** as many canon OSRS items & monsters as possible (data-driven from an OSRS dataset → tech roadmap).
**Stat tables & balance:** see companion doc **Items, Monsters & Balance** (power-tier framework + MVP item/monster rosters).
**Acquisition:** every item is tagged **Craftable / Drop-only / Hybrid-assembly** (with craft skill+level or drop source+rate) — the rule + full table is in companion §10. Craftable gear flows from the production chains (§9.x); drop-only gear comes from monster/boss tables and is the GE's high-value endgame trade (§6).
**Stat model:** each canon item keeps identity & tier; **stat values roll within a per-item band** anchored to canon. Tiers stay separated so ranking holds.
✅ **Floor + discrete quality tiers.** Canon stats = the **Standard** tier (the floor); rarer tiers roll progressively **above** it: **Standard → Fine → Pristine → Masterwork**. Nothing rolls below canon (no feel-bad); high tiers feel special (real chase). 🟡 *exact per-tier bonuses TBD.*
- **Why tiers, not continuous rolls:** continuous per-instance stats break **fungibility**, forcing the GE into an auction house. Discrete tiers keep items **fungible within (type × tier)** → GE stays a clean commodity exchange (a few more SKUs per item); death-reclaim & pricing stay per-tier.
- *(Rejected alternative: continuous Center rolls — max looter-chase but breaks GE fungibility. Not used.)*
**Two value axes:** **Vertical** (straight upgrades) + **Horizontal** (situational affixes — combat triangle, anti-monster, skilling boosts).
**Affixes (horizontal axis)** layer on top; an affixed item is semi-unique, so affixed items trade via **auction-style listings** (or player↔hero) while plain tiered items remain GE commodities.

---

## 12. Gear & Equipment Roster 🟡

The target gear roster (vision). Not all ships at once — **gear follows the content roster**: early/mid gear is obtainable in the Varrock home region (shops, Smithing/Crafting/Fletching, early monsters, Slayer, defenders); **endgame gear arrives with its source** (teleport zones, bosses, raids, high Slayer) as those are built. Every item carries **canon minimum level requirements** and **canon stats/abilities** (from the OSRS dataset → tech/data roadmap), slotted into the **Floor+tiers** model (§11), feeding the **combat math** (§10).

Legend: ★ = MVP-era (home region) · ☆ = endgame/later (arrives with its source content).

### 12.1 Melee
- ★ Metal tiers **Bronze→Rune** (shops/Smithing/drops); ★/☆ **Dragon** weapons & armour.
- ☆ **Barrows** (degradable) — *spans styles: Dharok/Guthan/Torag/Verac = melee, Karil = ranged, Ahrim = magic.*
- ☆ **Bandos** set; ☆ **Torva** (degradable).
- ★ **Anti-Dragon shield**; ☆ **Dragonfire shield** (active: dragonfire); ☆ **Dragon hunter lance** *(canon name; you wrote "Dragon slayer lance")*.
- ☆ **Slayer helmet** (Slayer pts, §15) + **skins** (cosmetic recolors).
- Amulets (scaling): ★ Strength → Power → Glory → ☆ Fury → Torture.
- Rings: ★ Berserker/Warrior → ☆ imbued ("next tier").
- Gloves: hand-slot progression → ☆ **Ferocious** *(canon gloves are quest/boss-sourced → no-quest gate for now, see 15.3)*.
- **Defenders** Bronze → ☆ **Avernic**, from the **Warriors' Guild** (★ add a teleport). ✅ entry req: **canon Attack + Strength ≥ 130** (e.g. 65/65, or 99 in either).
- Melee rings/amulets/boots across tiers (find/craft).
- ☆ **Capes (general slot):** Fire cape (Fight Caves) → Infernal cape (Inferno) — see §8 zones.

### 12.2 Magic
- ★ Basic robes (blue/black wizard) → mystic; ★ elemental staves, battlestaves, mystic staves.
- ☆ **God staves** (Mage Arena); wands ★ basic → ☆ **Kodai wand**.
- ★ Books as offhand → ☆ god books; ☆ **Wyvern shield**; ☆ **Elidinis' ward** *(canon spelling)*.
- Mage rings/amulets/boots across tiers.

### 12.3 Ranged
- ★ Leather / hard leather / studded / green d'hide → ☆ **Masori**.
- **Ava's devices** — ★ adapted: **level + item gated** (no quest, since quests aren't in MVP) → ☆ **Dizana's quiver**.
- ★ Bows & crossbows (shortbow/oak/willow/maple/yew, basic crossbows) → ☆ **Twisted bow**.
- Range rings/amulets/boots across tiers.

### 12.4 New mechanics this roster introduces
- **Degradation / repair** (Barrows, Torva, DFS charges): lose effectiveness with use → repair at a cost (gold sink) / recharge. Brain treats "repair gear" as a **maintenance need** (§18). 🟡 degrade-to-broken-then-repair (OSRS-style) vs degrade-to-dust.
- **Item abilities:** **passives** (Slayer-helm on-task boost, Twisted bow scaling, Ava's ammo recovery) + **actives** (special attacks via **spec energy** — DFS, dragon weapons). Simple passives in MVP; complex/endgame abilities + spec energy **design-toward**, arriving with their items. **Situational conditional-multipliers** (Salve vs undead, Slayer-helm on-task, Berserker+obsidian, Brimstone, Occult) are the core of the *"highest tier ≠ best"* balance — see companion *Items, Monsters & Balance* §1.1.
- **Cosmetic variants:** **Trimmed / gold-trimmed / god-trimmed** armour + **Slayer-helm skins** — rare **cosmetic-only** rolls on drop (no stat change); layered on Floor+tiers.

### 12.5 Acquisition & integration
- **Sources:** shops (early) · Smithing/Crafting/Fletching (player-made) · monster/boss drops · Slayer rewards · GE (post-unlock) · zone/raid drops (endgame).
- **No-quest workarounds (MVP):** items normally quest-locked (Ava's, RFD gloves, etc.) use **level + item/material gates** until quests exist.
- Obeys canon level requirements to equip; provides per-style attack/strength/defence bonuses to the combat math (§10).

🟡 **OPEN:** exact MVP gear cut; degradation repair model; which passives/actives are MVP vs later.

---

## 13. Inventory, Equipment, Banking & Presets ✅ (improves on EHT's single gear set)

Each hero has the canon setup: **Equipped loadout** (standard equipment slots), **28-slot inventory**, **personal bank** (per-hero; **30 base → up to 150 slots** via town upgrade §19; stacks by type × tier).

**Loadout Presets (player-authored policies)** 🟡 WIP: player defines named gear setups per activity (Magic / Melee / Ranged / Mining / Woodcutting…); heroes auto-equip the relevant preset when the AI or a posted task selects that activity. The Incentivize/Nudge steering tool — define intent, hero executes.

**Behavior:** heroes swap loadouts to fit the goal; path to a bank to deposit/swap; manage their own bank, OR the player opens it and gears them. Offline: items accrue to bank; choices resolved statistically.
🟡 Optional shared **Town Storage** for crafting materials — TBD.

---

## 14. Death, Gravestones & Looting 🟡

Death is **live-only** (never offline) and **not permanent** — a dead hero **respawns after 30s** at their respawn point (default: home city / Varrock). Death is a **setback** (30s out + lost non-kept loot + the run back), not loss of the hero.

**Items kept on death:**
| State | Kept |
|---|---|
| Normal | **3** most valuable |
| + Protect Item (Prayer) | **4** |
| Skulled (attacked a rival in the Wilderness) | **0** |
| Skulled + Protect Item | **1** |

Non-kept items drop as a **lootable pile/gravestone** at the death spot.

**Visibility — who can loot, by death type:**
| Death type | Timeline |
|---|---|
| **PvP** (killed by a rival-adventurer PKer) | **Killer** loots **immediately**; after **60s** → public to everyone in the area / who perceives it. |
| **PvE** (monster, anywhere **incl. Wilderness**) | **Immediately public** to everyone who perceives it — no exclusive window. |

**Owner's options to recover loot:**
- **Pay 10% reclaim fee** (of total lost-loot value) → remaining items instantly returned (**instant buy-back**). *(Value: canon base/high-alch pre-GE; GE price post-GE. "Minimum" 10% — may scale later.)*
- **Or run back and loot manually** after respawn, in a **Hasty** state — racing the vultures. The fallback if you can't afford the fee; may be infeasible if you died far away (e.g., deep Wilderness).
🟡 *Reclaim reinterpreted as instant buy-back (vs last turn's protected-window unlock), since PvE is now immediately public. Confirm.*

**Looting (any public pile/gravestone):**
- **1 item per interaction**; grab interval uniform random **1.2–2.1s**.
- **Hasty** (owner looting their own pile): interval − (rolled **0.3–0.7s**) → effective **~0.5–1.8s**, an edge over vultures. 🟡 rerolls per-grab (assumed).

**Vulture behavior — gated by LOCAL PERCEPTION (core AI rule):**
- Only heroes who have **actually perceived** the pile (perception radius / line of sight) can target it. **No global knowledge; no cross-map rushing.**
- Pull is **moderate, distance-decaying**, weighted by the **greed** trait + current-task value — opportunistic diversions, never a swarm.

> Makes **local perception + utility-based decision-making** a hard Hero-AI requirement.

---

## 15. Slayer & Tasks 🟡

A mid-game **content engine**: kill monsters → unlock them as tasks → slay for Slayer XP, bonus combat XP, and extra loot → feeds the economy. Plugs into the friendship graph via co-op partnering. (Slayer = the 17th MVP skill; naturally dormant early, blooms mid-game.)

### 15.1 Slayer Master — Vannaka (canon)
- **Location:** Edgeville Dungeon (east of the Wilderness entrance), in the western cluster near Edgeville/Barbarian Village — reachable from the Varrock home region. Canonically tied to Varrock (Varrock Diary NPC).
- **Canon gate:** heroes need **Combat level 40** to take his tasks → the built-in "let the world settle" gate.
- More masters later (Mazchna, Chaeldar, …) as the world expands.
- **Dual-agency:** player curates the **task pool** (which unlocked monsters are assignable); heroes autonomously pull tasks; player may also assign a specific task to a specific hero (nudge).

### 15.2 Two-gate unlock model
- **Monster → task pool (town-wide):** eligible once the colony has slain it **≥100×**; then the **player enables** it in Vannaka's pool. ✅ **Bosses: threshold scales with difficulty** (tougher/rarer → fewer kills; e.g. a deadly boss ~15, a trash mob 100) → pacing self-balances, no per-monster hand-tuning.
- **Hero → task (per hero):** master's **Combat 40** + any monster-specific **Slayer-level** requirement (canon; optional/design-toward).

### 15.3 Tasks & on-task bonuses
- **Task = "Slay N [monster]"** (N scales with monster). Completion → **Slayer reward points** (canon) → spend on unlocks/perks (design-toward reward shop).
- **While on task, assigned monster only:** Slayer XP per kill (≈ monster HP); **bonus combat XP** (🟡 +25–50%, tunable); **+1 extra loot roll** per kill (bosses included). Bonuses end on completion/cancel.

### 15.4 Slayer Partnering (canon-rooted "co-op / Social Slayer")
- Up to **3 heroes**; only **friends** (relationship ≥ Friend, §16) may request/join.
- **Forming:** requester opens partnership → friends respond → must **travel to & meet** the requester → **queue until 3 slots fill OR 60s** → embark. **No joining after embark.** Solo allowed.
- **Shared task:** all partners slay the **same monster** into **one shared kill count** → faster.
- 🟡 **Reward model (propose):** each partner earns full Slayer XP + bonus combat XP + the +1 drop **for their own kills** (no dilution) **plus a small co-op bonus** (canon co-op Slayer points / minor XP boost) — partnering attractive, solo not punished.
- Emergent: partnering lowers risk on dangerous tasks → cautious/sociable heroes have a social reason to team up.

### 15.5 Integration & balance
- **Brain:** "Get a Slayer task" / "Do task (solo/partnered)" are Activities; on-task bonuses raise slaying utility; combat-inclined/ambitious heroes favor it; a sociable hero with a friend requesting → high utility to join. Vannaka = common knowledge.
- **Progression engine:** combat kills → monster unlocks → more tasks (incl. bosses) → more loot → economy; higher masters/areas gate later content.
- **Balance:** on-task is intentionally the strongest combat option (the incentive); flooding bounded by per-task kill counts + specific assigned monster; boss threshold lowered for sane pacing.

🟡 **OPEN (minor, proposed defaults riding):** partnership reward model; bonus-combat-XP %; whether to use canon Slayer-level-to-damage gates.

---

## 16. Population & Social Systems 🟡

The emergent **friendships and feuds** are the colony's "stories" layer — the DF-style drama. One coherent system; the relationship graph is cheap to run from early, with effects wired in progressively.

### 16.1 Population & Immigration
- **Cap:** default **50** citizens (configurable).
- **Immigration:** applicants arrive at a rate scaling with **town reputation/appeal** × **free capacity**. At cap → no new arrivals until a slot frees.
- **Capacity valves:** (1) **Kick** — civic vote or god failsafe (§16.2); (2) **Voluntary departure** — an unhappy / low-loyalty hero may leave on their own (ties happiness to population; town isn't purely kick-gated).
- Deaths do **not** free slots (30s respawn; not permanent).
- **Newcomer rarity tiers:** ✅ each applicant rolls a **rarity tier** that sets their **starting stats & gear** (e.g. Greenhorn → Seasoned → Veteran → Elite). Nothing otherwise special — just a head-start. **Better town facilities raise the odds of higher-tier arrivals** (a nicer city attracts more accomplished adventurers), tying the tycoon-build loop to population quality. 🟡 exact tier table + odds curve TBD.

### 16.2 Civic Votes & Kicking
- **God initiates** a kick → triggers a **30s town vote**.
- **Electorate:** citizens **present in the city** AND **eligible** — *not* in combat, training a skill, shopping, AFK, or incapacitated.
- **Each eligible voter casts yes/no** via a probability shaped by their **relationship to the target** (friends defend → no; nemeses → yes) + an assessment of the target's **value to the town**.
- ✅ **Quorum / threshold — Option A:** vote valid only if ≥ **25%** of citizens are eligible-and-vote; **pass on > 50% of ballots cast**. A void (sub-quorum) vote does **not** consume a kick attempt.
- **Fail:** target stays; **90s cooldown** before another vote on the same target.
- **Failsafe:** after **5 failed (valid) votes**, the god may **force-kick**.
- *Most citizens are usually busy → turnout is often low → the force-kick failsafe is the practical backstop. Loosen eligibility/quorum to make votes the primary path.*

**Exile outcome (kicked, NOT deleted):** removed from town; future fate weighted by the exile's **resentment toward the town** (driven by how many voted yes / past mistreatment):
- Low resentment → may **reapply** to rejoin later (re-enters applicant pool).
- High resentment → chance to **spawn as a Wilderness monster event** — a vengeful exile, a roaming nemesis.

### 16.3 Friendship & Nemesis — the Social Web
**Model:** a **directed, signed relationship graph**. Each ordered pair A→B holds **R ∈ [−100, +100]** (start 0). Asymmetric; sparse storage; **decays toward 0** over time (lazy/elapsed-based) so bonds & grudges fade unless reinforced.

**Tiers (tunable):** Nemesis ≤ −60 · Rival −60..−20 · Neutral −20..+20 · Friend +20..+60 · Ally ≥ +60.

**Event deltas (defaults; tunable; repeat-dampened):**
| Event (B acts on A) | R(A→B) |
|---|---|
| B kills A in PvP | −25 |
| B loots A's gravestone | −5 / item (event cap −30) |
| B votes YES to kick A | −15 |
| B votes NO to kick A (defends) | +10 |
| A ↔ B complete a trade | +3 (mutual, daily cap) |
| B returns A's looted items after killing A | +30 |
| Co-op survive a boss/expedition together | +5 |
| Passive time near each other in town | +0.1 / min (small cap) |

**Effects (scale with tier):**
- **Trade:** Friends/Allies → discounts & prioritized trades; Rivals/Nemeses → markup or refuse.
- **PvP targeting (Wild):** won't initiate on Friend+; Nemesis sharply raises targeting weight (× risk trait).
- **Friendly-kill give-back:** killing a Friend+ → P(return loot) scales with tier (e.g., Friend ~40%, Ally ~80%).
- **Voting:** relationship to target shifts the yes/no probability (§16.2).
- **Aid (optional):** Allies may rescue a downed friend or share food.

### 16.4 Balance & Phasing
- **Runaway-loop guard:** kill→nemesis→more PvP→more kills is dampened by (a) decay, (b) diminishing returns on repeated same-pair events, (c) the 30s respawn, (d) a per-pair aggression cooldown.
- **Cliques** shielding a bad actor → handled by the **force-kick failsafe**.
- **Cold start:** everyone begins Neutral; the web builds through play.
- **Offline:** nemesis-generating events (PvP/looting) are **live-only**; light friendly drift (trades) + decay resolve statistically.
- **Phasing:** track the **graph from early** (cheap); wire **effects incrementally** (trade pricing → voting → PvP targeting → give-back → aid).

---

## 17. The Chronicle (Legends & Sagas) ✅ (in MVP)

The "stories" layer — what makes the colony worth watching (the Dwarf Fortress soul).
- **Town Chronicle:** an auto-generated, filterable **event log** of notable happenings — a milestone (first 99, notable level-ups), a boss kill, a notable death/PK, an exile's banishment & possible monster-return, a rivalry turning to friendship, a rare drop, a record. Curated by **notability** (only events worth remembering, not every tick).
- **Per-hero Saga:** each hero has a generated **backstory** + running record of milestones, kills, deaths, rivalries, friendships → surfaced in the hero panel's Saga tab (§20).
- **Notability scoring:** events carry a weight; only above-threshold ones are logged → keeps the Chronicle readable. Feeds from Death (§14), Social (§16), Slayer/bosses (§15/§10), drops (§11).
- **MVP version:** lightweight — milestone/death/boss/rare-drop/social events + per-hero milestone lists. Richer narrative templating later.

---

## 18. Hero AI — The "Brain" 🟡

The keystone. Each hero is an autonomous agent that decides what to do next the way an OSRS player would — and the player (god) can incentivize, nudge, or seize.

### 18.1 Architecture — layered utility brain (3 layers + reactive interrupts)
**Layer 1 — Drives & Needs (why):** continuously-updated pressures, baseline-weighted by traits.
- *Survival:* HP (eat/flee), threat-safety. *Maintenance:* supplies (food/runes/ammo), free inventory, gear adequacy. *Growth:* XP/levels toward goals, wealth, quest progress. *Personality/social:* greed, risk appetite, ambition, sociability, loyalty.

**Layer 2 — Goals & Activity selection (what):** the hero holds a few **goals** (e.g. "40 Mining", "afford rune platebody", "finish Demon Slayer"); each decision it generates candidate **activities** it *knows about and can do*, scores each by **utility**, picks the best feasible.
- *Utility* = expected reward (XP/gold/progress) × drive-relief − risk − time/travel cost, weighted by traits and **player incentives** (bounties/prices/posted quests raise relevant utilities).
- *Feasibility gates:* level/gear/gold/quest-prereqs; reachable (teleport unlocked / known location / within perception).
- *Activities:* TrainSkill(X), Fight(zone/monster), DoQuest(X), BuyUpgrade/Restock, SellLoot/UseGE, BankTrip, LootPile(seen), GoWild(risk/PK), Flee/Eat, Socialize/Trade, Rest/Idle.

**Layer 3 — Plans & Routines (how):** the chosen activity expands into a scripted **trip** mirroring OSRS play.
- *Gathering trip:* equip skilling preset → (bank tools/junk) → travel to node → gather until inventory full or interrupted → travel to bank → deposit → loop/re-eval.
- *Combat/boss trip:* equip combat preset → withdraw food+supplies → travel → fight (eat at HP threshold, use Prayer in danger) → loot → return → bank → restock.
- *Shopping/upgrade:* go to shop/GE → buy best affordable upgrade / post offers → equip → resume.

**Reactive interrupts (highest priority, checked each tick):** HP below threshold → eat/flee; inventory full → bank; PKer/strong threat perceived in Wild → flee or fight (by risk trait; PKer-types invert); high-value pile perceived → maybe divert (greed-weighted, perception-gated); **player command** → nudge (one-off high-priority activity) or seize (suspend brain).

### 18.2 Mirrors an OSRS player
Plays to its stats (won't attempt content above level; trains prereqs; chases affordable upgrades); supply-managed trips with banking; eat-at-HP / flee-the-stronger / pray-in-danger; goal-driven grind that sets a new goal on completion; buys upgrades when affordable, sells loot, uses the GE once unlocked.

### 18.3 Goals, Favorite Skill, Traits, Archetypes & Knowledge

**Long-term goal (shared by all heroes):** ✅ every hero ultimately aims to **level all skills to 99** (the reincarnation milestone, §5.7). So *eventually* everyone trains everything — but the **order and intensity** are individual, which is what diversifies the colony.

**Favorite skill / leaning (procgen individuality):** ✅ each hero is generated with a **favorite skill** (and often a secondary), e.g. Fishing+Cooking, melee combat, Magic, Mining+Smithing, Ranged. This bias means:
- They **spend disproportionate time** on their favorite(s) and reach high levels in them **first** → distinct silhouettes (a Fisher-Cook vs a Mage vs a Melee bruiser) using **different gear** at any given moment, not everyone in the same kit.
- They **still chip away** at non-favorite skills (toward the all-99 goal), but lower in their utility ranking → a long, natural tail of specialization before convergence.
- Implementation: the favorite applies a **utility multiplier** to that skill's training/earning activities (Layer 2, §18.1); secondary gets a smaller one. Tied to the **skill-aptitude** sliders below — favorite = highest aptitude.
- **Emergent realism:** at any snapshot the town is a believable mix of specialists (some fishing, some mining, some bossing) rather than a monoculture — and the economy benefits (natural division of labor → inter-hero trade, §16).

**Traits & sliders:** skill **aptitudes** (favorite = peak; shapes soft specialization, §9) · personality sliders: **risk tolerance, greed, ambition, sociability, patience/efficiency, loyalty(→town)**.

**Archetypes** emerge from favorite + trait combos (not hard classes): e.g. Skiller, PKer, Merchanter, Quester, All-rounder — now flavored by *which* skill they favor (a "Fisher", a "Mage", a "Slayer-grinder").

**Knowledge model (respects "must have seen it"):** *Common knowledge* — shops, banks, well-known resource sites (heroes know these like any player). *Discovered/transient* — a specific gravestone, a roaming monster, a PKer's presence; known only if perceived (radius / line of sight); can expire/be forgotten.

### 18.4 Dual-agency integration
- **Incentivize:** bounties/prices/stock/posted quests + loadout presets feed Layer-2 utility & Layer-3 loadouts — brain responds organically.
- **Nudge:** injects a high-utility one-off activity that wins the next decision (or interrupts now); hero then resumes autonomy.
- **Seize:** brain suspended; player drives; resumes on release.

### 18.5 Dual-resolvability (live + offline)
Each **Activity** carries both a **live routine** AND an **expected-yield/hour function** (XP, gold, items, supplies consumed). Offline catch-up = identify the current activity → project its yields over elapsed time × 75% (24h cap). Keeps live and offline consistent (Time keystone, §4).

### 18.6 Balance & robustness
- **Anti-thrash:** current activity gets a **stickiness/hysteresis** bonus; routines run to a natural break before re-eval — heroes commit to a "trip" (also human).
- **Decision cadence:** re-pick top activity periodically / on completion / on interrupt — not every tick (performant + human).
- **Anti-degenerate-optima:** aptitude diversity + **node congestion penalties** + **economy feedback** (everyone mining → ore price falls → mining utility falls) → specialization self-balances.
- **Performance:** spatially-indexed perception; throttled re-eval; ~50 agents comfortable.

🟡 **OPEN:** favorite-skill utility-multiplier magnitude (how strongly leaning skews behavior) + trait tuning weights.

---

## 19. Town & Facilities 🟡

The tycoon layer — what the player builds and upgrades. **Model: Hybrid (C).** Canon Varrock stays authentic (fixed NPC shops, banks, palace in canon spots) AND is **upgradeable**, plus the player adds **new structures** on open plots in/around the city (EHT / Dungeon Village "develop the settlement"). Building/upgrading drives **reputation → immigration** (§16) and hero **satisfaction**.

### 19.1 Bank capacity upgrade ✅
- **Town-wide** bank capacity: default **30 slots**, upgradeable to **150** (will expand later). Benefits **all heroes' personal banks**.
- **Stacking:** identical items share one slot with a quantity — stacks per **(item type × quality tier)** (Rune Scimitar [Standard] separate from [Fine]). Canon bank behavior, consistent with Floor+tiers (§11).

### 19.2 Shop leveling ✅ (designed divergence — "conceptually canon")
- Canon shops stay **open with their basic stock**; the player **invests to level a shop up to Lvl 99** (on-theme cap) using **gold + items** (higher tiers cost gold + higher-tier item inputs).
- **Per-level effects (scale with level):** faster **restock/respawn**; chance for **higher-tier items** to appear (stock slots roll above default tier — ties to Floor+tiers); larger **stock quantity**.
- A meaningful investment + a gold **and** item **sink** (healthy for the economy). 🟡 exact curves TBD.

### 19.3 Building catalog (player-placed structures)
Each building has a **build cost** (gold + materials, one-time), an **upkeep** (gold/day — the continuous economy sink, §6), and provides **utility + reputation + satisfaction**. Buildings are **upgradeable** (tiers) the same way shops level. Grouped by purpose:

| Building | Purpose / effect | Build + upkeep | Notes |
|---|---|---|---|
| **Hero Lodge / Housing** ★ | lets heroes *live in town* → raises retention, sets **respawn point**, +satisfaction; capacity per lodge | low→med | More lodges = more comfortable population near the 50 cap |
| **Inn / Tavern** ★ | rest & recover; social hub → relationship-building (§16); +satisfaction | low | EHT/Dungeon Village staple |
| **Training facilities** (dummies, range, altar) | small XP-rate or convenience boost for that skill in-town | med | Convenience, not a replacement for world training |
| **Production buildings** (smithy annex, cook's range, crafting hall) | enable/boost **crafting chains** (§ Economy §6) in town; material throughput | med | Feeds the gather→craft→enhance loop |
| **Enhancement Forge** ☆ | enables **Enhancement** (§5.6); higher tiers unlock higher quality-tier attempts | med→high | The "one more upgrade" sink |
| **Marketplace / GE annex** | unlocks/expands the **Grand Exchange** (post road-north unlock, §6) | high | Player-driven market access |
| **Decorations / amenities** (statues, gardens, fountains) | pure **reputation + satisfaction**, no function | low, low upkeep | The "make the town nice" lever → attracts higher-tier newcomers (§16) |
| **Access points** (Warriors' Guild teleport, etc.) | unlock/shorten travel to a zone | med | Ties to teleport gating (§8) |
| **Bank expansion** | the §19.1 capacity upgrade | gold + items | Town-wide |

🟡 *Exact costs/upkeep/tier curves TBD — tune as sinks against §6.*

### 19.4 Reputation & Satisfaction (the formulas) 🟡 proposed
Two related but distinct town meters:

**Town Reputation** (drives immigration, §16):
- `Reputation = Σ(building reputation values) + bonuses(decorations, cleared content, Chronicle milestones, defeated Zezimas) − penalties(recent kicks, hero deaths, unrest)`.
- **Effect:** higher reputation → **faster applicant arrival** AND **better newcomer rarity-tier odds** (§16) — a nicer, more famous town attracts more accomplished adventurers. This is the core tycoon payoff loop.

**Hero Satisfaction** (per-hero, drives retention + productivity):
- `Satisfaction = base + housing/amenity access + fair shop prices (§6) + successful activity (leveling, good loot) + positive relationships (§16) − overcharging − repeated deaths − idleness/unmet needs`.
- **Effects:** high satisfaction → hero **stays longer**, small **productivity/XP bonus**, loyalty to town (less likely to leave or vote chaotically); low satisfaction → **voluntary departure** (§16 capacity valve), poorer voting, eventual exit.
- **The key tension (ties to §6):** prices too high → satisfaction drops → heroes leave; amenities cost upkeep → you can't over-build. Balancing reputation-growth against the upkeep sink *is* the tycoon game.

### 19.5 Ties
- **Reputation → immigration & newcomer quality** (§16). **Satisfaction → retention & productivity.** **Upkeep → the economy sink** (§6). **Upgrades = Incentivize-tier** lever (shape what heroes can do without commanding them).

🟡 **OPEN:** exact build/upkeep costs & tier curves; reputation/satisfaction coefficients; building cap / town-plot layout (grid vs free placement).

---

## 20. UI — Hero Inspection & Command Panel 🟡 (panel = MVP)

Click any hero to open their panel — the primary window into a hero and the UI home of the **Nudge** and **Seize** tiers (§2). Surfacing a hero's inner state is what turns a black-box sim into a *readable* ant farm; it's cheap because the brain (§18) already computes this state.

### 20.1 Tabs
- **Stats:** 17 skills (levels + XP), combat level, HP, per-style equipment bonuses, gold, current location/activity.
- **Thoughts (★ standout):** live readout of the brain (§18) — current **goal** + **trip step**, the top utility-scored options it's weighing, and its **needs/drives** — rendered as natural-language thoughts: *"Inventory's full — heading to the east bank."* · *"This fight's going badly, I should run."* · *"Saving for a rune platebody — 12k short."* · *"That looks like a fresh gravestone…"* Makes the AI legible; doubles as a debug view.
- **Gear:** equipped loadout + 28-slot inventory + bank (§13); inspect, and via **Seize** equip/swap or set **loadout presets**.
- **Relationships:** friends/nemeses (social graph §16) — flavor + explains behavior.
- **Saga:** backstory + Chronicle milestones (§17) — who this hero *is*.

### 20.2 Influence / commands (Nudge & Seize UI)
- **Nudge (one-off):** Train [skill] · Fight [target] · Go on a Slayer task · Raid / go to [zone] · Go to bank · Buy [gear/supplies] · Recall to town · Rest. Hero executes, then **resumes autonomy** (§18.4).
- **Standing directives (per-hero Incentivize):** "prioritize Slayer," "avoid the Wilderness," "focus Mining," set a goal — biases utility without micromanaging.
- **Seize:** direct control (brain suspended; resumes on release).
- **Feasibility-aware:** options the hero can't currently do (Slayer below Combat 40 / no task pool, Raid with no unlocked zone, unaffordable gear) show **disabled with the reason** — teaches the gating systems.
- Also: **track/favourite** this hero (follow their saga); **initiate a kick vote** (§16).

### 20.3 Scope
- **MVP:** panel (Stats/Thoughts/Gear) + Nudge for available systems (Train/Fight/Bank/Buy) + Seize + track/kick.
- **Expands as systems unlock:** Slayer/Raid/zone commands appear with those systems; Relationships/Saga fill out with the social graph + Chronicle.

🟡 **OPEN:** exact panel layout; how much brain reasoning to expose; camera & town-build UI; incentivize dashboards; Chronicle viewer.

---

## 21. Tech & Data Foundations 🟡

How Claude Code builds it, and where the OSRS content comes from.

### 21.1 Data sourcing ✅ (the content engine — de-risked)
- **Primary source:** **osrsbox-db / its maintained `osrsreboxed` fork** — a complete, weekly-updated database of OSRS **items (~23,000), monsters, and prayers** as JSON, plus **20K+ item icon PNGs** keyed by item ID. Available as bulk JSON (items-complete.json, monsters-complete.json), a REST API, and a Python package.
- **Gives us directly:** item equipment stats + **level requirements**; monster **combat stats / attack speed / HP / drop tables / Slayer associations**; prayers; icons → exactly what combat (§10), gear (§12), Slayer (§15), loot (§11) need.
- **Pipeline:** at build time, ingest the JSON + icons into our **own local content DB**, mapping canon fields to our schema; custom layers (Floor+tiers §11, item abilities §12, AI §18, social §16) wrap the canon data. Verify freshest fork at build; fall back to the **OSRS Wiki** (authoritative living source) for anything stale.
- **GE prices:** not needed live (our GE is an internal simulated market); use canon **base/high-alch values** from the dataset as the value floor.

### 21.2 Engine & architecture 🟡
- **Lock: separate SIM CORE from RENDER/UI.** A deterministic, headless-runnable sim (ticks, agents, economy, combat) + a thin render/UI layer → enables dual-resolvability, offline catch-up, the LOD trick (§10.6), testability, clean save/load.
- **Agents:** component/ECS heroes (stats, inventory, brain §18, relationships §16); **0.6s tick** (matches combat §10); statistical mode for offline/LOD.
- **Persistence:** serialize world state (heroes, banks, relationships, town, chronicle) → save; offline catch-up on load (§11).
- **Engine: ✅ Godot 4 (GDScript/C#), desktop-first** — free, excellent 2D/pixel, lightweight, handles ~50 agents comfortably; mobile/web export kept open. (Alternatives considered: TS + PixiJS web; Unity; Bevy/Rust.)

**Formulas & data schemas:** all equations (XP curve, combat, AI utility function, economy, enhancement, reincarnation, reputation/satisfaction, social) + core entity schemas (Hero/Item/Monster/Town/Zone/Chronicle) live in companion **EQUATIONS_AND_SCHEMAS.md** — wired with placeholder `CONFIG.*` constants to tune.
🟡 **OPEN:** save format/serialization details.

### 21.3 Art direction & asset pipeline 🟡

- **Style:** pixel-art **2.5D isometric** view.
- **Directional sprites:** monsters and player characters need sprites for **8 facings** (up, down, left, right, and the four diagonals). *Full directional logic may come later;* for **prototyping**, generate placeholder/representative sprites (not boxes) — rough generated concepts of each item, monster, and a basic player look — for **all items and monsters**.
- **Asset generation (prototype):** auto-generate representative sprites/icons for the full item & monster set (canon icons from osrsreboxed §21.1 cover item inventory art; world/character/monster sprites are generated). Goal: a testable world that looks like *things*, not placeholders, even before final art.
- **Procedural character appearance (later, EHT-style):** extend procgen to player **looks** — hair style/colour, shirt & pant style/colour, facial hair style/colour (for applicable characters), etc. — so each generated hero is visually distinct (EHT is the reference). Layered/customizable sprite parts; ties to the procgen hero identity (§18.3).
🟡 **OPEN:** sprite resolution & layering scheme; 8-direction vs billboard during prototype; character part-set scope.



---

## 22. MVP Slice & Build Order ✅

The smallest coherent vertical slice that proves the concept: **"A Living Varrock" you can watch and steer.** Everything here is already designed above; this just draws the first-build line.

### 22.1 In the MVP
~10–20 procgen adventurers autonomously **gather → craft → fight → bank → trade → level** in canon Varrock + immediate surroundings, while you build/upgrade and steer.
- **World:** Varrock + immediate surroundings (§7); resource nodes for the included skills; **no teleport zones yet**.
- **Heroes:** procgen traits/archetypes (§18.3) + the full brain (§18); start cap ~10–20 (scale toward 50).
- **Skills (lean first cut):** combat set (Attack/Strength/Defence/Hitpoints/Ranged/Magic/Prayer) + a few gathering/artisan to show the loop — **Mining, Woodcutting, Fishing, Cooking, Smithing, Crafting**; rest of the 17 layer in after. **Slayer is mid-game → post-first-slice** by design.
- **Combat (§10):** OSRS-exact formulas, live + statistical, vs canon local monsters (rats, men, dark wizards at the stone circle) up to the **Varrock Sewers boss Scurrius**. Faithful curve + compression slider.
- **Economy:** NPC fixed-price shops + internal buy/sell; **GE locked** (post-MVP unlock).
- **Death (§14):** full death / 30s respawn / loot / perception-gated looting, live.
- **Town (§19):** build/upgrade basic facilities (bank capacity, shop leveling); population cap + reputation immigration + voluntary departure + the **kick vote** (§16).
- **Control:** all three tiers — incentivize (prices/stock/presets), nudge, seize.
- **Social (§16):** relationship graph running + minimal effects (trade prefs, kick-vote bias); full effects after.
- **Chronicle (lightweight):** ✅ **in MVP** — event log + per-hero milestones so the ant farm reads as *stories* from day one (§17).
- **Tech (§21):** Godot 4 desktop; osrsreboxed data ingested; sim/render separation.
- **Hero panel (§20):** click a hero → Stats/Thoughts/Gear + Nudge/Seize commands.

### 22.2 NOT in the first slice (post-MVP — already designed/queued)
Teleport zones & their content (Barrows, Kourend, Fight Caves/Inferno, raids); Slayer & partnering; endgame gear (Torva/Masori/Twisted bow/Kodai/…); the GE; reincarnation; quests; gear degradation; special attacks & full prayer book; full boss mechanics; Sailing & later skills.

### 22.3 Suggested build order (for Claude Code)
0. **Foundations:** data ingest (osrsreboxed → content DB), Varrock map + render, one hero in town. Sim/render split from the start.
1. **One skill loop:** brain + a gathering trip (mine → bank), with the dual-resolvable activity model.
2. **Combat:** tick combat + local monsters + death/respawn + the statistical "am I winning?" check.
3. **Economy & population:** NPC shops (buy/sell), multiple heroes, immigration; basic relationship graph.
4. **Player layer:** control tiers (incentivize/nudge/seize) + town building/upgrades (bank, shops).
5. **Story & society:** kick votes + social effects + the Chronicle.
6. **Polish/scale:** push toward 50 heroes, LOD, offline catch-up, save/load.

✅ first-cut skills confirmed; ✅ Chronicle in MVP. 🟡 minor: pull-earlier/later tweaks as building reveals.

---

## 23. Prototype Learnings (Phase-0 vertical slice) ✅

A runnable Phase-0 prototype (`prototype.html`) put the core systems on screen — autonomous utility-brain heroes, canon combat, and the food economy — to validate the riskiest assumptions before the full build. Findings:

**Validated (keep as designed):**
- **The utility brain works & reads as believable.** Heroes score activities (favorite-skill bias + congestion penalty + travel cost + trip-commitment stickiness) and visibly choose, commit to a trip, and re-decide. **No thrashing** observed — the stickiness/commit-to-trip rule (§18) is essential and confirmed.
- **Congestion spreading works** — when too many heroes pick the same node its utility drops and they diversify; the economy self-redistributes labor (§6/§18) with no scripting.
- **The Fisher→Cook→Warrior economy creates genuine emergent division of labor** — fishers supply food to the Market, warriors buy it before fighting, and a broke warrior auto-diverts to mining to earn food money. This loop (§6/§9) is the heart of the "ant farm" and it *works*.
- **The Hero Panel "Thoughts" readout is the legibility win** (§20) — being able to click a hero and read *why* they're doing something is what makes the colony watchable rather than opaque. Confirmed as MVP-critical.
- **The Chronicle carries the "stories" feel** even in lite form (§17) — milestone/sale/kill/flee events make the colony feel alive.

**Prototype simplifications (NOT the spec — the full design still stands):**
- No real banking (sold straight to shop); no quality tiers/enhancement; combat is melee-only & single-style; one monster type; gold faucets are **not** yet sink-balanced; XP compression exaggerated (×40) for watchability; movement is open-field (no pathfinding obstacles); "death" is a simple respawn stub.

**Open question the prototype made concrete:**
- 🟡 **Economy equilibrium (§6):** the gold sparkline trends upward (faucets > sinks) without the designed sinks wired in. This confirms the §6 sinks (GE tax, facility upkeep, enhancement, food demand) are *necessary*, not optional. Next economic iteration should wire them and tune to a stable total-gold curve.

**Takeaway:** the core fantasy is validated — believable autonomous heroes + a self-organizing economy + a readable story layer. The design is sound; remaining work is *tuning numbers* and *building breadth*, not rethinking the loop.

---

## 24. Onboarding & First-Time Experience 🟡

The sim is deep; a new player must grasp **watch → steer → build** without a wall of tutorials. Onboarding teaches by *doing*, framed by the dual-agency fantasy ("you're the town's unseen hand").

### 23.1 The first 10 minutes (guided, skippable)
1. **Arrival:** the player starts with a tiny Varrock and **1–2 starter heroes** already pottering (mining/fighting a rat) — the ant farm is *alive* immediately, before any instruction.
2. **Watch:** a prompt invites clicking a hero → the **Hero Panel** (§20) opens on the *Thoughts* tab ("see what they're thinking"). This single action teaches that heroes are autonomous and legible.
3. **Steer (Nudge):** guided prompt to *nudge* a hero to train a skill or fight — teaches Tier-2 control; hero complies then resumes autonomy.
4. **Build:** guided prompt to place/upgrade one facility (e.g. a Lodge or shop level) → shows reputation/satisfaction tick up → teaches the tycoon loop and that building attracts heroes.
5. **Incentivize:** set one shop price or post one bounty → teaches Tier-1 ("you're the central bank").
6. **First payoff:** a hero hits a small milestone → first **Chronicle** entry appears ("your colony's story begins").

### 23.2 Principles
- **Diegetic, not modal-heavy:** prompts point at the real UI; minimal blocking popups. Fully **skippable** for returning players.
- **Progressive disclosure:** advanced systems (Slayer, GE, teleport zones, enhancement, reincarnation, Zezima) surface **only when first unlocked** — each with a one-time contextual tip, not front-loaded.
- **The Chronicle is the teacher of *why*:** it narrates consequences so the player learns the sim by reading its stories.
- **Goal signposting:** the long-term goal (grow strong → defeat Zezima) is stated early but lightly, so there's direction without pressure.
🟡 **OPEN:** exact tip triggers & copy; tutorial length; whether a sandbox "first town" differs from normal start.

---

## 25. Save / Load & Persistence ✅ (schema-driven)

The sim state is large and persistent; saving serializes the world, loading restores it and runs offline catch-up (§4).

### 24.1 What a save contains (serialize the §12 schemas — EQUATIONS_AND_SCHEMAS.md)
- **Town:** reputation, treasury gold, populationCap, buildings[], shops[] (stock + levels), bankCapacity, geUnlocked, unlockedZones[], zezimaCount, monsterUnlockKills{}, postedBounties[]/tasks[].
- **Heroes[]:** full Hero schema each (skills+xp, traits, favorite skill, equipped/inventory/bank, gold, currentActivity/goal, knownLocations, reincarnationCount + echo mults, satisfaction, statusFlags, loadout presets).
- **Social graph:** sparse relationship entries (fromId, toId, score, lastUpdated) — decay computed lazily on load.
- **Item instances:** any non-stacked instances with qualityTier/affixes/charges/cosmetic.
- **Chronicle:** event log (capped/rolling) + per-hero saga milestones.
- **World/RNG:** resource-node states, active world events, RNG seed, **lastSavedTimestamp** (drives offline Δt).
- **Meta:** save schema **version** (for migration), CONFIG snapshot (so a save replays under its own balance).

### 24.2 Mechanics
- **Autosave** on a timer + on app close; manual save optional. Single primary save slot (idle-game convention) — 🟡 multi-slot TBD.
- **On load:** restore state → compute `Δt = now − lastSavedTimestamp` → run **offline catch-up** (§4: cap 24h, ×0.75, rares ×0.5, no deaths) → present a "while you were away" Chronicle summary.
- **Versioning:** on schema-version mismatch, run forward-migration; never hard-fail a save.
- **Format:** JSON (human-readable, debuggable) or a compact binary if size demands; Godot resource/`user://` storage (§21). Sparse storage for relationships & non-neutral state keeps saves small even at 50 heroes.
🟡 **OPEN:** exact serialization format & compression; multi-slot/cloud; save-size budget at 50 heroes.

---

## 26. IP / Legal Note

Varrock, the GE, NPCs, and "RuneScape" are **Jagex IP**. Fine for a personal/learning project; before public distribution consider keeping it private, reviewing Jagex's fan-content policy, or re-skinning to an original setting that preserves the mechanics.

---

## Roadmap — Still To Define

**Companion docs:** `ITEMS_MONSTERS_BALANCE.md` (gear ladders, situational mechanics, monster roster, acquisition) · `EQUATIONS_AND_SCHEMAS.md` (all formulas + data schemas) · `WORLD_AND_CHARACTERS.md` (NPC sheets, Varrock + region map blueprints, sprite/asset-generation reference).


**Parked for potential future implementation:**
- **World difficulty / ascension tiers** — scale world monsters up (with scaled rewards) as the colony matures; likely *per-region* difficulty gated by a colony **ascension level** driven by cumulative **reincarnation count** (+ items / cumulative level), while preserving safe early zones for new applicants & fresh reincarnations. Must be a canon-respecting multiplier layer (like item quality tiers), reward-scaling (no treadmill), and brain-aware (per-area/opt-in so weak heroes avoid it). *Deferred — revisit post-MVP.*


| Item | Status |
|---|---|
| Hero goals & specialization — ✅ all-99 long-term goal + procgen **favorite skill** leaning (build diversity, §18.3) | ✅ |
| Wilderness risk model — ✅ **A+B** (PvE + rival-adventurer PKers) | ✅ |
| Death system — ✅ 30s respawn, keep-counts (Protect Item/skull), PvP vs PvE visibility, local-perception looting; 🟡 open: 10% reclaim semantics, hasty reroll cadence | 🟡 |
| Population — cap (50), reputation-driven immigration, voluntary departure, exile→monster weighting | 🟡 |
| Civic vote quorum — ✅ Option A (majority of ballots cast, ≥25% quorum, void ≠ attempt) | ✅ |
| Friendship/Nemesis tuning — deltas, decay, effect curves, anti-runaway dampening | 🟡 |
| Item rolls — ✅ Floor + tiers (Standard/Fine/Pristine/Masterwork), fungible per tier, affixes auctioned; 🟡 per-tier bonuses TBD | 🟡 |
| Cooking — ✅ added to MVP (Fisher→Cook→Warrior food loop) | ✅ |
| Loadout preset details (Inventory & Presets) | 🟡 |
| Hero AI brain — ✅ architecture; ✅ trait sliders + archetypes (Skiller/PKer/Merchanter/Quester/All-rounder); 🟡 tuning | 🟡 |
| Slayer & Tasks — ✅ system + ✅ boss threshold (scale by difficulty); 🟡 minor: partner reward model, bonus-XP %, slayer-level gates | 🟡 |
| Combat — ✅ OSRS-exact formulas, dual-resolvable, triangle, LOD, ✅ pacing (faithful curve + 99 + 92-halfway, uniform compression slider); 🟡 advanced (specials/prayer book/boss mechanics) | 🟡 |
| Gear & Equipment roster — ✅ target list + phasing, ✅ Warriors' Guild req (canon Att+Str ≥130); 🟡 open: exact MVP cut, degradation/repair model, item-ability scope | 🟡 |
| Town & Facilities — ✅ hybrid model, bank/shop upgrades, ✅ building catalog (§19.3), ✅ reputation & satisfaction formulas (§19.4); 🟡 exact costs/curves, plot layout | 🟡 |
| Tech & Data — ✅ data source (osrsreboxed), ✅ sim/render separation, ✅ engine (Godot 4, desktop-first); 🟡 save format | 🟡 |
| Resource-node placement around Varrock (incl. Hunter grounds) | ⬜ |
| Economy & gold balance — ✅ faucets/sinks model, dual-market pricing, equilibrium logic, tunable levers (§6); 🟡 exact numbers + NPC gold model | 🟡 |
| Production/crafting chains — ✅ chain structure + MVP chains (§9.x); 🟡 exact recipes (dataset), per-step XP/time | 🟡 |
| Quests (canon Varrock quests as content) | ⬜ |
| Teleport unlocks & location-flow — ✅ canon access→gate map, ✅ full unlock progression (§8), 🟡 per-zone stat fill | 🟡 |
| God Wars Dungeon — ✅ zone package (Troll Country, killcount-40 gate, 4 generals, per-wing skill gates, §8.x + companion §10); 🟡 Nex wing later, stat snapshot | 🟡 |
| Godswords & god capes/stoles — ✅ blade+hilt build, specials, capes/stoles (companion §10); 🟡 validate stats/drop rates | 🟡 |
| Core loop & progression — ✅ loop + gated spine + balance levers, ✅ enhancement (§5.6), ✅ reincarnation (§5.7), ✅ **win condition: Zezima escalating rival** (§5.8); 🟡 magnitude/scaling tuning | 🟡 |
| UI — ✅ hero inspection & command panel (Stats/Thoughts/Gear + Nudge/Seize, §20); 🟡 camera, town-build UI, dashboards, Chronicle viewer | 🟡 |
| The Chronicle — ✅ in MVP (event log + per-hero sagas, notability-scored, §17) | ✅ |
| Onboarding & first-time UX — ✅ teach-by-doing flow + progressive disclosure (§23); 🟡 tip copy/triggers | 🟡 |
| Save/Load & persistence — ✅ schema-driven save contents + load/catch-up + versioning (§24); 🟡 format/compression, multi-slot | 🟡 |
| MVP slice — ✅ "A Living Varrock" + 7-phase build order (§22); Chronicle in | ✅ |

---
*Last updated: this session.*
