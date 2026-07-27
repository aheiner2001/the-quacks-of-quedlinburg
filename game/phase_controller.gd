class_name PhaseController
extends Node

signal phase_changed(phase: String)
signal active_player_changed(index: int)
signal chip_drawn(player: int, result: Dictionary)
signal exploded(player: int)
signal flask_used(player: int)
signal round_ended(round: int)
signal game_over(winner_indices: Array)

var state: GameState

func setup(player_count: int, seed: int = 0) -> void:
	state = GameState.new_game(player_count, seed)

func begin_round() -> void:
	state.begin_round()
	phase_changed.emit(state.phase)
	active_player_changed.emit(state.active_player)

func draw_active() -> void:
	var player_index := state.active_player
	var result := state.draw_active()
	if result.is_empty():
		return
	chip_drawn.emit(player_index, result)
	if result.get("exploded", false):
		exploded.emit(player_index)
	_after_potions_action()

func stop_active() -> void:
	state.stop_active()
	_after_potions_action()

func use_flask_active() -> void:
	if state.use_flask_active():
		flask_used.emit(state.active_player)

func take_vp_active() -> bool:
	return state.take_vp(state.eval_player)

func go_shop_active() -> bool:
	var changed := state.go_to_shop(state.eval_player)
	if changed:
		phase_changed.emit(state.phase)
	return changed

func buy_active(sku: String) -> bool:
	return state.buy(state.eval_player, sku)

func refill_flask_active() -> bool:
	return state.refill_flask(state.eval_player)

func finish_eval_player() -> bool:
	return state.finish_eval_player()

func convert_coins_active() -> bool:
	return state.convert_coins_to_vp(state.eval_player)

func convert_rubies_active() -> bool:
	return state.convert_rubies_to_vp(state.eval_player)

func end_turn_and_continue() -> void:
	state.end_turn()
	if state.phase == "game_over":
		phase_changed.emit(state.phase)
		game_over.emit(state.winners())
	else:
		begin_round()

func _after_potions_action() -> void:
	if state.all_players_stopped():
		state.begin_evaluation()
		phase_changed.emit(state.phase)
	elif state.players[state.active_player].stopped:
		state.advance_hotseat()
		active_player_changed.emit(state.active_player)
