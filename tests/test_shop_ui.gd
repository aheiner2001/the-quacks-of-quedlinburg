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
		9,
		"shop list provides explicit purchase controls for every chip"
	)
	failures += AssertUtil.truthy(
		controller.state.players[0].chose_vp,
		"non-exploded evaluation cannot skip automatic vp"
	)
	failures += AssertUtil.eq(
		shop.get_node("EvaluationPanel/DoneButton").disabled,
		false,
		"done is available after mandatory vp is granted"
	)
	controller.state.players[0].coins = 30
	controller.go_shop_active()
	shop.call("_refresh_evaluation")
	shop.get_node("PumpkinShelf").pressed.emit()
	failures += AssertUtil.eq(
		controller.state.players[0].purchases.size(),
		0,
		"browsing a shelf does not purchase"
	)
	var pumpkin_index := -1
	var mandrake_index := -1
	var poots_index := -1
	for index in shop.get_node("EvaluationPanel/WhiteShop").item_count:
		var sku: String = shop.get_node("EvaluationPanel/WhiteShop").get_item_metadata(index)
		if sku == "pumpkin":
			pumpkin_index = index
		elif sku == "mandrake":
			mandrake_index = index
		elif sku == "poots":
			poots_index = index
	failures += AssertUtil.truthy(pumpkin_index >= 0, "pumpkin has explicit buy entry")
	if pumpkin_index >= 0:
		failures += AssertUtil.eq(
			shop.get_node("EvaluationPanel/WhiteShop").is_item_disabled(pumpkin_index),
			false,
			"round 1 pumpkin buy entry enabled"
		)
		shop.call("_on_white_shop_item_clicked", pumpkin_index, Vector2.ZERO, MOUSE_BUTTON_LEFT)
		failures += AssertUtil.eq(
			controller.state.players[0].purchases,
			["pumpkin"],
			"explicit list click purchases pumpkin"
		)
	failures += AssertUtil.truthy(mandrake_index >= 0, "mandrake has explicit buy entry")
	if mandrake_index >= 0:
		failures += AssertUtil.truthy(
			shop.get_node("EvaluationPanel/WhiteShop").is_item_disabled(mandrake_index),
			"round 2 buy entry locked"
		)
	failures += AssertUtil.truthy(poots_index >= 0, "poots has explicit buy entry")
	if poots_index >= 0:
		failures += AssertUtil.truthy(
			shop.get_node("EvaluationPanel/WhiteShop").is_item_disabled(poots_index),
			"round 3 buy entry locked"
		)
	controller.state.players[0].flask_full = false
	shop.get_node("TextureButton").pressed.emit()
	failures += AssertUtil.truthy(
		controller.state.players[0].flask_full,
		"flask texture button remains an explicit purchase"
	)

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
