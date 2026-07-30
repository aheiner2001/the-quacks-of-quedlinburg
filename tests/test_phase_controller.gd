class_name TestPhaseController
extends RefCounted

static func run() -> int:
	var failures := 0
	failures += _test_potions_transition()
	failures += _test_rejected_draw_emits_nothing()
	failures += _test_crow_skull_explosion_emits_signal()
	failures += _test_bonus_die_rolls_each_eligible_player()
	failures += _test_evaluation_hotseat()
	failures += _test_end_turn_and_continue()
	return failures

static func _test_potions_transition() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(1, 99)
	controller.begin_round()
	failures += AssertUtil.eq(controller.state.phase, "potions", "phase potions")
	controller.stop_active()
	failures += AssertUtil.eq(
		controller.state.phase,
		"bonus_die",
		"bonus die starts after only player stops"
	)
	controller.finish_bonus_die_phase()
	failures += AssertUtil.eq(controller.state.phase, "evaluation", "bonus die finishes into evaluation")
	controller.free()
	return failures

static func _test_crow_skull_explosion_emits_signal() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(1, 105)
	controller.begin_round()
	var player := controller.state.players[0]
	player.pot.place(Chip.make(Chip.ChipColor.WHITE, 7))
	player.pending_crow_draws = [Chip.make(Chip.ChipColor.WHITE, 1)]
	player.awaiting_crow_choice = true
	var explosion_events: Array[int] = []
	controller.exploded.connect(func(player_index: int): explosion_events.append(player_index))

	controller.resolve_crow_skull_active(0)

	failures += AssertUtil.eq(explosion_events, [0], "exploding crow selection emits explosion")
	failures += AssertUtil.truthy(player.exploded, "exploding crow selection marks player exploded")
	failures += AssertUtil.truthy(player.stopped, "exploding crow selection stops player")
	controller.free()
	return failures

static func _test_bonus_die_rolls_each_eligible_player() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(2, 103)
	controller.begin_round()
	controller.state.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 4))
	controller.state.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	controller.stop_active()
	controller.stop_active()
	controller.state.rng.seed = 1001
	var leader_before := _bonus_snapshot(controller.state.players[0])
	var trailing_before := _bonus_snapshot(controller.state.players[1])
	var face := controller.roll_bonus_die_active()
	failures += _assert_bonus_die_reward(
		controller.state.players[0], leader_before, face, "sole leader receives die reward"
	)
	failures += _assert_bonus_snapshot(
		controller.state.players[1], trailing_before, "trailing player receives no die reward"
	)
	controller.finish_bonus_die_phase()
	controller.free()

	controller = PhaseController.new()
	controller.setup(2, 104)
	controller.begin_round()
	controller.state.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	controller.state.players[1].pot.place(Chip.make(Chip.ChipColor.ORANGE, 2))
	controller.stop_active()
	controller.stop_active()
	controller.state.rng.seed = 1002
	var first_before := _bonus_snapshot(controller.state.players[0])
	var second_before := _bonus_snapshot(controller.state.players[1])
	face = controller.roll_bonus_die_active()
	failures += _assert_bonus_die_reward(
		controller.state.players[0], first_before, face, "first tied leader receives die reward"
	)
	failures += _assert_bonus_snapshot(
		controller.state.players[1], second_before, "second tied leader waits for die reward"
	)
	second_before = _bonus_snapshot(controller.state.players[1])
	face = controller.roll_bonus_die_active()
	failures += _assert_bonus_die_reward(
		controller.state.players[1], second_before, face, "second tied leader receives die reward"
	)
	controller.finish_bonus_die_phase()
	failures += AssertUtil.eq(controller.state.phase, "evaluation", "bonus die finishes after eligible rolls")
	controller.free()
	return failures

static func _bonus_snapshot(player: PlayerState) -> Dictionary:
	return {
		"vp": player.vp,
		"rubies": player.rubies,
		"droplet": player.pot.droplet,
		"pending_droplet_bonus": player.pending_droplet_bonus,
		"bag_size": player.bag.size(),
	}

static func _assert_bonus_snapshot(player: PlayerState, before: Dictionary, label: String) -> int:
	var failures := 0
	failures += AssertUtil.eq(player.vp, before["vp"], "%s vp" % label)
	failures += AssertUtil.eq(player.rubies, before["rubies"], "%s rubies" % label)
	failures += AssertUtil.eq(player.pot.droplet, before["droplet"], "%s droplet" % label)
	failures += AssertUtil.eq(
		player.pending_droplet_bonus,
		before["pending_droplet_bonus"],
		"%s pending droplet" % label
	)
	failures += AssertUtil.eq(player.bag.size(), before["bag_size"], "%s bag" % label)
	return failures

static func _assert_bonus_die_reward(
	player: PlayerState, before: Dictionary, face: int, label: String
) -> int:
	match face:
		BonusDie.Face.VP1:
			return AssertUtil.eq(player.vp, before["vp"] + 1, label)
		BonusDie.Face.VP2:
			return AssertUtil.eq(player.vp, before["vp"] + 2, label)
		BonusDie.Face.RUBY:
			return AssertUtil.eq(player.rubies, before["rubies"] + 1, label)
		BonusDie.Face.DROPLET:
			var failures := 0
			failures += AssertUtil.eq(player.pot.droplet, before["droplet"], "%s defers droplet" % label)
			failures += AssertUtil.eq(
				player.pending_droplet_bonus,
				before["pending_droplet_bonus"] + 1,
				label
			)
			return failures
		BonusDie.Face.ORANGE:
			return AssertUtil.eq(player.bag.size(), before["bag_size"] + 1, label)
	return AssertUtil.eq(face, -1, "%s has a valid die face" % label)

static func _test_rejected_draw_emits_nothing() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(1, 102)
	controller.begin_round()
	controller.state.players[0].stopped = true
	var draw_events: Array = []
	controller.chip_drawn.connect(
		func(player_index: int, result: Dictionary):
			draw_events.append([player_index, result])
	)
	controller.draw_active()
	failures += AssertUtil.eq(draw_events.size(), 0, "rejected draw emits no chip event")
	controller.free()
	return failures

static func _test_evaluation_hotseat() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(2, 100)
	controller.begin_round()
	controller.state.players[0].pot.place(Chip.make(Chip.ChipColor.ORANGE, 1))
	controller.state.players[1].pot.place(Chip.make(Chip.ChipColor.GREEN, 1))
	controller.state.players[0].stopped = true
	controller.state.players[1].stopped = true
	controller.state.begin_evaluation()
	failures += AssertUtil.eq(controller.state.eval_player, 0, "evaluation starts at player 0")
	failures += AssertUtil.truthy(
		controller.state.players[0].chose_vp,
		"active eval player automatically receives vp"
	)
	controller.state.players[0].coins = 10
	failures += AssertUtil.truthy(controller.go_shop_active(), "active eval player selects shop")
	failures += AssertUtil.truthy(
		controller.continue_to_shop_active(), "continue enters shop phase"
	)
	failures += AssertUtil.truthy(controller.buy_active("pumpkin_1"), "active eval player buys")
	failures += AssertUtil.eq(
		controller.finish_eval_player(),
		false,
		"first evaluation completion has another player"
	)
	failures += AssertUtil.eq(controller.state.eval_player, 1, "evaluation advances to player 1")
	failures += AssertUtil.truthy(
		controller.state.players[1].chose_vp,
		"second player automatically receives vp"
	)
	failures += AssertUtil.truthy(
		controller.finish_eval_player(),
		"last evaluation completion reports all done"
	)
	controller.free()
	return failures

static func _test_end_turn_and_continue() -> int:
	var failures := 0
	var controller := PhaseController.new()
	controller.setup(1, 101)
	controller.begin_round()
	controller.state.begin_evaluation()
	controller.state.players[0].evaluation_done = true
	controller.end_turn_and_continue()
	failures += AssertUtil.eq(controller.state.round, 2, "continue advances round")
	failures += AssertUtil.eq(controller.state.phase, "potions", "continue begins next round")

	controller.state.round = 9
	controller.state.begin_evaluation()
	controller.state.players[0].coins = 5
	controller.state.players[0].rubies = 2
	failures += AssertUtil.truthy(controller.convert_coins_active(), "active converts coins")
	failures += AssertUtil.truthy(controller.convert_rubies_active(), "active converts rubies")
	controller.state.players[0].evaluation_done = true
	var game_over_events: Array = []
	controller.game_over.connect(func(winners: Array): game_over_events.append(winners))
	controller.end_turn_and_continue()
	failures += AssertUtil.eq(controller.state.phase, "game_over", "final continue stays game over")
	failures += AssertUtil.eq(game_over_events.size(), 1, "final continue emits game over")
	controller.free()
	return failures
