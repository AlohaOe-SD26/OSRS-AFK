# Gielinor Tycoon — Equations & Data Schemas
> Companion to the Game Design Doc. The **implementation-math layer**: every formula in one place + the core entity schemas.
> **Constants in `CONFIG.*` are placeholders** — wired into the formulas but **tuned by playtesting**, not balance-solved on paper. Canon OSRS formulas (combat, XP curve) are exact; our custom systems use named tunables. Exact item/monster values come from the **osrsreboxed dataset** at build (§21 GDD).

---

## 1. Leveling & XP (canon-exact)

**XP→level curve (OSRS canon, exact):** XP required for level L:
```
XP(L) = floor( (1/4) * Σ_{n=1}^{L-1} floor( n + 300 * 2^(n/7) ) )
```
- Level cap **99** (XP 13,034,431). **Level 92 = 6,517,253 XP ≈ half of 99** (preserved — §9 GDD).
- **XP gained per action** = `baseActionXP × CONFIG.xpRate`. `CONFIG.xpRate` = the global **compression multiplier** (the §9 slider; default e.g. `5.0`, range 1–20). Applied uniformly → preserves the curve shape & the 92-halfway property.
- **Total level** = Σ levels of all active skills (the reincarnation trigger = all = 99).
- **Combat level** (canon): `0.25 × (Defence + Hitpoints + floor(Prayer/2)) + 0.325 × max( Attack+Strength , 2×floor(Magic×... ) )` → use the **exact OSRS combat-level formula from the dataset**; do not hand-reimplement.

---

## 2. Combat Resolution (canon-exact core — §10 GDD)

**Effective level:** `eff = floor(level × prayerMult) + styleBonus + 8` (× potion if any).
**Max hit (melee/ranged):** `maxHit = floor(0.5 + effStr × (gearStr + 64) / 640)` · **Magic:** `baseSpellDmg × (1 + magicDmgBonus)`.
**Attack roll:** `att = effAtt × (gearAtt + 64)` · **Defence roll:** `def = (targetDef + 9) × (targetDefBonus + 64)`.
**Hit chance:**
```
if att > def:  acc = 1 − (def + 2) / (2 × (att + 1))
else:          acc = att / (2 × (def + 1))
```
**Average hit:** `avgHit = (maxHit + 1) / 2`.
**Live DPS / statistical:** `DPS = avgHit × acc / (weaponSpeedTicks × 0.6)`.
**Time-to-kill:** `TTK = targetHP / DPS` (seconds).
**Situational multipliers (§1.1 companion):** applied to acc and/or maxHit as conditional factors, e.g. on-task Slayer helm `×1.1667` melee; Salve(ei) `×1.20` vs undead (overrides Slayer helm); these stack per the documented rules.
**Combat XP:** `xp = damageDealt × 4 × CONFIG.xpRate` to the trained style + `damageDealt × 1.33 × CONFIG.xpRate` to Hitpoints (canon ratios).

**"Am I winning?" check (brain, live + statistical):**
```
myDPS, enemyDPS computed both directions
myTTK = enemyHP / myDPS ;  surviveTime = (myHP + foodHealAvailable) / enemyDPS
fightValue = (myTTK < surviveTime × CONFIG.safetyMargin[riskTrait])
→ if false: flee/eat. riskTrait scales the margin (daredevil ~0.8, cautious ~1.5).
```

---

## 3. Offline Catch-up (§4 GDD)

For elapsed time `Δt` (capped `min(Δt, 24h)`):
```
For the hero's current Activity A with expectedYieldPerHour(A):
  gain = expectedYieldPerHour(A) × (Δt in hours) × CONFIG.offlineRate   // offlineRate = 0.75
  XP, gold, common items accrue; rare/boss drops roll at 0.5× normal chance (§4)
  No deaths / consequential events offline.
```
Each Activity defines `expectedYieldPerHour` (XP/gold/items/consumables) derived from the same combat/skill math (§2) — guaranteeing live↔offline consistency.

---

## 4. Hero AI — Utility Function (§18 GDD — the core decision equation)

Each decision tick, score every feasible candidate **activity** `a`; pick `argmax`. 
```
Utility(a) = Σ_d ( driveWeight[d] × driveRelief(a,d) )      // needs/drives relieved
           + expectedReward(a)      // XP/gold/progress toward goals, normalized
           × favoriteMult(a)        // ×CONFIG.favoriteMult if a trains the hero's favorite skill (~1.5); secondary ~1.2
           × incentiveMult(a)       // player bounties/posted tasks/prices raise this
           − riskCost(a)            // expected loss × riskAversion[trait]
           − travelCost(a)          // distance/time to reach
           − congestionPenalty(a)   // CONFIG.congestionK × (agents already at node)  → self-balancing economy
           + stickiness(a)          // +CONFIG.stickyBonus if a == currentActivity (anti-thrash hysteresis)
Feasible(a) = hasLevel ∧ hasGear ∧ hasGold ∧ reachable(known/perceived) ∧ questPrereqs
```
- **Drives** (0–100, trait-weighted baselines): survival(HP), supplies, inventory-space, growth(XP), wealth, social. `driveWeight[d]` set by personality traits.
- **Re-evaluation cadence:** every `CONFIG.decisionInterval` (e.g. 3–5 s) OR on routine-complete OR on interrupt — not every tick.
- **Reactive interrupts** bypass scoring (priority order): low-HP→eat/flee; inventory-full→bank; threat-perceived→flee/fight by risk; player command.

---

## 5. Economy (§6 GDD)

**NPC dynamic price (per item):**
```
buyPrice  = baseValue × clamp( 1 + CONFIG.priceK × (1 − stock/maxStock) , CONFIG.priceFloor, CONFIG.priceCeil )
sellPrice = baseValue × clamp( CONFIG.sellMargin × (stock/maxStock inverse) , floor, ceil )   // shops pay below base; falls as stock rises
```
Bounds e.g. `priceFloor=0.4, priceCeil=1.3, sellMargin=0.55`.
**GE price:** emergent from matched buy/sell offers; **GE tax** = `CONFIG.geTax × saleValue` (e.g. 0.01) → primary wealth-scaling sink.
**Gold equilibrium target:** tune so `Σ faucets/hour ≈ Σ sinks/hour` at a given town size. Monitor `totalGold` over time; faucets/sinks both scale with population & activity.
**Restock (shop level L, §19):** `restockInterval = baseInterval / (1 + CONFIG.shopRestockK × L)`; higher-tier-item chance `= CONFIG.shopTierChance × L`.

## 6. Enhancement (§5.6 GDD)
```
successChance(tier→tier+1) = CONFIG.enhSuccess[tier]      // e.g. Standard→Fine .90, Fine→Pristine .65, Pristine→Masterwork .35
cost(tier) = CONFIG.enhBaseGold × CONFIG.enhTierMult^tier  +  materials[tier]
onFail: consume materials; Masterwork attempt only: CONFIG.enhDowngradeChance (0.10) → drop to Fine
```

## 7. Reincarnation (§5.7 GDD)
```
trigger: allActiveSkills == 99
on reincarnate (count c → c+1):
  reset all skill levels→1 (HP→10), XP→0; unequip gear to bank
  echoXPmult   = 1 + CONFIG.echoXP × c        // e.g. 0.10 per rebirth (multiplicative)
  echoDmgMult  = 1 + CONFIG.echoDmg × c        // e.g. 0.05 per rebirth
  grant 1 trait-reroll token; milestone(c % 5 == 0) → prestige cosmetic
  effective xpRate for this hero = CONFIG.xpRate × echoXPmult
Zezima (§5.8): same engine but skills stay 99; only echoDmgMult compounds per defeat.
```

## 8. Population, Reputation & Satisfaction (§16, §19 GDD)
```
Reputation = Σ buildingRep + Σ decorationRep + CONFIG.repPerClear×contentCleared
           + CONFIG.repPerZezima×zezimaCount − CONFIG.repPerKick×recentKicks − CONFIG.repPerDeath×recentDeaths
immigrationRate = CONFIG.baseImmig × (1 + Reputation/CONFIG.repScale) × (freeCapacity>0)
newcomerTier ~ weightedRoll( tiers, weights shifted by Reputation )   // Greenhorn→Seasoned→Veteran→Elite

Satisfaction(hero) = base + housingAccess + amenityAccess + fairPriceScore(§5 prices)
                   + recentSuccess(levels,loot) + Σ relationshipScore(§9) − overcharge − recentDeaths − unmetNeeds
if Satisfaction < CONFIG.leaveThreshold for CONFIG.leaveDuration → voluntary departure
productivityMult = 1 + CONFIG.satProd × (Satisfaction − 50)/50
```

## 9. Social Graph (§16 GDD)
```
R(A→B) ∈ [−100, +100], start 0, asymmetric, sparse-stored.
decay: R *= CONFIG.relDecay^(daysElapsed)   // lazy, toward 0
event deltas (repeat-dampened): kill −25, gravestone-loot −5/item(cap−30), yes-vote −15,
  defend-vote +10, trade +3 (daily cap), return-loot +30, co-op-survive +5, proximity +0.1/min(cap)
tiers: Nemesis ≤−60, Rival −60..−20, Neutral −20..20, Friend 20..60, Ally ≥60
```

## 10. Death & Looting (§14 GDD)
```
keep = 3 (+1 Protect Item; skulled→0, +1 if Protect Item)
PvP death: killer loots immediately; +60s → public
PvE death (incl. Wild): items immediately public
reclaim fee = 0.10 × Σ value(lost items)   // instant buy-back if affordable
respawn after 30s at respawn point
loot grab interval = uniform(1.2, 2.1)s per item; owner Hasty = interval − uniform(0.3,0.7) (reroll per grab)
vulture targeting: only perceived piles; weight = greed × value / distance, capped (no swarm)
```

## 11. Slayer (§15 GDD)
```
monster unlockable as task when colonyKills[monster] ≥ (boss ? scaleByDifficulty : 100)
on-task vs assigned monster: +SlayerXP(≈monsterHP×CONFIG.xpRate), +CONFIG.slayerCombatBonus combat XP (~25–50%), +1 loot roll
partnership: ≤3 friends (Friend+), shared kill count; each gets own rewards + small co-op bonus
```

---

## 12. DATA SCHEMAS (core entities — field lists for the builder)

### Hero
```
id, name, appearance{hair,skin,top,bottom,facialHair,colors...}(§20.3),
skills{ skillId: {level, xp} }(17 active), combatLevel(derived), hitpointsCurrent,
favoriteSkill, secondarySkill, traits{riskTolerance,greed,ambition,sociability,patience,loyalty},
equipped{slot:itemInstanceId}, inventory[28 itemInstanceId], bank[{itemTypeId,tier,qty}],
gold, currentActivity, currentGoal[], knownLocations[], perceived[](transient),
reincarnationCount, echoXPmult, echoDmgMult, satisfaction, statusFlags{inCombat,training,banking,afk,incapacitated,onTask},
loadoutPresets{name:{slot:itemTypeId}}, relationships→ stored in global sparse graph keyed (fromId,toId)
```
### ItemType (catalog, from dataset)  /  ItemInstance (owned)
```
ItemType: id, name, slot, levelReqs{skill:lvl}, baseStats{att,str,def per style, prayer, magicDmg...},
  baseValue, stackable, acquisition{type: Craftable|DropOnly|Hybrid, craftSkill, craftLevel, recipe[], dropSources[{monsterId,rate}]},
  passives[], activeSpecial{cost,effect}, degradable{maxCharges}, iconId
ItemInstance: itemTypeId, qualityTier(Standard|Fine|Pristine|Masterwork), affixes[], chargesLeft, cosmeticVariant
```
### Monster (from dataset)
```
id, name, combatLevel, hitpoints, attackStyles[], maxHits{}, weaknessStyle, attackSpeed,
aggressive, undeadFlag, slayerLevelReq, region, dropTable[{itemTypeId, rate}], isBoss, coinDropRange
```
### Town
```
reputation, gold(treasury), populationCap(50), heroes[], buildings[{type,tier,upkeep,repValue}],
shops[{npcId, stock[], level}], bankCapacity(30→150), geUnlocked(bool), unlockedZones[], zezimaCount,
postedBounties[], postedSlayerTasks[], monsterUnlockKills{monsterId:count}
```
### Zone / Location
```
id, name, type(home|teleport-zone|dungeon|raid|wave-survival|wilderness), accessGate{magicLevel,item,killcount,skillReqs},
monsters[], resourceNodes[{skill, type, depletion, respawn}], boss, liveOnlyRisk(bool), teleportTier
```
### Chronicle Event
```
id, timestamp, type(milestone|death|boss|drop|social|exile|zezima), notabilityScore, heroIds[], text(generated)
```

---

## 13. Open / to-tune (placeholder constants live in CONFIG)
All `CONFIG.*` values above are starting points to tune against the XP-compression pacing. Exact item stats, monster stats, drop rates, and craft levels come from the **dataset** (verify at a snapshot patch date). Equations are wired; only constants and dataset values remain to fill.

*Companion to GAME_DESIGN_DOC.md. Last updated: this session.*
