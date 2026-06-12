extends SceneTree
## STAGE-2 unified sweep: one tool, all THREE numbers per arm so each lever's attribution is clean
## (combat-share · social distribution · economy). Multi-seed, mean ± SD. Vary ONLY the combat lever(s);
## social config stays at the locked Step-5 defaults (prox3.6/coop2.4/fric4.5/kinship0.8/decay.97). Run:
##   godot --headless --path game --script res://tools/diag_stage2.gd
##
## Two-sided combat-share criterion: must DROP from ~32% but NOT crater (progression/social need fighters).

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]

func _initialize() -> void:
	print("=== STAGE-2 SWEEP — %d seeds, %d days, immigration ON (mean ± SD). Social locked; vary combat. ===\n" % [SEEDS.size(), DAYS])
	# arm = {trip_rounds, weighted}.  trip_rounds 9999 = timer disabled (current). weighted = soften argmax.
	# 4TH TEST (#1e, post-Unit-0): the activity surface BRAIN_V2 was waiting for is now live — slayer
	# on-task pull, funded bounty, aggression danger term. A = brain v1 on this surface; B = BRAIN_V2.
	# Decision point: if B holds the band and doesn't re-monoculture, the default flip goes to the user.
	Config.COMBAT_TRIP_ROUNDS = 9999
	Config.BRAIN_WEIGHTED_TIES = false
	Config.BRAIN_V2 = false
	_arm("A baseline (brain v1, Unit-0 surface)", 9999, false)
	Config.BRAIN_V2 = true
	_arm("B BRAIN V2 4th test (skillNeed, Unit-0 surface)", 9999, false)
	Config.BRAIN_V2 = false
	quit(0)

func _arm(label: String, trip_rounds: int, weighted: bool) -> void:
	Config.COMBAT_TRIP_KILLS = 6
	Config.COMBAT_TRIP_ROUNDS = trip_rounds
	Config.BRAIN_WEIGHTED_TIES = weighted
	var cshare: Array = []
	var fr: Array = []
	var al: Array = []
	var ri: Array = []
	var ne: Array = []
	var gpc: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		cshare.append(m["cshare"])
		fr.append(m["friend"]); al.append(m["ally"]); ri.append(m["rival"]); ne.append(m["nemesis"])
		gpc.append(m["gpc"])
	print("%s" % label)
	print("    combat-share (non-fav fighting): %.0f%% ± %.0f   [must drop from ~32%%, not crater]" % [_mean(cshare), _sd(cshare)])
	print("    social:  Friend %.1f%% ± %.1f · Ally %.1f%% · Rival %.1f%% ± %.1f · Nemesis %.1f%%" % [_mean(fr), _sd(fr), _mean(al), _mean(ri), _sd(ri), _mean(ne)])
	print("    per-capita gold: %.0f ± %.0f   [attractor should still bound; level may drop as loot faucet shrinks]\n" % [_mean(gpc), _sd(gpc)])

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
	# combat-share: % of non-fighting-favorite heroes currently fighting (matches the banked 32% metric)
	var nonfav := 0
	var nonfav_fighting := 0
	for h in world.heroes:
		if h.favorite != "fighting":
			nonfav += 1
			if String(h.act.get("intent", "")) == "FIGHT":
				nonfav_fighting += 1
	# social tier counts over stored edges
	var counts := {"Friend": 0, "Ally": 0, "Rival": 0, "Nemesis": 0}
	for a in world.social.adj:
		for b in world.social.adj[a]:
			var t: String = world.social.tier(int(a), int(b), today)
			if counts.has(t):
				counts[t] = int(counts[t]) + 1
	var pairs: int = maxi(1, n * (n - 1))
	return {
		"cshare": 100.0 * float(nonfav_fighting) / maxf(1.0, float(nonfav)),
		"friend": 100.0 * float(counts["Friend"]) / pairs,
		"ally": 100.0 * float(counts["Ally"]) / pairs,
		"rival": 100.0 * float(counts["Rival"]) / pairs,
		"nemesis": 100.0 * float(counts["Nemesis"]) / pairs,
		"gpc": float(world.total_gold()) / maxi(1, n),
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
