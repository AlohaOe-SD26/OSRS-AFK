extends SceneTree
## Labor-distribution diagnostic (Step-3 monoculture investigation). Runs a colony to ~40 heroes
## and prints the activity histogram, a favorite-vs-current-intent cross-tab (to see whether heroes
## follow their favorite or get pulled elsewhere), the gather/food prices, per-capita gold, and the
## social friend count — the BEFORE/AFTER measurement the planner asked for. Run:
##   godot --headless --path game --script res://tools/diag_labor.gd

const DAYS := 23

func _initialize() -> void:
	var content := ContentDB.new()
	if not content.load_all("res://data"):
		push_error("diag_labor: content DB failed to load")
		quit(1)
		return
	var world := SimWorld.new()
	var tele := Telemetry.new(Config.DEFAULT_SEED)
	world.telemetry = tele
	world.setup(content, 6, Config.DEFAULT_SEED)
	var actions := int(DAYS / SimWorld._DD_PER_ACTION)
	for i in range(actions):
		world.tick(SimWorld._ACTION_SECONDS)

	var pop := world.heroes.size()
	var gold := world.total_gold()
	# intent histogram + favorite histogram + cross-tab (favorite==fighting following fight?)
	var by_intent := {}
	var by_fav := {}
	var fav_match := 0          # heroes whose current intent matches their favorite leaning
	var nonfav_fighting := 0    # NON-fighting-favorite heroes currently fighting (the tell)
	for h in world.heroes:
		var intent: String = h.act.get("intent", "idle")
		if intent == "":
			intent = "idle"
		by_intent[intent] = int(by_intent.get(intent, 0)) + 1
		by_fav[h.favorite] = int(by_fav.get(h.favorite, 0)) + 1
		var follows: bool = (intent == "FIGHT" and h.favorite == "fighting") \
			or (intent != "FIGHT" and intent != "idle" and Activities.skill_of(intent) == h.favorite)
		if follows:
			fav_match += 1
		if intent == "FIGHT" and h.favorite != "fighting":
			nonfav_fighting += 1

	print("=== LABOR DIAGNOSTIC — day %d ===" % world.sim_day)
	print("population: %d  ·  total gold: %d  ·  per-capita: %d" % [pop, gold, int(round(float(gold) / maxi(1, pop)))])
	print("prices: ore %dg · logs %dg · food %dg  (floor frac %.2f×base)" % [
		world.economy.sell_price("iron_ore"), world.economy.sell_price("logs"), world.economy.food_price(), Config.PRICE_FLOOR_FRAC])
	print("shop stock: ore %d/%d · logs %d/%d · cooked_fish %d/%d" % [
		world.economy.shop_for("iron_ore").total_stock("iron_ore"), int(world.economy.shop_for("iron_ore").maximum["iron_ore"]),
		world.economy.shop_for("logs").total_stock("logs"), int(world.economy.shop_for("logs").maximum["logs"]),
		world.economy.total_stock("trout"), int(world.economy.shop_for("trout").maximum["trout"])])
	print("pop_scale (heroes/baseline): %.2f  →  effective town demand = base × this" % (float(pop) / float(Config.POP_BASELINE)))
	var im := ""
	for k in by_intent:
		im += "%s %d · " % [k, by_intent[k]]
	print("ACTIVITY (current intent): %s" % im.trim_suffix("· "))
	var fm := ""
	for k in by_fav:
		fm += "%s %d · " % [k, by_fav[k]]
	print("FAVORITE leanings:          %s" % fm.trim_suffix("· "))
	print("following-favorite: %d/%d  ·  NON-fighting-favorite heroes currently fighting: %d" % [fav_match, pop, nonfav_fighting])
	if world.social != null:
		var th: Dictionary = world.social.tier_histogram(world.sim_day)
		print("social: %d edges · friends %d · rivals %d · nemeses %d" % [world.social.edge_count(), th["Friend"], th["Rival"], th["Nemesis"]])

	# CADENCE PROBE (§18.6): snapshot each hero's intent + decision-count, run 2 more sim-days,
	# and measure DECISION POINTS REACHED per hero — split by fighters vs gatherers. This is the
	# MECHANISM check (did fighters start re-deciding at all?), distinct from the OUTCOME (did the
	# labor mix change?). Pre-trip-completion, fighters reached ~0 decision points over days.
	var before_dec := {}
	var was_fighting := {}
	var fighters0 := 0
	var gatherers0 := 0
	for h in world.heroes:
		before_dec[h.id] = h.decisions
		var intent: String = h.act.get("intent", "idle")
		was_fighting[h.id] = (intent == "FIGHT")
		if intent == "FIGHT":
			fighters0 += 1
		elif Activities.is_gather(intent):
			gatherers0 += 1
	var probe_actions := int(2.0 / SimWorld._DD_PER_ACTION)
	for i in range(probe_actions):
		world.tick(SimWorld._ACTION_SECONDS)
	var f_dec := 0
	var g_dec := 0
	for h in world.heroes:
		if not before_dec.has(h.id):
			continue
		var delta: int = h.decisions - int(before_dec[h.id])
		if was_fighting[h.id]:
			f_dec += delta
		else:
			g_dec += delta
	print("CADENCE PROBE (decision points over 2 sim-days): fighters %d total = %.1f/fighter · gatherers/other %.1f/hero" % [
		f_dec, float(f_dec) / maxf(1.0, float(fighters0)), float(g_dec) / maxf(1.0, float(world.heroes.size() - fighters0))])
	quit(0)
