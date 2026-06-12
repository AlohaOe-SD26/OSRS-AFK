extends SceneTree
## STEP-6 OFFLINE gate — the instance-#5 gate, two-sided: the offline return-batch must be ABSORBED by the
## attractor (no spike on reconnect, no permanently shifted level), and the caps/rates must clamp. NOT a
## byte-identical gate — offline is an intentional approximation (75%, capped); the criterion is bounded
## re-convergence. Method per seed (uses the proven save/load to clone one day-12 state):
##   grow 12 days → save → for H in {2,6,24,30}: load clone → offline_catchup(H) → batch bounded?
##   cap: gain(30h) == gain(24h) exactly (the 24h clamp).
##   trajectory: the H=24 world continues live 6 days vs a no-offline control clone — post-reconnect
##   per-capita gold must re-converge to the control's bounded level (≤25% apart at the end).
## Standing harness rules: preload deps, quit() at end, run foreground with timeout.
##   godot --headless --path game --script res://tools/gate_offline.gd

const SaveLoad := preload("res://sim/SaveLoad.gd")
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE]
const GROW_DAYS := 12
const CONT_DAYS := 6
const SAMPLE_TICKS := 1200   # trajectory sample cadence (~1.2 sim-days)

func _initialize() -> void:
	print("=== STEP-6 OFFLINE GATE — return-batch absorbed by the attractor; caps clamp (3 seeds) ===\n")
	var content := ContentDB.new()
	content.load_all("res://data")
	var all_ok := true
	for seed_v in SEEDS:
		all_ok = _one_seed(content, int(seed_v)) and all_ok
	print("\n%s" % ("PASS — offline yield respects the live economy's bounds; the attractor absorbs the batch." if all_ok else "FAIL — instance #5 caught at the gate; STOP."))
	quit(0 if all_ok else 1)

func _one_seed(content, seed_v: int) -> bool:
	var ok := true
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	for i in range(int(GROW_DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var gpc_pre := _gpc(world)
	SaveLoad.save_to_file(world, "user://gate_off.dat")
	print("seed %x — day %d, pop %d, per-capita PRE = %d" % [seed_v, world.sim_day, world.heroes.size(), gpc_pre])
	# --- batch boundedness across durations (incl. past the cap) ---
	var gains: Dictionary = {}
	var b24: SimWorld = null
	for hrs in [2.0, 6.0, 24.0, 30.0]:
		var b: SimWorld = SaveLoad.load_from_file(content, "user://gate_off.dat")
		var s := b.offline_catchup(hrs)
		gains[hrs] = int(s["gold"])
		var gpc_post := _gpc(b)
		var bounded := gpc_post <= 3 * gpc_pre and gpc_post <= gpc_pre + 1500
		ok = ok and bounded
		print("    offline %4.1fh: batch +%6dg  → per-capita %4d   %s" % [hrs, int(s["gold"]), gpc_post, "bounded" if bounded else "SPIKE — FAIL"])
		if hrs == 24.0:
			b24 = b
	var cap_ok: bool = int(gains[30.0]) == int(gains[24.0])
	ok = ok and cap_ok
	print("    24h cap clamps: gain(30h) %d == gain(24h) %d  -> %s" % [int(gains[30.0]), int(gains[24.0]), "YES" if cap_ok else "NO — FAIL"])
	# --- post-reconnect trajectory: H=24 world vs no-offline control, 6 live days ---
	var ctrl: SimWorld = SaveLoad.load_from_file(content, "user://gate_off.dat")
	var traj_b: Array = [_gpc(b24)]
	var traj_c: Array = [_gpc(ctrl)]
	var cont_ticks := int(CONT_DAYS / SimWorld._DD_PER_ACTION)
	for i in range(cont_ticks):
		b24.tick(SimWorld._ACTION_SECONDS)
		ctrl.tick(SimWorld._ACTION_SECONDS)
		if (i + 1) % SAMPLE_TICKS == 0:
			traj_b.append(_gpc(b24))
			traj_c.append(_gpc(ctrl))
	traj_b.append(_gpc(b24))
	traj_c.append(_gpc(ctrl))
	var final_b := float(traj_b[traj_b.size() - 1])
	var final_c := float(traj_c[traj_c.size() - 1])
	var delta_pct := absf(final_b - final_c) / maxf(1.0, final_c) * 100.0
	var conv_ok := delta_pct <= 25.0
	ok = ok and conv_ok
	print("    post-reconnect per-capita (offline-24h arm): %s" % _fmt(traj_b))
	print("    control (no offline, same window):           %s" % _fmt(traj_c))
	print("    re-convergence after %d live days: %.0f vs %.0f (Δ %.0f%%)  -> %s\n" % [CONT_DAYS, final_b, final_c, delta_pct, "re-bounds" if conv_ok else "SHIFTED — FAIL"])
	return ok

func _gpc(w) -> int:
	return int(round(float(w.total_gold()) / maxi(1, w.heroes.size())))

func _fmt(a: Array) -> String:
	var out: PackedStringArray = []
	for v in a:
		out.append("%d" % int(v))
	return " → ".join(out)
