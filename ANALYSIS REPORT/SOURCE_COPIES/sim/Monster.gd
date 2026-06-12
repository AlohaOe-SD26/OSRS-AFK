class_name Monster
extends RefCounted
## Canon monster, ingested from the dataset. Drives combat (§10) and the Salve path
## (`undead`, ITEMS_MONSTERS_BALANCE §1.1/§5.8). Phase 0 carries these but only wires the
## math/telemetry, not live fights (build step 2). (EQUATIONS §12)

var id: String = ""
var name: String = ""
var combat_level: int = 1
var hitpoints: int = 1
var attack_styles: Array = []
var max_hit: int = 0
var weakness_style: String = ""     # the style to use against it (combat triangle, §10)
var attack_speed: int = 4           # in ticks
var aggressive: bool = false
var undead: bool = false
var slayer_level_req: int = 0
var region: String = ""
var is_boss: bool = false
var coin_drop_min: int = 0
var coin_drop_max: int = 0
var drop_table: Array = []          # [ { itemTypeId, rate } ]

static func from_dict(d: Dictionary) -> Monster:
	var m := Monster.new()
	m.id = d.get("id", "")
	m.name = d.get("name", "")
	m.combat_level = int(d.get("combatLevel", 1))
	m.hitpoints = int(d.get("hitpoints", 1))
	m.attack_styles = d.get("attackStyles", [])
	m.max_hit = int(d.get("maxHit", 0))
	m.weakness_style = d.get("weaknessStyle", "")
	m.attack_speed = int(d.get("attackSpeed", 4))
	m.aggressive = bool(d.get("aggressive", false))
	m.undead = bool(d.get("undeadFlag", false))
	m.slayer_level_req = int(d.get("slayerLevelReq", 0))
	m.region = d.get("region", "")
	m.is_boss = bool(d.get("isBoss", false))
	var coins: Array = d.get("coinDropRange", [0, 0])
	m.coin_drop_min = int(coins[0]) if coins.size() > 0 else 0
	m.coin_drop_max = int(coins[1]) if coins.size() > 1 else m.coin_drop_min
	m.drop_table = d.get("dropTable", [])
	return m
