# DESIGN RULINGS — response to ANALYSIS_REPORT.md (2026-06-11)

**From:** the design partner (planner), via Nick.
**Verification note:** your report was spot-checked against `SOURCE_COPIES/` — every checked formula, constant, and claim matched verbatim (Shop.gd curves, Config values, `fight_is_winnable`, the nudge contract, the materialized punch list). The report is treated as fully trustworthy. Outstanding work — the manifest, the honest flags, and the verbatim-quote discipline made this reviewable at distance.

**The contract, reaffirmed:** these rulings set *what* features do. *When* and *how* remain yours — the Unit 0–5 sequencing proposal is **endorsed as-is**, including C4-never-before-C2/Unit-4 and the faucets-land-one-at-a-time constraint. Every unit ships through your existing gates (101-suite, determinism/save/offline, multi-seed sweeps, band report). Plan the RNG-stream re-baselines as you see fit.

---

## R1. Treasury ledger & re-injection — ACCEPT as a player-throttled faucet; escrow at posting; adopt purchase routing at 40%

- City buy orders and funded bounties as a bounded re-injection faucet: **accepted**, your analysis is correct and your recommendation is adopted. No additional hard outflow cap — instead, make affordability structural: **city buy orders escrow their gold at posting** (posting a 200-unit order at 10g reserves 2,000g from treasury; cancel/expiry refunds the unfilled remainder). This makes overdraft impossible by construction, is OSRS-canonical GE behavior, and is simpler than a flow cap. Bounties stay per-kill affordability-checked (your/the reference's rule) — no escrow needed at that cadence.
- **Adopt B1's purchase→treasury routing at 40%** (burn 60%). Rationale: the treasury must have a real pulse to fund Unit 0's bounties and Unit 4's buy orders, or the player's new levers are decorative; 40% keeps burn dominant. The number is yours to tune in the 30–50% band within sweep gates. Per your recommendation: routing + city-buy outflow are **one ledger unit** — model g* before/after, sweep once, re-center once.
- Add treasury inflow/outflow lines to telemetry when this lands (the heavy-shop ceiling watch number will want them anyway).

## R2. Buyer of last resort — KEEP the floor

Ruled definitively: **baseline NPC town demand keeps a survivable floor income.** The autonomous colony must remain viable with the player AFK — autonomy *is* the product; an idle game that deadlocks without procurement micromanagement breaks the core promise. Your C4 ceiling formula (`min(saturation_curve, 0.30 × GE_reference)` with graceful degradation to today's validated behavior when the GE is illiquid) is exactly right and is adopted as written. City orders are upside pressure, never a survival requirement.

## R3. Shop roster — GREENLIT: Horvik, Lowe, Zaff, Aubury, Swordshop; defer Apothecary & Thessalia

Unit-2 scope, as catalog breadth permits: **Horvik (armour/smithy), Lowe (archery), Zaff (staves), Aubury (runes), the Swordshop (melee)**. Hard-won lesson from the reference build, offered as rationale: combat-style diversity is *supply-gated* — in the reference, magic and ranged silently never trained because their consumables/gear weren't reliably purchasable (a chicken-and-egg between style adoption and style supply). Aubury's runes and Lowe's ammo are therefore not flavor — they're the prerequisites for the combat triangle (wave b) actually expressing. **Defer Apothecary** (no potion system yet) and **Thessalia** (cosmetic; pairs with appearance customization later). Stagger openings if you like (rep- or treasury-gated) — your call.

## R4. Slayer master — VANNAKA, with a documented placement divergence

**Vannaka.** He is not "reference parity" — he's *designed cast*: `WORLD_AND_CHARACTERS.md` §1 lists Vannaka (Slayer Master, Edgeville Dungeon, Combat-40 gate). Lore accuracy is an invariant; do not invent a stand-in when canon already provides the character. Placement: until Edgeville exists, station him at the west gate / Edgeville-road edge of the map with a documented divergence note ("Vannaka, visiting Varrock" — Chronicle line on first unlock is a nice touch, optional), and relocate him home when zones expand westward. Divergences-with-documentation is the established pattern; inventing NPCs is not.

## R5. Bounty unification — YES; one lever, two effects; gather incentives migrate to funded mechanisms

- Adopt the funded per-kill bounty and **retire the clamped utility FIGHT bounty when it lands** (same unit). Design principle going forward: **every incentive that moves gold is funded; the attraction derives from the payout.** Concretely: the posted bounty value enters fight scoring through your existing greed-weighted `reward` term (payout × the same 0.2 × (0.6+greed) shape) — not as a separate flat utility knob. One lever the player sets; two effects (attraction + payment) from the same number. Your 0–3× avg-coin-drop translation is endorsed.
- Gather incentives: keep the current clamped utility incentives **as the interim**, then migrate — **city buy orders (C2) are the funded gather incentive** (pay-per-delivery through the market, exactly your banked conclusion), with B1's price-bias as the soft secondary lever. End state after Unit 4: pure-utility gold-less incentives retire; the Incentives UI presents bounties (combat) and buy orders / price-bias (gather) as the two faces of one funded system.

## R6. On-task bonus — mechanic locked; the number is yours; instrument the §18 prediction

Open at +20, lock via the standard sweep — **the number is yours within gates**, ruled explicitly. One addition, cheap and valuable: Slayer tasks are precisely the "finite, risky, gated combat targets" that the banked §18 asymmetry analysis predicted would resolve the combat-attractor lean (KI-3) and feed BRAIN_V2's activity-breadth precondition. **Instrument the Unit-0 sweep to report the monoculture/rival-lean metrics alongside the usual band** — this verifies (or falsifies) a banked prediction for free while you're already sweeping. If the prediction holds, note it in the decisions log; it strengthens the case for the BRAIN_V2 4th test.

## R7. Loot settings — drop-filter reading ACCEPTED

`loot_policy` = a drop-filter (keep-all / upgrades-and-valuables / salvage-all) governing the existing auto-resolve branch. Literal ground loot is **not** C1's intent — it arrives with §14 graves/vultures in wave (e), where it's load-bearing. Fold the filter into the offline rare-drop projection if/when itemized offline drops exist; until then nothing extra.

## R8. Tax architecture — shop 3% untouched; GE tax 1% at open, treasury-routed; city orders untaxed

- The **3% shop-sale tax stays exactly as-is** — it is a component of the locked attractor; don't touch it in any Part-B/C unit.
- When the real GE lands (Unit 4): **GE trade tax = 1%** at open (canon rate, EQUATIONS §5's example), **routed to the treasury — yes** (your lean confirmed; it partially replaces shop-tax inflow as volume migrates GE-ward). Tunable 1–3% within gates if treasury starves under real volume; report the migration effect in the unit's band report.
- **City buy orders are untaxed** (the city is the buyer; taxing your own treasury is ledger noise). Hero↔hero and hero-sell-to-city... clarification: tax applies to *hero-side proceeds* of GE-matched trades, regardless of counterparty — so a hero filling a city buy order pays the same 1% on proceeds as in a hero↔hero fill. Uniform, simple, one rule.
- The `GE_TAX` misnomer: rename to `SHOP_TAX` whenever Unit 1/2 already has the files open — cosmetic, your timing.

## R9. Bank scope — IN for Unit 4, confirmed

Your assumption holds, with one requirement made explicit: **GE expiry/cancel refunds and unfilled-buy returns need a deposit target** — without a bank, refund flows have nowhere safe to land (a lesson the reference build learned the hard way: expiry refunds deadlocked until they routed to the bank). Bank and order book ship together; hoarding's antidote (C2's sell pressure + city demand) lands the same unit hoarding becomes possible — your own sequencing argument, endorsed.

## R10. Save migrations — GREENLIT for Unit 0, before any schema churn

Build the scaffold first: keep `SAVE_VERSION`, add an ordered chain of per-version upgrader functions (v1→v2→…→current) run before normal load. Gate criterion: a migrated save **loads validly and continues deterministically from the load point** (it does not need byte-equivalence to any historical run — that contract applies within a version, not across migrations). Every Part-B/C unit that touches the save bumps the version and ships its upgrader.

**Process priority #0, before Unit 0 itself: make the initial git commit and push.** Zero commits with everything staged is the single largest project risk on the books — one errant `git checkout`/`reset` from this state can destroy 6,500 lines with no recovery. First action when work resumes: commit the current green state (something like `Initial commit — MVP "Living Varrock" complete, 101/101 green, pre-rulings baseline`), push to origin, confirm it's visible on GitHub, then proceed under the Project Kit's per-work-item commit discipline. The `ANALYSIS REPORT/` and `PROJECT KNOWLEDGE/` folders go in it.

## R11. UI tech for C1 — your lean (b) APPROVED: Control nodes for new popups only

Approved with conditions: (1) existing immediate-mode panels stay untouched (already your plan); (2) the new popups share visual constants (palette, fonts, paddings) with the existing look so the mixed paradigm reads as one game; (3) popups remain render-layer — read sim read-only, dispatch through the same SimWorld methods as `_dispatch_ui`; (4) a decisions-log entry recording the paradigm split and the rule for which side new UI lands on (suggested rule: forms/complex-input → Control nodes; HUD/panels → immediate-mode, until a deliberate unification). Treat C1 as the experiment; if Control nodes prove better, future complex UI follows.

## R12. Day denomination — CONFIRMED: sim-days

All day-denominated specs in Part B/C mean **sim-days** (≈41.1 real minutes at 1×), exactly as you assumed throughout. C5's literal translation (imports correctly negligible-but-nonzero at your scale) is right. If a future spec ever means real time, it will say "real" explicitly.

---

## Endorsements & notes (no action required beyond what's stated)

- **Sequencing**: Units 0–5 adopted as proposed; Unit 0 absorbs B2; Unit 1 (catalog migration) promoted to prerequisite is correct — and note KI-10 (GOODS/items.json base-value mismatch) resolves there *before* anything prices against `base_value`.
- **B1 verdict table**: accepted line-by-line, including keep-ours on the sell curve, consumption model, and cost ladder. The price-bias clamp expectation (narrower than 50–150% pay-side) matches the incentive-sweep evidence; sweep it.
- **C5 queueing**: reservation-on-start FIFO adopted as proposed. The closed loop you identified (C2 accumulates → C3 upgrades + C5 crafting drain) is the design — keep the bug-class lens on it as tiers scale.
- **Chronicle**: yes — orders filled, crafts completed, tasks assigned/completed all emit `log_event` at sensible notability (task completions probably notability > 0; routine fills 0).
- **PROJECT KNOWLEDGE**: maintenance per the Part-E rules is now standing practice; the materialized punch list is the single source of truth. Well done flagging the skeleton collision and filling rather than duplicating.

**Next from you:** proceed with priority #0 (git) and Unit 0 under these rulings. No further design gate before Unit 0; flag anything that surprises you mid-build per normal practice.
