class_name ItemType
extends RefCounted
## Catalog entry, ingested from the dataset (osrsreboxed → ContentDB). Canon identity; stat
## VALUES are Standard-tier here (the §11 floor) and roll above per quality tier. (EQUATIONS §12)
##
## Unit 1 (catalog migration): the catalog is now the SINGLE source of item truth — ids are the
## sim's inventory/equipment keys, base_value anchors shop pricing, tier/style drive gear combat
## effects, tradeable gates vendoring, and acquisition carries recipes (recipes-as-data).

var id: String = ""
var name: String = ""
var slot: String = ""               # Hero slot key (main/off/head/torso/...); "" = not equipable
var style: String = ""              # main-hand weapon style (sword/bow/staff); "" for non-weapons
var tier: int = 0                   # gear tier (combat effect scale); 0 = not gear
var level_reqs: Dictionary = {}     # { skill_id: level }
var base_stats: Dictionary = {}     # { att_slash, str, def_*, ... } per-style bonuses
var base_value: int = 0             # canon base/high-alch value (the price anchor, §6)
var stackable: bool = false
var tradeable: bool = true          # may shops/GE trade it (vendoring gate)
var acquisition: Dictionary = {}    # { type: Craftable|DropOnly|Hybrid|..., recipe, craftSkill, dropPool, ... }
var is_food: bool = false
var heals: int = 0
var icon_id: String = ""            # osrsreboxed icon key (PNG), §21

static func from_dict(d: Dictionary) -> ItemType:
	var it := ItemType.new()
	it.id = d.get("id", "")
	it.name = d.get("name", "")
	it.slot = d.get("slot", "")
	it.style = d.get("style", "")
	it.tier = int(d.get("tier", 0))
	it.level_reqs = d.get("levelReqs", {})
	it.base_stats = d.get("baseStats", {})
	it.base_value = int(d.get("baseValue", 0))
	it.stackable = bool(d.get("stackable", false))
	it.tradeable = bool(d.get("tradeable", true))
	it.acquisition = d.get("acquisition", {})
	it.is_food = bool(d.get("isFood", false))
	it.heals = int(d.get("heals", 0))
	it.icon_id = d.get("iconId", it.id)
	return it

## In the random gear-drop pool (rats drop gear, M3a)?
func in_drop_pool() -> bool:
	return bool(acquisition.get("dropPool", false))

## Recipe accessors (recipes-as-data): [] / "" when not craftable.
func recipe() -> Array:
	return acquisition.get("recipe", [])

func craft_skill() -> String:
	return String(acquisition.get("craftSkill", ""))

func craft_xp() -> int:
	return int(acquisition.get("craftXp", 0))
