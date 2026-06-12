extends SceneTree
## UNIT-0 CLOSING SWEEP (#1e, ruling R6). Sweeps SLAYER_ON_TASK (opened at +20; "the number is
## yours within gates") and reports, per arm, the monoculture and rival-lean metrics alongside the
## usual per-capita-gold band — instrumented so the banked §18 prediction (Slayer's finite, risky,
## gated combat targets resolve the combat-attractor lean AND its social mask, KI-4/KI-5) is
## verified or falsified for free while sweeping. Multi-seed, mean ± SD (single-seed before/after
## is RNG-confounded). All other levers pinned at committed defaults. Run:
##   godot --headless --path game --script res://tools/diag_unit0.gd
## Banked reference points: combat-share (non-fav fighting) was 32–42%% bug-era, ~8–20%% post-fixes
## (KI-4); social web rival-leaning, Rival 10–13%% vs Friend 8–9%% (KI-5); validated gold band
## 1,065–1,211 pre-survival-triad (drifted up — fewer deaths = more productive hours; re-baseline).

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]
const ARMS := [0.0, 10.0, 20.0, 35.0]

func _initialize() -> void:
	print("=== UNIT-0 CLOSING SWEEP — SLAYER_ON_TASK x %d arms, %d seeds, %d sim-days (mean ± SD) ===" % [ARMS.size(), SEEDS.size(), DAYS])
	print("(§18 verdict needs: combat-share NOT above the ~8–20%% banked range, rival-lean eased toward Friend ≥ Rival)\n")
	for bonus in ARMS:
		_arm(float(bonus))
	quit(0)

func _arm(bonus: float) -> void:
	Config.SLAYER_ON_TASK = bonus
	# pin everything else at committed defaults — this sweep isolates ONE lever
	Config.BRAIN_V2 = false
	Config.COMBAT_TRIP_KILLS = 6
	Config.COMBAT_CONGESTION_MULT = 0.5
	var cshare: Array = []
	var fr: Array = []
	var al: Array = []
	var ri: Array = []
	var ne: Array = []
	var gpc: Array = []
	var dead: Array = []
	var tasks: Array = []
	var ontask: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		cshare.append(m["cshare"])
		fr.append(m["friend"]); al.append(m["ally"]); ri.append(m["rival"]); ne.append(m["nemesis"])
		gpc.append(m["gpc"]); dead.append(m["deaths"]); tasks.append(m["tasks"]); ontask.append(m["ontask"])
	print("SLAYER_ON_TASK = %+.0f%s" % [bonus, "   (open default)" if absf(bonus - 20.0) < 0.01 else ""])
	print("    monoculture — non-fav fighting: %.0f%% ± %.0f   [banked: 32%% bug-era / 8–20%% post-fix]" % [_mean(cshare), _sd(cshare)])
	print("    social — Friend %.1f%% ± %.1f · Ally %.1f%% · Rival %.1f%% ± %.1f · Nemesis %.1f%%" % [_mean(fr), _sd(fr), _mean(al), _mean(ri), _sd(ri), _mean(ne)])
	print("    rival-lean (Rival − Friend): %+.1f pts   [KI-5 banked: +2 to +4 = rival-leaning]" % (_mean(ri) - _mean(fr)))
	print("    per-capita gold: %.0f ± %.0f   [old band 1,065–1,211 — re-baselining]" % [_mean(gpc), _sd(gpc)])
	print("    deaths/run: %.1f ± %.1f · slayer tasks assigned: %.1f · fighters on-task: %.0f%%\n" % [_mean(dead), _sd(dead), _mean(tasks), _mean(ontask)])

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
	var nonfav := 0
	var nonfav_fighting := 0
	var fighters := 0
	var fighters_on_task := 0
	for h in world.heroes:
		var fighting: bool = String(h.act.get("intent", "")) == "FIGHT"
		if h.favorite != "fighting":
			nonfav += 1
			if fighting:
				nonfav_fighting += 1
		if fighting:
			fighters += 1
			if not h.slayer_task.is_empty() and String(h.act.get("loc", "")) == String(h.slayer_task.get("camp", "")):
				fighters_on_task += 1
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
		"deaths": world.deaths,
		"tasks": world.slayer_tasks_assigned,
		"ontask": 100.0 * float(fighters_on_task) / maxf(1.0, float(fighters)),
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
