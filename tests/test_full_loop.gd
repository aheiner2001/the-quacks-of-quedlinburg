class_name TestFullLoop
extends RefCounted

static func run() -> int:
	var failures := 0
	var game := GameState.new_game(2, 123)

	while game.phase != "game_over":
		game.begin_round()
		game.stop_active()
		game.advance_hotseat()
		game.stop_active()
		game.begin_evaluation()

		for player_index in game.players.size():
			game.take_vp(player_index)
			if game.round != 9:
				game.players[player_index].chose_shop = true
				game.finish_shop(player_index)
			else:
				game.players[player_index].evaluation_done = true

		game.end_turn()

	failures += AssertUtil.eq(game.round, 9, "full loop ends on round 9")
	failures += AssertUtil.eq(game.phase, "game_over", "full loop reaches game over")
	failures += AssertUtil.truthy(game.winners().size() >= 1, "full loop has a winner")
	return failures
