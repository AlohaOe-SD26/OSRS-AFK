class_name Config
extends RefCounted
## Tunable constants — mirrors EQUATIONS_AND_SCHEMAS.md `CONFIG.*`.
##
## Economy sinks (GE_TAX, UPKEEP_*, RAT_DROP_*, PRICE_FLOOR_FRAC, SHOP_CONSUME) are
## NOT placeholders: they were validated in prototype.html, taking total gold from
## an unbounded +3,557%/6-day runaway to a bounded equilibrium (~5.3k @ 8 heroes,
## steady-state drift ±~15%). See GDD §23 / §6 and the tuning session notes.
##
## XP_RATE here is the *moderate* default (EQUATIONS §1: "default e.g. 5.0"), NOT the
## prototype's exaggerated ×40 (which existed only to make levels climb watchably fast).

# ---- pacing (§9 / EQUATIONS §1) ----
const XP_RATE: float = 5.0            # global XP-compression multiplier (the §9 slider, range 1–20)

# ---- the brain / utility function (§18 / EQUATIONS §4) ----
const FAVORITE_MULT: float = 1.6      # utility multiplier for a hero's favorite skill (~1.5–1.6)
const SECONDARY_MULT: float = 1.2     # smaller multiplier for the secondary skill
const CONGESTION_K: float = 7.0       # crowded nodes lose utility → self-balancing labor (§6)
const STICKY_BONUS: float = 6.0       # anti-thrash hysteresis for the current activity
const DECISION_INTERVAL: float = 4.0  # seconds between re-evaluations (3–5s, §18.6)

# ---- movement / work cadence ----
const TICK: float = 0.6               # canon sim tick, seconds (§10.1 / §21.2)
const WORK_TICKS_PER_ACTION: int = 4  # sim ticks per gather/work action (≈ a 2.4s action)
const MOVE_SPEED: float = 2.4         # tiles per second

# ---- combat survival thresholds (§18 reactive interrupts) ----
const EAT_THRESHOLD: float = 0.45     # eat at 45% HP
const FLEE_THRESHOLD: float = 0.28    # flee below 28% with no food
const FOOD_HEAL: int = 6
const FOOD_BUY_QTY: int = 4

# ---- economy sinks (§6) — VALIDATED in the prototype tune ----
const GE_TAX: float = 0.03            # sales skim on every shop sale (§5 wealth-scaling sink)
const UPKEEP_RATE: float = 0.40       # daily upkeep PROPORTIONAL to gold held → stable attractor
const UPKEEP_FLAT: float = 6.0        # small flat per-hero/day upkeep baseline
const RAT_DROP_MIN: int = 6           # coin drop range per rat kill (keeps the combat loop solvent)
const RAT_DROP_RANGE: int = 10
const PRICE_FLOOR_FRAC: float = 0.12  # a saturated shop still pays this fraction of base value

# town demand: whole units/sim-day the NPC town absorbs (bounds the gather faucet, §6)
const SHOP_CONSUME: Dictionary = {
	"ore": 350.0,
	"logs": 350.0,
	"raw_fish": 0.0,
	"cooked_fish": 260.0,
}

# ---- offline catch-up (§4 / EQUATIONS §3) ----
const OFFLINE_RATE: float = 0.75      # 75% of active yield
const OFFLINE_CAP_HOURS: float = 24.0 # cap elapsed time
const OFFLINE_RARE_MULT: float = 0.5  # rare/boss drops roll at half chance offline

# ---- world / population (§16, §22.1) ----
const SIM_MINUTES_PER_TICK: float = 1.4  # in-sim clock minutes advanced per work-action (display only)
const DEFAULT_SEED: int = 0xA17F00D      # deterministic RNG seed (override per save, §25)
