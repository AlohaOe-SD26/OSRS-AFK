extends SceneTree
## TEMP diagnostic (#1d): who dies, how often, and what it does to reputation/economy with
## aggressive monsters live. Mirrors the population test (24k ticks, immigration ON).
##   godot --headless --path game --script res://tools/diag_aggro.gd

func _initialize() -> void:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.setup(content, 6, Config.DEFAULT_SEED)
	var last_deaths := 0
	for i in range(24000):
		world.tick(SimWorld._ACTION_SECONDS)
		if world.deaths != last_deaths:
			last_deaths = world.deaths
			if world.deaths <= 12 or world.deaths % 25 == 0:
				# the most recent chronicle "die" line says who/what
				for e in world.chronicle:
					if String(e["cls"]) == "die" and String(e["text"]).contains("slain"):
						print("  death #%d @tick %d: %s" % [world.deaths, i, e["text"]])
						break
		if i % 6000 == 5999:
			print("  t%5d  pop %d  deaths %d  flees %d  rep %d  recent_deaths %.1f  gold/cap %d  treas %d" %
				[i, world.heroes.size(), world.deaths, world.flees, int(world.population.reputation),
				world.population.recent_deaths, world.total_gold() / maxi(1, world.heroes.size()),
				int(world.economy.treasury)])
	print("FINAL: deaths %d  flees %d  rep %.1f  kill_counts %s" % [world.deaths, world.flees,
		world.population.reputation, world.kill_counts])
	quit(0)
