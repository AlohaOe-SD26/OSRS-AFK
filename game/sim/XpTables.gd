class_name XpTables
extends RefCounted
## Canon OSRS XP curve + combat level (EQUATIONS §1). Level cap 99 (XP 13,034,431);
## level 92 ≈ half of 99 — this property is preserved because XP_RATE scales XP gained
## UNIFORMLY (it never touches the curve shape).
##
## Stateless: all members are static. The table is built once and cached.

const MAX_LEVEL: int = 99

static var _xp_for_level: PackedInt64Array = _build_table()

static func _build_table() -> PackedInt64Array:
	# XP(L) = floor( (1/4) * Σ_{n=1}^{L-1} floor( n + 300 * 2^(n/7) ) )
	var table := PackedInt64Array()
	table.resize(MAX_LEVEL + 1)
	table[0] = 0
	table[1] = 0
	var points := 0.0
	for n in range(1, MAX_LEVEL):
		points += floorf(n + 300.0 * pow(2.0, n / 7.0))
		table[n + 1] = int(floorf(points / 4.0))
	return table

## Total XP required to reach a level (1..99).
static func xp_for_level(level: int) -> int:
	level = clampi(level, 1, MAX_LEVEL)
	return _xp_for_level[level]

## Level (1..99) for a given total XP.
static func level_for_xp(xp: int) -> int:
	var lvl := 1
	for i in range(2, MAX_LEVEL + 1):
		if xp >= _xp_for_level[i]:
			lvl = i
		else:
			break
	return lvl

## Canon combat level from the seven combat skills.
## cb = 0.25*(Def + HP + floor(Prayer/2)) + 0.325*max(Att+Str, 2*floor(Magic*?), 2*floor(Ranged*?))
## OSRS uses 0.325 * floor(Ranged*3/2) for ranged and floor(Magic*3/2) for magic.
static func combat_level(att: int, strn: int, def: int, hp: int, ranged: int, magic: int, prayer: int) -> int:
	var base: float = 0.25 * (def + hp + floorf(prayer / 2.0))
	var melee: float = 0.325 * (att + strn)
	var rng_cb: float = 0.325 * floorf(ranged * 3.0 / 2.0)
	var mag_cb: float = 0.325 * floorf(magic * 3.0 / 2.0)
	var best: float = maxf(melee, maxf(rng_cb, mag_cb))
	return int(floorf(base + best))
