extends RefCounted
## Save/load — full sim-state persistence (GDD §25, Step 6). Serializes EVERYTHING that evolves —
## heroes, monsters, economy/shops, population, social graph, player layer (incentives/buildings/kick
## records), chronicle, clock/counters, and the RNG STATE (§25: the stream continues, not restarts) —
## so save→load→continue is byte-identical to an uninterrupted run (the determinism gate).
##
## Design rules:
##  • BINARY Variant serialization (FileAccess.store_var/get_var) — exact bit round-trip for floats and
##    Vector2s; a text format's decimal precision could silently break the determinism gate.
##  • save_world() is a PURE READ — it must not mutate the world (no log_event), so saving mid-run
##    cannot perturb the run it's saving.
##  • DELIBERATELY NO class_name (standing harness rule #2): consumers `preload("res://sim/SaveLoad.gd")`
##    so no --import pass is ever needed. References only long-registered sim classes.

const SAVE_VERSION := 2   # v2: Slayer (kill_counts/tasks_assigned on world; slayer_task/points/skill on heroes)

# --------------------------------------------------------------------- migrations (R10 scaffold)
## Ordered upgrader chain: key v maps to a Callable that takes a version-v save dict and returns a
## version-(v+1) dict. Every unit that changes the save shape bumps SAVE_VERSION and appends its
## upgrader here (e.g. `1: _migrate_1_to_2`). Ruled contract (DESIGN_RULINGS R10): a migrated save
## must LOAD VALIDLY and CONTINUE DETERMINISTICALLY from the load point — byte-equivalence to
## historical runs is only guaranteed WITHIN a version, never across a migration.
static func _chain() -> Dictionary:
	return {1: _migrate_1_to_2}

## v1 → v2 (Unit 0, Slayer): pre-Slayer worlds know nothing and hold no tasks; heroes gain the
## slayer skill at 1 (matching _new_hero's init so v2 worlds hash-shape consistently).
static func _migrate_1_to_2(d: Dictionary) -> Dictionary:
	var nd: Dictionary = d.duplicate(true)
	nd["kill_counts"] = {}
	nd["slayer_tasks_assigned"] = 0
	nd["bounties"] = {}
	nd["scurrius_unlocked"] = false
	for md in nd["monsters"]:
		md["atk_cd"] = 0.0
	for hd in nd["heroes"]:
		hd["slayer_task"] = {}
		hd["slayer_points"] = 0
		hd["skills"]["slayer"] = {"level": 1, "xp": 0}
		hd["tol_t"] = 0.0
	nd["version"] = 2
	return nd

## Walk `d` up the chain until it reaches SAVE_VERSION. Returns {} when the save cannot be brought
## current (future/unknown version, or a gap in the chain) — callers treat {} as "unloadable", which
## preserves the old strict-version rejection for anything the chain can't reach.
## `chain` is injectable so tests can exercise the walker with a synthetic chain; production callers
## pass nothing and get the real one.
static func migrate(d: Dictionary, chain: Dictionary = {}) -> Dictionary:
	if chain.is_empty():
		chain = _chain()
	var v := int(d.get("version", -1))
	while v != SAVE_VERSION and chain.has(v):
		d = chain[v].call(d)
		var nv := int(d.get("version", -1))
		if nv <= v:   # every upgrader must advance the version — guards against a stalled chain
			return {}
		v = nv
	return d if v == SAVE_VERSION else {}

# --------------------------------------------------------------------------- save
static func save_world(w) -> Dictionary:
	var heroes: Array = []
	for h in w.heroes:
		heroes.append(_save_hero(h))
	var monsters: Array = []
	for m in w.monsters:
		monsters.append({"type_id": m.type_id, "pos": m.pos, "hp": m.hp, "max_hp": m.max_hp,
			"defence": m.defence, "monster_max_hit": m.monster_max_hit, "attack_speed": m.attack_speed,
			"alive": m.alive, "respawn": m.respawn, "wander": m.wander, "atk_cd": m.atk_cd,
			"move_target": m.move_target, "camp": m.camp})
	var shops: Array = []
	for s in w.economy.shops:
		shops.append({"npc_id": s.npc_id, "stock": s.stock.duplicate(true),
			"maximum": s.maximum.duplicate(true), "base": s.base.duplicate(true),
			"consume": s.consume.duplicate(true), "level": s.level})
	var p = w.population
	return {
		"version": SAVE_VERSION,
		"rng_state": w.rng.get_state(),
		# clock / counters
		"sim_day": w.sim_day, "sim_clock": w.sim_clock, "sim_total": w.sim_total,
		"action_n": w.action_n, "deaths": w.deaths, "flees": w.flees, "total_kills": w.total_kills,
		"work_acc": w._work_acc, "next_id": w._next_id, "name_counts": w._name_counts.duplicate(true),
		"paused": w.paused,
		# entities
		"heroes": heroes, "monsters": monsters,
		# economy
		"treasury": w.economy.treasury, "tax_collected": w.economy.tax_collected, "shops": shops,
		# population
		"pop": {"enabled": p.enabled, "reputation": p.reputation, "recent_deaths": p.recent_deaths,
			"recent_kicks": p.recent_kicks, "immig_accum": p._immig_accum, "arrivals": p.arrivals,
			"departures": p.departures, "tier_counts": p.tier_counts.duplicate(true)},
		# social graph
		"social": {"adj": w.social.adj.duplicate(true), "acc": w.social._acc, "today": w.social._today},
		# player layer + story
		"incentives": w.incentives.duplicate(true), "buildings": w.buildings.duplicate(true),
		"kick_records": w.kick_records.duplicate(true),
		# slayer + funded bounties + boss gate (v2)
		"kill_counts": w.kill_counts.duplicate(true), "slayer_tasks_assigned": w.slayer_tasks_assigned,
		"bounties": w.bounties.duplicate(true), "scurrius_unlocked": w.scurrius_unlocked,
		"announced_bonds": w._announced_bonds.duplicate(true),
		"chronicle": w.chronicle.duplicate(true),
	}

static func _save_hero(h) -> Dictionary:
	return {"id": h.id, "hero_name": h.hero_name, "favorite": h.favorite, "secondary": h.secondary,
		"skin": h.skin, "hair": h.hair, "shirt": h.shirt, "skills": h.skills.duplicate(true),
		"hp": h.hp, "gold": h.gold, "inv": h.inv.duplicate(true), "traits": h.traits.duplicate(true),
		"tier": h.tier, "satisfaction": h.satisfaction, "unhappy_days": h.unhappy_days,
		"recent_success": h.recent_success, "pos": h.pos, "move_target": h.move_target,
		"act": h.act.duplicate(true), "thought": h.thought, "flash": h.flash, "decisions": h.decisions,
		"last_candidates": h.last_candidates.duplicate(true), "backstory": h.backstory,
		"milestones": h.milestones.duplicate(true), "nudge": h.nudge.duplicate(true), "seized": h.seized,
		"slayer_task": h.slayer_task.duplicate(true), "slayer_points": h.slayer_points,
		"weapon": h.weapon, "equipped": h.equipped.duplicate(true), "goal": h.goal.duplicate(true), "run_on": h.run_on, "run_energy": h.run_energy,
		"run_stop_at": h.run_stop_at, "run_cd_left": h.run_cd_left, "tol_t": h.tol_t,
		"path": h.path.duplicate(true), "path_goal": h.path_goal}

# --------------------------------------------------------------------------- load
## Rebuild a full SimWorld from a save dict. Mirrors setup()'s wiring WITHOUT its random draws — every
## evolving field is restored from the save; only static derivations (locations) rebuild from content.
static func load_world(content, d: Dictionary) -> SimWorld:
	var w := SimWorld.new()
	w.content = content
	w.rng = Rng.new(0)
	w.rng.set_state(int(d["rng_state"]))
	w._load_locations()
	# clock / counters
	w.sim_day = int(d["sim_day"]); w.sim_clock = float(d["sim_clock"]); w.sim_total = float(d["sim_total"])
	w.action_n = int(d["action_n"]); w.deaths = int(d["deaths"]); w.flees = int(d["flees"])
	w.total_kills = int(d["total_kills"]); w._work_acc = float(d["work_acc"])
	w._next_id = int(d["next_id"]); w._name_counts = d["name_counts"]; w.paused = bool(d["paused"])
	# entities (array ORDER preserved — tick iterates heroes in order, so order is part of determinism)
	for hd in d["heroes"]:
		w.heroes.append(_load_hero(hd))
	for md in d["monsters"]:
		var m := MonsterInstance.new()
		m.type_id = md["type_id"]; m.pos = md["pos"]; m.hp = int(md["hp"]); m.max_hp = int(md["max_hp"])
		m.defence = int(md["defence"]); m.monster_max_hit = int(md["monster_max_hit"])
		m.attack_speed = int(md["attack_speed"]); m.alive = bool(md["alive"])
		m.respawn = float(md["respawn"]); m.wander = float(md["wander"]); m.move_target = md["move_target"]
		m.atk_cd = float(md.get("atk_cd", 0.0))
		m.camp = String(md.get("camp", "combat"))
		w.monsters.append(m)
	# economy: fresh shops (canon defs), then overwrite all evolving fields by npc_id
	w.economy = Economy.new()
	w.economy.treasury = float(d["treasury"])
	w.economy.tax_collected = float(d["tax_collected"])
	for sd in d["shops"]:
		for s in w.economy.shops:
			if s.npc_id == sd["npc_id"]:
				s.stock = sd["stock"]; s.maximum = sd["maximum"]; s.base = sd["base"]
				s.consume = sd["consume"]; s.level = int(sd["level"])
	# population
	w.population = Population.new()
	var pd: Dictionary = d["pop"]
	w.population.enabled = bool(pd["enabled"]); w.population.reputation = float(pd["reputation"])
	w.population.recent_deaths = float(pd["recent_deaths"]); w.population.recent_kicks = float(pd["recent_kicks"])
	w.population._immig_accum = float(pd["immig_accum"]); w.population.arrivals = int(pd["arrivals"])
	w.population.departures = int(pd["departures"]); w.population.tier_counts = pd["tier_counts"]
	# social graph
	w.social = Social.new()
	var sd2: Dictionary = d["social"]
	w.social.adj = sd2["adj"]; w.social._acc = float(sd2["acc"]); w.social._today = int(sd2["today"])
	# player layer + story
	w.incentives = d["incentives"]; w.buildings = d["buildings"]; w.kick_records = d["kick_records"]
	w._announced_bonds = d["announced_bonds"]; w.chronicle = d["chronicle"]
	# slayer + funded bounties + boss gate (v2 — migration guarantees presence)
	w.kill_counts = d["kill_counts"]; w.slayer_tasks_assigned = int(d["slayer_tasks_assigned"])
	w.bounties = d.get("bounties", {})
	w.scurrius_unlocked = bool(d.get("scurrius_unlocked", false))
	return w

static func _load_hero(hd: Dictionary) -> Hero:
	var h := Hero.new()
	h.id = int(hd["id"]); h.hero_name = hd["hero_name"]; h.favorite = hd["favorite"]
	h.secondary = hd["secondary"]; h.skin = hd["skin"]; h.hair = hd["hair"]; h.shirt = hd["shirt"]
	h.skills = hd["skills"]; h.hp = int(hd["hp"]); h.gold = float(hd["gold"]); h.inv = hd["inv"]
	h.traits = hd["traits"]; h.tier = hd["tier"]; h.satisfaction = float(hd["satisfaction"])
	h.unhappy_days = int(hd["unhappy_days"]); h.recent_success = float(hd["recent_success"])
	h.pos = hd["pos"]; h.move_target = hd["move_target"]; h.act = hd["act"]; h.thought = hd["thought"]
	h.flash = float(hd["flash"]); h.decisions = int(hd["decisions"])
	h.last_candidates = hd["last_candidates"]; h.backstory = hd["backstory"]
	h.milestones = hd["milestones"]; h.nudge = hd["nudge"]; h.seized = bool(hd["seized"])
	h.slayer_task = hd["slayer_task"]; h.slayer_points = int(hd["slayer_points"])
	h.weapon = String(hd.get("weapon", "sword"))
	h.equipped = hd.get("equipped", {})
	h.goal = hd.get("goal", {})
	h.run_on = bool(hd.get("run_on", false))
	h.run_energy = float(hd.get("run_energy", 100.0))
	h.run_stop_at = float(hd.get("run_stop_at", 0.0))
	h.run_cd_left = float(hd.get("run_cd_left", 0.0))
	h.tol_t = float(hd.get("tol_t", 0.0))
	h.path = hd.get("path", [])
	h.path_goal = hd.get("path_goal", null)
	return h

# --------------------------------------------------------------------------- files
static func save_to_file(w, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(save_world(w))
	return true

## Returns the loaded SimWorld, or null (missing file / unmigratable version). Old saves are run up
## the migration chain first; only saves the chain can't bring current are rejected.
## Caller attaches telemetry.
static func load_from_file(content, path: String) -> SimWorld:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d = f.get_var()
	if not (d is Dictionary):
		return null
	var current: Dictionary = migrate(d)
	if current.is_empty():
		return null
	return load_world(content, current)
