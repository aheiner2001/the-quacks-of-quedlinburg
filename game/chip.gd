class_name Chip
extends RefCounted

enum Color { WHITE, ORANGE, GREEN, BLUE, RED, YELLOW, PURPLE, BLACK }

static func make(color: int, value: int) -> Dictionary:
	return {"color": color, "value": value}

static func is_white(chip: Dictionary) -> bool:
	return int(chip["color"]) == Color.WHITE
