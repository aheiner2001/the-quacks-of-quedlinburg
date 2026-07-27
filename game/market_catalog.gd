class_name MarketCatalog
extends RefCounted

const _CHIP_STOCK := 10
const _FLASK_STOCK := 99

static var _SKUS: Array = [
	{"id": "pumpkin", "kind": "chip", "color": Chip.ChipColor.ORANGE, "value": 1, "cost": 3, "unlock_round": 1, "label": "Pumpkin"},
	{"id": "shroom", "kind": "chip", "color": Chip.ChipColor.GREEN, "value": 1, "cost": 4, "unlock_round": 1, "label": "Shroom"},
	{"id": "spider", "kind": "chip", "color": Chip.ChipColor.BLUE, "value": 1, "cost": 6, "unlock_round": 1, "label": "Spider"},
	{"id": "moth", "kind": "chip", "color": Chip.ChipColor.RED, "value": 1, "cost": 6, "unlock_round": 1, "label": "Moth"},
	{"id": "mandrake", "kind": "chip", "color": Chip.ChipColor.YELLOW, "value": 1, "cost": 8, "unlock_round": 2, "label": "Mandrake"},
	{"id": "poots", "kind": "chip", "color": Chip.ChipColor.PURPLE, "value": 1, "cost": 9, "unlock_round": 3, "label": "Poots"},
	{"id": "white_1", "kind": "chip", "color": Chip.ChipColor.WHITE, "value": 1, "cost": 1, "unlock_round": 1, "label": "White 1"},
	{"id": "white_2", "kind": "chip", "color": Chip.ChipColor.WHITE, "value": 2, "cost": 2, "unlock_round": 1, "label": "White 2"},
	{"id": "white_3", "kind": "chip", "color": Chip.ChipColor.WHITE, "value": 3, "cost": 4, "unlock_round": 1, "label": "White 3"},
	{"id": "flask_refill", "kind": "flask_refill", "color": null, "value": null, "cost": 2, "unlock_round": 1, "label": "Flask Refill"},
]


static func default_stock() -> Dictionary:
	var stock := {}
	for sku in _SKUS:
		var stock_count := _FLASK_STOCK if sku["kind"] == "flask_refill" else _CHIP_STOCK
		stock[sku["id"]] = sku.duplicate(true)
		stock[sku["id"]]["stock"] = stock_count
	return stock


static func is_unlocked(entry: Dictionary, round: int) -> bool:
	return round >= int(entry["unlock_round"])
