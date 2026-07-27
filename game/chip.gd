class_name Chip
extends RefCounted

enum ChipColor { WHITE, ORANGE, GREEN, BLUE, RED, YELLOW, PURPLE, BLACK }

static func make(color: int, value: int) -> Dictionary:
	return {"color": color, "value": value}

static func is_white(chip: Dictionary) -> bool:
	return int(chip["color"]) == ChipColor.WHITE
