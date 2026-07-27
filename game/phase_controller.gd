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

func _after_potions_action() -> void:
	if state.all_players_stopped():
		state.begin_evaluation()
		phase_changed.emit(state.phase)
	elif state.players[state.active_player].stopped:
		state.advance_hotseat()
		active_player_changed.emit(state.active_player)
