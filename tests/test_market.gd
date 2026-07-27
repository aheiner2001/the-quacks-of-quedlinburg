class_name TestMarket
extends RefCounted

static func run() -> int:
	var f := 0
	var stock := MarketCatalog.default_stock()
	f += AssertUtil.truthy(stock.has("gary_1"), "gary_1")
	f += AssertUtil.eq(int(stock["gary_1"]["cost"]), 5, "gary 1 cost")
	f += AssertUtil.eq(int(stock["gary_2"]["cost"]), 10, "gary 2 cost")
	f += AssertUtil.eq(int(stock["gary_4"]["cost"]), 19, "gary 4 cost")
	f += AssertUtil.eq(int(stock["pumpkin_1"]["cost"]), 3, "pumpkin 1")
	f += AssertUtil.truthy(stock.has("pumpkin_6"), "pumpkin 6")
	f += AssertUtil.eq(
		MarketCatalog.is_unlocked(stock["mandrake_1"], 1),
		false,
		"mandrake locked r1"
	)
	f += AssertUtil.eq(
		MarketCatalog.is_unlocked(stock["mandrake_1"], 2),
		true,
		"mandrake r2"
	)
	f += AssertUtil.eq(
		MarketCatalog.is_unlocked(stock["poots_1"], 2),
		false,
		"poots locked r2"
	)
	f += AssertUtil.eq(
		MarketCatalog.is_unlocked(stock["poots_1"], 3),
		true,
		"poots unlocks r3"
	)
	f += AssertUtil.eq(stock.has("flask_refill"), false, "no coin flask sku")
	f += AssertUtil.eq(stock.size(), 16, "one sku per CSV row")
	f += AssertUtil.eq(
		MarketCatalog.skus_for_shelf("GaryInfo"),
		["gary_1", "gary_2", "gary_4"],
		"gary shelf skus"
	)
	f += AssertUtil.eq(
		MarketCatalog.skus_for_shelf("PumpkinShelf"),
		["pumpkin_1", "pumpkin_6"],
		"pumpkin shelf skus"
	)
	f += AssertUtil.eq(stock["gary_1"]["kind"], "chip", "entry kind")
	f += AssertUtil.eq(stock["gary_1"]["color"], Chip.ChipColor.BLACK, "gary color")
	f += AssertUtil.eq(stock["gary_1"]["value"], 1, "gary value")
	f += AssertUtil.eq(stock["gary_1"]["stock"], 10, "gary stock")
	f += AssertUtil.eq(stock["gary_1"]["unlock_round"], 1, "gary unlock")
	f += AssertUtil.eq(stock["gary_1"]["label"], "Scary Gary 1", "gary label")
	f += AssertUtil.eq(stock["gary_1"]["character_slug"], "gary", "gary slug")
	f += AssertUtil.eq(stock["gary_1"]["shelf_node"], "GaryInfo", "gary shelf")
	stock["gary_1"]["stock"] = 0
	var fresh_stock := MarketCatalog.default_stock()
	f += AssertUtil.eq(
		fresh_stock["gary_1"]["stock"],
		10,
		"default stock deep-copies the cached template"
	)
	return f
