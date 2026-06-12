# Gielinor Tycoon — Asset Generation Prompt Pack
> Reusable prompts for generating the game's 2.5D isometric pixel art consistently. Pair with `WORLD_AND_CHARACTERS.md` (appearance briefs + map) and the **procedural sprites in `prototype.html`** (the interim placeholder style/reference).
> **Do NOT generate item *inventory icons*** — those come from the **osrsreboxed dataset** (~20k canon PNGs, GDD §21). Generate only: world/character sprites, monster sprites, equipped-gear overlays, and map tiles/buildings.

---

## 0. How to use this
1. **Lock the style first (cheap):** generate the **Style-Lock Test Set** (§5) — one hero, two monsters, three tiles — confirm the look + resolution, *then* mass-produce. Don't generate hundreds of assets before the look is locked.
2. **Prepend the Style Bible (§1) to every prompt** so all assets stay cohesive. Keep a fixed palette + seed/style-reference image once you have one you like.
3. Generate on a **transparent background**, consistent scale, consistent light direction.

---

## 1. STYLE BIBLE (prepend to every prompt)
> *"2.5D isometric pixel-art game sprite, Old School RuneScape–inspired earthy medieval-fantasy aesthetic. Dimetric/isometric ~2:1 angle, viewed from above at ~30°. Limited warm palette (mossy greens, parchment, stone greys, iron, muted gold accents). Soft top-left light source, subtle ambient occlusion, crisp pixel edges, no anti-aliased blur. Transparent background. Clean readable silhouette. Cohesive, not photorealistic."*

**Technical defaults (lock during the test set):**
- **Characters / NPCs:** ~64×96 px sprite, feet centered, standing on an implied iso tile.
- **Monsters:** scale to threat — small (rat/chicken) ~48×48, humanoid ~64×96, boss (Scurrius) ~128×128.
- **Map tiles:** iso diamond ~64×32 px (top face), buildings as iso blocks sized in tile multiples.
- **Equipped-gear overlays:** same frame/anchor as the hero base, layered on top.
- **Directions:** generate **South-East facing** first as canonical; full set = 8 facings (N, NE, E, SE, S, SW, W, NW) — or generate 4 (S, SE, E, NE) and **mirror** for the W-side (prototype acceptable).
- **Animation (later):** idle, walk, attack, hurt, death. Prototype = idle + walk.

---

## 2. HEROES (procgen, layered — GDD §20.3)
Heroes are built from **swappable layers** so each generated adventurer looks distinct. Generate each layer on the same anchor/frame.

- **Base body + skin:** `[STYLE BIBLE] A human adventurer base body, neutral standing pose, [skin tone: pale/tan/brown/dark], plain undergarment, arms slightly out. SE facing.`
- **Hair layer:** `[STYLE BIBLE] Hair only, top-down iso, [style: short/long/ponytail/bald/mohawk], [color], aligned to the base head. Transparent.`
- **Facial hair (applicable):** `[STYLE BIBLE] Facial hair only, [beard/stubble/moustache], [color]. Transparent overlay.`
- **Shirt/top:** `[STYLE BIBLE] Torso garment only, [tunic/robe/leather jerkin], [color]. Overlay on base.`
- **Legs/bottom:** `[STYLE BIBLE] Leg garment only, [trousers/skirt/robe-bottom], [color]. Overlay.`
- Generate a small **part library** per layer (e.g., 4–6 hair styles × palette, 4 tops, etc.) → combine for variety. Reference: the 8 visibly-distinct procgen heroes in `prototype.html`.

## 3. EQUIPPED GEAR OVERLAYS (per slot/tier)
Layered on the hero base; start with a few representative looks per tier, expand later.
- `[STYLE BIBLE] Equipped [weapon: bronze/iron/steel/mithril/adamant/rune/dragon] [scimitar/sword/bow/staff], held in hand, aligned to hero base SE facing. Overlay only, transparent.`
- `[STYLE BIBLE] Worn [armour tier] [platebody/chainbody/robe/dragonhide body], torso overlay aligned to hero base. Transparent.`
- Capes: `[STYLE BIBLE] Worn cape [fire cape/infernal cape/god cape/skillcape colors], hanging behind the hero, SE facing overlay.`

## 4. MONSTERS (MVP roster — companion ITEMS_MONSTERS_BALANCE §5)
One prompt per creature; use the canon description.
| Monster | Prompt seed (after Style Bible) |
|---|---|
| Chicken | `a small white/brown chicken, iso, ~48px` |
| Rat / Giant rat | `a grey sewer rat with long tail (and a larger giant-rat variant), iso, ~48px` |
| Cow | `a black-and-white cow, iso, ~64px` |
| Man / Woman | `a plain town commoner (male & female variants), simple medieval clothes, iso ~64×96` |
| Goblin | `a small green goblin in tattered armour holding a club, iso ~56px` |
| Dark wizard | `a hooded dark-robed wizard (Zamorak), menacing, iso ~64×96` |
| Guard | `a Varrock city guard in chainmail with a halberd, iso ~64×96` |
| Zombie | `a shambling rotted zombie, iso ~64×96` |
| **Scurrius (BOSS)** | `a giant monstrous rat king boss, scarred, oversized, imposing silhouette, iso ~128px` |

## 5. NPCs (Varrock cast — appearance briefs in WORLD_AND_CHARACTERS §1)
Use each NPC's appearance brief verbatim after the Style Bible, e.g.:
- Aubury: `an elderly wizard in blue robes, pointed hat, long white beard, holding a staff, iso ~64×96`
- Horvik: `a burly smith in a leather apron over a tunic, soot-smudged, muscular, iso ~64×96`
- King Roald: `a middle-aged king in red and gold robes with a gold crown and brown beard, regal, iso ~64×96`
- …(repeat for Zaff, Lowe, Thessalia, Apothecary, Baraek, Gypsy Aris, Reldo, Curator, Vannaka — briefs in the World doc.)

## 6. MAP TILES, TERRAIN & BUILDINGS (Varrock blueprint — WORLD_AND_CHARACTERS §2)
- **Ground tiles:** `[STYLE BIBLE] a single isometric ground tile (64×32 top face), [grass / dirt path / cobblestone / farmland / sand (Al Kharid) / cave floor], tileable, transparent edges.`
- **Water:** `[STYLE BIBLE] isometric water tile, River Lum blue, gentle ripples, tileable.`
- **Buildings (iso blocks):** Bank, Market/Shop, Range, Varrock Palace, Church/Chapel, Museum, generic houses — `[STYLE BIBLE] an isometric [building], stone-and-timber medieval, [size] tiles footprint, [roof color].`
- **Resource nodes:** `[STYLE BIBLE] an isometric [mining rocks with ore veins / cluster of yew & oak trees / fishing spot on a riverbank / dark-wizard stone circle]`.
- **Assemble** the Varrock home map per the §2 ASCII blueprint (4 gates, W/E banks, central plaza, palace N, Aubury/Museum SE, sewers manhole, Stone Circle S).

## 7. Style-Lock Test Set (generate these FIRST)
1. **One hero** — base + 1 hair + 1 top + a bronze scimitar overlay (proves the layering works).
2. **Two monsters** — a rat (small) and Scurrius (boss) (proves scale range).
3. **Three tiles** — grass, cobblestone, a building (bank) (proves the tilemap look).
→ Confirm resolution, angle, palette, and that layered overlays align. Once approved, lock these as the **style reference** and mass-produce against it.

## 8. Consistency checklist
- Same iso angle + light direction on every asset.
- Fixed palette (save it; reuse).
- Same pixel density / outline weight.
- Anchor points consistent (feet-center for characters; tile-origin for buildings).
- Keep one approved **style reference sheet**; pass it alongside each new prompt.

---
*Companion to the Gielinor Tycoon docs. Item icons → osrsreboxed; everything here → generated. Last updated: this session.*
