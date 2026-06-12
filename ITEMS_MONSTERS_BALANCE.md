# Gielinor Tycoon — Items, Monsters & Balance
> Companion to the Game Design Doc (operationalizes GDD §9 Items, §10 Gear, §8 Combat).
> **Source of truth for exact canon stats = the osrsreboxed dataset**, ingested at build; the **OSRS Wiki** is the validation fallback. This doc designs the **balance framework**, the **situational-mechanics layer**, and **curates the rosters**. Specific figures below are drawn from the OSRS Wiki and reflect a recent game state (post-2025 rebalances); anything uncertain is marked **(verify)**. Illustrative numbers are **≈**.

---

## 1. How balance works — the "highest tier ≠ always best" engine

Styles are balanced not by identical numbers but by three canon levers:
1. **Combat triangle** — Melee > Ranged > Magic > Melee; hitting a monster's weakness boosts accuracy/damage.
2. **Monster weaknesses** — most monsters are weak to one style, so the "best" style is target-dependent.
3. **Cost asymmetry** — melee ~free; **ranged burns ammo**; **magic burns runes** but buys utility/safety. Cost is both a balance lever and an economy sink.

**Design rule:** at every power tier, each style has a parallel option of comparable effectiveness *against the monsters it suits*. No style is globally dominant.

### 1.1 Situational mechanics (the heart of build diversity) — implement as CONDITIONAL MULTIPLIERS, not flat stats
| Mechanic | Condition | Effect |
|---|---|---|
| **Salve amulet (ei)** | target is **undead** | **+20% accuracy & damage all styles** (imbued melee/ranged +20%, magic +15% on the lesser tiers). **Overrides — does NOT stack with — Slayer helmet/black mask.** Stacks with Void. |
| **Slayer helmet (i) / black mask (i)** | hero is **on a Slayer task** for that monster | +16.67% melee accuracy & damage; **+15% ranged & magic** when imbued. (In-area only for Konar/Krystilia-style tasks.) |
| **Berserker necklace** | wielding an **obsidian melee weapon** | **+20% damage**; stacks with obsidian armour (+10%), Slayer helm, and Void. (Otherwise a *downgrade* — lowers accuracy/defence.) |
| **Brimstone ring** | magic attack | 25% chance per hit to **ignore 10% of the target's magic defence**. Rivals seers (i) for mage accuracy. |
| **Occult necklace** | magic | **+10% magic damage** — beats Fury/Torture for mage DPS (the only neck with a magic-damage %). |
| **Necklace of anguish / Amulet of torture** | ranged / melee | Pure-offence best-in-slot necks; beat the all-round Fury when you don't need its defence/prayer. |
| **Ava's device** | ranged, no metal torso | **72% (accumulator) / 80% (assembler)** ammo recovery — ranged sustain (a build-defining economy effect). |

**Non-stacking / priority rules to hard-code:** Salve **beats** Slayer helmet vs undead (don't stack). Slayer-helmet bonus only **on task**. Berserker necklace only matters **with obsidian**. These are what stop "just wear the highest tier" from always winning.

**Tuning benchmark:** if heroes always default to the highest-tier generic neck regardless of target, the situational multipliers are too weak — raise them until the right tool wins in its niche.

**Stat model (GDD §9):** canon item = **Standard** quality tier (the floor); Fine/Pristine/Masterwork roll above; items stack/trade fungibly per (type × tier).

---

## 2. Power-Tier Framework (the balance spine)

Each row ≈ equal power across the three columns (balanced via §1). ★ = MVP-era · ☆ = endgame.

| Tier | ~Req | Melee | Ranged | Magic |
|---|---|---|---|---|
| ★ T1 | lvl 1 | Bronze / Iron | Shortbow + bronze/iron arrows | Air/Mind Strike |
| ★ T2 | 5–10 | Steel | Oak shortbow + steel arrows | Wizard robes; Water/Earth Strike |
| ★ T3 | 20 | Mithril | Willow shortbow + mithril arrows | Basic staff; Bolt spells |
| ★ T4 | 30 | Adamant | Maple shortbow + adamant arrows | Battlestaff; Blast spells |
| ★ T5 | 40 | Rune | Yew shortbow + rune arrows; Green d'hide | Mystic robes; Wave spells |
| ★ T6 | 50 | Dragon weapons (Rune armour) | Magic shortbow; Blue d'hide; crossbows | God spells; mystic + god cape |
| ☆ T7 | 60 | Dragon armour; Obsidian | Red/Black d'hide; Rune crossbow | Surge spells; Trident-tier |
| ☆ T8 | 70 | Barrows; Bandos | Karil's; Armadyl; crystal | Ahrim's; god staves |
| ☆ T9 | 75+ | Torva | Masori | Ancestral-equivalent |
| ☆ Cap | high | top melee weapon line | **Twisted bow** | **Kodai wand** + top staff |

---

## 3. Accessory & Jewelry Ladder

★ = MVP-era · ☆ = endgame. Exact bonus values = dataset.

### 3.1 Amulets / Necklaces (neck slot)
| Item | Source / req | Bonuses | Situational |
|---|---|---|---|
| ★ Amulet of strength | ruby, 49 Mag enchant | +10 Str, +10 melee att | Cheap max-hit neck vs low-def targets |
| ★ Amulet of power | diamond, 57 Mag | balanced att/def, +6 Str | Best all-round early/F2P neck |
| ★ Amulet of glory | dragonstone, 80 Craft | +10 att, +6 Str, +3 pray, +3 def | **Teleports** (Edgeville/Karamja/Draynor/Al Kharid); boosts mining gem table; Eternal = unlimited tele |
| ☆ Amulet of fury | onyx, 87 Mag | +10 att, +8 Str, +15 def, +5 pray | Jack-of-all-trades; great for long/dangerous trips |
| ☆ Amulet of torture | zenyte, 93 Mag, 75 HP | +15 melee att, +10 Str | **Best melee DPS neck** (no defence) |
| ☆ Necklace of anguish | zenyte | +15 ranged att, +5 ranged Str | **Best ranged neck** |
| ☆ Occult necklace | smoke devil drop, 70 Mag | +12 mag att, **+10% magic dmg** | **Best mage-DPS neck** |
| ★–☆ **Salve amulet (e/i/ei)** | Haunted Mine (+ Tarn miniquest / imbue) | +16.67%→**+20% vs undead** | The headline situational item; overrides Slayer helm vs undead |
| ☆ Berserker necklace | onyx | (no att/Str; lowers def) | **+20% dmg only with obsidian weapons** |
| ☆ Amulet of the damned | Shade Catacombs | glory-like | Buffs full Barrows set effects; degrades, lost on death |

### 3.2 Rings
| Item | Source | Bonus | Situational |
|---|---|---|---|
| ☆ Berserker ring | Dagannoth Rex | +4 Str (imbued +8) | Melee max-hit ring |
| ☆ Warrior / Archers / Seers ring | Dagannoth Kings | +4 (imbued +8); seers(i) also +0.5% mag dmg | Per-style accuracy/def rings |
| ☆ Ring of suffering | zenyte, 93 Mag | +10 def, +2 pray (imbued ×2) | Best defensive ring; (r) recoil charge |
| ☆ Brimstone ring | Alchemical Hydra parts | mixed att/def | 25% chance ignore 10% target mag def |
| ★ Ring of wealth | dragonstone | — | Imbued: Wildy clue rate ×2, better rare-table access (not unique rates) |
| ★ Ring of dueling | emerald | — | Teleports: Arena/Castle Wars/Ferox |
| ★ Ring of recoil | sapphire | — | Reflects 10%+1 dmg (40 HP then shatters) |
| ★ Explorer's ring | Lumbridge/Draynor Diary | — | Cabbage tele, free low-alchs, run-energy restore |
| ☆ Ring of the gods | Vet'ion | +1 def, +4 pray | Imbued: stronger prayer |
| ☆ Tyrannical / Treasonous | Callisto / Venenatis | +8 crush / +8 stab att+def | Treasonous pairs with dragon warhammer spec |

### 3.3 Capes
| Item | Source | Bonus | Situational |
|---|---|---|---|
| ★ Skillcapes (99) | level 99 | +9 att/def (style varies) | Unique per-skill perk |
| ★ Obsidian cape | TzHaar shop | +9 def, +1 pray | Cheap defensive cape |
| ★ Ava's attractor/accumulator | Animal Magnetism (no-quest gate in MVP) | small/+4 ranged att | **72% ammo recovery** (accumulator) |
| ☆ Fire cape | TzTok-Jad (Fight Caves) | strong melee | **Required to enter the Inferno** (sacrificed) |
| ☆ Infernal cape | TzKal-Zuk (Inferno) | +8 Str, +12 all def | **Best melee cape** |
| ☆ God capes (Sara/Guthix/Zamorak) | Mage Arena I, 60 Mag | +10 mag att | Charge spell w/ matching god staff |
| ☆ Imbued god cape | Mage Arena II, 75 Mag | +15 mag att/def, **+2% mag dmg** | Best mage cape |
| ☆ Ava's assembler | Dragon Slayer II + Vorkath head, 70 Rng | +8 ranged att, +2 Str | **80% ammo recovery; never drops ammo** |
| ☆ Dizana's quiver | Fortis Colosseum, 75 Rng | best ranged att, +2 pray | Stores ammo; Sunfire adds accuracy/Str |
| ☆ Max cape | 99 all | +9 att, +4 pray | Inherits assembler ammo-saving w/ Vorkath head |

### 3.4 Helmets & on-task utility
| Item | Source / req | Effect |
|---|---|---|
| ☆ Black mask | Cave horror; 40 CB | +16.67% melee on task; Def-reducing charges |
| ☆ Black mask (i) | imbue | + on-task +15% ranged & magic |
| ★–☆ Slayer helmet | 55 Craft + 400 Slayer pts | combines mask + sense gear; +16.67% melee on task; full-helm defence; **recolours/skins** (1,000 pts each) |
| ☆ Slayer helmet (i) | imbue | + on-task +15% ranged & magic. **Salve overrides vs undead; stacks with Berserker+obsidian** |

---

## 4. Core gear progression per style (the weapon/armour spine — MVP ★)
| Style | Early → mid (MVP) | Notes |
|---|---|---|
| **Melee** | Bronze→Rune scimitar/platebody/legs/helm/shield → Dragon weapons (Att/Def 1/5/20/30/40/60) | Defenders from Warriors' Guild (Att+Str ≥130, canon) |
| **Ranged** | Shortbow→Yew shortbow + arrows; crossbow + bolts; Leather→Studded→Green d'hide (Rng 1→40) | **Ammo cost = balance/sink**; Ava's recovers it |
| **Magic** | Elemental staff→Battlestaff; Wizard→Mystic robes; Strike→Bolt→Blast→Wave (Mag 1→65) | **Rune cost = balance/sink**; battlestaffs give free element runes |

---

## 5. Monster Roster by Region
Columns: ≈Cmb · ≈HP · attack style · **weakness (use this)** · aggro · **undead?** (Salve applies) · Slayer · notes. ★ = MVP region.

### 5.1 ★ Varrock ring
| Monster | ≈Cmb | ≈HP | Style | Weakness | Undead? | Notes |
|---|---|---|---|---|---|---|
| Chicken / Rat / Cow / Man-Woman / Goblin | 1–13 | 2–12 | melee | any | no | Starter XP + economy feeders (cowhide→leather, feathers) |
| Zombie (sewers/Stronghold) | 13–53 | ~22–30 | melee | fire ~50% | **YES** | Salve works |
| Dark wizard (7 / 20) | 7 / 20 | ~15 / ~30 | **magic** | **ranged** | no | Stone Circle (S gate); Demon Slayer/Delrith |
| Guard | ~21 | ~22 | melee | melee/ranged | no | Palace |
| Flesh Crawler / Minotaur / Catablepon / Ankou | 28–~75 | varies | melee | any | Ankou=**YES** | Stronghold of Security; skull-sceptre parts |
| **Scurrius (BOSS)** | ~250 *(designed CB 60–90)* | 500 solo | melee+ranged+magic | rat-bone weapons +10 max hit | no | **MVP first boss**; drops Scurrius' spine |

### 5.2 ★ Al Kharid
| Monster | ≈Cmb | ≈HP | Style | Weakness | Undead? | Notes |
|---|---|---|---|---|---|---|
| Al Kharid warrior | 9 | 18 | melee | any | no | High HP/low CB → F2P melee training |
| Scorpion | 14 | — | melee | any | no | Mine |
| Desert strykewyrm | 103 | — | melee/magic | — | no | 77 Slayer |

### 5.3 ☆ Morytania (undead focus — Salve relevance)
| Monster | ≈Cmb | ≈HP | Style | Weakness | Slayer | Undead? | Notes |
|---|---|---|---|---|---|---|---|
| Crawling hand | 8 | 16 | crush | none | 5 | **YES** | Lowest Slayer-Tower undead |
| Banshee | 23 | 22 | magic | air spells | 15 | **YES** | Earmuffs needed |
| Aberrant spectre | 96 | 90 | magic | air spells | 60 | **YES** | Nose peg needed |
| Bloodveld | 76 | 120 *(verify)* | magic-melee | demon (demonbane) | 50 | NO | |
| Gargoyle | 111 | 105 | slash | crush + magic | 75 | NO (golem) | Finish w/ rock hammer ≤9 HP |
| Nechryael | 115 | 105 | crush | demon | 80 | NO | |
| Abyssal demon | 124 | 150 | stab | demon | 85 | NO | **Whip 1/512** |
| Ghoul | 42 | — | melee | any | — | **NO — alive!** (Salve does NOT work) | Common gotcha |
| Ghast | varies | — | rots food | — | — | NO (wiki excludes) | Druid pouch to see |
| Feral Vampyre / Vyrewatch (Sentinel) | 61–151 | ~30–150 | melee | flail only (ivandis/blisterwood) | Vampyres | NO | Sentinel: blood shard 1/1500 |
| **Grotesque Guardians (BOSS)** | Dusk 246 / Dawn 228 | 450 ea | Dusk melee / Dawn ranged | Dusk earth (melee) | 75 | NO (golem) | Slayer Tower roof |

### 5.4 ☆ Karamja
| Monster | ≈Cmb | Weakness | Undead? | Notes |
|---|---|---|---|---|
| Harpie bug swarm | 46 | needs lit bug lantern to damage | no | 33 Slayer + 33 FM |
| Jogre / Death wing | 53 / 83 | any | no | Bat Slayer task |
| Metal dragons (bronze/iron/steel) | 139/189/246 | — (antifire) | no | Brimhaven Dungeon |
| TzHaar (Fight Caves / Inferno) | various | — | no | TzTok-Jad→fire cape; TzKal-Zuk→infernal cape |

### 5.5 ☆ Wilderness (live-only; PvP risk)
| Monster | ≈Cmb | ≈HP | Weakness | Undead? | Notes |
|---|---|---|---|---|---|
| Revenants | up to ~135 | varies | — | **YES** | Revenant weapons; ether |
| Callisto / Artio (BOSS) | 470 / lower | high | — | no | Artio drops Voidwaker hilt |
| Venenatis / Spindel (BOSS) | 464 / — | 850 / 515 | ranged | no | Voidwaker gem |
| **Vet'ion / Calvar'ion (BOSS)** | — | 1,110 / lower | **crush; UNDEAD → Salve works** | **YES** | High-end Salve use case; ring of the gods |
| Chaos Fanatic / Crazy Archaeologist / Scorpia | mid–high | — | — | no | Solo Wildy bosses |

### 5.6 ☆ Great Kourend (Zeah)
| Monster | ≈Cmb | ≈HP | Weakness | Slayer | Undead? | Notes |
|---|---|---|---|---|---|---|
| Sand Crab | 15 | 60 | any | — | no | Premier AFK training (max hit 1) |
| Lizardman / brute / **shaman** | 53–150 | 60–150 | shaman: **stab & ranged** | 75-pt unlock | no | Shaman drops **Dragon warhammer** |
| Wyrm / Drake / Hydra | 97/192/194 | 120/225/300 | earth spells; dragonbane | 62/84/95 | no | Karuulm; dragon harpoon/sword, boot upgrades |
| **Sarachnis (BOSS)** | 318 | 400 | **crush** | none | no | Cudgel 1/384 |
| **Alchemical Hydra (BOSS)** | 426 | 1,100 | **ranged**; dragonbane | 95 task-only | no | Claw→dragon hunter lance; leather→ferocious gloves |
| Catacombs of Kourend | varies | varies | varies | varies | Ankou=**YES** | Dark beast, hellhound, greater nechryael, brutal black dragon; shared totem table |

### 5.7 Region progression ladder (difficulty spine via Slayer gates)
Varrock ring + Al Kharid (CB 1–60, no gates) → Karamja low + Stronghold (mid) → Morytania Slayer Tower (Slayer 5→15→50→60→75→80→85→124 CB) → Zeah Karuulm + Wilderness bosses (CB 150–426). The Slayer-level gates (**5 → 15 → 50 → 60 → 75 → 80 → 85 → 95**) double as a reusable difficulty curve.

### 5.8 The undead tag (drives the Salve path)
Tag every monster `undead: bool` at data entry. **Gotchas:** Vet'ion/Calvar'ion ARE undead (Salve works at the high end); **ghouls and ghasts are NOT** undead (common misconception — Salve/Crumble Undead do nothing). Generic skeletons/ghosts/zombies/revenants/Ankou = undead.

---

## 6. Custom layers (recap — GDD)
Quality tiers (Standard→Fine→Pristine→Masterwork, §9); passives/actives + spec energy (§10); degradation/repair (Barrows/Torva/DFS); cosmetic trims/skins; Slayer-helm recolours.

## 7. How exact numbers get filled
Build-time ingest osrsreboxed → our schema (item equipment stats + level reqs; monster combat stats, attack speed, HP, weaknesses, drop tables, **undead flag**). This doc supplies **selection + balance + situational mechanics + roles**; the dataset supplies **values**; OSRS Wiki validates.

## 8. Validation checklist (resolve before ship)
- **Post-rebalance figures:** several HP/CB reflect 2025 "Project Rebalance / Summer Sweep Up" (e.g., Wyrm 130→120, Drake→225, elemental weaknesses added). Confirm current values.
- **Verify exact CB/HP:** Bloodveld HP 120; dark beast 182/220; warped jelly ~135/187; Feral Vampyre L61 HP; Rotting zombie, Ghast, Bryophyta, Catablepon; Callisto post-rework HP.
- **Ghast undead status:** official wiki **excludes** ghasts (Salve off); some third-party lists disagree — follow the official wiki.
- **Seers (i):** raises magic damage to **+0.5%** (the "+0.3%" elsewhere is the *increase*).
- **God-book per-book stats** not individually pulled — verify each.
- **Drop rates** are version-specific/indicative, not authoritative.

---
*Companion to GAME_DESIGN_DOC.md. Last updated: this session (incorporates OSRS Wiki research pass).*

---

## 9. God Wars Dungeon — Generals & Gear (mid-to-endgame)
*Location: Troll Country N of Trollheim (canon — not the Wilderness). Entry 60 Str/Agi; killcount 40 per wing (resets on leaving); per-wing gates Bandos 70 Str / Saradomin 70 Agi / Armadyl 70 Rng / Zamorak 70 HP. **Boss stats are version-dependent → pull exact values from the dataset at a snapshot patch date; figures below are indicative (verify).***

### 9.1 The four generals
| General (God) | ≈Cmb | ≈HP | Attack styles | Pray vs | Best style | Weakness |
|---|---|---|---|---|---|---|
| **Kree'arra** (Armadyl) | 580 | ~255* | Ranged + magic + melee (flies — *immune to most melee*) | Missiles | **Ranged** | Air spells ~30% |
| **General Graardor** (Bandos) | 624 | ~255* | Crush melee + ranged slam (15–35) | Melee | Melee/Ranged | Earth ~40% *(2025 — verify)* |
| **Commander Zilyana** (Saradomin) | 596 | ~255* | Fast (2-tick) melee + magic | Magic (kite) | **Ranged** | (ice/ZGS freeze) |
| **K'ril Tsutsaroth** (Zamorak) | 650 | ~255* | Slash melee + magic + **prayer-smash special** (hits through prayer, drains prayer) | Melee or Magic | Melee/Ranged | Water ~30% *(2024 — verify)* |
*Each has 3 bodyguards (≈cmb 139–159, HP ~120–162) of mixed styles — kill order matters. \*Wiki infoboxes read HP 255 for all four; effective tankiness is in their defences, not HP.*

**Why they fit our combat systems:** each general forces a *specific* prayer + style — a perfect live showcase of the combat triangle (§9) and the brain's "bring the right tool" logic. Kree'arra (melee-immune) *requires* ranged; K'ril punishes lazy prayer. Great Slayer-partner content (§14).

### 9.2 Drops (canon rates — verify at build)
- **Godsword shards** 1, 2, 3 — ~1/762 each (~1/254 any) from every general + bodyguards.
- **Hilts** (general-only, ~1/508): Armadyl / Bandos / Saradomin / Zamorak.
- **Armour:** Armadyl set (helm/chest/skirt), Bandos set (chest/tassets/boots) — ~1/381 each piece.
- **Uniques:** Saradomin sword & Armadyl crossbow (Zilyana); Zamorakian spear, Staff of the dead, Steam battlestaff (K'ril). Pets 1/5,000.
- *(Nex wing — Ancient hilt, Torva — slated later.)*

### 9.3 Godswords (top-tier ☆ melee weapon line)
**Build:** smith shards 1+2+3 → **Godsword blade** (**80 Smithing**), then attach any **hilt** (swappable freely). **75 Attack** to wield; **+132 Slash / +132 Strength**, +8 Prayer; 2h, speed 6. *All variants share these base stats — they differ only by special attack (50% spec energy, doubled accuracy):*
| Godsword | Hilt from | Special — effect |
|---|---|---|
| **Armadyl (AGS)** | Kree'arra | +~37.5% max hit — biggest burst |
| **Bandos (BGS)** | Graardor | +21% dmg; drains target stats (Def→Str→Pray→Atk→Mag→Rng) by damage dealt |
| **Saradomin (SGS)** | Zilyana | +10% dmg; heals 50% of dmg as HP, 25% as Prayer (min 10/5) |
| **Zamorak (ZGS)** | K'ril | +10% dmg; **freezes** target 19.2s (Ice Barrage duration) |
| *Ancient (later)* | *Nex* | *+10% dmg; delayed 25 dmg if target doesn't move; heals 15%* |

These sit at the **capstone melee tier** (§2) alongside the other top weapons; their *utility* (heal / freeze / stat-drain / burst) gives build variety beyond raw DPS — reinforcing "highest tier ≠ only choice" (§1.1).

### 9.4 God capes & stoles (magic + prayer)
| Item | Source / req | Bonus |
|---|---|---|
| ☆ God cape (Sara/Guthix/Zamorak) | Mage Arena I, **60 Mag** | +10 Magic attack (statistically identical; alignment matters only in GWD); buy from Perdu ~250k once unlocked |
| ☆ Imbued god cape | Mage Arena II, **75 Mag** | +15 Mag attack, +15 Mag def, **+2% magic damage** — best mage cape |
| ☆ God stoles (vestment) | Treasure Trails; **60 Prayer** | high amulet-slot **Prayer** bonus; counts as god item in GWD *(exact OSRS Prayer value — verify; the +10 floating online is the old RS3 figure)* |
| ☆ Vestment robes / god books | clues / Horror from the Deep | Prayer-bonus prayer-armour set; god books +5 Prayer (+ effects when completed) |

🟡 **Validate at build (version-dependent):** Graardor Earth weakness (2025), K'ril Water weakness (2024) & defence changes, exact boss HP/defences, god-stole Prayer bonus, all drop rates. Snapshot a target OSRS patch date and pull from the dataset.

---

## 10. Item Acquisition — Craftable vs Drop-Only vs Hybrid
*Every item carries an **acquisition type** (a data field). Craft levels & drop rates come from the dataset at build; figures below are canon-anchored with **(verify)** on anything version-dependent. This is the rule Claude Code applies to tag the full item set.*

### 10.1 The three archetypes (the core rule)
1. **Craftable** — made entirely from a skill + materials (the player-made spine).
2. **Drop-only** — no creation path; obtained by killing a specific monster/boss (or shop/quest for some dragon weapons).
3. **Hybrid / assembly** — a **boss-dropped component** finished with a **skill step** (the most-confused category — tag BOTH the drop source/rate AND the craft skill+level).

### 10.2 Decision tree (apply to every item)
1. Standard tiered metal (bronze→rune)? → **Craftable (Smithing)** at the tier breakpoint. *Exception: **black & white armour are NOT craftable** — drop/shop only.*
2. Dragonhide/leather body, gem jewellery, standard bow/arrow, or rune? → **Craftable** (Crafting/Fletching/Runecraft) — but inputs (hides, gems, essence) are drops/gathered.
3. Dragon / Barrows / GWD / Nex / DKS / raid / boss unique? → **Drop-only** (dragon *weapons* may be shop/quest).
4. Boss component + skill step? → **Hybrid** (flag both).

### 10.3 Craftable spine (skill + level)
| Line | Skill | Level breakpoints |
|---|---|---|
| Metal armour/weapons | Smithing | Bronze 1 · Iron 10 · Steel 20 · Mith 30 · Addy 40 · **Rune med helm 88, rune body/legs/skirt/2h 99** |
| Dragonhide bodies | Crafting | Green **63** · Blue **71** · Red **77** · Black **84** (leather/studded lower) |
| Gem jewellery | Crafting (+Magic to enchant) | Dragonstone (glory) **80** · cut zenyte **89** · amulet of torture **98**; anguish/suffering/bracelet ~92–95 *(verify)* |
| Bows / arrows / bolts | Fletching (bolts also Smithing) | per-item *(verify)* |
| Runes | Runecraft | per-rune |
*Black/white armour: **not craftable.***

### 10.4 Drop-only & hybrid — canon rates (anchor values; verify at build)
| Item | Type | Source → rate |
|---|---|---|
| Barrows piece (any set) | Drop-only | Barrows chest: **specific ≈1/350**, **any piece ≈1/15 per chest** (all 6 killed) |
| Bandos chestplate/tassets/boots | Drop-only | Graardor: **1/381 specific, 1/127 any** |
| Godsword **shards** | Drop-only | GWD generals **~1/762 specific / 1/254 any** |
| Godsword (blade) | **Hybrid** | shards 1+2+3 → blade (**Smithing 80**) + hilt (**~1/508** drop) |
| Torva (helm/body/legs) | **Hybrid** | Nex drop (~1/258 effective, verify) → repair (**Smithing 90** for platebody) |
| Abyssal whip | Drop-only | Abyssal demons **1/512** (85 Slayer) |
| Dragon boots | Drop-only | Spiritual mages **1/128** |
| Dragon scimitar | Shop/drop | Ape Atoll shop 100k (MM1); Scorpia 1/128 |
| Dragon weapons (dagger/long/mace/baxe/halberd) | Shop/quest | Zanaris/guild shops; quest-gated |
| Dragon 2h / med helm / chainbody / platelegs | Drop-only | various dragons/bosses (~1/128–1/512 by source) |
| **Dragon platebody / kiteshield / sq shield** | **Hybrid** | dropped halves/components → anvil/Dragon Forge (**Smithing 60–90**) |
| Dragonfire shield | **Hybrid** | Draconic visage (rare drop) + anti-dragon shield (**Smithing 90**) |
| Dragon defender | Drop (minigame) | Warriors' Guild cyclopes, **~1/100** sequential |
| Dragon hunter lance | **Hybrid** | Hydra claw (Alch. Hydra **1/1,000**) + Zamorakian hasta. *(NOT a Skotizo drop — common myth)* |
| Dagannoth Kings rings (zerk/warrior/seers/archers) | Drop-only | each King **1/128** |
| Zenyte shard | Drop-only | Demonic/tortured gorillas **1/300** (post-MM2) → feeds craftable jewellery |
| Occult necklace | Drop-only | Smoke devils **1/512** / Thermy **1/350** |
| Kodai wand | **Hybrid** | Kodai insignia (CoX mega-rare) + master wand |
| Trident(s) | **Hybrid** | Kraken/Cave kraken drop → charge with runes; swamp variant +Crafting 59 |
| Elidinis' ward | **Hybrid** | Broken ward (ToA) + Arcane sigil (**Prayer 90 + Smithing 90**) |
| Twisted bow / Masori | Drop-only (raid) | CoX / ToA — **points/raid-level system, not a flat rate** (model expected *raids*) |
| Crystal armour/bow | **Hybrid (sing)** | Gauntlet seed + crystal shards (Smithing+Crafting; SotE) |
| Dizana's quiver | Reward | Fortis Colosseum completion |
| Ava's accumulator/assembler | Quest + assembly | Animal Magnetism / DS2 + materials |

### 10.5 How this plugs into our systems
- **Crafting chains (§9.x)** produce the *craftable* spine; **drop tables** (combat, §10) produce the *drop-only* tier; **Enhancement (§5.6)** and hybrid assembly both consume drops + skill steps → all four loops share materials.
- **Economy (§6):** drop-only endgame gear is the **GE's high-value trade** (heroes who can't farm it buy it); craftable gear is the steady artisan supply. This is *why* the GE matters at endgame.
- **No-quest gating (§3):** quest-locked items (dragon weapons, Ava's, crystal, etc.) use our level+item+kill gates until quests exist.
- **Raid uniques** use a **points/raid-completion** drop model, not flat per-kill — flag for the combat/statistical resolver (§10).

🟡 **Validate at build (from dataset/wiki):** all drop rates & craft levels flagged (verify); raid unique-table math; Nex/Torva current per-piece rate; godsword shard 1/762 vs historical 1/768; bow/bolt Fletching levels.
