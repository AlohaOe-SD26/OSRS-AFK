extends SceneTree
## STAGE-2 ASYMMETRY CONFIRMATION — single pass, EXISTING-LOGS ONLY (no new instrumentation; that would be
## §18's first move). Tests the re-diagnosis: combat is a PRICE-INDEPENDENT refuge → combat-share should rise
## as gather price falls (gather gluts → its reward collapses, combat's flat base doesn't). Reads ONLY fields
## the telemetry already exports per snapshot: ore (gather sell price), acts.fight (fighters), pop.
##
## Two reads per seed:
##  • FULL-RUN Pearson(ore_price, fight_share) — captures the price-falls-as-combat-rises trajectory, but is
##    POP-CONFOUNDED (both move with population over the run).
##  • PLATEAU Pearson (last third, pop ~stable) — the DECISIVE cut: at fixed pop, does price still inversely
##    track fight-share? If yes → mechanism holds (pop ruled out). If plateau price has ~no variance, report
##    the LEVEL instead (is gather floored while combat-share is high?) → can't-confirm-cheaply.
## Run:  godot --headless --path game --script res://tools/diag_asymmetry.gd

const DAYS := 23
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE, 0x1234567, 0xD00D42, 0x5EED99, 0x0B1, 0x7A11]

func _initialize() -> void:
	print("=== STAGE-2 ASYMMETRY — combat-as-price-independent-refuge (existing-logs correlation, %d seeds) ===" % SEEDS.size())
	print("(mechanism predicts NEGATIVE corr: gather price down → fight-share up. Plateau = decisive (pop-controlled).)\n")
	var full_r: Array = []
	var plat_r: Array = []
	var plat_price: Array = []
	var plat_pricevar: Array = []
	var plat_fshare: Array = []
	for seed_v in SEEDS:
		var m := _run_one(int(seed_v))
		full_r.append(m["full_r"])
		if not is_nan(m["plat_r"]):
			plat_r.append(m["plat_r"])
		plat_price.append(m["plat_price"])
		plat_pricevar.append(m["plat_pricevar"])
		plat_fshare.append(m["plat_fshare"])
	print("FULL-RUN  Pearson(ore_price, fight_share): %.2f ± %.2f   (pop-confounded; expect strongly negative if mechanism holds)" % [_mean(full_r), _sd(full_r)])
	print("PLATEAU   Pearson(ore_price, fight_share): %.2f ± %.2f   (DECISIVE — pop stable)" % [_mean(plat_r), _sd(plat_r)] if not plat_r.is_empty() else "PLATEAU   Pearson: undefined (no price variance in every seed)")
	print("PLATEAU   ore price: %.1f ± %.1f  (price std/seed %.2f — low ⇒ gather pinned at floor ⇒ correlation moot, read the LEVEL)" % [_mean(plat_price), _sd(plat_price), _mean(plat_pricevar)])
	print("PLATEAU   fight-share (of pop): %.0f%% ± %.0f\n" % [_mean(plat_fshare) * 100.0, _sd(plat_fshare) * 100.0])
	_verdict(_mean(full_r), _mean(plat_r) if not plat_r.is_empty() else NAN, _mean(plat_pricevar))
	quit(0)   # SceneTree scripts MUST exit explicitly — without this the process idles forever (the diagnosed hang)

func _verdict(full_r: float, plat_r: float, pricevar: float) -> void:
	print("VERDICT:")
	if not is_nan(plat_r) and pricevar > 0.5 and plat_r <= -0.3:
		print("  • CONFIRMED (colony-level): at stable pop, gather-price and fight-share are inversely correlated (r=%.2f)." % plat_r)
		print("    → combat IS a price-independent refuge. Bank the asymmetry as STRONG (per-hero decision-level read deferred to §18)." )
	elif pricevar <= 0.5:
		print("  • CAN'T-CONFIRM-CHEAPLY: plateau gather price has ~no variance (pinned ⇒ %.1f) — no signal to correlate at fixed pop." % pricevar)
		print("    Full-run r=%.2f is suggestive but pop-confounded. Bank as LEADING-BUT-UNCONFIRMED; per-hero confirmation = §18's first move." % full_r)
	elif not is_nan(plat_r) and plat_r > -0.1:
		print("  • SURPRISE — NOT correlated at stable pop (r=%.2f): fighters fight largely REGARDLESS of gather-price state." % plat_r)
		print("    The price-refuge mechanism is likely WRONG. Flag for re-diagnosis BEFORE banking anything as benign.")
	else:
		print("  • MIXED (plateau r=%.2f, pricevar=%.1f) — weak/ambiguous. Bank as LEADING-BUT-UNCONFIRMED." % [plat_r, pricevar])

func _run_one(seed_v: int) -> Dictionary:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	for i in range(int(DAYS / SimWorld._DD_PER_ACTION)):
		world.tick(SimWorld._ACTION_SECONDS)
	var log: Array = world.telemetry.dbg_log
	var n := log.size()
	# full-run series (skip cold-start first eighth)
	var fx: Array = []
	var fy: Array = []
	var px: Array = []
	var py: Array = []
	for i in range(n):
		var d: Dictionary = log[i]
		var pop: int = int(d["pop"])
		if pop <= 0:
			continue
		var price := float(d["ore"])
		var fshare := float(int(d["acts"].get("fight", 0))) / float(pop)
		if i >= n / 8:
			fx.append(price); fy.append(fshare)
		if i >= 2 * n / 3:        # plateau third (pop ~stable)
			px.append(price); py.append(fshare)
	return {
		"full_r": _pearson(fx, fy),
		"plat_r": _pearson(px, py),
		"plat_price": _mean(px),
		"plat_pricevar": _sd(px),
		"plat_fshare": _mean(py),
	}

func _pearson(xs: Array, ys: Array) -> float:
	var n := xs.size()
	if n < 3:
		return NAN
	var mx := _mean(xs)
	var my := _mean(ys)
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in range(n):
		var dx := float(xs[i]) - mx
		var dy := float(ys[i]) - my
		sxy += dx * dy
		sxx += dx * dx
		syy += dy * dy
	if sxx <= 0.0 or syy <= 0.0:
		return NAN   # no variance in one series
	return sxy / sqrt(sxx * syy)

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
