class_name MonsterInstance
extends RefCounted
## A LIVE monster in the world (distinct from the Monster *catalog* type). Spawned at a combat
## node; heroes fight these via the tick-combat loop (§10). Pure SIM-CORE state.

var type_id: String = "rat"
var pos: Vector2 = Vector2.ZERO
var hp: int = 15
var max_hp: int = 15
var defence: int = 1          # feeds the hero's accuracy roll (Combat.defence_roll)
var monster_max_hit: int = 1  # damage it deals back to a hero
var attack_speed: int = 4
var alive: bool = true
var respawn: float = 0.0      # seconds until respawn when dead
var wander: float = 0.0       # seconds until next idle wander
var move_target: Variant = null

static func from_type(m: Monster, at: Vector2) -> MonsterInstance:
	var r := MonsterInstance.new()
	r.type_id = m.id
	r.hp = m.hitpoints
	r.max_hp = m.hitpoints
	r.monster_max_hit = maxi(1, m.max_hit)
	r.attack_speed = m.attack_speed
	r.defence = maxi(1, int(round(m.combat_level / 10.0)))  # coarse Phase-0 defence from combat level
	r.pos = at
	r.alive = true
	return r
