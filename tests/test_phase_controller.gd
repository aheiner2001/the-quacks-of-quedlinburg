class_name TestPhaseController
extends RefCounted

static func run() -> int:
	var failures := 0
	failures += _test_potions_transition()
	failures += _test_rejected_draw_emits_nothing()
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
	failures += AssertUtil.truthy(controller.go_shop_active(), "active eval player enters shop")
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
