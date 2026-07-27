class_name TestChip
extends RefCounted

static func run() -> int:
	var f := 0
	var c := Chip.make(Chip.Color.WHITE, 2)
	f += AssertUtil.eq(c["color"], Chip.Color.WHITE, "chip color")
	f += AssertUtil.eq(c["value"], 2, "chip value")
	f += AssertUtil.truthy(Chip.is_white(c), "white check")
	f += AssertUtil.eq(Chip.is_white(Chip.make(Chip.Color.ORANGE, 1)), false, "orange not white")
	return f
