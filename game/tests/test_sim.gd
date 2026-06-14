extends SceneTree
## Headless test harness for the SIM CORE. Run:
##   godot --headless --script res://tests/test_sim.gd
## Exits 0 on all-pass, 1 on any failure. This is the Godot-side equivalent of the browser
## validation done on the prototype: it asserts the canon math AND that the tuned economy
## stays bounded over a multi-day run (no runaway, no starvation).

# preloaded by path, not class_name — the standing harness rule (no --import dependency)
const SimHash := preload("res://tools/sim_hash.gd")
const SaveLoad := preload("res://sim/SaveLoad.gd")

var failures: int = 0
var checks: int = 0

func _check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  PASS  ", msg)
	else:
		failures += 1
		print("  FAIL  ", msg)

func _initialize() -> void:
	print("=== GIELINOR TYCOON — SIM CORE TESTS ===")
	# #13: pin the LOCKED founder template for the suite so role-dependent checks (heroes[0] is a miner,
	# etc.) stay stable; the rolled path has its own dedicated test (_test_unit13_founders).
	Config.FOUNDERS_LOCKED = true
	_test_xp_curve()
	_test_combat_math()
	_test_shops_first_class()
	_test_economy_equilibrium()
	_test_offline_catchup()
	_test_live_combat()
	_test_population_dynamics()
	_test_social_graph()
	_test_control_tiers()
	_test_town_building()
	_test_social_negatives()
	_test_civic_kick()
	_test_chronicle_narrative()
	_test_slayer()
	_test_funded_bounty()
	_test_aggro_and_boss()
	_test_saveload()
	_test_unit1_catalog()
	_test_unit2_shops()
	_test_unit2c_bias()
	_test_unit2d_combat_gear()
	_test_unit3a_param_nudge()
	_test_unit3b_feasibility()
	_test_unit13_founders()
	_test_unit14_immigrants()
	_test_unit15_immigrant_gear()
	_test_unit5a_bank()
	_test_unit5b_ge_orderbook()
	# Guard against false greens: if a script error aborts a test function mid-way, its remaining
	# _check() calls silently don't run. Assert the full expected count actually executed.
	const EXPECTED := 224
	var incomplete := checks != EXPECTED
	if incomplete:
		print("  WARN  only %d/%d expected checks ran — a test aborted (script error?)" % [checks, EXPECTED])
	print("\n=== %d/%d checks passed (%d ran) ===" % [checks - failures, checks, checks])
	quit(1 if (failures > 0 or incomplete) else 0)

func _test_xp_curve() -> void:
	print("\n[XP curve — canon, EQUATIONS §1]")
	_check(XpTables.xp_for_level(99) == 13034431, "level 99 total XP = 13,034,431")
	_check(XpTables.xp_for_level(92) == 6517253, "level 92 total XP = 6,517,253 (≈ half of 99)")
	_check(abs(XpTables.xp_for_level(92) - XpTables.xp_for_level(99) / 2) < 1000, "92 is within 1k of half-of-99")
	_check(XpTables.level_for_xp(XpTables.xp_for_level(50)) == 50, "level_for_xp round-trips at 50")
	_check(XpTables.level_for_xp(0) == 1, "0 XP = level 1")
	_check(XpTables.combat_level(1, 1, 1, 10, 1, 1, 1) == 3, "fresh hero combat level = 3")

func _test_combat_math() -> void:
	print("\n[Combat math — canon, EQUATIONS §2]")
	_check(Combat.max_hit(40, 80) == 9, "max_hit(effStr 40, gearStr 80) = 9")
	_check(Combat.average_hit(9) == 5.0, "average_hit(9) = 5.0")
	_check(Combat.hit_chance(2000, 1000) > 0.5, "attack > defence → acc > 0.5")
	_check(Combat.hit_chance(1000, 2000) < 0.5, "attack < defence → acc < 0.5")
	var d := Combat.dps(5.0, 0.5, 4)
	_check(d > 0.0 and d < 5.0, "dps positive and sane (%.3f)" % d)
	_check(Combat.fight_is_winnable(2.0, 0.2, 15, 30, 0, 1.0), "strong hero vs weak rat is winnable")
	_check(not Combat.fight_is_winnable(0.1, 5.0, 500, 20, 0, 1.0), "weak hero vs boss is NOT winnable")

func _test_shops_first_class() -> void:
	print("\n[NPC shops — first-class entities, §6/§19.2]")
	var eco := Economy.new()
	_check(eco.shops.size() == 2, "two canon shops exist (General Store + Fishmonger)")
	var gen: Shop = eco.shop_for("iron_ore")
	_check(gen != null and gen.trades("logs"), "General Store trades ore AND logs (inspectable)")
	_check(eco.shop_for("iron_ore").level == 1, "shop level is inspectable (starts 1 — §19.2 dial for Step 4)")
	# saturation-aware price: a full shop pays strictly less than a near-empty one
	var empty := eco.sell_price("iron_ore")
	gen.stock["iron_ore"] = gen.maximum["iron_ore"]
	var full := eco.sell_price("iron_ore")
	_check(full < empty, "sell price falls as stock saturates (%d full < %d empty)" % [full, empty])
	_check(full >= int(round(gen.base["iron_ore"] * Config.PRICE_FLOOR_FRAC)), "saturated price respects the floor (anti-leak)")
	# GE-tax is now tracked first-class
	var eco2 := Economy.new()
	var seller := Hero.new()
	seller.inv = {"iron_ore": 10}
	eco2.sell_goods(seller)
	_check(eco2.tax_collected > 0.0, "GE-tax accrues to tax_collected (%.2fg skimmed)" % eco2.tax_collected)

func _test_economy_equilibrium() -> void:
	print("\n[Economy equilibrium — VALIDATED sinks, §6]")
	var content := ContentDB.new()
	if not content.load_all("res://data"):
		_check(false, "content DB loaded")
		return
	_check(content.items.size() > 0, "items.json loaded (%d items)" % content.items.size())
	_check(content.monsters.size() > 0, "monsters.json loaded (%d monsters)" % content.monsters.size())
	_check(content.map_data.has("locations"), "map locations loaded")

	var world := SimWorld.new()
	var tele := Telemetry.new(Config.DEFAULT_SEED)
	world.telemetry = tele
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false   # fixed-population regression guard for the ATTRACTOR (§6)

	# fast-forward ~12 sim-days (one tick == one work-action here)
	var ticks := 12000
	for i in range(ticks):
		world.tick(SimWorld._ACTION_SECONDS)

	var n := tele.dbg_log.size()
	_check(n > 50, "captured telemetry snapshots (%d)" % n)
	# steady-state drift: middle third vs last third
	var mid: Array = []
	var late: Array = []
	for i in range(n):
		if i >= n / 3 and i < 2 * n / 3:
			mid.append(tele.dbg_log[i]["gold"])
		elif i >= 2 * n / 3:
			late.append(tele.dbg_log[i]["gold"])
	var mid_avg := _avg(mid)
	var late_avg := _avg(late)
	var drift := int(round((late_avg - mid_avg) / max(1.0, mid_avg) * 100.0))
	var final_gold := world.total_gold()
	print("    total gold day %d = %d · steady-state drift %d%%" % [world.sim_day, final_gold, drift])
	_check(final_gold > 800, "economy not starved (gold %d > 800)" % final_gold)
	_check(final_gold < 40000, "economy not inflating (gold %d < 40000 for 6 heroes)" % final_gold)
	_check(abs(drift) < 60, "steady-state drift bounded (|%d%%| < 60)" % drift)

func _test_offline_catchup() -> void:
	print("\n[Offline catch-up — §4 / §3]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 3, Config.DEFAULT_SEED)
	# put a hero on a known gather activity
	world.heroes[0].act = {"intent": "GATHER_ORE", "loc": "mine", "skill": "mining", "res": "iron_ore", "phase": "gather", "target": "mine", "then": ""}
	var s10 := world.offline_catchup(10.0)
	_check(s10["hours"] == 10.0, "10h elapsed not capped")
	_check(s10["gold"] >= 0, "offline gold accrued (%d)" % s10["gold"])
	# the instance-#5 fix: the attractor projection bounds the batch (the old linear model gave ~118k/10h)
	_check(int(s10["gold"]) < 8000, "offline batch is attractor-bounded, not linear (%dg < 8000 for a 10h miner)" % s10["gold"])
	var s48 := world.offline_catchup(48.0)
	_check(s48["hours"] == Config.OFFLINE_CAP_HOURS, "48h capped to 24h")
	# the 24h cap clamps the YIELD, not just the reported hours: identical worlds, 24h vs 30h → same gain
	var wa := SimWorld.new()
	wa.setup(content, 6, Config.DEFAULT_SEED)
	var wb := SimWorld.new()
	wb.setup(content, 6, Config.DEFAULT_SEED)
	for i in range(1000):
		wa.tick(SimWorld._ACTION_SECONDS)
		wb.tick(SimWorld._ACTION_SECONDS)
	var ga := wa.offline_catchup(24.0)
	var gb := wb.offline_catchup(30.0)
	_check(int(ga["gold"]) == int(gb["gold"]), "cap clamps the yield: gain(24h) == gain(30h) (%d == %d)" % [int(ga["gold"]), int(gb["gold"])])
	# the offline batch is an approximation, but the CONTINUATION after it is still exactly deterministic
	for i in range(800):
		wa.tick(SimWorld._ACTION_SECONDS)
		wb.tick(SimWorld._ACTION_SECONDS)
	_check(SimHash.state_string(wa) == SimHash.state_string(wb),
		"post-offline continuation is deterministic (two same-seed offline runs stay identical)")
	# equipment (M1d): equipping moves the item OUT of the inventory; one per slot; swap returns the old
	var eh := Hero.new()
	eh.inv = {"iron_sword": 1, "Steel sword": 1}
	var n0 := eh.inv_count()
	eh.equip_item("main", "iron_sword")
	_check(eh.inv_count() == n0 - 1 and String(eh.equipped["main"]) == "iron_sword",
		"equip moves the item out of the inventory into its slot (frees space)")
	eh.equip_item("main", "Steel sword")
	_check(String(eh.equipped["main"]) == "Steel sword" and int(eh.inv.get("iron_sword", 0)) == 1,
		"one item per slot — equipping a second swaps the old piece back to the inventory")

func _test_live_combat() -> void:
	print("\n[Live combat — §10 / §14]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	var tele := Telemetry.new(Config.DEFAULT_SEED)
	world.telemetry = tele
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false   # fixed-population regression guard for the combat loop
	_check(world.monsters.size() == 19, "19 monsters spawned across the 6 camps (rats/chickens/cows/wizards/barbarians/goblins)")
	var food_min := 999
	var food_sum := 0
	var samples := 0
	for i in range(8000):
		world.tick(SimWorld._ACTION_SECONDS)
		if i % 50 == 0:
			var fs := world.economy.total_stock("trout")
			food_min = mini(food_min, fs)
			food_sum += fs
			samples += 1
	var kills_per_event := float(world.total_kills) / maxf(1.0, world.deaths + world.flees)
	print("    kills %d · deaths %d · flees %d · kills/(death+flee) %.2f · gold %d" % [world.total_kills, world.deaths, world.flees, kills_per_event, world.total_gold()])
	print("    shop food: min %d · avg %d  (fighters' fuel — if min≈0 the cooks/town under-supply)" % [food_min, int(food_sum / maxi(1, samples))])
	_check(world.total_kills > 0, "heroes killed rats (%d)" % world.total_kills)
	var trained := false
	for h in world.heroes:
		if h.favorite == "fighting" and maxi(h.skill_level("strength"), maxi(h.skill_level("ranged"), h.skill_level("magic"))) > 8:
			trained = true
	_check(trained, "a fighter trained their STYLE skill past its head-start via combat")
	var all_alive := true
	for h in world.heroes:
		if h.hp <= 0:
			all_alive = false
	_check(all_alive, "no hero stuck at 0 HP (death/respawn works)")
	var fg := world.total_gold()
	_check(fg > 500 and fg < 60000, "economy still bounded with the fighter food-sink (gold %d)" % fg)

func _test_population_dynamics() -> void:
	print("\n[Population & immigration — §16.1/§19.4 — the planner's two watch numbers]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	var tele := Telemetry.new(Config.DEFAULT_SEED)
	world.telemetry = tele
	world.setup(content, 6, Config.DEFAULT_SEED)   # immigration ON (default)
	# fast-forward ~23 sim-days so the population curve grows and approaches its plateau
	for i in range(24000):
		world.tick(SimWorld._ACTION_SECONDS)
	var p: Population = world.population
	var pop := world.heroes.size()
	print("    pop 6 -> %d / cap %d · arrivals %d · departures %d · rep %d" % [pop, Config.POP_CAP, p.arrivals, p.departures, int(p.reputation)])
	var th := ""
	for k in p.tier_counts:
		th += "%s %d  " % [k, p.tier_counts[k]]
	print("    newcomer tiers: %s" % th)

	_check(p.arrivals > 0, "immigration occurred (%d arrivals)" % p.arrivals)
	_check(pop > 6, "population grew from the founding 6 (now %d)" % pop)
	_check(pop <= Config.POP_CAP, "population never exceeds the cap (%d <= %d)" % [pop, Config.POP_CAP])
	_check(p.reputation > Config.REP_BASE, "colony earned reputation above base (%d > %d)" % [int(p.reputation), int(Config.REP_BASE)])

	var n := tele.dbg_log.size()
	# population stabilizes (no oscillation): the head-count band over the last third stays tight
	var late_min := 9999
	var late_max := 0
	for i in range(n):
		if i >= 2 * n / 3:
			var pv: int = tele.dbg_log[i]["pop"]
			late_min = mini(late_min, pv)
			late_max = maxi(late_max, pv)
	print("    late-run population band: %d..%d (swing %d)" % [late_min, late_max, late_max - late_min])
	_check(late_max - late_min <= 6, "population stabilizes, doesn't oscillate (late swing %d <= 6)" % (late_max - late_min))

	# gold bounded AS POPULATION CHANGES: per-capita gold stays in a sane band across the run
	var gpc_min := 999999
	var gpc_max := 0
	for i in range(n):
		if i >= n / 4:   # skip the cold-start warmup
			var g: int = tele.dbg_log[i]["gpc"]
			gpc_min = mini(gpc_min, g)
			gpc_max = maxi(gpc_max, g)
	print("    per-capita gold band (post-warmup): %d..%d" % [gpc_min, gpc_max])
	_check(gpc_min > 120, "per-capita gold never starves as population scales (min %d > 120)" % gpc_min)
	_check(gpc_max < 8000, "per-capita gold never inflates as population scales (max %d < 8000)" % gpc_max)

func _test_social_graph() -> void:
	print("\n[Social relationship graph — §16.3/§9 — sparse + lazy decay]")
	var soc := Social.new()
	# repeated co-bonding (as the proximity pass does) should climb into Friend/Ally tier
	for d in range(1, 30):
		soc._bump(0, 1, 1.5, d)
		soc._bump(1, 0, 1.5, d)
	var r01 := soc.get_r(0, 1, 30)
	print("    after 29 days co-located: R(0->1) = %.1f (%s)" % [r01, soc.tier(0, 1, 30)])
	_check(r01 > Config.REL_FRIEND, "repeated co-bonding reaches Friend+ (R=%.1f)" % r01)
	var t := soc.tier(0, 1, 30)
	_check(t == "Friend" or t == "Ally", "tier classification works (%s)" % t)
	_check(soc.trade_modifier(0, 1, 30) < 1.0, "trade-pref: a friendship DISCOUNTS the price (×%.2f)" % soc.trade_modifier(0, 1, 30))
	# sparse storage: an untouched pair has no edge and reads 0; only touched edges are stored
	_check(soc.get_r(0, 5, 30) == 0.0, "untouched pair reads 0 (sparse — no edge stored)")
	_check(soc.edge_count() == 2, "only the 2 touched directed edges exist (sparse, %d)" % soc.edge_count())
	# lazy decay toward 0 when not reinforced, then self-prune
	var faded := soc.get_r(0, 1, 60)
	_check(faded < r01 and faded > 0.0, "edge decays toward 0 when not reinforced (%.1f -> %.1f)" % [r01, faded])
	var pruned := soc.get_r(0, 1, 4000)
	_check(pruned == 0.0, "a fully-faded edge self-prunes to 0 (keeps storage sparse)")
	# the hostile side + its trade markup
	var soc2 := Social.new()
	for d in range(1, 60):
		soc2._bump(2, 3, -2.0, d)
	var t2 := soc2.tier(2, 3, 60)
	_check(t2 == "Nemesis" or t2 == "Rival", "negative deltas reach Rival/Nemesis (%s)" % t2)
	_check(soc2.trade_modifier(2, 3, 60) > 1.0, "trade-pref: a hostile bond MARKS UP the price (×%.2f)" % soc2.trade_modifier(2, 3, 60))
	# live integration: a running colony fills the graph, and it stays sparse/bounded
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false   # fixed 6 heroes → a clean directed-pair bound to assert
	for i in range(4000):
		world.tick(SimWorld._ACTION_SECONDS)
	var ec: int = world.social.edge_count()
	var max_pairs: int = world.heroes.size() * (world.heroes.size() - 1)
	print("    live 6-hero colony: %d social edges (<= %d directed pairs)" % [ec, max_pairs])
	_check(ec > 0, "a live colony populates the social graph (%d edges)" % ec)
	_check(ec <= max_pairs, "graph stays within the directed-pair bound (sparse, %d <= %d)" % [ec, max_pairs])

func _test_control_tiers() -> void:
	print("\n[Player control tiers — §2/§18.4 — incentivize / nudge / seize]")
	var content := ContentDB.new()
	content.load_all("res://data")

	# --- Tier-1 INCENTIVIZE: a posted bounty adds exactly its weight to the activity's brain utility ---
	var w1 := SimWorld.new()
	w1.setup(content, 6, Config.DEFAULT_SEED)
	var hg: Hero = w1.heroes[0]
	hg.inv["bronze_axe"] = 1   # tool-gated now: give the axe so the candidate is the ACTIVITY, not the purchase
	var s0 := _cand_score(Brain.candidates_with_terms(hg, w1), "GATHER_LOGS")
	w1.set_incentive("GATHER_LOGS", 20.0)
	var s1 := _cand_score(Brain.candidates_with_terms(hg, w1), "GATHER_LOGS")
	_check(abs((s1 - s0) - 20.0) < 0.001, "incentive adds exactly its weight to the activity utility (%.1f -> %.1f)" % [s0, s1])
	w1.set_incentive("GATHER_ORE", 999.0)
	_check(abs(float(w1.incentives["GATHER_ORE"]) - Config.INCENTIVE_MAX) < 0.001, "incentive clamps at INCENTIVE_MAX (survival can't be crowded out)")
	w1.set_incentive("GATHER_LOGS", 0.0)
	_check(not w1.incentives.has("GATHER_LOGS"), "setting weight 0 clears the incentive")

	# colony-scale direction (single seed, pop fixed): a heavy incentive must not REDUCE target labor.
	# The rigorous mean±SD magnitude is tools/diag_incentive.gd (multi-seed, per measurement-discipline).
	var ctrl := _count_intent_after_run(Config.DEFAULT_SEED, "", 0.0, "GATHER_LOGS")
	var inc := _count_intent_after_run(Config.DEFAULT_SEED, "GATHER_LOGS", Config.INCENTIVE_MAX, "GATHER_LOGS")
	print("    labor pull (1 seed, integrated): GATHER_LOGS hero-samples  control %d -> incentivized %d" % [ctrl, inc])
	_check(inc > ctrl, "Tier-1 incentive pulls labor onto the target (%d > %d samples; magnitude in diag_incentive.gd)" % [inc, ctrl])

	# --- Tier-2 NUDGE: one-off injected activity that wins the next decision, then resumes autonomy ---
	var w2 := SimWorld.new()
	w2.setup(content, 6, Config.DEFAULT_SEED)
	var hn: Hero = w2.heroes[0]   # a mining-favorite founder
	var queued := w2.nudge_hero(hn, "GATHER_LOGS")
	_check(queued and not hn.nudge.is_empty() and hn.act.is_empty(), "nudge queued and current trip interrupted")
	w2.tick(SimWorld._ACTION_SECONDS)   # one work-action consumes the nudge
	_check(String(hn.act.get("intent", "")) == "GATHER_LOGS", "nudge wins the next decision (now chopping logs, not its favorite)")
	_check(hn.nudge.is_empty(), "nudge is consumed (one-off, not sticky)")
	hn.act = {}                          # simulate the nudged trip ending
	w2.tick(SimWorld._ACTION_SECONDS)
	_check(not hn.act.is_empty() and hn.nudge.is_empty(), "hero resumes autonomous decisions after the nudge")

	# --- Tier-3 SEIZE: brain suspended; player drives; clean release ---
	var w3 := SimWorld.new()
	w3.setup(content, 6, Config.DEFAULT_SEED)
	var hs: Hero = w3.heroes[2]
	w3.seize_hero(hs)
	_check(hs.seized, "seize sets the suspended flag")
	hs.act = {}
	var dec_before := hs.decisions
	for i in range(20):
		w3.tick(SimWorld._ACTION_SECONDS)
	_check(hs.act.is_empty() and hs.decisions == dec_before, "seized brain is SUSPENDED — no autonomous decisions")
	var commanded := w3.command_seized(hs, "GATHER_ORE")
	_check(commanded and String(hs.act.get("intent", "")) == "GATHER_ORE", "command_seized issues a direct activity")
	w3.release_hero(hs)
	_check(not hs.seized, "release clears the suspended flag")
	hs.act = {}
	w3.tick(SimWorld._ACTION_SECONDS)
	_check(not hs.act.is_empty(), "released hero resumes autonomous decisions")

func _test_town_building() -> void:
	print("\n[Town building & upgrades — §19 — the tycoon layer]")
	# treasury is fed by the GE-tax skim (gold already removed from hero circulation → attractor untouched)
	var eco := Economy.new()
	var seller := Hero.new()
	seller.inv = {"iron_ore": 20}
	eco.sell_goods(seller)
	_check(eco.treasury > 0.0, "treasury accrues from the GE-tax skim (%.1fg)" % eco.treasury)
	_check(abs(eco.treasury - eco.tax_collected) < 0.001, "treasury equals cumulative tax (same skim, double-booked for inspection)")

	# §19.2 shop leveling: stock capacity AND town demand scale by the SAME factor (faucet/sink invariant)
	var gen: Shop = eco.shop_for("iron_ore")
	eco.treasury = 100000.0
	var lvl0 := gen.level
	var max0: float = gen.maximum["iron_ore"]
	var con0: float = gen.consume["iron_ore"]
	var cost := eco.shop_upgrade_cost(gen)
	var tre0 := eco.treasury
	var up := eco.try_upgrade_shop(gen)
	var factor := 1.0 + Config.SHOP_CAP_PER_LEVEL
	_check(up and gen.level == lvl0 + 1, "shop upgrade raises the level (%d -> %d)" % [lvl0, gen.level])
	_check(abs(gen.maximum["iron_ore"] - max0 * factor) < 0.01, "upgrade scales stock capacity (×%.2f)" % factor)
	_check(abs(gen.consume["iron_ore"] - con0 * factor) < 0.01, "upgrade scales town demand by the SAME factor (bounded by construction)")
	_check(abs(eco.treasury - (tre0 - float(cost))) < 0.001, "upgrade debits the treasury by its cost (%dg)" % cost)
	eco.treasury = 0.0
	_check(not eco.try_upgrade_shop(gen), "upgrade fails when the treasury can't afford it")

	# §19.3 buildings: treasury debit + reputation/satisfaction contribution + a daily upkeep sink
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.economy.treasury = 5000.0
	var built := world.build("lodge")
	_check(built and world.buildings.size() == 1, "build() places a structure and debits the treasury")
	_check(world.town_satisfaction_bonus() > 0.0, "amenity contributes per-hero satisfaction (+%.0f)" % world.town_satisfaction_bonus())
	_check(world.town_reputation_bonus() > 0.0, "building contributes town reputation (+%.0f)" % world.town_reputation_bonus())
	world.population.update_reputation(world)
	var rep_with := world.population.reputation
	world.buildings.clear()
	world.population.update_reputation(world)
	var rep_without := world.population.reputation
	_check(rep_with > rep_without, "a building raises town reputation (%.0f > %.0f → faster immigration, §16)" % [rep_with, rep_without])
	world.build("monument")
	var t_before := world.economy.treasury
	world._town_daily()
	_check(world.economy.treasury < t_before, "building upkeep drains the treasury daily (the §6 continuous sink)")

	# the §6.5-by-construction claim: heavy shop investment keeps per-capita gold BOUNDED (no re-tune)
	var bw := _run_with_upgrades(Config.DEFAULT_SEED, 5)
	print("    heavy shop-leveling run (both shops +5): total gold day-end = %d (6 heroes)" % bw)
	_check(bw > 500 and bw < 60000, "economy stays bounded under heavy shop investment (gold %d)" % bw)

func _test_social_negatives() -> void:
	print("\n[Social negative deltas — §16.3/§9, Step 5]")
	var soc := Social.new()
	soc.record_vote(0, 1, true, 1)    # hero 0 resents 1 (a yes-voter)
	_check(abs(soc.get_r(0, 1, 1) - Config.REL_VOTE_YES) < 0.01, "yes-vote applies the resentment delta (%.0f)" % Config.REL_VOTE_YES)
	soc.record_vote(0, 2, false, 1)   # hero 0 warms to 2 (a defender)
	_check(abs(soc.get_r(0, 2, 1) - Config.REL_VOTE_DEFEND) < 0.01, "defend-vote applies the warmth delta (+%.0f)" % Config.REL_VOTE_DEFEND)
	var soc2 := Social.new()
	soc2.record_graveloot(0, 3, 1)
	_check(abs(soc2.get_r(0, 3, 1) - Config.REL_GRAVELOOT) < 0.01, "gravestone-loot applies the grudge delta (wired, dormant)")
	# competition friction: MORE fighters than rats at the pit accrues rivalry over repeated passes
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 8, Config.DEFAULT_SEED)   # 8 fighters vs 4 rats → contested
	world.population.enabled = false
	for h in world.heroes:
		h.act = {"intent": "FIGHT", "loc": "combat", "skill": "strength", "res": "", "phase": "fight"}
	for d in range(1, 40):
		world.social._proximity_pass(world, 1.0)
	var any_negative := false
	for a in world.social.adj:
		for b in world.social.adj[a]:
			if float(world.social.get_r(int(a), int(b), 40)) < 0.0:
				any_negative = true
	_check(any_negative, "competition friction: an overcrowded rat pit (fighters > rats) breeds rivalry")

func _test_civic_kick() -> void:
	print("\n[Civic kick vote — §16.2, Step 5]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false
	var target: Hero = world.heroes[0]
	# everyone busy fighting → turnout below quorum → VOID (does not consume an attempt)
	for h in world.heroes:
		h.act = {"intent": "FIGHT", "loc": "combat", "phase": "fight"}
	var r_void := world.start_kick_vote(target)
	_check(String(r_void["outcome"]) == "void", "sub-quorum vote is VOID (turnout below 25%)")
	_check(int(world.kick_records.get(target.id, {}).get("failed", 0)) == 0, "a void vote does NOT consume a kick attempt")
	# everyone available + everyone LOVES the target → defenders win → FAIL (target stays, warmth banked)
	for h in world.heroes:
		h.act = {}
		if h != target:
			world.social._bump(h.id, target.id, 100.0, world.sim_day)
	var r := world.start_kick_vote(target)
	_check(String(r["outcome"]) == "fail", "a vote on a beloved hero FAILS — defenders win (%d–%d)" % [int(r["yes"]), int(r["no"])])
	_check(world.heroes.has(target), "a failed vote leaves the target in the colony")
	_check(float(world.social.get_r(target.id, world.heroes[1].id, world.sim_day)) > 0.0, "defenders earn the target's warmth (+ delta)")
	# god force-kick exiles outright
	var t2: Hero = world.heroes[2]
	var before := world.heroes.size()
	var ok := world.force_kick(t2, true)
	_check(ok and world.heroes.size() == before - 1 and not world.heroes.has(t2), "force-kick exiles the hero (removed from the colony)")
	# the failsafe unlocks after KICK_FORCE_AFTER failed votes
	world.kick_records[target.id] = {"failed": Config.KICK_FORCE_AFTER, "cooldown_until": 0.0}
	_check(world.can_force_kick(target), "force-kick failsafe unlocks after %d failed votes" % Config.KICK_FORCE_AFTER)

func _test_chronicle_narrative() -> void:
	print("\n[Chronicle social narrative — §17, Step 5]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.chronicle.clear()
	# forge a strong mutual feud between heroes 0 and 1
	world.social._bump(0, 1, -70.0, world.sim_day)
	world.social._bump(1, 0, -70.0, world.sim_day)
	world._chronicle_social_daily()
	var found_feud := false
	for ev in world.chronicle:
		var c := String(ev.get("cls", ""))
		if c == "nemesis" or c == "rival":
			found_feud = true
	_check(found_feud, "a forged feud is narrated into the Chronicle")
	_check(world.heroes[0].milestones.size() > 0, "the feud is recorded in the hero's saga (milestone)")
	var n_before := world.chronicle.size()
	world._chronicle_social_daily()
	_check(world.chronicle.size() == n_before, "an unchanged bond is not re-narrated (de-dup)")

func _test_slayer() -> void:
	print("\n[Slayer — Unit 0 / spec B2 under rulings R4–R6]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false
	var h: Hero = null
	for c in world.heroes:
		if c.favorite == "fighting":
			h = c
			break
	_check(h != null, "found a fighter to test with")
	# canon Combat-40 gate (R4): fresh heroes are well below it → Vannaka ignores them
	_check(world.combat_level_of(h) < Config.SLAYER_COMBAT_GATE,
		"fresh fighter is below the Combat-40 gate (cl %d)" % world.combat_level_of(h))
	_check(not world._wants_slayer_task(h), "no Vannaka detour below the gate")
	world._boost(h, SimWorld.style_skill(h), 60)
	world._boost(h, "defence", 60)
	h.hp = h.max_hp()
	h.gold = 200.0   # solvent → the FIGHT candidates exist (food-or-gold gate) for the term check below
	_check(world.combat_level_of(h) >= Config.SLAYER_COMBAT_GATE, "boosted fighter passes the gate")
	# knowledge gate (B2): nothing has been killed yet → empty pool even past the combat gate
	_check(world.slayer_pool(h).is_empty(), "unknown monsters → empty task pool (knowledge gate)")
	world.kill_counts["rat"] = Config.SLAYER_KNOWLEDGE
	_check(not world.slayer_pool(h).is_empty(), "colony knowledge (%d rat kills) unlocks the rat task" % Config.SLAYER_KNOWLEDGE)
	_check(world._wants_slayer_task(h), "eligible taskless fighter now wants a task")
	world._assign_slayer_task(h)
	_check(not h.slayer_task.is_empty() and String(h.slayer_task["mon"]) == "rat", "Vannaka assigns a rat task")
	var total := int(h.slayer_task.get("total", 0))
	_check(total >= 14 and total <= 35, "task sized in the HP-10..19 band 14–35 (%d)" % total)
	# the on-task bonus appears on the FIGHT candidate for exactly the task camp (R6: open +20)
	var on := 0.0
	for c2 in Brain.candidates_with_terms(h, world):
		if String(c2.get("intent", "")) == "FIGHT" and String(c2.get("loc", "")) == String(h.slayer_task["camp"]):
			for t in c2["terms"]:
				if String(t[0]) == "task":
					on = float(t[1])
	_check(absf(on - Config.SLAYER_ON_TASK) < 0.01, "on-task camp carries the +%d pull in fight scoring" % int(Config.SLAYER_ON_TASK))
	# kill attribution → completion: slayer XP, points, task cleared, colony knowledge grows
	h.slayer_task["remaining"] = 1
	var mon: Monster = content.monster("rat")
	var mi := MonsterInstance.from_type(mon, Vector2.ZERO)
	var pts_before := h.slayer_points
	var sxp_before := h.skill_xp("slayer")
	world._record_kill(h, mi, mon)
	_check(h.slayer_task.is_empty(), "task completes at 0 remaining")
	_check(h.slayer_points >= pts_before + Config.SLAYER_POINTS_MIN, "slayer points awarded (+%d)" % (h.slayer_points - pts_before))
	_check(h.skill_xp("slayer") > sxp_before, "on-task kill grants slayer XP (≈0.9×HP)")
	_check(int(world.kill_counts["rat"]) == Config.SLAYER_KNOWLEDGE + 1, "colony kill_counts increments on the kill")

func _test_funded_bounty() -> void:
	print("\n[Funded per-kill bounty — Unit 0 / R5 (one lever, two effects; utility FIGHT incentive retired)]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false
	world.set_incentive("FIGHT", 24.0)
	_check(not world.incentives.has("FIGHT"), "set_incentive(FIGHT) is rejected — utility combat bounty retired")
	var rat: Monster = content.monster("rat")
	world.set_bounty("rat", 999.0)
	_check(absf(float(world.bounties["rat"]) - world.bounty_cap(rat)) < 0.01,
		"bounty clamps to 3× avg coin drop (%.1fg)" % world.bounty_cap(rat))
	var h: Hero = null
	for c in world.heroes:
		if c.favorite == "fighting":
			h = c
			break
	h.gold = 200.0
	world.economy.treasury = 1000.0
	var wealth_w := 0.6 + float(h.traits.get("greed", 0.4))
	_check(absf(_fight_term(h, world, "combat", "bounty") - float(world.bounties["rat"]) * 0.2 * wealth_w) < 0.01,
		"bounty term = payout × 0.2 × (0.6+greed) — attraction derives from the payout")
	world.economy.treasury = 0.0
	_check(_fight_term(h, world, "combat", "bounty") == 0.0,
		"empty treasury → zero attraction (same affordability rule as payment)")
	world.economy.treasury = 100.0
	var mi := MonsterInstance.from_type(rat, Vector2.ZERO)
	var g0 := h.gold
	world._record_kill(h, mi, rat)
	_check(absf(h.gold - g0 - world.bounty_cap(rat)) < 0.01
		and absf(world.economy.treasury - (100.0 - world.bounty_cap(rat))) < 0.01,
		"a kill pays the bounty treasury → hero")
	world.economy.treasury = 1.0
	g0 = h.gold
	world._record_kill(h, mi, rat)
	_check(h.gold == g0 and world.economy.treasury == 1.0,
		"treasury short → the kill pays nothing (overdraw impossible)")

func _test_aggro_and_boss() -> void:
	print("\n[Aggressive monsters + Scurrius kill-count gate — Unit 0 #1d]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	world.population.enabled = false
	var boss_count := 0
	for m in world.monsters:
		if m.type_id == "scurrius":
			boss_count += 1
	_check(boss_count == 0, "Scurrius does not spawn while the gate is locked")
	var h: Hero = null
	for c in world.heroes:
		if c.favorite == "fighting":
			h = c
			break
	world._boost(h, SimWorld.style_skill(h), 90)
	world._boost(h, "defence", 90)
	h.hp = h.max_hp()
	h.gold = 500.0
	_check(_fight_term(h, world, "scurrius", "base") < -1e8,
		"even an endgame-strength hero gets no candidate for the locked lair")
	world.kill_counts["rat"] = Config.SCURRIUS_UNLOCK_KILLS
	world.tick(SimWorld._ACTION_SECONDS)
	_check(world.scurrius_unlocked, "the gate opens at %d colony rat kills" % Config.SCURRIUS_UNLOCK_KILLS)
	var spawned := false
	for m in world.monsters:
		if m.type_id == "scurrius" and m.alive:
			spawned = true
	_check(spawned, "Scurrius spawns at his nest on unlock")
	_check(_fight_term(h, world, "scurrius", "base") > -1e8, "the strong hero now sees the boss candidate")
	# aggressive strike: a hurt worker adjacent to a goblin abandons the trip and falls back to town
	var gob: MonsterInstance = null
	for m in world.monsters:
		if m.type_id == "goblin" and m.alive:
			gob = m
			break
	var g: Hero = world.heroes[0]   # a miner — non-FIGHT intent
	g.hp = 4
	g.inv.erase("trout")
	g.act = {"intent": "GATHER_LOGS", "loc": "forest", "phase": "gather"}
	g.pos = gob.pos
	world._monster_strike_hero(gob, content.monster("goblin"), g)
	_check(g.act.is_empty() and g.thought.begins_with("Harassed"),
		"a struck worker abandons the trip and falls back to town")
	var d0 := world.deaths
	world._hero_death(g, "a goblin")
	_check(world.deaths == d0 + 1 and g.pos == world.location_tile("shop"),
		"shared death handler: counter increments, hero respawns at town")
	# passive regen (canon 1 HP/min): the RECOVERY half of harassment — without it a foodless
	# chipped-down worker can never heal and the aggro loop converges on death (measured)
	g.hp = 3
	for i in range(Config.REGEN_EVERY_ACTIONS + 1):
		world.tick(SimWorld._ACTION_SECONDS)
	_check(g.hp > 3, "passive regen heals a hurt hero (1 HP per %d actions)" % Config.REGEN_EVERY_ACTIONS)
	# a lair boss punishes trespassers only — never passers-by (else he farms the adjacent rat pit)
	var boss: MonsterInstance = null
	for m in world.monsters:
		if m.type_id == "scurrius" and m.alive:
			boss = m
			break
	var pb: Hero = world.heroes[1]
	pb.hp = pb.max_hp()
	pb.act = {"intent": "GATHER_ORE", "loc": "mine", "phase": "gather"}
	pb.pos = boss.pos
	boss.atk_cd = 0.0
	world._tick_monsters(0.05)
	_check(boss.atk_cd == 0.0 and pb.hp == pb.max_hp(), "a lair boss ignores a passer-by (no strike)")
	pb.act = {"intent": "FIGHT", "loc": "scurrius", "phase": "travel"}
	pb.pos = boss.pos
	world._tick_monsters(0.05)
	_check(boss.atk_cd > 0.0, "...but strikes a trespasser who came for him")
	# canon aggression tolerance: a settled worker is ignored; a fresh arrival is fair game
	var gob2: MonsterInstance = null
	for m in world.monsters:
		if m.type_id == "goblin" and m.alive:
			gob2 = m
			break
	var wc2: Hero = world.heroes[3]
	for c in world.heroes:   # park everyone else in town so wc2 is the only prey in radius
		if c != wc2:
			c.pos = world.location_tile("shop")
	wc2.hp = wc2.max_hp()
	wc2.act = {"intent": "GATHER_LOGS", "loc": "forest", "phase": "gather"}
	wc2.pos = gob2.pos
	gob2.atk_cd = 0.0
	wc2.tol_t = Config.AGGRO_TOLERANCE_S + 1.0
	world._tick_monsters(0.05)
	_check(gob2.atk_cd == 0.0, "a settled worker (past tolerance) is ignored by aggressive monsters")
	wc2.tol_t = 0.0
	world._tick_monsters(0.05)
	_check(gob2.atk_cd > 0.0, "...a fresh arrival is struck (harassment = arrival tax)")
	# danger back-pressure: the goblin-shared willows carry a frailty-scaled penalty in gather scoring
	var wc: Hero = world.heroes[2]
	wc.inv["bronze_axe"] = 1
	wc.inv.erase("trout")
	wc.hp = maxi(1, int(wc.max_hp() * 0.3))
	var hurt_pen := _gather_term(wc, world, "GATHER_LOGS", "danger")
	wc.hp = wc.max_hp()
	wc.inv["trout"] = 2
	var fed_pen := _gather_term(wc, world, "GATHER_LOGS", "danger")
	_check(hurt_pen < fed_pen and fed_pen < 0.0,
		"goblin-shared willows carry a danger term; hurt+foodless deepens it (%.1f < %.1f)" % [hurt_pen, fed_pen])

## The named term's value on the `intent` gather candidate (-1e9 if candidate/term absent).
func _gather_term(h: Hero, world: SimWorld, intent: String, term: String) -> float:
	for c in Brain.candidates_with_terms(h, world):
		if String(c.get("intent", "")) == intent:
			for t in c["terms"]:
				if String(t[0]) == term:
					return float(t[1])
	return -1e9

## The named term's value on the FIGHT candidate for `camp` (-1e9 if candidate/term absent).
func _fight_term(h: Hero, world: SimWorld, camp: String, term: String) -> float:
	for c in Brain.candidates_with_terms(h, world):
		if String(c.get("intent", "")) == "FIGHT" and String(c.get("loc", "")) == camp:
			for t in c["terms"]:
				if String(t[0]) == term:
					return float(t[1])
	return -1e9

func _test_saveload() -> void:
	print("\n[Save/load — §25, Step 6 — the determinism invariant applied to persistence]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	for i in range(3000):
		world.tick(SimWorld._ACTION_SECONDS)
	_check(SaveLoad.save_to_file(world, "user://test_save.dat"), "save writes a file (binary Variant)")
	var loaded: SimWorld = SaveLoad.load_from_file(content, "user://test_save.dat")
	_check(loaded != null, "load reads it back")
	_check(SimHash.state_string(world) == SimHash.state_string(loaded),
		"loaded state ≡ saved state (full fingerprint incl. RNG state + monsters)")
	for i in range(2000):
		world.tick(SimWorld._ACTION_SECONDS)
		loaded.tick(SimWorld._ACTION_SECONDS)
	_check(SimHash.state_string(world) == SimHash.state_string(loaded),
		"continued evolution stays identical (deterministic continuation, 2000 ticks)")

	# --- migration scaffold (R10) — upgrader-chain walker; ruled contract: a migrated save loads
	# validly and continues deterministically FROM THE LOAD POINT (cross-version byte-equivalence
	# to historical runs is explicitly NOT required).
	var cur: Dictionary = SaveLoad.save_world(world)
	_check(SaveLoad.migrate(cur) == cur, "migrate() is identity at the current version")
	var future: Dictionary = cur.duplicate(true)
	future["version"] = SaveLoad.SAVE_VERSION + 1
	_check(SaveLoad.migrate(future).is_empty(),
		"future/unknown version is unmigratable → rejected (old strict check survives)")
	# synthetic v0 save (field stripped) + injected upgrader: walks the chain back to current
	var old: Dictionary = cur.duplicate(true)
	old["version"] = 0
	old.erase("paused")
	var up0 := func(d: Dictionary) -> Dictionary:
		var nd: Dictionary = d.duplicate(true)
		nd["paused"] = false
		nd["version"] = SaveLoad.SAVE_VERSION
		return nd
	var migrated: Dictionary = SaveLoad.migrate(old, {0: up0})
	_check(not migrated.is_empty() and migrated.has("paused"),
		"synthetic v0 save walks the upgrader chain to current")
	var from_migrated: SimWorld = SaveLoad.load_world(content, migrated)
	_check(from_migrated != null and SimHash.state_string(from_migrated) == SimHash.state_string(world),
		"migrated save loads validly (state ≡ source world)")
	for i in range(500):
		world.tick(SimWorld._ACTION_SECONDS)
		from_migrated.tick(SimWorld._ACTION_SECONDS)
	_check(SimHash.state_string(world) == SimHash.state_string(from_migrated),
		"migrated world continues deterministically from the load point (500 ticks)")
	# --- the REAL v1→v2 upgrader (Unit 0, Slayer): a stripped v1 save walks the production chain
	var v1: Dictionary = SaveLoad.save_world(world)
	v1["version"] = 1
	v1.erase("kill_counts")
	v1.erase("slayer_tasks_assigned")
	v1.erase("bounties")
	v1.erase("scurrius_unlocked")
	for md in v1["monsters"]:
		md.erase("atk_cd")
	for hd in v1["heroes"]:
		hd.erase("slayer_task")
		hd.erase("slayer_points")
		hd.erase("tol_t")
		hd["skills"].erase("slayer")
	var v2: Dictionary = SaveLoad.migrate(v1)
	_check(int(v2.get("version", -1)) == SaveLoad.SAVE_VERSION and v2.has("kill_counts"),
		"v1 save migrates to v%d via the production chain" % SaveLoad.SAVE_VERSION)
	var w2: SimWorld = SaveLoad.load_world(content, v2)
	_check(w2 != null and w2.heroes[0].slayer_task.is_empty() and w2.heroes[0].skill_level("slayer") == 1,
		"migrated v1 world loads with Slayer defaults in place")

func _test_unit1_catalog() -> void:
	print("\n[Unit 1 — catalog migration: catalog-driven prices/gear/recipes + v2→v3 save upgrade]")
	var content := ContentDB.new()
	content.load_all("res://data")
	# KI-8 RESOLVED: shop base values come from the catalog (single price truth)
	var eco := Economy.new(content)
	_check(absf(float(eco.shop_for("iron_ore").base["iron_ore"]) - float(content.base_value("iron_ore"))) < 0.01
		and content.base_value("iron_ore") == 17,
		"shop base values are catalog-sourced (KI-8: iron_ore 17, not the old hardcoded 16)")
	# shops trade gear: since Unit 2 the specialist roster owns the boards (R3 — swordshop trades swords)
	var gshop: Shop = eco.shop_for("iron_sword")
	_check(gshop != null and gshop.npc_id == "swordshop", "shops trade gear (iron_sword routed to the Swordshop)")
	_check(eco.sell_price("iron_sword") == int(round(content.base_value("iron_sword") * 0.5)),
		"gear board opens at the old half-value anchor (fill 0.5 → f 0.5 → %dg)" % eco.sell_price("iron_sword"))
	var gh := Hero.new()
	gh.inv = {"iron_sword": 1, "bronze_pickaxe": 1}
	var tax0: float = eco.tax_collected
	var got := eco.sell_goods(gh)
	_check(got > 0 and not gh.inv.has("iron_sword") and eco.tax_collected > tax0,
		"carried gear vendors through the shop board, taxed like any sale (+%dg)" % got)
	_check(int(gh.inv.get("bronze_pickaxe", 0)) == 1, "untradeable items (tools/ammo) never vendor")
	# recipes-as-data
	var cook: ItemType = content.craft_output("cooking", "raw_trout")
	_check(cook != null and cook.id == "trout" and cook.craft_xp() == 6,
		"cooking recipe comes from the catalog (raw_trout → trout, craftXp 6)")
	var smith: ItemType = content.craft_output("smithing", "iron_ore")
	_check(smith != null and smith.id == "iron_sword" and smith.recipe().size() == 3,
		"smithing recipe comes from the catalog (3× iron_ore → iron_sword)")
	_check(content.gear_drop_pool().size() == 7, "gear drop pool is catalog-flagged (7 dropPool items)")
	# --- the REAL v2→v3 upgrader: a v2-shaped save (LEGACY ids) walks the production chain
	var world := SimWorld.new()
	world.setup(content, 4, Config.DEFAULT_SEED)
	var v2s: Dictionary = SaveLoad.save_world(world)
	v2s["version"] = 2
	var h0: Dictionary = v2s["heroes"][0]
	h0["inv"] = {"ore": 3, "cooked_fish": 2, "Iron sword": 1}
	h0["equipped"] = {"main": "Bronze sword"}
	# a TRUE v2 shops array: exactly the two pre-roster shops with legacy ids (the current save has
	# 7 shops — leaving extras in would defeat the v4 upgrader's append-by-npc_id and fake the test)
	v2s["shops"] = [
		{"npc_id": "general_store",
			"stock": {"ore": 20.0, "logs": 20.0}, "maximum": {"ore": 120.0, "logs": 120.0},
			"base": {"ore": 16.0, "logs": 12.0}, "consume": {"ore": 350.0, "logs": 350.0}, "level": 1},
		{"npc_id": "fishmonger",
			"stock": {"raw_fish": 10.0, "cooked_fish": 14.0}, "maximum": {"raw_fish": 80.0, "cooked_fish": 80.0},
			"base": {"raw_fish": 7.0, "cooked_fish": 9.0}, "consume": {"raw_fish": 0.0, "cooked_fish": 60.0},
			"level": 1},
	]
	for c in ["treasury_in_tax", "treasury_in_routing", "treasury_out_bounty",
			"treasury_out_upgrade", "treasury_out_building"]:
		v2s.erase(c)
	var v3: Dictionary = SaveLoad.migrate(v2s)
	_check(int(v3.get("version", -1)) == SaveLoad.SAVE_VERSION, "v2 save migrates to v%d via the production chain" % SaveLoad.SAVE_VERSION)
	var h0m: Dictionary = v3["heroes"][0]
	_check(int(h0m["inv"].get("iron_ore", 0)) == 3 and int(h0m["inv"].get("trout", 0)) == 2
		and int(h0m["inv"].get("iron_sword", 0)) == 1 and not h0m["inv"].has("ore"),
		"v3 upgrader renames inventory keys to canon catalog ids")
	_check(String(h0m["equipped"]["main"]) == "bronze_sword", "v3 upgrader renames equipped item ids")
	var w3: SimWorld = SaveLoad.load_world(content, v3)
	var gen3: Shop = w3.economy.shop_for("iron_ore")
	var sw3: Shop = w3.economy.shop_for("iron_sword")
	_check(w3 != null and gen3 != null and absf(float(gen3.base["iron_ore"]) - 17.0) < 0.01
		and sw3 != null and float(sw3.stock.get("iron_sword", -1.0)) == 4.0,
		"migrated v2 world loads with the catalog iron_ore base AND gear stocked on the v4 roster")

func _test_unit2_shops() -> void:
	print("\n[Unit 2 — shop economy v2: roster, dynamic buy pricing, imports, unlocks, treasury ledger]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var eco := Economy.new(content)
	_check(eco.shops.size() == 7 and eco.shop_for("arrows").npc_id == "lowe"
		and eco.shop_for("runes").npc_id == "aubury" and eco.shop_for("bronze_sword").npc_id == "swordshop"
		and eco.shop_for("wooden_shield").npc_id == "horvik" and eco.shop_for("bronze_pickaxe").npc_id == "general_store",
		"7-shop roster loads from shops.json with R3 routing (Lowe/Aubury/Swordshop/Horvik/General)")
	_check(eco.buy_cost("bronze_sword") == 30 and eco.buy_cost("bronze_pickaxe") == 12
		and eco.buy_cost("arrows") == 12 and eco.buy_cost("wooden_shield") == 35,
		"dynamic charge prices reproduce the validated flat costs at baseline fill (30/12/12/35)")
	var lowe: Shop = eco.shop_for("arrows")
	lowe.stock["arrows"] = 1.0
	var scarce := eco.buy_cost("arrows")
	lowe.stock["arrows"] = lowe.maximum["arrows"]
	var glut := eco.buy_cost("arrows")
	lowe.stock["arrows"] = 60.0
	_check(scarce > 12 and glut < 12, "buy price rises when scarce (%dg) and falls when glutted (%dg)" % [scarce, glut])
	var buyer := Hero.new()
	buyer.gold = 1000.0
	var t0: float = eco.treasury
	var p0 := eco.buy_cost("bronze_sword")
	var got := eco.buy_item(buyer, "bronze_sword", 1)
	_check(got == 1 and absf(eco.treasury - t0 - p0 * Config.PURCHASE_TREASURY_ROUTE) < 0.01
		and absf(eco.treasury_in_routing - p0 * Config.PURCHASE_TREASURY_ROUTE) < 0.01
		and absf(buyer.gold - (1000.0 - p0)) < 0.01,
		"purchase draws real stock; hero pays full price; 40%% routes to the treasury (R1)")
	eco.shop_for("bronze_sword").stock["bronze_sword"] = 0.0
	_check(eco.buy_item(buyer, "bronze_sword", 1) == 0, "out-of-stock goods cannot be bought (supply-gated, R3)")
	_check(eco.buy_item(buyer, "iron_sword", 1) == 0, "tier-2 stock is locked behind shop level (unlockLevel 2)")
	eco.shop_for("iron_sword").level_up()
	_check(eco.buy_item(buyer, "iron_sword", 1) == 1, "leveling the shop unlocks tier-2 stock for purchase")
	var vendor := Hero.new()
	vendor.inv = {"iron_sword": 1}
	var eco2 := Economy.new(content)
	_check(eco2.sell_goods(vendor) > 0, "vendoring is NOT level-gated (a dropped iron sword sells at level 1)")
	var eco3 := Economy.new(content)
	var l3: Shop = eco3.shop_for("arrows")
	l3.stock["arrows"] = 0.0
	eco3.shop_for("iron_ore").stock["iron_ore"] = 0.0
	for i in range(40):
		eco3.economy_tick(0.1, [])
	_check(float(l3.stock["arrows"]) > 45.0,
		"ambient imports restock purchasables toward baseline (C5: %.1f/60 after 4 days)" % float(l3.stock["arrows"]))
	_check(float(eco3.shop_for("iron_ore").stock["iron_ore"]) == 0.0,
		"hero-supplied goods (baseline 0) never import — the gather faucet stays the sole supply")
	var feed := Hero.new()
	feed.gold = 100.0
	var eco4 := Economy.new(content)
	var fr0: float = eco4.treasury
	var fb := eco4.buy_food(feed, 1)
	_check(fb == 1 and eco4.treasury > fr0 and eco4.treasury_in_routing > 0.0,
		"food purchases route the R1 treasury share too")
	var seller := Hero.new()
	seller.inv = {"iron_ore": 10}
	eco4.sell_goods(seller)
	_check(eco4.treasury_in_tax > 0.0, "treasury ledger tracks tax inflow")
	eco4.treasury = 100000.0
	eco4.try_upgrade_shop(eco4.shop_for("iron_ore"))
	_check(eco4.treasury_out_upgrade > 0.0, "treasury ledger tracks upgrade outflow")
	# --- the REAL v3→v4 upgrader: a v3-shaped save (gear on the General-Store board) walks the chain
	var world := SimWorld.new()
	world.setup(content, 4, Config.DEFAULT_SEED)
	var v3s: Dictionary = SaveLoad.save_world(world)
	v3s["version"] = 3
	for c in ["treasury_in_tax", "treasury_in_routing", "treasury_out_bounty",
			"treasury_out_upgrade", "treasury_out_building"]:
		v3s.erase(c)
	v3s["shops"] = [
		{"npc_id": "general_store",
			"stock": {"iron_ore": 25.0, "logs": 20.0, "iron_sword": 7.0, "bronze_sword": 4.0},
			"maximum": {"iron_ore": 120.0, "logs": 120.0, "iron_sword": 8.0, "bronze_sword": 8.0},
			"base": {"iron_ore": 17.0, "logs": 12.0, "iron_sword": 60.0, "bronze_sword": 26.0},
			"consume": {"iron_ore": 350.0, "logs": 350.0, "iron_sword": 0.25, "bronze_sword": 0.25},
			"level": 1},
		{"npc_id": "fishmonger",
			"stock": {"raw_trout": 10.0, "trout": 14.0}, "maximum": {"raw_trout": 80.0, "trout": 80.0},
			"base": {"raw_trout": 7.0, "trout": 9.0}, "consume": {"raw_trout": 0.0, "trout": 60.0},
			"level": 2},
	]
	var v4: Dictionary = SaveLoad.migrate(v3s)
	_check(int(v4.get("version", -1)) == SaveLoad.SAVE_VERSION and v4["shops"].size() == 7,
		"v3 save migrates to v%d (7-shop roster)" % SaveLoad.SAVE_VERSION)
	var sw: Dictionary = {}
	var genm: Dictionary = {}
	for sd in v4["shops"]:
		if String(sd["npc_id"]) == "swordshop":
			sw = sd
		elif String(sd["npc_id"]) == "general_store":
			genm = sd
	_check(not sw.is_empty() and absf(float(sw["stock"]["iron_sword"]) - 7.0) < 0.01
		and not genm["stock"].has("iron_sword") and genm["stock"].has("bronze_pickaxe")
		and float(v4.get("treasury_in_routing", -1.0)) == 0.0,
		"v4 upgrader transplants evolved gear stock to its new shop, strips the old board, adds tools + ledger")
	var w4: SimWorld = SaveLoad.load_world(content, v4)
	_check(w4 != null and w4.economy.shop_for("iron_sword").npc_id == "swordshop"
		and w4.economy.shops.size() == 7 and (w4.economy.shops[1] as Shop).level == 2,
		"migrated v3 world loads on the v4 roster (fishmonger keeps its evolved level)")

func _test_unit2c_bias() -> void:
	print("\n[Unit 2 #3c — price-bias lever: clamp, treasury-funded overpay, underpay, brain coupling]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var eco := Economy.new(content)
	eco.set_price_bias("iron_ore", 99.0)
	var clamped_hi: float = eco.bias_of("iron_ore")
	eco.set_price_bias("iron_ore", 0.01)
	var clamped_lo: float = eco.bias_of("iron_ore")
	_check(absf(clamped_hi - Config.PRICE_BIAS_MAX) < 0.001 and absf(clamped_lo - Config.PRICE_BIAS_MIN) < 0.001,
		"bias clamps to the swept band [%.0f%%, %.0f%%]" % [Config.PRICE_BIAS_MIN * 100, Config.PRICE_BIAS_MAX * 100])
	# funded overpay advertises AND pays; the premium is drawn from the treasury
	eco.treasury = 1000.0
	eco.set_price_bias("iron_ore", Config.PRICE_BIAS_MAX)
	var base_p: int = eco.shop_for("iron_ore").sell_price("iron_ore")
	_check(eco.sell_price("iron_ore") == int(round(base_p * Config.PRICE_BIAS_MAX)),
		"funded overpay advertises the biased price (%dg → %dg)" % [base_p, eco.sell_price("iron_ore")])
	var seller := Hero.new()
	seller.inv = {"iron_ore": 5}
	var paid := eco.sell_goods(seller)
	_check(eco.treasury_out_bias > 0.0 and paid > base_p * 5 * 0.9,
		"overpay premium is treasury-funded (out_bias %.0fg on a %dg sale)" % [eco.treasury_out_bias, paid])
	# unfunded overpay degrades to the base price (no overdraw, like bounties)
	var eco2 := Economy.new(content)
	eco2.treasury = 0.0
	eco2.set_price_bias("iron_ore", Config.PRICE_BIAS_MAX)
	var b2: int = eco2.shop_for("iron_ore").sell_price("iron_ore")
	_check(eco2.sell_price("iron_ore") == b2, "unfunded overpay never advertises (treasury empty → base price)")
	# underpay pays less and creates NO treasury flow (the savings were never minted)
	var eco3 := Economy.new(content)
	eco3.set_price_bias("iron_ore", Config.PRICE_BIAS_MIN)
	var s3 := Hero.new()
	s3.inv = {"iron_ore": 5}
	var paid3 := eco3.sell_goods(s3)
	var b3: int = eco3.shop_for("iron_ore").sell_price("iron_ore")
	_check(paid3 < b3 * 5 and eco3.treasury_out_bias == 0.0 and absf(eco3.treasury - eco3.treasury_in_tax) < 0.001,
		"underpay shrinks the faucet with zero treasury flow (%dg for 5 units)" % paid3)
	# brain coupling: the gather reward term reads the biased price → the lever steers organically
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	var hg: Hero = world.heroes[0]
	hg.inv["bronze_pickaxe"] = 1
	var s_before := _cand_score(Brain.candidates_with_terms(hg, world), "GATHER_ORE")
	world.economy.treasury = 10000.0
	world.economy.set_price_bias("iron_ore", Config.PRICE_BIAS_MAX)
	var s_after := _cand_score(Brain.candidates_with_terms(hg, world), "GATHER_ORE")
	_check(s_after > s_before, "the brain's reward term reads the biased price (score %.1f → %.1f)" % [s_before, s_after])
	# v4→v5 migration: the v4→v5 upgrader injects the bias dict + premium counter; the chain then
	# carries them up to the current SAVE_VERSION (version-agnostic so later bumps don't break this).
	var v4s: Dictionary = SaveLoad.save_world(world)
	v4s["version"] = 4
	v4s.erase("price_bias")
	v4s.erase("treasury_out_bias")
	var v5: Dictionary = SaveLoad.migrate(v4s)
	_check(int(v5.get("version", -1)) == SaveLoad.SAVE_VERSION and v5.has("price_bias") and float(v5.get("treasury_out_bias", -1.0)) == 0.0,
		"v4 save migrates up the chain (bias dict + premium counter present at v%d)" % SaveLoad.SAVE_VERSION)

## #3d — KI-4 combat-side counter-force: the gear-drop reward term is gated by COMBAT_GEAR_REWARD,
## reads the gear-board reference price, and SATURATES DOWNWARD as the board fills (the negative
## feedback combat lacked). Default OFF → no term, so the rest of the suite/sim is untouched.
func _test_unit2d_combat_gear() -> void:
	print("\n[Unit 2 #3d — combat gear-drop reward coupling (KI-4 counter-force): flag, price coupling, default-OFF]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	# a feasible rat-fighter: bow main (no off-hand check), fed, leveled past the rat power gate
	var h: Hero = world.heroes[0]
	h.weapon = "bow"
	h.equipped["main"] = "shortbow"
	h.inv["trout"] = 5
	h.skills["ranged"] = {"level": 5, "xp": 0}; h.skills["defence"] = {"level": 5, "xp": 0}
	var ref_p := world.economy.gear_board_ref_price()
	# default OFF: no gear term on the FIGHT candidate (and the global default must be OFF)
	Config.COMBAT_GEAR_REWARD = false
	_check(ref_p > 0.0 and _fight_term(h, world, "combat", "gear") <= -1e8,
		"default OFF: combat carries no gear term (board ref price %.0fg exists)" % ref_p)
	# ON: the gear term appears, positive, equal to ref_price × K × greed-weight
	Config.COMBAT_GEAR_REWARD = true
	var wealth_w := 0.6 + float(h.traits.get("greed", 0.4))
	var expect := world.economy.gear_board_ref_price() * Config.COMBAT_GEAR_K * wealth_w
	var got := _fight_term(h, world, "combat", "gear")
	_check(got > 0.0 and absf(got - expect) < 0.01,
		"ON: gear term reads the board price (%.0f × %.2f × %.2f = %.2f)" % [world.economy.gear_board_ref_price(), Config.COMBAT_GEAR_K, wealth_w, got])
	# price coupling (the counter-force): flood the gear board → ref price falls → the term SHRINKS
	for s in world.economy.shops:
		for g in s.goods:
			if content.tier(g) > 0:
				s.stock[g] = float(s.maximum[g])   # saturate every gear arm → board price floors out
	var got_flooded := _fight_term(h, world, "combat", "gear")
	_check(got_flooded < got and got_flooded > 0.0,
		"flooding the gear board shrinks the reward (%.2f → %.2f) — the KI-4 negative feedback" % [got, got_flooded])
	Config.COMBAT_GEAR_REWARD = false   # restore the default OFF (static var must not leak into later tests)

## #4a — C1 parameterized nudge: the loot_policy drop-filter (pure), and the count_range roll that
## bakes a per-trip commitment onto the won nudge's act. Unparameterized nudges stay unchanged.
func _test_unit3a_param_nudge() -> void:
	print("\n[Unit 3 #4a — parameterized nudge: count-range roll, loot_policy drop-filter, save v6]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var cheap: ItemType = content.item("leather_cowl")   # base 16
	var dear: ItemType = content.item("iron_sword")      # base 60
	_check(SimWorld.loot_keeps(Config.LOOT_KEEP_ALL, cheap) and SimWorld.loot_keeps(Config.LOOT_KEEP_ALL, dear),
		"keep-all carries every non-upgrade drop")
	_check(not SimWorld.loot_keeps(Config.LOOT_SALVAGE, dear) and not SimWorld.loot_keeps(Config.LOOT_SALVAGE, cheap),
		"salvage-all carries nothing (everything → coins)")
	_check(SimWorld.loot_keeps(Config.LOOT_VALUABLES, dear) and not SimWorld.loot_keeps(Config.LOOT_VALUABLES, cheap),
		"upgrades-and-valuables keeps iron_sword(60), salvages leather_cowl(16)")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	var h: Hero = world.heroes[0]
	h.weapon = "bow"; h.equipped["main"] = "shortbow"; h.inv["trout"] = 5
	world.nudge_hero(h, "FIGHT", {"count_range": [3, 3], "loot_policy": Config.LOOT_SALVAGE})
	_check(h.nudge.get("count_range", []) == [3, 3] and String(h.nudge.get("loot_policy", "")) == Config.LOOT_SALVAGE,
		"a parameterized nudge stores count_range + loot_policy on the pending nudge")
	world._start_activity(h)   # the dominating nudge wins → its params bake onto the trip act
	_check(int(h.act.get("count_target", -1)) == 3 and String(h.act.get("loot_policy", "")) == Config.LOOT_SALVAGE,
		"the won nudge rolls count_target=%d + carries loot_policy onto the trip" % int(h.act.get("count_target", -1)))
	var h2: Hero = world.heroes[1]
	world.nudge_hero(h2, "GATHER_LOGS")   # plain, unparameterized
	world._start_activity(h2)
	_check(not h2.act.has("count_target") and not h2.act.has("loot_policy"),
		"a plain nudge adds no params (standing trip-length + keep-all unchanged)")
	var v6s: Dictionary = SaveLoad.save_world(world)
	v6s["version"] = 5
	var migrated: Dictionary = SaveLoad.migrate(v6s)
	_check(int(migrated.get("version", -1)) == SaveLoad.SAVE_VERSION and SaveLoad.load_world(content, migrated) != null,
		"v5 save migrates up the chain and loads (params forward-compatible)")

## #4b — B4 feasibility gating: `nudge_feasible` allows an affordable acquisition step but disables
## (with a reason) when the hero categorically can't act. The render layer greys+tooltips from this.
func _test_unit3b_feasibility() -> void:
	print("\n[Unit 3 #4b — nudge feasibility gating (B4): weapon/food/tool/affordability]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	var h: Hero = world.heroes[0]
	_check(bool(world.nudge_feasible(h, "REGROUP")["ok"]), "Town nudge is always feasible")
	h.equipped["main"] = "bronze_sword"; h.weapon = "sword"; h.inv["trout"] = 3; h.gold = 0.0
	_check(bool(world.nudge_feasible(h, "FIGHT")["ok"]), "armed + fed → Fight feasible (no gold needed)")
	var h2: Hero = world.heroes[1]
	h2.equipped.erase("main"); h2.weapon = "sword"; h2.gold = 0.0; h2.inv["trout"] = 3
	var f2: Dictionary = world.nudge_feasible(h2, "FIGHT")
	_check(not bool(f2["ok"]) and String(f2["reason"]).contains("weapon"), "no weapon + broke → Fight gated (%s)" % f2["reason"])
	var h3: Hero = world.heroes[2]
	h3.inv.erase("bronze_pickaxe"); h3.gold = 0.0
	var f3: Dictionary = world.nudge_feasible(h3, "GATHER_ORE")
	_check(not bool(f3["ok"]) and String(f3["reason"]).contains("pickaxe"), "no pickaxe + broke → Mine gated (%s)" % f3["reason"])
	h3.gold = 100.0
	_check(bool(world.nudge_feasible(h3, "GATHER_ORE")["ok"]), "no pickaxe but affordable → Mine feasible (legible buy-then-mine)")
	h.seized = true
	_check(not bool(world.nudge_feasible(h, "FIGHT")["ok"]), "seized hero → nudge gated (direct Command instead)")

## #13 — rolled founders: deterministic on the seed, viability-constrained (≥1 fisher), gold-banded,
## weapon-style rolled, spawned inside the walls; FOUNDERS_LOCKED restores the fixed template.
func _test_unit13_founders() -> void:
	print("\n[#13 — rolled founders: locked template, determinism, viability, gold band, weapon-style, spawn]")
	var content := ContentDB.new()
	content.load_all("res://data")
	Config.FOUNDERS_LOCKED = true
	var wl := SimWorld.new()
	wl.setup(content, 6, Config.DEFAULT_SEED)
	_check(wl.heroes[0].favorite == "mining" and int(wl.heroes[0].gold) == 20,
		"FOUNDERS_LOCKED → the fixed template (heroes[0] mines, 20g)")
	Config.FOUNDERS_LOCKED = false
	var wa := SimWorld.new(); wa.setup(content, 6, Config.DEFAULT_SEED)
	var wb := SimWorld.new(); wb.setup(content, 6, Config.DEFAULT_SEED)
	var same := true
	for i in range(6):
		var a: Hero = wa.heroes[i]
		var b: Hero = wb.heroes[i]
		if a.hero_name != b.hero_name or a.favorite != b.favorite or int(a.gold) != int(b.gold) or a.weapon != b.weapon or a.pos != b.pos:
			same = false
	_check(same, "rolled founders are deterministic (same seed ⇒ identical roster)")
	var fishers := 0
	for h in wa.heroes:
		if h.favorite == "fishing":
			fishers += 1
	_check(fishers >= 1, "viability: at least one fisher among the founders (%d)" % fishers)
	var gold_ok := true
	for h in wa.heroes:
		if int(h.gold) < Config.FOUNDER_GOLD_MIN or int(h.gold) > Config.FOUNDER_GOLD_MAX:
			gold_ok = false
	_check(gold_ok, "every founder's gold is in the rolled band [%d,%d]" % [Config.FOUNDER_GOLD_MIN, Config.FOUNDER_GOLD_MAX])
	var wstyle_ok := true
	for h in wa.heroes:
		if h.favorite == "fighting" and not (h.weapon in ["sword", "bow", "staff"]):
			wstyle_ok = false
	_check(wstyle_ok, "fighting founders roll a weapon style in {sword,bow,staff}")
	var differs := false
	for i in range(6):
		if wa.heroes[i].favorite != wl.heroes[i].favorite or int(wa.heroes[i].gold) != int(wl.heroes[i].gold):
			differs = true
	_check(differs, "the rolled roster differs from the locked template (rolling is live)")
	var in_walls := true
	for h in wa.heroes:
		if not wa._inside_city(h.pos):
			in_walls = false
	_check(in_walls, "founders spawn on walkable tiles inside the city walls")
	Config.FOUNDERS_LOCKED = true   # restore the suite default (role-stable for any later test)

## #14 — immigrant gold rolls in economy-fitted tier bands (fraction of the attractor ref), tiered
## and bounded; fighters roll their weapon style (id%3 retired). Deterministic on the seed.
func _test_unit14_immigrants() -> void:
	print("\n[#14 — immigrant gold rolled in economy-fitted bands + rolled weapon style]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var ref := Config.GOLD_ATTRACTOR_REF
	var green: Dictionary = Config.NEWCOMER_TIERS[0]
	var elite: Dictionary = Config.NEWCOMER_TIERS[3]
	var g_lo := int(round(ref * float(green["gold_frac"][0]))); var g_hi := int(round(ref * float(green["gold_frac"][1])))
	var e_lo := int(round(ref * float(elite["gold_frac"][0]))); var e_hi := int(round(ref * float(elite["gold_frac"][1])))
	var w := SimWorld.new()
	w.setup(content, 6, Config.DEFAULT_SEED)
	var gmin := 99999; var gmax := -1; var emin := 99999; var emax := -1
	var fighters := 0; var fighters_valid := 0
	for i in range(20):
		var hg: Hero = w.spawn_immigrant(green); gmin = mini(gmin, int(hg.gold)); gmax = maxi(gmax, int(hg.gold))
		var he: Hero = w.spawn_immigrant(elite); emin = mini(emin, int(he.gold)); emax = maxi(emax, int(he.gold))
		for h in [hg, he]:
			if h.favorite == "fighting":
				fighters += 1
				if h.weapon in ["sword", "bow", "staff"]:
					fighters_valid += 1
	_check(gmin >= g_lo and gmax <= g_hi, "Greenhorn gold rolls within its band [%d,%d] (saw %d..%d)" % [g_lo, g_hi, gmin, gmax])
	_check(emin >= e_lo and emax <= e_hi, "Elite gold rolls within its band [%d,%d] (saw %d..%d)" % [e_lo, e_hi, emin, emax])
	_check(e_lo > g_hi, "Elite gold band sits entirely above Greenhorn's (tiered: %d > %d)" % [e_lo, g_hi])
	_check(e_hi < ref, "even Elite arrives below the per-capita attractor %d (bounded: %d)" % [ref, e_hi])
	_check(fighters >= 1 and fighters == fighters_valid, "every immigrant fighter rolled a weapon in {sword,bow,staff} (%d fighters)" % fighters)
	var wa := SimWorld.new(); wa.setup(content, 6, 0xBEEF01)
	var ia: Hero = wa.spawn_immigrant(Config.NEWCOMER_TIERS[2])
	var wb := SimWorld.new(); wb.setup(content, 6, 0xBEEF01)
	var ib: Hero = wb.spawn_immigrant(Config.NEWCOMER_TIERS[2])
	_check(int(ia.gold) == int(ib.gold) and ia.favorite == ib.favorite and ia.weapon == ib.weapon,
		"immigrant roll is deterministic (same seed ⇒ same arrival)")

## #15 — arrivals roll starting gear scaled by rarity tier: Elite arrivals wear more (and higher-
## tier) gear than Greenhorns; pieces are valid catalog gear; fighters keep a style-matched main.
func _test_unit15_immigrant_gear() -> void:
	print("\n[#15 — immigrant gear rolls: boost-scaled quality, style-matched main, validity]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var w := SimWorld.new()
	w.setup(content, 6, Config.DEFAULT_SEED)
	var elite: Dictionary = Config.NEWCOMER_TIERS[3]
	var green: Dictionary = Config.NEWCOMER_TIERS[0]
	var elite_armor := 0; var green_armor := 0; var elite_t2 := 0
	var arrivals: Array = []
	for i in range(20):
		var he: Hero = w.spawn_immigrant(elite)
		var hg: Hero = w.spawn_immigrant(green)
		arrivals.append(he); arrivals.append(hg)
		for slot in ["head", "torso", "off"]:
			if he.equipped.has(slot):
				elite_armor += 1
				if content.tier(String(he.equipped[slot])) == 2:
					elite_t2 += 1
			if hg.equipped.has(slot):
				green_armor += 1
	var valid := true
	var style_ok := true
	for h in arrivals:
		for slot in h.equipped:
			var it: ItemType = content.item(String(h.equipped[slot]))
			if it == null or it.slot != String(slot):
				valid = false
		if h.favorite == "fighting" and h.equipped.has("main") and content.style(String(h.equipped["main"])) != h.weapon:
			style_ok = false
	_check(elite_armor > green_armor, "Elite arrivals wear more armor than Greenhorns (%d vs %d) — boost-scaled" % [elite_armor, green_armor])
	_check(elite_t2 >= 1, "high-tier (Elite) arrivals roll tier-2 gear (%d pieces)" % elite_t2)
	_check(valid, "every equipped piece is catalog gear in its matching slot")
	_check(style_ok, "fighter arrivals keep a style-matched main-hand")
	var wa := SimWorld.new(); wa.setup(content, 6, 0xC0FFEE)
	var ia: Hero = wa.spawn_immigrant(elite)
	var wb := SimWorld.new(); wb.setup(content, 6, 0xC0FFEE)
	var ib: Hero = wb.spawn_immigrant(elite)
	_check(ia.equipped == ib.equipped, "arrival gear roll is deterministic (same seed ⇒ same kit)")

## #5a — the bank foundation (Unit 4, R9): per-hero balance, total-wealth upkeep (no attractor
## dodge), death-safe, save v7. Inert in live play (empty bank) until the GE refunds fill it (#5b).
func _test_unit5a_bank() -> void:
	print("\n[Unit 4 #5a — bank: deposit/withdraw, total-wealth upkeep, death-safe, save v7]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	var h: Hero = world.heroes[0]
	h.gold = 100.0; h.bank = 0.0
	var before := world.total_gold()
	var moved := world.bank_deposit(h, 60.0)
	_check(moved == 60.0 and h.gold == 40.0 and h.bank == 60.0 and world.total_gold() == before,
		"deposit moves coinpurse→bank, total wealth unchanged")
	world.bank_withdraw(h, 25.0)
	_check(h.gold == 65.0 and h.bank == 35.0, "withdraw moves bank→coinpurse")
	_check(world.bank_deposit(h, 9999.0) == 65.0 and h.gold == 0.0, "deposit is capped at the coinpurse")
	_check(world.bank_withdraw(h, 9999.0) == 100.0 and h.bank == 0.0, "withdraw is capped at the balance")
	var hb: Hero = world.heroes[1]
	hb.gold = 0.0; hb.bank = 1000.0
	world.economy.economy_tick(1.0, [hb])
	_check(hb.gold == 0.0 and hb.bank < 1000.0, "upkeep drains the bank when the coinpurse is empty (bank %.0f — no attractor dodge)" % hb.bank)
	var hd2: Hero = world.heroes[2]
	hd2.gold = 100.0; hd2.bank = 500.0
	world._hero_death(hd2, "a test rat")
	_check(hd2.bank == 500.0, "death-transfer leaves banked gold untouched (bank %.0f)" % hd2.bank)
	var s: Dictionary = SaveLoad.save_world(world)
	s["version"] = 6
	for hdz in s["heroes"]:
		hdz.erase("bank")
	var m: Dictionary = SaveLoad.migrate(s)
	var w2: SimWorld = SaveLoad.load_world(content, m)
	_check(int(m.get("version", -1)) == SaveLoad.SAVE_VERSION and w2 != null and float(w2.heroes[0].bank) == 0.0,
		"v6 save migrates to v%d; pre-bank heroes default bank=0" % SaveLoad.SAVE_VERSION)

## #5b — the GE order book engine: escrow on post, price-time matching, 1% seller tax → treasury,
## resting-price execution + buyer refund to bank, cancel refunds (gold→bank, goods→inv), save v8.
func _test_unit5b_ge_orderbook() -> void:
	print("\n[Unit 4 #5b — GE order book: escrow, price-time match, 1% tax, refunds→bank, save v8]")
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	# --- escrow on post ---
	var hs: Hero = world.heroes[0]; hs.inv = {"logs": 10}; hs.gold = 0.0; hs.bank = 0.0
	var hb: Hero = world.heroes[1]; hb.inv = {}; hb.gold = 1000.0; hb.bank = 0.0
	var sid := world.ge_post_order(hs.id, "sell", "logs", 5, 100)
	_check(sid >= 0 and int(hs.inv.get("logs", 0)) == 5, "sell order escrows the goods (10→5)")
	var bid := world.ge_post_order(hb.id, "buy", "logs", 5, 100)
	_check(bid >= 0 and hb.gold == 500.0, "buy order escrows the gold (1000→500)")
	# --- match: both @100, sell is older → exec 100, no refund; seller gets gross−1% tax ---
	var ge_tax0 := world.economy.treasury_in_ge_tax
	world.ge_match()
	var tax := int(round(500.0 * Config.GE_TAX))
	_check(int(hb.inv.get("logs", 0)) == 5 and hs.gold == float(500 - tax) and (world.economy.treasury_in_ge_tax - ge_tax0) == float(tax) and world.ge_orders.is_empty(),
		"match: goods→buyer, gold−1%% tax→seller (%dg), tax→treasury, book clears" % int(hs.gold))
	# --- resting-price execution + buyer overpay refunds to the bank ---
	var w2 := SimWorld.new(); w2.setup(content, 6, Config.DEFAULT_SEED)
	var s2: Hero = w2.heroes[0]; s2.inv = {"iron_ore": 4}; s2.gold = 0.0
	var b2: Hero = w2.heroes[1]; b2.inv = {}; b2.gold = 1000.0; b2.bank = 0.0
	w2.ge_post_order(s2.id, "sell", "iron_ore", 4, 10)   # resting (older)
	w2.ge_post_order(b2.id, "buy", "iron_ore", 4, 12)    # aggressor escrows 48
	w2.ge_match()
	_check(int(b2.inv.get("iron_ore", 0)) == 4 and b2.bank == 8.0,
		"fill executes at the resting price; the buyer's overpay refunds to the bank (8g)")
	# --- price priority: the cheaper sell fills first; the dearer remains resting ---
	var w3 := SimWorld.new(); w3.setup(content, 6, Config.DEFAULT_SEED)
	var sh: Hero = w3.heroes[0]; sh.inv = {"cowhide": 3}; sh.gold = 0.0   # dearer, posted first
	var sl: Hero = w3.heroes[1]; sl.inv = {"cowhide": 3}; sl.gold = 0.0   # cheaper, posted second
	w3.ge_post_order(sh.id, "sell", "cowhide", 3, 50)
	w3.ge_post_order(sl.id, "sell", "cowhide", 3, 30)
	var bq: Hero = w3.heroes[2]; bq.inv = {}; bq.gold = 1000.0; bq.bank = 0.0
	w3.ge_post_order(bq.id, "buy", "cowhide", 3, 60)
	w3.ge_match()
	_check(sl.gold > 0.0 and sh.gold == 0.0 and int(bq.inv.get("cowhide", 0)) == 3,
		"price priority: the cheaper sell fills first; the dearer stays resting")
	# --- cancel refunds: buy→bank (R9), sell→inv ---
	var w4 := SimWorld.new(); w4.setup(content, 6, Config.DEFAULT_SEED)
	var cb: Hero = w4.heroes[0]; cb.inv = {}; cb.gold = 600.0; cb.bank = 0.0
	var cs: Hero = w4.heroes[1]; cs.inv = {"trout": 8}
	var cbid := w4.ge_post_order(cb.id, "buy", "trout", 5, 100)    # escrows 500
	var csid := w4.ge_post_order(cs.id, "sell", "trout", 5, 100)   # escrows 5 trout (8→3)
	w4.ge_cancel_order(cbid)
	w4.ge_cancel_order(csid)
	_check(cb.bank == 500.0 and cb.gold == 100.0 and int(cs.inv.get("trout", 0)) == 8,
		"cancel: buy escrow refunds to the bank (500g), sell escrow returns goods to inv")
	# --- save v7 → v8 migration (GE state round-trips / defaults) ---
	var w5 := SimWorld.new(); w5.setup(content, 6, Config.DEFAULT_SEED)
	w5.ge_unlocked = true
	w5.heroes[0].inv["logs"] = 5
	var posted := w5.ge_post_order(w5.heroes[0].id, "sell", "logs", 2, 40)
	var s: Dictionary = SaveLoad.save_world(w5)
	var m: Dictionary = SaveLoad.migrate(s)
	var w5b: SimWorld = SaveLoad.load_world(content, m)
	_check(posted >= 0 and int(m.get("version", -1)) == SaveLoad.SAVE_VERSION and w5b != null and w5b.ge_unlocked and w5b.ge_orders.size() == 1,
		"save v%d round-trips the GE order book (unlocked + 1 resting order)" % SaveLoad.SAVE_VERSION)

## Score of the candidate matching `intent` in a scored candidate list (-inf if absent).
func _cand_score(cands: Array, intent: String) -> float:
	for c in cands:
		if String(c.get("intent", "")) == intent:
			return float(c["score"])
	return -1e9

## Run a fixed-population colony ~6 days and ACCUMULATE hero-samples on `count_intent` (sampled
## periodically), optionally with one incentive set. Integrating over the run instead of reading a
## single instant removes snapshot noise (an instantaneous 6-hero count is mostly RNG — exactly the
## measurement-discipline trap). Population fixed so the count isn't confounded by immigration.
func _count_intent_after_run(seed_v: int, inc_intent: String, inc_weight: float, count_intent: String) -> int:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, seed_v)
	world.population.enabled = false
	if inc_intent != "":
		world.set_incentive(inc_intent, inc_weight)
	var samples := 0
	for i in range(6000):
		world.tick(SimWorld._ACTION_SECONDS)
		if i % 50 == 0:
			for h in world.heroes:
				if String(h.act.get("intent", "")) == count_intent:
					samples += 1
	return samples

## Run a fixed-population colony ~12 days with both shops pre-leveled by `levels`; return total gold.
func _run_with_upgrades(seed_v: int, levels: int) -> int:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, seed_v)
	world.population.enabled = false
	world.economy.treasury = 1.0e7
	for s: Shop in world.economy.shops:
		for i in range(levels):
			world.economy.try_upgrade_shop(s)
	for i in range(12000):
		world.tick(SimWorld._ACTION_SECONDS)
	return world.total_gold()

func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()
