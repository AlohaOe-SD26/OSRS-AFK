extends SceneTree
## #13 RE-BASELINE — rolled founders shift the seed stream AND starting wealth, so the per-capita
## gold band must be re-established and the colony proven VIABLE across seeds (the viability
## constraint = ≥1 fisher; this also checks no seed starves/collapses). Rolled founders are the
## default (FOUNDERS_LOCKED off). Multi-seed, mean ± SD (single-seed is RNG-confounded). Run:
##   godot --headless --path game --script res://tools/diag_founders.gd
## Lock criterion: g/cap band stays bounded near the prior 1,501 ± 235 (the upkeep attractor pins it
## regardless of starting gold); deaths stay low; every seed keeps ≥1 fisher and a living colony.

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]

func _initialize() -> void:
	Config.FOUNDERS_LOCKED = false   # measure the ROLLED founders (the shipped default)
	print("=== #13 ROLLED-FOUNDER RE-BASELINE — %d seeds, %d days (mean ± SD) ===\n" % [SEEDS.size(), DAYS])
	var gpc: Array = []
	var pop: Array = []
	var dead: Array = []
	var min_fish := 99
	var start_gold: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		gpc.append(m["gpc"]); pop.append(m["pop"]); dead.append(m["deaths"])
		start_gold.append(m["start_gold"])
		min_fish = mini(min_fish, int(m["founder_fishers"]))
		print("  seed %x: founders fishers=%d start-gold avg %.0f → day-%d pop %d · g/cap %d · deaths %d" % [
			seed_v, int(m["founder_fishers"]), float(m["start_gold"]), DAYS, int(m["pop"]), int(m["gpc"]), int(m["deaths"])])
	print("\n  per-capita gold: %.0f ± %.0f   (prior band 1,501 ± 235)" % [_mean(gpc), _sd(gpc)])
	print("  population:      %.0f ± %.0f" % [_mean(pop), _sd(pop)])
	print("  deaths/run:      %.1f ± %.1f" % [_mean(dead), _sd(dead)])
	print("  founder starting gold (rolled): %.0f ± %.0f  [band %d–%d]" % [_mean(start_gold), _sd(start_gold), Config.FOUNDER_GOLD_MIN, Config.FOUNDER_GOLD_MAX])
	print("  VIABILITY: min founder fishers across seeds = %d (must be ≥ 1); all colonies alive = %s" % [min_fish, "yes" if _all_alive(pop) else "NO"])
	quit(0)

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	var fishers := 0
	var sg := 0.0
	for h in world.heroes:
		if h.favorite == "fishing":
			fishers += 1
		sg += float(h.gold)
	sg /= maxf(1.0, float(world.heroes.size()))
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var n: int = world.heroes.size()
	return {
		"gpc": float(world.total_gold()) / maxi(1, n),
		"pop": n,
		"deaths": world.deaths,
		"founder_fishers": fishers,
		"start_gold": sg,
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
