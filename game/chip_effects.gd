class_name ChipEffects
extends RefCounted

static func toadstool_bonus(orange_count: int) -> int:
	if orange_count <= 0:
		return 0
	if orange_count <= 2:
		return 1
	return 2
