class_name Combat
extends RefCounted
## Canon OSRS combat math (EQUATIONS §2 / GDD §10.2). The SAME functions power the live
## tick fight AND the statistical "am I winning?" / offline view — they can never diverge
## (the §4 keystone). Stateless; all static.
##
## Phase 0 unit-tests these (tests/test_sim.gd) but does not yet wire a live fight — that's
## build-order step 2 (§22.3). They live here now because the schema + tests need them and
## the offline-yield projection (Activities) reuses DPS.

## Effective level = floor(level × prayerMult) + styleBonus + 8 (× potion if any).
static func effective_level(level: int, prayer_mult: float, style_bonus: int) -> int:
	return int(floor(level * prayer_mult)) + style_bonus + 8

## Max hit (melee/ranged) = floor(0.5 + effStr × (gearStr + 64) / 640).
static func max_hit(eff_str: int, gear_str: int) -> int:
	return int(floor(0.5 + eff_str * (gear_str + 64) / 640.0))

## Attack roll = effAtt × (gearAtt + 64).
static func attack_roll(eff_att: int, gear_att: int) -> int:
	return eff_att * (gear_att + 64)

## Defence roll = (targetDef + 9) × (targetDefBonus + 64).
static func defence_roll(target_def: int, target_def_bonus: int) -> int:
	return (target_def + 9) * (target_def_bonus + 64)

## Hit chance from attack vs defence rolls (canon piecewise formula).
static func hit_chance(att: int, def: int) -> float:
	if att > def:
		return 1.0 - (def + 2.0) / (2.0 * (att + 1.0))
	return att / (2.0 * (def + 1.0))

## Average hit = (maxHit + 1) / 2.
static func average_hit(mh: int) -> float:
	return (mh + 1.0) / 2.0

## DPS = avgHit × acc / (weaponSpeedTicks × 0.6).
static func dps(avg_hit: float, acc: float, weapon_speed_ticks: int) -> float:
	return avg_hit * acc / (weapon_speed_ticks * Config.TICK)

## Time-to-kill (seconds) = targetHP / DPS.
static func time_to_kill(target_hp: int, dps_value: float) -> float:
	if dps_value <= 0.0:
		return INF
	return target_hp / dps_value

## The brain's "am I winning?" check (EQUATIONS §2, statistical form).
## Returns true if the hero is expected to win with margin; risk_margin scales survival need
## (daredevil ~0.8, cautious ~1.5).
static func fight_is_winnable(my_dps: float, enemy_dps: float, enemy_hp: int, my_hp: int, food_heal_available: int, risk_margin: float) -> bool:
	var my_ttk := time_to_kill(enemy_hp, my_dps)
	if enemy_dps <= 0.0:
		return true
	var survive_time := (my_hp + food_heal_available) / enemy_dps
	return my_ttk < survive_time * risk_margin
