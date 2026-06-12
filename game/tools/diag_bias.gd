extends SceneTree
## #3c CLAMP SWEEP — how wide may the price-bias lever swing before it destabilizes? (B1; ruled
## expectation: "narrower than 50–150%".) Arms apply ONE bias to ONE good (logs) from day 3 with an
## ORGANIC treasury (tax + routing only — sustainability is part of the question). Multi-seed,
## mean ± SD. Labor share is INTEGRATED over the run (instantaneous counts are RNG noise). Run:
##   godot --headless --path game --script res://tools/diag_bias.gd
## Lock criterion: widest band where (a) the pull is real (share separates from control), (b) g*
## stays bounded (no inflation/starvation drift), (c) the premium drain is funded (treasury ≥ 0
## throughout is structural; watch out_bias vs inflows for sustainability).

const DAYS := 16
const BIAS_DAY := 3.0
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99]

func _initialize() -> void:
	print("=== #3c PRICE-BIAS CLAMP SWEEP — %d seeds, %d days, bias on LOGS from day %d (mean ± SD) ===\n" % [SEEDS.size(), DAYS, int(BIAS_DAY)])
	_arm("control (no bias)", 1.0)
	_arm("overpay 130%", 1.3)
	_arm("overpay 150%", 1.5)
	_arm("underpay 70%", 0.7)
	quit(0)

func _arm(label: String, bias: float) -> void:
	Config.PRICE_BIAS_MIN = 0.5   # widen the clamp so the SWEEP can probe outside the opening stance
	Config.PRICE_BIAS_MAX = 1.5
	var share: Array = []
	var gpc: Array = []
	var tre: Array = []
	var drain: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v), bias)
		share.append(m["share"]); gpc.append(m["gpc"]); tre.append(m["treasury"]); drain.append(m["out_bias"])
	print("%s" % label)
	print("    woodcutting labor share: %.1f%% ± %.1f   (integrated; the steering effect)" % [_mean(share), _sd(share)])
	print("    per-capita gold:         %.0f ± %.0f   (stability)" % [_mean(gpc), _sd(gpc)])
	print("    treasury end:            %.0f ± %.0f   ·  premium drain %.0f ± %.0f\n" % [_mean(tre), _sd(tre), _mean(drain), _sd(drain)])

func _run_one(seed_v: int, bias: float) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	var ticks := int(DAYS / SimWorld._DD_PER_ACTION)
	var bias_tick := int(BIAS_DAY / SimWorld._DD_PER_ACTION)
	var samples := 0
	var on_logs := 0
	var pop_sum := 0
	for i in range(ticks):
		world.tick(SimWorld._ACTION_SECONDS)
		if i == bias_tick and absf(bias - 1.0) > 0.01:
			world.economy.set_price_bias("logs", bias)
		if i > bias_tick and i % 50 == 0:
			samples += 1
			pop_sum += world.heroes.size()
			for h in world.heroes:
				if String(h.act.get("intent", "")) == "GATHER_LOGS":
					on_logs += 1
	var pop: int = world.heroes.size()
	return {
		"share": 100.0 * float(on_logs) / maxf(1.0, float(pop_sum)),
		"gpc": float(world.total_gold()) / maxi(1, pop),
		"treasury": float(world.economy.treasury),
		"out_bias": float(world.economy.treasury_out_bias),
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
