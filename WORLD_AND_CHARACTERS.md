# Gielinor Tycoon — World & Characters Blueprint
> Companion to the GDD. The **visual reference layer**: NPC character sheets, map blueprints, and asset-generation notes to feed sprite/world art creation.
> Art target (GDD §20.3): **2.5D isometric, pixel art, 8-direction sprites**. Appearance notes below are written to guide an AI image/sprite generator. Canon-accurate; layout from the OSRS Wiki. Item/monster sprites primarily come from osrsreboxed icons (§21); world/character sprites are generated.

---

## 1. Main Varrock NPC Character Sheets
Each NPC: role · location · in-game function · **appearance brief** (for sprite generation). NPCs are **fixed canon residents** (the authored layer, GDD §3) — distinct from the procgen heroes.

| NPC | Role | Location | In-game function | Appearance brief (sprite) |
|---|---|---|---|---|
| **King Roald** | Monarch of Misthalin | Varrock Palace throne room (centre-N) | Flavor/lore; quest-giver later | Middle-aged king, red & gold robes, gold crown, brown beard, regal posture |
| **Aubury** | Rune merchant / Runecraft | Aubury's Rune Shop (SE corner) | Sells runes; teleport to Rune Essence mine (Runecraft access) | Elderly wizard, blue robes, pointed hat, long white beard, staff |
| **Horvik** | Armourer / Smith | Horvik's Armour Shop (centre, NW of east bank; has anvil) | Sells/【buys】 plate & chain armour; anvil access | Burly smith, leather apron over tunic, soot-smudged, short dark hair, muscular |
| **Zaff** | Staff merchant | Zaff's Superior Staffs (NW of central plaza) | Sells staves & battlestaves (Magic) | Lean shopkeeper, blue/purple robes, neat, holding a staff |
| **Lowe** | Archery merchant | Lowe's Archery Emporium (W side, near west bank) | Sells bows, crossbows, ammo (Ranged) | Tall thin man, green/brown ranger garb, quiver, stern face |
| **Thessalia** | Clothier | Thessalia's Fine Clothes (N of swordshop, W of general store) | Sells clothing; **free appearance change** (ties to char customization §20.3) | Middle-aged woman, fine green dress, apron, hair in a bun |
| **Apothecary** | Potion-maker | The Apothecary (S of west bank) | Sells/【makes】 strength & energy potions (consumables, buy-only MVP §10) | Old scientist, stained lab robe, wild grey hair, round glasses |
| **Baraek** | Fur trader | Fur stall, Varrock Square (centre) | Buys/sells fur; Shield of Arrav hook | Stocky stall-keeper, brown vest, flat cap, gruff |
| **Gypsy Aris** | Fortune teller | The Gypsy's Tent (central plaza) | Demon Slayer quest hook; flavor | Older woman, colorful headscarf & shawl, hoop earrings, crystal ball |
| **Reldo** | Palace librarian | Varrock Palace library (W wing) | Lore/research; quest info | Bookish man, brown scholar robes, balding, holding a book |
| **Museum Curator** | Curator | Varrock Museum (SE, near east bank) | Shield of Arrav; museum/collection flavor | Elderly gentleman, formal suit, monocle, white moustache |
| **Shopkeeper** | General store | Varrock General Store (E of gypsy tent) | Buys/sells general goods | Plain apron over tunic, friendly, average build |
| **Swordshop clerk** | Melee weapons | Varrock Swordshop (SW of general store) | Sells swords/daggers (melee) | Working-class clerk, leather jerkin |
| **Vannaka** | Slayer Master | **Edgeville Dungeon** (W cluster, not Varrock) | Assigns Slayer tasks (Combat 40 gate, §15) | Tall armoured warrior, full helm, battle-worn plate, imposing (he's a high-level NPC) |

*Note:* Naff (Zaff's assistant, battlestaves) and Iffie/Iffi (Thessalia's relative) are minor and optional.

---

## 2. Varrock Map Blueprint (ASCII layout — for the visual map)
Top = North. Canon-accurate relative positions. This is the **home-city base map**; the AI map-art generator should treat this as the spatial blueprint.

```
                        ╔════════ N (North Gate → Wilderness road / GE NW) ════════╗
                        ║                                                          ║
                        ║              ┌──────────────────────┐                    ║
                        ║              │   VARROCK PALACE       │                   ║
                        ║   [Reldo/    │  (King Roald, throne,  │                   ║
                        ║    library]  │   altar, courtyard)    │                   ║
                        ║              └──────────────────────┘                    ║
                        ║   ┌─────────┐         ┌──────────┐        ┌────────────┐  ║
   W (West Gate         ║   │ WEST    │  [Zaff's Staffs]   │        │ Varrock     │  ║   E (East Gate →
   → Barbarian Village, ║   │ BANK    │         │ CHURCH/  │        │ MUSEUM      │  ║   Digsite / Al Kharid
   Gunnarsgrunn,        ║   └─────────┘  ┌────────┐ chapel │        │ (Curator)   │  ║   crossroads;
   River Lum fishing)   ║   [Anvils S    │CENTRAL │  (NE)  │        └────────────┘  ║   yew trees E)
                        ║    of W bank]  │ PLAZA / │        │   ┌──────────┐         ║
                        ║   [Apothecary  │ SQUARE  │ [Gen.  │   │ EAST BANK │         ║
                        ║    S of W bank]│ Baraek  │  Store]│   └──────────┘         ║
                        ║   [Lowe's      │ fur,    │        │   [Aubury's Rune Shop  ║
                        ║    Archery W]  │ Gypsy   │ [Horvik│    + Zamorak/chaos     ║
                        ║                │ tent]   │  Armour│    altar — SE corner]  ║
                        ║   [Thessalia   └────────┘  +anvil]│   [Varrock Sewers      ║
                        ║    Clothes]   [Swordshop SW         │    entrance — manhole] ║
                        ║                of Gen. Store]                              ║
                        ║                                                           ║
                        ╚════════ S (South Gate → farms/Lumbridge road) ════════════╝
                                          │
                              [Dark-Wizard STONE CIRCLE — just S/SW of south gate,
                               lvl 7 & 20 wizards; Delrith / Demon Slayer site]
```

**Key landmarks (for map art):** city wall with 4 gates (N/E/S/W); two banks (W & E); central plaza/square with fur stall + gypsy tent; palace (N-centre); church/chapel (NE); museum + Aubury's (SE); sewers manhole; the surrounding terrain (yews in/around city, willows/oaks S, yews E).

---

## 3. Region Overview Map (hub-and-spoke — GDD §8)
Conceptual world layout (not to scale; teleport-linked spokes around the Varrock home region).

```
                              [ WILDERNESS ]  (N — live-only PvP, revenants, Wildy bosses)
                                    │ (N gate / Edgeville lever)
        [ EDGEVILLE ]──────[ GRAND EXCHANGE ]
        (Vannaka/Slayer,         (NW, unlock          [ GOD WARS DUNGEON ]
         Wilderness edge)         road north)          (Troll Country, late)
              │                        │                      ░ teleport spoke ░
   [ BARBARIAN ]                 ╔══════════════╗
   [ VILLAGE ]──── W ───────────║   VARROCK     ║──── E ────[ DIGSITE ]──[ AL KHARID ]
   (River Lum fishing)          ║  (HOME CITY)  ║                          (desert hub)
                                ╚══════════════╝
                                   │ S gate
                          [ STONE CIRCLE / farms ]
                          [ → LUMBRIDGE road ]

   ░░ TELEPORT SPOKES (reached by magic/item gates, GDD §8) ░░
   • KARAMJA → Fight Caves (Fire cape) → The Inferno (Infernal cape)
   • GREAT KOUREND / ZEAH (lizardmen→Hydra, Sarachnis)
   • MORYTANIA (Canifis, Slayer Tower — undead/Salve)
   • BARROWS (6-brother boss run)
   • WEISS (far north)
   • RAIDS (CoX / ToA / Colosseum)  • Apex: ZEZIMA arena
```
*The home region (Varrock + Edgeville + Barbarian Village + Al Kharid road + Stone Circle/farms) is a real contiguous explorable map; everything else is a teleport-gated spoke (GDD §8). Distances between spokes are abstracted.*

---

## 4. Sprite / Asset Generation Reference

### 4.1 Global art direction (GDD §20.3)
- **Style:** pixel-art, **2.5D isometric** projection. Cohesive palette (OSRS-flavored earthy medieval fantasy).
- **Directions:** 8 facings per animate sprite (N, NE, E, SE, S, SW, W, NW). Prototype may use fewer + mirroring; full 8-dir later.
- **Animation states (heroes/monsters):** idle, walk, attack (per style), hurt, death. Prototype: idle + walk minimum.

### 4.2 Heroes (procgen — GDD §20.3)
Layered, customizable sprite parts so each generated hero looks distinct:
- **Layers:** body/skin tone → hair (style + color) → facial hair (style + color, applicable chars) → top (style + color) → bottom (style + color) → equipped gear overlays (weapon, armour, cape) per slot.
- **Equipped gear shows on the sprite** (the loadout, GDD §13) — at least weapon + body + head for readability.
- EHT-style variety is the reference. Prototype: a small part-set that still yields visibly different heroes.

### 4.3 Monsters
- Sourced conceptually from canon (companion ITEMS_MONSTERS_BALANCE §5/§9). Each needs an isometric sprite + the animation states.
- Prototype priority (MVP roster): chicken, rat/giant rat, cow, man/woman, goblin, dark wizard, guard, zombie, **Scurrius (boss)**.
- Bosses are larger / distinct silhouettes.

### 4.4 Items
- **Inventory/equipment icons:** use **osrsreboxed canon icons** (20k+ PNGs keyed by item ID, GDD §21) — no generation needed for icons.
- **Equipped appearance** on the hero sprite: generated overlays per gear slot (can start with a few representative looks per tier, expand later).

### 4.5 Map / background
- Tilesets for: city cobblestone/paths, building roofs/walls, grass/farmland, water (River Lum), trees (yew/oak/willow), dungeon/sewer, desert (Al Kharid), wilderness, cave (Fight Caves). 
- Use the §2 Varrock blueprint + §3 region map as the spatial reference for the home-region tilemap.

### 4.6 Generation pipeline note (for the AI builder)
1. Item icons → ingest from osrsreboxed (done at build).
2. Hero parts → generate a layered part-set (skin/hair/clothing/gear) in the 2.5D iso style.
3. Monsters → generate per-creature iso sprites (MVP roster first).
4. Map tiles → generate the tileset; assemble Varrock per the §2 blueprint.
5. Keep one **style reference sheet** so all generated assets stay visually consistent.

---

## 5. Open / to-detail
🟡 Exact tile dimensions & sprite resolution; full 8-direction vs prototype mirroring; the hero part-set list (hair/clothing styles enumerated); per-tier equipped-gear overlay scope; precise in-city coordinates (the ASCII map is relative — exact tile grid TBD when the tilemap is built).

*Companion to GAME_DESIGN_DOC.md. Last updated: this session.*
