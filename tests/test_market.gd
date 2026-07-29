class_name TestMarket
extends RefCounted

static func run() -> int:
	var f := 0
	var stock := MarketCatalog.default_stock()
	f += AssertUtil.eq(int(stock["gary_1"]["color"]), Chip.ChipColor.BLUE, "gary is blue Crow Skull")
	f += AssertUtil.eq(int(stock["spider_1"]["color"]), Chip.ChipColor.GREEN, "spider is green")
	f += AssertUtil.eq(int(stock["shroom_1"]["color"]), Chip.ChipColor.RED, "mushroom is red Toadstool")
	f += AssertUtil.eq(int(stock["moth_1"]["color"]), Chip.ChipColor.BLACK, "moth is black Hawkmoth")
	f += AssertUtil.eq(int(stock["poots_1"]["color"]), Chip.ChipColor.PURPLE, "ghost is purple")
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
	f += AssertUtil.eq(stock.size(), 20, "one sku per CSV row")
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
	f += AssertUtil.eq(stock["gary_1"]["value"], 1, "gary value")
	f += AssertUtil.truthy(int(stock["gary_1"]["stock"]) > 0, "gary stock")
	f += AssertUtil.eq(stock["gary_1"]["unlock_round"], 1, "gary unlock")
	f += AssertUtil.eq(stock["gary_1"]["label"], "Scary Gary 1", "gary label")
	f += AssertUtil.eq(stock["gary_1"]["character_slug"], "gary", "gary slug")
	f += AssertUtil.eq(stock["gary_1"]["shelf_node"], "GaryInfo", "gary shelf")
	var original_gary_stock := int(stock["gary_1"]["stock"])
	stock["gary_1"]["stock"] = 0
	var fresh_stock := MarketCatalog.default_stock()
	f += AssertUtil.eq(
		fresh_stock["gary_1"]["stock"],
		original_gary_stock,
		"default stock deep-copies the cached template"
	)
	return f
