class_name ItemType
extends RefCounted
## Catalog entry, ingested from the dataset (osrsreboxed → ContentDB). Canon identity; stat
## VALUES are Standard-tier here (the §11 floor) and roll above per quality tier. (EQUATIONS §12)

var id: String = ""
var name: String = ""
var slot: String = ""               # weapon/body/legs/...; "" for resources/consumables
var level_reqs: Dictionary = {}     # { skill_id: level }
var base_stats: Dictionary = {}     # { att_slash, str, def_*, ... } per-style bonuses
var base_value: int = 0             # canon base/high-alch value (the price anchor, §6)
var stackable: bool = false
var acquisition: Dictionary = {}    # { type: Craftable|DropOnly|Hybrid, ... }
var is_food: bool = false
var heals: int = 0
var icon_id: String = ""            # osrsreboxed icon key (PNG), §21

static func from_dict(d: Dictionary) -> ItemType:
	var it := ItemType.new()
	it.id = d.get("id", "")
	it.name = d.get("name", "")
	it.slot = d.get("slot", "")
	it.level_reqs = d.get("levelReqs", {})
	it.base_stats = d.get("baseStats", {})
	it.base_value = int(d.get("baseValue", 0))
	it.stackable = bool(d.get("stackable", false))
	it.acquisition = d.get("acquisition", {})
	it.is_food = bool(d.get("isFood", false))
	it.heals = int(d.get("heals", 0))
	it.icon_id = d.get("iconId", it.id)
	return it
