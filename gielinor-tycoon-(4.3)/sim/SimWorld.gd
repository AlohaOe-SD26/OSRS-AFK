class_name SimWorld
extends RefCounted
## The deterministic SIM CORE (GDD §21.2). Owns all simulation state (heroes, economy,
## content, clock, chronicle) and advances it via tick(dt). NO Node, NO rendering — the
## render layer reads this read-only. Headless-runnable (tests/test_sim.gd drives it with
## no engine display), which is what makes offline catch-up, LOD and save/load possible.
##
## Phase 0 wires build-order steps 0–1 (§22.3): one+ heroes on the brain doing dual-resolvable
## gather trips (mine/chop/fish → cook → sell) in a self-balancing economy. Combat is present
## as math/content (Combat.gd, monsters.json) but not yet a live activity (step 2).

const NAMES := ["Bjorn", "Saoirse", "Magnus", "Elara", "Thorne", "Rookwood", "Vael", "Mira",
	"Oskar", "Linnea", "Garrick", "Yusuf"]
const SKIN := ["#e7b58a", "#c98d5e", "#9c6b43", "#e8c9a0", "#7a5235"]
const HAIR := ["#3a2a1a", "#6b4423", "#c9a24b", "#8a8a8a", "#1c1c1c", "#a33d23"]
const SHIRT := ["#5a7d4f", "#6f93b0", "#8c2f2a", "#7a5ea0", "#b0883a", "#3d6b6b"]
const GATHER_SKILLS := ["mining", "woodcutting", "fishing", "cooking",
	"attack", "strength", "defence", "hitpoints"]

var content: ContentDB
var economy: Economy
var rng: Rng
var telemetry                      # Telemetry (set by owner after construction)

var heroes: Array = []             # Array[Hero]
var locations: Dictionary = {}     # loc_key -> { pos: Vector2, kind, label }
var grid_size: int = 18

var chronicle: Array = []          # newest-first event log (§17), capped
var paused: bool = false

# clock / counters
var sim_day: int = 1
var sim_clock: float = 0.0         # minutes within the current day (0..1440)
var sim_total: float = 0.0         # total sim-minutes elapsed
var action_n: int = 0              # work-actions executed
var deaths: int = 0

var _work_acc: float = 0.0
# static vars (not const) — initializers reference another class's consts, evaluated at load
static var _ACTION_SECONDS: float = Config.WORK_TICKS_PER_ACTION * Config.TICK
static var _DD_PER_ACTION: float = Config.SIM_MINUTES_PER_TICK / 1440.0

# ---------------------------------------------------------------------------
func setup(content_db: ContentDB, hero_count: int = 6, seed_value: int = Config.DEFAULT_SEED) -> void:
	content = content_db
	rng = Rng.new(seed_value)
	economy = Economy.new()
	_load_locations()
	heroes.clear()
	for i in range(hero_count):
		heroes.append(_make_hero(i))
	log_event("The colony of Varrock stirs to life. %d adventurers arrive." % hero_count, "lv")

func _load_locations() -> void:
	var md: Dictionary = content.map_data
	grid_size = int(md.get("gridSize", 18))
	var locs: Dictionary = md.get("locations", {})
	for key in locs:
		var l: Dictionary = locs[key]
		locations[key] = {
			"pos": Vector2(float(l.get("x", 0)), float(l.get("y", 0))),
			"kind": l.get("kind", "build"),
			"label": l.get("label", key),
		}

func _make_hero(i: int) -> Hero:
	# Phase-0 favorites span the gather loop so division of labor reads immediately.
	var favs := ["mining", "mining", "woodcutting", "fishing", "fishing", "woodcutting"]
	var h := Hero.new()
	h.id = i
	h.hero_name = NAMES[i % NAMES.size()]
	h.favorite = favs[i % favs.size()]
	h.secondary = "cooking" if h.favorite == "fishing" else ""
	h.skin = SKIN[i % SKIN.size()]
	h.hair = HAIR[i % HAIR.size()]
	h.shirt = SHIRT[i % SHIRT.size()]
	for s in GATHER_SKILLS:
		h.skills[s] = {"level": 1, "xp": 0}
	h.skills["hitpoints"] = {"level": 10, "xp": XpTables.xp_for_level(10)}
	# small head-start in the favorite so roles are legible from the first minute
	_boost(h, h.favorite, 6)
	if h.favorite == "fishing":
		_boost(h, "cooking", 5)
	h.hp = h.max_hp()
	h.gold = 20
	h.traits = {
		"risk": 0.3 + rng.randf() * 0.3,
		"greed": 0.3 + rng.randf() * 0.5,
		"ambition": rng.randf(),
		"sociability": rng.randf(),
		"patience": rng.randf(),
		"loyalty": rng.randf(),
	}
	# spawn near the central plaza / rat pit
	var c: Vector2 = location_tile("combat")
	h.pos = c + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
	return h

func _boost(h: Hero, skill: String, level: int) -> void:
	h.skills[skill] = {"level": level, "xp": XpTables.xp_for_level(level)}

# ---------------------------------------------------------------------------
# Helpers used by the brain
func location_tile(key: String) -> Vector2:
	return locations.get(key, {}).get("pos", Vector2.ZERO)

func distance_to(hero: Hero, loc_key: String) -> float:
	return hero.pos.distance_to(location_tile(loc_key))

func congestion(loc_key: String) -> int:
	var c := 0
	for h in heroes:
		if h.act.get("loc", "") == loc_key:
			c += 1
	return c

# ---------------------------------------------------------------------------
# Main deterministic step. dt = elapsed seconds (scaled by the caller's speed control).
func tick(dt: float) -> void:
	if paused:
		return
	for h in heroes:
		_move_step(h, dt)
	_work_acc += dt
	while _work_acc >= _ACTION_SECONDS:
		_work_acc -= _ACTION_SECONDS
		_advance_clock()
		for h in heroes:
			_work_action(h)
		economy.economy_tick(_DD_PER_ACTION, heroes)
		if telemetry != null and action_n % 30 == 0:
			telemetry.capture_snapshot(self)

func _advance_clock() -> void:
	sim_clock += Config.SIM_MINUTES_PER_TICK
	sim_total += Config.SIM_MINUTES_PER_TICK
	action_n += 1
	if sim_clock >= 24 * 60:
		sim_clock -= 24 * 60
		sim_day += 1

# ---------------------------------------------------------------------------
# Movement
func _set_move(h: Hero, loc_key: String) -> void:
	h.move_target = location_tile(loc_key)

func _at_target(h: Hero) -> bool:
	return h.move_target == null or h.pos.distance_to(h.move_target) < 0.18

func _move_step(h: Hero, dt: float) -> void:
	if h.move_target == null:
		return
	var target: Vector2 = h.move_target
	var d := h.pos.distance_to(target)
	if d < 0.05:
		return
	var step := Config.MOVE_SPEED * dt
	var k := minf(1.0, step / d)
	h.pos += (target - h.pos) * k

# ---------------------------------------------------------------------------
# The trip FSM (GDD §18.1 Layer 3). Mirrors the validated prototype loop.
func _start_activity(h: Hero) -> void:
	var c := Brain.choose(h, self)
	if c.is_empty():
		h.act = {}
		h.thought = "Deciding what to do next…"
		return
	h.act = {"intent": c["intent"], "loc": c["loc"], "skill": c["skill"],
		"res": c["res"], "phase": "goto", "target": c["loc"], "then": ""}
	_set_move(h, c["loc"])
	_narrate(h)

func _work_action(h: Hero) -> void:
	if h.act.is_empty():
		_start_activity(h)
		return
	var a: Dictionary = h.act
	if not _at_target(h):
		return  # still travelling
	match a["phase"]:
		"goto":
			# arrival: either begin working, or resolve a chained step (sell/cook/sellfood)
			match a.get("then", ""):
				"sell":
					var g := economy.sell_goods(h)
					if g > 0:
						log_event("%s sold goods for %dg." % [h.hero_name, g], "gold")
					h.act = {}
					return
				"cook":
					var cooked := 0
					while int(h.inv.get("raw_fish", 0)) > 0:
						h.inv["raw_fish"] = int(h.inv["raw_fish"]) - 1
						h.inv["cooked_fish"] = int(h.inv.get("cooked_fish", 0)) + 1
						_grant_xp(h, "cooking", 6)
						cooked += 1
					a["phase"] = "goto"
					a["target"] = "shop"
					a["then"] = "sellfood"
					_set_move(h, "shop")
					_narrate(h)
					return
				"sellfood":
					var pay := economy.sell_food(h, 0)
					if pay > 0:
						log_event("%s cooked & sold food (+%dg)." % [h.hero_name, pay], "gold")
					h.act = {}
					return
				_:
					# arrived at the resource node → begin gathering / fishing
					a["phase"] = "fish" if a["intent"] == "PROVISION" else "gather"
					_narrate(h)
		"gather":
			h.inv[a["res"]] = int(h.inv.get(a["res"], 0)) + 1
			_grant_xp(h, a["skill"], 8)
			if int(h.inv[a["res"]]) >= 14 or h.inv_count() >= 27:
				a["phase"] = "goto"
				a["target"] = "shop"
				a["then"] = "sell"
				_set_move(h, "shop")
				_narrate(h)
		"fish":
			h.inv["raw_fish"] = int(h.inv.get("raw_fish", 0)) + 1
			_grant_xp(h, "fishing", 8)
			if int(h.inv["raw_fish"]) >= 8:
				a["phase"] = "goto"
				a["target"] = "range"
				a["then"] = "cook"
				_set_move(h, "range")
				_narrate(h)

func _grant_xp(h: Hero, skill: String, base_amount: int) -> void:
	var new_level := h.add_xp(skill, int(round(base_amount * Config.XP_RATE)))
	if new_level > 0 and (new_level % 5 == 0 or new_level >= 20):
		log_event("%s reached %s %d!" % [h.hero_name, _cap(skill), new_level], "lv")

# ---------------------------------------------------------------------------
# Offline catch-up (GDD §4 / EQUATIONS §3) — the statistical resolution path.
# Projects each hero's CURRENT activity forward over elapsed time. No deaths/events offline.
func offline_catchup(elapsed_hours: float) -> Dictionary:
	var dt_hours := minf(elapsed_hours, Config.OFFLINE_CAP_HOURS)
	var summary := {"hours": dt_hours, "gold": 0, "xp": 0}
	for h in heroes:
		var intent: String = h.act.get("intent", "")
		if not Activities.is_gather(intent):
			continue
		var y := Activities.expected_yield_per_hour(h, economy, intent)
		var gold_gain := int(round(y["gold"] * dt_hours * Config.OFFLINE_RATE))
		var xp_gain := int(round(y["xp"] * dt_hours * Config.OFFLINE_RATE))
		h.gold += gold_gain
		h.add_xp(Activities.skill_of(intent), xp_gain)
		summary["gold"] += gold_gain
		summary["xp"] += xp_gain
	log_event("While you were away (%.1fh): the colony earned %dg." % [dt_hours, summary["gold"]], "gold")
	return summary

# ---------------------------------------------------------------------------
# Thoughts (legibility, §20) + chronicle (§17)
func _narrate(h: Hero) -> void:
	var a: Dictionary = h.act
	if a.is_empty():
		h.thought = "Deciding what to do next…"
		return
	var phase: String = a.get("phase", "")
	var then: String = a.get("then", "")
	if phase == "goto" and then == "sell":
		h.thought = "Inventory full — off to the Market to sell."
	elif phase == "goto" and then == "cook":
		h.thought = "Carrying fish to the Range to cook."
	elif phase == "goto" and then == "sellfood":
		h.thought = "Taking fresh food to the Market."
	elif phase == "goto":
		var what := {"GATHER_ORE": "ore", "GATHER_LOGS": "logs", "PROVISION": "fish"}.get(a["intent"], "work")
		h.thought = "Heading out for %s." % what
	elif phase == "gather":
		h.thought = "%s — %d so far." % ["Mining ore" if a["skill"] == "mining" else "Chopping logs", int(h.inv.get(a["res"], 0))]
	elif phase == "fish":
		h.thought = "Fishing — %d caught." % int(h.inv.get("raw_fish", 0))

func log_event(text: String, cls: String = "") -> void:
	var stamp := "D%d %02d:%02d" % [sim_day, int(sim_clock / 60.0) % 24, int(sim_clock) % 60]
	chronicle.push_front({"text": text, "cls": cls, "t": stamp})
	if chronicle.size() > 60:
		chronicle.pop_back()

func total_gold() -> int:
	var g := 0.0
	for h in heroes:
		g += h.gold
	return int(round(g))

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
