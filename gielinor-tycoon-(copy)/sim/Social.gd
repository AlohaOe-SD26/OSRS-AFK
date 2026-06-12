class_name Social
extends RefCounted
## The directed, signed relationship graph (GDD §16.3 / EQUATIONS §9) — the colony's social web,
## the substrate the Dwarf-Fortress "stories" layer grows from. Step-3 scope (per the planner):
## RUNNING AND ACCRUING, but with MINIMAL effects wired (trade-prefs). The heavier effects
## (PvP-target avoidance, kick-vote bias, friendly-kill give-back) stay queued for Step 5 — the
## prototype proved the cheap version reads well, so this is deliberately not over-built.
##
## STORAGE — the planner's perf watch ("sparse + lazy decay stay performant as it fills"):
##  • SPARSE: nested adjacency `adj[from][to] = {r, day}` holds ONLY nonzero edges (no n² matrix).
##  • LAZY DECAY: an edge decays toward 0 only when touched — `r *= REL_DECAY^Δdays` — O(1) per
##    access, no per-tick sweep over the whole graph.
##  • SELF-PRUNING: once |r| falls below REL_PRUNE the edge is erased, so faded bonds free storage.
##  • THROTTLED ACCRUAL: proximity passes run every REL_INTERVAL sim-days, and only pair heroes
##    that share a work node (natural sparsity) — bounded cost even at the 50-hero cap.
##
## R(A→B) ∈ [−100, +100], start 0, ASYMMETRIC. Phase-0 accrual sources that actually exist:
## proximity (co-located heroes) + a co-op bond at the rat pit. Kill/gravestone/vote deltas are
## live-only or post-Step-5 and slot into _bump() the same way when those systems land.

var adj: Dictionary = {}              # from_id(int) -> { to_id(int) -> {"r": float, "day": int} }
var _acc: float = 0.0                 # throttle accumulator (sim-days since last proximity pass)
var _today: int = 1                   # most recent sim-day seen (for decay + no-arg effect queries)

# ---------------------------------------------------------------------------
## Decayed relationship A→B as of `today`. Applies lazy decay and prunes faded edges.
func get_r(a: int, b: int, today: int) -> float:
	var inner: Dictionary = adj.get(a, {})
	if not inner.has(b):
		return 0.0
	var e: Dictionary = inner[b]
	var elapsed: int = today - int(e["day"])
	if elapsed > 0:
		var nv: float = float(e["r"]) * pow(Config.REL_DECAY, float(elapsed))
		e["day"] = today
		if absf(nv) < Config.REL_PRUNE:
			inner.erase(b)
			return 0.0
		e["r"] = nv
	return float(e["r"])

## Apply a (repeat-dampened upstream) delta to A→B, clamped to [−100, 100]; prune if it fades.
func _bump(a: int, b: int, delta: float, today: int) -> void:
	var cur: float = get_r(a, b, today)            # decays first
	var nv: float = clampf(cur + delta, -100.0, 100.0)
	if absf(nv) < Config.REL_PRUNE:
		if adj.has(a):
			adj[a].erase(b)
		return
	if not adj.has(a):
		adj[a] = {}
	adj[a][b] = {"r": nv, "day": today}

# ---------------------------------------------------------------------------
## Driven each economy-tick by SimWorld; internally throttled to a proximity pass per REL_INTERVAL.
func tick(world, dd: float) -> void:
	_today = world.sim_day
	_acc += dd
	if _acc < Config.REL_INTERVAL:
		return
	var elapsed: float = _acc
	_acc = 0.0
	_proximity_pass(world, elapsed)
	_kinship_pass(world, elapsed)

## Heroes sharing a work node affect each other — and the SIGN depends on crowding (§9 + Step-5):
##  • a HEALTHY node (≤ REL_FRICTION_CROWD bodies) → a small co-op/proximity BOND (+); the rat pit adds
##    a co-op-survive bond.
##  • an OVER-CONGESTED node (> REL_FRICTION_CROWD, competing for scarce spots/market) → COMPETITION
##    FRICTION (−): the symmetric negative of the bond (Step-5 autonomous rivalry source). Self-correcting:
##    the same congestion drives the brain to disperse, so friction is bounded by the crowd thinning out.
## Grouping by node keeps this far below all-pairs cost.
func _proximity_pass(world, elapsed_days: float) -> void:
	var today: int = world.sim_day
	var groups: Dictionary = {}
	for h in world.heroes:
		var loc: String = h.act.get("loc", "")
		if loc == "":
			continue
		if not groups.has(loc):
			groups[loc] = []
		groups[loc].append(h.id)
	# Friction is gated on genuine SCARCITY, not raw headcount: the rat pit has a fixed number of rats,
	# so MORE fighters than rats = real competition for kills → rivalry. Gather nodes (ore/trees/fish) are
	# abundant → no scarcity → always the co-op bond. This maps friction to the actual game (scarce mobs vs
	# unlimited gather) and is self-correcting (the same congestion the brain routes around).
	var rats: int = world.alive_monster_count()
	for loc in groups:
		var ids: Array = groups[loc]
		if ids.size() < 2:
			continue
		var delta: float
		if loc == "combat" and ids.size() > maxi(1, rats):
			delta = -minf(Config.REL_FRICTION_CAP, Config.REL_FRICTION * elapsed_days)   # too many for the rats → friction
		else:
			delta = minf(Config.REL_PROX_CAP, Config.REL_PROXIMITY * elapsed_days)        # abundant node → bond
			if loc == "combat":
				delta += Config.REL_COOP                  # co-op-survive flavor when the pit isn't overcrowded
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				_bump(ids[i], ids[j], delta, today)        # asymmetric pair, both directions
				_bump(ids[j], ids[i], delta, today)

## Same-trade KINSHIP pass (Step 5): heroes sharing a favorite skill accrue a small steady positive bond,
## INDEPENDENT of location (stable where proximity co-op is churn-limited). Symmetric to friction. Grouping
## by favorite keeps it to within-trade pairs (far below all-pairs). Fighters get it too, but the pit's
## friction outweighs it → net rivalrous (correct).
func _kinship_pass(world, elapsed_days: float) -> void:
	var today: int = world.sim_day
	var groups: Dictionary = {}
	for h in world.heroes:
		var fav: String = h.favorite
		if fav == "":
			continue
		if not groups.has(fav):
			groups[fav] = []
		groups[fav].append(h.id)
	var gain: float = minf(Config.REL_KINSHIP_CAP, Config.REL_KINSHIP * elapsed_days)
	if gain <= 0.0:
		return
	for fav in groups:
		var ids: Array = groups[fav]
		if ids.size() < 2:
			continue
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				_bump(ids[i], ids[j], gain, today)
				_bump(ids[j], ids[i], gain, today)

## Hero-↔-hero trade bond (§9, +3 daily cap). LATENT in Phase 0 (heroes trade NPC shops, not each
## other); kept so the GE / hero-trade path in a later step just calls this.
func record_trade(a: int, b: int, today: int) -> void:
	_bump(a, b, Config.REL_TRADE, today)
	_bump(b, a, Config.REL_TRADE, today)

## Kick-vote delta (§16.2/§9, Step 5): the TARGET's relationship toward each VOTER shifts by how they
## voted — resentment toward a yes-voter, warmth toward a defender. Directed (target → voter).
func record_vote(target_id: int, voter_id: int, voted_yes: bool, today: int) -> void:
	_bump(target_id, voter_id, Config.REL_VOTE_YES if voted_yes else Config.REL_VOTE_DEFEND, today)

## Gravestone-loot delta (§16.3/§14, Step 5 — DORMANT): the VICTIM resents whoever looted their grave.
## Fires on PvE death (≈never at current survival tuning); wired & ready for PvP / §14 looting.
func record_graveloot(victim_id: int, looter_id: int, today: int) -> void:
	_bump(victim_id, looter_id, Config.REL_GRAVELOOT, today)

# ---------------------------------------------------------------------------
# Tiers (§16.3)
func tier(a: int, b: int, today: int) -> String:
	return tier_of(get_r(a, b, today))

## Classify a raw R value into its tier (§16.3) — shared by tier() and the Chronicle's pair-tier read.
func tier_of(r: float) -> String:
	if r <= -Config.REL_ALLY:
		return "Nemesis"
	if r <= -Config.REL_FRIEND:
		return "Rival"
	if r >= Config.REL_ALLY:
		return "Ally"
	if r >= Config.REL_FRIEND:
		return "Friend"
	return "Neutral"

# ---------------------------------------------------------------------------
# EFFECTS — Step-3 wires ONLY trade-prefs (+ the gentle §19.4 relationship→satisfaction term).
# PvP avoidance / vote bias / give-back stay queued (Step 5).

## Trade-preference multiplier on a hero-to-hero price (§16.3): Friends/Allies get a discount,
## Rivals/Nemeses a markup. THE wired effect. Latent until hero-hero/GE trade exists; ready then.
func trade_modifier(buyer: int, seller: int, today: int) -> float:
	match tier(buyer, seller, today):
		"Ally":    return 0.90
		"Friend":  return 0.95
		"Rival":   return 1.05
		"Nemesis": return 1.10
		_:         return 1.00

## Gentle §19.4 relationship term for hero satisfaction: net of this hero's standing bonds, scaled
## and capped small so the social web nudges retention without dominating it. Uses the last-seen day.
func satisfaction_bonus(hero_id: int) -> float:
	var inner: Dictionary = adj.get(hero_id, {})
	if inner.is_empty():
		return 0.0
	var net: float = 0.0
	for to_id in inner:
		net += get_r(hero_id, to_id, _today)
	return clampf(net / Config.REL_SAT_SCALE, -Config.REL_SAT_CAP, Config.REL_SAT_CAP)

# ---------------------------------------------------------------------------
# Maintenance + telemetry
## Remove all edges touching a departed/exiled hero (§16.1) — keeps the graph consistent + sparse.
func drop_node(id: int) -> void:
	adj.erase(id)
	for from_id in adj:
		adj[from_id].erase(id)

## This hero's standing relationships, strongest-magnitude first (Hero Panel Social tab, §20).
## Returns [{ "to": int, "r": float, "tier": String }] for non-Neutral bonds, up to `limit`.
func relations_for(id: int, today: int, limit: int = 6) -> Array:
	var out: Array = []
	for to_id in adj.get(id, {}):
		var r: float = get_r(id, to_id, today)
		if absf(r) >= Config.REL_FRIEND:   # surface only meaningful bonds (Friend/Ally/Rival/Nemesis)
			out.append({"to": to_id, "r": r, "tier": tier(id, to_id, today)})
	out.sort_custom(func(a, b): return absf(a["r"]) > absf(b["r"]))
	return out.slice(0, limit)

func edge_count() -> int:
	var n := 0
	for from_id in adj:
		n += adj[from_id].size()
	return n

## Tier histogram across all live edges (telemetry / future Relationships tab §20).
func tier_histogram(today: int) -> Dictionary:
	var h := {"Nemesis": 0, "Rival": 0, "Friend": 0, "Ally": 0}
	for from_id in adj:
		for to_id in adj[from_id]:
			var t: String = tier(from_id, to_id, today)
			if t != "Neutral":
				h[t] = int(h[t]) + 1
	return h
