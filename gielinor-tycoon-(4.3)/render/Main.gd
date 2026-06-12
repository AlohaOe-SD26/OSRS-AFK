extends Node2D
## RENDER / UI layer (GDD §21.2). This is the ONLY place that knows about drawing. It holds a
## SimWorld and reads it read-only every frame; it never puts game logic in nodes. Swapping
## this scene out (e.g. headless) leaves the sim untouched — that's the invariant.
##
## Controls (drawn on-screen): [Space] pause · [1/2/4/8] speed · [E] export debug log · click a hero.

const TW := 46.0
const TH := 23.0
const PANEL_W := 366.0

var world: SimWorld
var telemetry: Telemetry
var speed: float = 2.0
var selected: Hero = null
var origin := Vector2(400, 70)
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	var content := ContentDB.new()
	if not content.load_all("res://data"):
		push_error("Main: content DB failed to load — check res://data/*.json")
	telemetry = Telemetry.new(Config.DEFAULT_SEED)
	world = SimWorld.new()
	world.telemetry = telemetry
	world.setup(content, 6, Config.DEFAULT_SEED)
	_update_origin()
	get_viewport().size_changed.connect(_update_origin)
	set_process(true)

func _update_origin() -> void:
	var vp := get_viewport_rect().size
	origin = Vector2((vp.x - PANEL_W) / 2.0, 70.0)

func _process(delta: float) -> void:
	world.tick(delta * speed)
	queue_redraw()

# --------------------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: speed = 0.0
			KEY_1: speed = 1.0
			KEY_2: speed = 2.0
			KEY_4: speed = 4.0
			KEY_8: speed = 8.0
			KEY_E: _export_log()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_hero(event.position)

func _pick_hero(mouse: Vector2) -> void:
	var best: Hero = null
	var bd := 26.0
	for h in world.heroes:
		var p := _iso(h.pos) + Vector2(0, TH / 2.0 - 12.0)
		var d := p.distance_to(mouse)
		if d < bd:
			bd = d
			best = h
	if best != null:
		selected = best

func _export_log() -> void:
	var txt := telemetry.export_log(world)
	var path := "user://debug_log.txt"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		print("Exported debug log → %s (%s)" % [path, ProjectSettings.globalize_path(path)])
	print(txt)

# --------------------------------------------------------------------------- iso helpers
func _iso(tile: Vector2) -> Vector2:
	return origin + Vector2((tile.x - tile.y) * TW / 2.0, (tile.x + tile.y) * TH / 2.0)

func _shade(c: Color, amt: float) -> Color:
	return Color(clampf(c.r + amt, 0, 1), clampf(c.g + amt, 0, 1), clampf(c.b + amt, 0, 1), c.a)

# --------------------------------------------------------------------------- draw
func _draw() -> void:
	_draw_ground()
	# depth-sort props + heroes by (x + y)
	var drawables: Array = []
	for key in world.locations:
		var loc: Dictionary = world.locations[key]
		drawables.append({"d": loc["pos"].x + loc["pos"].y, "fn": "loc", "data": loc})
	for h in world.heroes:
		drawables.append({"d": h.pos.x + h.pos.y + 0.4, "fn": "hero", "data": h})
	drawables.sort_custom(func(a, b): return a["d"] < b["d"])
	for o in drawables:
		if o["fn"] == "loc":
			_draw_location(o["data"])
		else:
			_draw_hero(o["data"])
	_draw_hud()

func _draw_ground() -> void:
	var g := world.grid_size
	var water: Dictionary = world.content.map_data.get("water_tiles", {})
	for x in range(g):
		for y in range(g):
			var f := Color("#3c4a2c")
			if (x + y) % 2 == 1:
				f = Color("#41512f")
			if water.has("x_from") and x >= int(water["x_from"]) and x <= int(water["x_to"]) and y >= int(water["y_from"]) and y <= int(water["y_to"]):
				f = Color("#3a5f78")
			_draw_tile_diamond(Vector2(x, y), f, Color(0, 0, 0, 0.08))

func _draw_tile_diamond(tile: Vector2, fill: Color, stroke: Color) -> void:
	var p := _iso(tile)
	var pts := PackedVector2Array([
		p, p + Vector2(TW / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(-TW / 2.0, TH / 2.0)])
	draw_colored_polygon(pts, fill)
	if stroke.a > 0.0:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), stroke, 1.0)

func _draw_location(loc: Dictionary) -> void:
	var kind: String = loc["kind"]
	var p := _iso(loc["pos"])
	match kind:
		"build":
			_draw_building(p, Color("#7a6a4a"))
		"rocks":
			for i in range(4):
				var ox := 14.0 if i % 2 == 1 else -12.0
				var oy := -2.0 if i < 2 else 8.0
				draw_circle(p + Vector2(ox, TH / 2.0 + oy), 7.0, Color("#6b6b72") if i % 2 == 1 else Color("#54545c"))
		"trees":
			for i in range(3):
				var ox := (i - 1) * 15.0
				draw_rect(Rect2(p.x + ox - 2, p.y + TH / 2.0 - 2, 4, 10), Color("#5a3a22"))
				draw_circle(p + Vector2(ox, TH / 2.0 - 8.0), 11.0, Color("#3f6b39") if i % 2 == 1 else Color("#4d7d44"))
		"water":
			_draw_tile_diamond(loc["pos"], Color("#3a5f78"), Color(0, 0, 0, 0.1))
		_:
			_draw_tile_diamond(loc["pos"], Color("#6b5a3a"), Color("#4a3e26"))
	_label(loc["label"], p + Vector2(0, -8), Color("#e6c87a"))

func _draw_building(p: Vector2, col: Color) -> void:
	var hgt := 30.0
	# left face, right face, roof — a simple iso prism
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-TW / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(0, TH - hgt), p + Vector2(-TW / 2.0, TH / 2.0 - hgt)]), _shade(col, -0.12))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(TW / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(0, TH - hgt), p + Vector2(TW / 2.0, TH / 2.0 - hgt)]), _shade(col, 0.04))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -hgt), p + Vector2(TW / 2.0, TH / 2.0 - hgt), p + Vector2(0, TH - hgt), p + Vector2(-TW / 2.0, TH / 2.0 - hgt)]), _shade(col, 0.12))

func _draw_hero(h: Hero) -> void:
	var p := _iso(h.pos)
	var cx := p.x
	var cy := p.y + TH / 2.0
	draw_circle(Vector2(cx, cy + 2), 9.0, Color(0, 0, 0, 0.3))
	if selected == h:
		draw_arc(Vector2(cx, cy + 2), 13.0, 0, TAU, 24, Color("#e6c87a"), 2.0)
	var body := Color("#ffffff") if h.flash > 0.0 else Color(h.shirt)
	draw_rect(Rect2(cx - 6, cy - 16, 12, 15), body)
	draw_circle(Vector2(cx, cy - 19), 5.2, Color(h.skin))
	draw_circle(Vector2(cx, cy - 21), 5.0, Color(h.hair))
	# HP pip if hurt
	if h.hp < h.max_hp():
		draw_rect(Rect2(cx - 8, cy - 28, 16, 3), Color(0, 0, 0))
		draw_rect(Rect2(cx - 8, cy - 28, 16.0 * maxf(0, float(h.hp) / h.max_hp()), 3), Color("#66cc22"))
	_label(h.hero_name, Vector2(cx, cy - 32), Color("#efe3c4"))
	if h.flash > 0.0:
		h.flash -= 0.05

func _label(text: String, pos: Vector2, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
	draw_string(_font, pos + Vector2(-w / 2.0 + 1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
	draw_string(_font, pos + Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

# --------------------------------------------------------------------------- HUD
func _draw_hud() -> void:
	var vp := get_viewport_rect().size
	var x := vp.x - PANEL_W
	draw_rect(Rect2(x, 0, PANEL_W, vp.y), Color("#1a1814"))
	draw_line(Vector2(x, 0), Vector2(x, vp.y), Color("#4a4338"), 1.0)
	var pad := x + 14.0
	var y := 24.0
	_hud_line("THE COLONY", pad, y, Color("#c9a24b"), 13); y += 22
	_hud_line("Day %d   Heroes %d" % [world.sim_day, world.heroes.size()], pad, y, Color("#cdbf9f")); y += 18
	_hud_line("Total gold  %d" % world.total_gold(), pad, y, Color("#e6c87a")); y += 18
	_hud_line("Ore price %dg   Food %d" % [world.economy.sell_price("ore"), world.economy.total_stock("cooked_fish")], pad, y, Color("#cdbf9f")); y += 26

	_hud_line("HERO PANEL", pad, y, Color("#c9a24b"), 13); y += 20
	if selected != null:
		var h := selected
		_hud_line("%s  · favours %s" % [h.hero_name, SimWorld._cap(h.favorite)], pad, y, Color("#e6c87a")); y += 18
		_hud_line("HP %d/%d   %dg" % [maxi(0, h.hp), h.max_hp(), int(h.gold)], pad, y, Color("#a99c84")); y += 18
		_hud_line("“%s”" % h.thought, pad, y, Color("#d8cba8")); y += 20
		var skl := "ATK %d STR %d DEF %d  MINE %d WC %d FISH %d COOK %d" % [
			h.skill_level("attack"), h.skill_level("strength"), h.skill_level("defence"),
			h.skill_level("mining"), h.skill_level("woodcutting"), h.skill_level("fishing"), h.skill_level("cooking")]
		_hud_line(skl, pad, y, Color("#bcae90"), 10); y += 16
		var bag := "bag: "
		for k in h.inv:
			if int(h.inv[k]) > 0:
				bag += "%d %s  " % [int(h.inv[k]), k]
		_hud_line(bag if bag != "bag: " else "bag: empty", pad, y, Color("#bcae90"), 10); y += 24
	else:
		_hud_line("(click a hero to read their thoughts)", pad, y, Color("#7b7060"), 11); y += 24

	_hud_line("THE CHRONICLE", pad, y, Color("#c9a24b"), 13); y += 20
	for ev in world.chronicle.slice(0, mini(14, world.chronicle.size())):
		_hud_line("%s  %s" % [ev["t"], ev["text"]], pad, y, Color("#cdbf9f"), 10); y += 15

	_hud_line("[Space] pause  [1/2/4/8] speed %dx  [E] export log" % int(speed), pad, vp.y - 16, Color("#7b7060"), 10)

func _hud_line(text: String, x: float, y: float, col: Color, size: int = 12) -> void:
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 28, size, col)
