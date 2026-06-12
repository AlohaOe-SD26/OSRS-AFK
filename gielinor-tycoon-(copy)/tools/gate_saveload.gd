extends SceneTree
## STEP-6 SAVE/LOAD gate — the determinism invariant applied to persistence: a run that is SAVED TO DISK,
## RELOADED, and continued must be byte-identical to an uninterrupted run from the same seed. Run A =
## uninterrupted; run B = identical except at the midpoint tick the world is saved to a file, a NEW world
## is loaded from that file, and the run continues on the loaded world. Hashes must match exactly.
## Complies with the standing harness rules: preload deps (no --import), quit() at end, run foreground.
##   godot --headless --path game --script res://tools/gate_saveload.gd

const SimHash := preload("res://tools/sim_hash.gd")
const SaveLoad := preload("res://sim/SaveLoad.gd")
const SEEDS := [0xA17F00D, 0xBEEF01, 0xC0FFEE]
const DAYS := 12

func _initialize() -> void:
	print("=== STEP-6 SAVE/LOAD GATE — save→load→continue ≡ uninterrupted (same seed) ===")
	var content := ContentDB.new()
	content.load_all("res://data")
	var ticks := int(DAYS / SimWorld._DD_PER_ACTION)
	var mid := int(ticks / 2.0)
	var all_ok := true
	for seed_v in SEEDS:
		var a: Array = SimHash.run_and_hash(int(seed_v), DAYS)
		var hook := func(world, i: int):
			if i == mid:
				SaveLoad.save_to_file(world, "user://gate_save.dat")
				var loaded: SimWorld = SaveLoad.load_from_file(content, "user://gate_save.dat")
				loaded.telemetry = Telemetry.new(int(seed_v))
				return loaded   # the rest of the run continues on the DISK-ROUND-TRIPPED world
			return world
		var b: Array = SimHash.run_and_hash(int(seed_v), DAYS, hook)
		var ok: bool = a[0] == b[0]
		all_ok = all_ok and ok
		print("  seed %x: uninterrupted %d vs save@mid→load→continue %d  -> %s" % [seed_v, a[0], b[0], "IDENTICAL" if ok else "DIVERGED"])
		if not ok:
			_first_diff(a[1], b[1])
	print("\n%s" % ("PASS — persistence is deterministic (save→load→continue ≡ uninterrupted)." if all_ok else "FAIL — a field is missing/mutated in save/load; STOP."))
	quit(0 if all_ok else 1)

## On divergence, print the first differing state line — points at the missed/mutated field directly.
func _first_diff(sa: String, sb: String) -> void:
	var la := sa.split("\n")
	var lb := sb.split("\n")
	for i in range(mini(la.size(), lb.size())):
		if la[i] != lb[i]:
			print("    first diff @%d:\n      A: %s\n      B: %s" % [i, la[i], lb[i]])
			return
	print("    states equal but trace diverged (mid-run divergence that later reconverged)")
