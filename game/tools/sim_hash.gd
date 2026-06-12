extends RefCounted
## Deterministic state-hash of a SimWorld — the shared correctness instrument for Step-6's determinism gates
## (LOD byte-identical · save/load deterministic-replay · offline faucet-absorption). Hashes the full telemetry
## series PLUS the live hero/economy/social/population state into one stable int, so two runs that should be
## identical can be compared in one number. ONLY reads sim state (never renders) → render/LOD lives outside this.
##
## DELIBERATELY NO class_name: harnesses load this via `preload("res://tools/sim_hash.gd")`, which works
## regardless of the global class cache — so no `--import` pass is ever needed before running a gate. (The
## --import-then---script chain hung a gate run once; preload-by-path removes that dependency entirely.)

## A stable string fingerprint of the world's current live state (order-independent where it must be).
static func state_string(world) -> String:
	var parts: PackedStringArray = []
	parts.append("D%d T%d K%d Dth%d Fl%d RNG%d" % [world.sim_day, int(round(world.sim_total)), world.total_kills, world.deaths, world.flees, world.rng.get_state()])
	parts.append("GOLD%d TREAS%d TAX%.1f" % [world.total_gold(), int(world.economy.treasury), world.economy.tax_collected])
	for m in world.monsters:
		parts.append("m%s hp%d %s r%.3f" % [m.type_id, m.hp, "A" if m.alive else "d", m.respawn])
	# heroes sorted by id → order-independent
	var heroes: Array = world.heroes.duplicate()
	heroes.sort_custom(func(a, b): return a.id < b.id)
	for h in heroes:
		parts.append("h%d:%s g%d hp%d %s|%s sp%d task%s/%d" % [h.id, h.hero_name, int(h.gold), h.hp,
			_skills_str(h), String(h.act.get("intent", "-")), h.slayer_points,
			String(h.slayer_task.get("mon", "-")), int(h.slayer_task.get("remaining", 0))])
	# economy shops
	for s in world.economy.shops:
		parts.append("shop%s L%d %s" % [s.npc_id, s.level, _stock_str(s)])
	# slayer colony knowledge (Unit 0) — part of the persistence/determinism fingerprint
	var kk: Array = world.kill_counts.keys()
	kk.sort()
	for k in kk:
		parts.append("kc%s:%d" % [k, int(world.kill_counts[k])])
	# social edge count + tier histogram (graph shape)
	if world.social != null:
		var th: Dictionary = world.social.tier_histogram(world.sim_day)
		parts.append("soc e%d F%d A%d R%d N%d" % [world.social.edge_count(), th["Friend"], th["Ally"], th["Rival"], th["Nemesis"]])
	if world.population != null:
		parts.append("pop%d rep%d arr%d dep%d" % [world.heroes.size(), int(world.population.reputation), world.population.arrivals, world.population.departures])
	return "\n".join(parts)

static func _skills_str(h) -> String:
	var ks: Array = h.skills.keys()
	ks.sort()
	var out: PackedStringArray = []
	for k in ks:
		out.append("%s%d/%d" % [k, int(h.skills[k]["level"]), int(h.skills[k]["xp"])])
	return ",".join(out)

static func _stock_str(s) -> String:
	var ks: Array = s.stock.keys()
	ks.sort()
	var out: PackedStringArray = []
	for k in ks:
		out.append("%s%.2f" % [k, s.stock[k]])
	return ",".join(out)

## Run a fresh world `days` sim-days from `seed_v` and return [hash:int, final_state_string:String].
## `tick_hook` (optional Callable(world, tick_index)) lets a caller inject a save/load mid-run, etc.
static func run_and_hash(seed_v: int, days: int, tick_hook = null) -> Array:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(seed_v)
	world.setup(content, 6, seed_v)
	var ticks := int(days / SimWorld._DD_PER_ACTION)
	var trace := ""
	for i in range(ticks):
		world.tick(SimWorld._ACTION_SECONDS)
		if tick_hook != null:
			world = tick_hook.call(world, i)
		if i % 500 == 0:
			trace += "[%d] GOLD%d K%d POP%d\n" % [i, world.total_gold(), world.total_kills, world.heroes.size()]
	var final := state_string(world)
	return [(trace + final).hash(), final]
