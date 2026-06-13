extends SceneTree
## #3d UNIT-2 CLOSING SWEEP — the KI-4 combat counter-force experiment + the Unit-2 closing band
## re-baseline. KI-4: combat is the standing monoculture refuge because its appeal is
## price-INDEPENDENT (flat base + coin drops), so it never saturates the way gather's price*0.25
## reward does. This sweeps the two combat-side levers TOGETHER:
##   - COMBAT_CONGESTION_MULT {0.5 current, 0.75, 1.0}  — the local crowding penalty weight
##   - COMBAT_GEAR_REWARD {off, on}                     — the gear-board price coupling (#3d)
## 6 arms = 3 × 2. Multi-seed, mean ± SD. Monoculture is INTEGRATED over the run (an instantaneous
## 6-hero count is mostly RNG — the measurement-discipline trap), kills/deaths/g-cap are end-of-run.
## Run:  godot --headless --path game --script res://tools/diag_unit2_close.gd
##
## LOCK CRITERION (KI-4 ruling): pick the arm that (a) drops integrated non-fav monoculture
## meaningfully below the control (0.5/off ≈ the shipped sim), WITHOUT (b) cratering combat —
## total_kills must stay within ~30% of the control, AND (c) g/cap stays bounded (no inflation/
## starvation drift). **AND (d) — LEARNED 2026-06-13 — the candidate arm must keep the release GATES
## green (determinism / save-load / OFFLINE), verified by actually running them at the arm's config
## BEFORE locking.** The 2026-06-13 run picked congestion 1.0 on (a)+(b)+(c) alone; 1.0's higher
## g/cap variance then FAILED the offline re-convergence gate (beef01 Δ31% vs ≤25%), forcing a revert.
## So: this sweep's metrics are necessary but NOT sufficient — the gates are part of the criterion.
## Among arms clearing (a)–(d), prefer the largest monoculture drop. The WINNER's g/cap mean±SD is the
## Unit-2 CLOSING BAND of record. (2026-06-13 outcome: NO arm cleared (a)+(d) — 1.0 gate-blocked, the
## gear coupling falsified, 0.75 band-destabilizing — so the shipping config stayed 0.5/off.)

const DAYS := 23
const WARMUP_DAY := 3.0
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]
const CONGESTION_ARMS := [0.5, 0.75, 1.0]

func _initialize() -> void:
	print("=== #3d UNIT-2 CLOSING SWEEP — congestion {0.5/0.75/1.0} × gear-coupling {off/on}, %d seeds, %d days (mean ± SD) ===" % [SEEDS.size(), DAYS])
	print("(KI-4: lower non-fav monoculture WITHOUT cratering kills; the winner's g/cap = the Unit-2 closing band)\n")
	for cong in CONGESTION_ARMS:
		_arm(float(cong), false)
		_arm(float(cong), true)
	quit(0)

func _arm(cong: float, gear: bool) -> void:
	# pin every other lever at its committed default — this sweep isolates the two combat levers
	Config.BRAIN_V2 = false
	Config.SLAYER_ON_TASK = 20.0
	Config.COMBAT_TRIP_KILLS = 6
	Config.COMBAT_CONGESTION_MULT = cong
	Config.COMBAT_GEAR_REWARD = gear
	Config.COMBAT_GEAR_K = 0.20
	var mono: Array = []
	var kills: Array = []
	var dead: Array = []
	var gpc: Array = []
	var board: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		mono.append(m["mono"]); kills.append(m["kills"]); dead.append(m["deaths"])
		gpc.append(m["gpc"]); board.append(m["board"])
	var tag := "congestion %.2f · gear-coupling %s" % [cong, "ON " if gear else "off"]
	var note := "   (control = shipped sim)" if (absf(cong - 0.5) < 0.01 and not gear) else ""
	print("%s%s" % [tag, note])
	print("    monoculture — non-fav fighting: %.0f%% ± %.0f   (integrated; KI-4 target = below control)" % [_mean(mono), _sd(mono)])
	print("    combat kills/run:               %.0f ± %.0f   (combat must NOT crater)" % [_mean(kills), _sd(kills)])
	print("    per-capita gold:                %.0f ± %.0f   (the closing band — winner becomes record)" % [_mean(gpc), _sd(gpc)])
	print("    deaths/run %.1f ± %.1f  ·  gear-board price end %.0f ± %.0f\n" % [_mean(dead), _sd(dead), _mean(board), _sd(board)])

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	var ticks := int(DAYS / SimWorld._DD_PER_ACTION)
	var warm := int(WARMUP_DAY / SimWorld._DD_PER_ACTION)
	var nonfav_fighting := 0
	var nonfav_samples := 0
	for i in range(ticks):
		world.tick(SimWorld._ACTION_SECONDS)
		if i > warm and i % 50 == 0:
			for h in world.heroes:
				if h.favorite != "fighting":
					nonfav_samples += 1
					if String(h.act.get("intent", "")) == "FIGHT":
						nonfav_fighting += 1
	var n: int = world.heroes.size()
	return {
		"mono": 100.0 * float(nonfav_fighting) / maxf(1.0, float(nonfav_samples)),
		"kills": float(world.total_kills),
		"deaths": float(world.deaths),
		"gpc": float(world.total_gold()) / maxi(1, n),
		"board": world.economy.gear_board_ref_price(),
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
