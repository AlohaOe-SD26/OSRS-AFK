extends Node2D
## RENDER / UI layer (GDD §21.2). This is the ONLY place that knows about drawing. It holds a
## SimWorld and reads it read-only every frame; it never puts game logic in nodes. Swapping
## this scene out (e.g. headless) leaves the sim untouched — that's the invariant.
##
## Controls (drawn on-screen): [Space] pause · [1/2/4/8] speed · [E] export debug log · click a hero.

const TW := 56.0   # tile size up from 46/23 — the city reads bigger on screen (user-requested scale-up)
const TH := 28.0
const PANEL_W := 366.0

var world: SimWorld
var telemetry: Telemetry
var speed: float = 2.0
var selected: Hero = null
var origin := Vector2(400, 70)
var _font: Font
# Hero Panel (§20): tabbed inspection. Default to Thoughts — the legibility win.
const TAB_NAMES := ["Stats", "Thoughts", "Gear", "Social", "Saga"]
var panel_tab: int = 1
var _tab_rects: Array = []   # [{rect:Rect2, idx:int}] computed each draw for click hit-testing
# ONE tabbed menu (player-requested UX): everything lives in a single OVERLAY panel — Colony (stats+town),
# Hero (sub-tabs+commands), Chronicle. It does NOT squish the play field (the map centers on the full
# window; the panel draws on top). Minimizeable, DEFAULT CLOSED; docks right or left (toggle, default right).
const TOP_TABS := ["Colony", "Chronicle"]
var _menu_open: bool = false
var _dock_right: bool = true
var _top_tab: int = 0
# HERO POPUP (independent of the main menu): clicking a hero opens a bottom drawer for THAT hero.
# While open, the camera SNAPS to and FOLLOWS the hero, zoomed ×2 of whatever zoom you were at; a
# slider (with readout) at the top of the popup varies the zoom — floored at the pre-popup zoom
# (can't zoom out past it), capped at 4× it. Closing restores the camera exactly.
const DRAWER_H := 240.0
var _hero_popup: bool = false
var _pp_zoom: float = 2.0          # slider value (the live camera zoom while the popup is open)
var _pp_zoom_min: float = 1.0      # floor = the camera zoom at popup-open time
var _pp_zoom_max: float = 4.0
var _pp_prev_zoom: float = 1.0     # camera state to restore on close
var _pp_prev_cam: Vector2 = Vector2.ZERO
var _zoom_dragging: bool = false
var _zoom_track: Rect2 = Rect2()   # the slider's hit rect (rebuilt each draw)
# Clickable control surfaces (Step 4, §20.2) — the Nudge/Seize hero commands + the town-building /
# incentive buttons. Rebuilt every _draw; hit-tested in _unhandled_input. [{rect, kind, arg}].
var _ui_rects: Array = []
# #4b: hover-tooltips for DISABLED buttons (infeasible nudges). Rebuilt every _draw [{rect, text}];
# drawn last (on top) when the cursor is over a disabled button. `_mouse_pos` tracks the cursor.
var _tips: Array = []
var _mouse_pos: Vector2 = Vector2.ZERO

const SaveLoad := preload("res://sim/SaveLoad.gd")
const SAVE_PATH := "user://save.dat"
var _content: ContentDB

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_content = ContentDB.new()
	if not _content.load_all("res://data"):
		push_error("Main: content DB failed to load — check res://data/*.json")
	telemetry = Telemetry.new(Config.DEFAULT_SEED)
	world = SimWorld.new()
	world.telemetry = telemetry
	world.setup(_content, 6, Config.DEFAULT_SEED)
	_update_origin()
	get_viewport().size_changed.connect(_update_origin)
	set_process(true)
	if "--shot" in OS.get_cmdline_user_args():
		_shot = true
		speed = 8.0   # develop the colony fast before capturing (levels, bonds, immigration)
	elif "--lodshot" in OS.get_cmdline_user_args():
		set_process(false)            # we drive the sim manually; captures at exact population states
		call_deferred("_capture_lod_shots")

# Camera (M1a, ported from the HTML concept): wheel = zoom toward the cursor; middle/right-drag = pan;
# [Home] = re-center. Implemented via draw_set_transform so ALL world drawing (terrain/locs/heroes)
# pans/zooms for free; _iso stays in raw world space; picking transforms hero positions to screen.
var _zoom: float = 1.0
var _cam: Vector2 = Vector2.ZERO
var _panning: bool = false
var _lmb_down: bool = false      # left-drag pan: click selects on RELEASE if no drag happened
var _lmb_dragged: bool = false

func _world_to_screen(p: Vector2) -> Vector2:
	return p * _zoom + _cam

func _update_origin() -> void:
	# world-space origin for the iso projection (matches the concept: x = (gridH+3)·TW/2)
	origin = Vector2((world.grid_h + 3) * TW / 2.0, 48.0)
	_center_camera()

func _center_camera() -> void:
	var vp := get_viewport_rect().size
	var center_world := _iso(Vector2(world.grid_w / 2.0, world.grid_h / 2.0))
	_cam = Vector2(vp.x / 2.0, vp.y / 2.0 - 40.0) - center_world * _zoom

## The open menu's overlay rect (right- or left-docked).
func _panel_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var px := vp.x - PANEL_W if _dock_right else 0.0
	return Rect2(px, TOPBAR_H, PANEL_W, vp.y - TOPBAR_H)

var _shot: bool = false
var _shot_frames: int = 0

func _process(delta: float) -> void:
	world.tick(delta * speed)
	# WASD / arrows: pan the camera — or WALK the hero directly when one is seized in the popup
	var dirv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dirv.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dirv.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dirv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dirv.x += 1.0
	if dirv != Vector2.ZERO:
		if _hero_popup and selected != null and selected.seized:
			# screen-direction → iso tile-direction, short rolling target = direct walking
			var t := Vector2(dirv.x / 2.0 + dirv.y, dirv.y - dirv.x / 2.0).normalized()
			selected.move_target = selected.pos + t * 0.8
		elif not _hero_popup:
			_cam += -dirv * 900.0 * delta
	queue_redraw()
	if _shot:
		_shot_frames += 1
		if _shot_frames == 360:        # ~develop the colony, then capture each tab and quit
			_capture_shots()

func _capture_shots() -> void:
	set_process(false)                 # freeze the sim while we shoot
	if world.heroes.size() > 0:
		# pick a hero with some saga to it (most decisions made)
		var pick: Hero = world.heroes[0]
		for h in world.heroes:
			if h.decisions > pick.decisions:
				pick = h
		selected = pick
	_dock_right = true   # captures must be deterministic — a stray click during the develop window
	_menu_open = false   # must not leak state into what the shots claim to show
	await _snap("shot_0_closed_default")
	_menu_open = true
	_top_tab = 0
	await _snap("shot_1_colony")
	_menu_open = false
	panel_tab = 1
	_open_hero_popup()        # hero popup: camera snaps to the hero at 2×, slider in the header
	await _snap("shot_2_hero_popup")
	_close_hero_popup()
	_menu_open = true
	_top_tab = 1
	await _snap("shot_3_chronicle")
	_dock_right = false
	_top_tab = 0
	await _snap("shot_4_docked_left")
	print("SHOTS SAVED to %s (hero: %s)" % [ProjectSettings.globalize_path("user://"), selected.hero_name if selected else "none"])
	get_tree().quit()

# LOD verification captures (debug, `--lodshot`): fast-forward the sim to the exact states the two LOD
# behaviors flip in, and screenshot each. Checks: (1) label-throttle at the >24-hero boundary (pop 24 = all
# labeled, pop 25 = selected-only); (2) culling engages ONLY for off-screen positions (shrunk window).
func _capture_lod_shots() -> void:
	_lod = true
	while world.heroes.size() < 24:
		world.tick(SimWorld._ACTION_SECONDS)
	selected = world.heroes[0]
	await _snap("lod1_pop24_all_labeled")
	while world.heroes.size() < 25:
		world.tick(SimWorld._ACTION_SECONDS)
	await _snap("lod2_pop25_throttled")
	while world.sim_day < 23:
		world.tick(SimWorld._ACTION_SECONDS)
	await _snap("lod3_scale_on")
	_lod = false
	await _snap("lod4_scale_off")
	_lod = true
	get_window().size = Vector2i(720, 520)   # shrink → parts of the map go off-screen → cull engages
	await RenderingServer.frame_post_draw
	await _snap("lod5_cull_small_window")
	get_window().size = Vector2i(560, 420)   # tiny: map MUST overflow → positively demonstrate the cull
	await RenderingServer.frame_post_draw
	await _snap("lod6_cull_tiny_window")
	print("LOD SHOTS SAVED to %s (pop %d, day %d, culled-at-small %d)" % [ProjectSettings.globalize_path("user://"), world.heroes.size(), world.sim_day, _lod_culled])
	get_tree().quit()

func _snap(shot_name: String) -> void:
	queue_redraw()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://%s.png" % shot_name)

# --------------------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_pos = event.position   # #4b: track the cursor for disabled-button hover-tooltips
		queue_redraw()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: speed = 0.0
			KEY_1: speed = 1.0
			KEY_2: speed = 2.0
			KEY_4: speed = 4.0
			KEY_8: speed = 8.0
			KEY_E: _export_log()
			KEY_L: _lod = not _lod   # toggle render LOD (visual only — never affects the sim)
			KEY_F5:
				# save is a PURE READ of the sim (no chronicle event) — saving can't perturb the run (§25 gate)
				if SaveLoad.save_to_file(world, SAVE_PATH):
					print("Saved → %s" % ProjectSettings.globalize_path(SAVE_PATH))
			KEY_F9:
				var loaded: SimWorld = SaveLoad.load_from_file(_content, SAVE_PATH)
				if loaded != null:
					world = loaded
					world.telemetry = telemetry
					selected = null
					print("Loaded ← %s (day %d, %d heroes)" % [ProjectSettings.globalize_path(SAVE_PATH), world.sim_day, world.heroes.size()])
			KEY_M: _menu_open = not _menu_open
			KEY_R: _roster_open = not _roster_open
			KEY_ESCAPE: _close_hero_popup()
			KEY_HOME:
				_zoom = 1.0
				_center_camera()
			KEY_TAB: panel_tab = (panel_tab + 1) % TAB_NAMES.size()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.12)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_zoom_dragging = false
			if _lmb_down:
				_lmb_down = false
				if not _lmb_dragged:
					# seized hero in the popup: a map click is a MOVE ORDER (walk there); else select
					if _hero_popup and selected != null and selected.seized:
						var w: Vector2 = (event.position - _cam) / _zoom
						var a: float = (w.x - origin.x) / (TW / 2.0)
						var b: float = (w.y - origin.y - TH / 2.0) / (TH / 2.0)
						selected.move_target = Vector2((a + b) / 2.0, (b - a) / 2.0)
					else:
						_pick_hero(event.position)   # a clean click (no drag) selects
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _hero_popup and _zoom_track.has_point(event.position):
				_zoom_dragging = true
				_slider_set(event.position.x)
				return
			if _click_ui(event.position):
				return
			if _click_tab(event.position):
				return
			if _menu_open and _panel_rect().has_point(event.position):
				return   # clicks on the open panel never fall through to the map behind it (it's an overlay)
			if _hero_popup and event.position.y > get_viewport_rect().size.y - DRAWER_H:
				return   # clicks on the popup drawer don't fall through either
			if event.position.y < TOPBAR_H:
				return   # top HUD bar
			if _roster_open and event.position.x < ROSTER_W:
				return   # roster panel (cards are buttons; empty space doesn't pick through)
			# over the map: maybe a click (select on release) or a LEFT-DRAG pan (move > 6px)
			_lmb_down = true
			_lmb_dragged = false
	elif event is InputEventMouseMotion and _zoom_dragging:
		_slider_set(event.position.x)
	elif event is InputEventMouseMotion and (_panning or _lmb_down):
		if _lmb_down and not _lmb_dragged and event.relative.length() < 1.0:
			pass   # jitter below the drag threshold accumulates via _lmb_dragged below
		if _lmb_down:
			_lmb_dragged = true
		_cam += event.relative
		queue_redraw()

## Map a mouse x on the slider track to the popup zoom [floor .. 4×floor].
func _slider_set(mx: float) -> void:
	var t := clampf((mx - _zoom_track.position.x) / maxf(1.0, _zoom_track.size.x), 0.0, 1.0)
	_pp_zoom = lerpf(_pp_zoom_min, _pp_zoom_max, t)
	queue_redraw()

## Zoom toward the cursor (the point under the mouse stays put).
func _zoom_at(mouse: Vector2, factor: float) -> void:
	var nz := clampf(_zoom * factor, 0.45, 3.0)
	_cam = mouse - (mouse - _cam) * (nz / _zoom)
	_zoom = nz
	queue_redraw()

func _click_tab(mouse: Vector2) -> bool:
	if not _hero_popup:
		return false   # hero sub-tabs live in the hero popup now
	for t in _tab_rects:
		if t["rect"].has_point(mouse):
			panel_tab = int(t["idx"])
			return true
	return false

# Step-4 control dispatch (§2/§18.4/§19). Every button routes to a SimWorld control method — the
# render layer issues player intent and the sim core does the work (dual-agency: same systems as the AI).
func _click_ui(mouse: Vector2) -> bool:
	for u in _ui_rects:
		if u["rect"].has_point(mouse):
			_dispatch_ui(u)
			queue_redraw()
			return true
	return false

func _dispatch_ui(u: Dictionary) -> void:
	match String(u["kind"]):
		"noop":
			pass   # #4b: a disabled button absorbs its click (the tooltip already says why it's gated)
		"nudge":
			if selected != null:
				world.nudge_hero(selected, String(u["arg"]))
		"command":
			if selected != null:
				world.command_seized(selected, String(u["arg"]))
		"seize":
			if selected != null:
				world.seize_hero(selected)
		"release":
			if selected != null:
				world.release_hero(selected)
		"upgrade_shop":
			world.upgrade_shop(u["arg"])
		"build":
			world.build(String(u["arg"]))
		"incentive":
			_cycle_incentive(String(u["arg"]))
		"bounty":
			_cycle_bounty(String(u["arg"]))
		"price_bias":
			_cycle_price_bias(String(u["arg"]))
		"kick_vote":
			if selected != null:
				world.start_kick_vote(selected)
		"force_kick":
			if selected != null:
				world.force_kick(selected)
		"menu_open":
			_menu_open = true
		"menu_close":
			_menu_open = false
		"popup_close":
			_close_hero_popup()
		"speed":
			speed = float(u["arg"])
		"unequip":
			if selected != null:
				selected.unequip_slot(String(u["arg"]))
		"equip":
			if selected != null:
				selected.equip_item(String(u["arg"][0]), String(u["arg"][1]))
		"run_toggle":
			if selected != null:
				selected.run_on = not selected.run_on
		"center_cam":
			_zoom = 1.0
			_center_camera()
		"roster_toggle":
			_roster_open = not _roster_open
		"menu_toggle":
			_menu_open = not _menu_open
		"roster":
			selected = u["arg"]
			_open_hero_popup()
		"dock_swap":
			_dock_right = not _dock_right
		"top_tab":
			_top_tab = int(u["arg"])

## Cycle a per-good price bias: 100% → MAX (overpay) → MIN (underpay) → 100% (#3c / B1).
func _cycle_price_bias(good: String) -> void:
	var cur := world.economy.bias_of(good)
	if absf(cur - 1.0) < 0.01:
		world.economy.set_price_bias(good, Config.PRICE_BIAS_MAX)
	elif cur > 1.0:
		world.economy.set_price_bias(good, Config.PRICE_BIAS_MIN)
	else:
		world.economy.set_price_bias(good, 1.0)

## Cycle a funded per-kill bounty: off → 1× → 2× → 3× avg coin drop → off (Unit 0 / R5).
func _cycle_bounty(mon_id: String) -> void:
	var mon: Monster = world.content.monster(mon_id)
	if mon == null:
		return
	var step := world.avg_coin_drop(mon)
	var cur := float(world.bounties.get(mon_id, 0.0))
	world.set_bounty(mon_id, 0.0 if cur >= world.bounty_cap(mon) - 0.01 else cur + step)

## Cycle a posted utility incentive on a GATHER activity: off → one step → max → off (§18.4; FIGHT
## retired per R5 — combat steering is the funded bounty row).
func _cycle_incentive(intent: String) -> void:
	var cur := float(world.incentives.get(intent, 0.0))
	var nxt := 0.0
	if cur <= 0.0:
		nxt = Config.INCENTIVE_STEP
	elif cur < Config.INCENTIVE_MAX:
		nxt = Config.INCENTIVE_MAX
	world.set_incentive(intent, nxt)

func _pick_hero(mouse: Vector2) -> void:
	var best: Hero = null
	var bd := 26.0
	for h in world.heroes:
		var p := _world_to_screen(_iso(h.pos) + Vector2(0, TH / 2.0 - 12.0))
		var d := p.distance_to(mouse)
		if d < bd:
			bd = d
			best = h
	if best != null:
		selected = best
		_open_hero_popup()

## Open (or retarget) the hero popup: bank the camera, set the zoom floor to the CURRENT zoom,
## default the slider to ×2 of it. The camera follow happens each frame in _draw.
func _open_hero_popup() -> void:
	if not _hero_popup:
		_pp_prev_zoom = _zoom
		_pp_prev_cam = _cam
		_pp_zoom_min = _zoom
		_pp_zoom_max = _zoom * 4.0
		_pp_zoom = minf(_zoom * 2.0, _pp_zoom_max)
	_hero_popup = true

func _close_hero_popup() -> void:
	if not _hero_popup:
		return
	_hero_popup = false
	_zoom = _pp_prev_zoom
	_cam = _pp_prev_cam
	queue_redraw()

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
# LOD (§22.3 / §18.6, Step 6) — RENDER-ONLY scaling for ~50 heroes. Two cheap wins, both purely visual:
#  (1) viewport CULL — skip drawables whose iso screen position is outside the play area (off-screen heroes
#      cost nothing to draw); (2) LABEL THROTTLE — name labels (draw_string) are the per-hero draw cost, so
#      at scale only the selected hero is labelled. CRITICAL INVARIANT: LOD reads sim read-only and writes
#      NOTHING to sim state → it cannot change sim outcomes (the byte-identical gate; the sim never sees `_lod`).
var _lod: bool = true

func _in_view(screen: Vector2, play_w: float, vp: Vector2) -> bool:
	const M := 48.0   # margin so partially-on-screen sprites still draw
	return screen.x >= -M and screen.x <= play_w + M and screen.y >= -M and screen.y <= vp.y + M

func _draw() -> void:
	var vp := get_viewport_rect().size
	# hero-popup camera: follow the selected hero, zoomed per the popup slider, centered in the
	# visible area above the drawer. Restored exactly on close.
	if _hero_popup and selected != null:
		_zoom = _pp_zoom
		var focus := _iso(selected.pos) + Vector2(0, TH / 2.0)
		_cam = Vector2(vp.x / 2.0, (vp.y - DRAWER_H) / 2.0) - focus * _zoom
	# WORLD PASS under the camera transform (pan + zoom apply to everything drawn until reset)
	draw_set_transform(_cam, 0.0, Vector2(_zoom, _zoom))
	_draw_ground()
	# depth-sort props + heroes by (x + y); cull off-screen under LOD (screen-space test — live when zoomed)
	var drawables: Array = []
	for key in world.locations:
		var loc: Dictionary = world.locations[key]
		if not _lod or _in_view(_world_to_screen(_iso(loc["pos"])), vp.x, vp):
			drawables.append({"d": loc["pos"].x + loc["pos"].y, "fn": "loc", "data": loc})
	for r in world.monsters:
		if r.alive and (not _lod or _in_view(_world_to_screen(_iso(r.pos)), vp.x, vp)):
			drawables.append({"d": r.pos.x + r.pos.y + 0.3, "fn": "rat", "data": r})
	var culled := 0
	for h in world.heroes:
		if not _lod or _in_view(_world_to_screen(_iso(h.pos)), vp.x, vp):
			drawables.append({"d": h.pos.x + h.pos.y + 0.4, "fn": "hero", "data": h})
		else:
			culled += 1
	drawables.sort_custom(func(a, b): return a["d"] < b["d"])
	# label only the selected hero when LOD is on and the colony is crowded (draw_string is the per-hero cost)
	var label_all := not _lod or world.heroes.size() <= 24
	for o in drawables:
		match o["fn"]:
			"loc": _draw_location(o["data"])
			"rat": _draw_rat(o["data"])
			_: _draw_hero(o["data"], label_all or o["data"] == selected)
	_lod_culled = culled
	_draw_projectiles()
	# HUD PASS in screen space
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud()

## Ranged/magic projectiles (visual layer): arrows fly flat & fast; fireballs travel with a pulsing
## glow + ember trail. Timing is per-hero phase-offset so volleys don't synchronize.
func _draw_projectiles() -> void:
	var ms := Time.get_ticks_msec() / 1000.0
	# dark wizards CAST at whoever is fighting them — purple bolt with a fading trail
	for m in world.monsters:
		if not m.alive or String(m.type_id) != "dark_wizard":
			continue
		var foe: Hero = null
		var fd := 4.5
		for h2 in world.heroes:
			if h2.act.get("phase", "") == "fight" and String(h2.act.get("loc", "")) == m.camp:
				var d2: float = h2.pos.distance_to(m.pos)
				if d2 < fd:
					fd = d2
					foe = h2
		if foe == null:
			continue
		var wa := _iso(m.pos) + Vector2(7, -10)
		var wb := _iso(foe.pos) + Vector2(0, -8)
		var wt := fmod(ms * 1.6 + m.pos.x * 0.7, 1.0)
		var wp := wa.lerp(wb, wt)
		draw_circle(wp, 4.0, Color(0.55, 0.3, 0.95, 0.3))
		draw_circle(wp, 2.2, Color("#b48ae0"))
		draw_circle(wa.lerp(wb, maxf(0.0, wt - 0.1)), 1.4, Color(0.55, 0.3, 0.95, 0.35))
	for h in world.heroes:
		if h.act.get("phase", "") != "fight" or h.weapon == "sword":
			continue
		var best = null
		var bd := 1e9
		for m in world.monsters:
			if m.alive:
				var d: float = h.pos.distance_to(m.pos)
				if d < bd:
					bd = d
					best = m
		if best == null or bd > 6.0:
			continue
		var a := _iso(h.pos) + Vector2(6, -8)
		var b := _iso(best.pos) + Vector2(0, TH / 2.0 - 4.0)
		var t := fmod(ms * (2.2 if h.weapon == "bow" else 1.4) + h.id * 0.37, 1.0)
		var p := a.lerp(b, t)
		if h.weapon == "bow":
			var dirv := (b - a).normalized()
			draw_line(p - dirv * 5.0, p + dirv * 3.0, Color("#d8ccb4"), 1.4)   # shaft
			draw_line(p + dirv * 3.0, p + dirv * 5.5, Color("#9a9aa4"), 2.2)   # head
		else:
			var pulse := 0.7 + sin(ms * 9.0 + h.id) * 0.3
			draw_circle(p, 5.5 * pulse, Color(1.0, 0.45, 0.1, 0.22))           # outer glow (pulsates)
			draw_circle(p, 3.2, Color(1.0, 0.55, 0.15, 0.9))                   # fireball core
			draw_circle(p, 1.6, Color(1.0, 0.85, 0.4))                         # hot center
			draw_circle(a.lerp(b, maxf(0.0, t - 0.12)), 1.8, Color(1.0, 0.4, 0.1, 0.35))  # ember trail

var _lod_culled: int = 0

func _draw_rat(r) -> void:
	var p := _iso(r.pos)
	var cx := p.x
	var cy := p.y + TH / 2.0
	draw_circle(Vector2(cx, cy + 1), 7.0, Color(0, 0, 0, 0.3))
	match String(r.type_id):
		"dark_wizard":
			# player-like robed figure: dark robe, skin head, pointed wizard hat, glowing hands
			var ms := Time.get_ticks_msec() / 1000.0
			draw_rect(Rect2(cx - 6, cy - 16, 12, 16), Color("#2a1a3e"))            # robe
			draw_rect(Rect2(cx - 7, cy - 4, 14, 4), Color("#1e1230"))              # robe hem
			draw_circle(Vector2(cx, cy - 19), 5.0, Color("#c98d5e"))               # head
			# wizard hat: brim + tall point
			draw_rect(Rect2(cx - 7, cy - 24, 14, 3), Color("#1a1028"))
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 5, cy - 24), Vector2(cx + 5, cy - 24), Vector2(cx + 1, cy - 34)]), Color("#241438"))
			draw_circle(Vector2(cx + 1, cy - 34), 1.5, Color("#b48ae0"))           # hat tip glow
			# casting hands — pulsing dark-magic glow
			var pulse := 0.5 + sin(ms * 5.0 + r.pos.x) * 0.5
			draw_circle(Vector2(cx + 7, cy - 8), 2.5 + pulse, Color(0.55, 0.35, 0.9, 0.5))
			draw_circle(Vector2(cx + 7, cy - 8), 1.4, Color("#b48ae0"))
		"barbarian":
			# burly player-like figure: bare chest, war-paint, horned helm, axe at the side
			draw_rect(Rect2(cx - 7, cy - 15, 14, 15), Color("#b07a52"))            # torso (bare)
			draw_rect(Rect2(cx - 7, cy - 6, 14, 6), Color("#5a3a22"))              # hide kilt
			draw_line(Vector2(cx - 5, cy - 12), Vector2(cx + 5, cy - 10), Color("#8c2f2a"), 2.0)  # war-paint
			draw_circle(Vector2(cx, cy - 18), 5.0, Color("#c98d5e"))               # head
			draw_rect(Rect2(cx - 5, cy - 23, 10, 3), Color("#6a6a72"))             # helm band
			draw_line(Vector2(cx - 5, cy - 23), Vector2(cx - 8, cy - 28), Color("#e8e0d0"), 2.0)  # horns
			draw_line(Vector2(cx + 5, cy - 23), Vector2(cx + 8, cy - 28), Color("#e8e0d0"), 2.0)
			draw_line(Vector2(cx + 8, cy - 2), Vector2(cx + 12, cy - 12), Color("#8a6a3a"), 2.0)  # axe haft
			draw_rect(Rect2(cx + 10, cy - 15, 5, 4), Color("#c8c8d0"))             # axe head
		"goblin":
			# small green humanoid with pointy ears and a crude club
			draw_rect(Rect2(cx - 4, cy - 9, 8, 9), Color("#5a7d3f"))               # body
			draw_circle(Vector2(cx, cy - 12), 4.0, Color("#6b8e4a"))               # head
			draw_line(Vector2(cx - 4, cy - 13), Vector2(cx - 7, cy - 15), Color("#6b8e4a"), 2.0)  # ears
			draw_line(Vector2(cx + 4, cy - 13), Vector2(cx + 7, cy - 15), Color("#6b8e4a"), 2.0)
			draw_circle(Vector2(cx - 1.5, cy - 12.5), 0.9, Color("#d6604a"))       # eyes
			draw_circle(Vector2(cx + 1.5, cy - 12.5), 0.9, Color("#d6604a"))
			draw_line(Vector2(cx + 5, cy - 4), Vector2(cx + 9, cy - 10), Color("#6a4a2a"), 2.5)   # club
		"chicken":
			draw_circle(Vector2(cx, cy - 4), 5.0, Color("#e8e0d0"))
			draw_circle(Vector2(cx + 4, cy - 7), 2.5, Color("#f0e8d8"))
			draw_line(Vector2(cx + 6, cy - 7), Vector2(cx + 9, cy - 6), Color("#d6a04a"), 2.0)   # beak
		"cow":
			draw_circle(Vector2(cx, cy - 5), 8.0, Color("#e8e2d4"))
			draw_circle(Vector2(cx - 3, cy - 6), 3.5, Color("#3a3026"))             # patch
			draw_circle(Vector2(cx + 7, cy - 4), 3.5, Color("#d8d2c4"))             # head
		_:
			draw_circle(Vector2(cx, cy - 4), 7.0, Color("#6e6258"))
			draw_circle(Vector2(cx + 6, cy - 5), 3.0, Color("#7d7066"))
	if r.hp < r.max_hp:
		draw_rect(Rect2(cx - 8, cy - 14, 16, 3), Color(0, 0, 0))
		draw_rect(Rect2(cx - 8, cy - 14, 16.0 * (float(r.hp) / r.max_hp), 3), Color("#cc3333"))

# Canon Varrock terrain (M1a, ported from the HTML concept's bakeTerrain): district floors (city stone /
# Barbarian Village / palace / GE plaza), the River Lum with bridges, the road net, deterministic deco
# trees, the city wall (with gate gaps) and the GE ring. All data-driven from map.json "terrain".
func _t_in_rect(x: int, y: int, r: Dictionary) -> bool:
	return x >= int(r["x0"]) and x <= int(r["x1"]) and y >= int(r["y0"]) and y <= int(r["y1"])

func _t_in_segs(x: int, y: int, segs: Array) -> bool:
	for s in segs:
		if _t_in_rect(x, y, s):
			return true
	return false

static func _deco_hash(x: int, y: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	return float(h % 1000) / 1000.0

func _ell(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)

func _draw_ground() -> void:
	var terr: Dictionary = world.content.map_data.get("terrain", {})
	var city: Dictionary = terr.get("city", {})
	var barb: Dictionary = terr.get("barb", {})
	var pal: Dictionary = terr.get("palace", {})
	var ge: Dictionary = terr.get("ge", {})
	var river: Array = terr.get("river", [])
	var bridges: Array = terr.get("bridges", [])
	var roads: Array = terr.get("roads", [])
	for x in range(world.grid_w):
		for y in range(world.grid_h):
			var odd := (x + y) % 2 == 1
			var f: Color
			var on_river := _t_in_segs(x, y, river)
			var on_bridge := _t_in_segs(x, y, bridges)
			var on_road := _t_in_segs(x, y, roads)
			var grass := false
			if on_river and not on_bridge:
				f = Color("#3a5a7a") if odd else Color("#34526f")
			elif on_bridge and on_river:
				f = Color("#6a5236")
			elif not ge.is_empty() and Vector2(x - float(ge["x"]), y - float(ge["y"])).length() < float(ge["r"]):
				f = Color("#8a7d62") if odd else Color("#82765c")
			elif not pal.is_empty() and _t_in_rect(x, y, pal):
				f = Color("#7d7d88") if odd else Color("#75757f")
			elif not city.is_empty() and _t_in_rect(x, y, city):
				f = Color("#4a4438") if odd else Color("#46402f")
			elif not barb.is_empty() and _t_in_rect(x, y, barb):
				f = Color("#5a4a34") if odd else Color("#54452f")
			elif on_road:
				f = Color("#5e5038") if odd else Color("#584b34")
			else:
				f = Color("#3b4527") if odd else Color("#374023")
				grass = true
			_draw_tile_diamond(Vector2(x, y), f, Color(0, 0, 0, 0.07))
			# scattered wilderness trees (deterministic deco, outside town, off roads)
			if grass and not on_road and _deco_hash(x, y) < 0.085:
				var p := _iso(Vector2(x, y))
				var cx := p.x
				var cy := p.y + TH / 2.0
				draw_rect(Rect2(cx - 1.5, cy - 2, 3, 7), Color("#3c2a16"))
				_ell(Vector2(cx, cy - 7), 7, 8, Color("#3f6b39") if _deco_hash(x + 7, y) < 0.5 else Color("#48763f"))
	# city wall with gate gaps
	if not city.is_empty():
		var gaps: Dictionary = terr.get("wall_gaps", {})
		var wc := Color("#7a7060")
		var x0 := float(city["x0"]); var x1 := float(city["x1"])
		var y0 := float(city["y0"]); var y1 := float(city["y1"])
		var gn: Array = gaps.get("n", [x0, x0]); var gs: Array = gaps.get("s", [x0, x0])
		var gw: Array = gaps.get("w", [y0, y0]); var ge2: Array = gaps.get("e", [y0, y0])
		_wall(Vector2(x0, y0), Vector2(float(gn[0]), y0), wc); _wall(Vector2(float(gn[1]), y0), Vector2(x1, y0), wc)
		_wall(Vector2(x0, y1), Vector2(float(gs[0]), y1), wc); _wall(Vector2(float(gs[1]), y1), Vector2(x1, y1), wc)
		_wall(Vector2(x0, y0), Vector2(x0, float(gw[0])), wc); _wall(Vector2(x0, float(gw[1])), Vector2(x0, y1), wc)
		_wall(Vector2(x1, y0), Vector2(x1, float(ge2[0])), wc); _wall(Vector2(x1, float(ge2[1])), Vector2(x1, y1), wc)
	# GE ring
	if not ge.is_empty():
		var gc := _iso(Vector2(float(ge["x"]), float(ge["y"]))) + Vector2(0, TH / 2.0)
		var rx: float = float(ge["r"]) * TW / 2.0 * 1.06
		var ry: float = float(ge["r"]) * TH / 2.0 * 1.06
		var ring := PackedVector2Array()
		for i in range(33):
			var a := TAU * i / 32.0
			ring.append(gc + Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(ring, Color("#9a8d6a"), 3.0)

func _wall(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(_iso(a), _iso(b), col, 5.0)

func _draw_tile_diamond(tile: Vector2, fill: Color, stroke: Color) -> void:
	var p := _iso(tile)
	var pts := PackedVector2Array([
		p, p + Vector2(TW / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(-TW / 2.0, TH / 2.0)])
	draw_colored_polygon(pts, fill)
	if stroke.a > 0.0:
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), stroke, 1.0)

## Iso prism (3-face box) — the concept's `box()` helper: w = footprint width, hgt = wall height.
func _box(p: Vector2, w: float, hgt: float, col: Color) -> void:
	var h2 := hgt * 0.4
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-w / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(0, TH - h2), p + Vector2(-w / 2.0, TH / 2.0 - h2)]), _shade(col, -0.13))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(w / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(0, TH - h2), p + Vector2(w / 2.0, TH / 2.0 - h2)]), _shade(col, -0.04))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, TH - h2 - TH / 2.0), p + Vector2(w / 2.0, TH / 2.0 - h2), p + Vector2(0, TH - h2), p + Vector2(-w / 2.0, TH / 2.0 - h2)]), _shade(col, 0.10))

func _draw_location(loc: Dictionary) -> void:
	var kind: String = loc["kind"]
	var p := _iso(loc["pos"])
	var cx := p.x
	var cy := p.y + TH / 2.0
	var lbl_col := Color("#e6c87a")
	var lbl_y := -8.0
	match kind:
		"bank":
			_box(p, TW * 0.62, 26, Color("#7a6a4a")); lbl_col = Color("#ffd24a"); lbl_y = -12.0
		"palace":
			_box(p, TW * 1.1, 40, Color("#8c8c96")); lbl_col = Color("#ffd24a"); lbl_y = -26.0
		"shop":
			_box(p, TW * 0.62, 20, Color("#8a6a3a")); lbl_col = Color("#e8d8a8")
		"altar":
			_box(p, TW * 0.62, 22, Color("#9a9ab0")); lbl_col = Color("#cfe0ff"); lbl_y = -10.0
		"range":
			_box(p, TW * 0.5, 16, Color("#8c5a3a")); lbl_col = Color("#f0b070"); lbl_y = -6.0
			# the item being cooked appears ON the range while a cook is working it
			for h in world.heroes:
				if h.pos.distance_to(loc["pos"]) < 1.4 and (String(h.act.get("then", "")) == "cook" or int(h.inv.get("raw_trout", 0)) > 0):
					_ell(Vector2(cx, cy - 8), 6, 3, Color("#2c261d"))
					_ell(Vector2(cx, cy - 9), 3, 1.6, Color("#e8a050"))
					break
		"anvil":
			_box(p, TW * 0.5, 16, Color("#6a6a72")); lbl_col = Color("#cfcad0"); lbl_y = -6.0
		"tavern":
			_box(p, TW * 0.62, 20, Color("#7a4a5a")); lbl_col = Color("#f0c0d0")
		"gate":
			_box(p, TW * 0.5, 18, Color("#6a6052")); lbl_col = Color("#d8b87a")
		"hole":
			_ell(Vector2(cx, cy), 13, 7, Color("#15110c")); _ell(Vector2(cx, cy), 10, 5, Color("#000000"))
			lbl_col = Color("#9a8f7a"); lbl_y = -4.0
		"ge":
			_box(p, TW * 0.5, 18, Color("#4a4438")); lbl_col = Color("#7a7264")   # locked until the GE unlocks
		"fountain":
			_ell(Vector2(cx, cy), 14, 7, Color("#8a8d96")); _ell(Vector2(cx, cy), 9, 4.5, Color("#3a5a7a"))
			_ell(Vector2(cx, cy - 4), 3, 4, Color("#9fc0e0")); lbl_col = Color("#cfe0ff"); lbl_y = -14.0
		"portal":
			_ell(Vector2(cx, cy - 8), 9, 14, Color("#7a4ae0")); _ell(Vector2(cx, cy - 8), 5, 9, Color("#b48ae0"))
			lbl_col = Color("#d0b8ff"); lbl_y = -22.0
		"circle":
			for i in range(5):
				var a := TAU * i / 5.0
				_ell(Vector2(cx + cos(a) * 16.0, cy + sin(a) * 8.0), 4, 6, Color("#5a5a66"))
			lbl_col = Color("#c0a8e0"); lbl_y = -10.0
		"grass":
			_ell(Vector2(cx, cy), 16, 8, Color("#41502b")); lbl_col = Color("#aac890"); lbl_y = -4.0
		"rocks":
			for i in range(4):
				var ox := 13.0 if i % 2 == 1 else -11.0
				var oy := -2.0 if i < 2 else 7.0
				_ell(Vector2(cx + ox, cy + oy), 8, 5, Color("#6b6b72") if i % 2 == 1 else Color("#54545c"))
			lbl_col = Color("#cfcad0")
		"trees":
			for i in range(3):
				var ox := (i - 1) * 15.0
				var oy := (i % 2) * 7.0
				draw_rect(Rect2(cx + ox - 2, cy - 3 + oy, 4, 10), Color("#4a3018"))
				_ell(Vector2(cx + ox, cy - 9 + oy), 10, 11, Color("#3f6b39") if i % 2 == 1 else Color("#4d7d44"))
			lbl_col = Color("#9fd08f"); lbl_y = -12.0
		"water":
			for i in range(3):
				_draw_tile_diamond(Vector2(loc["pos"].x, loc["pos"].y + i - 1), Color("#3a5a7a"), Color("#2c4660"))
			lbl_col = Color("#9fd0f0"); lbl_y = -6.0
		"build":
			_draw_building(p, Color("#7a6a4a"))
		"npc":
			# a standing armoured figure (Vannaka: tall warrior, full helm — WORLD §1)
			draw_rect(Rect2(cx - 3, cy - 16, 6, 12), Color("#6a6e78"))
			_ell(Vector2(cx, cy - 18), 3.5, 3.5, Color("#8a8e98"))
			_ell(Vector2(cx, cy), 7, 3, Color("#211c14"))
			lbl_col = Color("#e07a5a"); lbl_y = -26.0
		_:
			_draw_tile_diamond(loc["pos"], Color("#6b5a3a"), Color("#4a3e26"))
	_label(loc["label"], p + Vector2(0, lbl_y), lbl_col)

func _draw_building(p: Vector2, col: Color) -> void:
	var hgt := 30.0
	# left face, right face, roof — a simple iso prism
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-TW / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(0, TH - hgt), p + Vector2(-TW / 2.0, TH / 2.0 - hgt)]), _shade(col, -0.12))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(TW / 2.0, TH / 2.0), p + Vector2(0, TH), p + Vector2(0, TH - hgt), p + Vector2(TW / 2.0, TH / 2.0 - hgt)]), _shade(col, 0.04))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -hgt), p + Vector2(TW / 2.0, TH / 2.0 - hgt), p + Vector2(0, TH - hgt), p + Vector2(-TW / 2.0, TH / 2.0 - hgt)]), _shade(col, 0.12))

func _draw_hero(h: Hero, labeled: bool = true) -> void:
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
	# armor visuals (M3a): equipped pieces drawn ON the body — helm over the hair, plate over the shirt
	var torso := String(h.equipped.get("torso", ""))
	if torso != "":
		var pc := Color("#b8b8c2") if torso.begins_with("Iron") else Color("#8a6a4a")
		draw_rect(Rect2(cx - 6, cy - 16, 12, 9), pc)
		draw_rect(Rect2(cx - 6, cy - 16, 12, 15), pc.darkened(0.35), false, 1.0)
	var head_i := String(h.equipped.get("head", ""))
	if head_i != "":
		draw_circle(Vector2(cx, cy - 22), 4.6, Color("#b8b8c2") if head_i.begins_with("Iron") else Color("#8a6a4a"))
	_draw_held(h, cx, cy)   # weapon (worn/in-use) + activity tool — gear visible on the character
	if labeled:   # LOD throttles name labels (draw_string is the per-hero cost) — purely visual
		_label(h.hero_name, Vector2(cx, cy - 32), Color("#efe3c4"))
	# NOTE: h.flash is a sim→render cosmetic signal (sim sets it on hit/eat; render fades it). It feeds NO
	# sim decision, so culling a hero's draw under LOD cannot change any sim outcome (byte-identical gate).
	if h.flash > 0.0:
		h.flash -= 0.05

## Weapon + tool visuals (M1c). The WEAPON is always worn (right side); fighting poses it raised.
## TOOLS show while the activity runs: pickaxe (mining), axe (woodcutting), rod+line (fishing).
func _draw_held(h: Hero, cx: float, cy: float) -> void:
	var fighting: bool = h.act.get("phase", "") == "fight"
	var phase0: String = h.act.get("phase", "")
	var skilling: bool = phase0 == "gather" or phase0 == "fish"
	var ms := Time.get_ticks_msec() / 1000.0
	# FACING: gear draws on the side the hero faces (toward their movement target — 8-dir read)
	var face := 1.0
	if h.move_target != null:
		var dx: float = (_iso(h.move_target) - _iso(h.pos)).x
		if absf(dx) > 0.5:
			face = signf(dx)
	cx += (face - 1.0) * 7.0   # mirrors the weapon/tool cluster to the facing side
	var tilt := (-0.5 + sin(ms * 6.0 + h.id * 1.7) * 0.55) if fighting else 0.25
	# RuneScape rule: while SKILLING weapons are put away — only the tool in use shows
	var shown_weapon := "" if skilling else h.weapon
	match shown_weapon:
		"sword":
			var a := Vector2(cx + 7, cy - 6)
			var dirv := Vector2(cos(tilt), sin(tilt) - 1.0).normalized()
			draw_line(a, a + dirv * 13.0, Color("#d8d8e0"), 2.4)             # blade
			draw_line(a, a + dirv * 13.0, Color("#9a9aa8"), 1.0)             # edge highlight
			draw_line(a + dirv * 2.5 + Vector2(-3, 1.8), a + dirv * 2.5 + Vector2(3, -1.8), Color("#c9a24b"), 2.2)  # gold crossguard
			draw_circle(a - dirv * 2.0, 1.6, Color("#c9a24b"))               # pommel
		"bow":
			var c := Vector2(cx + 8, cy - 9)
			draw_arc(c, 7.5, -1.25 + tilt, 1.25 + tilt, 12, Color("#8a6a3a"), 2.4)
			var s1 := c + Vector2(cos(-1.25 + tilt), sin(-1.25 + tilt)) * 7.5
			var s2 := c + Vector2(cos(1.25 + tilt), sin(1.25 + tilt)) * 7.5
			var pull := (sin(ms * 6.0 + h.id) * 2.0 - 1.0) if fighting else 0.0
			draw_line(s1, c + Vector2(-2.0 + pull, 0), Color("#e8e0cc"), 1.0)  # drawn string
			draw_line(s2, c + Vector2(-2.0 + pull, 0), Color("#e8e0cc"), 1.0)
		"staff":
			draw_line(Vector2(cx + 8, cy + 2), Vector2(cx + 7, cy - 16), Color("#6a4a2a"), 2.4)
			draw_line(Vector2(cx + 8, cy + 2), Vector2(cx + 7, cy - 16), Color("#8a6238"), 1.0)
			var orb := Vector2(cx + 7, cy - 18)
			var pulse := 0.6 + sin(ms * 5.0 + h.id) * 0.4
			draw_circle(orb, 4.5, Color(0.7, 0.4, 1.0, 0.25 * pulse))        # outer glow (pulsates)
			draw_circle(orb, 2.6, Color("#b48ae0") if fighting else Color("#7fb6d9"))
	# activity tool (usable, not equipable) — ANIMATED while the skill runs (swing arcs / rod bob)
	var intent: String = h.act.get("intent", "")
	var phase: String = h.act.get("phase", "")
	var sw := sin(ms * 5.5 + h.id * 2.1)   # per-hero phase so crews don't swing in unison
	if phase == "gather" and intent == "GATHER_ORE":
		var hd := Vector2(cx - 13 + sw * 2.5, cy - 13 + absf(sw) * 4.0)   # pick head arcs down on the strike
		draw_line(Vector2(cx - 7, cy - 4), hd, Color("#8a6a3a"), 2.0)
		draw_arc(hd + Vector2(-1, -1), 4.0, 0.6, 3.2, 6, Color("#9a9aa4"), 2.5)
	elif phase == "gather" and intent == "GATHER_LOGS":
		var hd2 := Vector2(cx - 13 + sw * 3.0, cy - 13 + absf(sw) * 3.5)  # axe chop arc
		draw_line(Vector2(cx - 7, cy - 4), hd2, Color("#8a6a3a"), 2.0)
		draw_rect(Rect2(hd2.x - 4, hd2.y - 3, 5, 4), Color("#c8c8d0"))
	elif phase == "fish":
		var bob := sw * 1.6
		draw_line(Vector2(cx - 6, cy - 4), Vector2(cx - 15, cy - 15 + bob * 0.4), Color("#8a6a3a"), 1.5)
		draw_line(Vector2(cx - 15, cy - 15 + bob * 0.4), Vector2(cx - 17, cy + 2 + bob), Color("#d8ccb4"), 0.8)
		draw_circle(Vector2(cx - 17, cy + 3 + bob), 1.2, Color("#7fb6d9"))

func _label(text: String, pos: Vector2, col: Color) -> void:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
	draw_string(_font, pos + Vector2(-w / 2.0 + 1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
	draw_string(_font, pos + Vector2(-w / 2.0, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

# --------------------------------------------------------------------------- HUD
func _draw_hud() -> void:
	_ui_rects.clear()
	_tips.clear()
	var vp := get_viewport_rect().size
	if selected != null and not world.heroes.has(selected):
		selected = null   # the selected hero was exiled / departed — clear the stale reference
		_close_hero_popup()

	# concept-style top HUD bar (title · clock · stat chips · speed buttons · roster/menu) + help line
	_draw_topbar(vp)
	_draw_roster(vp)
	_hud_line("[M] menu  [R] roster  [Space] pause  [wheel] zoom  [RMB-drag] pan  [Home] center  [E] log  [L] LOD %s%s  [F5/F9] save/load" % ["on" if _lod else "off", ("  (%d culled)" % _lod_culled) if _lod and _lod_culled > 0 else ""], (ROSTER_W + 12.0) if _roster_open else 14.0, vp.y - 14, Color("#7b7060"), 10)

	if not _menu_open:
		_draw_hero_popup(vp)
		_draw_tooltips()
		return

	# OPEN: the single tabbed overlay (drawn over the map, never squishing it)
	var pr := _panel_rect()
	draw_rect(pr, Color("#1a1814", 0.97))
	draw_line(Vector2(pr.position.x if _dock_right else pr.end.x, 0), Vector2(pr.position.x if _dock_right else pr.end.x, vp.y), Color("#4a4338"), 1.0)
	var pad := pr.position.x + 14.0
	var y := pr.position.y + 22.0
	# header: title + dock-side toggle + close
	_hud_line("TOWN LEDGER", pad, y, Color("#c9a24b"), 13)
	var bx := pr.end.x - 130.0
	bx = _button("side: %s" % ("R" if _dock_right else "L"), bx, y, "dock_swap", "", false)
	_button("X close", bx, y, "menu_close", "", false)
	y += 22
	# top tabs — ONE interface for everything
	var tx := pad
	for i in range(TOP_TABS.size()):
		tx = _button(TOP_TABS[i], tx, y, "top_tab", i, i == _top_tab)
	y += 24
	match _top_tab:
		0: _menu_colony(pad, y)
		_: _menu_chronicle(pad, y)
	_draw_hero_popup(vp)   # the hero popup is independent — drawn on top of everything
	_draw_tooltips()

# ---- the three top-level menu tabs ----
# ---- concept-style top HUD bar + left hero roster ----
const TOPBAR_H := 44.0
const ROSTER_W := 196.0
var _roster_open: bool = true

func _draw_topbar(vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, TOPBAR_H), Color("#3a342a"))
	draw_line(Vector2(0, TOPBAR_H), Vector2(vp.x, TOPBAR_H), Color("#1c1813"), 2.0)
	_hud_line("GIELINOR TYCOON", 12.0, 27.0, Color("#ffd24a"), 15)
	_hud_line("Day %d  %02d:%02d" % [world.sim_day, int(world.sim_clock / 60.0) % 24, int(world.sim_clock) % 60], 168.0, 27.0, Color("#a89a80"), 11)
	var x := 268.0
	for chip in [["Gold %d" % world.total_gold(), "#ffd24a"], ["Treasury %d" % int(world.economy.treasury), "#e6c87a"],
		["Pop %d/%d" % [world.heroes.size(), Config.POP_CAP], "#cdbf9f"], ["Rep %d" % int(world.population.reputation), "#cdbf9f"]]:
		var w := _font.get_string_size(String(chip[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14.0
		draw_rect(Rect2(x, 12, w, 20), Color("#272219"))
		_hud_line(String(chip[0]), x + 7.0, 26.0, Color(String(chip[1])), 11)
		x += w + 8.0
	# speed buttons + roster/menu toggles (right end)
	var bx := vp.x - 388.0
	for sp in [["||", 0.0], ["1x", 1.0], ["2x", 2.0], ["4x", 4.0], ["8x", 8.0]]:
		bx = _button(String(sp[0]), bx, 26.0, "speed", float(sp[1]), absf(speed - float(sp[1])) < 0.01)
	bx += 8.0
	bx = _button("Center", bx, 26.0, "center_cam", "", false)
	bx = _button("Roster [R]", bx, 26.0, "roster_toggle", "", _roster_open)
	_button("Menu [M]", bx, 26.0, "menu_toggle", "", _menu_open)

func _draw_roster(vp: Vector2) -> void:
	if not _roster_open:
		return
	draw_rect(Rect2(0, TOPBAR_H, ROSTER_W, vp.y - TOPBAR_H), Color("#332c22", 0.95))
	draw_line(Vector2(ROSTER_W, TOPBAR_H), Vector2(ROSTER_W, vp.y), Color("#1c1813"), 2.0)
	var y := TOPBAR_H + 18.0
	_hud_line("HEROES (%d)" % world.heroes.size(), 10.0, y, Color("#c9a24b"), 12)
	y += 10.0
	var card_h := 34.0
	var max_cards := int((vp.y - y - 26.0) / card_h)
	var shown := 0
	for h in world.heroes:
		if shown >= max_cards:
			_hud_line("+%d more…" % (world.heroes.size() - shown), 10.0, y + 14.0, Color("#7b7060"), 10)
			break
		var r := Rect2(4, y, ROSTER_W - 10, card_h - 3)
		draw_rect(r, Color("#3a3326") if h == selected else Color("#272219"))
		if h == selected:
			draw_rect(r, Color("#c9a24b"), false, 1.0)
		draw_circle(Vector2(18, y + 15), 8.0, Color(h.shirt))
		draw_circle(Vector2(18, y + 9), 5.0, Color(h.skin))
		_hud_line(h.hero_name, 32.0, y + 13.0, Color("#e6c87a") if h == selected else Color("#d8ccb4"), 11)
		_hud_line(_activity_desc(h).left(20), 32.0, y + 26.0, Color("#a89a80"), 9)
		# HP bar
		draw_rect(Rect2(ROSTER_W - 52, y + 8, 40, 4), Color("#1c1813"))
		draw_rect(Rect2(ROSTER_W - 52, y + 8, 40.0 * maxf(0.0, float(h.hp) / h.max_hp()), 4), Color("#7fae6b"))
		if h.seized:
			_hud_line("SEIZED", ROSTER_W - 52, y + 26.0, Color("#d09a5a"), 8)
		_ui_rects.append({"rect": r, "kind": "roster", "arg": h})
		y += card_h
		shown += 1

func _menu_colony(pad: float, y: float) -> void:
	_hud_line("THE COLONY", pad, y, Color("#c9a24b"), 13); y += 18
	_hud_line("Day %d   Heroes %d   Rep %d" % [world.sim_day, world.heroes.size(), int(world.population.reputation)], pad, y, Color("#cdbf9f")); y += 16
	_hud_line("Gold %d    Treasury %d" % [world.total_gold(), int(world.economy.treasury)], pad, y, Color("#e6c87a")); y += 16
	_hud_line("Ore %dg   Food %d   Rats slain %d   Deaths %d" % [world.economy.sell_price("iron_ore"), world.economy.total_stock("trout"), world.total_kills, world.deaths], pad, y, Color("#cdbf9f")); y += 22
	_draw_town(pad, y)

# HERO POPUP drawer (independent of the main menu): header = name + ZOOM SLIDER (with readout) + close;
# columns = identity | sub-tabs (Stats/Thoughts/Gear/Social/Saga) | commands (Nudge/Seize/vote).
func _draw_hero_popup(vp: Vector2) -> void:
	if not _hero_popup or selected == null:
		return
	var h := selected
	var top := vp.y - DRAWER_H
	draw_rect(Rect2(0, top, vp.x, DRAWER_H), Color("#272219", 0.97))
	draw_line(Vector2(0, top), Vector2(vp.x, top), Color("#c9a24b"), 2.0)
	# header row: name · zoom slider + readout · close
	var y := top + 20.0
	var nm_col := Color("#d09a5a") if h.seized else Color("#e6c87a")
	_hud_line("%s  -  %s%s" % [h.hero_name, h.tier, "   [SEIZED]" if h.seized else ""], 14.0, y, nm_col, 13)
	var track_x := vp.x * 0.38
	var track_w := vp.x * 0.30
	_zoom_track = Rect2(track_x, y - 12, track_w, 16)   # generous hit rect
	_hud_line("zoom", track_x - 38.0, y, Color("#857a67"), 10)
	draw_rect(Rect2(track_x, y - 6, track_w, 5), Color("#1c1813"))
	var t := (_pp_zoom - _pp_zoom_min) / maxf(0.001, _pp_zoom_max - _pp_zoom_min)
	draw_rect(Rect2(track_x, y - 6, track_w * t, 5), Color("#c9a24b"))
	draw_circle(Vector2(track_x + track_w * t, y - 3.5), 6.0, Color("#e6c87a"))
	_hud_line("%.1fx" % _pp_zoom, track_x + track_w + 10.0, y, Color("#e6c87a"), 11)
	_button("X close", vp.x - 70.0, y, "popup_close", "", false)
	# three columns
	var cy := y + 16.0
	var id_x := 14.0
	var tab_x := 250.0
	var cmd_x := vp.x - 230.0
	# identity column
	var iy := cy + 4.0
	var cl := XpTables.combat_level(h.skill_level("attack"), h.skill_level("strength"), h.skill_level("defence"), h.skill_level("hitpoints"), 1, 1, 1)
	_hud_line("Combat %d   HP %d/%d" % [cl, maxi(0, h.hp), h.max_hp()], id_x, iy, Color("#bcae90"), 11); iy += 15
	_hud_line("%dg   ·   favours %s" % [int(h.gold), h.favorite], id_x, iy, Color("#bcae90"), 11); iy += 15
	_hud_line("Satisfaction %d/100" % int(h.satisfaction), id_x, iy, Color("#9b9078"), 10); iy += 15
	_hud_line("Now: %s" % _activity_desc(h), id_x, iy, Color("#bcae90"), 10)
	# sub-tabs column
	var ty := _draw_tabs(tab_x, cy + 4.0) + 6
	match panel_tab:
		0: _tab_stats(h, tab_x, ty)
		1: _tab_thoughts(h, tab_x, ty)
		2: _tab_gear(h, tab_x, ty)
		3: _tab_social(h, tab_x, ty)
		_: _tab_saga(h, tab_x, ty)
	# commands column
	_draw_commands(h, cmd_x, cy + 4.0)

func _menu_chronicle(pad: float, y: float) -> void:
	_hud_line("THE CHRONICLE", pad, y, Color("#c9a24b"), 13); y += 18
	var vp := get_viewport_rect().size
	var rows := mini(world.chronicle.size(), int((vp.y - y - 30.0) / 14.0))
	for ev in world.chronicle.slice(0, rows):
		_hud_line("%s  %s" % [ev["t"], ev["text"]], pad, y, _chronicle_color(String(ev.get("cls", ""))), 10); y += 14

# --------------------------------------------------------------------------- Step-4 control surfaces
## A clickable button. Returns the next x (so callers can lay buttons out in a row). Records its rect
## in _ui_rects for hit-testing. `kind`/`arg` route through _dispatch_ui.
func _button(label: String, x: float, y: float, kind: String, arg, active: bool, enabled: bool = true, tip: String = "") -> float:
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 10.0
	var r := Rect2(x, y - 11, w, 16)
	if enabled:
		draw_rect(r, Color("#4a3c22") if active else Color("#2b2820"))
		draw_rect(r, Color("#5a5040"), false, 1.0)
		draw_string(_font, Vector2(x + 5, y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#efe0b8") if active else Color("#cdbf9f"))
		_ui_rects.append({"rect": r, "kind": kind, "arg": arg})
	else:
		# #4b disabled: dim fill/border/text; absorb the click as a no-op (so it never deselects the
		# hero by falling through to the map) and register a hover-tooltip explaining WHY it's gated.
		draw_rect(r, Color("#211e18"))
		draw_rect(r, Color("#3a352b"), false, 1.0)
		draw_string(_font, Vector2(x + 5, y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#6f6552"))
		_ui_rects.append({"rect": r, "kind": "noop", "arg": ""})
		if tip != "":
			_tips.append({"rect": r, "text": tip})
	return x + w + 3.0

## #4b: draw the hover-tooltip for whichever disabled button the cursor is over (drawn last → on top).
func _draw_tooltips() -> void:
	for t in _tips:
		if (t["rect"] as Rect2).has_point(_mouse_pos):
			_draw_tip_box(String(t["text"]), _mouse_pos)
			return

func _draw_tip_box(text: String, at: Vector2) -> void:
	var tw := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var box := Rect2(at + Vector2(12, 6), Vector2(tw + 12, 20))
	var vp := get_viewport_rect().size
	if box.end.x > vp.x:
		box.position.x = maxf(4.0, vp.x - box.size.x - 4.0)
	draw_rect(box, Color("#15130f", 0.96))
	draw_rect(box, Color("#5a5040"), false, 1.0)
	draw_string(_font, box.position + Vector2(6, 14), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e6d8b4"))

## Hero command row (§20.2): Nudge a one-off activity (or, while seized, COMMAND it directly), and the
## Seize/Release toggle. Same five verbs the brain itself selects among (dual-agency).
func _draw_commands(h: Hero, pad: float, y: float) -> float:
	_hud_line("COMMAND (direct)" if h.seized else "NUDGE (one-off, then resumes)", pad, y, Color("#857a67"), 10); y += 15
	var bx := pad
	for c in [["Mine", "GATHER_ORE"], ["Chop", "GATHER_LOGS"], ["Fish", "PROVISION"], ["Fight", "FIGHT"], ["Town", "REGROUP"]]:
		if h.seized:
			bx = _button(String(c[0]), bx, y, "command", String(c[1]), false)   # direct control — not feasibility-gated
		else:
			# #4b: gate an infeasible nudge with a disabled button + reason tooltip (no silent brain redirect)
			var feas: Dictionary = world.nudge_feasible(h, String(c[1]))
			bx = _button(String(c[0]), bx, y, "nudge", String(c[1]), false, bool(feas["ok"]), String(feas["reason"]))
	y += 19
	if h.seized:
		var bx3 := _button("Release control", pad, y, "release", "", true)
		_button("RUN %s" % ("ON" if h.run_on else "off"), bx3, y, "run_toggle", "", h.run_on)
		y += 19
		# stamina bar (run energy)
		draw_rect(Rect2(pad, y - 8, 130, 7), Color("#1c1813"))
		draw_rect(Rect2(pad, y - 8, 130.0 * h.run_energy / 100.0, 7), Color("#d6a04a") if h.run_on else Color("#7fae6b"))
		_hud_line("%d%%" % int(h.run_energy), pad + 136.0, y, Color("#a89a80"), 9)
		y += 12
		_hud_line("click map = walk there · WASD = walk", pad, y, Color("#857a67"), 9)
	else:
		_button("Seize (drive directly)", pad, y, "seize", "", false)
	y += 19
	# civic kick vote (§16.2): god initiates; force-kick unlocks after enough failed votes
	var bx2 := pad
	bx2 = _button("Call kick vote", bx2, y, "kick_vote", "", false)
	if world.can_force_kick(h):
		_button("FORCE-KICK", bx2, y, "force_kick", "", true)
	y += 19
	return y

## Town-building & incentive controls (§19 / §18.4): shop upgrades, build buttons, and the bounty row.
func _draw_town(pad: float, y: float) -> float:
	_hud_line("TOWN  ·  treasury %dg" % int(world.economy.treasury), pad, y, Color("#c9a24b"), 12); y += 16
	# Unit 2: the roster is 7 shops — short labels, wrapped into rows so the buttons stay on-panel
	const _SHOP_SHORT := {"general_store": "Gen", "fishmonger": "Fish", "swordshop": "Swrd",
		"lowe": "Lowe", "zaff": "Zaff", "aubury": "Aub", "horvik": "Horv"}
	var bx := pad
	var per_row := 0
	for s: Shop in world.economy.shops:
		var short: String = _SHOP_SHORT.get(s.npc_id, s.npc_id.left(4))
		bx = _button("%s Lv%d  up %dg" % [short, s.level, world.economy.shop_upgrade_cost(s)], bx, y, "upgrade_shop", s, false)
		per_row += 1
		if per_row == 4:   # wrap after 4 buttons
			per_row = 0
			bx = pad
			y += 19
	if per_row > 0:
		y += 19
	bx = pad
	for kind in Config.BUILDINGS:
		var spec: Dictionary = Config.BUILDINGS[kind]
		bx = _button("+%s %d" % [String(kind).capitalize(), int(spec["cost"])], bx, y, "build", kind, false)
	y += 19
	_hud_line("Gather incentives (cycle off/+%d/+%d):" % [int(Config.INCENTIVE_STEP), int(Config.INCENTIVE_MAX)], pad, y, Color("#857a67"), 10); y += 14
	bx = pad
	for c in [["Mine", "GATHER_ORE"], ["Chop", "GATHER_LOGS"], ["Fish", "PROVISION"]]:
		var w := float(world.incentives.get(c[1], 0.0))
		var lbl := "%s+%d" % [String(c[0]), int(w)] if w > 0.0 else String(c[0])
		bx = _button(lbl, bx, y, "incentive", String(c[1]), w > 0.0)
	y += 19
	# funded per-kill bounties (Unit 0 / R5): treasury-paid, per KNOWN monster, cycle 0→1×→2×→3× avg drop
	_hud_line("Kill bounties — treasury pays per kill (cycle to 3× avg drop):", pad, y, Color("#857a67"), 10); y += 14
	bx = pad
	for c in SimWorld.CAMPS:
		var mon: Monster = world.content.monster(String(c["mon"]))
		if mon == null or not world.monster_known(mon):
			continue
		var b := float(world.bounties.get(mon.id, 0.0))
		var lbl2 := "%s %dg" % [mon.name, int(round(b))] if b > 0.0 else mon.name
		bx = _button(lbl2, bx, y, "bounty", mon.id, b > 0.0)
	y += 19
	# price-bias lever (#3c / B1): per-good pay multiplier; overpay is treasury-funded
	_hud_line("Price bias — what shops pay (cycle %d%%/100%%/%d%%; overpay = treasury-funded):" % [
		int(Config.PRICE_BIAS_MIN * 100.0), int(Config.PRICE_BIAS_MAX * 100.0)], pad, y, Color("#857a67"), 10); y += 14
	bx = pad
	for c in [["Ore", "iron_ore"], ["Logs", "logs"], ["Fish", "trout"]]:
		var pb := world.economy.bias_of(String(c[1]))
		var lbl3 := "%s %d%%" % [String(c[0]), int(round(pb * 100.0))] if absf(pb - 1.0) > 0.01 else String(c[0])
		bx = _button(lbl3, bx, y, "price_bias", String(c[1]), absf(pb - 1.0) > 0.01)
	y += 19
	if world.buildings.size() > 0:
		var names: Array = []
		for b in world.buildings:
			names.append(String(b["name"]))
		_hud_line("Built: %s" % ", ".join(names), pad, y, Color("#9b9078"), 10); y += 14
	return y

# --------------------------------------------------------------------------- Hero Panel tabs (§20)
func _draw_tabs(pad: float, y: float) -> float:
	_tab_rects.clear()
	var tx := pad
	for i in range(TAB_NAMES.size()):
		var label: String = TAB_NAMES[i]
		var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 10.0
		var active := i == panel_tab
		var r := Rect2(tx, y - 11, w, 17)
		if active:
			draw_rect(r, Color("#322d24"))
		draw_string(_font, Vector2(tx + 5, y + 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color("#e6c87a") if active else Color("#857a67"))
		_tab_rects.append({"rect": r, "idx": i})
		tx += w + 2
	return y + 8

func _activity_desc(h: Hero) -> String:
	if h.act.is_empty():
		return "deciding what to do next"
	match String(h.act.get("intent", "")):
		"FIGHT": return "fighting at the Rat Pit"
		"GATHER_ORE": return "mining ore"
		"GATHER_LOGS": return "chopping logs"
		"PROVISION": return "fishing"
		"REGROUP": return "back in town to regroup"
	return String(h.act.get("intent", "idle"))

func _tab_stats(h: Hero, pad: float, y: float) -> float:
	var cl := XpTables.combat_level(h.skill_level("attack"), h.skill_level("strength"),
		h.skill_level("defence"), h.skill_level("hitpoints"), 1, 1, 1)
	var second := "  (2nd %s)" % SimWorld._cap(h.secondary) if h.secondary != "" else ""
	_hud_line("Combat %d    HP %d/%d    %dg" % [cl, maxi(0, h.hp), h.max_hp(), int(h.gold)], pad, y, Color("#a99c84"), 11); y += 15
	_hud_line("Favours %s%s" % [SimWorld._cap(h.favorite), second], pad, y, Color("#bcae90"), 11); y += 15
	_hud_line("Now: %s" % _activity_desc(h), pad, y, Color("#bcae90"), 11); y += 16
	_hud_line("ATK %d   STR %d   DEF %d   HP %d" % [h.skill_level("attack"), h.skill_level("strength"), h.skill_level("defence"), h.skill_level("hitpoints")], pad, y, Color("#bcae90"), 10); y += 14
	_hud_line("MINE %d   WC %d   FISH %d   COOK %d" % [h.skill_level("mining"), h.skill_level("woodcutting"), h.skill_level("fishing"), h.skill_level("cooking")], pad, y, Color("#bcae90"), 10); y += 15
	_hud_line("Satisfaction %d / 100" % int(h.satisfaction), pad, y, Color("#9b9078"), 10); y += 14
	return y

func _tab_thoughts(h: Hero, pad: float, y: float) -> float:
	_hud_line("\"%s\"" % h.thought, pad, y, Color("#d8cba8"), 12); y += 18
	_hud_line("Weighing its options (utility):", pad, y, Color("#857a67"), 10); y += 14
	var shown := 0
	for c in h.last_candidates:
		if shown >= 4:
			break
		var mark := "> " if shown == 0 else "  "
		_hud_line("%s%-9s %6.1f   %s" % [mark, c["intent"], float(c["score"]), _dominant_term(c)], pad, y,
			Color("#cdbf9f") if shown == 0 else Color("#8f846f"), 10); y += 13
		shown += 1
	if shown == 0:
		_hud_line("(hasn't weighed its options yet)", pad, y, Color("#7b7060"), 10); y += 13
	return y

func _dominant_term(c: Dictionary) -> String:
	var bn := ""
	var bv := 0.0
	for t in c["terms"]:
		if absf(float(t[1])) > absf(bv):
			bv = float(t[1])
			bn = String(t[0])
	return "%s %+.0f" % [bn, bv] if bn != "" else ""

## Which slot a carried item equips to (Unit 1: pure catalog lookup); "" = not equipable.
func _gear_slot_of(item: String) -> String:
	var it: ItemType = world.content.item(item)
	return it.slot if it != null else ""

## Gear tab (M1d): paper-doll EQUIPPED grid (one item per slot, logical body arrangement) + a clearly
## SEPARATE bordered INVENTORY box to its right. Equip/unequip mechanics live on Hero (one-per-slot,
## items move between the two); autonomous gear acquisition arrives with the M3a item economy.
func _tab_gear(h: Hero, pad: float, y: float) -> float:
	var inv_x := pad + 252.0
	_hud_line("EQUIPPED", pad, y, Color("#c9a24b"), 11)
	_hud_line("INVENTORY  (%d/28)" % h.inv_count(), inv_x, y, Color("#c9a24b"), 11)
	y += 6.0
	var rows := [["", "head", ""], ["cape", "neck", ""], ["main", "torso", "off"], ["", "legs", ""], ["gloves", "boots", "ring"]]
	var box_h := rows.size() * 26.0 + 8.0
	draw_rect(Rect2(pad - 4, y - 2, 236, box_h), Color("#1c1813"))
	draw_rect(Rect2(pad - 4, y - 2, 236, box_h), Color("#564a38"), false, 1.0)
	var by := y + 2.0
	for r in rows:
		var bx := pad
		for slot in r:
			if slot != "":
				var rect := Rect2(bx, by, 73, 23)
				draw_rect(rect, Color("#332c22"))
				draw_rect(rect, Color("#6b5a2a") if h.equipped.has(slot) else Color("#564a38"), false, 1.0)
				_hud_line(String(slot), bx + 3, by + 9, Color("#7b7060"), 8)
				var itm := String(h.equipped.get(slot, ""))
				_hud_line(world.item_name(itm) if itm != "" else "-", bx + 3, by + 19, Color("#e6c87a") if itm != "" else Color("#4a4438"), 9)
				if h.seized and itm != "":   # seized: click a filled slot to UNEQUIP (needs bag space)
					_ui_rects.append({"rect": rect, "kind": "unequip", "arg": slot})
			bx += 77.0
		by += 26.0
	# inventory box — visually distinct (darker fill, own border) so slots can't be confused
	draw_rect(Rect2(inv_x - 4, y - 2, 190, box_h), Color("#221d15"))
	draw_rect(Rect2(inv_x - 4, y - 2, 190, box_h), Color("#564a38"), false, 1.0)
	# CANON 28-slot grid (7×4): each non-stackable unit gets ITS OWN cell; stackables one cell w/ qty
	var cells: Array = []
	for k in h.inv:
		var q := int(h.inv[k])
		if q <= 0:
			continue
		if Hero.STACKABLES.has(String(k)):
			cells.append([String(k), q])
		else:
			for i in range(q):
				cells.append([String(k), 1])
	var cw := 26.0
	for s2 in range(28):
		var col := s2 % 7
		var row2 := s2 / 7
		var cr := Rect2(inv_x + col * cw, y + 2 + row2 * cw, cw - 2, cw - 2)
		draw_rect(cr, Color("#2a241a") if s2 < cells.size() else Color("#1e1a12"))
		draw_rect(cr, Color("#564a38"), false, 1.0)
		if s2 < cells.size():
			var nm := String(cells[s2][0])
			var qn := int(cells[s2][1])
			_hud_line(world.item_name(nm).left(3), cr.position.x + 2, cr.position.y + 12, Color("#d8ccb4"), 8)
			if qn > 1:
				_hud_line(str(qn), cr.position.x + 2, cr.position.y + 21, Color("#ffd24a"), 8)
			var slot2 := _gear_slot_of(nm)
			if h.seized and slot2 != "" and qn == 1:
				_ui_rects.append({"rect": cr, "kind": "equip", "arg": [slot2, nm]})
				draw_rect(cr, Color("#c9a24b"), false, 1.0)   # equipable highlight
	return by + 8.0

func _tab_social(h: Hero, pad: float, y: float) -> float:
	var rels: Array = []
	if world.social != null:
		rels = world.social.relations_for(h.id, world.sim_day, 6)
	if rels.is_empty():
		_hud_line("No strong bonds yet - still getting to", pad, y, Color("#9b9078"), 11); y += 13
		_hud_line("know the colony.", pad, y, Color("#9b9078"), 11); y += 14
		return y
	for r: Dictionary in rels:
		var other := world.hero_by_id(int(r["to"]))
		var nm := other.hero_name if other != null else "someone"
		var tier := String(r["tier"])
		_hud_line("%-7s %s  (%+d)" % [tier, nm, int(r["r"])], pad, y, _rel_color(tier), 11); y += 14
	return y

func _rel_color(tier: String) -> Color:
	match tier:
		"Ally": return Color("#7fd08a")
		"Friend": return Color("#9ccf86")
		"Rival": return Color("#d0995f")
		"Nemesis": return Color("#cc6a5a")
	return Color("#bcae90")

func _tab_saga(h: Hero, pad: float, y: float) -> float:
	_hud_line(h.backstory, pad, y, Color("#cdbf9f"), 10); y += 16
	_hud_line("Milestones:", pad, y, Color("#857a67"), 10); y += 14
	var shown := 0
	for m: Dictionary in h.milestones:
		if shown >= 5:
			break
		_hud_line("%s  %s" % [m["t"], m["text"]], pad, y, Color("#bcae90"), 10); y += 13
		shown += 1
	if shown == 0:
		_hud_line("Their saga is just beginning.", pad, y, Color("#7b7060"), 10); y += 13
	return y

## Color a Chronicle line by its event class so the colony's story reads at a glance (§17).
func _chronicle_color(cls: String) -> Color:
	match cls:
		"friend": return Color("#9ccf86")   # friendships / alliances — warm green
		"rival", "nemesis": return Color("#cc6a5a")   # feuds — red
		"vote", "exile": return Color("#d0995f")      # civic upheaval — amber
		"die": return Color("#a08a7a")       # deaths / grudges — muted
		"gold": return Color("#e6c87a")      # economy — gold
		"boss", "lv": return Color("#cdbf9f") # milestones / level-ups
	return Color("#cdbf9f")

func _hud_line(text: String, x: float, y: float, col: Color, size: int = 12) -> void:
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, PANEL_W - 28, size, col)
