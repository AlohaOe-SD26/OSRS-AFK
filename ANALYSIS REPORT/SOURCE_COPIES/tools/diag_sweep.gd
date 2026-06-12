extends SceneTree
## Multi-seed validation of the Stage-1 candidate-generation fix (cargo-only gather gate + non-empty
## invariant). Single-seed before/after is invalid here — the change alters the RNG draw order, so we
## run each config across many seeds and report MEAN ± SD; declare success only if the distributions
## separate. Two arms, ONE variable changed (Config.GATHER_GATE_CARGO_ONLY); all other levers at
## committed defaults (trip N=6, congestion ×0.5, floor 0.12). Run:
##   godot --headless --path game --script res://tools/diag_sweep.gd
## Metric: % of NON-fighting-favorite heroes who are fighting (the monoculture symptom).

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99,
	0x0B1, 0x7A11, 0x3C3C, 0x9019, 0xAB12, 0x4242, 0xF00B, 0x1357, 0x2468, 0xCAFE]

func _initialize() -> void:
	print("=== STAGE-1 GATE FIX — %d seeds × 2 arms, %d sim-days each (mean ± SD) ===" % [SEEDS.size(), DAYS])
	print("(metric: %% of non-fighting-favorite heroes who are fighting = the monoculture symptom)\n")
	_run_arm("BEFORE (gate over ALL inv — the bug)", false)
	_run_arm("AFTER  (gate over CARGO only — the fix)", true)
	quit(0)

func _run_arm(label: String, cargo_only: bool) -> void:
	Config.GATHER_GATE_CARGO_ONLY = cargo_only
	# other levers explicitly at committed defaults so this arm isolates ONE variable
	Config.COMBAT_TRIP_KILLS = 6
	Config.COMBAT_CONGESTION_MULT = 0.5
	Config.PRICE_FLOOR_FRAC = 0.12
	var fight: Array = []
	var pct: Array = []
	var follow: Array = []
	var gpc: Array = []
	for seed_v in SEEDS:
		var m: Dictionary = _run_one(int(seed_v))
		fight.append(m["fight"])
		pct.append(m["pct_nonfav"])
		follow.append(m["follow"])
		gpc.append(m["gpc"])
	print("%s" % label)
	print("    fight head-count:        %.1f ± %.1f" % [_mean(fight), _sd(fight)])
	print("    %% non-fav-favs fighting:  %.0f%% ± %.0f   (THE metric)" % [_mean(pct), _sd(pct)])
	print("    following-favorite:      %.0f%% ± %.0f" % [_mean(follow), _sd(follow)])
	print("    per-capita gold:         %.0f ± %.0f\n" % [_mean(gpc), _sd(gpc)])

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var pop: int = world.heroes.size()
	var fight := 0
	var nonfav_fighting := 0
	var nonfav_total := 0
	var following := 0
	for h in world.heroes:
		var intent: String = h.act.get("intent", "")
		var fighting: bool = intent == "FIGHT"
		if fighting:
			fight += 1
		if h.favorite != "fighting":
			nonfav_total += 1
			if fighting:
				nonfav_fighting += 1
		var follows: bool = (fighting and h.favorite == "fighting") or (Activities.is_gather(intent) and Activities.skill_of(intent) == h.favorite)
		if follows:
			following += 1
	return {
		"fight": fight,
		"pct_nonfav": int(round(100.0 * float(nonfav_fighting) / maxf(1.0, float(nonfav_total)))),
		"follow": int(round(100.0 * float(following) / maxi(1, pop))),
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
