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
# Town treasury (§19): the SPENDABLE pool the player builds from. Fed by the shop tax — i.e. gold the
# §5 sink ALREADY removed from hero circulation, so banking it here changes nothing about total_gold()
# or the validated attractor; it just gives the skimmed gold a tycoon purpose. Drained by build/upkeep.
var treasury: float = 0.0

func _init(content: ContentDB = null) -> void:
	# Two canon Varrock vendors (GDD §7). Stock/max/consume = the validated tune (Config.SHOP_CONSUME
	# stays the single tuning home); BASE values are catalog-sourced (Unit 1 / KI-8).
	var general_defs := {
		"iron_ore": {"stock": 20.0, "max": 120.0, "base": _bv(content, "iron_ore", 16.0), "consume": Config.SHOP_CONSUME["iron_ore"]},
		"logs": {"stock": 20.0, "max": 120.0, "base": _bv(content, "logs", 12.0), "consume": Config.SHOP_CONSUME["logs"]},
	}
	# Unit 1 — SHOPS TRADE GEAR: every tradeable catalog item with a gear tier joins the board
	# (catalog file order — deterministic). The roster split (Horvik/Lowe/...) arrives with Unit 2.
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
	shops = [general, market]
	for s: Shop in shops:
		for good in s.goods:
			_by_good[good] = s

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

## Hero buys cooked fish from the shop (a gold sink). Returns units bought.
func buy_food(hero: Hero, want: int) -> int:
	var bought := 0
	var p := food_price()
	var s: Shop = _by_good["trout"]
	while bought < want and hero.gold >= p and s.stock["trout"] >= 1.0 and not hero.inv_full():
		hero.gold -= p
		s.stock["trout"] -= 1.0
		hero.inv["trout"] = int(hero.inv.get("trout", 0)) + 1
		bought += 1
	return bought

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
	s.level_up()
	return true
