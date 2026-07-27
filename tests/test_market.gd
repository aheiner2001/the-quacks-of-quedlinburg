class_name TestMarket
extends RefCounted

static func run() -> int:
	var f := 0
	var stock := MarketCatalog.default_stock()
	f += AssertUtil.truthy(stock.has("pumpkin"), "has pumpkin")
	f += AssertUtil.truthy(stock.has("flask_refill"), "has flask")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["mandrake"], 1), false, "mandrake locked r1")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["mandrake"], 2), true, "mandrake r2")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["poots"], 2), false, "poots locked r2")
	f += AssertUtil.eq(MarketCatalog.is_unlocked(stock["poots"], 3), true, "poots r3")
	return f
