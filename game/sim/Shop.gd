class_name Shop
extends RefCounted
## A first-class NPC shop (GDD §6.4 / §7 / §19.2). Phase-0 step-3 promotes the economy's
## previously-implicit "one big price table" into named, INSPECTABLE shop entities — each with
## its own stock, the goods it trades, and a `level` (the §19.2 shop-leveling dial, wired in
## Step 4: restock speed / higher-tier stock / quantity all scale with it).
##
## The dynamic-price mechanic (GDD §6.4 / EQUATIONS §5) lives here now: buying price rises as
## stock falls (scarcity); selling price falls as stock rises (anti-dumping), bounded by a floor.
## The exact curves are the ones the equilibrium was VALIDATED against in the prototype — moved,
## not re-derived (see Economy.gd / Config.gd headers).
##
## `consume` is this shop's slice of town demand (units/sim-day the NPC town absorbs) — the
## first-class form of the gather-faucet backpressure that used to be a loose Config dict applied
## inline in Economy.economy_tick.

var npc_id: String = ""
var shop_name: String = ""
var goods: Array = []                  # good ids this shop trades
var stock: Dictionary = {}             # good -> float (kept float for sub-unit consumption)
var maximum: Dictionary = {}           # good -> float capacity
var base: Dictionary = {}              # good -> base value (canon; catalog-sourced since Unit 1)
var consume: Dictionary = {}           # good -> units/sim-day town demand (faucet backpressure, §6)
var level: int = 1                     # §19.2 shop level (1..99); gates unlockLevel stock (Unit 2)
# ---- Unit 2 (shop economy v2) — STATIC per-good defs (from shops.json; not serialized) ----
var baseline: Dictionary = {}          # good -> ambient-import target (C5); 0 = hero-supplied, no imports
var charge: Dictionary = {}            # good -> buy-side price anchor (= the price at baseline 0.5 fill)
var unlock: Dictionary = {}            # good -> shop level required to BUY it (vendoring is never gated)

static func make(id: String, display: String, defs: Dictionary) -> Shop:
	## defs: good -> { "stock": float, "max": float, "base": float, "consume": float,
	##                 "baseline": float, "charge": float, "unlockLevel": int }
	var s := Shop.new()
	s.npc_id = id
	s.shop_name = display
	for good in defs:
		var d: Dictionary = defs[good]
		s.goods.append(good)
		s.stock[good] = float(d.get("stock", 0.0))
		s.maximum[good] = float(d.get("max", 1.0))
		s.base[good] = float(d.get("base", 1.0))
		s.consume[good] = float(d.get("consume", 0.0))
		s.baseline[good] = float(d.get("baseline", 0.0))
		s.charge[good] = float(d.get("charge", 0.0))
		s.unlock[good] = int(d.get("unlockLevel", 1))
	return s

func trades(good: String) -> bool:
	return stock.has(good)

## Unit 2: may a hero BUY this good here right now? Stock-gated (purchases draw real stock — the
## R3 supply-gating lesson) and level-gated (tier-up unlocks). Vendoring is deliberately NOT gated.
func can_buy(good: String) -> bool:
	return stock.has(good) and stock[good] >= 1.0 and level >= int(unlock.get(good, 1)) \
		and float(charge.get(good, 0.0)) > 0.0

## Unit 2: per-good dynamic BUY price. Same scarcity curve as buy_price, normalized so the price at
## baseline fill (r = 0.5) equals the `charge` anchor exactly — the validated flat costs (tool 12g,
## weapon 30g, ...) are reproduced at equilibrium and rise/fall with real scarcity around it.
func charge_price(good: String) -> int:
	var r: float = stock[good] / maximum[good]
	return maxi(1, int(round(float(charge[good]) * (1.4 - r * 0.7) / 1.05)))

## Price the shop PAYS a hero for `good` (falls toward PRICE_FLOOR_FRAC×base as stock saturates).
## Identical curve to the validated prototype: f = clamp(1.2 − fill×1.4, floor, ·).
func sell_price(good: String) -> int:
	var r: float = stock[good] / maximum[good]
	var f: float = maxf(Config.PRICE_FLOOR_FRAC, 1.2 - r * 1.4)
	return maxi(1, int(round(base[good] * f)))

## Price the shop CHARGES a hero for `good` (rises as stock falls — scarcity). `charge_base`
## is what the shop marks the good up to at neutral stock (the food sink uses FOOD_BUY_BASE).
func buy_price(good: String, charge_base: float) -> int:
	var r: float = stock[good] / maximum[good]
	return int(round(charge_base * (1.4 - r * 0.7)))

func room_for(good: String) -> int:
	return int(floor(maxf(0.0, maximum[good] - stock[good])))

## Town consumption drains stock (bounds the gather faucet). `dd` = fraction of a sim-day;
## `pop_scale` grows town demand with the colony so faucets & sinks scale together (§6.5).
func consume_tick(dd: float, pop_scale: float = 1.0) -> void:
	for good in consume:
		if stock.has(good):
			stock[good] = maxf(0.0, stock[good] - float(consume[good]) * dd * pop_scale)

## Unit 2 (C5): AMBIENT IMPORTS — stock drifts UP toward its baseline (caravans restock what the
## town supplies; never destroys stock, never exceeds the baseline). Only goods with baseline > 0
## participate — hero-supplied goods (ore/logs/fish/dropped gear) keep baseline 0 so the validated
## gather/vendor faucets stay the sole supply. This is the R3 supply-gating fix: ammo, runes and
## starter weapons are RELIABLY purchasable, so the combat triangle can actually express.
func import_tick(dd: float) -> void:
	for good in baseline:
		var target: float = float(baseline[good])
		if target > 0.0 and stock[good] < target:
			stock[good] = minf(target, stock[good] + (target - stock[good]) * Config.SHOP_IMPORT_K * dd)

func total_stock(good: String) -> int:
	return int(floor(stock.get(good, 0.0)))

## §19.2 shop level-up: raise the level and scale stock CAPACITY and town DEMAND by the same factor.
## Scaling both together keeps the per-good faucet/sink ratio invariant (the §6.5 principle already
## used for population) → a leveled-up shop moves more volume but the equilibrium stays bounded.
func level_up() -> void:
	level += 1
	var factor := 1.0 + Config.SHOP_CAP_PER_LEVEL
	for good in goods:
		maximum[good] = maximum[good] * factor
		if consume.has(good):
			consume[good] = consume[good] * factor
