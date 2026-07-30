extends SceneTree

func _initialize() -> void:
	var session = root.get_node("GameSession")
	session.call("start_local", 1)
	var controller = session.controller as PhaseController
	controller.stop_active()
	controller.finish_bonus_die_phase()
	controller.go_shop_active()
	controller.continue_to_shop_active()

	var shop = (load("res://node_2d.tscn") as PackedScene).instantiate()
	root.add_child(shop)
	print("shop in tree=", shop.is_inside_tree())
	print("abs=", shop.get_node_or_null("/root/GameSession"))
	print("tree root=", shop.get_tree().root.get_node_or_null("GameSession"))
	print("ctrl via abs prop=", shop.get_node_or_null("/root/GameSession").controller if shop.get_node_or_null("/root/GameSession") else null)
	print("shop._controller()=", shop.call("_controller"))
	print("phase=", controller.state.phase, " chose=", controller.state.players[0].chose_shop, " done=", controller.state.players[0].evaluation_done)
	print("is_shopping=", shop.call("_is_shopping"))
	quit(0)
