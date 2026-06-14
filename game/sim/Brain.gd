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
##
## Each candidate carries a "terms" breakdown (ordered [name, value] pairs) and the score is
## EXACTLY their sum — so decision-level instrumentation (tools/diag_decision.gd) reports the same
## math the brain actually uses; the instrument cannot diverge from the score.

## Returns the chosen activity as { "intent", "loc", "skill", "res", "score", "terms" } or an
## empty Dictionary if nothing is feasible.
static func choose(hero: Hero, world) -> Dictionary:
	var candidates := candidates_with_terms(hero, world)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]

## All feasible scored candidates (same gating as choose) — used by choose() and by the decision
## instrument so both see identical math.
##
## INVARIANT (Stage-1 fix): the gather "room?" check is a soft eligibility test over CARGO only, so
## carried food can never delete the gather menu; and if the candidate set is ever empty we append a
## guaranteed productive fallback (regroup→sell at town) so no agent can be left with a starved menu.
static func candidates_with_terms(hero: Hero, world) -> Array:
	var candidates: Array = []
	var used := hero.cargo_count() if Config.GATHER_GATE_CARGO_ONLY else hero.inv_count()
	var space_left := (28 - used) > 4
	if space_left:
		for intent in Activities.CATALOG:
			candidates.append(_score(hero, world, intent))
	# FIGHT candidates — one per CAMP the hero can plausibly take on (multi-camp world, zones slice 1)
	for c in SimWorld.CAMPS:
		var fight := _score_fight(hero, world, String(c["loc"]), String(c["mon"]))
		if not fight.is_empty():
			candidates.append(fight)
	# SMITHING (crafting slice 1): forge carried ore into a sword at the anvil. The glut term makes
	# smithing attractive exactly when the ore market floors — the over-supply release valve.
	if int(hero.inv.get("iron_ore", 0)) >= 3:
		var glut: float = maxf(0.0, 6.0 - float(world.economy.sell_price("iron_ore"))) * 2.5
		var sterms: Array = [["base", 9.0 + hero.skill_level("smithing") * 0.4], ["glut", glut],
			["goal", Config.GOAL_BIAS if String(hero.goal.get("skill", "")) == "smithing" else 0.0],
			["sticky", Config.STICKY_BONUS if hero.act.get("intent", "") == "SMITH" else 0.0]]
		candidates.append(_finish({"intent": "SMITH", "loc": "anvil", "skill": "smithing", "res": ""}, sterms))
	if candidates.is_empty():
		candidates.append(_fallback(hero))   # never-empty-menu invariant
	return candidates

## Always-eligible productive default — head to town and sell whatever's carried (which frees cargo
## and unlocks gather next decision). The safety net that makes a starved menu impossible.
static func _fallback(hero: Hero) -> Dictionary:
	return _finish({"intent": "REGROUP", "loc": "shop", "skill": "", "res": ""}, [["fallback", 0.0]])

## skillNeed (concept-ported, the §18 saturation): distance-from-99 scaled by ambition — 0 at 99,
## so EVERY activity's appeal fades as mastery approaches; no activity can be a permanent refuge.
static func _skill_need(hero: Hero, skill: String) -> float:
	var l := hero.skill_level(skill)
	if l >= 99:
		return 0.0
	return (1.0 + (99.0 - l) / 99.0) * (float(hero.traits.get("ambition", 0.5)) * 0.5 + 0.75)

static func _finish(d: Dictionary, terms: Array) -> Dictionary:
	var s := 0.0
	for t in terms:
		s += float(t[1])
	d["terms"] = terms
	d["score"] = s
	return d

## FIGHT candidate (§18). Feasible if the hero has food or can afford it; cautious heroes
## (low risk trait) avoid it; fighting-favorite heroes strongly prefer it.
## NOTE the asymmetry vs gathering: combat has NO economic-reward term — its appeal is a flat base
## + Strength scaling, neither of which responds to prices/yield. Gathering's reward term saturates
## with price; combat's congestion is its ONLY negative feedback.
static func _score_fight(hero: Hero, world, camp: String = "combat", mon_id: String = "rat") -> Dictionary:
	# combat requires a MAIN-HAND weapon equipped; without one, the option is to BUY one (if affordable).
	# Buy-candidates emit once (on the rat-camp pass) so the camp loop doesn't duplicate them.
	if not hero.equipped.has("main"):
		# Unit 2: affordability reads the LIVE shop price (dynamic, scarcity-priced); the old flat
		# const survives only as the bare-rig fallback (legacy roster has no charge anchors).
		var wid: String = {"sword": "bronze_sword", "bow": "shortbow", "staff": "apprentice_staff"}[hero.weapon]
		var wcost: int = world.economy.buy_cost(wid)
		if wcost <= 0:
			wcost = Config.WEAPON_COST
		if camp == "combat" and hero.gold >= wcost + 10:
			return _finish({"intent": "BUY_WEAPON", "loc": "shop", "skill": "strength", "res": ""},
				[["base", 11.0], ["goal", Config.GOAL_BIAS if String(hero.goal.get("skill", "")) == "strength" else 0.0]])
		return {}
	if camp == "combat" and hero.weapon == "sword" and not hero.equipped.has("off") and hero.gold >= 120.0:
		return _finish({"intent": "BUY_OFFHAND", "loc": "shop", "skill": "strength", "res": ""},
			[["base", 12.5], ["sticky", Config.STICKY_BONUS if hero.act.get("intent", "") == "FIGHT" else 0.0]])
	# POWER GATE (§18 feasibility): don't pick fights you can't plausibly take
	var mon: Monster = world.content.monster(mon_id)
	if mon == null:
		return {}
	if mon.is_boss and not world.scurrius_unlocked:
		return {}   # locked boss camp (#1d) — no candidate until the kill-count gate opens
	if hero.skill_level(SimWorld.style_skill(hero)) + hero.skill_level("defence") < mon.combat_level:
		return {}
	var food := int(hero.inv.get("trout", 0))
	var food_price := int(world.economy.food_price())
	var can_fight := food >= 1 or hero.gold >= food_price * 2
	if not can_fight:
		return {}
	var terms: Array = []
	if Config.BRAIN_V2:
		# §18 SYMMETRY FIX: combat's base uses the SAME skillNeed-saturating form as gather — its appeal
		# falls as Strength approaches 99 and is no longer a flat, price-independent refuge.
		var fav_m := Config.FAVORITE_MULT if hero.favorite == "fighting" else 1.0
		terms.append(["base", 8.0 + _skill_need(hero, "strength") * 13.0 * fav_m])
		terms.append(["favorite", 0.0])
	else:
		terms.append(["base", 14.0 + hero.skill_level("strength") * 0.4])
		terms.append(["favorite", Config.FAVORITE_MULT * 10.0 if hero.favorite == "fighting" else 0.0])
	# coin reward — camps now differ economically (wizards/guards pay; chickens don't)
	var wealth_w := 0.6 + float(hero.traits.get("greed", 0.4))
	terms.append(["reward", (mon.coin_drop_min + mon.coin_drop_max) * 0.5 * 0.2 * wealth_w])
	# #3d KI-4 COUNTER-FORCE (default OFF): gear-drop reward coupled to the gear-board price. Combat's
	# only price-responsive feedback — the board crashes as fighters flood it and dump gear, so this
	# term saturates DOWNWARD and combat stops being the price-independent refuge (symmetric to gather).
	if Config.COMBAT_GEAR_REWARD:
		terms.append(["gear", world.economy.gear_board_ref_price() * Config.COMBAT_GEAR_K * wealth_w])
	# FUNDED BOUNTY (Unit 0 / R5): the posted per-kill payout enters through the SAME greed-weighted
	# reward shape — one number the player sets, attraction derived from the payout. Affordability-
	# gated by the same rule that gates payment, so an empty treasury attracts nobody.
	terms.append(["bounty", _bounty(world, mon_id) * 0.2 * wealth_w])
	terms.append(["congestion", -world.congestion(camp) * Config.CONGESTION_K * Config.COMBAT_CONGESTION_MULT])
	terms.append(["risk", -(1.0 - float(hero.traits.get("risk", 0.4))) * (4.0 + mon.max_hit * 2.0)])
	terms.append(["travel", -world.distance_to(hero, camp) * 0.4])
	terms.append(["food_pen", -6.0 if food < 1 else 0.0])
	terms.append(["sticky", Config.STICKY_BONUS if (hero.act.get("intent", "") == "FIGHT" and hero.act.get("loc", "") == camp) else 0.0])
	# (the clamped utility FIGHT incentive is RETIRED — R5: combat steering is the funded bounty above)
	terms.append(["goal", Config.GOAL_BIAS if String(hero.goal.get("skill", "")) == "strength" else 0.0])
	# Slayer on-task pull (Unit 0 / B2, R6): the camp hosting the hero's assigned monster gains a bounded
	# bonus — per-hero and task-rotated, so it steers without becoming a standing colony-wide attractor.
	terms.append(["task", Config.SLAYER_ON_TASK if String(hero.slayer_task.get("mon", "")) == mon_id else 0.0])
	return _finish({"intent": "FIGHT", "loc": camp, "skill": "strength", "res": ""}, terms)

static func _score(hero: Hero, world, intent: String) -> Dictionary:
	var skill := Activities.skill_of(intent)
	var loc_key := Activities.location_of(intent)
	# TOOL GATE: no tool in inventory → the candidate becomes "go BUY the tool" (same desire, −2 — the
	# acquisition step a real player takes; prevents tool-gating from locking heroes to their favorite)
	if Config.TOOL_FOR.has(skill) and int(hero.inv.get(Config.TOOL_FOR[skill], 0)) <= 0:
		var tcost: int = world.economy.buy_cost(String(Config.TOOL_FOR[skill]))
		if tcost <= 0:
			tcost = Config.TOOL_COST   # bare-rig fallback (legacy roster has no charge anchors)
		if hero.gold < tcost + 5:
			return _finish({"intent": intent, "loc": loc_key, "skill": skill, "res": ""}, [["unaffordable", -999.0]])
		var bt := _score_inner(hero, world, intent, skill, loc_key)
		bt["intent"] = "BUY_TOOL"
		bt["loc"] = "shop"
		bt["score"] = float(bt["score"]) - 2.0
		bt["terms"].append(["needs_tool", -2.0])
		return bt
	return _score_inner(hero, world, intent, skill, loc_key)

static func _score_inner(hero: Hero, world, intent: String, skill: String, loc_key: String) -> Dictionary:
	var terms: Array = []
	if Config.BRAIN_V2:
		# skillNeed-saturating base (same form as combat — symmetric), favorite folded in multiplicatively
		var fav_m := Config.FAVORITE_MULT if hero.favorite == skill else (Config.SECONDARY_MULT if hero.secondary == skill else 1.0)
		terms.append(["base", 8.0 + _skill_need(hero, skill) * 13.0 * fav_m])
		terms.append(["favorite", 0.0])
		# DEMAND-RESPONSIVE labor (the concept's economy→brain feedback): town food running low pulls fishers
		if intent == "PROVISION":
			var stock: int = world.economy.total_stock("trout")
			if stock < 12:
				terms.append(["demand", minf(20.0, (12.0 - stock) * 2.0) * (0.4 + float(hero.traits.get("greed", 0.4)))])
	else:
		terms.append(["base", 10.0 + hero.skill_level(skill) * 0.5])
		var fav := 0.0
		if hero.favorite == skill:
			fav = Config.FAVORITE_MULT * 10.0
		elif hero.secondary == skill:
			fav = Config.SECONDARY_MULT * 10.0
		terms.append(["favorite", fav])
	# expected wealth from this activity (greed-weighted) — the term that SATURATES with price. #5e-2:
	# reads the BEST venue (max of the shop price and any standing GE/city buy order) so a funded city
	# order pulls labor onto the good. Identical to the shop price while no buy order exists.
	var wealth_w := 0.6 + float(hero.traits.get("greed", 0.4))
	var price := int(world.best_sell_price(Activities.sells_as(intent)))
	terms.append(["reward", price * 0.25 * wealth_w])
	# self-balancing: crowded nodes are less attractive (§6 / §18.6)
	terms.append(["congestion", -world.congestion(loc_key) * Config.CONGESTION_K])
	# danger (#1d back-pressure): aggressive monsters sharing this workplace tax it, scaled by
	# frailty — a hurt or foodless hero looks elsewhere until passive regen restores them, while a
	# healthy provisioned one shrugs the harassment off. Without this term the goblin-shared willows
	# stayed the argmax for chipped-down woodcutters → measured death-loop (2,096 deaths/24k ticks).
	var threat: float = world.aggro_threat_at(loc_key)
	if threat > 0.0:
		var hp_frac := float(hero.hp) / maxf(1.0, float(hero.max_hp()))
		var foodless := 2.0 if int(hero.inv.get("trout", 0)) <= 0 else 1.0
		terms.append(["danger", -threat * (1.5 - hp_frac) * foodless])
	# travel cost
	terms.append(["travel", -world.distance_to(hero, loc_key) * 0.4])
	# anti-thrash hysteresis
	terms.append(["sticky", Config.STICKY_BONUS if hero.act.get("intent", "") == intent else 0.0])
	# Tier-1 Incentivize (§18.4): a posted bounty / standing priority raises this activity's utility
	# so the brain responds organically. 0 when the player hasn't set one → no behavior change.
	terms.append(["incentive", _incentive(world, intent)])
	# goal bias (§18.3): the active "train X to N" goal pulls toward its skill (cooking rides fishing)
	var gskill := String(hero.goal.get("skill", ""))
	terms.append(["goal", Config.GOAL_BIAS if (gskill == skill or (gskill == "cooking" and skill == "fishing")) else 0.0])
	return _finish({"intent": intent, "loc": loc_key, "skill": skill, "res": Activities.resource_of(intent)}, terms)

## The player's Tier-1 incentive weight for an intent (0 if none / no control layer). Read defensively
## so the brain still works in bare-bones test rigs that don't set up the incentives dict.
static func _incentive(world, intent: String) -> float:
	var inc = world.get("incentives")
	if inc is Dictionary:
		return float(inc.get(intent, 0.0))
	return 0.0

## The AFFORDABLE funded bounty on a monster (0 if none / treasury short / bare test rig). Reads the
## same affordability rule the payment uses, defensively like _incentive.
static func _bounty(world, mon_id: String) -> float:
	var b = world.get("bounties")
	if b is Dictionary and b.has(mon_id) and world.economy != null:
		var amt: float = float(b[mon_id])
		if float(world.economy.treasury) >= amt:
			return amt
	return 0.0
