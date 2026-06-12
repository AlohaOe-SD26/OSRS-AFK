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
const GATHER_SKILLS := ["mining", "woodcutting", "fishing", "cooking", "smithing",
	"attack", "strength", "defence", "hitpoints", "ranged", "magic"]

## The combat skill a hero's STYLE trains (M3b): swords→strength, bows→ranged, staves→magic.
static func style_skill(h: Hero) -> String:
	return {"sword": "strength", "bow": "ranged", "staff": "magic"}.get(h.weapon, "strength")

var content: ContentDB
var economy: Economy
var population: Population          # reputation / immigration / departures (§16, step 3)
var social = null                  # Social relationship graph (sub-step 3); null-safe until wired
var rng: Rng
var telemetry                      # Telemetry (set by owner after construction)
var _next_id: int = 0              # monotonic hero id source (founders + immigrants)
var _name_counts: Dictionary = {}  # base name -> times used, so repeats become "Bjorn II" (unique display)

var heroes: Array = []             # Array[Hero]
var monsters: Array = []           # Array[MonsterInstance] — live combat targets (§10)
var locations: Dictionary = {}     # loc_key -> { pos: Vector2, kind, label }
var grid_size: int = 18            # legacy max-dimension (kept for back-compat)
var grid_w: int = 18               # rectangular world grid (canon Varrock map is 46×34)
var grid_h: int = 18

var chronicle: Array = []          # newest-first event log (§17), capped
var paused: bool = false

# ---- player control & tycoon layer (§2 / §18.4 / §19, Step 4) ----
# Tier-1 Incentivize: intent -> utility weight added to that activity's brain score (read by Brain).
# Empty by default → the brain behaves exactly as before (zero behavior change until the player posts one).
var incentives: Dictionary = {}
# Player-placed buildings (§19.3): each { kind, name, rep, sat, upkeep }. Empty by default → no upkeep
# sink and no rep/satisfaction bonus, so every Step-0..3 test stays byte-identical until the player builds.
var buildings: Array = []
# Civic kick-vote bookkeeping (§16.2, Step 5): target_id -> { failed: int, cooldown_until: float (sim_total) }.
var kick_records: Dictionary = {}
# Chronicle de-dup (§17, Step 5): "a<b" pair key -> the strongest tier already announced for that pair, so a
# forming alliance / nemesis is narrated ONCE (not every pass it stays at that tier).
var _announced_bonds: Dictionary = {}

# clock / counters
var sim_day: int = 1
var sim_clock: float = 0.0         # minutes within the current day (0..1440)
var sim_total: float = 0.0         # total sim-minutes elapsed
var action_n: int = 0              # work-actions executed
var deaths: int = 0    # actual deaths (HP→0)
var flees: int = 0     # disengaged starving (out of food) — distinct from a death (HANDOFF §8)
var total_kills: int = 0

# Phase-0 combat placeholders — a notional starter weapon's gear bonuses (real game: from equipped
# gear, §12). Kept as named constants so combat reads against the canon Combat.gd math.
const GEAR_ATT_BONUS: int = 10
const GEAR_STR_BONUS: int = 5
const MONSTER_RESPAWN_S: float = 8.0
const MONSTER_RETALIATE_CHANCE: float = 0.55

var _work_acc: float = 0.0
# static vars (not const) — initializers reference another class's consts, evaluated at load
static var _ACTION_SECONDS: float = Config.WORK_TICKS_PER_ACTION * Config.TICK
static var _DD_PER_ACTION: float = Config.SIM_MINUTES_PER_TICK / 1440.0

# ---------------------------------------------------------------------------
func setup(content_db: ContentDB, hero_count: int = 6, seed_value: int = Config.DEFAULT_SEED) -> void:
	content = content_db
	rng = Rng.new(seed_value)
	economy = Economy.new()
	population = Population.new()
	social = Social.new()
	_load_locations()
	heroes.clear()
	for i in range(hero_count):
		heroes.append(_make_hero(i))
	_next_id = hero_count
	_spawn_monsters(4)
	log_event("The colony of Varrock stirs to life. %d adventurers arrive." % hero_count, "lv")

# Monster CAMPS (zones slice 1): the canon map's wild spots each host a roster monster. Dark wizards
# hit for 3 and are weak to RANGED — real danger + the combat triangle's first live use.
const CAMPS: Array = [
	{"loc": "combat", "mon": "rat", "n": 4},
	{"loc": "farm_s", "mon": "chicken", "n": 3},
	{"loc": "cow_field", "mon": "cow", "n": 3},
	{"loc": "stone_circle", "mon": "dark_wizard", "n": 3},   # weak RANGED
	{"loc": "longhall", "mon": "barbarian", "n": 3},          # weak MAGIC — triangle coverage complete
	{"loc": "forest", "mon": "goblin", "n": 3},               # goblins harass the willows (shared workplace)
]

func _spawn_monsters(_n: int) -> void:
	monsters.clear()
	for c in CAMPS:
		var mt: Monster = content.monster(String(c["mon"]))
		if mt == null:
			continue
		for i in range(int(c["n"])):
			var mi := MonsterInstance.from_type(mt, _combat_scatter(String(c["loc"])))
			mi.camp = String(c["loc"])
			monsters.append(mi)

func _combat_scatter(camp_loc: String = "combat") -> Vector2:
	var c: Vector2 = location_tile(camp_loc)
	return c + Vector2(rng.randf_range(-1.7, 1.7), rng.randf_range(-1.7, 1.7))

func _load_locations() -> void:
	var md: Dictionary = content.map_data
	grid_size = int(md.get("gridSize", 18))
	grid_w = int(md.get("gridW", grid_size))
	grid_h = int(md.get("gridH", grid_size))
	var locs: Dictionary = md.get("locations", {})
	for key in locs:
		var l: Dictionary = locs[key]
		locations[key] = {
			"pos": Vector2(float(l.get("x", 0)), float(l.get("y", 0))),
			"kind": l.get("kind", "build"),
			"label": l.get("label", key),
		}

func _make_hero(i: int) -> Hero:
	# Phase-0 founder favorites span gathering AND fighting → the Fisher→Cook→Warrior loop (§9)
	# closes: fighters buy food from cooks, the food sink that pulls gold back toward the tune.
	var favs := ["mining", "woodcutting", "fishing", "fishing", "fighting", "fighting"]
	return _new_hero(i, favs[i % favs.size()], "Founder", 0, 20)

## Shared hero constructor (founders + immigrants). `tier_boost` adds head-start levels on top of
## the role baseline (a higher rarity tier = a more accomplished arrival, §16.1). RNG draw order
## (traits ×6, then pos ×2) is preserved from the original so seeded runs stay deterministic.
func _new_hero(id: int, favorite: String, tier_name: String, tier_boost: int, start_gold: int) -> Hero:
	var h := Hero.new()
	h.id = id
	h.hero_name = _unique_name(NAMES[id % NAMES.size()])
	h.favorite = favorite
	h.secondary = "cooking" if favorite == "fishing" else ""
	h.tier = tier_name
	h.skin = SKIN[id % SKIN.size()]
	h.hair = HAIR[id % HAIR.size()]
	h.shirt = SHIRT[id % SHIRT.size()]
	for s in GATHER_SKILLS:
		h.skills[s] = {"level": 1, "xp": 0}
	h.skills["hitpoints"] = {"level": 10, "xp": XpTables.xp_for_level(10)}
	# role head-start (legible from the first minute) + rarity-tier bonus on top
	if favorite == "fighting":
		_boost(h, "attack", 8 + tier_boost)
		_boost(h, "strength", 8 + tier_boost)
		var st: String = ["sword", "bow", "staff"][id % 3]   # weapon set below; boost the matching style skill
		if st == "bow":
			_boost(h, "ranged", 8 + tier_boost)
		elif st == "staff":
			_boost(h, "magic", 8 + tier_boost)
		_boost(h, "defence", 6 + tier_boost)
		_boost(h, "hitpoints", 12 + tier_boost)
	else:
		_boost(h, favorite, 6 + tier_boost)
		if favorite == "fishing":
			_boost(h, "cooking", 5 + tier_boost)
	h.hp = h.max_hp()
	h.gold = start_gold
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
	h.weapon = ["sword", "bow", "staff"][id % 3]   # deterministic (id-based, no RNG draw)
	# spawn loadout = ONLY the favorite's item: fighters get their weapon; skillers get their tool
	if favorite == "fighting":
		h.equipped = {"main": {"sword": "Bronze sword", "bow": "Shortbow", "staff": "Apprentice staff"}[h.weapon]}
		if h.weapon == "bow":
			h.inv["Arrows"] = 60   # ranged/magic styles consume supplies (melee doesn't — RS-like)
		elif h.weapon == "staff":
			h.inv["Runes"] = 60
	elif Config.TOOL_FOR.has(favorite):
		h.inv[Config.TOOL_FOR[favorite]] = 1
	h.backstory = _make_backstory(h)   # deterministic (no rng draw) — must not perturb the seed stream
	return h

## Generated one-line saga backstory (§17/§20). Derived ONLY from already-set fields (tier, favorite,
## dominant trait) — no RNG, so it can't shift the deterministic draw order the tests/sweeps depend on.
const _ARCHETYPE := {"mining": "prospector", "woodcutting": "woodsman", "fishing": "angler",
	"cooking": "cook", "fighting": "brawler"}
const _TRAIT_FLAVOR := {"greed": "chasing a fortune", "ambition": "hungry for glory",
	"risk": "with a reckless streak", "sociability": "and a friend to everyone",
	"patience": "patient and methodical", "loyalty": "loyal to Varrock to the bone"}
func _make_backstory(h: Hero) -> String:
	var arch: String = _ARCHETYPE.get(h.favorite, "adventurer")
	var dom := ""
	var best := -1.0
	for t in h.traits:
		if float(h.traits[t]) > best:
			best = float(h.traits[t])
			dom = t
	var flavor: String = _TRAIT_FLAVOR.get(dom, "seeking their fortune")
	var origin := "A founding settler" if h.tier == "Founder" else "Arrived as a %s" % h.tier
	return "%s — a born %s, %s." % [origin, arch, flavor]

## Unique display name: the Nth hero to draw a given base name becomes "Name", "Name II", "Name III"…
## (12 names for up to 50 heroes → repeats are guaranteed; collisions read as bugs in the Chronicle).
func _unique_name(base: String) -> String:
	var n: int = int(_name_counts.get(base, 0)) + 1
	_name_counts[base] = n
	return base if n == 1 else "%s %s" % [base, _roman(n)]

const _ROMAN := ["", "", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX"]
static func _roman(n: int) -> String:
	return _ROMAN[n] if n < _ROMAN.size() else str(n)

func _boost(h: Hero, skill: String, level: int) -> void:
	h.skills[skill] = {"level": level, "xp": XpTables.xp_for_level(level)}

## Immigration arrival (§16.1) — called by Population once an applicant is admitted. Builds an
## immigrant with a random favorite + the rolled rarity tier's head-start/gold, appends, logs.
func spawn_immigrant(tier: Dictionary) -> Hero:
	var h := _new_hero(_next_id, _rand_favorite(), tier["name"], int(tier["boost"]), int(tier["gold"]))
	_next_id += 1
	heroes.append(h)
	log_event("%s the %s arrives in Varrock." % [h.hero_name, tier["name"]], "lv")
	return h

func _rand_favorite() -> String:
	var pool := ["mining", "woodcutting", "fishing", "fishing", "fighting", "fighting"]
	return pool[rng.randi_range(0, pool.size() - 1)]

## Voluntary departure (§16.1 capacity valve) — frees a slot. Removes the hero and its social
## edges; the render layer reads world.heroes so a departed hero simply stops being drawn.
func depart_hero(h: Hero) -> void:
	heroes.erase(h)
	if social != null:
		social.drop_node(h.id)
	log_event("%s left Varrock — discontent (satisfaction %d)." % [h.hero_name, int(h.satisfaction)], "die")

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

## Live rat count (§10) — the scarce combat resource; the social pass uses it to detect when the pit is
## over-fished (more fighters than rats → competition friction).
func alive_monster_count() -> int:
	var c := 0
	for r in monsters:
		if r.alive:
			c += 1
	return c

## Live monsters at one camp — the per-camp scarce resource (social friction + offline pit ceilings).
func alive_monster_count_at(loc: String) -> int:
	var c := 0
	for r in monsters:
		if r.alive and r.camp == loc:
			c += 1
	return c

# ---------------------------------------------------------------------------
# PLAYER CONTROL TIERS (GDD §2 / §18.4) — the Step-4 keystone. All three act on the SAME utility
# brain / activity systems the heroes use autonomously (the dual-agency invariant, HANDOFF §5).

## Tier-1 INCENTIVIZE: post a bounty / standing priority on an activity. Adds `weight` utility to that
## intent in every hero's scoring (Brain._incentive) → the brain reorients organically, no commands.
## `step` multiples of Config.INCENTIVE_STEP are the natural UI unit; clamped so it can't crowd out
## survival entirely. weight 0 (or clear_incentive) removes it.
func set_incentive(intent: String, weight: float) -> void:
	var w: float = clampf(weight, 0.0, Config.INCENTIVE_MAX)
	if w <= 0.0:
		incentives.erase(intent)
	else:
		incentives[intent] = w

func clear_incentive(intent: String) -> void:
	incentives.erase(intent)

func clear_all_incentives() -> void:
	incentives.clear()

## Tier-2 NUDGE: inject a one-off activity that wins the hero's next decision, then it resumes autonomy.
## Interrupts the current trip (clears act → immediate re-decide) so the response is visible at once.
## Ignored for a seized hero (seize already gives you direct control — use command_seized there).
func nudge_hero(h: Hero, intent: String) -> bool:
	if h.seized:
		return false
	var head := _intent_head(intent)
	if head.is_empty():
		return false
	h.nudge = head
	h.act = {}                                   # drop the current trip → re-decide now; the nudge wins
	h.thought = "Heeding your nudge — %s." % _intent_phrase(intent)
	log_event("You nudge %s to %s." % [h.hero_name, _intent_phrase(intent)], "lv")
	return true

## Tier-3 SEIZE: suspend the hero's brain (it stops auto-deciding) and take direct control.
func seize_hero(h: Hero) -> void:
	h.seized = true
	h.act = {}
	h.nudge = {}
	h.thought = "Seized — awaiting your command."
	log_event("You seize direct control of %s." % h.hero_name, "lv")

## Release a seized hero back to autonomy — it re-decides on its own next action.
func release_hero(h: Hero) -> void:
	h.seized = false
	h.act = {}
	h.thought = "Released — back to my own judgment."
	log_event("You release %s back to autonomy." % h.hero_name, "lv")

## Issue a direct activity to a SEIZED hero (no-op otherwise). Builds the trip exactly like an
## autonomous decision would; when it completes the hero idles, awaiting the next command (no auto-decide).
func command_seized(h: Hero, intent: String) -> bool:
	if not h.seized:
		return false
	var head := _intent_head(intent)
	if head.is_empty():
		return false
	_apply_choice(h, head)
	return true

## Resolve an intent string into the head fields of an activity ({intent,loc,skill,res}) — shared by
## nudge & seize so a player command builds the same activity the brain would. Empty = unknown intent.
static func _intent_head(intent: String) -> Dictionary:
	if Activities.is_gather(intent):
		return {"intent": intent, "loc": Activities.location_of(intent),
			"skill": Activities.skill_of(intent), "res": Activities.resource_of(intent)}
	elif intent == "FIGHT":
		return {"intent": "FIGHT", "loc": "combat", "skill": "strength", "res": ""}
	elif intent == "REGROUP":
		return {"intent": "REGROUP", "loc": "shop", "skill": "", "res": ""}
	return {}

static func _intent_phrase(intent: String) -> String:
	match intent:
		"GATHER_ORE": return "mine ore"
		"GATHER_LOGS": return "chop logs"
		"PROVISION": return "fish & cook"
		"FIGHT": return "fight at the Rat Pit"
		"REGROUP": return "head to town"
	return intent

# ---------------------------------------------------------------------------
# TOWN BUILDING / UPGRADES (GDD §19) — the tycoon layer. Funded by the treasury (the GE-tax skim);
# reputation/satisfaction bonuses feed Population (§16/§19.4); upkeep is the §6 continuous sink.

## Invest treasury to level a shop (§19.2). Returns true on success. See Economy.try_upgrade_shop.
func upgrade_shop(s: Shop) -> bool:
	var cost := economy.shop_upgrade_cost(s)
	if economy.try_upgrade_shop(s):
		log_event("You invest %dg — %s reaches Level %d." % [cost, s.shop_name, s.level], "gold")
		return true
	return false

## Build a player-placed structure (§19.3) from the catalog. Debits the treasury; the building then
## contributes reputation + per-hero satisfaction and draws a daily upkeep (the tycoon tension, §19.4).
func build(kind: String) -> bool:
	var spec: Dictionary = Config.BUILDINGS.get(kind, {})
	if spec.is_empty():
		return false
	var cost: float = float(spec["cost"])
	if economy.treasury < cost:
		return false
	economy.treasury -= cost
	buildings.append({"kind": kind, "name": spec["name"], "rep": float(spec["rep"]),
		"sat": float(spec["sat"]), "upkeep": float(spec["upkeep"])})
	log_event("Built a %s (−%dg). Varrock grows." % [spec["name"], int(cost)], "lv")
	if population != null:
		population.update_reputation(self)   # reflect the new draw immediately
	return true

## Total reputation contributed by player buildings (§19.4) — read by Population.update_reputation.
func town_reputation_bonus() -> float:
	var r := 0.0
	for b in buildings:
		r += float(b["rep"])
	return r

## Total per-hero satisfaction contributed by amenities (§19.4) — read by Population.compute_satisfaction.
func town_satisfaction_bonus() -> float:
	var s := 0.0
	for b in buildings:
		s += float(b["sat"])
	return s

## Daily building upkeep — the §6 continuous treasury sink (the reason you can't over-build). Called
## on day rollover. No-op until the player builds something, so the validated runs are untouched.
func _town_daily() -> void:
	var upkeep := 0.0
	for b in buildings:
		upkeep += float(b["upkeep"])
	if upkeep > 0.0:
		economy.treasury -= upkeep   # may go negative (a deficit blocks new builds until tax refills it)

# ---------------------------------------------------------------------------
# CIVIC KICK VOTES (GDD §16.2) — the colony's self-governance + the player's failsafe. God initiates a
# vote; the eligible electorate casts relationship-and-value-weighted ballots; quorum + majority decide.
# A FAILED vote leaves the target resentful of the yes-voters (§9 deltas) → this is the civic rivalry source.

## Eligible voters (§16.2): everyone but the target who is present + NOT actively working (in a
## gather/fish/fight phase). Travelling / transacting / idle heroes are "available to participate".
## Seized heroes are under direct control → not free to vote.
func eligible_voters(target: Hero) -> Array:
	var out: Array = []
	for h in heroes:
		if h == target or h.seized:
			continue
		var phase: String = h.act.get("phase", "")
		if phase == "gather" or phase == "fish" or phase == "fight":
			continue   # busy at a work node
		out.append(h)
	return out

## A voter's P(yes) (§16.2): shaped by their relationship TO the target (friends defend → low; nemeses
## pile on → high) and the target's value-to-town (don't exile the strong). Clamped off 0/1.
func _vote_yes_prob(voter: Hero, target: Hero) -> float:
	var rel := 0.0
	if social != null:
		rel = social.get_r(voter.id, target.id, sim_day)   # voter → target
	var cl := XpTables.combat_level(target.skill_level("attack"), target.skill_level("strength"),
		target.skill_level("defence"), target.skill_level("hitpoints"), 1, 1, 1)
	var value_norm: float = clampf(float(cl) / Config.KICK_VALUE_REF, 0.0, 1.0)
	var p: float = Config.KICK_BASE_YES - Config.KICK_REL_WEIGHT * (rel / 100.0) - Config.KICK_VALUE_WEIGHT * value_norm
	return clampf(p, 0.05, 0.95)

## God initiates a kick vote (§16.2). Returns a result dict { outcome, yes, no, eligible, quorum_needed }.
## outcome ∈ "cooldown" | "void" (sub-quorum, does NOT consume an attempt) | "fail" | "pass".
func start_kick_vote(target: Hero) -> Dictionary:
	var rec: Dictionary = kick_records.get(target.id, {"failed": 0, "cooldown_until": 0.0})
	if sim_total < float(rec["cooldown_until"]):
		return {"outcome": "cooldown", "yes": 0, "no": 0, "eligible": 0}
	var voters := eligible_voters(target)
	var quorum_needed: int = int(ceil(Config.KICK_QUORUM_FRAC * float(heroes.size())))
	if voters.size() < quorum_needed:
		log_event("A vote to exile %s failed to reach quorum (%d/%d present)." % [target.hero_name, voters.size(), quorum_needed], "vote")
		return {"outcome": "void", "yes": 0, "no": 0, "eligible": voters.size(), "quorum_needed": quorum_needed}
	var yes := 0
	var no := 0
	for v: Hero in voters:
		var voted_yes := rng.chance(_vote_yes_prob(v, target))
		if voted_yes:
			yes += 1
		else:
			no += 1
		if social != null:
			social.record_vote(target.id, v.id, voted_yes, sim_day)   # target resents yes-voters, warms to defenders
	var passed := float(yes) > Config.KICK_PASS_FRAC * float(yes + no)
	if passed:
		log_event("The colony votes to EXILE %s (%d–%d)." % [target.hero_name, yes, no], "vote")
		_exile_hero(target, false)
		kick_records.erase(target.id)
		return {"outcome": "pass", "yes": yes, "no": no, "eligible": voters.size()}
	rec["failed"] = int(rec["failed"]) + 1
	rec["cooldown_until"] = sim_total + Config.KICK_COOLDOWN_DAYS * 1440.0
	kick_records[target.id] = rec
	log_event("A vote to exile %s FAILS (%d–%d). %d failed so far." % [target.hero_name, yes, no, int(rec["failed"])], "vote")
	return {"outcome": "fail", "yes": yes, "no": no, "eligible": voters.size(), "failed": int(rec["failed"])}

## True once the failsafe is unlocked (§16.2): the god may force-kick after KICK_FORCE_AFTER failed votes.
func can_force_kick(target: Hero) -> bool:
	return int(kick_records.get(target.id, {}).get("failed", 0)) >= Config.KICK_FORCE_AFTER

## God failsafe (§16.2): remove the target outright. Intended after KICK_FORCE_AFTER failed votes, but the
## god may always exercise it (it IS the failsafe). `force` skips the failed-count gate (player override).
func force_kick(target: Hero, force: bool = false) -> bool:
	if not force and not can_force_kick(target):
		return false
	log_event("The god force-exiles %s from Varrock." % target.hero_name, "vote")
	_exile_hero(target, true)
	kick_records.erase(target.id)
	return true

## Exile outcome (§16.2) — removed from town (NOT deleted), social edges dropped, reputation dented like a
## kick. Wilderness-monster-return / re-application weighting is post-MVP; logged as a banishment event.
func _exile_hero(target: Hero, forced: bool) -> void:
	heroes.erase(target)
	if social != null:
		social.drop_node(target.id)
	if population != null:
		population.recent_kicks += 1.0   # §8 reputation penalty window (decays)
	log_event("%s is banished from Varrock%s." % [target.hero_name, " by decree" if forced else ""], "exile")

# ---------------------------------------------------------------------------
# Main deterministic step. dt = elapsed seconds (scaled by the caller's speed control).
func tick(dt: float) -> void:
	if paused:
		return
	for h in heroes:
		_move_step(h, dt)
	_tick_monsters(dt)
	_work_acc += dt
	while _work_acc >= _ACTION_SECONDS:
		_work_acc -= _ACTION_SECONDS
		var prev_day := sim_day
		_advance_clock()
		for h in heroes:
			_work_action(h)
		economy.economy_tick(_DD_PER_ACTION, heroes)
		if social != null:
			social.tick(self, _DD_PER_ACTION)
		if population != null:
			population.step(self, _DD_PER_ACTION)
			if sim_day != prev_day:
				population.daily(self)
		if sim_day != prev_day:
			_town_daily()   # building upkeep — the §6 continuous treasury sink (no-op until built)
			_chronicle_social_daily()   # narrate new friendships/rivalries into the Chronicle (§17)
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
	# heroes pick a personal SPOT within the area, not the exact node point — work sites read as a
	# scattered crew (wide at gather/combat areas, tight at town counters). Seeded rng → deterministic.
	var spread := 1.4 if (loc_key == "mine" or loc_key == "forest" or loc_key == "fishing" or loc_key == "combat") else 0.5
	var jittered := location_tile(loc_key) + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
	# never aim INTO water/walls — fall back to the node tile itself (rng draw order preserved)
	h.move_target = jittered if not _tile_blocked(jittered) else location_tile(loc_key)

func _at_target(h: Hero) -> bool:
	return h.move_target == null or h.pos.distance_to(h.move_target) < 0.18

func _move_step(h: Hero, dt: float) -> void:
	# run energy: drains while actually running, regenerates otherwise (deterministic, dt-driven)
	var moving: bool = h.move_target != null and h.pos.distance_to(h.move_target) >= 0.05
	if h.run_on and moving and h.run_energy > 0.0:
		h.run_energy = maxf(0.0, h.run_energy - 7.0 * dt)
		# autonomous run ends at its rolled stop level (seized heroes: player toggles manually)
		if not h.seized and h.run_energy <= h.run_stop_at:
			h.run_on = false
	else:
		h.run_energy = minf(100.0, h.run_energy + 4.0 * dt)
	if not h.run_on and h.run_cd_left > 0.0:
		h.run_cd_left = maxf(0.0, h.run_cd_left - dt)   # cooldown ticks only after the run ends
	if h.move_target == null:
		return
	var goal: Vector2 = h.move_target
	# (re)build the BFS path when the target changed; clear-line trips skip pathfinding entirely
	if h.path_goal == null or (h.path_goal as Vector2).distance_to(goal) > 0.01:
		_build_path(h, goal)
	var target := goal
	while h.path.size() > 0:
		if h.pos.distance_to(h.path[0]) < 0.35:
			h.path.pop_front()
			continue
		target = h.path[0]
		break
	var d := h.pos.distance_to(target)
	if d < 0.05:
		return
	var step := Config.MOVE_SPEED * dt * (1.8 if (h.run_on and h.run_energy > 0.0) else 1.0)
	var k := minf(1.0, step / d)
	var nxt: Vector2 = h.pos + (target - h.pos) * k
	# HARD COLLISION (the safety net under the pathing): water and walls cannot be entered, ever.
	if _tile_blocked(nxt):
		var sx := Vector2(nxt.x, h.pos.y)
		var sy := Vector2(h.pos.x, nxt.y)
		if not _tile_blocked(sx):
			h.pos = sx
		elif not _tile_blocked(sy):
			h.pos = sy
	else:
		h.pos = nxt

## Build h.path: empty if the straight line is clear; else BFS waypoints (tile centers) + the exact goal.
func _build_path(h: Hero, goal: Vector2) -> void:
	h.path_goal = goal
	h.path = []
	if _line_clear(h.pos, goal):
		return
	var pts := _bfs(Vector2i(int(round(h.pos.x)), int(round(h.pos.y))), Vector2i(int(round(goal.x)), int(round(goal.y))))
	for p in pts:
		h.path.append(Vector2(p.x, p.y))
	h.path.append(goal)

func _line_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(ceil(a.distance_to(b) * 2.5)) + 1
	for i in range(1, n + 1):
		if _tile_blocked(a.lerp(b, float(i) / n)):
			return false
	return true

## Deterministic 8-dir BFS over the blocked-tile grid (no corner cutting). Exact: gates and bridges
## are simply the open cells, so paths flow through them naturally. ~1900 cells — cheap per trip.
func _bfs(start: Vector2i, goal: Vector2i) -> Array:
	if _tile_blocked(Vector2(goal.x, goal.y)):
		return []   # target clamping should prevent this; fall back to direct + hard-block
	var came: Dictionary = {start: start}
	var queue: Array = [start]
	var qi := 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while qi < queue.size():
		var cur: Vector2i = queue[qi]
		qi += 1
		if cur == goal:
			break
		for dv: Vector2i in dirs:
			var nb: Vector2i = cur + dv
			if nb.x < 0 or nb.y < 0 or nb.x >= grid_w or nb.y >= grid_h or came.has(nb):
				continue
			if _tile_blocked(Vector2(nb.x, nb.y)):
				continue
			if dv.x != 0 and dv.y != 0:   # diagonal: both orthogonals must be open (no corner cutting)
				if _tile_blocked(Vector2(cur.x + dv.x, cur.y)) or _tile_blocked(Vector2(cur.x, cur.y + dv.y)):
					continue
			came[nb] = cur
			queue.append(nb)
	if not came.has(goal):
		return []
	var path: Array = []
	var node: Vector2i = goal
	while node != start:
		path.push_front(node)
		node = came[node]
	# light smoothing: drop waypoints reachable on a clear straight line from the start
	while path.size() >= 2 and _line_clear(Vector2(start.x, start.y), Vector2(path[1].x, path[1].y)):
		path.pop_front()
	return path

# --- world collision (mirrors map.json terrain; the sim's physical truth) -------------------------
# River: vertical arm x10..11/y4..24 (bridge y12) + south belt y25..26/x10..49 (bridges x26/31/45).
# City wall: ring of rect 16..38 × 3..21, passable ONLY at the gates (N x20-22 · W y11-13 · S x25-27 · E y11-13).
func _tile_blocked(p: Vector2) -> bool:
	var x := int(round(p.x))
	var y := int(round(p.y))
	if (x >= 10 and x <= 11 and y >= 4 and y <= 24) or (x >= 10 and x <= 49 and y >= 25 and y <= 26):
		if not ((y == 12 and x >= 10 and x <= 11) or ((x == 26 or x == 31 or x == 45) and y >= 25 and y <= 26)):
			return true   # water, no bridge
	var on_we := (x == 16 or x == 38) and y >= 3 and y <= 21
	var on_ns := (y == 3 or y == 21) and x >= 16 and x <= 38
	if on_we and y >= 11 and y <= 13:
		return false      # west/east gates
	if on_ns and y == 3 and x >= 20 and x <= 22:
		return false      # north gate
	if on_ns and y == 21 and x >= 25 and x <= 27:
		return false      # south gate
	return (on_we or on_ns) and WALLS_SOLID

# Walls SOLID — exact grid-BFS pathfinding replaced the failed heuristic waypoint routing (which
# stalled heroes at successive seams). Gates/bridges are simply open cells; BFS flows through them.
const WALLS_SOLID := true

func _inside_city(p: Vector2) -> bool:
	return p.x > 16.4 and p.x < 37.6 and p.y > 3.4 and p.y < 20.6

const _GATES := [Vector2(21, 3), Vector2(16, 12), Vector2(26, 21), Vector2(38, 12)]

## Stateless waypoint routing: crossing the city wall goes via the nearest GATE; crossing either
## river arm goes via its BRIDGE. Computed fresh each step — no stored path, determinism untouched.
func _route(from: Vector2, to: Vector2) -> Vector2:
	var fin := _inside_city(from)
	var tin := _inside_city(to)
	# crossing the wall (either direction), or an outside→outside line that would chord THROUGH the
	# city footprint: go via the best GATE (minimizing the whole journey, not just the nearest gate)
	if WALLS_SOLID and (fin != tin or (not fin and not tin and _seg_crosses_city(from, to))):
		var g: Vector2 = _GATES[0]
		var best := from.distance_to(g) + g.distance_to(to)
		for cand: Vector2 in _GATES:
			var c := from.distance_to(cand) + cand.distance_to(to)
			if c < best:
				best = c
				g = cand
		if from.distance_to(g) > 1.1:
			return _route_river(from, g)   # head to the gate first (river-aware leg)
		# at the gate: push THROUGH the gap to the far side before resuming — releasing straight to the
		# final target here let the line clip the ring beside the gap (the West-Bank stuck spot)
		# push direction = AWAY from where the hero came from (continuing through), NOT toward the
		# target's side — a target west of the East Gate pushed heroes back inside (the fisher orbit)
		if g.y == 3.0 or g.y == 21.0:      # north/south gates pass vertically
			return Vector2(g.x, g.y + (2.2 if from.y < g.y else -2.2))
		return Vector2(g.x + (2.2 if from.x < g.x else -2.2), g.y)
	return _route_river(from, to)

## Conservative test: does the straight segment pass over the city rect (16..38 × 3..21)?
func _seg_crosses_city(a: Vector2, b: Vector2) -> bool:
	if maxf(a.x, b.x) < 16.0 or minf(a.x, b.x) > 38.0 or maxf(a.y, b.y) < 3.0 or minf(a.y, b.y) > 21.0:
		return false
	# sample the segment — cheap and good enough at these scales
	for i in range(1, 8):
		var p := a.lerp(b, i / 8.0)
		# deep-interior test only — corner-grazing chords slide around the ring instead of being
		# forced back to a gate (which ping-ponged heroes at the SE corner)
		if p.x > 17.6 and p.x < 36.4 and p.y > 4.6 and p.y < 19.4:
			return true
	return false

func _route_river(from: Vector2, to: Vector2) -> Vector2:
	# south belt (y 25..26)
	if (from.y < 24.6) != (to.y < 24.6):
		var bx := 26.0
		for cand in [31.0, 45.0]:
			if absf(from.x - cand) < absf(from.x - bx):
				bx = cand
		if absf(from.x - bx) > 0.45:
			return Vector2(bx, from.y)
		return Vector2(bx, 27.4 if from.y < 24.6 else 23.6)
	# vertical arm (x 10..11, y 4..24) — bridge at y 12
	if (from.x < 9.6) != (to.x < 9.6) and (from.y < 24.6 or to.y < 24.6):
		if absf(from.y - 12.0) > 0.45:
			return Vector2(from.x, 12.0)
		return Vector2(8.4 if from.x > 9.6 else 12.6, 12.0)
	return to

# ---------------------------------------------------------------------------
# Monsters (§10): idle wander + respawn. Continuous (dt-based), like hero movement.
func _tick_monsters(dt: float) -> void:
	for r: MonsterInstance in monsters:
		if not r.alive:
			r.respawn -= dt
			if r.respawn <= 0.0:
				_respawn_monster(r)
			continue
		r.wander -= dt
		if r.wander <= 0.0:
			var c: Vector2 = location_tile(r.camp)
			r.wander = 1.0 + rng.randf() * 2.0
			r.move_target = c + Vector2(rng.randf_range(-1.8, 1.8), rng.randf_range(-1.8, 1.8))
		if r.move_target != null:
			var target: Vector2 = r.move_target
			var d := r.pos.distance_to(target)
			if d > 0.05:
				r.pos += (target - r.pos) * minf(1.0, 0.7 * dt / d)

func _respawn_monster(r: MonsterInstance) -> void:
	var rat: Monster = content.monster(r.type_id)
	if rat != null:
		var fresh := MonsterInstance.from_type(rat, _combat_scatter(r.camp))
		r.type_id = fresh.type_id
		r.hp = fresh.hp
		r.max_hp = fresh.max_hp
		r.defence = fresh.defence
		r.monster_max_hit = fresh.monster_max_hit
		r.pos = fresh.pos
	r.alive = true
	r.respawn = 0.0
	r.wander = 0.0
	r.move_target = null

func _nearest_monster(h: Hero) -> MonsterInstance:
	var best: MonsterInstance = null
	var bd := 1e9
	var camp: String = h.act.get("loc", "combat")
	for r: MonsterInstance in monsters:
		if r.alive and r.camp == camp:
			var d := h.pos.distance_to(r.pos)
			if d < bd:
				bd = d
				best = r
	return best

## M3a: a gear drop — auto-equip if it beats the current piece in that slot (style-matched for main),
## salvage to coins otherwise (half value; full value if it replaced nothing). Saga-logged on upgrade.
func _gear_drop(h: Hero) -> void:
	var d: Dictionary = Config.GEAR_DROPS[rng.randi_range(0, Config.GEAR_DROPS.size() - 1)]
	var slot := String(d["slot"])
	var style := String(d["style"])
	if style != "" and style != h.weapon:
		h.gold += float(d["value"]) * 0.5   # wrong style → salvage
		return
	var cur_tier := int(Config.GEAR_TIER.get(h.equipped.get(slot, ""), 0))
	var new_tier := int(Config.GEAR_TIER.get(d["item"], 0))
	if new_tier > cur_tier:
		if h.equipped.has(slot):
			h.gold += 8.0   # salvage the old piece (flat scrap)
		h.equipped[slot] = String(d["item"])
		_milestone(h, "Looted & equipped %s" % String(d["item"]))
		log_event("%s loots a %s — an upgrade!" % [h.hero_name, String(d["item"])], "gold", 2)
	elif h.cargo_count() < 24:
		h.inv[String(d["item"])] = int(h.inv.get(String(d["item"]), 0)) + 1   # CARRIED — sellable/swappable
	else:
		h.gold += float(d["value"]) * 0.5   # no space → salvage

## Nearest living hero other than `h` (used by the dormant gravestone-loot grab). null if alone.
func _nearest_other_hero(h: Hero) -> Hero:
	var best: Hero = null
	var bd := 1.0e9
	for o in heroes:
		if o == h or o.hp <= 0:
			continue
		var d := h.pos.distance_to(o.pos)
		if d < bd:
			bd = d
			best = o
	return best

# One combat exchange (§10): hero attacks (canon rolls), monster retaliates; handles eat/flee,
# kill rewards, and hero death/respawn. Called from _work_action when in the 'fight' phase.
func _fight_round(h: Hero) -> void:
	var r := _nearest_monster(h)
	if r == null:
		h.thought = "Waiting for a foe to appear…"
		return
	# reactive interrupts (§18): eat low, flee if starving
	if h.hp < int(h.max_hp() * Config.EAT_THRESHOLD) and int(h.inv.get("cooked_fish", 0)) > 0:
		h.inv["cooked_fish"] = int(h.inv["cooked_fish"]) - 1
		h.hp = mini(h.max_hp(), h.hp + Config.FOOD_HEAL)
		h.flash = 0.4
	elif h.hp < int(h.max_hp() * Config.FLEE_THRESHOLD) and int(h.inv.get("cooked_fish", 0)) <= 0:
		flees += 1
		log_event("%s flees the Rat Pit — out of food!" % h.hero_name, "die")
		h.act = {}
		_set_move(h, "shop")
		_narrate(h)
		return
	# close to ENGAGE REACH before attacking — style-dependent (M1c): swords close in; bows/staves
	# attack from a reasonable distance (visibly different combat silhouettes at the pit)
	# DRY FALLBACK (instance-#7 fix): out of ammo with no gold to restock → fight UNARMED (canon: you
	# can always punch) at melee reach with no gear bonus — income keeps flowing, the hero recovers,
	# no capital lockout (the probe showed broke+dry fighters thrashing FIGHT→disengage forever).
	var dry: bool = Config.AMMO_ON and h.weapon != "sword" \
		and int(h.inv.get("Arrows" if h.weapon == "bow" else "Runes", 0)) <= 0
	var reach := 0.9
	if not dry:
		if h.weapon == "bow":
			reach = 4.2
		elif h.weapon == "staff":
			reach = 3.2
	if h.pos.distance_to(r.pos) > reach:
		h.move_target = r.pos
		return
	# hero attacks — canon rolls (Combat.gd); GEAR IS REAL (M3b): weapon tier feeds the attack/strength
	# bonuses (tier-1 ≡ the old flat constants, upgrades now matter); armor tiers + shield mitigate.
	var wt := 0 if dry else int(Config.GEAR_TIER.get(h.equipped.get("main", ""), 0))
	# STYLE-CORRECT rolls & XP (M3b): swords roll attack/strength; bows roll & train RANGED;
	# staves roll & train MAGIC. Same canon roll machinery, style-appropriate levels.
	var ss := "strength" if dry else SimWorld.style_skill(h)   # unarmed = melee rolls
	var acc_skill := "attack" if ss == "strength" else ss
	var eff_acc := Combat.effective_level(h.skill_level(acc_skill), 1.0, 0)
	var eff_pow := Combat.effective_level(h.skill_level(ss), 1.0, 0)
	var acc := Combat.hit_chance(Combat.attack_roll(eff_acc, 4 + wt * 6), Combat.defence_roll(r.defence, 0))
	# STYLE TRIANGLE (M3b): attacking into a monster's weakness is rewarded, off-weakness punished.
	# Catalog-driven (monsters.json weaknessStyle); "any" (rats) = neutral ×1.0 — provably no-op today,
	# live the moment zone monsters with real weaknesses arrive.
	var mon: Monster = content.monster(r.type_id)
	if mon != null and mon.weakness_style != "any" and mon.weakness_style != "":
		var style: String = {"strength": "melee", "ranged": "ranged", "magic": "magic"}[ss]
		acc = clampf(acc * (1.25 if style == mon.weakness_style else 0.85), 0.02, 0.99)
	var mh := Combat.max_hit(eff_pow, 1 + wt * 4)
	# ammo/rune consumption (M3b): bows and staves spend 1 per attack; dry → disengage to restock.
	# GATED OFF pending diagnosis: first enable collapsed kills 2631→25 (×100, far beyond the intended
	# supply cost) — cause undiagnosed; needs a dedicated cycle. Plumbing (spawn ammo, buyammo chain) stays.
	var ammo_kind := ("Arrows" if h.weapon == "bow" else ("Runes" if h.weapon == "staff" else "")) if (Config.AMMO_ON and not dry) else ""
	if ammo_kind != "":
		h.inv[ammo_kind] = int(h.inv[ammo_kind]) - 1   # punching (dry) consumes nothing
	var dmg := 0
	if rng.chance(acc):
		dmg = rng.randi_range(0, mh)
		r.hp -= dmg
	if dmg > 0:
		_grant_xp(h, ss, dmg * 4)
		_grant_xp(h, "hitpoints", int(round(dmg * 1.33)))
	# monster retaliates — armor tiers (head/torso) and a shield reduce damage taken
	if rng.chance(MONSTER_RETALIATE_CHANCE):
		var mit := 1.0 - 0.06 * (int(Config.GEAR_TIER.get(h.equipped.get("head", ""), 0)) + int(Config.GEAR_TIER.get(h.equipped.get("torso", ""), 0)))
		if h.equipped.has("off"):
			mit -= 0.12
		var raw := rng.randi_range(0, r.monster_max_hit)
		h.hp -= int(ceil(raw * maxf(0.4, mit)))
	# kill
	if r.hp <= 0:
		r.alive = false
		r.respawn = MONSTER_RESPAWN_S
		total_kills += 1
		h.act["kills"] = int(h.act.get("kills", 0)) + 1   # §18.6 combat-trip progress
		# coin drop from the CATALOG (per-monster ranges; rats keep the re-tuned Config values)
		if mon != null and r.type_id != "rat":
			h.gold += rng.randi_range(mon.coin_drop_min, maxi(mon.coin_drop_min, mon.coin_drop_max))
		else:
			h.gold += rng.randi_range(Config.RAT_DROP_MIN, Config.RAT_DROP_MIN + Config.RAT_DROP_RANGE)
		if rng.chance(Config.GEAR_DROP_CHANCE):
			_gear_drop(h)
		if total_kills % 15 == 0:
			log_event("%s felled a giant rat — %d slain in all." % [h.hero_name, total_kills], "boss", 0)
	# hero death (§14, live-only) — respawn at the bank/shop, drop 10% gold
	if h.hp <= 0:
		deaths += 1
		if population != null:
			population.recent_deaths += 1.0   # dents reputation (§8), decays over the next days
		# §14 gravestone-loot (DORMANT — deaths≈0 at current survival tuning): the dropped gold is grabbed
		# by the nearest fellow at the pit, and the fallen hero resents the looter (§16.3 negative delta).
		# Gold-neutral transfer (was a 10% sink; with deaths≈0 the economy is unaffected — verified).
		var dropped: float = h.gold * 0.1
		var looter := _nearest_other_hero(h)
		if looter != null and dropped >= 1.0:
			looter.gold += dropped
			if social != null:
				social.record_graveloot(h.id, looter.id, sim_day)
			log_event("%s looted %s's grave (+%dg) — a grudge is born." % [looter.hero_name, h.hero_name, int(dropped)], "die")
		h.gold = h.gold - dropped
		log_event("%s was slain by a rat! Respawns shortly." % h.hero_name, "die")
		h.hp = h.max_hp()
		h.act = {}
		h.pos = location_tile("shop")
		_set_move(h, "shop")
		return
	# disengage to re-provision if low on food and hurt
	if int(h.inv.get("cooked_fish", 0)) <= 0 and h.hp < int(h.max_hp() * 0.6):
		h.act = {}
		_set_move(h, "shop")
		_narrate(h)
		return
	# §18.6 trip completion: the combat trip ENDS → re-decide (like a gather trip filling its inventory).
	# TWO paths: (a) N kills (the "good haul" path — unreachable at high congestion); (b) Stage-2 RE-ENTRANT
	# TIMER — after a ROUNDS budget regardless of kills, so a congestion-starved fighter still re-decides on a
	# regular cadence instead of only on food/flee exits. Either path frees the congestion/utility machinery.
	h.act["rounds"] = int(h.act.get("rounds", 0)) + 1
	if int(h.act.get("kills", 0)) >= Config.COMBAT_TRIP_KILLS or int(h.act["rounds"]) >= Config.COMBAT_TRIP_ROUNDS:
		h.act = {}
		_set_move(h, "shop")
		h.thought = "Good haul — back to town to restock and weigh what's worth doing."
		return
	h.thought = "Fighting rats · %d food left." % int(h.inv.get("cooked_fish", 0))

# ---------------------------------------------------------------------------
# The trip FSM (GDD §18.1 Layer 3). Mirrors the validated prototype loop.
## Goal lifecycle (§18.3): complete a met goal (saga + chronicle), then pick a new one — 50% the
## favorite, 50% rotating through the rest (incl. Strength for everyone) → varied, player-like arcs.
func _maybe_pick_goal(h: Hero) -> void:
	if not Config.GOALS_ON:
		return
	if not h.goal.is_empty():
		# a "strength" (combat) goal is satisfied by the hero's STYLE skill (ranged/magic for bow/staff)
		var gs := String(h.goal["skill"])
		var eff := SimWorld.style_skill(h) if gs == "strength" else gs
		if h.skill_level(eff) >= int(h.goal["level"]):
			_milestone(h, "Reached a goal: %s %d" % [SimWorld._cap(String(h.goal["skill"])), int(h.goal["level"])])
			log_event("%s reached a goal — %s %d!" % [h.hero_name, _cap(String(h.goal["skill"])), int(h.goal["level"])], "lv", 2)
			h.goal = {}
		else:
			return
	var pool := ["mining", "woodcutting", "fishing", "cooking", "strength", "smithing"]
	var fav_skill := "strength" if h.favorite == "fighting" else h.favorite
	var skill: String = fav_skill if rng.chance(0.5) else String(pool[rng.randi_range(0, pool.size() - 1)])
	h.goal = {"skill": skill, "level": mini(99, h.skill_level(skill) + rng.randi_range(4, 12))}

func _start_activity(h: Hero) -> void:
	_maybe_pick_goal(h)
	# autonomous RUN roll (skipped while seized — the player drives run manually): only when the
	# cooldown has expired; FAILED rolls re-trigger the cooldown before run can be rolled again.
	if not h.seized and h.run_cd_left <= 0.0:
		if rng.chance(0.45) and h.run_energy > 25.0:
			h.run_on = true
			h.run_stop_at = rng.randf_range(5.0, h.run_energy * 0.7)   # random energy spend
			h.run_cd_left = rng.randf_range(15.0, 120.0)               # cooldown starts when the run ends
		else:
			h.run_cd_left = rng.randf_range(15.0, 120.0)               # failed roll → cooldown anyway
	# score all candidates once → stash the full breakdown for the Hero Panel's Thoughts tab (§20),
	# then take the argmax. Same math the brain uses (candidates carry their own term breakdown).
	var cands := Brain.candidates_with_terms(h, self)
	# Tier-2 Nudge (§18.4): a pending player nudge injects a one-off candidate that dominates THIS
	# decision, then is consumed → the hero resumes full autonomy on its next decision. It still
	# carries an honest score/term so the Thoughts tab shows it winning legibly.
	if not h.nudge.is_empty():
		var n: Dictionary = h.nudge.duplicate()
		n["terms"] = [["nudge", Config.NUDGE_BONUS]]
		n["score"] = Config.NUDGE_BONUS
		cands.append(n)
		h.nudge = {}
	cands.sort_custom(func(a, b): return a["score"] > b["score"])
	h.last_candidates = cands
	h.decisions += 1   # §18.6 cadence telemetry — a decision point was reached
	if cands.is_empty():
		h.act = {}
		h.thought = "Deciding what to do next…"
		return
	_apply_choice(h, _pick_candidate(cands))

## Choose among scored candidates. Default = hard argmax (cands[0]). Stage-2 lever 2: if BRAIN_WEIGHTED_TIES,
## pick WEIGHTED-RANDOM among NEAR-TIES (within BRAIN_TIE_BAND of the top) → breaks the synchronized-herd
## monoculture (deterministic argmax makes every hero re-deciding at the same instant pick the same option).
## Acts at activity-category level (cands are intents). A dominating nudge (+1000) is never in the band → still wins.
func _pick_candidate(cands_desc: Array) -> Dictionary:
	if not Config.BRAIN_WEIGHTED_TIES or cands_desc.size() < 2:
		return cands_desc[0]
	var top: float = float(cands_desc[0]["score"])
	var threshold: float = top - Config.BRAIN_TIE_BAND
	var band: Array = []
	var total := 0.0
	for c in cands_desc:
		if float(c["score"]) >= threshold:
			band.append(c)
			total += float(c["score"]) - threshold + 1.0   # weight ≥ 1 (avoids negative/zero weights)
		else:
			break   # sorted desc → once below the band, all rest are too
	if band.size() < 2:
		return cands_desc[0]
	var r := rng.randf() * total
	var acc := 0.0
	for c in band:
		acc += float(c["score"]) - threshold + 1.0
		if r <= acc:
			return c
	return band[0]

## Set up the trip-FSM act from a chosen candidate (shared by autonomous decisions, nudges, and
## seize-commands so all three build the activity identically).
func _apply_choice(h: Hero, c: Dictionary) -> void:
	h.act = {"intent": c["intent"], "loc": c["loc"], "skill": c["skill"],
		"res": c["res"], "phase": "goto", "target": c["loc"], "then": "", "kills": 0}
	# pre-fight: stock up on food at the Market before heading to the Rat Pit (the food sink)
	if c["intent"] == "FIGHT" and int(h.inv.get("cooked_fish", 0)) < 2 and h.gold >= economy.food_price():
		h.act["target"] = "shop"
		h.act["then"] = "buyfood"
	# pre-fight ammo restock (bow/staff): 30 for 12g — cheap per-kill margin (anti-poverty-trap)
	elif c["intent"] == "FIGHT" and h.weapon != "sword" and int(h.inv.get("Arrows" if h.weapon == "bow" else "Runes", 0)) < 10 and h.gold >= 12.0:
		h.act["target"] = "shop"
		h.act["then"] = "buyammo"
	# fallback regroup: go to town and sell the load (frees cargo → gather available next decision)
	elif c["intent"] == "REGROUP":
		h.act["then"] = "sell"
	elif c["intent"] == "BUY_TOOL":
		h.act["then"] = "buytool"
	elif c["intent"] == "BUY_WEAPON":
		h.act["then"] = "buyweapon"
	elif c["intent"] == "BUY_OFFHAND":
		h.act["then"] = "buyoffhand"
	elif c["intent"] == "SMITH":
		h.act["then"] = "smith"
	_set_move(h, h.act["target"])
	_narrate(h)

func _work_action(h: Hero) -> void:
	if h.act.is_empty():
		# Tier-3 Seize (§18.4): a seized hero's brain is SUSPENDED — it never auto-decides; it idles
		# until the player issues a command (command_seized) or releases it (release_hero).
		if h.seized:
			h.thought = "Seized — awaiting your command."
			return
		_start_activity(h)
		return
	var a: Dictionary = h.act
	# FIGHT does its own movement (chasing wandering mobs) — handle before the travel gate
	if a.get("intent", "") == "FIGHT" and a.get("phase", "") == "fight":
		_fight_round(h)
		return
	if not _at_target(h):
		return  # still travelling
	match a["phase"]:
		"goto":
			# arrival: either begin working, or resolve a chained step (sell/cook/sellfood/buyfood)
			match a.get("then", ""):
				"buyfood":
					var bought := economy.buy_food(h, Config.FOOD_BUY_QTY)
					if bought > 0:
						log_event("%s bought %d food for the Rat Pit." % [h.hero_name, bought], "gold", 0)
					a["phase"] = "goto"
					a["target"] = a["loc"]   # return to THIS trip's camp (multi-camp world)
					a["then"] = ""
					_set_move(h, a["loc"])
					_narrate(h)
					return
				"smith":
					# forge: 3 ore → an Iron sword (carried — equip if upgrade, else vendors later)
					while int(h.inv.get("ore", 0)) >= 3 and not h.inv_full():
						h.inv["ore"] = int(h.inv["ore"]) - 3
						if int(h.inv["ore"]) <= 0:
							h.inv.erase("ore")
						h.inv["Iron sword"] = int(h.inv.get("Iron sword", 0)) + 1
						_grant_xp(h, "smithing", 40)
					h.act = {}
					return
				"buyammo":
					var ak := "Arrows" if h.weapon == "bow" else "Runes"
					if h.gold >= 12.0:
						h.gold -= 12.0   # burned supply sink (the ranged/magic counterpart of the food sink)
						h.inv[ak] = int(h.inv.get(ak, 0)) + 60   # bigger bundle = fewer restock trips
					a["phase"] = "goto"
					a["target"] = a["loc"]   # return to THIS trip's camp (multi-camp world)
					a["then"] = ""
					_set_move(h, a["loc"])
					_narrate(h)
					return
				"buytool":
					var tool := String(Config.TOOL_FOR.get(a.get("skill", ""), ""))
					if tool != "" and h.gold >= Config.TOOL_COST:
						h.gold -= Config.TOOL_COST   # burned: the tool-purchase gold sink
						h.inv[tool] = int(h.inv.get(tool, 0)) + 1
						log_event("%s bought a %s — taking up %s." % [h.hero_name, tool, String(a.get("skill", ""))], "gold", 0)
					h.act = {}
					return
				"buyweapon":
					if h.gold >= Config.WEAPON_COST:
						h.gold -= Config.WEAPON_COST
						h.equipped["main"] = {"sword": "Bronze sword", "bow": "Shortbow", "staff": "Apprentice staff"}[h.weapon]
						_milestone(h, "Bought a %s" % String(h.equipped["main"]))
					h.act = {}
					return
				"buyoffhand":
					if h.gold >= 35.0 and not h.equipped.has("off"):
						h.gold -= 35.0   # burned sink, like tools
						h.equipped["off"] = "Wooden shield"
						_milestone(h, "Bought a Wooden shield")
					h.act = {}
					return
				"sell":
					var g := economy.sell_goods(h)
					if g > 0:
						log_event("%s sold goods for %dg." % [h.hero_name, g], "gold", 0)
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
						log_event("%s cooked & sold food (+%dg)." % [h.hero_name, pay], "gold", 0)
					h.act = {}
					return
				_:
					# arrived at the node → begin the right work phase
					if a["intent"] == "FIGHT":
						a["phase"] = "fight"
					elif a["intent"] == "PROVISION":
						a["phase"] = "fish"
					else:
						a["phase"] = "gather"
					_narrate(h)
		"gather":
			h.inv[a["res"]] = int(h.inv.get(a["res"], 0)) + 1
			_grant_xp(h, a["skill"], 8)
			if int(h.inv[a["res"]]) >= 14 or h.cargo_count() >= 27 or h.inv_full():
				a["phase"] = "goto"
				a["target"] = "shop"
				a["then"] = "sell"
				_set_move(h, "shop")
				_narrate(h)
		"fish":
			h.inv["raw_fish"] = int(h.inv.get("raw_fish", 0)) + 1
			_grant_xp(h, "fishing", 8)
			if int(h.inv["raw_fish"]) >= 8 or h.inv_full():
				a["phase"] = "goto"
				a["target"] = "range"
				a["then"] = "cook"
				_set_move(h, "range")
				_narrate(h)

func _grant_xp(h: Hero, skill: String, base_amount: int) -> void:
	var new_level := h.add_xp(skill, int(round(base_amount * Config.XP_RATE)))
	if new_level > 0 and (new_level % 5 == 0 or new_level >= 20):
		_milestone(h, "Reached %s %d" % [_cap(skill), new_level])   # personal saga — every notable level
		# the town Chronicle gets only MAJOR milestones (§17 "first 99, notable level-ups"), else level-up
		# spam from a 45-hero colony buries the story.
		if new_level == 50 or new_level == 75 or new_level == 90 or new_level >= 99:
			log_event("%s reached %s %d!" % [h.hero_name, _cap(skill), new_level], "lv", 3 if new_level >= 99 else 2)

func hero_by_id(id: int) -> Hero:
	for h in heroes:
		if h.id == id:
			return h
	return null

func _stamp() -> String:
	return "D%d %02d:%02d" % [sim_day, int(sim_clock / 60.0) % 24, int(sim_clock) % 60]

## Record a notable per-hero saga event (§17/§20 Saga tab), newest-first, capped.
func _milestone(h: Hero, text: String) -> void:
	h.milestones.push_front({"t": _stamp(), "text": text})
	if h.milestones.size() > 12:
		h.milestones.pop_back()

# ---------------------------------------------------------------------------
# Chronicle social narrative (§17, Step 5) — turns the relationship graph into STORY. A daily scan
# announces relationships that have CROSSED a tier boundary since last announced (formed / deepened /
# reconciled / soured), once each, to both the town Chronicle and the two heroes' sagas.

## The more-extreme of the two directed tiers for a pair (a feud needs only one side to feel it).
func _pair_tier(a: int, b: int) -> String:
	if social == null:
		return "Neutral"
	var ra: float = social.get_r(a, b, sim_day)
	var rb: float = social.get_r(b, a, sim_day)
	return social.tier_of(ra if absf(ra) >= absf(rb) else rb)

const _SOCIAL_HEADLINES_PER_DAY := 3   # cap global Chronicle social lines/day → no burst-spam (§17 curation)

func _chronicle_social_daily() -> void:
	if social == null:
		return
	var seen: Dictionary = {}
	var headlines: Array = []   # only the dramatic extremes (Ally/Nemesis) reach the town Chronicle
	for a in social.adj.keys():
		for b in social.adj[a].keys():
			var lo: int = mini(int(a), int(b))
			var hi: int = maxi(int(a), int(b))
			var key := "%d_%d" % [lo, hi]
			if seen.has(key):
				continue
			seen[key] = true
			var t := _pair_tier(lo, hi)
			var prev: String = _announced_bonds.get(key, "Neutral")
			if t == prev:
				continue
			if t == "Neutral":
				_announced_bonds.erase(key)   # bond faded → let a future one re-announce
				continue
			var ha := hero_by_id(lo)
			var hb := hero_by_id(hi)
			if ha == null or hb == null:
				continue
			_announced_bonds[key] = t
			_bond_saga(ha, hb, prev, t)        # personal saga milestone — ALWAYS (per-hero story)
			if t == "Ally" or t == "Nemesis":  # only the rare extremes are town news (notability §17)
				headlines.append({"a": ha, "b": hb, "t": t})
	# cap per-day so a maturing web doesn't dump dozens of lines at once (the cold-read spam bug)
	for hl: Dictionary in headlines.slice(0, _SOCIAL_HEADLINES_PER_DAY):
		var t: String = hl["t"]
		if t == "Ally":
			log_event("%s and %s are now steadfast allies." % [hl["a"].hero_name, hl["b"].hero_name], "friend", 3)
		else:
			log_event("%s and %s have become sworn nemeses." % [hl["a"].hero_name, hl["b"].hero_name], "nemesis", 3)

## Per-hero saga milestone for a relationship crossing (both heroes' Saga tab, §17/§20).
func _bond_saga(a: Hero, b: Hero, prev: String, t: String) -> void:
	var was_neg := prev == "Rival" or prev == "Nemesis"
	var was_pos := prev == "Friend" or prev == "Ally"
	var sa := ""
	var sb := ""
	match t:
		"Friend":
			sa = ("Made peace with %s" % b.hero_name) if was_neg else ("Befriended %s" % b.hero_name)
			sb = ("Made peace with %s" % a.hero_name) if was_neg else ("Befriended %s" % a.hero_name)
		"Ally":
			sa = "Became close allies with %s" % b.hero_name
			sb = "Became close allies with %s" % a.hero_name
		"Rival":
			sa = ("Fell out with %s" % b.hero_name) if was_pos else ("Grew to resent %s" % b.hero_name)
			sb = ("Fell out with %s" % a.hero_name) if was_pos else ("Grew to resent %s" % a.hero_name)
		"Nemesis":
			sa = "Made a sworn nemesis of %s" % b.hero_name
			sb = "Made a sworn nemesis of %s" % a.hero_name
		_:
			return
	_milestone(a, sa)
	_milestone(b, sb)

# ---------------------------------------------------------------------------
# Offline catch-up (GDD §4 / EQUATIONS §3) — the statistical resolution path. Step-6 rewrite: the
# projection respects THE SAME bounds the live economy enforces (the instance-#5 fix — an offline yield
# that ignored saturation was a production faucet with no back-pressure):
#  • MARKET CEILING (gather): the town only absorbs its consumption rate per good (shop-level-scaled,
#    §19.2) — production beyond it can't sell, exactly like live capacity-respecting shops. Shared
#    across all offline gatherers of that good. Priced at the CURRENT (≈saturated/floored) sell price.
#  • PIT THROUGHPUT (combat): rats are shared — total kill rate is bounded by spawns, not per-hero.
#  • ATTRACTOR PROJECTION (gold): at live cadence 24h ≈ 35 sim-days, so linear gold accrual with no
#    sink would inject ~100k/hero (the held offline-yield bug). Live gold follows g' = rate − upkeep(g)
#    (the §6 attractor); we apply its CLOSED FORM: g(T) = g* + (g0 − g*)·e^(−k·T). Offline gold thus
#    approaches what live play would actually HOLD and cannot overshoot it. Floored at g0 (§4 safe
#    accrual — never lose gold offline). XP stays linear ×OFFLINE_RATE (no sink live either — faithful).
#  • Rare drops roll at OFFLINE_RARE_MULT when a drop system exists (Phase 0 has none — constant ready).
# No deaths/events offline (§4 live-only risk). The world clock does not advance (catch-up rewards only).
func offline_catchup(elapsed_hours: float) -> Dictionary:
	var dt_hours := minf(elapsed_hours, Config.OFFLINE_CAP_HOURS)
	var simdays_per_hour := Activities.actions_per_hour() * Config.SIM_MINUTES_PER_TICK / 1440.0
	var pop_scale: float = float(heroes.size()) / float(Config.POP_BASELINE)
	# head-counts per offline activity (single-player: the whole colony is offline together)
	var gatherers: Dictionary = {}   # sells_as good -> count
	var fighters := 0
	for h in heroes:
		var intent: String = h.act.get("intent", "")
		if Activities.is_gather(intent):
			var good := Activities.sells_as(intent)
			gatherers[good] = int(gatherers.get(good, 0)) + 1
		elif Activities.is_combat(intent):
			fighters += 1
	# the live upkeep sink, converted to per-REAL-HOUR (offline applies the same sinks as live, §6)
	var uk_rate: float = Config.UPKEEP_RATE * simdays_per_hour
	var uk_flat: float = Config.UPKEEP_FLAT * simdays_per_hour
	var summary := {"hours": dt_hours, "gold": 0, "xp": 0}
	for h in heroes:
		var intent: String = h.act.get("intent", "")
		var r_h := 0.0    # market/pit-capped gross gold per real hour for this hero's activity
		var xp_h := 0.0
		var skill := ""
		if Activities.is_gather(intent):
			skill = Activities.skill_of(intent)
			var good := Activities.sells_as(intent)
			var n := maxi(1, int(gatherers.get(good, 1)))
			var shop: Shop = economy.shop_for(good)
			var consume_rate: float = float(shop.consume.get(good, 0.0)) if shop != null else 0.0
			var market_uph: float = consume_rate * pop_scale * simdays_per_hour   # units/hr the town absorbs
			var uph: float = minf(Activities.actions_per_hour() * Activities.TRIP_EFFICIENCY, market_uph / n)
			r_h = uph * float(economy.sell_price(good)) * (1.0 - Config.GE_TAX)
			xp_h = Activities.actions_per_hour() * Activities.TRIP_EFFICIENCY * Activities.GATHER_XP_PER_ACTION * Config.XP_RATE
		elif Activities.is_combat(intent):
			skill = "strength"
			var pit_kph: float = float(alive_monster_count()) * Activities.FIGHT_KILLS_PER_HOUR
			var kph: float = minf(Activities.FIGHT_KILLS_PER_HOUR, pit_kph / maxf(1.0, float(fighters))) * Activities.TRIP_EFFICIENCY
			var avg_drop := (Config.RAT_DROP_MIN + Config.RAT_DROP_MIN + Config.RAT_DROP_RANGE) / 2.0
			r_h = kph * avg_drop
			xp_h = kph * Activities.RAT_HP * 4.0 * Config.XP_RATE
		else:
			continue   # idle / regrouping heroes accrue nothing (matches live: no activity, no yield)
		# attractor-respecting gold projection (closed form of the live ODE — cannot overshoot g*)
		var g_star: float = (Config.OFFLINE_RATE * r_h - uk_flat) / uk_rate
		var g_t: float = g_star + (h.gold - g_star) * exp(-uk_rate * dt_hours)
		var new_gold: float = maxf(h.gold, g_t)   # §4 safe accrual: never LOSE gold offline
		var gold_gain := int(round(new_gold - h.gold))
		var xp_gain := int(round(xp_h * dt_hours * Config.OFFLINE_RATE))
		h.gold += float(gold_gain)
		h.add_xp(skill, xp_gain)
		summary["gold"] = int(summary["gold"]) + gold_gain
		summary["xp"] = int(summary["xp"]) + xp_gain
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
	if phase == "goto" and then == "buyfood":
		h.thought = "Buying food before the Rat Pit."
	elif phase == "fight":
		h.thought = "Fighting rats · %d food left." % int(h.inv.get("cooked_fish", 0))
	elif phase == "goto" and then == "sell":
		h.thought = "Inventory full — off to the Market to sell."
	elif phase == "goto" and then == "cook":
		h.thought = "Carrying fish to the Range to cook."
	elif phase == "goto" and then == "sellfood":
		h.thought = "Taking fresh food to the Market."
	elif phase == "goto":
		var what: String = {"GATHER_ORE": "ore", "GATHER_LOGS": "logs", "PROVISION": "fish", "FIGHT": "a fight"}.get(a["intent"], "work")
		h.thought = "Heading out for %s." % what
	elif phase == "gather":
		h.thought = "%s — %d so far." % ["Mining ore" if a["skill"] == "mining" else "Chopping logs", int(h.inv.get(a["res"], 0))]
	elif phase == "fish":
		h.thought = "Fishing — %d caught." % int(h.inv.get("raw_fish", 0))

## Append a Chronicle event (§17). `notability` (1 ordinary … 3 saga-worthy) lets the viewer surface the
## most memorable happenings; the colony's running event log is curated by only logging notable things.
func log_event(text: String, cls: String = "", notability: int = 1) -> void:
	if notability <= 0:
		return   # routine telemetry (per-sale gold flow, per-kill ticks) — not Chronicle-worthy (§17 curation)
	chronicle.push_front({"text": text, "cls": cls, "t": _stamp(), "notability": notability})
	if chronicle.size() > 60:
		chronicle.pop_back()

func total_gold() -> int:
	var g := 0.0
	for h in heroes:
		g += h.gold
	return int(round(g))

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
