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

func load_all(base_path: String = "res://data") -> bool:
	var ok := true
	# prefer the dataset-ingested files (tools/ingest_osrsreboxed.gd) over the seed when present
	ok = _load_items(_prefer(base_path, "items")) and ok
	ok = _load_monsters(_prefer(base_path, "monsters")) and ok
	ok = _load_map(base_path + "/varrock_map.json") and ok
	return ok

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
