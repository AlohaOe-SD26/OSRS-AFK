extends SceneTree
## #5e-2 GE-ACTIVE re-baseline — the economy with the Grand Exchange OPEN the whole run (ge_unlocked
## forced true from day 1, the maximal-effect stress test): the town autonomously posts city buy
## orders (funded gather incentive) and heroes fill them for a premium. Question: does the attractor
## stay BOUNDED once this re-injection faucet is live? Multi-seed, mean ± SD. Run:
##   godot --headless --path game --script res://tools/diag_ge.gd
## Lock criterion: g/cap stays in/near the GE-LOCKED band (1,384 ± 174) — the budget guard
## (city escrow ≤ 25% treasury) + the upkeep attractor must absorb the re-injection. All colonies
## alive. Reports the shop→GE tax migration (R8: GE tax partially replaces shop tax as volume moves).

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]

func _initialize() -> void:
	Config.FOUNDERS_LOCKED = false
	print("=== #5e-2 GE-ACTIVE RE-BASELINE — GE open all run, %d seeds, %d days (mean ± SD) ===\n" % [SEEDS.size(), DAYS])
	var gpc: Array = []; var pop: Array = []; var dead: Array = []
	var shoptax: Array = []; var getax: Array = []; var cinv: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		gpc.append(m["gpc"]); pop.append(m["pop"]); dead.append(m["deaths"])
		shoptax.append(m["shoptax"]); getax.append(m["getax"]); cinv.append(m["cinv"])
		print("  seed %x: day-%d pop %d · g/cap %d · treasury %d · shop-tax %d / GE-tax %d · city-inv %d · deaths %d" % [
			seed_v, DAYS, int(m["pop"]), int(m["gpc"]), int(m["treasury"]), int(m["shoptax"]), int(m["getax"]), int(m["cinv"]), int(m["deaths"])])
	print("\n  per-capita gold: %.0f ± %.0f   (GE-LOCKED band 1,384 ± 174 — must stay near it)" % [_mean(gpc), _sd(gpc)])
	print("  population:      %.0f ± %.0f   ·  deaths/run %.1f ± %.1f" % [_mean(pop), _sd(pop), _mean(dead), _sd(dead)])
	print("  tax migration (R8): shop-tax %.0f ± %.0f  ·  GE-tax %.0f ± %.0f  (GE share %.0f%%)" % [
		_mean(shoptax), _sd(shoptax), _mean(getax), _sd(getax), 100.0 * _mean(getax) / maxf(1.0, _mean(shoptax) + _mean(getax))])
	print("  city inventory accrued: %.0f ± %.0f   ·  ALL ALIVE = %s" % [_mean(cinv), _sd(cinv), "yes" if _all_alive(pop) else "NO"])
	quit(0)

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	world.ge_unlocked = true   # FORCE the GE open for the whole run (maximal-effect stress test)
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var n: int = world.heroes.size()
	var ci := 0
	for k in world.city_inventory:
		ci += int(world.city_inventory[k])
	return {
		"gpc": float(world.total_gold()) / maxi(1, n), "pop": n, "deaths": world.deaths,
		"treasury": world.economy.treasury, "shoptax": world.economy.treasury_in_tax,
		"getax": world.economy.treasury_in_ge_tax, "cinv": ci,
	}

func _all_alive(pop: Array) -> bool:
	for p in pop:
		if int(p) <= 0:
			return false
	return true

func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / a.size()

func _sd(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var m := _mean(a)
	var ss := 0.0
	for v in a:
		ss += (float(v) - m) * (float(v) - m)
	return sqrt(ss / (a.size() - 1))
