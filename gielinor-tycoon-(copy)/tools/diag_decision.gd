extends SceneTree
## DECISION-LEVEL INSTRUMENT (pure observation — no interventions). Answers: when a fighter
## re-decides, what does it actually SEE, term by term, and why does combat win? Runs a colony to
## ~40 heroes, then for the puzzle group (NON-fighting-favorite heroes currently fighting) replays
## their re-decision point — act cleared so it's a faithful fresh choice (no stickiness; combat
## congestion excludes the hero itself) — and reports the average candidate utility breakdown plus
## concrete examples. The brain attaches the same "terms" it scores with, so this cannot diverge.
##   godot --headless --path game --script res://tools/diag_decision.gd

const DAYS := 23

func _initialize() -> void:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(Config.DEFAULT_SEED)
	world.setup(content, 6, Config.DEFAULT_SEED)
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)

	# sanity: does combat congestion equal the fight head-count? (if not, fighters' loc != "combat")
	var fight_n := 0
	for h in world.heroes:
		if h.act.get("intent", "") == "FIGHT":
			fight_n += 1
	print("=== DECISION INSTRUMENT — day %d · pop %d ===" % [world.sim_day, world.heroes.size()])
	print("fight-intent heroes: %d · congestion(\"combat\"): %d · congestion(mine/forest/fishing): %d/%d/%d" % [
		fight_n, world.congestion("combat"), world.congestion("mine"), world.congestion("forest"), world.congestion("fishing")])
	print("ore sell %dg · food price %dg\n" % [world.economy.sell_price("ore"), world.economy.food_price()])

	# aggregate term breakdown for NON-fighting-favorite heroes currently fighting (the puzzle)
	var agg_combat := {}
	var agg_gather := {}
	var n := 0
	var examples: Array = []
	for h in world.heroes:
		if h.act.get("intent", "") != "FIGHT" or h.favorite == "fighting":
			continue
		var cands := _rededecide(h, world)
		var combat: Dictionary = _find(cands, "FIGHT")
		var best_gather: Dictionary = _best_non_fight(cands)
		if combat.is_empty() or best_gather.is_empty():
			continue
		_accum(agg_combat, combat)
		_accum(agg_gather, best_gather)
		n += 1
		if examples.size() < 3:
			examples.append({"h": h, "combat": combat, "gather": best_gather})

	print("NON-fighting-favorite heroes currently fighting: %d  (their favorite is a GATHER skill)" % n)
	if n > 0:
		print("AVG candidate utility at their fresh re-decision (act cleared — no stickiness):")
		_print_avg("  COMBAT     ", agg_combat, n)
		_print_avg("  best GATHER", agg_gather, n)
		print("  → combat wins by %.1f on average\n" % ((_sum(agg_combat) - _sum(agg_gather)) / float(n)))

	# LOCK ANALYSIS: if combat loses at re-decision (it does), the monoculture is a re-decision lock.
	# Two candidate locks: (1) kills-gated trip-completion unreachable (few rats → most fighters get
	# no kills → never hit N kills → never re-decide); (2) food-hoard space gate suppresses gather.
	var k0 := 0       # fighters stuck at 0 kills this trip
	var k_lt := 0     # fighters below the trip-completion threshold
	var space_gated := 0
	var kmax := 0
	for h in world.heroes:
		if h.act.get("intent", "") != "FIGHT":
			continue
		var k: int = int(h.act.get("kills", 0))
		kmax = maxi(kmax, k)
		if k == 0:
			k0 += 1
		if k < Config.COMBAT_TRIP_KILLS:
			k_lt += 1
		if (28 - h.inv_count()) <= 4:
			space_gated += 1
	print("LOCK ANALYSIS (of %d current fighters):" % fight_n)
	print("  at 0 kills this trip: %d · below the N=%d completion threshold: %d · max kills any: %d" % [k0, Config.COMBAT_TRIP_KILLS, k_lt, kmax])
	print("  food-hoard space-gated (no gather candidates offered): %d" % space_gated)
	# 2-day window: how many CURRENT fighters actually reach a decision point (act emptied)?
	var fid := {}
	for h in world.heroes:
		if h.act.get("intent", "") == "FIGHT":
			fid[h.id] = h.decisions
	for i in range(int(2.0 / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var redecided := 0
	for h in world.heroes:
		if fid.has(h.id) and h.decisions > int(fid[h.id]):
			redecided += 1
	print("  of those %d fighters, only %d reached a decision point over the next 2 sim-days\n" % [fid.size(), redecided])

	for ex: Dictionary in examples:
		var h: Hero = ex["h"]
		print("example: %s (favorite %s · STR %d · mine %d wc %d fish %d · %dg · %d food)" % [
			h.hero_name, h.favorite, h.skill_level("strength"),
			h.skill_level("mining"), h.skill_level("woodcutting"), h.skill_level("fishing"),
			int(h.gold), int(h.inv.get("cooked_fish", 0))])
		print("   COMBAT      %s" % _fmt(ex["combat"]))
		print("   %s %s" % [("%s(fav)" % SimWorld._cap(ex["gather"]["skill"])).rpad(11), _fmt(ex["gather"])])
	quit(0)

func _rededecide(h: Hero, world) -> Array:
	var saved: Dictionary = h.act
	h.act = {}                                      # faithful fresh decision: no stickiness, self not at combat
	var cands := Brain.candidates_with_terms(h, world)
	h.act = saved
	return cands

func _find(cands: Array, intent: String) -> Dictionary:
	for c in cands:
		if c["intent"] == intent:
			return c
	return {}

func _best_non_fight(cands: Array) -> Dictionary:
	var best := {}
	for c in cands:
		if c["intent"] == "FIGHT":
			continue
		if best.is_empty() or float(c["score"]) > float(best["score"]):
			best = c
	return best

func _accum(agg: Dictionary, cand: Dictionary) -> void:
	for t in cand["terms"]:
		agg[t[0]] = float(agg.get(t[0], 0.0)) + float(t[1])

func _sum(agg: Dictionary) -> float:
	var s := 0.0
	for k in agg:
		s += float(agg[k])
	return s

func _print_avg(label: String, agg: Dictionary, n: int) -> void:
	var parts: Array = []
	var total := 0.0
	for k in agg:
		var v: float = float(agg[k]) / float(n)
		total += v
		parts.append("%s %.1f" % [k, v])
	print("%s total %.1f   [%s]" % [label, total, ", ".join(PackedStringArray(parts))])

func _fmt(cand: Dictionary) -> String:
	var parts: Array = []
	for t in cand["terms"]:
		parts.append("%s %.1f" % [t[0], float(t[1])])
	return "total %.1f  [%s]" % [float(cand["score"]), ", ".join(PackedStringArray(parts))]
