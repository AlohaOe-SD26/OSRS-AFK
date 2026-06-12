extends SceneTree
## Headless telemetry dump — the remote-friendly equivalent of pressing [E] in the live view.
## Runs a full colony (immigration ON) for a chosen span and prints the same export_log() a player
## would attach, so the build can be diagnosed without opening the GUI. Run:
##   godot --headless --path game --script res://tools/headless_log.gd
## Optional: pass days via the DAYS const below.

const DAYS := 23

func _initialize() -> void:
	var content := ContentDB.new()
	if not content.load_all("res://data"):
		push_error("headless_log: content DB failed to load")
		quit(1)
		return
	var world := SimWorld.new()
	var tele := Telemetry.new(Config.DEFAULT_SEED)
	world.telemetry = tele
	world.setup(content, 6, Config.DEFAULT_SEED)   # founders 6; immigration grows it
	var actions := int(DAYS / SimWorld._DD_PER_ACTION)
	for i in range(actions):
		world.tick(SimWorld._ACTION_SECONDS)
	print(tele.export_log(world))
	quit(0)
