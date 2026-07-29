class_name MarketCatalog
extends RefCounted

const _CHIP_STOCK := 10
const _CSV_PATH := "res://reference/token_shop_prices.csv"
static var _stock_template: Dictionary = {}
static var _loaded := false

const CHAR_META := {
	"Scary Gary": {
		"slug": "gary",
		"color": Chip.ChipColor.BLUE,
		"unlock": 1,
		"shelf": "GaryInfo",
	},
	"Pumpkin": {
		"slug": "pumpkin",
		"color": Chip.ChipColor.ORANGE,
		"unlock": 1,
		"shelf": "PumpkinShelf",
	},
	"Spider": {
		"slug": "spider",
		"color": Chip.ChipColor.GREEN,
		"unlock": 1,
		"shelf": "SpiderShelf",
	},
	"Mushroom": {
		"slug": "shroom",
		"color": Chip.ChipColor.RED,
		"unlock": 1,
		"shelf": "ShroomInfo",
	},
	"Ghost (Puts)": {
		"slug": "poots",
		"color": Chip.ChipColor.PURPLE,
		"unlock": 3,
		"shelf": "Pootsshelf",
	},
	"Mandrake (Toby Turnip)": {
		"slug": "mandrake",
		"color": Chip.ChipColor.YELLOW,
		"unlock": 2,
		"shelf": "MandrakeShelf",
	},
	"Moth": {
		"slug": "moth",
		"color": Chip.ChipColor.BLACK,
		"unlock": 1,
		"shelf": "MothShelf",
	},
	"Cherry Bomb": {
		"slug": "white",
		"color": Chip.ChipColor.WHITE,
		"unlock": 1,
		"shelf": "WhiteShop",
	},
}

const SHELF_SLUGS := {
	"GaryInfo": "gary",
	"PumpkinShelf": "pumpkin",
	"SpiderShelf": "spider",
	"ShroomInfo": "shroom",
	"Pootsshelf": "poots",
	"MandrakeShelf": "mandrake",
	"MothShelf": "moth",
}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_stock_template.clear()
	for row: Dictionary in CsvUtil.parse_file(_CSV_PATH):
		var character := str(row["character"])
		if not CHAR_META.has(character):
			push_error("MarketCatalog: unknown character %s" % character)
			continue
		var meta: Dictionary = CHAR_META[character]
		var value := int(str(row["token_type"]).split(" ")[0])
		var sku_id := "%s_%d" % [meta["slug"], value]
		_stock_template[sku_id] = {
			"id": sku_id,
			"kind": "chip",
			"color": meta["color"],
			"value": value,
			"cost": int(row["cost"]),
			"stock": _CHIP_STOCK,
			"unlock_round": meta["unlock"],
			"label": "%s %d" % [character, value],
			"character_slug": meta["slug"],
			"shelf_node": meta["shelf"],
		}
	_loaded = true


static func default_stock() -> Dictionary:
	return SupplyScaler.build_market(1)


static func default_stock_template() -> Dictionary:
	ensure_loaded()
	return _stock_template.duplicate(true)


static func skus_for_shelf(shelf_node: String) -> Array:
	ensure_loaded()
	var skus: Array = []
	for sku_id: String in _stock_template:
		var entry: Dictionary = _stock_template[sku_id]
		if entry["shelf_node"] == shelf_node:
			skus.append(sku_id)
	return skus


static func is_unlocked(entry: Dictionary, round: int) -> bool:
	return round >= int(entry["unlock_round"])
