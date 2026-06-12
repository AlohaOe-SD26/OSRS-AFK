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
var traits: Dictionary = {"risk": 0.4, "greed": 0.4, "ambition": 0.5, "sociability": 0.5, "patience": 0.5, "loyalty": 0.5}
# live state
var pos: Vector2 = Vector2.ZERO     # tile coordinates
var move_target: Variant = null     # Vector2 or null
var act: Dictionary = {}            # current activity FSM state
var thought: String = "Newly arrived in Varrock."
var flash: float = 0.0              # render hint (hit/eat flash)

func skill_level(s: String) -> int:
	return int(skills.get(s, {}).get("level", 1))

func skill_xp(s: String) -> int:
	return int(skills.get(s, {}).get("xp", 0))

func max_hp() -> int:
	return skill_level("hitpoints")

func inv_count() -> int:
	var n := 0
	for k in inv:
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
		if s == "hitpoints":
			hp = mini(max_hp(), hp + (after - before))
		return after
	return 0
