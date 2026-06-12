extends SceneTree
## AMMO-COLLAPSE probe: with consumption ON, where do the fighters actually get stuck?
## Prints kills + per-hero (weapon, ammo, gold, decisions, act intent/phase/then) + act histogram.
##   godot --headless --path game --script res://tools/diag_ammo.gd

func _initialize() -> void:
	for arm in [false, true]:
		Config.AMMO_ON = arm
		var content := ContentDB.new()
		content.load_all("res://data")
		var world := SimWorld.new()
		world.telemetry = Telemetry.new(Config.DEFAULT_SEED)
		world.setup(content, 6, Config.DEFAULT_SEED)
		world.population.enabled = false
		for i in range(8000):
			world.tick(SimWorld._ACTION_SECONDS)
		var hist: Dictionary = {}
		for h in world.heroes:
			var key := "%s/%s/%s" % [String(h.act.get("intent", "idle")), String(h.act.get("phase", "")), String(h.act.get("then", ""))]
			hist[key] = int(hist.get(key, 0)) + 1
		print("\nAMMO_ON=%s  kills=%d  gold=%d" % [str(arm), world.total_kills, world.total_gold()])
		print("  act histogram: ", hist)
		for h in world.heroes:
			print("  %s w=%s ammo=A%d/R%d gold=%d dec=%d act=%s/%s food=%d" % [h.hero_name, h.weapon,
				int(h.inv.get("Arrows", 0)), int(h.inv.get("Runes", 0)), int(h.gold), h.decisions,
				String(h.act.get("intent", "-")), String(h.act.get("then", "")), int(h.inv.get("cooked_fish", 0))])
	Config.AMMO_ON = false
	quit(0)
