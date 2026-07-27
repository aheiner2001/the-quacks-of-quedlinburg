class_name TestPot
extends RefCounted

static func run() -> int:
	var f := 0
	f += AssertUtil.eq(PotTrack.coins_for_space(15), 15, "coins=space")
	f += AssertUtil.eq(PotTrack.coins_for_space(33), 35, "coins at 33")
	f += AssertUtil.eq(PotTrack.vp_for_space(19), 5, "vp 19")
	f += AssertUtil.eq(PotTrack.vp_for_space(23), 7, "vp 23")
	f += AssertUtil.eq(PotTrack.vp_for_space(33), 15, "vp 33")

	var pot := Pot.new()
	var r1 := pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	f += AssertUtil.eq(r1["index"], 1, "first chip on 1")
	f += AssertUtil.eq(pot.white_sum(), 0, "orange ignored")
	var r2 := pot.place(Chip.make(Chip.ChipColor.WHITE, 2))
	f += AssertUtil.eq(r2["index"], 3, "white 2 from 1 -> 3")
	f += AssertUtil.eq(pot.white_sum(), 2, "white sum 2")
	f += AssertUtil.eq(pot.scoring_space(), 4, "scoring after last")

	# Explosion: whites 3+3+2 = 8 > 7
	var p2 := Pot.new()
	p2.place(Chip.make(Chip.ChipColor.WHITE, 3))
	p2.place(Chip.make(Chip.ChipColor.WHITE, 3))
	var boom := p2.place(Chip.make(Chip.ChipColor.WHITE, 2))
	f += AssertUtil.truthy(boom["exploded"], "exploded")
	f += AssertUtil.eq(boom["index"], 8, "exploding chip still placed")
	f += AssertUtil.eq(p2.scoring_space(), 9, "scoring after boom")
	return f
