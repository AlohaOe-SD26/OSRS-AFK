extends SceneTree
## Build-time ingest: osrsreboxed bulk JSON → our local content DB (GDD §21.1).
##
## The osrsreboxed dataset (~23k items + monsters + 20k icons) is NOT bundled. Download
## items-complete.json and monsters-complete.json from the osrsreboxed repo, then run:
##
##   godot --headless --script res://tools/ingest_osrsreboxed.gd -- \
##       <path/to/items-complete.json> <path/to/monsters-complete.json>
##
## It writes res://data/items.generated.json and res://data/monsters.generated.json in the
## SAME schema as the hand-authored seed; ContentDB prefers the *.generated.json when present.
## This keeps "canon stats come from the dataset" (HANDOFF §5) true while Phase 0 still boots
## from the seed today. SNAPSHOT THE PATCH DATE you ingest (several stats are version-specific).
##
## NOTE: this mapper is unverified against a live dataset in this environment — validate field
## names against the osrsreboxed schema at build (they are stable but worth a spot-check).

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: ... ingest_osrsreboxed.gd -- <items-complete.json> <monsters-complete.json>")
		quit(1)
		return
	var items_ok := _ingest_items(args[0], "res://data/items.generated.json")
	var mons_ok := _ingest_monsters(args[1], "res://data/monsters.generated.json")
	quit(0 if (items_ok and mons_ok) else 1)

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("ingest: missing %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())

func _write(path: String, data: Array) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ingest: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(data, "  "))
	print("ingest: wrote %d records → %s" % [data.size(), path])
	return true

func _ingest_items(src: String, dst: String) -> bool:
	var raw: Variant = _read(src)
	if not (raw is Dictionary):
		return false
	var out: Array = []
	for id in raw:
		var it: Dictionary = raw[id]
		# Only keep equipable gear + a value (skip the long tail of noted/placeholder rows).
		var equip: Dictionary = it.get("equipment", {}) if it.get("equipment") != null else {}
		var rec := {
			"id": str(it.get("id", id)),
			"name": it.get("name", ""),
			"slot": _map_slot(str(equip.get("slot", ""))),
			"baseValue": int(it.get("highalch", it.get("cost", 0))),
			"stackable": bool(it.get("stackable", false)),
			"tradeable": bool(it.get("tradeable", true)),
			"levelReqs": equip.get("requirements", {}) if equip.get("requirements") != null else {},
			"baseStats": _map_stats(equip),
			"acquisition": {"type": "Unknown"},
			"iconId": str(it.get("id", id)),
		}
		out.append(rec)
	return _write(dst, out)

## osrsreboxed equipment slot → our Hero slot key (Unit 1: catalog slot IS the equip slot).
func _map_slot(slot: String) -> String:
	match slot:
		"weapon", "2h": return "main"
		"shield": return "off"
		"body": return "torso"
		"hands": return "gloves"
		"feet": return "boots"
		"ammo": return ""        # ammo rides the inventory (stackable), not a paper-doll slot
	return slot                  # head/cape/neck/legs/ring already match

func _map_stats(equip: Dictionary) -> Dictionary:
	# Map the osrsreboxed equipment bonus fields to our base_stats keys.
	var s := {}
	for pair in [
		["attack_stab", "att_stab"], ["attack_slash", "att_slash"], ["attack_crush", "att_crush"],
		["attack_magic", "att_magic"], ["attack_ranged", "att_ranged"],
		["defence_stab", "def_stab"], ["defence_slash", "def_slash"], ["defence_crush", "def_crush"],
		["defence_magic", "def_magic"], ["defence_ranged", "def_ranged"],
		["melee_strength", "str"], ["ranged_strength", "ranged_str"],
		["magic_damage", "magic_dmg"], ["prayer", "prayer"],
	]:
		if equip.has(pair[0]) and equip[pair[0]] != null and int(equip[pair[0]]) != 0:
			s[pair[1]] = int(equip[pair[0]])
	return s

func _ingest_monsters(src: String, dst: String) -> bool:
	var raw: Variant = _read(src)
	if not (raw is Dictionary):
		return false
	var out: Array = []
	for id in raw:
		var m: Dictionary = raw[id]
		var attrs: Array = m.get("attributes", []) if m.get("attributes") != null else []
		var drops_src: Array = m.get("drops", []) if m.get("drops") != null else []
		var drops: Array = []
		for d in drops_src:
			drops.append({"itemTypeId": str(d.get("id", "")), "rate": float(d.get("rarity", 0.0))})
		out.append({
			"id": str(m.get("id", id)),
			"name": m.get("name", ""),
			"combatLevel": int(m.get("combat_level", 1)),
			"hitpoints": int(m.get("hitpoints", 1)),
			"attackStyles": m.get("attack_type", []),
			"maxHit": int(m.get("max_hit", 0)),
			"weaknessStyle": "",  # derive from elemental weakness at build (post-rebalance, §8 checklist)
			"attackSpeed": int(m.get("attack_speed", 4)),
			"aggressive": bool(m.get("aggressive", false)),
			"undeadFlag": ("undead" in attrs),
			"slayerLevelReq": int(m.get("slayer_level", 0)),
			"isBoss": false,
			"coinDropRange": [0, 0],
			"dropTable": drops,
		})
	return _write(dst, out)
