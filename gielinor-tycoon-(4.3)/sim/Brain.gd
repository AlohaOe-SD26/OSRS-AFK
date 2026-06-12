class_name Brain
extends RefCounted
## The Hero AI utility brain (GDD §18 / EQUATIONS §4). Scores every feasible candidate
## activity and returns the argmax. Phase 0 exercises the gathering activities so the core
## levers are live: favorite-skill bias, congestion self-balancing, travel cost, expected
## wealth, and anti-thrash stickiness. Combat/quest activities extend this same scoring in
## later build-order steps.
##
## Validated in the prototype (§23): heroes choose believably, commit to a trip (no
## thrashing), and congestion spreads labor across nodes with no scripting.

## Returns the chosen activity as { "intent": String, "loc": String, "skill": String,
## "res": String, "score": float } or an empty Dictionary if nothing is feasible.
static func choose(hero: Hero, world) -> Dictionary:
	var candidates: Array = []
	var space_left := (28 - hero.inv_count()) > 4
	if space_left:
		for intent in Activities.CATALOG:
			candidates.append(_score(hero, world, intent))
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]

static func _score(hero: Hero, world, intent: String) -> Dictionary:
	var skill := Activities.skill_of(intent)
	var loc_key := Activities.location_of(intent)
	var s := 10.0 + hero.skill_level(skill) * 0.5

	# favorite / secondary leaning (§18.3)
	if hero.favorite == skill:
		s += Config.FAVORITE_MULT * 10.0
	elif hero.secondary == skill:
		s += Config.SECONDARY_MULT * 10.0

	# expected wealth from this activity (greed-weighted)
	var wealth_w := 0.6 + float(hero.traits.get("greed", 0.4))
	var price := world.economy.sell_price(Activities.sells_as(intent))
	s += price * 0.25 * wealth_w

	# self-balancing: crowded nodes are less attractive (§6 / §18.6)
	s -= world.congestion(loc_key) * Config.CONGESTION_K

	# travel cost
	s -= world.distance_to(hero, loc_key) * 0.4

	# anti-thrash hysteresis: stay on the current activity unless something clearly beats it
	if hero.act.get("intent", "") == intent:
		s += Config.STICKY_BONUS

	return {
		"intent": intent,
		"loc": loc_key,
		"skill": skill,
		"res": Activities.resource_of(intent),
		"score": s,
	}
