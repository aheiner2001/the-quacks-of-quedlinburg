class_name SupplyScaler
extends RefCounted

const VALUE_BAND := {1: 4, 2: 2, 3: 1, 4: 1, 6: 1}

static func shared_token_supply(n: int) -> int:
	return int(round(75.0 * n))

static func shared_ruby_supply(n: int) -> int:
	return int(round(8.0 * n))

static func fortune_deck_size(n: int) -> int:
	return int(round(9.0 * n))

static func value_band(value: int) -> int:
	return int(VALUE_BAND.get(value, 1))

static func build_market(num_players: int) -> Dictionary:
	MarketCatalog.ensure_loaded()
	var template := MarketCatalog.default_stock_template()
	var ids: Array = template.keys()
	var weights: Array = []
	var total_w := 0.0
	for id in ids:
		var entry: Dictionary = template[id]
		var weight := float(value_band(int(entry["value"]))) / float(maxi(int(entry["cost"]), 1))
		weights.append(weight)
		total_w += weight
	var target := shared_token_supply(num_players)
	var raw: Array = []
	var floors: Array = []
	var floor_sum := 0
	for i in ids.size():
		var exact: float = (weights[i] / total_w) * float(target)
		var floor_value := int(floor(exact))
		floors.append(floor_value)
		raw.append(exact - float(floor_value))
		floor_sum += floor_value
	var remaining := target - floor_sum
	var order: Array = range(ids.size())
	order.sort_custom(func(a, b): return raw[a] > raw[b])
	for i in remaining:
		floors[order[i]] += 1
	var market := {}
	for i in ids.size():
		var entry: Dictionary = template[ids[i]].duplicate(true)
		entry["stock"] = floors[i]
		market[ids[i]] = entry
	return market
