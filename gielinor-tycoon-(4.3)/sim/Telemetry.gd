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
	dbg_log.append({
		"day": world.sim_day,
		"t": int(round(world.sim_total)),
		"gold": world.total_gold(),
		"ore": world.economy.sell_price("ore"),
		"food_p": world.economy.food_price(),
		"food": world.economy.total_stock("cooked_fish"),
		"acts": acts,
		"deaths": world.deaths,
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

	# steady-state drift: ignore the warmup ramp; compare last third vs middle third
	var mid: Array = []
	var late: Array = []
	for i in range(n):
		if i >= n / 3 and i < 2 * n / 3:
			mid.append(dbg_log[i]["gold"])
		elif i >= 2 * n / 3:
			late.append(dbg_log[i]["gold"])
	var drift := 0
	if _mean(mid) != 0.0:
		drift = int(round((_mean(late) - _mean(mid)) / _mean(mid) * 100.0))

	var anomalies: Array = []
	if n > 12 and drift > 25:
		anomalies.append("GOLD INFLATING (steady-state +%d%%) — faucets > sinks; raise UPKEEP_RATE/GE_TAX or lower drop-gold (§6)." % drift)
	if n > 12 and drift < -25:
		anomalies.append("GOLD STARVING (steady-state %d%%) — sinks > faucets; lower UPKEEP_RATE or raise prices/drops (§6)." % drift)
	var broke := 0
	for h in world.heroes:
		if h.gold < world.economy.food_price() and int(h.inv.get("cooked_fish", 0)) < 1 and h.favorite in ["attack", "strength", "defence"]:
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
		rows.append("d%d t%d  gold %6d  ore %dg  food %3d  deaths %d  cmb %d" % [d["day"], d["t"], d["gold"], d["ore"], d["food"], d["deaths"], d["cmb"]])
		i += step

	var chron: Array = []
	for ev in world.chronicle.slice(0, 15):
		chron.append("%s  %s" % [ev["t"], ev["text"]])

	var first_gold: int = dbg_log[0]["gold"] if n > 0 else gold_now
	var txt := "=== GIELINOR TYCOON — PHASE 0 DEBUG LOG ===\n"
	txt += "seed: %d · sim day %d · heroes %d · snapshots %d\n" % [seed_value, world.sim_day, world.heroes.size(), n]
	txt += "CONFIG: xpRate %.1f · geTax %.2f · upkeepRate %.2f · ratDrop %d-%d\n\n" % [Config.XP_RATE, Config.GE_TAX, Config.UPKEEP_RATE, Config.RAT_DROP_MIN, Config.RAT_DROP_MIN + Config.RAT_DROP_RANGE]
	txt += "--- SUMMARY ---\n"
	txt += "total gold: %d -> %d (steady-state drift %s%d%%)\n" % [first_gold, gold_now, ("+" if drift >= 0 else ""), drift]
	txt += "ore sell %dg · food price %dg · food in shop %d\n" % [world.economy.sell_price("ore"), world.economy.food_price(), world.economy.total_stock("cooked_fish")]
	txt += "activity mix now: %s\n\n" % mix.trim_suffix("· ")
	txt += "--- ANOMALIES (auto-flagged) ---\n"
	for a in anomalies:
		txt += "• %s\n" % a
	txt += "\n--- TIME SERIES (every %d snapshot) ---\n%s\n" % [step, "\n".join(PackedStringArray(rows))]
	txt += "\n--- RECENT CHRONICLE ---\n%s\n=== END ===" % "\n".join(PackedStringArray(chron))
	return txt
