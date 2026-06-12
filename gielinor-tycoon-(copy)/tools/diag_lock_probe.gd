extends SceneTree
## STEP-4 PROBE (2026-06-09): can the player's control tiers REACH a combat-locked hero?
## The held Stage-2 residual = ~32% of non-fighting-favorite heroes stuck fighting because the kills-gated
## trip-completion (N=6) is unreachable at high congestion (4 rats shared ~20 ways) → they never clear their
## act → never reach a decision point → "locked". The Tier-1 sweep proved incentivize moves *un*locked labor.
## OPEN QUESTION (load-bearing for whether Stage-2 is optional polish or a Step-5 prerequisite): do the new
## controls reach the LOCKED ones? Measured, not guessed — multi-seed, mean ± SD.
##
## Method: grow a colony to scale (23 days, immigration ON) → the monoculture forms. FREEZE membership, then
## identify the non-fav fighters (the over-concentrated set) and run a 2-day probe window under three arms
## (same seed → identical pre-probe state):
##   • none   — no intervention: how many are FROZEN (0 decisions in the window = truly locked)?
##   • nudge  — Tier-2: nudge each to GATHER_LOGS. Did they leave FIGHT? (nudge_hero clears act = an INTERRUPT)
##   • bounty — Tier-1: post a clamped (24) GATHER_LOGS bounty, NO nudge. Did they leave FIGHT? (passive utility,
##              only bites at a decision point → should reach only the non-frozen)
## Metric per arm: % of the target fighters who left FIGHT at any point in the window. Run:
##   godot --headless --path game --script res://tools/diag_lock_probe.gd

const DAYS := 23
const PROBE_DAYS := 2
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]

func _initialize() -> void:
	print("=== STEP-4 PROBE — do control tiers reach a combat-LOCKED hero? (%d seeds, mean ± SD) ===" % SEEDS.size())
	print("grow %d days → freeze → target = non-fav heroes currently FIGHTing → %d-day probe window\n" % [DAYS, PROBE_DAYS])
	var n_t: Array = []
	var nf: Array = []
	var frozen: Array = []
	var left_none: Array = []
	var left_nudge: Array = []
	var left_bounty: Array = []
	for seed_v in SEEDS:
		var a_none := _arm(int(seed_v), "none")
		var a_nudge := _arm(int(seed_v), "nudge")
		var a_bounty := _arm(int(seed_v), "bounty")
		if int(a_none["n"]) == 0:
			print("seed %x: no non-fav fighters at snapshot — skipped" % seed_v)
			continue
		n_t.append(a_none["n"])
		nf.append(a_none["nonfav_fight_pct"])
		frozen.append(a_none["pct_frozen"])
		left_none.append(a_none["pct_left"])
		left_nudge.append(a_nudge["pct_left"])
		left_bounty.append(a_bounty["pct_left"])
	print("colony state at probe (the monoculture we're probing):")
	print("    non-fav-favs fighting:   %.0f%% ± %.0f   (the held ~32%% residual)" % [_mean(nf), _sd(nf)])
	print("    target fighters / seed:  %.1f ± %.1f\n" % [_mean(n_t), _sd(n_t)])
	print("REACHABILITY — %% of those target fighters who LEFT combat during the %d-day window:" % PROBE_DAYS)
	print("    none   (locked baseline): %.0f%% left   ·  %.0f%% ± %.0f were FROZEN (0 decisions = truly locked)" % [_mean(left_none), _mean(frozen), _sd(frozen)])
	print("    NUDGE  (Tier-2 interrupt):%.0f%% ± %.0f left" % [_mean(left_nudge), _sd(left_nudge)])
	print("    BOUNTY (Tier-1 passive):  %.0f%% ± %.0f left" % [_mean(left_bounty), _sd(left_bounty)])
	print("")
	_verdict(_mean(frozen), _mean(left_none), _mean(left_nudge), _mean(left_bounty))
	quit(0)

func _verdict(frozen: float, ln: float, lnudge: float, lbounty: float) -> void:
	print("VERDICT:")
	if lnudge >= 90.0:
		print("  • NUDGE/SEIZE (Tier-2/3) REACH locked agents — they interrupt (clear act), no decision point needed.")
	else:
		print("  • NUDGE only reached %.0f%% — the interrupt does NOT reliably free locked fighters (unexpected; investigate)." % lnudge)
	if lbounty <= ln + 8.0:
		print("  • BOUNTY (Tier-1) does NOT reach the locked ones — passive utility needs a decision point the")
		print("    frozen fighters never hit (bounty %.0f%% ≈ no-intervention %.0f%%)." % [lbounty, ln])
		print("  → BRANCH: controls-INHERIT-the-lock for Tier-1. Stage-2 (re-entrant/timer trip-completion) is a")
		print("    PREREQUISITE for Incentivize to reach locked agents — but Nudge/Seize are a release valve, so")
		print("    Step-5 social systems are safe IF they don't rely on incentivize reaching combat-locked heroes.")
	else:
		print("  • BOUNTY (Tier-1) freed %.0f%% vs %.0f%% baseline — it DOES reach some locked agents." % [lbounty, ln])
		print("  → BRANCH: controls-RELEASE-the-lock. Stage-2 is optional polish; proceed to Step 5.")

func _arm(seed_v: int, mode: String) -> Dictionary:
	var world := _run_to_state(seed_v)
	world.population.enabled = false   # freeze membership → a clean probe (no departures confound the count)
	var targets: Array = []
	for h in world.heroes:
		if h.favorite != "fighting" and String(h.act.get("intent", "")) == "FIGHT":
			targets.append(h)
	var nf_pct := _nonfav_fight_pct(world)
	var n := targets.size()
	if n == 0:
		return {"n": 0, "pct_left": 0.0, "pct_frozen": 0.0, "nonfav_fight_pct": nf_pct}
	var ids: Array = []
	var d0: Dictionary = {}
	for h in targets:
		ids.append(h.id)
		d0[h.id] = h.decisions
	if mode == "nudge":
		for h in targets:
			world.nudge_hero(h, "GATHER_LOGS")
	elif mode == "bounty":
		world.set_incentive("GATHER_LOGS", Config.INCENTIVE_MAX)
	var left: Dictionary = {}
	for id in ids:
		left[id] = false
	var probe_ticks := int(PROBE_DAYS / SimWorld._DD_PER_ACTION)
	for i in range(probe_ticks):
		world.tick(SimWorld._ACTION_SECONDS)
		if i % 10 == 0:
			for id in ids:
				var h := world.hero_by_id(int(id))
				if h != null and String(h.act.get("intent", "")) != "FIGHT":
					left[id] = true
	var n_left := 0
	var n_frozen := 0
	for id in ids:
		if bool(left[id]):
			n_left += 1
		var h := world.hero_by_id(int(id))
		if h != null and h.decisions == int(d0[id]):
			n_frozen += 1
	return {
		"n": n,
		"pct_left": 100.0 * float(n_left) / float(n),
		"pct_frozen": 100.0 * float(n_frozen) / float(n),
		"nonfav_fight_pct": nf_pct,
	}

func _run_to_state(seed_v: int) -> SimWorld:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)   # immigration ON → grows to scale, the monoculture forms
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	return world

func _nonfav_fight_pct(world) -> float:
	var nonfav := 0
	var fighting := 0
	for h in world.heroes:
		if h.favorite != "fighting":
			nonfav += 1
			if String(h.act.get("intent", "")) == "FIGHT":
				fighting += 1
	return 100.0 * float(fighting) / maxf(1.0, float(nonfav))

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
