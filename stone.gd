extends StaticBody2D

@export var stone_value: int = 0:
	set(value):
		stone_value = value
		_update_label()

func _ready() -> void:
	_update_label()

func _update_label() -> void:
	if has_node("Label"):
		$Label.text = str(stone_value)
