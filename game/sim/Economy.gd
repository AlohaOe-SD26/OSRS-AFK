class_name Economy
extends RefCounted
## The colony market (GDD §6) — now a thin facade over first-class Shop entities (Shop.gd).
## Step 3 promoted the previously-implicit price table into named, inspectable shops; this class
## keeps the SAME public surface (sell_price/food_price/sell_goods/sell_food/buy_food/
## economy_tick/total_stock) so SimWorld/Brain/Telemetry/render are untouched, while routing each
## good to the shop that trades it. The §6 mechanics are preserved exactly (the equilibrium was
## VALIDATED against these curves/constants — see Config.gd header):
##
##  1. Saturation-aware sell price that decays toward PRICE_FLOOR_FRAC×base as stock fills
##     (Shop.sell_price) — closes the "shop mints at floor price forever" leak.
##  2. Capacity-respecting sales: the shop only pays for whole units that fit (Shop.room_for) →
##     backpressure on over-gathering.
##  3. SHOP_TAX skim on every sale — now ACCUMULATED in `tax_collected` (first-class, inspectable)
##     instead of an anonymous inline subtraction.
##  4. economy_tick(): per-shop town consumption (Shop.consume_tick) bounds the faucet +
##     wealth-proportional hero upkeep (the stable attractor that flattens total gold).
##
## UNIT 1 (catalog migration): BASE VALUES come from the CATALOG (ContentDB/items.json — KI-8's
## single price truth; iron_ore 17 supersedes the old hardcoded 16), and SHOPS TRADE GEAR — every
## tradeable tiered item joins the General Store's board with a small stock arm whose 0.5 starting
## fill reproduces the old half-value vendoring at open (f = 1.2 − 0.5×1.4 = 0.5). The null-content
## fallback bases keep bare unit tests (Economy.new()) meaningful; the live sim always passes content.

const GOODS := ["iron_ore", "logs", "raw_trout", "trout"]
const FOOD_BUY_BASE: float = 22.0   # what the shop charges heroes for cooked fish (the food sink)

var shops: Array = []               # Array[Shop] — inspectable (hero panel / shop UI, §20 / §19.2)
var _by_good: Dictionary = {}       # good -> Shop (routing index)
var tax_collected: float = 0.0      # cumulative SHOP_TAX skim (the §5 wealth-scaling sink, tracked)
# Town treasury (§19): the SPENDABLE pool the player builds from. Fed by the shop tax + the Unit-2
# purchase routing — gold the §6 sinks ALREADY removed from hero circulation, so banking it here
# changes nothing about total_gold() or the validated attractor. Drained by bounties/build/upkeep.
var treasury: float = 0.0
# Unit 2 (R1) — treasury LEDGER counters (telemetry; serialized so the ledger survives load):
var treasury_in_tax: float = 0.0       # inflow: SHOP_TAX skim on hero sales
var treasury_in_routing: float = 0.0   # inflow: PURCHASE_TREASURY_ROUTE share of hero purchases
var treasury_out_bounty: float = 0.0   # outflow: funded per-kill bounty payouts
var treasury_out_upgrade: float = 0.0  # outflow: shop level-ups
var treasury_out_building: float = 0.0 # outflow: building costs + daily building upkeep
var _content: ContentDB = null         # catalog reference (tradeable gate in sell_goods)

func _init(content: ContentDB = null) -> void:
	_content = content
	# Unit 2: the roster is DATA (data/shops.json — 7 shops per ruling R3); base values stay
	# catalog-sourced (Unit 1 / KI-8). The legacy 2-shop fallback keeps bare unit tests
	# (Economy.new()) and shops.json-less rigs meaningful.
	if content != null and not content.shop_defs.is_empty():
		for sd in content.shop_defs:
			var defs := {}
			for g in sd["goods"]:
				var iid := String(g["item"])
				defs[iid] = {"stock": float(g.get("stock", 0.0)), "max": float(g.get("max", 1.0)),
					"base": _bv(content, iid, 1.0), "consume": float(g.get("consume", 0.0)),
					"baseline": float(g.get("baseline", 0.0)), "charge": float(g.get("charge", 0.0)),
					"unlockLevel": int(g.get("unlockLevel", 1))}
			shops.append(Shop.make(String(sd["id"]), String(sd["name"]), defs))
	else:
		shops = _legacy_roster(content)
	for s: Shop in shops:
		for good in s.goods:
			_by_good[good] = s

## The pre-Unit-2 two-shop roster (general store + gear board, fishmonger) — fallback only.
static func _legacy_roster(content: ContentDB) -> Array:
	var general_defs := {
		"iron_ore": {"stock": 20.0, "max": 120.0, "base": _bv(content, "iron_ore", 16.0), "consume": Config.SHOP_CONSUME["iron_ore"]},
		"logs": {"stock": 20.0, "max": 120.0, "base": _bv(content, "logs", 12.0), "consume": Config.SHOP_CONSUME["logs"]},
	}
	if content != null:
		for iid in content.items:
			var it: ItemType = content.items[iid]
			if it.tier > 0 and it.tradeable:
				general_defs[iid] = {"stock": Config.GEAR_SHOP_STOCK, "max": Config.GEAR_SHOP_MAX,
					"base": float(it.base_value), "consume": Config.GEAR_SHOP_CONSUME}
	var general := Shop.make("general_store", "Varrock General Store", general_defs)
	var market := Shop.make("fishmonger", "Varrock Fishmonger", {
		"raw_trout": {"stock": 10.0, "max": 80.0, "base": _bv(content, "raw_trout", 7.0), "consume": Config.SHOP_CONSUME["raw_trout"]},
		"trout": {"stock": 14.0, "max": 80.0, "base": _bv(content, "trout", 9.0), "consume": Config.SHOP_CONSUME["trout"]},
	})
	return [general, market]

## Catalog base value with a legacy fallback (bare-test construction only — see the _init note).
static func _bv(content: ContentDB, id: String, fallback: float) -> float:
	if content != null and content.base_value(id) > 0:
		return float(content.base_value(id))
	return fallback

func shop_for(good: String) -> Shop:
	return _by_good.get(good, null)

## Price the shop PAYS a hero for a good (saturation-aware). Routes to the owning shop.
func sell_price(item: String) -> int:
	var s: Shop = _by_good.get(item, null)
	return s.sell_price(item) if s != null else 1

## Price the shop CHARGES a hero for cooked fish (rises as food stock falls).
func food_price() -> int:
	return _by_good["trout"].buy_price("trout", FOOD_BUY_BASE)

## Internal: pay a hero for `qty` units of `good`, skimming + banking SHOP_TAX. Returns gold paid.
func _pay_for(hero: Hero, good: String, qty: int, s: Shop) -> int:
	var gross := qty * s.sell_price(good)
	var tax := gross * Config.SHOP_TAX
	tax_collected += tax
	treasury += tax        # the skim becomes the player's spendable town fund (§19); see `treasury` note
	treasury_in_tax += tax
	var net := int(round(gross - tax))
	hero.gold += net
	s.stock[good] += qty
	return net

## Sell carried goods to the shops that trade them. Only whole units that fit are bought
## (backpressure). Unit 1: GEAR is a REAL shop trade now — carried tradeable gear routes through
## the SAME saturation-aware, taxed path as ore/logs (the flat half-value vendoring is retired).
## Food (trout/raw_trout) deliberately does NOT sell here — sell_food owns it (fighter keep-buffer);
## otherwise a fighter's REGROUP would dump its own rations. Untradeables (tools, ammo) never sell.
func sell_goods(hero: Hero) -> int:
	var g := 0
	for k in hero.inv.keys():
		var item := String(k)
		if item == "trout" or item == "raw_trout":
			continue
		# Unit 2: tools/ammo are STOCKED shop goods now (buy-side) but stay untradeable on the
		# vendor side — the catalog flag is the gate (a carried pickaxe is kit, not merchandise).
		if _content != null:
			var it: ItemType = _content.item(item)
			if it != null and not it.tradeable:
				continue
		var s: Shop = _by_good.get(item, null)
		if s == null:
			continue
		var have := int(hero.inv.get(item, 0))
		var qty := mini(have, s.room_for(item))
		if qty > 0:
			g += _pay_for(hero, item, qty, s)
			if have - qty <= 0:
				hero.inv.erase(item)
			else:
				hero.inv[item] = have - qty
	return g

## Cooks supply the Fishmonger's food (keeping a small buffer if the hero is a fighter).
func sell_food(hero: Hero, keep: int = 0) -> int:
	var have := int(hero.inv.get("trout", 0))
	var qty := maxi(0, have - keep)
	var s: Shop = _by_good["trout"]
	qty = mini(qty, s.room_for("trout"))
	if qty > 0:
		var pay := _pay_for(hero, "trout", qty, s)
		hero.inv["trout"] = have - qty
		return pay
	return 0

## Hero buys cooked fish from the shop (a gold sink). Returns units bought. Unit 2 (R1): a routed
## share of the spend funds the treasury; the rest burns (hero-side sink identical either way).
func buy_food(hero: Hero, want: int) -> int:
	var bought := 0
	var p := food_price()
	var s: Shop = _by_good["trout"]
	while bought < want and hero.gold >= p and s.stock["trout"] >= 1.0 and not hero.inv_full():
		hero.gold -= p
		_route_purchase(float(p))
		s.stock["trout"] -= 1.0
		hero.inv["trout"] = int(hero.inv.get("trout", 0)) + 1
		bought += 1
	return bought

## Unit 2: hero BUYS `qty` units of a stocked, unlocked good at the per-good dynamic charge price.
## Decrements real stock (purchases are SUPPLY-GATED — the R3 lesson; ambient imports replenish),
## routes the R1 treasury share, burns the rest. Returns units bought; the CALLER applies the
## inventory/equip effect (ammo bundles, tools, weapons all differ). Food goes through buy_food.
func buy_item(hero: Hero, good: String, qty: int = 1) -> int:
	var s: Shop = _by_good.get(good, null)
	if s == null:
		return 0
	var bought := 0
	while bought < qty and s.can_buy(good):
		var p := s.charge_price(good)
		if hero.gold < float(p):
			break
		hero.gold -= float(p)
		_route_purchase(float(p))
		s.stock[good] -= 1.0
		bought += 1
	return bought

## What a hero would pay for one unit right now (affordability checks; 0 = not purchasable here).
func buy_cost(good: String) -> int:
	var s: Shop = _by_good.get(good, null)
	if s == null or float(s.charge.get(good, 0.0)) <= 0.0:
		return 0
	return s.charge_price(good)

## R1 purchase→treasury routing: 40% of every hero purchase funds the treasury, 60% burns.
func _route_purchase(spend: float) -> void:
	var routed: float = spend * Config.PURCHASE_TREASURY_ROUTE
	treasury += routed
	treasury_in_routing += routed

## Per-work-action economy step. `dd` = fraction of a sim-day elapsed.
##  - per-shop town consumption drains stock (bounds the gather faucet)
##  - wealth-proportional + flat upkeep drains hero gold (the stable attractor sink)
## Returns total gold burned this step (telemetry).
func economy_tick(dd: float, heroes: Array) -> float:
	# town demand scales with population so the gather faucet/sink ratio is population-invariant
	# (§6.5). At the founding population this is exactly 1.0 → the validated 6-hero curve is preserved.
	var pop_scale: float = float(heroes.size()) / float(Config.POP_BASELINE)
	for s: Shop in shops:
		s.consume_tick(dd, pop_scale)
		s.import_tick(dd)   # Unit 2 (C5): ambient imports restock purchasables toward baseline
	var burned := 0.0
	for hero in heroes:
		var drain: float = (Config.UPKEEP_FLAT + Config.UPKEEP_RATE * hero.gold) * dd
		drain = minf(hero.gold, drain)   # never drives gold negative
		hero.gold -= drain
		burned += drain
	return burned

func total_stock(item: String) -> int:
	var s: Shop = _by_good.get(item, null)
	return s.total_stock(item) if s != null else 0

# --------------------------------------------------------------------------- shop leveling (§19.2)
## Treasury cost to take a shop from its current level to the next (geometric growth).
func shop_upgrade_cost(s: Shop) -> int:
	return int(round(Config.SHOP_UPGRADE_BASE_COST * pow(Config.SHOP_UPGRADE_COST_GROWTH, s.level - 1)))

## Player invests treasury to level a shop up (§19.2). Returns true on success. Stock capacity AND
## town demand grow by the same factor (Shop.level_up) so the faucet/sink ratio is preserved (§6.5)
## → the equilibrium stays bounded without a re-tune; the lever boosts THROUGHPUT, not the gold supply.
func try_upgrade_shop(s: Shop) -> bool:
	if s.level >= Config.SHOP_LEVEL_CAP:
		return false
	var cost := shop_upgrade_cost(s)
	if treasury < float(cost):
		return false
	treasury -= float(cost)
	treasury_out_upgrade += float(cost)
	s.level_up()
	return true
