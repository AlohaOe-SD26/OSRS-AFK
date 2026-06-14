class_name ContentDB
extends RefCounted
## Loads the local content DB (data/*.json) into ItemType/Monster catalogs.
##
## Phase 0 ships a small HAND-AUTHORED canon seed (data/items.json, data/monsters.json) so
## the game runs without the full ~23k-row osrsreboxed dataset. The real dataset drops in
## via tools/ingest_osrsreboxed.gd, which writes the SAME schema these loaders read — so
## "canon stats come from the dataset" (HANDOFF §5) holds; the seed is just the bootstrap.

var items: Dictionary = {}      # id -> ItemType
var monsters: Dictionary = {}   # id -> Monster
var map_data: Dictionary = {}   # raw varrock_map.json
var shop_defs: Array = []       # raw shops.json (Unit 2: the data-driven shop roster)

func load_all(base_path: String = "res://data") -> bool:
	var ok := true
	# prefer the dataset-ingested files (tools/ingest_osrsreboxed.gd) over the seed when present
	ok = _load_items(_prefer(base_path, "items")) and ok
	ok = _load_monsters(_prefer(base_path, "monsters")) and ok
	ok = _load_map(base_path + "/varrock_map.json") and ok
	ok = _load_shops(base_path + "/shops.json") and ok
	return ok

func _load_shops(path: String) -> bool:
	var data: Variant = _read_json(path)
	if not (data is Array):
		return false
	shop_defs = data
	return true

func _prefer(base_path: String, name: String) -> String:
	var generated := "%s/%s.generated.json" % [base_path, name]
	if FileAccess.file_exists(generated):
		return generated
	return "%s/%s.json" % [base_path, name]

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("ContentDB: missing file %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ContentDB: cannot open %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("ContentDB: invalid JSON in %s" % path)
	return parsed

func _load_items(path: String) -> bool:
	var data: Variant = _read_json(path)
	if not (data is Array):
		return false
	for d in data:
		var it := ItemType.from_dict(d)
		items[it.id] = it
	return true

func _load_monsters(path: String) -> bool:
	var data: Variant = _read_json(path)
	if not (data is Array):
		return false
	for d in data:
		var m := Monster.from_dict(d)
		monsters[m.id] = m
	return true

func _load_map(path: String) -> bool:
	var data: Variant = _read_json(path)
	if not (data is Dictionary):
		return false
	map_data = data
	return true

func item(id: String) -> ItemType:
	return items.get(id, null)

func monster(id: String) -> Monster:
	return monsters.get(id, null)

func base_value(id: String) -> int:
	var it: ItemType = items.get(id, null)
	return it.base_value if it != null else 0

# ------------------------------------------------------- Unit-1 catalog queries (single source of truth)
var _drop_pool: Array = []   # cached Array[ItemType], catalog file order (deterministic — the drop roll indexes it)

## The random gear-drop pool (replaces Config.GEAR_DROPS). Catalog file order is preserved so the
## RNG draw maps to the same item the old table order did.
func gear_drop_pool() -> Array:
	if _drop_pool.is_empty():
		for iid in items:
			if items[iid].in_drop_pool():
				_drop_pool.append(items[iid])
	return _drop_pool

## Gear tier of an item id (replaces Config.GEAR_TIER); 0 for unknown/non-gear.
func tier(id: String) -> int:
	var it: ItemType = items.get(id, null)
	return it.tier if it != null else 0

## Main-hand style of an item id ("sword"/"bow"/"staff"); "" for non-weapons.
func style(id: String) -> String:
	var it: ItemType = items.get(id, null)
	return it.style if it != null else ""

## #15 — equippable GEAR in a slot, optionally filtered by tier and weapon style. File order
## (deterministic — callers index it with the seeded RNG). want_tier -1 = any; want_style "" = any
## (and style-less armor always matches). Tools/ammo (slot "" or tier 0) are excluded.
func equippable(slot: String, want_tier: int = -1, want_style: String = "") -> Array:
	var out: Array = []
	for iid in items:
		var it: ItemType = items[iid]
		if it.slot != slot or it.tier <= 0:
			continue
		if want_tier != -1 and it.tier != want_tier:
			continue
		if want_style != "" and it.style != "" and it.style != want_style:
			continue
		out.append(it)
	return out

## Recipes-as-data: the crafted output whose recipe consumes `input_id` via `skill`
## (e.g. craft_output("cooking", "raw_trout") → trout). null when no recipe matches.
func craft_output(skill: String, input_id: String) -> ItemType:
	for iid in items:
		var it: ItemType = items[iid]
		if it.craft_skill() == skill and it.recipe().has(input_id):
			return it
	return null
