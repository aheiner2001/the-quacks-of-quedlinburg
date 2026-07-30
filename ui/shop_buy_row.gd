class_name ShopBuyRow
extends HBoxContainer

## Fixed slot row for ingredient buy options. Reposition/restyle in the editor;
## call bind_skus() from shop logic to fill values only.

signal buy_pressed(sku: String)


func _ready() -> void:
	for option in _options():
		if not option.buy_pressed.is_connected(_on_option_buy):
			option.buy_pressed.connect(_on_option_buy)
		if option.sku.is_empty():
			option.clear_option()


func _options() -> Array[ShopBuyOption]:
	var out: Array[ShopBuyOption] = []
	for child in get_children():
		if child is ShopBuyOption:
			out.append(child)
	return out


func option_count() -> int:
	var n := 0
	for option in _options():
		if option.visible and not option.sku.is_empty():
			n += 1
	return n


func skus() -> Array[String]:
	var out: Array[String] = []
	for option in _options():
		if option.visible and not option.sku.is_empty():
			out.append(option.sku)
	return out


func option_at(index: int) -> ShopBuyOption:
	var visible_options: Array[ShopBuyOption] = []
	for option in _options():
		if option.visible and not option.sku.is_empty():
			visible_options.append(option)
	if index < 0 or index >= visible_options.size():
		return null
	return visible_options[index]


func find_option(sku: String) -> ShopBuyOption:
	for option in _options():
		if option.sku == sku:
			return option
	return null


func bind_skus(skus: Array, market: Dictionary, can_buy_fn: Callable) -> void:
	var options := _options()
	for i in options.size():
		var option: ShopBuyOption = options[i]
		if i < skus.size():
			var sku: String = str(skus[i])
			var entry: Dictionary = market[sku]
			option.bind(
				sku,
				int(entry["value"]),
				int(entry["cost"]),
				bool(can_buy_fn.call(sku))
			)
		else:
			option.clear_option()


func _on_option_buy(sku: String) -> void:
	buy_pressed.emit(sku)
