class_name Config
extends RefCounted
## Tunable constants — mirrors EQUATIONS_AND_SCHEMAS.md `CONFIG.*`.
##
## Economy sinks (SHOP_TAX, UPKEEP_*, RAT_DROP_*, PRICE_FLOOR_FRAC, SHOP_CONSUME) are
## NOT placeholders: they were validated in prototype.html, taking total gold from
## an unbounded +3,557%/6-day runaway to a bounded equilibrium (~5.3k @ 8 heroes,
## steady-state drift ±~15%). See GDD §23 / §6 and the tuning session notes.
##
## XP_RATE here is the *moderate* default (EQUATIONS §1: "default e.g. 5.0"), NOT the
## prototype's exaggerated ×40 (which existed only to make levels climb watchably fast).

# ---- pacing (§9 / EQUATIONS §1) ----
const XP_RATE: float = 5.0            # global XP-compression multiplier (the §9 slider, range 1–20)

# ---- the brain / utility function (§18 / EQUATIONS §4) ----
# Candidate-generation invariant (Stage-1 fix): the gather menu's "is there room?" check counts
# CARGO (loot) only, not consumables — so a food-heavy fighter can never have every gather option
# silently deleted before scoring (the "starved menu" bug). static var so the sweep can A/B it.
static var GATHER_GATE_CARGO_ONLY: bool = true

const FAVORITE_MULT: float = 1.6      # utility multiplier for a hero's favorite skill (~1.5–1.6)
const SECONDARY_MULT: float = 1.2     # smaller multiplier for the secondary skill
const CONGESTION_K: float = 7.0       # crowded nodes lose utility → self-balancing labor (§6)
# combat-node congestion weight vs gather nodes (0.5 = combat areas hold more bodies than one ore
# rock). static var (not const) so the labor sweep can A/B it without recompiling; 0.5 = original.
static var COMBAT_CONGESTION_MULT: float = 0.5
const STICKY_BONUS: float = 6.0       # anti-thrash hysteresis for the current activity
const DECISION_INTERVAL: float = 4.0  # seconds between re-evaluations (3–5s, §18.6)
# Stage-2 lever 2: soften the hard argmax into a WEIGHTED-RANDOM pick among NEAR-TIE candidates (scores
# within BRAIN_TIE_BAND of the top) → breaks the synchronized-herd monoculture (all re-deciders picking the
# momentary best at once). Acts at ACTIVITY-CATEGORY level (candidates are intents) → influences fight-vs-gather.
# Stable without per-tick re-deciding (the FSM commits to a trip + sticky bonus). default off → A/B'd then locked.
static var BRAIN_WEIGHTED_TIES: bool = false
# M2 BRAIN V2 (the §18 rebalance, ported from the HTML concept): every activity's base scales with
# skillNeed — (1+(99−L)/99)·(ambition·0.5+0.75) — which SATURATES to 0 at 99 and applies to combat and
# gather SYMMETRICALLY (kills the price-independent combat refuge, the diagnosed asymmetry). Fishing
# gains a DEMAND-RESPONSIVE term (food stock low → fish). A/B-able; default flips on once gate-validated.
static var BRAIN_V2: bool = false
# GOAL SYSTEM (§18.3): heroes hold "train SKILL to level N" goals — favorite-weighted (50%) but rotating
# through the other skills (the not-only-their-favorite fix), +GOAL_BIAS utility toward the goal skill,
# saga entry on completion. A/B-able; flips on once the labor/economy gates pass.
# TOOL REQUIREMENTS (user-spec): an activity needs its tool IN INVENTORY (rod is never equipable);
# combat needs a MAIN-HAND weapon equipped. Heroes spawn with ONLY their favorite's item; switching
# skills requires BUYING the tool at the shop (gold sink) — the mandatory companion that prevents
# tool-gating × goal-rotation from becoming a favorite-only lockout (would-be bug-class #6).
const TOOL_FOR: Dictionary = {"mining": "bronze_pickaxe", "woodcutting": "bronze_axe", "fishing": "fishing_rod"}
static var AMMO_ON: bool = true    # ammo consumption ON — instance-#7 (capital lockout) fixed by the
                                   # dry-punch fallback; gate-validated via diag_ammo + the suite
const TOOL_COST: int = 12      # affordable off early gather income (20g start — no spawn poverty trap)
const WEAPON_COST: int = 30
static var GOALS_ON: bool = true   # GATE-VALIDATED 2026-06-09 (8-seed A/B: labor neutral 20→19%,
const GOAL_BIAS: float = 14.0      # friends 6.9→7.8%, rivals 14.6→13.8%, gold bounded 894±25)
const BRAIN_TIE_BAND: float = 10.0    # candidates within this of the top score are "near-ties" eligible for the weighted pick

# ---- movement / work cadence ----
const TICK: float = 0.6               # canon sim tick, seconds (§10.1 / §21.2)
const WORK_TICKS_PER_ACTION: int = 4  # sim ticks per gather/work action (≈ a 2.4s action)
const MOVE_SPEED: float = 3.4         # tiles per second (raised 2.4→3.4 with real collision routing —
                                      # gate/bridge detours added honest travel time; this recovers throughput)

# ---- combat survival thresholds (§18 reactive interrupts) ----
const EAT_THRESHOLD: float = 0.45     # eat at 45% HP
const FLEE_THRESHOLD: float = 0.28    # flee below 28% with no food
const FOOD_HEAL: int = 6
# Canon OSRS passive regen: 1 HP per minute. Denominated in work-actions (2.4s each → 25/min) and
# pulsed off the serialized action_n counter — no new save state, deterministic across save/load.
# Without this, a foodless worker chipped by aggressive monsters can NEVER recover (#1d death-loop).
const REGEN_EVERY_ACTIONS: int = 25
# Canon OSRS aggression tolerance (#1d): aggressive monsters ignore a hero who has been on the
# current trip longer than this — harassment is an ARRIVAL TAX (a strike or two), not sustained
# DPS. Without it, goblins sharing the willows out-damage regen and workers death-loop
# (measured: ~90 deaths/day colony-wide). Bosses never become tolerant.
const AGGRO_TOLERANCE_S: float = 8.0
const FOOD_BUY_QTY: int = 4
# §18.6 decision-cadence: a combat trip COMPLETES after this many kills → the hero banks/restocks
# and RE-DECIDES (like a gather trip filling its inventory). Without this the fight loop self-
# sustains forever and fighters never reach a decision point, freezing the labor distribution.
# N=6 ≈ a gather trip's action-count (cadence parity); staggered across heroes (no herd thrash).
# static var (not const) so the labor sweep can toggle it (a huge value = effectively disabled).
static var COMBAT_TRIP_KILLS: int = 6
# Stage-2 RE-ENTRANT/TIMER trip-completion: the kills-gate above is UNREACHABLE at high congestion (4 rats
# shared ~20 ways → a fighter rarely reaches 6 kills), so well-fed fighters re-decide only on food/flee exits
# (irregular, food-cycle-paced). This timer completes the combat trip after a fixed ROUNDS budget REGARDLESS
# of kills → regular, kill-rate-independent re-decision cadence (≈ a gather trip's ~14-action length → parity).
# default 9999 = DISABLED (preserves current behavior + all green tests) until A/B'd, then locked. static var.
static var COMBAT_TRIP_ROUNDS: int = 9999

# ---- economy sinks (§6) — VALIDATED in the prototype tune ----
# Renamed GE_TAX→SHOP_TAX (Unit 1, ruling R8): this is the SHOP-sale skim, locked at 3%; the real
# GE arrives in Unit 4 with its own 1% treasury-routed trade tax.
const SHOP_TAX: float = 0.03          # sales skim on every shop sale (§5 wealth-scaling sink)
# Re-centered 2026-06-10: exact BFS pathing ≈doubled effective income (no wasted walking) → the band
# drifted to ~1955..2144 vs the validated ~600-900. Doubling the proportional rate halves g* back into
# range; the offline attractor-projection reads this same constant, so live/offline stay coherent.
const UPKEEP_RATE: float = 0.80       # daily upkeep PROPORTIONAL to gold held → stable attractor
const UPKEEP_FLAT: float = 6.0        # small flat per-hero/day upkeep baseline
# M3 re-tune (2026-06-10): kill throughput ~tripled across the gear/style slices (913→2679) while
# per-kill drops stayed fixed → combat faucet grew ~40%. Halved to re-center per-capita toward the
# validated band; the wealth-proportional upkeep attractor does the rest.
const RAT_DROP_MIN: int = 3           # coin drop range per rat kill (keeps the combat loop solvent)
const RAT_DROP_RANGE: int = 5
# M3a slice 1: rats occasionally drop GEAR. If it beats the hero's piece in that slot (and matches
# their weapon style for main-hand), they AUTO-EQUIP it (old piece salvages to half value in coins);
# otherwise it's CARRIED and vendors at the shop's gear board. Unit 1: the drop pool, tiers, styles
# and values all live in the CATALOG now (items.json dropPool/tier/style/baseValue — the old
# GEAR_DROPS/GEAR_TIER tables are retired; ContentDB.gear_drop_pool()/tier()/style() replace them).
static var GEAR_DROP_CHANCE: float = 0.04
# a saturated shop still pays this fraction of base value. static var (not const) so the labor
# sweep can test whether the gather-price floor is what drives heroes into combat; 0.12 = validated.
static var PRICE_FLOOR_FRAC: float = 0.12

# Unit 1 — the gear arm of the shop board (shops trade gear; replaces the flat half-value
# vendoring). Initial fill 0.5 makes the open price ≈ 0.5×base (the old anchor, by construction:
# f = 1.2 − 0.5×1.4 = 0.5); the small town demand absorbs gear so the arm can't saturate forever.
const GEAR_SHOP_STOCK: float = 4.0
const GEAR_SHOP_MAX: float = 8.0
const GEAR_SHOP_CONSUME: float = 0.25

# town demand: whole units/sim-day the NPC town absorbs (bounds the gather faucet, §6).
# cooked_fish is low because in the combat economy the real food sink is FIGHTERS buying food
# (§6) — the town only takes a small residual; the 260 here was a gather-only-era artifact that
# starved the fighters (see PROJECT_STATUS combat-tuning note).
const SHOP_CONSUME: Dictionary = {
	"iron_ore": 350.0,
	"logs": 350.0,
	"raw_trout": 0.0,
	"trout": 60.0,
}

# ---- population, reputation & immigration (§16 / §19.4 / EQUATIONS §8) ----
static var POP_CAP: int = 50          # default citizen cap (§16.1); static var so the scale-validation sweep can stress higher N
const BASE_IMMIG: float = 2.4         # baseline applicants / sim-day at neutral rep & empty town
const REP_BASE: float = 12.0          # floor reputation (a known canon city already has some draw)
const REP_PER_AVGCMB: float = 1.1     # reputation per point of colony AVG combat level (bounded → no runaway)
const REP_PER_DEATH: float = 5.0      # reputation lost per death in the recent window
const REP_PER_KICK: float = 8.0       # reputation lost per recent kick (§16.2, wired in Step 5)
const REP_SCALE: float = 70.0         # reputation→immigration sensitivity divisor (EQUATIONS §8)
const REP_EVENT_DECAY: float = 0.75   # daily decay of the recent-deaths/kicks penalty windows
# Newcomer rarity tiers (§16.1): combat/gather head-start + starting gold + base draw weight.
# Reputation tilts the roll toward higher tiers (a famous town attracts accomplished adventurers).
const NEWCOMER_TIERS: Array = [
	{"name": "Greenhorn", "boost": 0,  "gold": 20,  "weight": 1.00},
	{"name": "Seasoned",  "boost": 7,  "gold": 45,  "weight": 0.55},
	{"name": "Veteran",   "boost": 16, "gold": 130, "weight": 0.22},
	{"name": "Elite",     "boost": 28, "gold": 320, "weight": 0.07},
]
const TIER_REP_TILT: float = 0.9      # how strongly reputation shifts weight toward higher tiers

# ---- hero satisfaction & retention (§19.4) ----
const SAT_BASE: float = 50.0          # neutral satisfaction
const SAT_GOLD_REF: float = 600.0     # gold at which the wealth-comfort term saturates (+SAT_WEALTH)
const SAT_WEALTH: float = 18.0        # max satisfaction from being comfortably solvent
const SAT_BROKE_PENALTY: float = 22.0 # foodless + can't-afford-food hit (the unmet-need, §8)
const SAT_SUCCESS: float = 4.0        # per recent level-up (decaying window), capped by SAT_SUCCESS_CAP
const SAT_SUCCESS_CAP: float = 16.0
const SAT_SUCCESS_DECAY: float = 0.6  # daily decay of the recent-success window
const LEAVE_THRESHOLD: float = 30.0   # satisfaction below this counts as an unhappy day (§16.1 valve)
const LEAVE_DAYS: int = 3             # consecutive unhappy days → voluntary departure
# Town demand scales with population so faucets & sinks grow together as the colony grows (§6.5):
# at the founding population the scale is 1.0 → the validated 6-hero curve is preserved exactly.
const POP_BASELINE: int = 6

# ---- social relationship graph (§16.3 / EQUATIONS §9) ----
# Directed, signed, SPARSE: only nonzero edges are stored, and they DECAY toward 0 lazily (on
# access), so the graph self-prunes and stays cheap as it fills (the planner's perf watch).
static var REL_DECAY: float = 0.97    # per-sim-day multiplicative decay toward 0 (grudges/bonds fade);
                                      # the steady-state ceiling lever (static var → distribution sweep A/Bs it)
const REL_PRUNE: float = 0.6          # |R| below this is dropped → keeps storage sparse
const REL_INTERVAL: float = 0.5       # sim-days between proximity passes (throttle → bounded cost)
# static var (Step 5): the co-op:friction balance, tuned by the distribution sweep (tools/diag_social.gd).
# Amplified ~3× from the first Step-5 guess so the (churn-limited) spread of co-location maps ACROSS the
# tier bands instead of compressing into Neutral — at the old low magnitudes the strongest bond in a
# 43-hero colony only reached ±24 (everything Neutral). At ~3× the web spreads: ~76% Neutral, ~6% Friend,
# ~17% Rival, ~1% Nemesis. INTERIM: the web is rival-leaning (the combat-locked pit is a big stable group →
# many rivals; gather co-op is churn-limited → friends cap ~6%). Balancing toward friends≥rivals needs a
# STABLE positive source (same-trade kinship) — a planner decision (see PROJECT_STATUS).
static var REL_PROXIMITY: float = 3.6 # R/sim-day gained by heroes sharing a work node (§9 proximity)
static var REL_PROX_CAP: float = 3.0  # max proximity gain per pass (raised so co-op amplitude isn't clipped)
static var REL_COOP: float = 2.4      # extra bond for sharing the rat pit (co-op-survive flavor, §9)
const REL_TRADE: float = 3.0          # hero↔hero trade delta, daily cap (LATENT until GE/hero trade)
const REL_FRIEND: float = 20.0        # tier thresholds (§16.3): Friend ≥ +20, Ally ≥ +60,
const REL_ALLY: float = 60.0          #   Rival ≤ −20, Nemesis ≤ −60
const REL_SAT_SCALE: float = 12.0     # divisor: net positive relationships → small §19.4 satisfaction term
const REL_SAT_CAP: float = 6.0        # cap on the relationship→satisfaction contribution (kept gentle)
# ---- Step 5: negative-delta sources (§16.2/§16.3/§9) ----
# COMPETITION FRICTION (Step-5 autonomous source): the SYMMETRIC NEGATIVE of the co-op/proximity bond.
# Heroes crowding an OVER-CONGESTED node (more than REL_FRICTION_CROWD bodies competing for scarce
# spots/market) take mild rivalry INSTEAD of bonding. Weak + crowd-gated so neutral stays the default and
# rivalry is the exception (the planner's guardrail). INTERIM bridge until PvP brings the canon kill delta.
# static var so a distribution sweep can A/B the co-op:friction balance without recompiling.
static var REL_FRICTION_CROWD: int = 5     # a node with MORE than this many heroes is "contested"
static var REL_FRICTION: float = 4.5       # R/sim-day lost per pass at a contested combat node (~3× the first guess)
static var REL_FRICTION_CAP: float = 4.5   # max friction magnitude per pass
# SAME-TRADE KINSHIP (Step 5): the stable positive symmetric to friction — heroes sharing a favorite skill
# feel affinity, accrued location-INDEPENDENTLY (stable where node co-op is churn-limited). Calibrated so a
# same-trade pair lands around Friend (~steady REL_KINSHIP×~33), NOT Ally (the friend-monoculture guardrail).
# Fighters get this too, but combat friction (scarce rats) outweighs it → net rivalrous (correct). static var → sweepable.
static var REL_KINSHIP: float = 0.8        # R/sim-day between same-favorite heroes (regardless of location)
static var REL_KINSHIP_CAP: float = 0.6    # max kinship gain per pass
# Kick-vote relationship deltas (§16.3/§9): a yes-voter earns the target's resentment; a defender, warmth.
const REL_VOTE_YES: float = -15.0
const REL_VOTE_DEFEND: float = 10.0
# Gravestone-loot delta (§16.3/§14) — DORMANT: fires on PvE death (≈0 at current survival tuning); wired so
# the §9 source list is architecturally complete and ready when PvP / §14 looting land (canon −5/item, cap −30).
const REL_GRAVELOOT: float = -15.0

# ---- civic kick vote (§16.2) ----
const KICK_QUORUM_FRAC: float = 0.25   # vote valid only if ≥25% of citizens are eligible-and-vote (Option A)
const KICK_PASS_FRAC: float = 0.50     # pass on > 50% of ballots cast
const KICK_FORCE_AFTER: int = 5        # after this many FAILED (valid) votes, the god may force-kick (failsafe)
const KICK_COOLDOWN_DAYS: float = 0.1  # cooldown before another vote on the same target (90s → sim-days)
# Vote probability (§16.2): shaped by the voter's relationship TO the target + the target's value to town.
const KICK_BASE_YES: float = 0.35      # baseline yes probability at neutral relationship / average value
const KICK_REL_WEIGHT: float = 0.45    # how strongly R(voter→target) shifts the vote (friends defend, nemeses pile on)
const KICK_VALUE_WEIGHT: float = 0.20  # how strongly the target's value-to-town lowers yes (don't exile the strong)
const KICK_VALUE_REF: float = 60.0     # combat level at which value-to-town saturates

# ---- player control tiers (§2 / §18.4 / §19, Step 4) ----
# Tier-1 Incentivize: a posted bounty adds this much UTILITY to the targeted activity in the brain
# (§18.4 "bounties/prices raise relevant utilities"). It steers LABOR, not the gold supply — the
# validated economy attractor is untouched (a gold-funded payout is a later treasury-coupled refinement).
# Sized against the brain's other terms (favorite ≈ +16, base ≈ +10..14): one "step" meaningfully
# competes without instantly dominating, so the pull is legible and tunable. The UI sets multiples of it.
const INCENTIVE_STEP: float = 12.0
# Clamp the bounty BELOW the overproduction threshold. A 16-seed sweep (tools/diag_incentive.gd) maps
# the response: 24 pulls labor (15%→18% on target) with the economy STABLE (per-capita gold 921 ± 48);
# at 30 the gold variance already blows up (1612 ± 929 — some seeds saturating); ≥~36 the bounty floods
# one node so hard the shop SATURATES (stock→max, price→floor) → heroes can't sell → per-capita gold
# craters (870→~131). So 24 is the last stable rung → the in-game cap. With STEP=12 the player gets a
# gentle notch (12, ~no shift — it sits under the +16 favorite-bias gap) and a strong notch (24, clear
# pull). A *funded* per-unit bounty that clears through the treasury could safely go higher (a later
# refinement; see PROJECT_STATUS). The clamp ensures the steering lever can never crater the economy.
const INCENTIVE_MAX: float = 24.0
# ---- Slayer (Unit 0 / spec B2 under rulings R4–R6) ----
# Vannaka (designed cast, WORLD_AND_CHARACTERS §1) assigns tasks only to heroes of combat level ≥ 40
# (canon gate). Until Edgeville exists he is stationed at the west-gate/Edgeville-road edge of the map
# — a DOCUMENTED placement divergence (R4); relocate when zones expand westward.
const SLAYER_COMBAT_GATE: int = 40
# On-task utility bonus (R6: open at +20, lock via the standard sweep — per-hero and task-rotated, so
# safer than a standing colony-wide bounty at equal magnitude). static var → sweepable.
static var SLAYER_ON_TASK: float = 20.0
# Knowledge gating (B2): a monster enters the task pool only once the COLONY has killed enough of them
# (the same mechanism generalizes to the Scurrius kill-count boss gate).
const SLAYER_KNOWLEDGE: int = 100
const SLAYER_KNOWLEDGE_BOSS: int = 15
# Task sizing inversely with toughness (B2, translated to our HP scale: rat 15 → Scurrius 500).
# Bands are [min_hp, size_lo, size_hi], first match wins; bosses use the dedicated band.
const SLAYER_SIZE_BOSS: Array = [3, 8]
const SLAYER_SIZE_BANDS: Array = [[20, 8, 20], [10, 14, 35], [0, 20, 60]]
# Bonus slayer XP per ON-TASK kill ≈ 0.9 × the monster's HP (reference-faithful; ×XP_RATE on grant).
const SLAYER_XP_PER_HP: float = 0.9
# Slayer points per completed task (currency; spending = later design, per B2).
const SLAYER_POINTS_MIN: int = 8
const SLAYER_POINTS_MAX: int = 16
# Scurrius kill-count boss gate (#1d): the sewers boss emerges once the colony has culled this many
# rats — the queue's named unlock, driven by the same kill_counts knowledge the task pool uses.
const SCURRIUS_UNLOCK_KILLS: int = 300

# Nudge (Tier 2): a nudge wins the next decision via a one-off utility bonus so large it dominates the
# argmax for that single decision, then it is consumed (the hero resumes autonomy). Kept finite (not
# infinite) so the candidate still carries an honest, inspectable score in the Thoughts tab.
const NUDGE_BONUS: float = 1000.0

# Town treasury & building (§19) — the tycoon layer. The treasury is funded by the GE tax already
# skimmed from sales (so it draws on gold ALREADY removed from hero circulation → total_gold() and the
# economy attractor are unaffected). The player spends it to level shops and raise buildings.
# Shop leveling (§19.2): each level costs gold AND scales the shop's stock capacity. Town demand
# (consume) scales by the SAME factor so the faucet and sink grow together (§6.5 principle) → the
# equilibrium stays bounded BY CONSTRUCTION rather than needing a re-tune.
const SHOP_UPGRADE_BASE_COST: float = 400.0    # treasury cost of 1→2; rises with level
const SHOP_UPGRADE_COST_GROWTH: float = 1.6    # geometric cost growth per level
const SHOP_LEVEL_CAP: int = 99                 # §19.2 on-theme cap
const SHOP_CAP_PER_LEVEL: float = 0.15         # +15% stock capacity (and town demand) per level above 1
# Building catalog (§19.3 subset for Step 4). Each: one-time treasury cost + daily treasury upkeep
# (the continuous §6 sink) + its reputation / per-hero-satisfaction contribution.
const BUILDINGS: Dictionary = {
	"lodge":    {"name": "Hero Lodge",  "cost": 600.0,  "upkeep": 8.0,  "rep": 4.0,  "sat": 6.0},
	"monument": {"name": "Monument",    "cost": 900.0,  "upkeep": 5.0,  "rep": 14.0, "sat": 2.0},
	"tavern":   {"name": "Inn / Tavern","cost": 500.0,  "upkeep": 7.0,  "rep": 3.0,  "sat": 5.0},
}

# ---- offline catch-up (§4 / EQUATIONS §3) ----
const OFFLINE_RATE: float = 0.75      # 75% of active yield
const OFFLINE_CAP_HOURS: float = 24.0 # cap elapsed time
const OFFLINE_RARE_MULT: float = 0.5  # rare/boss drops roll at half chance offline

# ---- world / population (§16, §22.1) ----
const SIM_MINUTES_PER_TICK: float = 1.4  # in-sim clock minutes advanced per work-action (display only)
const DEFAULT_SEED: int = 0xA17F00D      # deterministic RNG seed (override per save, §25)
