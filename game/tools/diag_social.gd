extends SceneTree
## STEP-5 social-web DISTRIBUTION sweep (§16.3). The planner's success criterion: a BELIEVABLE distribution
## — mostly Neutral, some Friends (co-op at healthy nodes), a few Rivals (friction at crowded ones), rare
## Nemeses. NOT a flipped monoculture (794 friends → 794 rivals). Multi-seed, mean ± SD. A/Bs the
## co-op:friction balance (REL_PROXIMITY/REL_COOP/REL_FRICTION/REL_FRICTION_CROWD are static var) so the
## balance can be tuned on evidence. Run:
##   godot --headless --path game --script res://tools/diag_social.gd

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99]

func _initialize() -> void:
	print("=== STEP-5 SOCIAL-WEB DISTRIBUTION — %d seeds, %d days, immigration ON (mean ± SD) ===" % [SEEDS.size(), DAYS])
	print("(directed bonds as %% of all ordered pairs · target: mostly Neutral, some Friend, few Rival, rare Nemesis)\n")
	# KINSHIP sweep: locked co-op/friction (prox3.6/coop2.4/fric4.5/cap3.0/d.97); vary same-trade kinship.
	# Question: does kinship (calibrated on its own merit, ~Friend for same-trade) yield a believable shape,
	# or is the web STILL rival-leaning (→ the 32% combat residual; Stage 2, not more social trimming)?
	_arm("kinship 0.0 (none, baseline)", 0.0)
	_arm("kinship 0.5", 0.5)
	_arm("kinship 0.8 (locked default)", 0.8)
	_arm("kinship 1.1", 1.1)
	quit(0)

func _arm(label: String, kinship: float) -> void:
	Config.REL_PROXIMITY = 3.6
	Config.REL_COOP = 2.4
	Config.REL_FRICTION = 4.5
	Config.REL_FRICTION_CAP = 4.5
	Config.REL_PROX_CAP = 3.0
	Config.REL_DECAY = 0.97
	Config.REL_KINSHIP = kinship
	Config.REL_KINSHIP_CAP = maxf(0.6, kinship)   # cap follows magnitude (non-binding)
	var pop: Array = []
	var fr: Array = []      # Friend
	var al: Array = []      # Ally
	var ri: Array = []      # Rival
	var ne: Array = []      # Nemesis
	var nz: Array = []      # any non-neutral as % of ordered pairs
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		pop.append(m["pop"])
		fr.append(m["friend_pct"])
		al.append(m["ally_pct"])
		ri.append(m["rival_pct"])
		ne.append(m["nemesis_pct"])
		nz.append(m["nonneutral_pct"])
	print("%s   (pop %.0f)" % [label, _mean(pop)])
	print("    Friend %.1f%% ± %.1f · Ally %.1f%% ± %.1f · Rival %.1f%% ± %.1f · Nemesis %.1f%% ± %.1f · (Neutral %.0f%%)" % [
		_mean(fr), _sd(fr), _mean(al), _sd(al), _mean(ri), _sd(ri), _mean(ne), _sd(ne), 100.0 - _mean(nz)])
	print("")

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var n: int = world.heroes.size()
	var today: int = world.sim_day
	var counts := {"Friend": 0, "Ally": 0, "Rival": 0, "Nemesis": 0}
	var max_pos := 0.0
	var max_neg := 0.0
	# iterate stored edges (sparse) and classify; unstored pairs are Neutral
	var soc = world.social
	for from_id in soc.adj:
		for to_id in soc.adj[from_id]:
			var rr: float = soc.get_r(int(from_id), int(to_id), today)
			max_pos = maxf(max_pos, rr)
			max_neg = minf(max_neg, rr)
			var t: String = soc.tier_of(rr)
			if counts.has(t):
				counts[t] = int(counts[t]) + 1
	print("        [seed %x: strongest bond +%.0f / %.0f]" % [seed_v, max_pos, max_neg])
	var pairs: int = maxi(1, n * (n - 1))
	var nonneutral: int = int(counts["Friend"]) + int(counts["Ally"]) + int(counts["Rival"]) + int(counts["Nemesis"])
	return {
		"pop": n,
		"friend_pct": 100.0 * float(counts["Friend"]) / pairs,
		"ally_pct": 100.0 * float(counts["Ally"]) / pairs,
		"rival_pct": 100.0 * float(counts["Rival"]) / pairs,
		"nemesis_pct": 100.0 * float(counts["Nemesis"]) / pairs,
		"nonneutral_pct": 100.0 * float(nonneutral) / pairs,
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
