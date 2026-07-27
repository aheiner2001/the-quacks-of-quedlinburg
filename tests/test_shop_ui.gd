class_name TestShopUI
extends RefCounted

static func run() -> int:
	var failures := 0
	var packed := load("res://node_2d.tscn") as PackedScene
	failures += AssertUtil.truthy(packed != null, "shop scene loads")
	if packed == null:
		return failures

	var shop := packed.instantiate()
	failures += AssertUtil.truthy(shop.get_script() != null, "shop script compiles")
	var expected_nodes := {
		"EvaluationPanel/TakeVPButton": Button,
		"EvaluationPanel/GoShopButton": Button,
		"EvaluationPanel/ConvertCoinsButton": Button,
		"EvaluationPanel/ConvertRubiesButton": Button,
		"EvaluationPanel/DoneButton": Button,
		"EvaluationPanel/StatusLabel": Label,
		"EvaluationPanel/WhiteShop": ItemList,
	}
	for node_path: String in expected_nodes:
		var node := shop.get_node_or_null(node_path)
		failures += AssertUtil.truthy(node != null, "shop has %s" % node_path)
		if node:
			failures += AssertUtil.truthy(
				is_instance_of(node, expected_nodes[node_path]),
				"%s has expected type" % node_path
			)

	var root: Window = Engine.get_main_loop().root
	var session: Node = root.get_node("GameSession")
	session.call("start_local", 1)
	var controller := session.get("controller") as PhaseController
	controller.stop_active()
	root.add_child(shop)
	failures += AssertUtil.truthy(
		shop.get_node("EvaluationPanel").visible,
		"evaluation panel visible during evaluation"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/WhiteShop").item_count,
		3,
		"white shop lists three chips"
	)
	controller.state.players[0].coins = 30
	controller.go_shop_active()
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(shop.get_node("PumpkinShelf").disabled, false, "round 1 shelf enabled")
	failures += AssertUtil.truthy(shop.get_node("MandrakeShelf").disabled, "round 2 shelf locked")
	failures += AssertUtil.truthy(shop.get_node("Pootsshelf").disabled, "round 3 shelf locked")

	controller.state.round = 9
	controller.state.begin_evaluation()
	shop.call("_refresh_evaluation")
	failures += AssertUtil.eq(shop.get_node("PumpkinShelf").visible, false, "shop hidden round 9")
	failures += AssertUtil.truthy(
		shop.get_node("EvaluationPanel/ConvertCoinsButton").visible,
		"coin conversion shown round 9"
	)
	root.remove_child(shop)
	shop.free()
	return failures
