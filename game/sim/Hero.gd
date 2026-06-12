class_name Hero
extends RefCounted
## A procgen adventurer ("player"). Phase-0 subset of the §12 Hero schema. Pure SIM-CORE
## state: no Node, no rendering — the render layer reads this.

var id: int = 0
var hero_name: String = ""
var favorite: String = ""           # favorite skill (utility bias, §18.3)
var secondary: String = ""
# appearance (procgen, §20.3) — so the render layer can draw distinct heroes
var skin: String = "#e7b58a"
var hair: String = "#3a2a1a"
var shirt: String = "#5a7d4f"
# skills: { skill_id: { "level": int, "xp": int } }
var skills: Dictionary = {}
var hp: int = 10
var gold: float = 20.0   # float so the small per-action proportional upkeep (§6) accrues instead
                         # of rounding to 0 each tick; display sites floor it

var inv: Dictionary = {"ore": 0, "logs": 0, "raw_fish": 0, "cooked_fish": 0}
# Weapon type = attack style (M1c): sword=melee, bow=ranged, staff=magic. Assigned deterministically
# (id-based, no RNG draw). Phase-0: style sets ENGAGE REACH + visuals; full triangle math lands in M3b.
var weapon: String = "sword"
# EQUIPMENT (M1d): ONE item per slot; equipping moves the item OUT of the inventory (frees space);
# swapping returns the old piece to the inventory; unequip needs a free inventory slot.
const SLOTS := ["head", "cape", "neck", "main", "torso", "off", "gloves", "legs", "boots", "ring"]
var equipped: Dictionary = {}      # slot -> item display name
# GOAL (§18.3 Layer-2): {"skill": String, "level": int} — "train X to N", biases utility until met,
# then a new goal is picked (favorite-weighted but ROTATING — heroes don't only do their favorite).
var goal: Dictionary = {}
# RUN (seized-control feature): 2× walk speed while energy lasts; drains running, regens otherwise.
var run_on: bool = false
var run_energy: float = 100.0
# autonomous run usage: rolled at decision points; runs until energy hits the rolled stop level,
# then a rolled 15–120s cooldown gates the next roll (failed rolls re-trigger the cooldown).
var run_stop_at: float = 0.0     # energy level at which this run ends (random per roll)
var run_cd_left: float = 0.0     # seconds until running may be rolled again
# pathfinding (grid BFS): waypoints to the current move_target. Serialized (a fresh BFS mid-trip
# could tie-break differently → save/load determinism requires persisting the exact path).
var path: Array = []
var path_goal: Variant = null    # the move_target this path was built for (Vector2 or null)

func equip_item(slot: String, item: String) -> bool:
	if not SLOTS.has(slot) or int(inv.get(item, 0)) <= 0:
		return false
	inv[item] = int(inv[item]) - 1
	if int(inv[item]) <= 0:
		inv.erase(item)
	if equipped.has(slot):   # one per slot — the old piece goes back to the inventory
		inv[equipped[slot]] = int(inv.get(equipped[slot], 0)) + 1
	equipped[slot] = item
	return true

func unequip_slot(slot: String) -> bool:
	if not equipped.has(slot) or inv_count() >= 28:
		return false
	inv[equipped[slot]] = int(inv.get(equipped[slot], 0)) + 1
	equipped.erase(slot)
	return true
var traits: Dictionary = {"risk": 0.4, "greed": 0.4, "ambition": 0.5, "sociability": 0.5, "patience": 0.5, "loyalty": 0.5}
# population / retention (§16.1 / §19.4)
var tier: String = "Founder"        # newcomer rarity tier (Greenhorn→Elite); founders are pre-existing
var satisfaction: float = 50.0      # §19.4 retention meter (recomputed daily)
var unhappy_days: int = 0           # consecutive days below LEAVE_THRESHOLD → voluntary departure
var recent_success: float = 0.0     # decaying window of recent level-ups (feeds satisfaction)
# live state
var pos: Vector2 = Vector2.ZERO     # tile coordinates
var move_target: Variant = null     # Vector2 or null
var act: Dictionary = {}            # current activity FSM state
var thought: String = "Newly arrived in Varrock."
var flash: float = 0.0              # render hint (hit/eat flash)
var decisions: int = 0             # §18.6 cadence telemetry: times the brain re-picked an activity
var last_candidates: Array = []    # the scored options weighed at the last decision (Thoughts tab, §20)
# ---- player control tiers (§2 / §18.4, Step 4) ----
# Nudge (Tier 2): a one-off player-injected activity that wins the NEXT decision, then is consumed →
# the hero resumes full autonomy. Empty = no pending nudge. Shape mirrors a brain candidate's head
# fields: { "intent", "loc", "skill", "res" }.
var nudge: Dictionary = {}
# Seize (Tier 3): brain suspended. While true the hero never auto-decides; it only acts on a
# player-issued command (world.command_seized) and idles otherwise. Release restores autonomy.
var seized: bool = false
var backstory: String = ""         # generated one-liner (Saga tab, §20)
var milestones: Array = []         # newest-first per-hero saga events (§17), capped
# ---- Slayer (Unit 0 / B2) ----
# Active task: { "mon": type_id, "camp": loc_key, "remaining": int, "total": int }. Empty = none.
# Assigned by Vannaka (SimWorld._assign_slayer_task) after the feasibility + knowledge gates.
var slayer_task: Dictionary = {}
var slayer_points: int = 0         # earned per completed task; spending = later design (B2)

func skill_level(s: String) -> int:
	return int(skills.get(s, {}).get("level", 1))

func skill_xp(s: String) -> int:
	return int(skills.get(s, {}).get("xp", 0))

func max_hp() -> int:
	return skill_level("hitpoints")

# CANON OSRS INVENTORY: 28 slots max; every item takes 1 slot per unit EXCEPT stackables
# (arrows, runes, fishing bait when implemented), which occupy a single slot for any quantity.
const STACKABLES := ["Arrows", "Runes", "Fishing bait"]
const INV_SLOTS := 28

func inv_count() -> int:   # = SLOTS USED (canon accounting)
	var n := 0
	for k in inv:
		var q := int(inv[k])
		if q <= 0:
			continue
		n += 1 if STACKABLES.has(k) else q
	return n

func inv_full() -> bool:
	return inv_count() >= INV_SLOTS

# Consumables the hero carries for self-use (food) — a RESERVED partition that must NOT count
# toward the "is there room to gather loot?" test (§ candidate-generation invariant). Otherwise a
# food-heavy fighter has every gather option deleted from its menu before scoring (the starved-menu
# bug the decision instrument proved).
const CONSUMABLES := ["cooked_fish", "Arrows", "Runes"]   # ammo rides the reserved partition like food

func cargo_count() -> int:
	var n := 0
	for k in inv:
		if not CONSUMABLES.has(k):
			n += int(inv[k])
	return n

## Add XP (already multiplied by XP_RATE upstream). Returns the new level if it changed,
## else 0. Hitpoints level-ups also top up the current HP pool by the gained levels.
func add_xp(s: String, amount: int) -> int:
	if not skills.has(s):
		skills[s] = {"level": 1, "xp": 0}
	var rec: Dictionary = skills[s]
	var before: int = rec["level"]
	rec["xp"] = int(rec["xp"]) + amount
	var after := XpTables.level_for_xp(rec["xp"])
	if after > before:
		rec["level"] = after
		recent_success += float(after - before)   # feeds §19.4 satisfaction (decays daily)
		if s == "hitpoints":
			hp = mini(max_hp(), hp + (after - before))
		return after
	return 0
