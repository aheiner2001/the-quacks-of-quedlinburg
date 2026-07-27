class_name TestPotions
extends RefCounted

static func run() -> int:
	var f := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# create_fresh: flask full, starter bag size 9
	var p := PlayerState.create_fresh()
	f += AssertUtil.truthy(p.flask_full, "flask starts full")
	f += AssertUtil.eq(p.bag.size(), 9, "starter bag size 9")

	# Deterministic white-2 draw → flask undo
	p.bag = Bag.new()
	p.bag.add(Chip.make(Chip.ChipColor.WHITE, 2))
	p.bag.add(Chip.make(Chip.ChipColor.WHITE, 2))
	var r := p.draw(rng)
	f += AssertUtil.eq(r["index"], 2, "placed white 2")
	f += AssertUtil.truthy(p.can_use_flask(), "flask ok on white")
	f += AssertUtil.truthy(p.use_flask(), "flask used")
	f += AssertUtil.eq(p.flask_full, false, "flask empty after use")
	f += AssertUtil.eq(p.bag.size(), 2, "chip returned to bag")
	f += AssertUtil.eq(p.pot.placements.size(), 0, "placement undone")
	f += AssertUtil.eq(p.stopped, false, "mid-draw flask allows continuing")

	# A player who voluntarily stopped cannot use the flask to resume.
	var stopped_player := PlayerState.create_fresh()
	stopped_player.bag = Bag.new()
	stopped_player.bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	stopped_player.bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	stopped_player.draw(rng)
	stopped_player.stop()
	f += AssertUtil.eq(stopped_player.can_use_flask(), false, "cannot flask after stopping")
	f += AssertUtil.eq(stopped_player.use_flask(), false, "flask cannot undo voluntary stop")
	f += AssertUtil.eq(stopped_player.pot.placements.size(), 1, "stopped placement remains")

	# Explosion via draws: white 3, white 3, white 2 → no flask
	var p3 := PlayerState.create_fresh()
	p3.stopped = false
	p3.bag = Bag.new()
	p3.bag.add(Chip.make(Chip.ChipColor.WHITE, 3))
	p3.draw(rng)
	p3.stopped = false
	p3.bag = Bag.new()
	p3.bag.add(Chip.make(Chip.ChipColor.WHITE, 3))
	p3.draw(rng)
	p3.stopped = false
	p3.bag = Bag.new()
	p3.bag.add(Chip.make(Chip.ChipColor.WHITE, 2))
	p3.draw(rng)
	f += AssertUtil.truthy(p3.exploded, "exploded via draws")
	f += AssertUtil.eq(p3.can_use_flask(), false, "cannot flask after explosion")

	return f
