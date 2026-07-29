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
	f += _test_crow_skull_and_mandrake()
	return f

static func _test_crow_skull_and_mandrake() -> int:
	var f := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 301
	var player := PlayerState.create_fresh()
	player.bag = Bag.new()
	player.bag.add(Chip.make(Chip.ChipColor.ORANGE, 1))
	player.bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	ChipEffects.begin_crow_skull(player, 2, rng)
	f += AssertUtil.eq(player.pending_crow_draws.size(), 2, "crow draws up to its value")
	f += AssertUtil.truthy(player.awaiting_crow_choice, "crow awaits a pick")
	f += AssertUtil.eq(player.bag.size(), 0, "crow chips leave bag pending choice")

	var game := GameState.new_game(1, 302)
	game.begin_round()
	game.players[0] = player
	game.resolve_crow_skull(0, 0)
	f += AssertUtil.eq(player.pot.placements.size(), 1, "crow keeps selected chip")
	f += AssertUtil.eq(player.bag.size(), 1, "crow returns unselected chip to bag")
	f += AssertUtil.eq(player.pending_crow_draws.size(), 0, "crow clears pending chips")
	f += AssertUtil.eq(player.awaiting_crow_choice, false, "crow choice resolves pending state")

	var mandrake := PlayerState.create_fresh()
	mandrake.bag = Bag.new()
	mandrake.pot.place(Chip.make(Chip.ChipColor.WHITE, 2))
	mandrake.place_drawn_chip(Chip.make(Chip.ChipColor.YELLOW, 1), rng)
	f += AssertUtil.truthy(mandrake.awaiting_mandrake, "yellow after white awaits mandrake choice")
	game.players[0] = mandrake
	game.resolve_mandrake(0, true)
	f += AssertUtil.eq(mandrake.pot.placements.size(), 1, "mandrake removes prior white placement")
	f += AssertUtil.eq(
		mandrake.pot.last_chip()["color"],
		Chip.ChipColor.YELLOW,
		"mandrake keeps yellow in pot"
	)
	f += AssertUtil.eq(
		mandrake.bag.count_matching(Chip.ChipColor.WHITE, 2),
		1,
		"mandrake returns white chip to bag"
	)
	f += AssertUtil.eq(mandrake.awaiting_mandrake, false, "mandrake choice resolves pending state")

	var nested := PlayerState.create_fresh()
	nested.bag = Bag.new()
	nested.bag.add(Chip.make(Chip.ChipColor.ORANGE, 1))
	nested.pending_crow_draws = [Chip.make(Chip.ChipColor.BLUE, 1)]
	nested.awaiting_crow_choice = true
	game.players[0] = nested
	game.resolve_crow_skull(0, 0)
	f += AssertUtil.eq(nested.pot.placements.size(), 1, "nested crow places kept blue")
	f += AssertUtil.truthy(nested.awaiting_crow_choice, "kept blue begins another crow choice")
	f += AssertUtil.eq(nested.pending_crow_draws.size(), 1, "nested crow draws another option")
	return f
