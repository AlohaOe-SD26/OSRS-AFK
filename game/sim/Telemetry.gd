class_name Telemetry
extends RefCounted
## Debug-log / telemetry (HANDOFF §8). Mirrors the prototype's "Export Debug Log" so a player
## can run the build, hit export, and send the log back for tuning. Captures startup config,
## periodic snapshots, auto-flagged anomalies (steady-state drift, not naive first-vs-last —
## so the healthy warmup ramp isn't false-flagged), a thinned time series, and the chronicle.

var dbg_log: Array = []           # Array[Dictionary] snapshots
var seed_value: int = 0
const MAX_SNAPSHOTS := 500

func _init(seed_v: int = 0) -> void:
	seed_value = seed_v

func capture_snapshot(world: SimWorld) -> void:
	var acts := {}
	for h in world.heroes:
		var k := _act_key(h)
		acts[k] = int(acts.get(k, 0)) + 1
	var cmb := 0
	for h in world.heroes:
		cmb += h.skill_level("attack") + h.skill_level("strength") + h.skill_level("defence")
	cmb = int(round(float(cmb) / maxi(1, world.heroes.size())))
	var pop: int = world.heroes.size()
	var gold: int = world.total_gold()
	dbg_log.append({
		"day": world.sim_day,
		"t": int(round(world.sim_total)),
		"gold": gold,
		"pop": pop,
		"gpc": int(round(float(gold) / maxi(1, pop))),   # gold per capita — the population-robust balance
		"rep": int(round(world.population.reputation)) if world.population != null else 0,
		"ore": world.economy.sell_price("ore"),
		"food_p": world.economy.food_price(),
		"food": world.economy.total_stock("cooked_fish"),
		"acts": acts,
		"deaths": world.deaths,
		"flees": world.flees,
		"kills": world.total_kills,
		"cmb": cmb,
	})
	if dbg_log.size() > MAX_SNAPSHOTS:
		dbg_log.pop_front()

static func _act_key(h: Hero) -> String:
	var intent: String = h.act.get("intent", "")
	if intent == "":
		return "idle"
	return intent.replace("GATHER_", "").replace("PROVISION", "FISH").to_lower()

func _mean(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for v in arr:
		s += v
	return s / arr.size()

func export_log(world: SimWorld) -> String:
	var n := dbg_log.size()
	var gold_now := world.total_gold()

	# steady-state drift on PER-CAPITA gold (population-robust — total gold legitimately scales with
	# head-count, so per-capita is the real balance signal). Ignore the warmup ramp; last vs middle third.
	var mid: Array = []
	var late: Array = []
	for i in range(n):
		if i >= n / 3 and i < 2 * n / 3:
			mid.append(dbg_log[i]["gpc"])
		elif i >= 2 * n / 3:
			late.append(dbg_log[i]["gpc"])
	var drift := 0
	if _mean(mid) != 0.0:
		drift = int(round((_mean(late) - _mean(mid)) / _mean(mid) * 100.0))

	var anomalies: Array = []
	if n > 12 and drift > 25:
		anomalies.append("GOLD INFLATING (per-capita steady-state +%d%%) — faucets > sinks; raise UPKEEP_RATE/GE_TAX or lower drop-gold (§6)." % drift)
	if n > 12 and drift < -25:
		anomalies.append("GOLD STARVING (per-capita steady-state %d%%) — sinks > faucets; lower UPKEEP_RATE or raise prices/drops (§6)." % drift)
	var broke := 0
	for h in world.heroes:
		if h.gold < world.economy.food_price() and int(h.inv.get("cooked_fish", 0)) < 1 and h.favorite == "fighting":
			broke += 1
	if broke > 0:
		anomalies.append("%d fighter(s) broke & foodless — economy may be choking the combat loop." % broke)
	if anomalies.is_empty():
		anomalies.append("none detected — loop looks healthy")

	# activity mix now
	var acts_now := {}
	for h in world.heroes:
		var k := _act_key(h)
		acts_now[k] = int(acts_now.get(k, 0)) + 1
	var mix := ""
	for k in acts_now:
		mix += "%s %d · " % [k, acts_now[k]]

	# thinned time series
	var step := maxi(1, int(n / 30.0))
	var rows: Array = []
	var i := 0
	while i < n:
		var d: Dictionary = dbg_log[i]
		rows.append("d%d t%d  pop %2d  gold %6d  g/cap %4d  rep %3d  ore %dg  food %3d  kills %d  deaths %d  cmb %d" % [d["day"], d["t"], d["pop"], d["gold"], d["gpc"], d["rep"], d["ore"], d["food"], d["kills"], d["deaths"], d["cmb"]])
		i += step

	var chron: Array = []
	for ev in world.chronicle.slice(0, 15):
		chron.append("%s  %s" % [ev["t"], ev["text"]])

	var first_gold: int = dbg_log[0]["gold"] if n > 0 else gold_now
	var txt := "=== GIELINOR TYCOON — PHASE 0 DEBUG LOG ===\n"
	txt += "seed: %d · sim day %d · heroes %d · snapshots %d\n" % [seed_value, world.sim_day, world.heroes.size(), n]
	txt += "CONFIG: xpRate %.1f · geTax %.2f · upkeepRate %.2f · ratDrop %d-%d\n\n" % [Config.XP_RATE, Config.GE_TAX, Config.UPKEEP_RATE, Config.RAT_DROP_MIN, Config.RAT_DROP_MIN + Config.RAT_DROP_RANGE]
	txt += "--- SUMMARY ---\n"
	var pop_now: int = world.heroes.size()
	txt += "total gold: %d -> %d  ·  per-capita drift %s%d%% (population-robust)\n" % [first_gold, gold_now, ("+" if drift >= 0 else ""), drift]
	if world.population != null:
		var pop0: int = dbg_log[0]["pop"] if n > 0 else pop_now
		var p: Population = world.population
		var tiers := ""
		for k in p.tier_counts:
			if int(p.tier_counts[k]) > 0:
				tiers += "%s %d · " % [k, p.tier_counts[k]]
		txt += "population: %d -> %d / cap %d  (arrivals %d · departures %d)\n" % [pop0, pop_now, Config.POP_CAP, p.arrivals, p.departures]
		txt += "reputation: %d  ·  newcomer tiers: %s\n" % [int(p.reputation), (tiers.trim_suffix("· ") if tiers != "" else "none yet")]
	if world.social != null:
		var th: Dictionary = world.social.tier_histogram(world.sim_day)
		txt += "social graph: %d edges  ·  friends %d · allies %d · rivals %d · nemeses %d\n" % [world.social.edge_count(), th["Friend"], th["Ally"], th["Rival"], th["Nemesis"]]
	txt += "rats slain: %d · deaths: %d · flees: %d\n" % [world.total_kills, world.deaths, world.flees]
	txt += "ore sell %dg · food price %dg · food in shop %d\n" % [world.economy.sell_price("ore"), world.economy.food_price(), world.economy.total_stock("cooked_fish")]
	txt += "activity mix now: %s\n\n" % mix.trim_suffix("· ")
	txt += "--- ANOMALIES (auto-flagged) ---\n"
	for a in anomalies:
		txt += "• %s\n" % a
	txt += "\n--- TIME SERIES (every %d snapshot) ---\n%s\n" % [step, "\n".join(PackedStringArray(rows))]
	txt += "\n--- RECENT CHRONICLE ---\n%s\n=== END ===" % "\n".join(PackedStringArray(chron))
	return txt
