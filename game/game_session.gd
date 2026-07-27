extends Node

var controller: PhaseController

func start_local(player_count: int) -> void:
	if controller:
		controller.queue_free()
	controller = PhaseController.new()
	add_child(controller)
	controller.setup(player_count)
	controller.begin_round()
