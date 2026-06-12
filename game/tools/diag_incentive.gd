extends SceneTree
## Tier-1 INCENTIVIZE labor-pull measurement (Step 4, GDD §2/§18.4). The planner's watch number:
## "does Incentivize measurably PULL labor?" Per measurement-discipline, a single seed is confounded
## (the lever changes choices → perturbs the RNG stream → shifts the newcomer-favorite mix), so this
## runs a CONTROLLED multi-seed A/B: identical seed per pair, ONE variable changed (the incentive),
## population fixed at 6 so immigration can't confound the count. Reports MEAN ± SD; the claim is real
## only if the distributions separate. Run:
##   godot --headless --path game --script res://tools/diag_incentive.gd
##
## Metric: % of heroes whose CURRENT activity is the incentivized target, control vs incentivized.
## Target = GATHER_LOGS (a non-favorite for most founders → a clean "did the bounty pull them?" read).

const DAYS := 12
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99,
	0x0B1, 0x7A11, 0x3C3C, 0x9019, 0xAB12, 0x4242, 0xF00B, 0x1357, 0x2468, 0xCAFE]
const TARGET := "GATHER_LOGS"

func _initialize() -> void:
	print("=== TIER-1 INCENTIVE LABOR-PULL — %d seeds, %d sim-days, pop fixed at 6 (mean ± SD) ===" % [SEEDS.size(), DAYS])
	print("(metric: %% of heroes whose current activity is %s — the bounty target)\n" % TARGET)
	# A ladder of incentive weights so the planner can read the dose-response, not just on/off.
	# Full response curve. In-game the bounty clamps to INCENTIVE_MAX (%.0f); arms above it show WHY
	# (the >~36 overproduction crater). This sweep sets the weight directly to map past the clamp.
	for w in [0.0, 12.0, 18.0, 24.0, 30.0, 45.0]:
		var over := "  ⚠ over the in-game cap" if w > Config.INCENTIVE_MAX else ""
		_run_arm(("bounty = %2.0f%s" % [w, over]) if w > 0.0 else "control", w)
	quit(0)

func _run_arm(label: String, weight: float) -> void:
	var pct: Array = []
	var gpc: Array = []
	for seed_v in SEEDS:
		var m: Dictionary = _run_one(int(seed_v), weight)
		pct.append(m["pct"])
		gpc.append(m["gpc"])
	print("%s" % label)
	print("    %% on %s:        %.0f%% ± %.0f   (THE metric)" % [TARGET, _mean(pct), _sd(pct)])
	print("    per-capita gold:        %.0f ± %.0f\n" % [_mean(gpc), _sd(gpc)])

func _run_one(seed_v: int, weight: float) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	world.population.enabled = false   # fix the head-count so the count is not confounded by immigration
	if weight > 0.0:
		world.incentives[TARGET] = weight   # set directly (bypass the INCENTIVE_MAX clamp) to map the FULL curve
	# TIME-INTEGRATE the fraction on target (sample periodically and average) — an instantaneous
	# end-of-run read at 6 heroes is mostly snapshot noise (the measurement-discipline trap). The
	# time-average is the honest "share of labor the bounty captured."
	var n_ticks := int(DAYS / SimWorld._DD_PER_ACTION)
	var pop: int = world.heroes.size()
	var frac_sum := 0.0
	var samples := 0
	for i in range(n_ticks):
		world.tick(SimWorld._ACTION_SECONDS)
		if i % 25 == 0:
			var on := 0
			for h in world.heroes:
				if String(h.act.get("intent", "")) == TARGET:
					on += 1
			frac_sum += float(on) / maxi(1, pop)
			samples += 1
	return {
		"pct": int(round(100.0 * frac_sum / maxi(1, samples))),
		"gpc": int(round(float(world.total_gold()) / maxi(1, pop))),
	}

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
