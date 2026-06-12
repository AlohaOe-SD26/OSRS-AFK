extends SceneTree
## STEP-6 determinism gate (shared). Establishes the baseline the LOD byte-identical gate rests on: two fresh
## runs from the same seed produce an IDENTICAL state hash. (LOD itself lives only in render/Main.gd — the
## headless sim never instantiates it, so the sim hash is render-independent by construction; this proves the
## sim half is deterministic. Save/load and offline gates extend this same harness.) Run directly — NO --import
## pass needed (SimHash is preloaded by path, not referenced via class_name):
##   godot --headless --path game --script res://tools/gate_determinism.gd

const SimHash := preload("res://tools/sim_hash.gd")
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE]
const DAYS := 12

func _initialize() -> void:
	print("=== STEP-6 DETERMINISM GATE — same seed → identical state hash (the byte-identical baseline) ===")
	var all_ok := true
	for seed_v in SEEDS:
		var a: Array = SimHash.run_and_hash(int(seed_v), DAYS)
		var b: Array = SimHash.run_and_hash(int(seed_v), DAYS)
		var ok: bool = a[0] == b[0]
		all_ok = all_ok and ok
		print("  seed %x: hash %d vs %d  -> %s" % [seed_v, a[0], b[0], "IDENTICAL" if ok else "DIVERGED"])
	print("\n%s" % ("PASS — sim is deterministic (LOD, render-only, cannot perturb it)." if all_ok else "FAIL — non-determinism detected; STOP."))
	quit(0 if all_ok else 1)
