class_name TestChipEffects
extends RefCounted

static func run() -> int:
	var f := 0
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(0), 0, "0 orange → +0")
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(1), 1, "1 orange → +1")
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(2), 1, "2 orange → +1")
	f += AssertUtil.eq(ChipEffects.toadstool_bonus(3), 2, "3 orange → +2")

	var pot := Pot.new()
	pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	f += AssertUtil.eq(pot.count_color(Chip.ChipColor.ORANGE), 2, "count oranges")

	var red := Chip.make(Chip.ChipColor.RED, 1)
	var before_oranges := pot.count_color(Chip.ChipColor.ORANGE)
	var result := pot.place(red, ChipEffects.toadstool_bonus(before_oranges))
	# droplet 0 + orange1 → idx1; +orange1 → idx2; red1 + bonus1 → idx4
	f += AssertUtil.eq(int(result["index"]), 4, "toadstool lands with orange bonus")
	return f
