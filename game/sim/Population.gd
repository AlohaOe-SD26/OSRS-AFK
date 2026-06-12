class_name Population
extends RefCounted
## Population, reputation & immigration (GDD §16.1 / §19.4 / EQUATIONS §8). Owns the colony's
## reputation meter, the immigration cadence, newcomer rarity-tier rolls, and the voluntary-
## departure valve. SimWorld drives it (step each economy-tick, daily on day rollover) and
## delegates hero construction/removal back to SimWorld (which owns names/appearance/locations).
##
## STABILITY DESIGN — the two things the planner is watching:
##  • Population can't oscillate: immigration rate is multiplied by the FREE-CAPACITY FRACTION,
##    so it decays smoothly to 0 as population approaches the cap → the curve ASYMPTOTES to a
##    stable level instead of overshooting. Reputation is built from the colony's AVG combat
##    level (bounded by the level cap), NOT a count that scales with population — so the
##    rep→immigration loop has no runaway term. Departures (sustained low satisfaction) are the
##    negative-feedback valve, floored at the founding population so the town can't empty out.
##  • Gold stays bounded as population changes: handled in Economy (per-hero proportional upkeep
##    is the attractor; town consumption scales with population, §6.5) — Population only changes
##    the head-count; it does not touch the gold attractor.

var enabled: bool = true
var reputation: float = Config.REP_BASE
var recent_deaths: float = 0.0        # decaying penalty window (deaths hurt reputation, §8)
var recent_kicks: float = 0.0         # decaying penalty window (kicks, §16.2 — wired in Step 5)
var _immig_accum: float = 0.0         # fractional applicant accumulator → smooth arrivals
# telemetry
var arrivals: int = 0
var departures: int = 0
var tier_counts: Dictionary = {}

func _init() -> void:
	for t in Config.NEWCOMER_TIERS:
		tier_counts[t["name"]] = 0

func free_capacity(world) -> int:
	var n: int = world.heroes.size()
	return maxi(0, Config.POP_CAP - n)

## Reputation (EQUATIONS §8 / §19.4). Bounded driver = avg combat level (no population-count term),
## minus decaying death/kick penalties. Buildings/decorations/cleared-content add in here in Step 4/5.
func update_reputation(world) -> void:
	var heroes: Array = world.heroes
	var cmb_sum := 0.0
	for h in heroes:
		cmb_sum += h.skill_level("attack") + h.skill_level("strength") + h.skill_level("defence")
	var avg_cmb: float = cmb_sum / maxf(1.0, float(heroes.size()))
	reputation = Config.REP_BASE + Config.REP_PER_AVGCMB * avg_cmb \
		+ world.town_reputation_bonus() \
		- Config.REP_PER_DEATH * recent_deaths - Config.REP_PER_KICK * recent_kicks
	reputation = maxf(0.0, reputation)

## Applicants per sim-day. The free-capacity fraction is the damper → asymptote, no oscillation.
func immigration_rate(world) -> float:
	if not enabled:
		return 0.0
	var free: int = free_capacity(world)
	if free <= 0:
		return 0.0
	var free_frac: float = float(free) / float(Config.POP_CAP)
	return Config.BASE_IMMIG * (1.0 + reputation / Config.REP_SCALE) * free_frac

## Roll a newcomer rarity tier (§16.1). Reputation tilts the weighted roll toward higher tiers
## (a famous town attracts accomplished adventurers). Returns the index into NEWCOMER_TIERS.
func roll_tier(world) -> int:
	var rep_norm: float = reputation / Config.REP_SCALE
	var weights: Array = []
	var total := 0.0
	for i in range(Config.NEWCOMER_TIERS.size()):
		var t: Dictionary = Config.NEWCOMER_TIERS[i]
		var w: float = float(t["weight"]) * pow(1.0 + Config.TIER_REP_TILT * rep_norm, float(i))
		weights.append(w)
		total += w
	var roll: float = world.rng.randf() * total
	var acc := 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if roll <= acc:
			return i
	return 0

## Per economy-tick step. `dd` = fraction of a sim-day. Decays penalty windows, refreshes
## reputation, advances the applicant accumulator, spawns arrivals while capacity allows.
func step(world, dd: float) -> void:
	if not enabled:
		return
	var keep: float = pow(Config.REP_EVENT_DECAY, dd)
	recent_deaths *= keep
	recent_kicks *= keep
	update_reputation(world)
	_immig_accum += immigration_rate(world) * dd
	while _immig_accum >= 1.0 and free_capacity(world) > 0:
		_immig_accum -= 1.0
		_spawn(world)
	if free_capacity(world) <= 0:
		_immig_accum = minf(_immig_accum, 1.0)   # don't bank infinite pent-up applicants at the cap

func _spawn(world) -> void:
	var ti: int = roll_tier(world)
	var tier: Dictionary = Config.NEWCOMER_TIERS[ti]
	var h = world.spawn_immigrant(tier)
	if h != null:
		arrivals += 1
		tier_counts[tier["name"]] = int(tier_counts[tier["name"]]) + 1

## Daily pass (on day rollover): recompute satisfaction, age the unhappy-day counters, and
## process voluntary departures (§16.1 valve) — floored at the founding population.
func daily(world) -> void:
	if not enabled:
		return
	update_reputation(world)
	var leaving: Array = []
	for h in world.heroes:
		h.recent_success *= Config.SAT_SUCCESS_DECAY
		h.satisfaction = compute_satisfaction(world, h)
		if h.satisfaction < Config.LEAVE_THRESHOLD:
			h.unhappy_days += 1
		else:
			h.unhappy_days = 0
		if h.unhappy_days >= Config.LEAVE_DAYS:
			leaving.append(h)
	for h in leaving:
		if world.heroes.size() <= Config.POP_BASELINE:
			break   # never let the town collapse below its founding core
		world.depart_hero(h)
		departures += 1

## Hero satisfaction (§19.4, Phase-0 subset): base + wealth comfort + recent success − unmet
## needs (foodless & can't afford food). Relationship term plugs in from Social.gd (sub-step 3).
func compute_satisfaction(world, h) -> float:
	var sat: float = Config.SAT_BASE
	sat += minf(1.0, h.gold / Config.SAT_GOLD_REF) * Config.SAT_WEALTH
	sat += minf(Config.SAT_SUCCESS_CAP, h.recent_success * Config.SAT_SUCCESS)
	var food: int = int(h.inv.get("trout", 0))
	var fp: int = world.economy.food_price()
	if food < 1 and h.gold < fp:
		sat -= Config.SAT_BROKE_PENALTY
	if world.social != null:
		sat += world.social.satisfaction_bonus(h.id)   # §9 relationships (0 until sub-step 3 fills)
	sat += world.town_satisfaction_bonus()              # §19.4 amenities (0 until the player builds)
	return clampf(sat, 0.0, 100.0)
