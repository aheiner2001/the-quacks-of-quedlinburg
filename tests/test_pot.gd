class_name TestPot
extends RefCounted

static func run() -> int:
	var f := 0
	PotTrack.ensure_loaded()
	f += AssertUtil.eq(PotTrack.max_space(), 54, "max space 54")
	f += AssertUtil.eq(PotTrack.coins_for_space(0), 0, "space 0 coins")
	f += AssertUtil.eq(PotTrack.coins_for_space(6), 5, "node 6 money")
	f += AssertUtil.eq(PotTrack.vp_for_space(6), 0, "node 6 vp")
	f += AssertUtil.truthy(PotTrack.has_ruby(6), "node 6 ruby")
	f += AssertUtil.eq(PotTrack.coins_for_space(23), 18, "node 23 money")
	f += AssertUtil.eq(PotTrack.vp_for_space(23), 5, "node 23 vp")
	f += AssertUtil.eq(PotTrack.coins_for_space(54), 35, "node 54 money")
	f += AssertUtil.eq(PotTrack.vp_for_space(54), 15, "node 54 vp")
	f += AssertUtil.eq(PotTrack.has_ruby(54), false, "node 54 no ruby")
	f += AssertUtil.eq(PotTrack.coins_for_space(33), 23, "node 33 money from CSV")
	f += AssertUtil.eq(PotTrack.vp_for_space(33), 8, "node 33 vp from CSV")

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

	var p3 := Pot.new()
	# Force far placement: droplet 50 + white 4 → clamp 54
	p3.droplet = 50
	var far := p3.place(Chip.make(Chip.ChipColor.WHITE, 4))
	f += AssertUtil.eq(far["index"], 54, "clamp to max space")
	f += AssertUtil.eq(p3.scoring_space(), 54, "scoring at cap")
	return f
