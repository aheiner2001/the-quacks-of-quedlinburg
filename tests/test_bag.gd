class_name TestBag
extends RefCounted

static func run() -> int:
	var f := 0
	var bag := Bag.make_starter()
	f += AssertUtil.eq(bag.size(), 9, "starter size")
	f += AssertUtil.eq(bag.count_matching(Chip.ChipColor.WHITE, 1), 4, "white 1s")
	f += AssertUtil.eq(bag.count_matching(Chip.ChipColor.WHITE, 2), 2, "white 2s")
	f += AssertUtil.eq(bag.count_matching(Chip.ChipColor.WHITE, 3), 1, "white 3s")
	f += AssertUtil.eq(bag.count_matching(Chip.ChipColor.ORANGE, 1), 1, "orange 1")
	f += AssertUtil.eq(bag.count_matching(Chip.ChipColor.GREEN, 1), 1, "green 1")

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var drawn := bag.draw(rng)
	f += AssertUtil.eq(bag.size(), 8, "after draw size")
	bag.put_back(drawn)
	f += AssertUtil.eq(bag.size(), 9, "after put_back")

	var b1 := Bag.make_starter()
	var b2 := Bag.make_starter()
	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 42
	r2.seed = 42
	f += AssertUtil.eq(b1.draw(r1), b2.draw(r2), "seeded draw deterministic")
	return f
