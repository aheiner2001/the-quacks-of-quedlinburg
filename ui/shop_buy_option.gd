class_name ShopBuyOption
extends Button

## Editor-editable buy chip control. Script only fills value/cost/enabled — layout lives in the scene.

signal buy_pressed(sku: String)

@export var sku: String = ""

@onready var _value_label: Label = get_node_or_null("ValueLabel") as Label
@onready var _cost_label: Label = get_node_or_null("CostLabel") as Label


func _ready() -> void:
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)
	if sku.is_empty():
		visible = false


func bind(p_sku: String, value: int, cost: int, can_buy: bool) -> void:
	sku = p_sku
	set_meta("sku", p_sku)
	visible = true
	disabled = not can_buy
	if _value_label:
		_value_label.text = str(value)
	if _cost_label:
		_cost_label.text = str(cost)
	# Keep a readable caption on the button itself (labels stay art-directable).
	text = "%d for %d coins" % [value, cost]
	tooltip_text = text


func clear_option() -> void:
	sku = ""
	if has_meta("sku"):
		remove_meta("sku")
	visible = false
	disabled = true
	text = ""
	if _value_label:
		_value_label.text = ""
	if _cost_label:
		_cost_label.text = ""


func _on_pressed() -> void:
	if sku.is_empty():
		return
	buy_pressed.emit(sku)
