class_name PhaseController
extends Node

signal phase_changed(phase: String)
signal active_player_changed(index: int)
signal chip_drawn(player: int, result: Dictionary)
signal exploded(player: int)
signal flask_used(player: int)
signal potion_choice_resolved(player: int)
signal round_ended(round: int)
signal game_over(winner_indices: Array)
signal bonus_die_needed

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

func resolve_crow_skull_active(keep_index: int) -> void:
	var player_index := state.active_player
	var result := state.resolve_crow_skull(player_index, keep_index)
	if not result.is_empty():
		chip_drawn.emit(player_index, result)
	potion_choice_resolved.emit(player_index)
	_after_potions_action()

func resolve_mandrake_active(return_white: bool) -> void:
	var player_index := state.active_player
	state.resolve_mandrake(player_index, return_white)
	potion_choice_resolved.emit(player_index)
	_after_potions_action()

func roll_bonus_die_active() -> int:
	if state.phase != "bonus_die" or state.bonus_die_index >= state.bonus_die_queue.size():
		return -1
	var face := BonusDie.roll(state.rng)
	var player_index := state.bonus_die_queue[state.bonus_die_index]
	state.apply_bonus_die(player_index, face)
	state.bonus_die_index += 1
	return face

func finish_bonus_die_phase() -> void:
	if state.phase != "bonus_die":
		return
	state.finish_bonus_die()
	phase_changed.emit(state.phase)

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
		state.begin_bonus_die()
		phase_changed.emit(state.phase)
		bonus_die_needed.emit()
	elif state.players[state.active_player].stopped:
		state.advance_hotseat()
		active_player_changed.emit(state.active_player)
