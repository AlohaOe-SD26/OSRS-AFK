# Gielinor Tycoon — Step 3 Findings (for the planner agent)

**Status:** Step 3 built + verified. Godot 4.6.3 headless test **52/52 green**. Built to the
locked spec (GDD §6/§16/§19.4, EQUATIONS §5/§8/§9 — formalized, not re-derived). Each sub-step
gated before stacking the next. No deviations from the brief; all holds respected.

---

## What was built

**3a — NPC shops first-class** (`Shop.gd` + `Economy.gd` facade)
- Two inspectable canon vendors: General Store (ore/logs) · Fishmonger (raw/cooked fish), each with
  stock + a `level` field (the §19.2 shop-leveling dial, effects land in Step 4).
- Town-consumption promoted to a per-shop first-class sink; GE-tax promoted to a tracked
  `economy.tax_collected`.
- **Behavior-preserving:** economy day-12 gold = **7152, drift +15% — byte-identical to the Step-2
  baseline.** The validated wealth-proportional attractor was untouched.

**3b — Population & immigration** (`Population.gd`)
- Reputation driven by **avg combat level** (bounded → no runaway term) minus a decaying death
  penalty. `immigrationRate = baseImmig × (1 + rep/scale) × free-capacity-fraction`.
- The **free-capacity fraction is the damper** → population asymptotes instead of overshooting.
- Newcomer rarity tiers Greenhorn→Elite, reputation-tilted. Voluntary-departure valve wired
  (floored at the founding 6). Town demand now scales with population (§6.5) so faucets & sinks
  grow together.

**3c — Relationship graph** (`Social.gd`)
- Directed, signed, **sparse** (nested adjacency, nonzero edges only), **lazy O(1) decay on access
  + self-prune**, tiers per §16.3.
- Phase-0 accrual = proximity + a rat-pit co-op bond. **One effect wired:** trade-preference
  multiplier (friend ×0.95 / rival ×1.05, latent until hero↔hero/GE trade), plus a gentle §19.4
  relationship→satisfaction term. PvP-avoid / vote-bias / give-back stay **queued for Step 5**.

---

## The two watch numbers — both GREEN, decisively

| Watch | Result |
|---|---|
| **Gold bounded as population changes?** | **Yes.** Per-capita gold **flat at ~810–840** across the entire 6→44 population climb. **Per-capita drift −1%.** Total gold grows 22k→36k *only* from head-count; per-hero it's pinned. |
| **Population: stable or oscillating?** | **Stable.** Smooth monotonic 6→44 (cap 50), late-run band 40–44 (**swing 4**). Zero oscillation. 0 departures (economy stayed healthy → valve never needed to fire). |

**Export-log evidence (every snapshot, full run):** `g/cap` holds 809–837 while `pop` climbs 27→43.
Reputation 12→58. Newcomer tiers: Greenhorn 15 · Seasoned 11 · Veteran 9 · Elite 2. 0 deaths,
0 flees, no auto-flagged anomalies ("loop looks healthy").

---

## Flagged observations — diagnosed, NOT tuned (planner's call)

Per the "don't over-tune transients; diagnose from telemetry first" rule. Both root-cause to the
**same** thing; both largely self-resolve in later steps.

1. **Activity monoculture at scale:** at 43 heroes, ~34 pile into the single rat pit. Root cause:
   ore floors at **2g** because shop *max capacity* (120) doesn't scale with population while
   consumption does → gathering pays nothing → labor rationally flees to combat (whose congestion
   penalty is also discounted ×0.5). The §18.3 "believable specialist mix" isn't holding at scale.
2. **Social monoculture:** because those 34 share one node, proximity bonding makes them all Friends
   (**794 friends, 0 rivals/nemeses**). Also there are NO negative-delta sources in Phase 0
   (kills/votes are live-only / Step-5) — so rivals literally can't form yet, by design.

**Cheapest single knob for variety now:** scale shop max-capacity with population. Otherwise both
ease naturally once later steps add combat nodes/zones and Step-4 shop-leveling adds capacity scaling.

---

## Decision point

- **Option A (build agent's lean): bank Step 3, proceed to Step 4** — player control tiers
  (incentivize/nudge/seize) + town building/upgrades + Hero Panel. The `Shop.level` dial and
  per-hero satisfaction/tier/relationships are already in place for it. The macro economy is
  provably healthy; the monoculture is a content/scale artifact that Step-4 shop-leveling + later
  zones are the natural fix for.
- **Option B: quick tuning pass first** — scale shop max-capacity with population to spread labor
  (and thus diversify the social web) before moving on.

**Reproduce the telemetry yourself:**
`godot --headless --path game --script res://tools/headless_log.gd` (prints a full export log).
Tests: `godot --headless --path game --script res://tests/test_sim.gd` (52/52).
