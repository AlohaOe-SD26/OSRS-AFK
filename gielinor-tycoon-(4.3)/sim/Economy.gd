class_name Economy
extends RefCounted
## NPC shop + the §6 faucet/sink model — a faithful GDScript port of the VALIDATED
## prototype economy (see Config.gd header). The key mechanics, in order of importance:
##
##  1. Saturation-aware sell price that decays toward ~0 (floor PRICE_FLOOR_FRAC) as stock
##     fills — closes the original "shop mints at floor price forever" leak (the ~16×
##     faucet/sink bug found in tuning).
##  2. Capacity-respecting sales: the shop only pays for whole units that fit under `max`
##     (town demand left room) → backpressure on over-gathering.
##  3. GE_TAX skim on every sale.
##  4. economy_tick(): town consumption drains stock (bounds the faucet) + wealth-proportional
##     hero upkeep (the stable attractor that flattens total gold).
##
## NOTE ON BASE VALUES: the four resource goods use the base values the equilibrium was
## tuned against (ore 16 / logs 12 / raw_fish 7 / cooked_fish 9). When the full item economy
## is wired, per-item base_value comes from the dataset (ContentDB) and the sinks get
## re-tuned against it — but for the Phase-0 gather loop these preserve the proven curve.

const GOODS := ["ore", "logs", "raw_fish", "cooked_fish"]

var stock: Dictionary = {"ore": 20.0, "logs": 20.0, "raw_fish": 10.0, "cooked_fish": 14.0}
var maximum: Dictionary = {"ore": 120.0, "logs": 120.0, "raw_fish": 80.0, "cooked_fish": 80.0}
var base: Dictionary = {"ore": 16, "logs": 12, "raw_fish": 7, "cooked_fish": 9}
const FOOD_BUY_BASE: float = 22.0   # what the shop charges heroes for cooked fish (the food sink)

## Price the shop PAYS a hero (falls toward PRICE_FLOOR_FRAC×base as stock saturates).
func sell_price(item: String) -> int:
	var r: float = stock[item] / maximum[item]
	var f: float = maxf(Config.PRICE_FLOOR_FRAC, 1.2 - r * 1.4)
	return maxi(1, int(round(base[item] * f)))

## Price the shop CHARGES a hero for cooked fish (rises as food stock falls).
func food_price() -> int:
	var r: float = stock["cooked_fish"] / maximum["cooked_fish"]
	return int(round(FOOD_BUY_BASE * (1.4 - r * 0.7)))

## Sell gathered ore/logs. Only whole units that fit are bought; GE_TAX is skimmed.
## Returns gold paid (leftover stays in the hero's bag → backpressure).
func sell_goods(hero: Hero) -> int:
	var g := 0
	for it in ["ore", "logs"]:
		var have := int(hero.inv.get(it, 0))
		if have <= 0:
			continue
		var room := int(floor(maxf(0.0, maximum[it] - stock[it])))
		var qty := mini(have, room)
		if qty > 0:
			g += int(round(qty * sell_price(it) * (1.0 - Config.GE_TAX)))
			stock[it] += qty
			hero.inv[it] = have - qty
	if g > 0:
		hero.gold += g
	return g

## Cooks supply the shop's food (keeping a small buffer if the hero is a fighter).
func sell_food(hero: Hero, keep: int = 0) -> int:
	var have := int(hero.inv.get("cooked_fish", 0))
	var qty := maxi(0, have - keep)
	var room := int(floor(maxf(0.0, maximum["cooked_fish"] - stock["cooked_fish"])))
	qty = mini(qty, room)
	if qty > 0:
		var pay := int(round(qty * sell_price("cooked_fish") * (1.0 - Config.GE_TAX)))
		hero.gold += pay
		stock["cooked_fish"] += qty
		hero.inv["cooked_fish"] = have - qty
		return pay
	return 0

## Hero buys cooked fish from the shop (a gold sink). Returns units bought.
func buy_food(hero: Hero, want: int) -> int:
	var bought := 0
	var p := food_price()
	while bought < want and hero.gold >= p and stock["cooked_fish"] >= 1.0:
		hero.gold -= p
		stock["cooked_fish"] -= 1.0
		hero.inv["cooked_fish"] = int(hero.inv.get("cooked_fish", 0)) + 1
		bought += 1
	return bought

## Per-work-action economy step. `dd` = fraction of a sim-day elapsed.
##  - town consumption drains stock (bounds the gather faucet)
##  - wealth-proportional + flat upkeep drains hero gold (the stable attractor sink)
## Returns total gold burned this step (telemetry).
func economy_tick(dd: float, heroes: Array) -> float:
	for it in Config.SHOP_CONSUME:
		if stock.has(it):
			stock[it] = maxf(0.0, stock[it] - float(Config.SHOP_CONSUME[it]) * dd)
	var burned := 0.0
	for hero in heroes:
		var drain: float = (Config.UPKEEP_FLAT + Config.UPKEEP_RATE * hero.gold) * dd
		drain = minf(hero.gold, drain)   # never drives gold negative
		hero.gold -= drain
		burned += drain
	return burned

func total_stock(item: String) -> int:
	return int(floor(stock.get(item, 0.0)))
