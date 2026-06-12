class_name Activities
extends RefCounted
## The dual-resolvable activity model (GDD §18.5 / §4 keystone). Every activity has BOTH:
##   • a LIVE path  — the scripted trip, ticked by SimWorld (travel → gather → sell → loop)
##   • a STATISTICAL path — expected_yield_per_hour(), used for offline catch-up (§3) and LOD
## The two share the same underlying rates, so live and offline can never diverge.
##
## Phase 0 implements the gathering activities (Mining/Woodcutting/Fishing). Combat/craft
## activities slot in here the same way in later build-order steps.

const GATHER_XP_PER_ACTION: float = 8.0   # base XP per gather action (× XP_RATE applied on grant)
const TRIP_EFFICIENCY: float = 0.7        # statistical de-rate for travel/banking overhead

## Activity catalog. Each entry: skill trained, the resource produced, the world location key,
## and the good the resource is ultimately sold as (fish is cooked → cooked_fish before sale).
const CATALOG := {
	"GATHER_ORE":   {"skill": "mining",      "res": "iron_ore",      "loc": "mine",    "sells_as": "iron_ore"},
	"GATHER_LOGS":  {"skill": "woodcutting", "res": "logs",     "loc": "forest",  "sells_as": "logs"},
	"PROVISION":    {"skill": "fishing",     "res": "raw_trout", "loc": "fishing", "sells_as": "trout"},
}

const FIGHT_KILLS_PER_HOUR: float = 60.0   # coarse Phase-0 estimate for offline combat yield
const RAT_HP: int = 15

static func is_gather(intent: String) -> bool:
	return CATALOG.has(intent)

static func is_combat(intent: String) -> bool:
	return intent == "FIGHT"

static func skill_of(intent: String) -> String:
	return CATALOG.get(intent, {}).get("skill", "")

static func resource_of(intent: String) -> String:
	return CATALOG.get(intent, {}).get("res", "")

static func location_of(intent: String) -> String:
	return CATALOG.get(intent, {}).get("loc", "")

static func sells_as(intent: String) -> String:
	return CATALOG.get(intent, {}).get("sells_as", "")

## Actions per real-world hour at the live rate (one action = WORK_TICKS_PER_ACTION sim ticks).
static func actions_per_hour() -> float:
	var action_seconds := Config.WORK_TICKS_PER_ACTION * Config.TICK
	return 3600.0 / action_seconds

## UNCONSTRAINED per-hour rates for a SOLO hero — the statistical basis rates (§18.5 dual-resolvability).
## NOTE (Step 6): these deliberately ignore market/pit saturation; SimWorld.offline_catchup applies the
## live bounds on top (market absorption per good, shared pit throughput, and the §6 upkeep-attractor
## projection for gold). Do NOT use this raw for any yield that touches the economy over a long window.
static func expected_yield_per_hour(hero: Hero, economy: Economy, intent: String) -> Dictionary:
	if is_combat(intent):
		# coarse: kills/hr × (avg coin drop, ~rat_hp damage worth of Strength XP) — solo, uncapped.
		var kph := FIGHT_KILLS_PER_HOUR * TRIP_EFFICIENCY
		var avg_drop := (Config.RAT_DROP_MIN + Config.RAT_DROP_MIN + Config.RAT_DROP_RANGE) / 2.0
		return {
			"xp": kph * RAT_HP * 4.0 * Config.XP_RATE,
			"gold": kph * avg_drop,
			"items": kph,
		}
	if not is_gather(intent):
		return {"xp": 0.0, "gold": 0.0, "items": 0.0}
	var aph := actions_per_hour() * TRIP_EFFICIENCY
	var sells_as_good := sells_as(intent)
	var price := economy.sell_price(sells_as_good)
	return {
		"xp": aph * GATHER_XP_PER_ACTION * Config.XP_RATE,
		"gold": aph * price,
		"items": aph,
	}
