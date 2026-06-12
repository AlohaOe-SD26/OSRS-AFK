extends SceneTree
## STEP-6 piece 1 — SCALE VALIDATION. Do the locked conclusions HOLD at the 50-hero MVP target? The natural
## immigration plateau is ~43 (free-capacity damper asymptotes below cap-50), so we raise the cap and let the
## normal machinery grow to ~50, then re-run the standing metrics multi-seed vs the small-N baselines. A
## conclusion that MOVES at scale is a FINDING (report it), not a tuning target. Run:
##   godot --headless --path game --script res://tools/diag_scale.gd
##
## Standing conclusions checked: economy bounded (per-capita gold) · combat-share (~32% non-fav fighting) ·
## social distribution (~76%N / 6%F / 17%R) · per-tick perf (wall-time, the 50-agent budget watch).

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]

func _initialize() -> void:
	print("=== STEP-6 SCALE VALIDATION — do locked conclusions hold at ~50? (%d seeds, %d days, mean ± SD) ===\n" % [SEEDS.size(), DAYS])
	_arm("baseline  cap 50 (→ ~43, the banked N)", 50)
	_arm("scaled    cap 66 (→ ~50+, the MVP target)", 66)
	quit(0)

func _arm(label: String, cap: int) -> void:
	Config.POP_CAP = cap
	var pop: Array = []
	var gpc: Array = []
	var drift: Array = []
	var cshare: Array = []
	var fr: Array = []
	var ri: Array = []
	var ms_per_ktick: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		pop.append(m["pop"]); gpc.append(m["gpc"]); drift.append(m["drift"])
		cshare.append(m["cshare"]); fr.append(m["friend"]); ri.append(m["rival"])
		ms_per_ktick.append(m["ms_per_ktick"])
	print("%s" % label)
	print("    population reached:      %.0f ± %.0f" % [_mean(pop), _sd(pop)])
	print("    per-capita gold:         %.0f ± %.0f   (steady-state drift %.0f%% ± %.0f → bounded?)" % [_mean(gpc), _sd(gpc), _mean(drift), _sd(drift)])
	print("    combat-share (non-fav):  %.0f%% ± %.0f" % [_mean(cshare), _sd(cshare)])
	print("    social: Friend %.1f%% ± %.1f · Rival %.1f%% ± %.1f" % [_mean(fr), _sd(fr), _mean(ri), _sd(ri)])
	print("    perf: %.1f ms / 1k ticks ± %.1f   (50-agent budget watch)\n" % [_mean(ms_per_ktick), _sd(ms_per_ktick)])

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)   # grow from the founding 6 via immigration to the (raised) cap
	var ticks := int(DAYS / SimWorld._DD_PER_ACTION)
	var t0 := Time.get_ticks_msec()
	for i in range(ticks):
		world.tick(SimWorld._ACTION_SECONDS)
	var elapsed_ms := Time.get_ticks_msec() - t0
	var n: int = world.heroes.size()
	var today: int = world.sim_day
	# economy: per-capita gold + steady-state drift (mid vs late third of the telemetry, like the green-gate test)
	var log: Array = world.telemetry.dbg_log
	var ln := log.size()
	var mid: Array = []
	var late: Array = []
	for i in range(ln):
		if i >= ln / 3 and i < 2 * ln / 3:
			mid.append(float(log[i]["gpc"]))
		elif i >= 2 * ln / 3:
			late.append(float(log[i]["gpc"]))
	var dr := 0.0
	if _mean(mid) != 0.0:
		dr = (_mean(late) - _mean(mid)) / _mean(mid) * 100.0
	# combat-share
	var nonfav := 0
	var nonfav_fighting := 0
	for h in world.heroes:
		if h.favorite != "fighting":
			nonfav += 1
			if String(h.act.get("intent", "")) == "FIGHT":
				nonfav_fighting += 1
	# social
	var counts := {"Friend": 0, "Rival": 0}
	for a in world.social.adj:
		for b in world.social.adj[a]:
			var t: String = world.social.tier(int(a), int(b), today)
			if counts.has(t):
				counts[t] = int(counts[t]) + 1
	var pairs: int = maxi(1, n * (n - 1))
	return {
		"pop": n,
		"gpc": float(world.total_gold()) / maxi(1, n),
		"drift": dr,
		"cshare": 100.0 * float(nonfav_fighting) / maxf(1.0, float(nonfav)),
		"friend": 100.0 * float(counts["Friend"]) / pairs,
		"rival": 100.0 * float(counts["Rival"]) / pairs,
		"ms_per_ktick": 1000.0 * float(elapsed_ms) / float(ticks),
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
