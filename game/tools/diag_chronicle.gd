extends SceneTree
## STEP-5 COLD-READ: run a colony to scale, stir in some civic drama (god-initiated kick votes), then
## dump the Chronicle + a hero's saga verbatim. The question is qualitative — does this read as a STORY
## you'd care about? Run:  godot --headless --path game --script res://tools/diag_chronicle.gd

const DAYS := 28
const SEED := 0xC0FFEE

func _initialize() -> void:
	var content := ContentDB.new()
	content.load_all("res://data")
	var world := SimWorld.new()
	world.telemetry = Telemetry.new(SEED)
	world.setup(content, 6, SEED)
	var ticks := int(DAYS / SimWorld._DD_PER_ACTION)
	var next_vote := int(ticks / 6.0)
	for i in range(ticks):
		world.tick(SimWorld._ACTION_SECONDS)
		# every ~DAYS/6, the god calls a kick vote on a random citizen → civic drama in the Chronicle
		if i == next_vote and world.heroes.size() > 8:
			next_vote += int(ticks / 6.0)
			var target: Hero = world.heroes[world.rng.randi_range(0, world.heroes.size() - 1)]
			var r := world.start_kick_vote(target)
			# at scale most citizens are busy → votes go sub-quorum; the god then uses the failsafe
			if String(r["outcome"]) != "pass":
				world.force_kick(target, true)
	print("\n========================= THE CHRONICLE OF VARROCK (day %d, %d citizens) =========================" % [world.sim_day, world.heroes.size()])
	for ev in world.chronicle:
		print("  %-12s [%s] %s" % [String(ev["t"]), String(ev.get("cls", "")), String(ev["text"])])
	# the most-storied hero (most milestones), with their saga
	var star: Hero = null
	for h in world.heroes:
		if star == null or h.milestones.size() > star.milestones.size():
			star = h
	if star != null:
		print("\n----------------- SAGA: %s the %s -----------------" % [star.hero_name, star.tier])
		print("  \"%s\"" % star.backstory)
		var cl := XpTables.combat_level(star.skill_level("attack"), star.skill_level("strength"), star.skill_level("defence"), star.skill_level("hitpoints"), 1, 1, 1)
		print("  Combat %d · favours %s · %dg" % [cl, star.favorite, int(star.gold)])
		for m in star.milestones:
			print("    %-12s %s" % [String(m["t"]), String(m["text"])])
		# their relationships
		var rels: Array = world.social.relations_for(star.id, world.sim_day, 8)
		if not rels.is_empty():
			print("  Bonds:")
			for rr: Dictionary in rels:
				var other := world.hero_by_id(int(rr["to"]))
				print("    %-8s %s (%+d)" % [String(rr["tier"]), other.hero_name if other else "?", int(rr["r"])])
	# tier histogram for context
	print("\n  social tiers (live edges): %s" % world.social.tier_histogram(world.sim_day))
	quit(0)
