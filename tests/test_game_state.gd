class_name TestGameState
extends RefCounted

static func run() -> int:
	var f := 0
	f += _test_new_game_and_round_reset()
	f += _test_evaluation_fork_and_shop()
	f += _test_ruby_grant_and_flask_refill()
	f += _test_turn_nine_and_winners()
	f += _test_potion_helpers_and_end_turn()
	f += _test_pending_potion_choices_block_stop_and_flask()
	f += _test_evaluation_b_chip_actions()
	return f

static func _test_new_game_and_round_reset() -> int:
	var f := 0
	var gs := GameState.new_game(2, 1)
	f += AssertUtil.eq(gs.players.size(), 2, "2 players")
	f += AssertUtil.eq(gs.round, 1, "round 1")
	f += AssertUtil.eq(gs.phase, "", "phase initially unset")
	gs.begin_round()
	f += AssertUtil.eq(gs.phase, "potions", "skip stubs to potions")
	f += AssertUtil.eq(gs.active_player, 0, "start player active")

	gs.round = 6
	var before := gs.players[0].bag.size()
	gs.begin_round()
	f += AssertUtil.eq(gs.players[0].bag.size(), before + 1, "round 6 adds white 1")
	f += AssertUtil.eq(
		gs.players[0].bag.count_matching(Chip.ChipColor.WHITE, 1),
		5,
		"round 6 white 1 count"
	)
	var after_first_begin := gs.players[0].bag.size()
	gs.begin_round()
	f += AssertUtil.eq(
		gs.players[0].bag.size(),
		after_first_begin,
		"round 6 white 1 is granted once"
	)
	return f

static func _test_evaluation_fork_and_shop() -> int:
	var f := 0
	var gs := GameState.new_game(2, 2)
	gs.begin_round()
	gs.players[0].pot.placements = [
		{"chip": Chip.make(Chip.ChipColor.ORANGE, 3), "index": 22}
	]
	gs.players[0].stopped = true
	gs.players[1].exploded = true
	gs.players[1].stopped = true
	gs.begin_evaluation()
	f += AssertUtil.eq(gs.players[0].coins, 18, "evaluation awards coins")
	f += AssertUtil.eq(gs.players[0].vp, 5, "non-exploded automatically gains non-zero vp")
	f += AssertUtil.truthy(gs.players[0].chose_vp, "mandatory vp is recorded")
	f += AssertUtil.eq(gs.take_vp(0), false, "mandatory vp cannot be taken twice")
	f += AssertUtil.eq(gs.players[1].chose_vp, false, "exploded player still chooses reward")
	f += AssertUtil.truthy(gs.go_to_shop(0), "non-exploded also shops")
	f += AssertUtil.truthy(gs.go_to_shop(1), "exploded chooses shop")
	f += AssertUtil.eq(gs.take_vp(1), false, "exploded cannot take vp after shop")

	gs.players[0].coins = 30
	f += AssertUtil.truthy(gs.can_buy(0, "pumpkin_1"), "can_buy allows valid purchase")
	f += AssertUtil.eq(gs.buy(0, "mandrake_1"), false, "mandrake locked r1")
	gs.round = 2
	f += AssertUtil.truthy(gs.buy(0, "mandrake_1"), "mandrake r2")
	f += AssertUtil.eq(gs.players[0].pending_bag_chips.size(), 1, "chip queued for bag")
	f += AssertUtil.eq(
		gs.can_buy(0, "mandrake_2"),
		false,
		"can_buy rejects a second chip of the same color"
	)
	f += AssertUtil.eq(gs.buy(0, "mandrake_2"), false, "cannot buy same chip color twice")
	f += AssertUtil.truthy(gs.buy(0, "pumpkin_1"), "second distinct chip")
	f += AssertUtil.eq(gs.buy(0, "shroom_1"), false, "maximum two purchases")

	var g2 := GameState.new_game(1, 3)
	g2.begin_round()
	g2.players[0].exploded = true
	g2.players[0].stopped = true
	g2.begin_evaluation()
	f += AssertUtil.truthy(g2.take_vp(0), "exploded chooses vp")
	f += AssertUtil.eq(g2.go_to_shop(0), false, "exploded cannot shop after vp")

	var g3 := GameState.new_game(1, 4)
	g3.begin_round()
	g3.players[0].stopped = true
	g3.begin_evaluation()
	f += AssertUtil.truthy(g3.go_to_shop(0), "shop can be finished without buying")
	f += AssertUtil.eq(g3.take_vp(0), false, "automatic vp is not awarded twice")
	# Flask refills move to the ruby-based refill_flask API in Task 4.
	g3.finish_shop(0)
	f += AssertUtil.truthy(g3.players[0].evaluation_done, "shop finish completes evaluation")
	f += AssertUtil.eq(g3.buy(0, "pumpkin_1"), false, "cannot buy after finishing shop")
	return f

static func _test_ruby_grant_and_flask_refill() -> int:
	var f := 0
	var gs := GameState.new_game(1, 9)
	gs.begin_round()
	gs.players[0].pot.placements = [
		{"chip": Chip.make(Chip.ChipColor.ORANGE, 1), "index": 5}
	]
	gs.begin_evaluation()
	f += AssertUtil.eq(gs.players[0].rubies, 1, "ruby granted on ruby scoring space")
	f += AssertUtil.eq(
		gs.players[0].coins,
		PotTrack.coins_for_space(6),
		"coins granted from same scoring space"
	)

	gs.players[0].flask_full = false
	gs.players[0].rubies = 2
	f += AssertUtil.truthy(gs.refill_flask(0), "two rubies refill an empty flask")
	f += AssertUtil.eq(gs.players[0].rubies, 0, "flask refill spends two rubies")
	f += AssertUtil.truthy(gs.players[0].flask_full, "refilled flask is full")
	f += AssertUtil.eq(gs.refill_flask(0), false, "full flask cannot be refilled")
	f += AssertUtil.eq(gs.refill_flask(-1), false, "invalid player cannot refill")

	var controller := PhaseController.new()
	controller.setup(1, 10)
	controller.begin_round()
	controller.state.players[0].flask_full = false
	controller.state.players[0].rubies = 2
	f += AssertUtil.eq(
		controller.refill_flask_active(),
		false,
		"flask cannot be refilled during potions"
	)
	controller.stop_active()
	controller.finish_bonus_die_phase()
	f += AssertUtil.truthy(controller.refill_flask_active(), "controller refills active flask")
	controller.free()
	return f

static func _test_turn_nine_and_winners() -> int:
	var f := 0
	var gs := GameState.new_game(2, 5)
	gs.round = 9
	gs.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 3))
	gs.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	gs.players[0].stopped = true
	gs.players[1].stopped = true
	gs.begin_evaluation()
	f += AssertUtil.eq(gs.players[0].final_pot_furthest, 3, "stores final pot distance")
	gs.players[0].coins = 10
	gs.players[0].rubies = 4
	var vp_before := gs.players[0].vp
	f += AssertUtil.truthy(gs.convert_coins_to_vp(0), "convert 5 coins")
	f += AssertUtil.eq(gs.players[0].vp, vp_before + 1, "coin conversion gains vp")
	f += AssertUtil.eq(gs.players[0].coins, 5, "coin conversion leaves remainder")
	f += AssertUtil.truthy(gs.convert_rubies_to_vp(0), "convert 2 rubies")
	f += AssertUtil.eq(gs.players[0].rubies, 2, "ruby conversion leaves remainder")
	f += AssertUtil.eq(gs.buy(0, "pumpkin_1"), false, "no buying round 9")

	var exploded_convert_first := GameState.new_game(1, 7)
	exploded_convert_first.round = 9
	exploded_convert_first.players[0].exploded = true
	exploded_convert_first.begin_evaluation()
	exploded_convert_first.players[0].coins = 5
	f += AssertUtil.truthy(
		exploded_convert_first.convert_coins_to_vp(0),
		"exploded player converts before vp"
	)
	f += AssertUtil.eq(
		exploded_convert_first.take_vp(0),
		false,
		"exploded player cannot take vp after converting"
	)

	var exploded_vp_first := GameState.new_game(1, 8)
	exploded_vp_first.round = 9
	exploded_vp_first.players[0].exploded = true
	exploded_vp_first.begin_evaluation()
	exploded_vp_first.players[0].coins = 5
	f += AssertUtil.truthy(exploded_vp_first.take_vp(0), "exploded player takes vp first")
	f += AssertUtil.eq(
		exploded_vp_first.convert_coins_to_vp(0),
		false,
		"exploded player cannot convert after taking vp"
	)

	gs.players[0].vp = 7
	gs.players[1].vp = 7
	f += AssertUtil.eq(gs.winners(), [0], "final pot breaks vp tie")
	gs.players[1].final_pot_furthest = 3
	f += AssertUtil.eq(gs.winners(), [0, 1], "shared winner after full tie")
	return f

static func _test_potion_helpers_and_end_turn() -> int:
	var f := 0
	var gs := GameState.new_game(2, 6)
	gs.begin_round()
	gs.players[0].bag = Bag.new()
	gs.players[0].bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	gs.players[0].bag.add(Chip.make(Chip.ChipColor.WHITE, 1))
	f += AssertUtil.eq(gs.draw()["index"], 1, "draw alias draws for active player")
	f += AssertUtil.truthy(gs.use_flask(), "use flask alias acts for active player")
	f += AssertUtil.eq(gs.draw_active()["index"], 1, "active player draws")
	f += AssertUtil.truthy(gs.all_players_stopped() == false, "not all players stopped")
	gs.stop()
	f += AssertUtil.eq(gs.advance_hotseat(), 1, "hotseat advances")
	gs.stop_active()
	f += AssertUtil.truthy(gs.all_players_stopped(), "all players stopped")

	var bag_before := gs.players[0].bag.size()
	gs.players[0].pending_bag_chips.append(Chip.make(Chip.ChipColor.GREEN, 1))
	gs.end_turn()
	f += AssertUtil.eq(gs.players[0].bag.size(), bag_before + 2, "pot and purchases return to bag")
	f += AssertUtil.eq(gs.players[0].pot.placements.size(), 0, "pot cleared")
	f += AssertUtil.eq(gs.round, 2, "round advances")
	f += AssertUtil.eq(gs.start_player, 1, "start player rotates each round")
	f += AssertUtil.eq(gs.phase, "end_of_turn", "normal turn ends")

	gs.round = 9
	gs.end_turn()
	f += AssertUtil.eq(gs.phase, "game_over", "round 9 ends game")
	return f

static func _test_pending_potion_choices_block_stop_and_flask() -> int:
	var failures := 0
	for pending_choice in ["awaiting_crow_choice", "awaiting_mandrake"]:
		var gs := GameState.new_game(1, 11)
		gs.begin_round()
		var player := gs.players[0]
		player.pot.place(Chip.make(Chip.ChipColor.WHITE, 1))
		player.set(pending_choice, true)

		failures += AssertUtil.eq(
			gs.use_flask_active(),
			false,
			"%s blocks flask use" % pending_choice
		)
		failures += AssertUtil.truthy(
			player.flask_full,
			"%s preserves flask while pending" % pending_choice
		)
		gs.stop_active()
		failures += AssertUtil.eq(
			player.stopped,
			false,
			"%s blocks stopping" % pending_choice
		)
	return failures

static func _test_evaluation_b_chip_actions() -> int:
	var f := 0
	var gs := GameState.new_game(3, 12)
	gs.begin_round()
	gs.start_player = 1
	gs.players[0].pot.place(Chip.make(Chip.ChipColor.BLACK, 1))
	gs.players[0].pot.place(Chip.make(Chip.ChipColor.BLACK, 1))
	gs.players[1].pot.place(Chip.make(Chip.ChipColor.GREEN, 1))
	gs.players[1].pot.place(Chip.make(Chip.ChipColor.GREEN, 1))
	gs.players[2].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	gs.players[2].pot.place(Chip.make(Chip.ChipColor.PURPLE, 1))
	gs.players[2].pot.place(Chip.make(Chip.ChipColor.PURPLE, 1))
	gs.players[2].pot.place(Chip.make(Chip.ChipColor.PURPLE, 1))
	gs.begin_evaluation()
	f += AssertUtil.eq(gs.players[0].pot.droplet, 1, "moth reward applies immediately")
	f += AssertUtil.eq(gs.players[0].rubies, 1, "moth beating both neighbors gains ruby")
	f += AssertUtil.eq(gs.players[1].rubies, 2, "spider gains one ruby per final green")
	f += AssertUtil.eq(gs.players[2].vp, 2, "ghosts use only their best tier")
	f += AssertUtil.eq(gs.players[2].pot.droplet, 1, "ghost best tier applies droplet immediately")
	f += AssertUtil.eq(
		gs.players[2].pending_droplet_bonus,
		0,
		"chip action droplets are not deferred"
	)

	var two_player := GameState.new_game(2, 13)
	two_player.begin_round()
	two_player.players[0].pot.place(Chip.make(Chip.ChipColor.BLACK, 1))
	two_player.players[1].pot.place(Chip.make(Chip.ChipColor.BLACK, 1))
	two_player.begin_evaluation()
	f += AssertUtil.eq(
		two_player.players[0].pot.droplet,
		1,
		"equal two-player moth counts gain droplets"
	)
	f += AssertUtil.eq(
		two_player.players[1].pot.droplet,
		1,
		"two-player moth reward applies to all players"
	)
	return f
