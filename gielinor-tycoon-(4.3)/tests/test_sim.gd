extends SceneTree
## Headless test harness for the SIM CORE. Run:
##   godot --headless --script res://tests/test_sim.gd
## Exits 0 on all-pass, 1 on any failure. This is the Godot-side equivalent of the browser
## validation done on the prototype: it asserts the canon math AND that the tuned economy
## stays bounded over a multi-day run (no runaway, no starvation).

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
	_test_economy_equilibrium()
	_test_offline_catchup()
	print("\n=== %d/%d checks passed ===" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)

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
	var s48 := world.offline_catchup(48.0)
	_check(s48["hours"] == Config.OFFLINE_CAP_HOURS, "48h capped to 24h")

func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / a.size()
