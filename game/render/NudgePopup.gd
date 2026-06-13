extends Control
## #4c — the project's FIRST Godot Control-node UI (ruling R11). A parameterized nudge popup: the
## player picks the activity, the TRIP LENGTH as a [min,max] range the hero rolls within (#4a
## count_range → count_target), and (for fights) the loot policy (#4a loot_policy drop-filter), then
## dispatches through SimWorld.nudge_hero(selected, intent, params). Strictly render-layer: it reads
## the sim read-only (nudge_feasible) and emits an intent for Main to dispatch — never mutates the sim.
##
## R11 paradigm split (logged in 06-DECISIONS-LOG): the immediate-mode HUD (Main.gd `_draw`) is
## untouched; COMPLEX-INPUT forms like this live in Control nodes. The palette below MIRRORS Main's
## HUD hexes so the mixed paradigm reads as one game (R11 condition 2). Target/monster routing is
## deferred — #4a wired loc/count_range/loot_policy into the FSM but not per-monster targeting, and
## there is effectively one combat camp today; the activity + range + loot params are all functional.

signal submitted(intent: String, params: Dictionary)
signal cancelled()

# palette mirrors Main.gd's immediate-mode HUD (one visual language across the paradigm split)
const C_BG := Color("#1a1814")
const C_BORDER := Color("#5a5040")
const C_GOLD := Color("#c9a24b")
const C_TEXT := Color("#efe0b8")
const C_DIM := Color("#a89a80")
const C_BAD := Color("#d08a6a")

# activity rows: [label, intent, default_min, default_max] — defaults bracket the standing trip length
# (FIGHT ≈ COMBAT_TRIP_KILLS 6; mine/chop ≈ 14; fish ≈ 8).
const ACTIVITIES := [
	["Fight (kills)", "FIGHT", 4, 8],
	["Mine ore (units)", "GATHER_ORE", 10, 18],
	["Chop logs (units)", "GATHER_LOGS", 10, 18],
	["Fish & cook (units)", "PROVISION", 6, 12],
]
const LOOT_OPTS := [["Keep all", "keep-all"], ["Upgrades & valuables", "upgrades-and-valuables"], ["Salvage all", "salvage-all"]]

var world = null            # set by Main on open (read-only use: nudge_feasible)
var hero = null             # the selected Hero
var _title := Label.new()
var _activity := OptionButton.new()
var _min := SpinBox.new()
var _max := SpinBox.new()
var _loot := OptionButton.new()
var _loot_row: HBoxContainer
var _reason := Label.new()
var _ok := Button.new()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # modal: eat clicks meant for the map behind it
	visible = false
	# dim scrim behind the panel
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.45)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	# centered panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(panel)
	var margin := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 16)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.custom_minimum_size = Vector2(320, 0)
	margin.add_child(vb)

	_title.text = "Nudge"
	_style_label(_title, C_GOLD, 14)
	vb.add_child(_title)
	vb.add_child(_dim_label("One-off override — the hero rolls within the range, then resumes autonomy."))

	# activity
	for i in range(ACTIVITIES.size()):
		_activity.add_item(String(ACTIVITIES[i][0]), i)
	_activity.item_selected.connect(_on_activity_changed)
	vb.add_child(_labeled("Activity", _activity))

	# trip-length range
	_setup_spin(_min, 1, 99, 4)
	_setup_spin(_max, 1, 99, 8)
	_min.value_changed.connect(func(_v): _sync_range(true))
	_max.value_changed.connect(func(_v): _sync_range(false))
	var range_row := HBoxContainer.new()
	range_row.add_theme_constant_override("separation", 8)
	range_row.add_child(_tag("min"))
	range_row.add_child(_min)
	range_row.add_child(_tag("max"))
	range_row.add_child(_max)
	vb.add_child(_labeled("Trip length", range_row))

	# loot policy (fights)
	for i in range(LOOT_OPTS.size()):
		_loot.add_item(String(LOOT_OPTS[i][0]), i)
	_loot_row = _labeled("Loot (fights)", _loot)
	vb.add_child(_loot_row)

	# feasibility reason (hidden unless infeasible)
	_style_label(_reason, C_BAD, 11)
	_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason.custom_minimum_size = Vector2(320, 0)
	vb.add_child(_reason)

	# buttons
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 8)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_on_cancel)
	_ok.text = "Nudge"
	_ok.pressed.connect(_on_ok)
	btns.add_child(cancel)
	btns.add_child(_ok)
	vb.add_child(btns)

## Populate for `h` and show. Called by Main on the "Nudge…" command button.
func open_for(w, h) -> void:
	world = w
	hero = h
	_title.text = "Nudge %s" % (h.hero_name if h != null else "")
	_activity.selected = 0
	_on_activity_changed(0)
	visible = true

func _on_activity_changed(idx: int) -> void:
	var a: Array = ACTIVITIES[idx]
	_min.value = float(int(a[2]))
	_max.value = float(int(a[3]))
	_loot_row.visible = String(a[1]) == "FIGHT"
	_refresh_feasibility()

func _refresh_feasibility() -> void:
	var intent := _current_intent()
	var feas: Dictionary = world.nudge_feasible(hero, intent) if world != null and hero != null else {"ok": true, "reason": ""}
	var ok := bool(feas.get("ok", true))
	_ok.disabled = not ok
	_reason.text = "" if ok else "✗ %s" % String(feas.get("reason", ""))
	_reason.visible = not ok

func _current_intent() -> String:
	return String(ACTIVITIES[_activity.selected][1])

func _sync_range(min_changed: bool) -> void:
	# keep min <= max by nudging the other field
	if min_changed and _min.value > _max.value:
		_max.value = _min.value
	elif not min_changed and _max.value < _min.value:
		_min.value = _max.value

func _on_ok() -> void:
	if _ok.disabled:
		return
	var intent := _current_intent()
	var params := {"count_range": [int(_min.value), int(_max.value)]}
	if intent == "FIGHT":
		params["loot_policy"] = String(LOOT_OPTS[_loot.selected][1])
	visible = false
	submitted.emit(intent, params)

func _on_cancel() -> void:
	visible = false
	cancelled.emit()

# ---- small builders (keep the tree terse) ----
func _panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_color = C_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	return sb

func _style_label(l: Label, col: Color, size: int) -> void:
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)

func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	_style_label(l, C_DIM, 10)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	return l

func _tag(text: String) -> Label:
	var l := Label.new()
	l.text = text
	_style_label(l, C_DIM, 11)
	return l

# a "Label : control" row
func _labeled(label: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	_style_label(l, C_TEXT, 12)
	l.custom_minimum_size = Vector2(96, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _setup_spin(s: SpinBox, lo: int, hi: int, val: int) -> void:
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = val
	s.custom_minimum_size = Vector2(64, 0)
