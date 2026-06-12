class_name Rng
extends RefCounted
## Deterministic, seeded RNG wrapper for the SIM CORE.
##
## The sim must be reproducible (GDD §21.2 / §25: RNG seed is part of the save) so that
## offline catch-up, save/load and testing all behave identically. NEVER use the global
## randi()/randf() inside the sim — thread one Rng instance through SimWorld instead.

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = Config.DEFAULT_SEED) -> void:
	_rng.seed = seed_value

## Current internal state — serialize this into the save (§25) so a reload continues the
## exact same stream rather than restarting it.
func get_state() -> int:
	return _rng.state

func set_state(state: int) -> void:
	_rng.state = state

## Uniform float in [0, 1).
func randf() -> float:
	return _rng.randf()

## Uniform float in [from, to).
func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

## Uniform int in [from, to] inclusive.
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

## True with probability p.
func chance(p: float) -> bool:
	return _rng.randf() < p
