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
	_test_saveload()
	# Guard against false greens: if a script error aborts a test function mid-way, its remaining
	# _check() calls silently don't run. Assert the full expected count actually executed.
	const EXPECTED := 101
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
	var gen: Shop = eco.shop_for("ore")
	_check(gen != null and gen.trades("logs"), "General Store trades ore AND logs (inspectable)")
	_check(eco.shop_for("ore").level == 1, "shop level is inspectable (starts 1 — §19.2 dial for Step 4)")
	# saturation-aware price: a full shop pays strictly less than a near-empty one
	var empty := eco.sell_price("ore")
	gen.stock["ore"] = gen.maximum["ore"]
	var full := eco.sell_price("ore")
	_check(full < empty, "sell price falls as stock saturates (%d full < %d empty)" % [full, empty])
	_check(full >= int(round(gen.base["ore"] * Config.PRICE_FLOOR_FRAC)), "saturated price respects the floor (anti-leak)")
	# GE-tax is now tracked first-class
	var eco2 := Economy.new()
	var seller := Hero.new()
	seller.inv = {"ore": 10}
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
	world.heroes[0].act = {"intent": "GATHER_ORE", "loc": "mine", "skill": "mining", "res": "ore", "phase": "gather", "target": "mine", "then": ""}
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
	eh.inv = {"Iron sword": 1, "Steel sword": 1}
	var n0 := eh.inv_count()
	eh.equip_item("main", "Iron sword")
	_check(eh.inv_count() == n0 - 1 and String(eh.equipped["main"]) == "Iron sword",
		"equip moves the item out of the inventory into its slot (frees space)")
	eh.equip_item("main", "Steel sword")
	_check(String(eh.equipped["main"]) == "Steel sword" and int(eh.inv.get("Iron sword", 0)) == 1,
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
	_check(world.monsters.size() == 4, "4 rats spawned at the Rat Pit")
	var food_min := 999
	var food_sum := 0
	var samples := 0
	for i in range(8000):
		world.tick(SimWorld._ACTION_SECONDS)
		if i % 50 == 0:
			var fs := world.economy.total_stock("cooked_fish")
			food_min = mini(food_min, fs)
			food_sum += fs
			samples += 1
	var kills_per_event := float(world.total_kills) / maxf(1.0, world.deaths + world.flees)
	print("    kills %d · deaths %d · flees %d · kills/(death+flee) %.2f · gold %d" % [world.total_kills, world.deaths, world.flees, kills_per_event, world.total_gold()])
	print("    shop food: min %d · avg %d  (fighters' fuel — if min≈0 the cooks/town under-supply)" % [food_min, int(food_sum / maxi(1, samples))])
	_check(world.total_kills > 0, "heroes killed rats (%d)" % world.total_kills)
	var trained := false
	for h in world.heroes:
		if h.favorite == "fighting" and h.skill_level("strength") > 8:
			trained = true
	_check(trained, "a fighter trained Strength past its head-start via combat")
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
	hg.inv["Axe"] = 1   # tool-gated now: give the axe so the candidate is the ACTIVITY, not the purchase
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
	seller.inv = {"ore": 20}
	eco.sell_goods(seller)
	_check(eco.treasury > 0.0, "treasury accrues from the GE-tax skim (%.1fg)" % eco.treasury)
	_check(abs(eco.treasury - eco.tax_collected) < 0.001, "treasury equals cumulative tax (same skim, double-booked for inspection)")

	# §19.2 shop leveling: stock capacity AND town demand scale by the SAME factor (faucet/sink invariant)
	var gen: Shop = eco.shop_for("ore")
	eco.treasury = 100000.0
	var lvl0 := gen.level
	var max0: float = gen.maximum["ore"]
	var con0: float = gen.consume["ore"]
	var cost := eco.shop_upgrade_cost(gen)
	var tre0 := eco.treasury
	var up := eco.try_upgrade_shop(gen)
	var factor := 1.0 + Config.SHOP_CAP_PER_LEVEL
	_check(up and gen.level == lvl0 + 1, "shop upgrade raises the level (%d -> %d)" % [lvl0, gen.level])
	_check(abs(gen.maximum["ore"] - max0 * factor) < 0.01, "upgrade scales stock capacity (×%.2f)" % factor)
	_check(abs(gen.consume["ore"] - con0 * factor) < 0.01, "upgrade scales town demand by the SAME factor (bounded by construction)")
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
